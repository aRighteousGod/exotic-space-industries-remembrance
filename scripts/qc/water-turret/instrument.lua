-- Appended only to the isolated ESIR copy by invoke-water-turret-qc.ps1.
local water_profiler,water_calls,water_event_profiler,water_event_calls
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
local function profile_water_event(original)
    return function(event)
        if not water_event_profiler then return original(event) end
        local timer=game.create_profiler()
        original(event)
        timer.stop();water_event_profiler.add(timer);water_event_calls=water_event_calls+1
    end
end
if ei_water_turret.created_effect then
    SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS[ei_water_turret.created_effect]=profile_water_event(ei_water_turret.on_fire_created)
end
ei_water_turret.on_object_destroyed=profile_water_event(ei_water_turret.on_object_destroyed)
local water_updater=ei_water_turret.updater
ei_water_turret.updater=function(event)
    if not water_profiler then return water_updater(event) end
    local timer=game.create_profiler()
    water_updater(event)
    timer.stop();water_profiler.add(timer);water_calls=water_calls+1
end
remote.add_interface("ei-water-qc", {
    start_profile=function()
        water_profiler=game.create_profiler(true);water_calls=0
        water_event_profiler=game.create_profiler(true);water_event_calls=0
    end,
    profile=function()
        helpers.write_file("water-profile.txt",{"",water_profiler},false)
        helpers.write_file("water-events-profile.txt",{"",water_event_profiler},false)
        helpers.write_file("water-profile-calls.json",helpers.table_to_json{updater=water_calls,events=water_event_calls},false)
        return water_calls
    end,
    record=function(entity) return storage.ei.water_turret.records[entity.unit_number] end,
    sample=function(entity)
        local r=storage.ei.water_turret.records[entity.unit_number]
        return {fire=r.fire,power=r.power,phase=r.phase,aim_checkpoint=r.aim_checkpoint,
            next_pulse=r.next_pulse,search=r.search~=nil,available=r.available,generation=r.generation}
    end,
    state=function() return storage.ei.water_turret end,
    counters=function() return storage.ei.water_turret.counters end,
    impacts=function() return water_impacts end,
    preferences=function(entity,mode,weapon_fires)
        ei_water_turret.qc_set_preferences(storage.ei.water_turret.records[entity.unit_number],
            {mode=mode,weapon_fires=weapon_fires},game.tick)
    end,
    rebuild=function() ei_water_turret.rebuild(game.tick) end,
    repair=function() ei_water_turret.repair_runtime_state("qc",game.tick) end,
    imported=function(surface) ei_water_turret.on_surface_imported{surface_index=surface.index,tick=game.tick} end,
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
