-- Native fixture dispatcher. Never shipped by the gameplay pack.
local support = require("support")
local config = support.config
local suite = require("native-suite") or {}
local previous = script.get_event_handler(defines.events.on_tick)
local start_tick, done
local attested

-- Native prototypes attest defaults independently of mutable gameplay settings.
-- The host accepts only first creation of a missing settings file, with exactly
-- this inventory and values; subsequent file changes remain integrity failures.
local function attest_defaults()
    local defaults={startup={},["runtime-global"]={},["runtime-per-user"]={}}
    for name,prototype in pairs(prototypes.mod_setting) do
        defaults[prototype.setting_type][name]=prototype.default_value
    end
    helpers.write_file("native-setting-defaults.json",helpers.table_to_json{
        run_id=config.run_id,suite=config.suite,profile=config.profile,phase=config.phase,
        input_hash=config.input_hash,engine_version=script.active_mods.base,defaults=defaults},false)
    attested=true
end

script.on_init(function()
    attest_defaults()
    if suite.init then suite.init() end
    -- A fresh ESIR graphical save otherwise opens the freeplay welcome dialog
    -- before ticks advance. The private fixture does not test welcome copy.
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end
end)

local function finish(result)
    local checks = result.checks or {}
    local passed = #checks > 0
    for name, enabled in pairs(config.expected_mods or {}) do
        checks[#checks+1] = {name="effective-mod-"..name,passed=(script.active_mods[name]~=nil)==enabled}
    end
    for _, check in ipairs(checks) do passed = passed and check.passed == true end
    local state = storage.esir_native_driver or {configuration_changes=0}
    if config.phase == "reload" then
        checks[#checks+1] = {name="ordinary-reload-no-configuration-change",passed=state.configuration_changes == 0}
        passed = passed and state.configuration_changes == 0
    elseif config.phase == "configuration" then
        checks[#checks+1] = {name="configuration-change-observed",passed=state.configuration_changes > 0}
        passed = passed and state.configuration_changes > 0
    end
    local report = {run_id=config.run_id,suite=config.suite,profile=config.profile,phase=config.phase,
        input_hash=config.input_hash,engine_version=script.active_mods.base,complete=true,passed=passed,
        cases=config.cases,checks=checks,metrics=result.metrics,tick=game.tick,player_count=#game.players,connected_players=#game.connected_players}
    helpers.write_file("native-test-"..config.phase..".json",helpers.table_to_json(report),false)
    done = true
    if config.checkpoint then
        assert(passed, "Checkpoint assertions failed")
        state.configuration_changes = 0
        storage.esir_native_driver = state
        if game.is_multiplayer() then game.server_save("native-checkpoint")
        else game.auto_save("native-checkpoint") end
    else
        script.finish_test(passed)
    end
end

-- This fixture owns its lifecycle observer. Suite lifecycle handlers can expose
-- a configuration callback; gameplay handlers remain in the gameplay mod.
script.on_configuration_changed(function(event)
    storage.esir_native_driver = storage.esir_native_driver or {configuration_changes=0}
    storage.esir_native_driver.configuration_changes = storage.esir_native_driver.configuration_changes + 1
    if suite.configuration_changed then suite.configuration_changed(event) end
end)
script.on_event(defines.events.on_tick,function(event)
    if done then return end
    start_tick = start_tick or event.tick
    local ok, result = pcall(function()
        if not attested then attest_defaults() end
        if previous then previous(event) end
        if suite.poll then return suite.poll(event.tick) end
        if remote.interfaces["esir-native-tests"] then
            if remote.interfaces["esir-native-tests"].step then return remote.call("esir-native-tests","step",event.tick) end
            return remote.call("esir-native-tests","poll")
        end
        return support.poll()
    end)
    if not ok then finish{checks={{name="fixture-exception",passed=false,detail=tostring(result)}}}
    elseif result and result.complete then finish(result)
    elseif event.tick-start_tick >= config.deadline_ticks then
        finish{checks={{name="lua-deadline",passed=false,detail="Required assertions did not complete"}}}
    end
end)
