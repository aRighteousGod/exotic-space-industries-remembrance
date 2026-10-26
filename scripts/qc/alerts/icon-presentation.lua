-- Actual generic handler with mocked native storage; engine save/provider removal is tested separately.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local catalog=require('lib/alert-catalog')
local mock=dofile('scripts/qc/alerts/icon-mock.lua')
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function setup()
    package.loaded['lib/lib']={get_valid_entity=function(e)return e and e.valid and e or nil end}
    package.loaded['lib/runtime-scheduler']={bump_counter=function()end}
    package.loaded['lib/alert-icon-sets']=nil;package.loaded['lib/alerts']=nil
    storage={};defines={alert_type={custom=1}};local sets=mock.install(catalog)
    local force={valid=true,index=1};local surface={valid=true,index=1,name='test'}
    local created,retained,released=0,0,0
    surface.create_entity=function(args)
        created=created+1;local e={valid=true,surface=surface,position=args.position}
        e.destroy=function()e.valid=false end;return e
    end
    local players={};game={tick=0,players=players,connected_players=players,get_player=function(i)return players[i]end}
    for i=1,2 do
        local p={index=i,valid=true,connected=true,force=force,surface=surface,mod_settings={}}
        for _,def in ipairs(catalog.entries)do
            p.mod_settings[def.setting_name]={value=true};if def.master then p.mod_settings[def.master]={value=true}end
        end
        p.mod_settings[sets.setting_name]={value=i==1 and 'rendered' or 'svg'}
        mock.player(p);players[i]=p
    end
    local m=require('lib/alerts')
    m.register_channel('ecology',{interval=32,steps=2,additions=1,creations=1,duration=3600,coalesce_ticks=600,
        once=true,max_incidents=64,max_anchors=32,max_per_player=4},{
        valid=function(r)return not r.invalid end,eligible=function()return true end,
        retain=function()retained=retained+1 end,release=function()released=released+1 end,
        message=function(r)return {'ecology',r.alert_id,r.count}end})
    m.initialize(0)
    local e={valid=true,unit_number=42,force=force,surface=surface,position={x=0,y=0}}
    local function service(first,last)
        for tick=first,last do
            game.tick=tick;m.updater{tick=tick}
            local a=m.channel_state('operational').last_service
            if a then check(a.steps<=32,'operational bound')end
            local b=m.channel_state('ecology').last_service
            if b then check(b.recipient_checks<=2 and b.additions<=1 and b.creations<=1,'ecology independent bounds')end
        end
    end
    return m,players,e,service,sets,function()return created,retained,released end
