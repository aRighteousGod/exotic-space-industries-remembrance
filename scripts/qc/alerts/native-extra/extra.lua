local model={}
local function check(s,name,ok) assert(ok,name);s.checks[#s.checks+1]=name end
local function count(player,entity)
    local n=0;for _,types in pairs(player.get_alerts{entity=entity,type=defines.alert_type.custom})do for _,rows in pairs(types)do n=n+#rows end end;return n
end
function model.step(ctx,player,tick)
    storage.alert_extra=storage.alert_extra or {start=tick,checks={}}
    local s=storage.alert_extra;local t=tick-s.start;local gate=ctx.gate
    if t==0 then
        s.surface=game.surfaces.nauvis
        s.container=s.surface.create_entity{name='ei-gate-container',position={-30,0},force=player.force}
        gate.make_gate(s.container,{tick=tick});s.gate=gate.find_gate(s.container);s.unit=s.gate.unit_number
        local row=storage.ei.gate.gate[s.unit];row.manual_enabled=true;s.gate.energy=0
        player.mod_settings['ei-alert-gate-low-power']={value=true};player.mod_settings['ei-gate-notifications']={value=true}
        s.combinator=s.surface.create_entity{name='constant-combinator',position={-25,0},force=player.force}
        local section=s.combinator.get_or_create_control_behavior().get_section(1)
        section.set_slot(1,{value={type='virtual',name='signal-E',quality='normal'},min=-1})
        check(s,'native circuit wire connected',s.combinator.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(s.container.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
        player.mod_settings['ei-alert-fluid-rupture']={value=true};player.mod_settings['ei-insulated-pipe-notifications']={value=true}
    elseif t==10 then
        gate.refresh_gate_live_state(s.gate,{tick=tick})
        check(s,'negative circuit enable overrides manual On',storage.ei.gate.gate[s.unit].effective_enabled==false and count(player,s.container)==0)
        s.combinator.get_control_behavior().get_section(1).set_slot(1,{value={type='virtual',name='signal-E',quality='normal'},min=1})
    elseif t==30 then
        gate.refresh_gate_live_state(s.gate,{tick=tick})
        check(s,'positive circuit enable takes effect',storage.ei.gate.gate[s.unit].effective_enabled==true)
    elseif t==60 then
        check(s,'circuit-driven low power delivers native alert',count(player,s.container)==1)
        player.opened=s.container;gate.open_gui(player,{tick=tick})
        for _,candidate in pairs(game.players) do if candidate.index~=player.index then s.viewer=candidate;break end end
        if s.viewer then
            s.viewer.force=player.force;s.viewer.opened=s.container;gate.open_gui(s.viewer,{tick=tick})
        end
        local gui=gate.get_gui_elements(player);gui.alerts.state=false
        gate.on_gui_checked_state_changed{player_index=player.index,element=gui.alerts,tick=tick}
        check(s,'native console source Off clears alert',count(player,s.container)==0)
        if s.viewer then check(s,'second native console projection updates',gate.get_gui_elements(s.viewer).alerts.state==false) end
        local clone=s.container.clone{position={-60,0},surface=s.surface,force=player.force}
        local cloned_gate=gate.find_gate(clone)
        check(s,'cloned gate starts alerts On',cloned_gate and storage.ei.gate.gate[cloned_gate.unit_number].alerts_enabled==true)
        local original_force=player.force
        local foreign=game.create_force('ESIR alert fixture other force');player.force=foreign
        gui.alerts.state=true
        gate.on_gui_checked_state_changed{player_index=player.index,element=gui.alerts,tick=tick}
        check(s,'foreign force cannot mutate gate switch',storage.ei.gate.gate[s.unit].alerts_enabled==false)
        player.force=original_force
        if s.viewer then s.viewer.opened=nil end
        player.opened=nil
        ctx.gui.on_toggle_menu{player_index=player.index,tick=tick}
        local p=storage.ei.ecology_gui.players[player.index];p.pane.selected_tab_index=3
        ctx.gui.on_gui_change{player_index=player.index,element=p.pane,tick=tick}
        p.frame.location={x=30,y=40}
        p.checks.wildfire.state=false
        ctx.gui.on_gui_change{player_index=player.index,element=p.checks.wildfire,tick=tick}
        check(s,'ecology checkbox writes authoritative native setting',player.mod_settings['ei-ecology-alert-wildfire'].value==false and not ctx.ecology.preferences(player).wildfire)
        player.mod_settings['ei-ecology-alert-wildfire']={value=true}
        local event={player_index=player.index,setting='ei-ecology-alert-wildfire',setting_type='runtime-per-user',tick=tick}
        ctx.ecology.on_settings_changed(event);ctx.alerts.on_settings_changed(event);ctx.gui.on_settings_changed(event)
        check(s,'native settings refresh ecology checkbox',p.checks.wildfire.state==true)
        local old=p.frame;p.layout_version=3
        ctx.gui.on_gui_change{player_index=player.index,element=p.pane,tick=tick}
        p=storage.ei.ecology_gui.players[player.index]
        check(s,'layout migration preserves tab and position',not old.valid and p.layout_version==4 and p.tab==3 and p.frame.location.x==30 and p.frame.location.y==40)
        check(s,'category checkbox uses custom signal glyph',p.checks.wildfire.caption[2]:find('ei-alert-ecology-wildfire',1,true)~=nil)
    elseif t==100 then
        storage.ei.ecology_gui.players[player.index].frame.location={x=560,y=30}
        game.take_screenshot{player=player,path='alerts-ecology-preferences.png',show_gui=true,resolution={1280,720}}
    elseif t==140 then
        local machine=s.surface.create_entity{name='steel-chest',position={0,100},force=player.force}
        ctx.alerts.record_incident('operational','fluid-rupture',{entity=machine},tick)
        for _,r in ipairs(ctx.alerts.channel_state('operational').items) do if r.alert_id=='fluid-rupture' and r.source_id==machine.unit_number then s.incident=r end end
        s.first_x=s.incident.position.x;s.first_y=s.incident.position.y
        machine.destroy()
    elseif t==150 then
        ctx.alerts.record_incident('operational','fluid-rupture',{surface=s.surface,position={1,100},force=player.force},tick)
    elseif t==280 then
        check(s,'native coalescing replaces old count without duplicate target',s.incident and s.incident.count==2 and count(player,s.incident.anchor)==1)
    elseif t==300 then
        player.mod_settings['ei-alert-fluid-rupture']={value=false}
        ctx.alerts.on_settings_changed{player_index=player.index,setting_type='runtime-per-user',setting='ei-alert-fluid-rupture',tick=tick}
    elseif t==340 then
        check(s,'native retained incident removed after personal Off',count(player,s.incident.anchor)==0)
        player.mod_settings['ei-alert-fluid-rupture']={value=true}
        ctx.alerts.on_settings_changed{player_index=player.index,setting_type='runtime-per-user',setting='ei-alert-fluid-rupture',tick=tick}
    elseif t==500 then
        check(s,'native personal On alone does not replay',count(player,s.incident.anchor)==0)
        ctx.alerts.record_incident('operational','fluid-rupture',{surface=s.surface,position={1,100},force=player.force},tick)
    elseif t==530 then
        local visible=count(player,s.incident.anchor)
        check(s,'fresh native report after personal On delivers and coalesces (visible='..visible..', count='..s.incident.count..')',
            visible==1 and s.incident.count==3 and s.incident.position.x==s.first_x and s.incident.position.y==s.first_y)
    elseif t==560 then
        return {complete=true,all_pass=true,count=#s.checks,checks=s.checks,engine=script.active_mods.base,
            second_viewer=s.viewer~=nil,scope='Native circuit enable transitions, clone defaults, force rejection, ecology GUI/native-setting synchronization, layout preservation and native coalescing; not connected multiplayer.'}
    end
end
return model
