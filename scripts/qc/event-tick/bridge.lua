-- Staged QC only: exercise event timestamps that differ from the engine tick.
-- This catches hidden game.tick reads and loss of tick zero through helper calls.
local tesla_tick_qc = require("scripts/control/teslas-legacy").tick_qc
local fluid_tick_qc = require("scripts/control/fluid-safety").tick_qc
local train_tick_qc = require("scripts/control/em-trains/charger").tick_qc
local neutron_tick_qc = require("scripts/control/neutron-collector")
local tick_qc_previous = script.get_event_handler(defines.events.on_tick)

script.on_event(defines.events.on_tick, function(event)
    tick_qc_previous(event)
    if event.tick ~= 1 then return end

    local checks = 0
    local function check(condition, name)
        assert(condition, "EVENT_TICK failed: " .. name)
        checks = checks + 1
        log("EVENT_TICK PASS " .. name)
    end

    local state = {burst_gates = {}, recent_hits_by_unit = {}, recent_hits_by_position = {}}
    local surface = game.surfaces[1]
    local position = {x = 100, y = 100}
    check(tesla_tick_qc.burst(state, "qc", surface.index, position, 0), "first burst at tick zero")
    check(not tesla_tick_qc.burst(state, "qc", surface.index, position, tesla_tick_qc.burst_ttl), "burst blocked at cooldown boundary")
    check(tesla_tick_qc.burst(state, "qc", surface.index, position, tesla_tick_qc.burst_ttl + 1), "burst allowed after event cooldown")

    local target = surface.create_entity{name = "steel-chest", position = position, force = "player"}
    assert(target and target.valid, "EVENT_TICK fixture target missing")
    local hit = {tick = 10000, target_entity = target, target_position = position, surface_index = surface.index}
    tesla_tick_qc.remember(state, hit, "qc-hit", target.force, 10)
    check(state.recent_hits_by_unit[target.unit_number].tick == 10000, "hit stores supplied event tick")
    check(tesla_tick_qc.take(state, target, "qc-hit", false, 10010) ~= nil, "hit retained at TTL boundary")
    tesla_tick_qc.remember(state, hit, "qc-hit", target.force, 10)
    check(tesla_tick_qc.take(state, target, "qc-hit", true, 10011) == nil, "expired hit rejected using current death tick")
    hit.tick = 0
    tesla_tick_qc.remember(state, hit, "qc-zero", target.force, 10)
    check(state.recent_hits_by_unit[target.unit_number].tick == 0, "hit preserves tick zero")
    target.destroy()

    local segment = {}
    fluid_tick_qc.warn(segment, "last_warning", 60, "event tick fixture", 10000)
    check(segment.last_warning == 10000, "warning records supplied tick")
    fluid_tick_qc.warn(segment, "last_warning", 60, "event tick fixture", 10059)
    check(segment.last_warning == 10000, "warning throttled before event deadline")
    fluid_tick_qc.warn(segment, "last_warning", 60, "event tick fixture", 10060)
    check(segment.last_warning == 10060, "warning resumes at event deadline")

    local entry = {}
    check(train_tick_qc.glow(entry, 2, 10000).tick == 10000, "EM glow records service tick")
    check(train_tick_qc.glow(entry, 2, 0).tick == 0, "EM glow preserves tick zero")

    -- Keep the real dispatcher-facing neutron methods; isolate expensive world
    -- operations so different budget branches can expose the ticks they receive.
    local originals, observed = {}, {}
    local function replace(name, fn)
        originals[name] = neutron_tick_qc[name]
        neutron_tick_qc[name] = fn
    end
    local runtime = {
        dirty_collector_count = 2, connected_source_count = 2,
        open_by_player = {[1] = true}, gui_refresh_buckets = {[10000] = {1}},
        wire_output_buckets = {},
    }
    replace("ensure_runtime_ready", function() return runtime end)
    replace("service_gui_refreshes", function(tick) observed.gui = tick; return false end)
    replace("process_dirty_collectors", function(_, _, tick) observed.dirty = tick; return 1 end)
    replace("poll_connected_sources", function(_, _, tick) observed.poll = tick; return 1 end)
    replace("service_wire_proxy_outputs", function(_, tick) observed.wire = tick; return 0 end)
    local ok, err = pcall(function()
        check(neutron_tick_qc.get_pending_work_count({tick = 9999}) == 4, "GUI work excluded before event deadline")
        check(neutron_tick_qc.get_pending_work_count({tick = 10000}) == 5, "GUI work included at event deadline")
        neutron_tick_qc.update(2, {tick = 10000})
        for _, role in ipairs({"gui", "dirty", "poll", "wire"}) do
            check(observed[role] == 10000, "neutron " .. role .. " receives current event tick")
        end
        neutron_tick_qc.update(2, {tick = 0})
        for _, role in ipairs({"gui", "dirty", "poll", "wire"}) do
            check(observed[role] == 0, "neutron " .. role .. " preserves tick zero")
        end
    end)
    for name, fn in pairs(originals) do neutron_tick_qc[name] = fn end
    assert(ok, err)
    log("EVENT_TICK ALL_COMPLETE checks=" .. checks)
end)
