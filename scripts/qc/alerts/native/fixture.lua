local model={}
local persistence=require('__zzz-esir-alerts-qc__/persistence')
local function check(s,name,ok) assert(ok,name);s.checks[#s.checks+1]=name end
local function native_count(player,entity)
    local count=0
    for _,types in pairs(player.get_alerts{type=defines.alert_type.custom,entity=entity}) do
        for _,rows in pairs(types) do count=count+#rows end
    end
    return count
end
local function setting(ctx,player,name,value,tick)
    player.mod_settings[name]={value=value}
    local e={player_index=player.index,setting=name,setting_type="runtime-per-user",tick=tick}
    ctx.ecology.on_settings_changed(e);ctx.alerts.on_settings_changed(e)
end
function model.step(ctx,player,tick,first)
    storage.alert_fixture=storage.alert_fixture or {checks={},start=tick}
    local s=storage.alert_fixture;local t=tick-s.start
    local alerts,gate=ctx.alerts,ctx.gate
    if s.phase=='saved-legacy' then
        if first then persistence.resume(ctx,player,tick);return end
        if tick-s.save_tick<120 then return end
        return {complete=true,all_pass=true,count=#s.checks,checks=s.checks,engine=script.active_mods.base,
            scope='Native connected settings, gate GUI/power/source mute, destructive incidents, 17 terrain receipt categories; migration save prepared.'}
    elseif s.phase=='verify-retirement' then return persistence.finish(ctx,tick) end
    if t==0 then
        s.surface=game.surfaces.nauvis
        s.surface.request_to_generate_chunks({0,0},2);s.surface.force_generate_chunk_requests()
        player.teleport({0,0},s.surface)
        for _,entry in ipairs(ctx.catalog.entries) do
            check(s,"native setting and icon "..entry.id,player.mod_settings[entry.setting_name]~=nil and prototypes.virtual_signal[entry.icon_signal]~=nil)
            setting(ctx,player,entry.setting_name,false,tick)
            check(s,"native false "..entry.id,not alerts.player_allows(player,entry.id))
            if entry.master then setting(ctx,player,entry.master,true,tick) end
            setting(ctx,player,entry.setting_name,true,tick)
            check(s,"native true "..entry.id,alerts.player_allows(player,entry.id))
        end
        s.container=s.surface.create_entity{name="ei-gate-container",position={10,0},force=player.force}
        gate.make_gate(s.container,{tick=tick})
        s.gate=gate.find_gate(s.container);s.unit=s.gate.unit_number
        local row=storage.ei.gate.gate[s.unit];row.manual_enabled=true;s.gate.energy=0
        gate.refresh_gate_live_state(s.gate,{tick=tick})
        player.opened=s.container;gate.open_gui(player,{tick=tick})
        check(s,"gate starts alerts On",row.alerts_enabled==true and gate.get_gui_elements(player).alerts.state)
    elseif t==30 then
        check(s,"gate targets visible container",native_count(player,s.container)==1)
        game.take_screenshot{player=player,path="alerts-gate-on.png",show_gui=true,resolution={1280,720}}
        local gui=gate.get_gui_elements(player);gui.alerts.state=false
        gate.on_gui_checked_state_changed{player_index=player.index,element=gui.alerts,tick=tick}
        check(s,"gate mute removes immediately",not storage.ei.gate.gate[s.unit].alerts_enabled and native_count(player,s.container)==0)
        gate.rebuild_runtime_state("alerts-fixture",{tick=tick})
        check(s,"gate Off survives rebuild",storage.ei.gate.gate[s.unit].alerts_enabled==false)
        gate.open_gui(player,{tick=tick});gui=gate.get_gui_elements(player);gui.alerts.state=true
        gate.on_gui_checked_state_changed{player_index=player.index,element=gui.alerts,tick=tick}
    elseif t==60 then
        check(s,"gate unmute reevaluates",native_count(player,s.container)==1)
        s.gate.energy=100e9;gate.refresh_gate_live_state(s.gate,{tick=tick})
        check(s,"100 GJ clears warning",native_count(player,s.container)==0)
        s.gate.energy=0;local row=storage.ei.gate.gate[s.unit];row.manual_enabled=false
        gate.refresh_gate_live_state(s.gate,{tick=tick})
        player.opened=nil
        s.incidents={}
        for i,entry in ipairs(ctx.catalog.entries) do
            if entry.channel=="operational" and entry.id~="gate-low-power" then
                local machine=s.surface.create_entity{name="steel-chest",position={i*3,20},force=player.force}
                alerts.record_incident("operational",entry.id,{entity=machine,message=entry.localised_name},tick)
                machine.destroy()
            end
        end
    elseif t==120 then
        for _,r in ipairs(alerts.channel_state("operational").items) do
            if r.mode=="retained" then
                check(s,"destroyed-source navigation "..r.alert_id,r.anchor and r.anchor.valid and native_count(player,r.anchor)==1)
                s.incidents[#s.incidents+1]=r
            end
        end
        check(s,"all nine finite operational types delivered",#s.incidents==9)
        for _,r in ipairs(s.incidents) do setting(ctx,player,ctx.catalog.by_id[r.alert_id].setting_name,false,tick) end
    elseif t==160 then
        for _,r in ipairs(s.incidents) do
            check(s,"visible type mute "..r.alert_id,native_count(player,r.anchor)==0)
            setting(ctx,player,ctx.catalog.by_id[r.alert_id].setting_name,true,tick)
        end
    elseif t==300 then
        for _,r in ipairs(s.incidents) do check(s,"no type-enable replay "..r.alert_id,native_count(player,r.anchor)==0) end
        check(s,"operational work cap",alerts.channel_state("operational").last_service.steps<=32)
        s.ecology_index=0;s.ecology_next=tick
    end
    if s.ecology_next and tick>=s.ecology_next then
        local previous=s.ecology_record
        if previous then
            check(s,"ecology native delivery "..previous.category,previous.anchor and previous.anchor.valid and native_count(player,previous.anchor)==1)
            previous.cancelled=true
        end
        s.ecology_index=s.ecology_index+1
        local category=ctx.catalog.ecology_categories[s.ecology_index]
        if category then
            local owner=storage.ei.terrain_evolution.surfaces[s.surface.index]
            local before=alerts.channel_state("ecology").next_id
            ctx.ecology.set_preference(player,"allow-unrevealed",true)
            check(s,"ecology receipt admitted "..category,ctx.ecology.record_effect{category=category,surface=s.surface,
                owner=owner,position={0,0},tick=tick,count=1})
            s.ecology_record=alerts.channel_state("ecology").by_id[before+1]
            check(s,"terrain reference retained "..category,s.ecology_record.chunk_token.references>0)
            s.ecology_next=tick+160
        else
            s.ecology_next=nil;s.finish_tick=tick+180
        end
    end
    if s.finish_tick and tick>=s.finish_tick then
        check(s,"ecology markers retired",alerts.channel_state("ecology").anchors==0)
        check(s,"terrain receipt released",s.ecology_record.chunk_token==nil)
        local e=alerts.channel_state("ecology").last_service
        check(s,"independent ecology caps",e.recipient_checks<=2 and e.additions<=1 and e.creations<=1)
        persistence.prepare(ctx,player,tick)
    end
end
return model
