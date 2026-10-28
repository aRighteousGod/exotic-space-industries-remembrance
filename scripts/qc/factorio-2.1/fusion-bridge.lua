-- Private owner access only; no shipping remote interface or test hooks.
local function find_widget(root,wanted)
    if not (root and root.valid) then return end
    local matches=true
    for key,value in pairs(wanted) do if root.tags[key]~=value then matches=false;break end end
    if matches then return root end
    for _,child in pairs(root.children) do
        local found=find_widget(child,wanted)
        if found then return found end
    end
end
remote.add_interface("esir-fusion-qc",{
    preference=function(index,name,value) game.get_player(index).mod_settings[name]={value=value} end,
    register=function(entity,tick) ei_fusion_reactor.on_built_entity(entity,tick) end,
    select=function(entity,selection,source,tick)
        local entry=storage.ei.fusion_reactor.reactors_by_unit[entity.unit_number]
        entry.manual_selection=selection
        entry.control_source=source or "manual"
        ei_fusion_reactor.update(1000,{tick=tick})
    end,
    service=function(tick) ei_fusion_reactor.update(1000,{tick=tick}) end,
    record=function(entity)
        local entry=storage.ei.fusion_reactor.reactors_by_unit[entity.unit_number]
        return {manual_selection=entry.manual_selection,effective_selection=entry.effective_selection,
            control_source=entry.control_source,wire_proxy=entry.wire_proxy,
            wire_proxy_connected=entry.wire_proxy_connected,wire_proxy_wired=entry.wire_proxy_wired,
            signal_cache=entry.signal_cache}
    end,
    repair=function(tick) ei_fusion_reactor.repair_runtime_state("qc",tick) end,
    paste=function(source,destination,tick)
        ei_fusion_reactor.on_entity_settings_pasted{source=source,destination=destination,tick=tick}
    end,
    configuration=function() ei_fusion_reactor.on_configuration_changed{} end,
    collector=function(entity,tick) ei_neutron_collector.on_built_entity(entity,{tick=tick}) end,
    collector_state=function(entity)
        local entry=storage.ei.neutron_runtime.collectors_by_unit[entity.unit_number]
        return {source=entry.source_unit,efficiency=entry.last_efficiency,disabled=entity.disabled_by_script,
            recipe=entity.get_recipe() and entity.get_recipe().name}
    end,
    status=function()
        local root=storage.ei.fusion_reactor
        local records=0
        for _ in pairs(root.reactors_by_unit) do records=records+1 end
        return {records=records,pending=ei_fusion_reactor.get_pending_work_count(),units=root.reactor_units}
    end,
    gui=function(index,action,value,tick)
        local player=game.get_player(index)
        local root=player.gui.relative["ei-fusion-reactor-console"] or player.gui.screen["ei-fusion-reactor-console"]
        if action=="open" then player.opened=value;ei_fusion_reactor.open_gui(player)
        elseif action=="close" then player.opened=nil
        elseif action=="reconcile" then ei_fusion_reactor.reconcile_gui_player(index)
        elseif action=="scroll-options" then
            root["body-scroll"].scroll_to_bottom()
        elseif action=="slider" then
            local element=root["body-scroll"]["main-container"]["control-flow"][value.name]
            element.slider_value=value.value
            script.get_event_handler(defines.events.on_gui_value_changed){player_index=index,element=element,tick=tick}
        elseif action=="click" then
            local element=assert(find_widget(root,value),"Fusion GUI action absent")
            script.get_event_handler(defines.events.on_gui_click){player_index=index,element=element,tick=tick,button=defines.mouse_button_type.left}
        end
        root=player.gui.relative["ei-fusion-reactor-console"] or player.gui.screen["ei-fusion-reactor-console"]
        local main=root and root["body-scroll"] and root["body-scroll"]["main-container"]
        local controls=main and main["control-flow"]
        local options={}
        if main then
            for _,flow in pairs(main["options-flow"].children) do
                for _,button in pairs(flow.children) do
                    options[#options+1]={visible=button.visible,enabled=button.enabled,tags=button.tags,
                        minimum=button.style.minimal_height,maximum=button.style.maximal_height,
                        flow_visible=flow.visible}
                end
            end
        end
        return {valid=root and root.valid or false,unit=storage.ei.fusion_reactor.open_by_player[index],
            options=options,gui_mode=root and root.tags.gui_mode,location=root and root.location,
            temperature=controls and controls["temperature-slider"].slider_value,
            injection=controls and controls["injection-rate-slider"].slider_value}
    end,
})
