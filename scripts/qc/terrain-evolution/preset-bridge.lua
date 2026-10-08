-- Appended only to disposable ESIR staging. Settings writes belong to ESIR;
-- invoke the registered player-change receiver explicitly after a scripted write.
local preset_config=require("lib/terrain-evolution-config")
remote.add_interface("ei-terrain-preset-qc",{
    select=function(name,custom)
        assert(script.active_mods["zzz-esir-terrain-qc"])
        settings.global["ei-terrain-performance"]={value=name}
        for key,value in pairs(custom or {}) do
            local row=assert(preset_config.by_key[key])
            settings.global[row.setting_name]={value=value}
        end
        local handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
        handler{name=defines.events.on_runtime_mod_setting_changed,tick=game.tick,
            setting="ei-terrain-performance",setting_type="runtime-global"}
        local root=storage.ei.terrain_evolution
        return {config=root.config,pass=root.pass,samples=root.counters.samples or 0}
    end,
    inspect=function()
        local root=storage.ei.terrain_evolution
        return {config=root.config,pass=root.pass,last=root.last_service,samples=root.counters.samples or 0}
    end,
})
