-- Appended only to the isolated ESIR copy by invoke-water-turret-qc.ps1.
local water_profiler,water_calls
local water_impacts={}
for _,id in ipairs(ei_firefighting.effects) do
    local original=SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS[id]
    SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS[id]=function(event)
        local p=event.target_position
        local key=event.effect_id..":"..p.x..":"..p.y
        water_impacts[key]=(water_impacts[key] or 0)+1
        return original(event)
    end
end
local water_updater=ei_water_turret.updater
ei_water_turret.updater=function(event)
    if not water_profiler then return water_updater(event) end
    local timer=game.create_profiler()
    water_updater(event)
    timer.stop();water_profiler.add(timer);water_calls=water_calls+1
end
remote.add_interface("ei-water-qc", {
    start_profile=function() water_profiler=game.create_profiler(true);water_calls=0 end,
    profile=function() helpers.write_file("water-profile.txt",{"",water_profiler},false);return water_calls end,
    record=function(entity) return storage.ei.water_turret.records[entity.unit_number] end,
    state=function() return storage.ei.water_turret end,
    impacts=function() return water_impacts end,
    preferences=function(entity,mode,weapon_fires)
        ei_water_turret.qc_set_preferences(storage.ei.water_turret.records[entity.unit_number],
            {mode=mode,weapon_fires=weapon_fires},game.tick)
    end,
    rebuild=function() ei_water_turret.rebuild(game.tick) end,
    impact=function(position,effect,surface)
        ei_firefighting.on_script_trigger_effect{target_position=position,effect_id=effect,surface_index=surface}
    end,
    gui_open=function(event) ei_water_turret.on_gui_opened(event) end,
    gui_change=function(event) ei_water_turret.on_gui_changed(event) end,
    blueprint=function(player_index,entity)
        ei_water_turret.on_blueprint{player_index=player_index,mapping={get=function() return {[1]=entity} end}}
    end,
    paste=function(source,destination) ei_water_turret.on_settings_pasted{source=source,destination=destination,tick=game.tick} end,
})