end
do
    local m,p,e,service,sets=setup()
    m.set_condition('operational',42,'gate-low-power',true,{entity=e,message={'gate'}},0);service(0,3)
    local state=m.channel_state('operational');local record=state.items[1];local epoch=state.roster_epoch
    check(p[1]._native[1].icon.name==sets.signal_name('rendered',record.alert_id),'player1 rendered')
    check(p[2]._native[1].icon.name==sets.signal_name('svg',record.alert_id),'player2 independent svg')
    local delivered=state.delivered;local original_tick=record.delivered[1]
    local tick=4
    for _,from in ipairs(sets.builtin_ids)do
        m.set_icon_set(p[1],from,tick);service(tick,tick+2);tick=tick+3
        for _,to in ipairs(sets.builtin_ids)do
            m.set_icon_set(p[1],to,tick);service(tick,tick+2);tick=tick+3
            check(#p[1]._native==1 and p[1]._native[1].icon.name==sets.signal_name(to,record.alert_id),'all personal transitions exact replacement')
        end
    end
    check(state.roster_epoch==epoch and record.delivered[1]==original_tick and state.delivered==delivered,'cosmetics preserve epochs delivery history and counts')
    check(#p[2]._native==1 and p[2]._native[1].icon.name==sets.signal_name('svg',record.alert_id),'other player unaffected')
    m.set_icon_set(p[1],'original',tick);m.set_icon_set(p[1],'svg',tick);m.set_icon_set(p[1],'rendered',tick)
    service(tick,tick+3);check(#p[1]._native==1,'rapid choices coalesce to latest')
    p[1].mod_settings['ei-alert-gate-low-power']={value=false}
    m.set_icon_set(p[1],'original',tick+4);service(tick+4,tick+8)
    check(#p[1]._native==0,'Off beats pending cosmetic change')
end
do
    local m,p,e,service,sets,counters=setup()
    m.record_incident('ecology','ecology-wildfire',{surface=e.surface,position=e.position},0);service(0,128)
    local state=m.channel_state('ecology');local r=state.items[1]
    local expiry,delivered,first=r.expires,state.delivered,r.delivered[1]
    p[2]._native={};m.set_icon_set(p[2],'original',129)
    m.set_icon_set(p[1],'original',129);service(129,320)
    check(#p[2]._native==0,'dismissed once alert not resurrected')
    check(#p[1]._native==1 and p[1]._native[1].icon.name==catalog.by_id[r.alert_id].icon_signal,'visible once alert refreshed')
    check(r.expires==expiry and r.delivered[1]==first and state.delivered==delivered and r.delivery_complete,'once state unchanged')
    local created,retained,released=counters();check(created==1 and retained==1 and released==0,'cosmetics do not allocate or retain')
    -- A new first delivery has the only addition allowance before a cosmetic refresh.
    m.set_icon_set(p[1],'svg',321)
    m.record_incident('ecology','ecology-flood',{surface=e.surface,position={x=64,y=0}},321)
    service(321,600);check(state.items[2].delivered[1] and state.items[2].delivered[2],'first delivery advances during cosmetic backlog')
    m.set_icon_set(p[1],'rendered',3600);service(3600,4160)
    check(#p[1]._native==0 and #p[2]._native==0,'expiry beats pending replacement')
    created,retained,released=counters();check(retained==2 and released==2,'receipt releases remain exact')
end
do
    local m,p,e,service,sets=setup()
    m.record_incident('ecology','ecology-wildfire',{surface=e.surface,position=e.position},0);service(0,128)
    local state=m.channel_state('ecology');local r=state.items[1]
    local epoch,delivered,deadline,first=state.roster_epoch,state.delivered,r.expires,r.delivered[1]
    settings.player_default[sets.setting_name]={value='original'}
    local unrelated={value=false};settings.player_default['fixture-unrelated']=unrelated
    m.on_settings_changed{setting_type='runtime-per-user',setting='fixture-unrelated',tick=129}
    check(settings.player_default[sets.setting_name].value=='original','unrelated nil-player event leaves icon default alone')
    m.on_settings_changed{setting_type='runtime-per-user',setting=sets.setting_name,tick=129}
    check(settings.player_default[sets.setting_name].value==sets.sentinel,'nil-player icon event restores future-player sentinel')
    check(settings.player_default['fixture-unrelated']==unrelated and unrelated.value==false,'default normalization touches only icon setting')
    check(p[1].mod_settings[sets.setting_name].value=='rendered' and p[2].mod_settings[sets.setting_name].value=='svg',
        'map default change preserves existing concrete player choices')
    service(129,256)
    check(state.roster_epoch==epoch and state.delivered==delivered and r.expires==deadline
        and r.delivered[1]==first and r.delivery_complete,'nil-player default event does not replay or reopen incident delivery')
    check(#p[1]._native==1 and #p[2]._native==1,'map default event leaves existing native alerts unchanged')
    settings.player_default[sets.setting_name]={value='svg'}
    m.on_player_event{player_index=1,tick=257}
    check(settings.player_default[sets.setting_name].value==sets.sentinel and state.roster_epoch==epoch,
        'existing player lifecycle also normalizes future default without changing audience')
end
do
    local m,p,e,service,sets=setup()
    p[1].mod_settings[sets.setting_name]={value='original'}
    m.set_condition('operational',42,'gate-low-power',true,{entity=e,message={'old'}},0);service(0,3)
    local r=m.channel_state('operational').items[1]
    r.recipient_icons,r.recipient_messages,r.presentation_checked=nil,nil,nil
    m.set_icon_set(p[1],'rendered',4);service(4,8)
    check(#p[1]._native==1 and p[1]._native[1].icon.name==sets.signal_name('rendered',r.alert_id),'pre-selector save removes actual Original icon')
end
do
    local m,p,e,service,sets=setup()
    local provider='fixture__partial'
    local values=prototypes.mod_setting[sets.setting_name].allowed_values;values[#values+1]=provider
    for _,d in ipairs(catalog.entries)do prototypes.virtual_signal[sets.signal_name(provider,d.id)]={}end
    sets.refresh_runtime();m.set_icon_set(p[1],provider,0)
    m.record_incident('ecology','ecology-wildfire',{surface=e.surface,position=e.position},0);service(0,128)
    local r=m.channel_state('ecology').items[1];local old=r.recipient_icons[1].name
    for _,d in ipairs(catalog.entries)do prototypes.virtual_signal[sets.signal_name(provider,d.id)]=nil end
    table.remove(values);p[1]._native[1].icon=nil -- Engine may strip a removed prototype's SignalID.
    settings.startup[sets.default_setting_name]={value='svg'};m.initialize(129);service(129,320)
    check(p[1].mod_settings[sets.setting_name].value=='svg','removed provider copies valid startup fallback')
    check(#p[1]._native==1 and p[1]._native[1].icon.name==sets.signal_name('svg',r.alert_id),'missing old prototype cleans by owned message without duplicate')
    check(r.recipient_icons[1].name~=old,'actual new signal recorded')
end
print('PASS '..checks..' icon presentation checks (native boundaries mocked)')
