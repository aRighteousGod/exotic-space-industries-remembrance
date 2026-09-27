-- Appended only to the isolated ESIR control copy by the QC runner. Factorio does
-- not allow scripts to raise GUI events; exercise the same private handlers here.
local qc_spider_profiler,qc_spider_profile_calls
local qc_spider_effect_calls=0
local qc_spider_dispatch={}
local function qc_count(key) qc_spider_dispatch[key]=(qc_spider_dispatch[key] or 0)+1 end
for key,module in pairs({spider_damage=ei_spider_vehicles,tesla_damage=ei_teslas_legacy,tank_damage=ei_emerald_apocalypse_hover_tank,wall_damage=ei_hemocrystal_wall}) do
    local handler=module.on_entity_damaged
    module.on_entity_damaged=function(event) qc_count(key);return handler(event) end
end
-- Preserve the production engine filters while observing actual entry into Lua.
for key,id in pairs({damage_dispatch=defines.events.on_entity_damaged,effect_dispatch=defines.events.on_script_trigger_effect}) do
    local handler=script.get_event_handler(id)
    local filters=key=="damage_dispatch" and script.get_event_filter(id) or nil
    script.on_event(id,function(event) qc_count(key);return handler(event) end,filters)
end
local qc_spider_predicate=ei_spider_vehicles.has_tick_work
ei_spider_vehicles.has_tick_work=function(event)
    qc_count("predicates")
    if not qc_spider_profiler then return qc_spider_predicate(event) end
    local timer=game.create_profiler()
    local result=qc_spider_predicate(event)
    timer.stop();qc_spider_profiler.add(timer)
    return result
end
local qc_spider_effect=ei_spider_vehicles.on_script_trigger_effect
ei_spider_vehicles.on_script_trigger_effect=function(event)
    qc_count("spider_effects")
    if not qc_spider_profiler then return qc_spider_effect(event) end
    local timer=game.create_profiler()
    qc_spider_effect(event)
    timer.stop();qc_spider_profiler.add(timer);qc_spider_effect_calls=qc_spider_effect_calls+1
end
local qc_spider_updater=ei_spider_vehicles.updater
ei_spider_vehicles.updater=function(event)
    qc_count("updaters")
    if not qc_spider_profiler then return qc_spider_updater(event) end
    local timer=game.create_profiler()
    qc_spider_updater(event)
    timer.stop();qc_spider_profiler.add(timer)
    qc_spider_profile_calls=qc_spider_profile_calls+1
end
remote.add_interface("esir-spider-qc-controls",{
    vehicle=function(id) return storage.ei.spider_vehicles.vehicles[id].entity end,
    dispatch_counts=function(reset)
        local counts=qc_spider_dispatch
        if reset then qc_spider_dispatch={} end
        return counts
    end,
    scheduled_work=function()
        local root=storage.ei.spider_vehicles
        return {retries=table.deepcopy(root.retries),pulses=table.deepcopy(root.pulses)}
    end,
    has_item_preference=function(number) return storage.ei.spider_vehicles.items[number]~=nil end,
    start_profile=function()
        qc_spider_profiler=game.create_profiler(true);qc_spider_profile_calls=0;qc_spider_effect_calls=0;qc_spider_dispatch={}
        if ei_spider_vehicles.qc_start_search_profile then ei_spider_vehicles.qc_start_search_profile() end
    end,
    profile=function()
        helpers.write_file("spider-selector-profile.txt",{"",qc_spider_profiler},false)
        if ei_spider_vehicles.qc_write_search_profile then ei_spider_vehicles.qc_write_search_profile() end
        return {file="spider-selector-profile.txt",calls=qc_spider_profile_calls,effect_calls=qc_spider_effect_calls,dispatch=qc_spider_dispatch}
    end,
    open=function(event) ei_spider_vehicles.on_gui_opened(event) end,
    change=function(event)
        local tags=event.element.tags
        local record=storage.ei.spider_vehicles.vehicles[tags.vehicle_id]
        local player=game.get_player(event.player_index)
        local result={tags=tags,record=record~=nil,opened_matches=record and player.opened==record.entity,force_matches=record and player.force==record.entity.force}
        ei_spider_vehicles.on_gui_changed(event)
        result.after=record and ei_spider_vehicles.get_weapon_controls(record.entity)
        return result
    end,
    close=function(event) ei_spider_vehicles.on_gui_closed(event) end,
    snapshot=function(entity)
        local id=ei_spider_vehicles.get_vehicle_id(entity)
        local record=storage.ei.spider_vehicles.vehicles[id]
        local result={name=entity.name,selected=entity.selected_gun_index,position=entity.position,controls=ei_spider_vehicles.get_weapon_controls(entity),
            cargo_size=#entity.get_inventory(defines.inventory.spider_trunk),cargo=entity.get_inventory(defines.inventory.spider_trunk).get_contents(),slots={}}
        if record.overkill_state then
            result.overkill={shots={},targets={},blocked=table.deepcopy(record.overkill_state.blocked)}
            for id,shot in pairs(record.overkill_state.shots) do
                result.overkill.shots[#result.overkill.shots+1]={id=id,damage=shot.damage,payload=shot.payload,earliest=shot.earliest}
            end
            for _,target in pairs(record.overkill_state.targets) do
                result.overkill.targets[#result.overkill.targets+1]={damage=target.damage,health=target.entity.valid and target.entity.health}
            end
        end
        if record.selection then
            result.turn=record.selection.turn
            for index,slot in pairs(record.selection.slots or {}) do
                result.slots[index]={group=slot.group,minimum=slot.minimum,maximum=slot.maximum,range_mode=slot.range_mode,target=slot.target and slot.target.valid and slot.target.position}
            end
        end
        return result
    end,
})
