local model={}
local function check(s,name,value) assert(value,name);s.checks[#s.checks+1]=name end
local function screenshot(player,name,gui)
    game.take_screenshot{player=player,path=name..'.png',resolution={1280,720},show_gui=gui~=false}
end
local function count(player,entity)
    local n=0
    for _,types in pairs(player.get_alerts{entity=entity,type=defines.alert_type.custom}) do
        for _,rows in pairs(types) do n=n+#rows end
    end
    return n
end
function model.step(ctx,player,tick)
    storage.icon_visual=storage.icon_visual or {start=tick,checks={},ecology={},sources={},owned={}}
    local s=storage.icon_visual;local t=tick-s.start
    if t==0 then
        s.surface=game.surfaces.nauvis
        s.surface.request_to_generate_chunks({0,0},2);s.surface.force_generate_chunk_requests()
        player.teleport({0,0},s.surface)
        if player.controller_type==defines.controllers.editor then player.toggle_map_editor() end
        player.game_view_settings.show_alert_gui=true;player.enable_alert(defines.alert_type.custom)
        s.scale=player.display_scale;s.resolution=player.display_resolution
        check(s,'viewport 1280x720',s.resolution.width==1280 and s.resolution.height==720)
        check(s,'expected default or enlarged scale',math.abs(s.scale-1)<0.01 or math.abs(s.scale-1.5)<0.01)
        for i,entry in ipairs(ctx.catalog.entries) do
            check(s,'native prototype '..entry.id,prototypes.virtual_signal[entry.icon_signal]~=nil)
            player.mod_settings[entry.setting_name]={value=true}
            if entry.master then player.mod_settings[entry.master]={value=true} end
        end
        if settings.startup['ei-terrain-evolution-enabled'].value then
            ctx.ecology.set_preference(player,'allow-unrevealed',true)
        end
    elseif t==20 then
        -- Let native preference events settle before admitting finite incidents.
        for i,entry in ipairs(ctx.catalog.entries) do
            if entry.channel=='operational' then
                local e=s.surface.create_entity{name='steel-chest',position={i*2,15},force=player.force}
                s.sources[#s.sources+1]=e.unit_number
                s.owned[e.unit_number]=true
                if entry.id=='gate-low-power' then
                    ctx.alerts.set_condition('operational','icon-qc-gate',entry.id,true,{entity=e,source_id=e.unit_number,message=entry.localised_name},tick)
                else ctx.alerts.record_incident('operational',entry.id,{entity=e,message=entry.localised_name},tick);e.destroy() end
            end
        end
    elseif t==100 then
        local delivered=0
        for _,r in ipairs(ctx.alerts.channel_state('operational').items) do
            if s.owned[r.source_id] then
                check(s,'native delivery '..r.alert_id,count(player,r.entity or r.anchor)==1)
                delivered=delivered+1
            end
        end
        check(s,'all ten operational icons delivered',delivered==10)
        screenshot(player,'native-operational-0')
        screenshot(player,'terrain-background',false)
    elseif t==115 then screenshot(player,'native-operational-15')
    elseif t==130 then screenshot(player,'native-operational-30')
    elseif t==150 then
        for _,source in ipairs(s.sources) do ctx.alerts.clear_source('operational',source,tick) end
    end
    if t>=200 and not s.ecology_done then
        if not settings.startup['ei-terrain-evolution-enabled'].value then
            s.ecology_done=true;s.gui_tick=tick+32
        else
            s.batch=s.batch or 0;s.ecology_next=s.ecology_next or tick
            if #s.ecology>0 then
                if not s.visible_tick then
                    local visible=true
                    for _,r in ipairs(s.ecology) do
                        if not r.anchor or count(player,r.anchor)~=1 then visible=false end
                    end
                    if visible then
                        s.visible_tick=tick
                        for _,r in ipairs(s.ecology) do check(s,'native delivery '..r.alert_id,true) end
                        screenshot(player,'native-ecology-'..s.batch..'-0')
                    else check(s,'bounded native ecology delivery wait',tick-s.admitted_tick<600) end
                else
                    local phase=tick-s.visible_tick
                    if phase==15 or phase==30 then screenshot(player,'native-ecology-'..s.batch..'-'..phase)
                    elseif phase==60 then
                        for _,r in ipairs(s.ecology) do r.cancelled=true end
                        s.ecology={};s.visible_tick=nil;s.batch=s.batch+1;s.ecology_next=tick+192
                    end
                end
            elseif tick>=s.ecology_next then
                if s.batch*4>=#ctx.catalog.ecology_categories then
                    s.ecology_done=true;s.gui_tick=tick+32
                else
                    s.admitted_tick=tick
                    for i=s.batch*4+1,math.min(s.batch*4+4,#ctx.catalog.ecology_categories) do
                        local category=ctx.catalog.ecology_categories[i]
                        local state=ctx.alerts.channel_state('ecology');local before=state.next_id
                        local owner=storage.ei.terrain_evolution.surfaces[s.surface.index]
                        check(s,'receipt '..category,ctx.ecology.record_effect{category=category,surface=s.surface,owner=owner,
                            position={0,0},tick=tick,count=1})
                        s.ecology[#s.ecology+1]=state.by_id[before+1]
                    end
                end
            end
        end
    end
    local gui_phase=s.gui_tick and tick-s.gui_tick or -1
    if gui_phase==0 then
        if settings.startup['ei-terrain-evolution-enabled'].value then
            ctx.gui.on_toggle_menu{player_index=player.index,tick=tick}
            local p=storage.ei.ecology_gui.players[player.index]
            check(s,'ecology frame opened',p and p.frame and p.frame.valid)
            p.pane.selected_tab_index=3;ctx.gui.on_gui_change{player_index=player.index,element=p.pane,tick=tick}
            p.frame.location={x=16,y=12}
        else
            local frame=player.gui.screen.add{type='frame',name='icon_catalog_fixture',direction='vertical',caption='ESIR alert icons: ecology disabled'}
            frame.location={x=16,y=12};local grid=frame.add{type='table',column_count=3}
            for _,entry in ipairs(ctx.catalog.entries) do
                local flow=grid.add{type='flow',direction='horizontal'}
                local icon=flow.add{type='sprite',sprite='virtual-signal/'..entry.icon_signal}
                icon.style.size=32;flow.add{type='label',caption=entry.id}
            end
        end
    elseif gui_phase==30 then screenshot(player,'ecology-preferences-top')
    elseif gui_phase==60 and settings.startup['ei-terrain-evolution-enabled'].value then
        local p=storage.ei.ecology_gui.players[player.index];p.bodies[3].scroll_to_element(p.checks.blood,'top-third')
    elseif gui_phase==90 then screenshot(player,'ecology-preferences-bottom')
    elseif gui_phase==140 then
        return {complete=true,all_pass=true,checks=s.checks,count=#s.checks,scale=s.scale,
            engine=script.active_mods.base,ecology=settings.startup['ei-terrain-evolution-enabled'].value,
            scope='Native all-27 signals, operational and ecology alerts, checkbox presentation; visual review separate.'}
    end
end
return model
