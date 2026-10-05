-- Staged-only engine assertions against the actual shared scheduler module.
do
    local scheduler = require("lib/runtime-scheduler")
    local previous = script.get_event_handler(defines.events.on_tick)
    local finished = false
    script.on_event(defines.events.on_tick, function(event)
        previous(event)
        if finished then return end
        finished = true
        local checks = {}
        local function check(name, condition)
            checks[#checks + 1] = {name = name, pass = condition == true}
            assert(condition, "Runtime scheduler QC: " .. name)
        end
        local saved_game, saved_helpers, saved_log = game, helpers, log
        local saved_state = storage.ei.runtime_scheduler
        local encoded, writes, clocks = {}, 0, 0
        local ok, failure = pcall(function()
            storage.ei.runtime_scheduler = nil
            _G.helpers = {
                table_to_json = function(record) encoded[#encoded + 1] = record; return "fixture" end,
                write_file = function() writes = writes + 1 end,
            }
            _G.log = function() end
            _G.game = setmetatable({}, {__index = function() error("Unexpected clock lookup") end})
            for _, tick in ipairs({0, 9371}) do
                check("counter-return-" .. tick, scheduler.bump_counter("qc", "count", 2, tick) == (tick == 0 and 2 or 4))
                check("counter-tick-" .. tick, scheduler.ensure_module_state("qc").last_tick == tick)
                local status = {sentinel = tick}
                check("status-identity-" .. tick, scheduler.set_module_status("qc", status, tick) == status)
                check("status-tick-" .. tick, scheduler.ensure_module_state("qc").last_tick == tick)
                local extra = {sentinel = true}
                local snapshot = scheduler.status_snapshot(extra, tick)
                check("snapshot-tick-" .. tick, snapshot.tick == tick)
                check("snapshot-shallow-" .. tick, snapshot.extra == extra and snapshot.modules == storage.ei.runtime_scheduler.modules)
                check("forced-write-" .. tick, scheduler.write_telemetry("qc", status, true, tick))
                check("write-tick-" .. tick, encoded[#encoded].tick == tick)
                local logged = scheduler.log_snapshot("qc-log", extra, tick)
                check("log-ticks-" .. tick, logged.tick == tick and encoded[#encoded].tick == tick
                    and encoded[#encoded].payload == logged and storage.ei.runtime_scheduler.telemetry.last_snapshot_tick == tick)
            end
            _G.game = setmetatable({}, {__index = function(_, key)
                assert(key == "tick"); clocks = clocks + 1; return 500 + clocks
            end})
            local count = scheduler.bump_counter("qc", "count")
            check("legacy-counter-default", count == 5 and scheduler.ensure_module_state("qc").last_tick == 501)
            local status = scheduler.set_module_status("qc", nil)
            check("legacy-status-default", next(status) == nil and scheduler.ensure_module_state("qc").last_tick == 502)
            check("legacy-snapshot", scheduler.status_snapshot().tick == 503)
            check("legacy-telemetry", scheduler.write_telemetry("legacy", {}, true) and encoded[#encoded].tick == 504)
            local before = clocks
            local logged = scheduler.log_snapshot("legacy-log", {})
            check("log-one-clock", clocks == before + 1 and logged.tick == 505 and encoded[#encoded].tick == 505
                and encoded[#encoded].payload.tick == 505 and storage.ei.runtime_scheduler.telemetry.last_snapshot_tick == 505)
            _G.game = nil
            check("no-game-counter", scheduler.bump_counter("qc", "count", 0) == 5 and scheduler.ensure_module_state("qc").last_tick == 0)
            scheduler.set_module_status("qc", {})
            check("no-game-status", scheduler.ensure_module_state("qc").last_tick == 0)
            check("no-game-snapshot", scheduler.status_snapshot().tick == 0)
            check("no-game-write", scheduler.write_telemetry("no-game", {}, true) and encoded[#encoded].tick == 0)
            check("no-game-log", scheduler.log_snapshot().tick == 0 and encoded[#encoded].tick == 0)
            storage.ei.runtime_scheduler = nil
            _G.game = setmetatable({}, {__index = function() error("Disabled write read clock") end})
            local old_writes, old_encoded = writes, #encoded
            check("disabled-write-return", scheduler.write_telemetry("disabled", {}) == false)
            check("disabled-no-encoding-io", writes == old_writes and #encoded == old_encoded)
            check("disabled-root-initialized", storage.ei.runtime_scheduler.telemetry.enabled == false)
            storage.ei.runtime_scheduler = nil
            check("gate-still-initializing", scheduler.telemetry_enabled() == false and storage.ei.runtime_scheduler ~= nil)
        end)
        _G.game, _G.helpers, _G.log = saved_game, saved_helpers, saved_log
        storage.ei.runtime_scheduler = saved_state
        if not ok then error(failure) end
        helpers.write_file("runtime-contracts-scheduler.json", helpers.table_to_json({all_pass = true, checks = checks}), false)
        log("RUNTIME_CONTRACTS mode=scheduler COMPLETE checks=" .. #checks)
    end)
end
