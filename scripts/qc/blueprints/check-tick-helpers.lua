-- Mock regression for the two QC helpers' callback-time contracts.
-- Runs under standalone Lua 5.4 against the actual helper files; this is NOT
-- Factorio engine, gameplay, LuaObject, rendering, or multiplayer validation.
-- Usage (repo cwd): .tools/lua-5.4.8/lua54.exe scripts/qc/blueprints/check-tick-helpers.lua [repo-root]
local repo = arg[1] or "."
local checked = 0

local function equal(actual, expected, message)
    checked = checked + 1
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function truthy(value, message)
    checked = checked + 1
    assert(value, message)
end

local EMERALD = "zzz-emerald-doctrine-qc_0.0.1"
local AURIC = "zzz-auric-fumarole-qc_0.0.1"
local MAIN_REMOTE = "exotic-industries-qc"
local SERVICE = "service_emerald_apocalypse_hover_tank_qc"
local SNAPSHOT = "get_emerald_apocalypse_hover_tank_qc_snapshot"

local function make_harness(helper, options)
    options = options or {}
    local h = {
        callbacks = {}, interfaces = {}, writes = {}, records = {}, calls = {},
        clock = {tick = 900000, reads = 0, forbid = false},
        generation_calls = 0, generation_tick_delta = 0,
    }
    local entities = {}
    local next_unit = 100
    local surface = {valid = true, name = helper == AURIC and "vulcanus" or "emerald-doctrine-qc"}
    surface.request_to_generate_chunks = function() end
    surface.force_generate_chunk_requests = function()
        h.generation_calls = h.generation_calls + 1
        -- A changing mock boundary clock proves a captured value stays stable
        -- through preparation; this does not model engine generation timing.
        h.clock.tick = h.clock.tick + h.generation_tick_delta
    end
    surface.find_entities_filtered = function()
        if helper == AURIC then return {} end
        return entities
    end
    surface.get_chunks = function() return function() return nil end end
    surface.is_chunk_generated = function() return false end
    surface.create_entity = function(spec)
        next_unit = next_unit + 1
        local entity = {valid = true, unit_number = next_unit, name = spec.name}
        entity.insert = function() return 1 end
        entity.destroy = function() entity.valid = false end
        entities[#entities + 1] = entity
        return entity
    end
    h.surface = surface
    local game = {forces = {}, surfaces = {}, planets = {}}
    if not options.missing_surface then game.surfaces[surface.name] = surface end
    game.create_surface = function(name)
        surface.name = name
        game.surfaces[name] = surface
        return surface
    end
    game.create_force = function(name)
        local force = {technologies = setmetatable({}, {
            __index = function(technologies, key)
                local technology = {researched = false}
                technologies[key] = technology
                return technology
            end,
        })}
        game.forces[name] = force
        return force
    end
    setmetatable(game, {
        __index = function(_, key)
            if key == "tick" then
                h.clock.reads = h.clock.reads + 1
                assert(not h.clock.forbid, "event path read game.tick instead of supplied tick")
                return h.clock.tick
            end
        end,
    })

    local remote = {interfaces = {
        [MAIN_REMOTE] = {
            reset_emerald_apocalypse_hover_tank_runtime = true,
            configure_emerald_apocalypse_hover_tank_qc = true,
            [SERVICE] = true,
            [SNAPSHOT] = true,
        },
    }}
    remote.add_interface = function(name, members)
        h.interfaces[name] = members
        remote.interfaces[name] = members
    end
    remote.call = function(name, member, ...)
        equal(name, MAIN_REMOTE, "remote receiver")
        local args = table.pack(...)
        h.calls[#h.calls + 1] = {member = member, args = args}
        -- The real main-mod remote currently reads its own game.tick. This
        -- spy validates only the helper's forwarded argument and successful
        -- response handling, not the main remote's time semantics.
        if member == SNAPSHOT then return {tick = args[1], qc_enabled = true, tracked_tanks = 1} end
        if member == "configure_emerald_apocalypse_hover_tank_qc" then return {tracked_tanks = 1} end
        return true
    end
    local env = setmetatable({
        storage = {}, game = game, remote = remote,
        defines = {events = {on_tick = 1}},
        script = {
            on_init = function(fn) h.callbacks.init = fn end,
            on_configuration_changed = function(fn) h.callbacks.config = fn end,
            on_event = function(id, fn)
                equal(id, 1, "only expected event registered")
                h.callbacks.tick = fn
            end,
        },
        helpers = {
            table_to_json = function(record)
                h.records[#h.records + 1] = record
                return "mock-record-" .. #h.records
            end,
            write_file = function(path, contents, append)
                h.writes[#h.writes + 1] = {path = path, contents = contents, append = append}
            end,
        },
        log = function() end,
    }, {__index = _G})
    h.env = env
    local path = repo .. "/.codex/skills/esir-dev/assets/" .. helper .. "/control.lua"
    local chunk, message = loadfile(path, "t", env)
    assert(chunk, message)
    chunk()
    truthy(h.callbacks.init and h.callbacks.config and h.callbacks.tick, helper .. " callbacks")
    equal(h.clock.reads, 0, helper .. " load is clock-free")
    return h
end

local function call_event(h, tick)
    local reads = h.clock.reads
    h.clock.forbid = true
    h.callbacks.tick({tick = tick})
    equal(h.clock.reads, reads, "event callback must not even attempt game.tick")
end

local function check_emerald_event_windows(base)
    local h = make_harness(EMERALD)
    call_event(h, base)
    local state = h.env.storage.emerald_doctrine_qc
    equal(state.base_tick, base, "Emerald event-build base tick including zero")
    equal(h.records[1].event, "built", "Emerald build report kind")
    equal(h.records[1].tick, base, "Emerald event-build report time")
    equal(state.checkpoint_index, 1, "Emerald initial checkpoint")
    for index, offset in ipairs({1, 30, 120, 360, 720, 1200}) do
        local record_count, call_count = #h.records, #h.calls
        call_event(h, base + offset - 1)
        equal(#h.records, record_count, "Emerald no early checkpoint")
        equal(#h.calls, call_count, "Emerald no early service")
        call_event(h, base + offset)
        equal(#h.records, record_count + 1, "Emerald exact deadline emits once")
        equal(#h.calls, call_count + 2, "Emerald service and snapshot calls")
        local record = h.records[#h.records]
        equal(record.event, "checkpoint", "Emerald checkpoint kind")
        equal(record.tick, base + offset, "Emerald report supplied tick")
        equal(record.relative_tick, offset, "Emerald report relative tick")
        truthy(record.service.ok and record.snapshot_ok, "Emerald successful spy responses")
        equal(h.calls[#h.calls - 1].member, SERVICE, "Emerald service remote")
        equal(h.calls[#h.calls - 1].args[1], 4096, "Emerald service budget")
        equal(h.calls[#h.calls - 1].args[2], base + offset, "Emerald forwarded service tick")
        equal(h.calls[#h.calls].member, SNAPSHOT, "Emerald snapshot remote")
        equal(h.calls[#h.calls].args[1], base + offset, "Emerald forwarded snapshot tick")
        equal(state.checkpoint_index, index + 1, "Emerald checkpoint advances once")
        call_event(h, base + offset)
        equal(#h.records, record_count + 1, "Emerald duplicate boundary cannot repeat checkpoint")
    end
    call_event(h, base + 5000)
    equal(#h.records, 7, "Emerald completed checkpoints remain exhausted")
end

local function check_emerald_boundaries()
    local h = make_harness(EMERALD)
    h.generation_tick_delta = 100
    h.clock.tick = 0
    h.callbacks.init()
    equal(h.clock.reads, 1, "Emerald init captures one boundary clock")
    equal(h.env.storage.emerald_doctrine_qc.base_tick, 0, "Emerald init captures zero before world build")
    equal(h.records[#h.records].tick, 0, "Emerald init report keeps captured zero")

    h.clock.reads, h.clock.tick = 0, 4000
    h.callbacks.config({tick = 123456}) -- configuration payload time is not used
    equal(h.clock.reads, 1, "Emerald configuration captures once")
    equal(h.env.storage.emerald_doctrine_qc.base_tick, 4000, "Emerald configuration boundary time")

    local api = h.interfaces["zzz-emerald-doctrine-qc"]
    h.clock.reads, h.clock.tick = 0, 8000
    h.env.storage.emerald_doctrine_qc.checkpoint_index = 5
    truthy(api.rebuild(), "Emerald remote rebuild result")
    equal(h.clock.reads, 1, "Emerald rebuild captures once")
    equal(h.env.storage.emerald_doctrine_qc.base_tick, 8000, "Emerald remote rebuild base")
    equal(h.env.storage.emerald_doctrine_qc.checkpoint_index, 1, "Emerald rebuild resets checkpoint")

    h.clock.reads, h.clock.tick = 0, 12345
    local result = api.snapshot()
    equal(h.clock.reads, 1, "Emerald context-free snapshot captures once")
    truthy(result.ok, "Emerald snapshot result")
    equal(h.calls[#h.calls].args[1], 12345, "Emerald context-free snapshot forwards boundary time")
end

local function report_fields(text)
    local fields = {}
    for line in text:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key then fields[key] = value end
    end
    return fields
end

local function check_auric_event_windows(base)
    local h = make_harness(AURIC)
    call_event(h, base)
    local state = h.env.storage.auric_fumarole_qc
    equal(state.start_tick, base, "Auric fallback initialization preserves event base including zero")
    equal(#h.writes, 1, "Auric fallback resets output once")
    equal(h.writes[1].append, false, "Auric reset overwrites output")
    equal(h.writes[1].contents, "", "Auric reset clears output")
    local previous_offset
    for index, offset in ipairs({2, 60, 600, 1800, 36000, 40000, 126000, 162000, 198000, 234000, 414000}) do
        local count = #h.writes
        call_event(h, base + offset - 1)
        equal(#h.writes, count, "Auric no early report")
        call_event(h, base + offset)
        equal(#h.writes, count + 1, "Auric report at exact scheduled offset")
        equal(h.writes[#h.writes].append, true, "Auric scheduled report appends")
        local fields = report_fields(h.writes[#h.writes].contents)
        equal(tonumber(fields.tick), base + offset, "Auric report supplied tick")
        equal(state.start_tick, base, "Auric report does not reset base")
        equal(state.previous_report_relative_tick, offset, "Auric report state supplied relative tick")
        equal(tonumber(fields.backfill_estimated_serviced_since_reset), math.floor(offset / 30) * 4,
            "Auric backfill estimate uses supplied relative time")
        local pulses = previous_offset and math.floor((offset - previous_offset) / 1800) or 0
        equal(tonumber(fields.auric_recovery_pulses_previous), pulses,
            "Auric recovery window uses previous supplied report time")
        equal(tonumber(fields.auric_zero_sample_count), index, "Auric sample count advances at reports only")
        call_event(h, base + offset + 1)
        equal(#h.writes, count + 1, "Auric no late report")
        equal(state.previous_report_relative_tick, offset, "Auric off-deadline callback leaves report state")
        previous_offset = offset
    end
    equal(h.generation_calls, 1, "Auric start zero is valid and does not reinitialize")
end

local function check_auric_boundaries()
    local h = make_harness(AURIC)
    h.generation_tick_delta = 100
    h.clock.tick = 0
    h.callbacks.init()
    equal(h.clock.reads, 1, "Auric init captures one boundary clock")
    equal(h.env.storage.auric_fumarole_qc.start_tick, 0, "Auric init captures zero before prepare")
    h.clock.reads, h.clock.tick = 0, 4000
    h.env.storage.auric_fumarole_qc.previous_report_relative_tick = 600
    h.env.storage.auric_fumarole_qc.auric_zero_sample_count = 9
    h.callbacks.config({tick = 123456})
    equal(h.clock.reads, 1, "Auric configuration captures once")
    equal(h.env.storage.auric_fumarole_qc.start_tick, 4000, "Auric config retains pre-prepare boundary time")
    equal(h.env.storage.auric_fumarole_qc.previous_report_relative_tick, nil, "Auric config clears report history")
    equal(h.env.storage.auric_fumarole_qc.auric_zero_sample_count, nil, "Auric config clears sample counters")
    equal(h.writes[#h.writes].append, false, "Auric config resets output")

    local missing = make_harness(AURIC, {missing_surface = true})
    call_event(missing, 50000)
    call_event(missing, 50002)
    local fields = report_fields(missing.writes[#missing.writes].contents)
    equal(fields.vulcanus, "missing", "Auric missing-surface report branch")
    equal(tonumber(fields.tick), 50002, "Auric missing-surface branch retains event time")
end

check_emerald_event_windows(0)
check_emerald_event_windows(50000)
check_emerald_boundaries()
check_auric_event_windows(0)
check_auric_event_windows(50000)
check_auric_boundaries()
print("QC_HELPER_TICK_MOCK ALL_COMPLETE: " .. checked .. " assertions; actual helper files, mocked APIs, no Factorio engine")
