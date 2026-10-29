local case = require("case")
local native = case.phase=="runtime" and require("native")
local transitions = (case.phase=="normal" or case.phase=="player" or case.phase=="donor" or case.phase=="eject"
    or case.phase=="removed" or case.phase=="reload" or case.phase=="relax" or case.phase=="legacy" or case.phase=="duplicates")
    and require("transitions")
script.on_init(function()
    storage.started = game.tick
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end
    helpers.write_file("quality-optional-init.json", helpers.table_to_json{passed=true,case=case.id,
        quality=script.active_mods.quality or false,space_age=script.active_mods["space-age"],recycler=script.active_mods.recycler}, false)
end)
if native then script.on_event(defines.events.on_tick,native.tick) end
if transitions then
    script.on_event(defines.events.on_tick,transitions.tick)
    script.on_configuration_changed(transitions.configuration)
    script.on_event(defines.events.on_entity_damaged,function(event)
        remote.call("esir-quality-removal-qc","normal_damage",event)
    end)
end
