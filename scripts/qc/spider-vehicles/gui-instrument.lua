-- Appended only to the isolated ESIR control copy by the QC runner. Factorio does
-- not allow scripts to raise GUI events; exercise the same private handlers here.
local qc_spider_profiler,qc_spider_profile_calls
local qc_spider_updater=ei_spider_vehicles.updater
ei_spider_vehicles.updater=function(event)
    if not qc_spider_profiler then return qc_spider_updater(event) end
    local timer=game.create_profiler()
    qc_spider_updater(event)
    timer.stop();qc_spider_profiler.add(timer)
    qc_spider_profile_calls=qc_spider_profile_calls+1
end
remote.add_interface("esir-spider-qc-controls",{
    has_item_preference=function(number) return storage.ei.spider_vehicles.items[number]~=nil end,
    start_profile=function()
        qc_spider_profiler=game.create_profiler(true);qc_spider_profile_calls=0
        if ei_spider_vehicles.qc_start_search_profile then ei_spider_vehicles.qc_start_search_profile() end
    end,
    profile=function()
        helpers.write_file("spider-selector-profile.txt",{"",qc_spider_profiler},false)
        if ei_spider_vehicles.qc_write_search_profile then ei_spider_vehicles.qc_write_search_profile() end
        return {file="spider-selector-profile.txt",calls=qc_spider_profile_calls}
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
        if record.selection then
            result.turn=record.selection.turn
            for index,slot in pairs(record.selection.slots or {}) do
                result.slots[index]={group=slot.group,minimum=slot.minimum,maximum=slot.maximum,range_mode=slot.range_mode,target=slot.target and slot.target.valid and slot.target.position}
            end
        end
        return result
    end,
})
