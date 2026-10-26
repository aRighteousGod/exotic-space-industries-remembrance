-- Actual production alert service with mocked native boundaries.
-- Lua 5.4 screening complements, and does not replace, connected Factorio fixtures.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local config=require('lib/terrain-alert-config')
local shipping='exotic-space-industries-remembrance/scripts/control/terrain-alerts.lua'
package.loaded['lib/lib']={get_valid_entity=function(e)return e and e.valid and e or nil end}
package.loaded['lib/runtime-scheduler']={bump_counter=function()end}
local checks=0
local icon_mock=dofile('scripts/qc/alerts/icon-mock.lua')
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function setup(count)
    package.loaded['lib/alerts']=nil
    storage={};defines={alert_type={custom=1}};prototypes={entity={['ei-alert-anchor']={}}};helpers={}
    icon_mock.install(require('lib/alert-catalog'))
    local surface={name='nauvis',index=1,valid=true}
    surface.create_entity=function(args)
        local e={valid=true,surface=surface,position=args.position};e.destroy=function()e.valid=false end;return e
    end
    local players,additions,removals={},{},{}
    local released=0
    game={players=players,connected_players={},get_player=function(i)return players[i]end}
    local function add(i)
        local p={index=i,valid=true,connected=true,admin=false,surface=surface,mod_settings={},
            force={index=1,valid=true,is_chunk_visible=function()return true end},print=function()end}
        p.mod_settings['ei-alert-icon-set']={value='original'}
        icon_mock.player(p,function()additions[i]=(additions[i] or 0)+1 end,
            function(filter)removals[#removals+1]={player=i,entity=filter.entity,type=filter.type,icon=filter.icon} end)
        for _,row in ipairs(config.schema)do p.mod_settings[row.name]={value=row.default}end
        players[i]=p;game.connected_players[#game.connected_players+1]=p;return p
    end
    for i=1,count do add(i) end
    local context={valid=function()return true end,retain=function()end,release=function()released=released+1 end,
        maintenance_begin=function()end,maintenance_update=function()end}
    local m=dofile(shipping);m.configure(context);m.initialize(0)
    m.record_effect{category='wildfire',surface=surface,owner={},position={x=0,y=0},tick=0,count=1}
    local core=require('lib/alerts')
    local root=core.channel_state('ecology');local incident=root.items[1]
    local function service(tick)
        m.updater{tick=tick};core.updater{tick=tick}
        check(root.last_service.recipient_checks<=2,'two total recipient checks including cleanup')
        check(root.last_service.additions<=1 and root.last_service.creations<=1,'native addition/creation budgets')
    end
    local function reload()
        package.loaded['lib/alerts']=nil
        m=dofile(shipping);m.configure(context);core=require('lib/alerts')
        return m
    end
    return m,players,root,incident,add,service,additions,removals,function()return released end,reload
end
do
    local m,p,root,r,add,service,adds=setup(3)
    service(0);p[1].connected=false;game.connected_players={p[2],p[3]};m.on_player_event{player_index=1,tick=1}
    for tick=32,256,32 do service(tick) end
    check(r.delivered[2] and r.delivered[3] and r.delivery_complete,'compaction does not skip remaining connected audience')
    check(adds[1]==1 and adds[2]==1 and adds[3]==1,'each original recipient added once')
end
do
    local m,p,root,r,add,service,adds=setup(3)
    service(0);p[1].connected=false;game.connected_players={p[2],p[3]};m.on_player_event{player_index=1,tick=1}
    p[1].connected=true;game.connected_players={p[1],p[2],p[3]};m.on_player_event{player_index=1,tick=2}
    add(4);m.on_player_event{player_index=4,tick=3}
    for tick=32,320,32 do service(tick) end
    check(r.delivered[2] and r.delivered[3],'continuously connected recipients survive traversal restart')
    check(not r.delivered[4],'new player receives no old backlog')
    check(adds[1]==1 and not adds[4],'later connections never receive an old notification')
end
do
    local m,p,root,r,add,service,adds=setup(1)
    service(0);check(r.delivery_complete,'single-recipient traversal completes')
    add(2);m.on_player_event{player_index=2,tick=1}
    service(32);service(64)
    check(r.delivery_complete and not r.delivered[2] and not adds[2],'completed incident never reopens')
    local epoch=root.roster_epoch
    m.refresh_preferences(p[1]);m.set_preference(p[1],'flood',false)
    check(root.roster_epoch==epoch+1,'type preference advances eligibility epoch without reopening a completed traversal')
end
do
    local m,p,root,r,add,service,adds,removals,released=setup(1)
    service(0);local anchor=r.anchor;r.expires=1
    service(32)
    check(#root.items==1 and anchor.valid and #root.players[1].live==0,'one cleanup action removes recipient before retiring helper')
    check(#removals==1 and removals[1].entity==anchor and removals[1].type==defines.alert_type.custom,'cleanup targets only the owned custom alert')
    service(64)
    check(#root.items==0 and root.anchors==0 and not anchor.valid,'subsequent bounded cleanup retires helper and capacity')
    check(root.by_id[r.id]==nil and root.coalesced[r.key]==nil and released()==1,'retirement releases indexes and provenance exactly once')
end
do
    local m,p,root,r,add,service,adds,removals,released,reload=setup(2)
    -- Simulate a saved V2 state from before roster fields existed. This is a
    -- table-preserving module reload, not native save serialization evidence.
    root.roster_epoch=nil;r.audience_epoch=nil;r.scan_epoch=nil
    for _,prefs in pairs(root.players)do prefs.connection_epoch=nil end
    m=reload();service(0)
    add(3);m.on_player_event{player_index=3,tick=1}
    for tick=32,224,32 do service(tick) end
    check(r.delivered[1] and r.delivered[2] and r.delivery_complete,'legacy epoch-zero audience completes after module reload')
    check(not r.delivered[3] and not adds[3],'legacy fallback excludes later connections')
end
do
    local m,p,root,r,add,service=setup(1)
    local attempted=0
    p[1].surface.create_entity=function()attempted=attempted+1;return nil end
    service(0)
    check(attempted==1 and root.anchors==0 and #root.players[1].live==0,
        'failed helper creation consumes one attempt without reserving anchor capacity')
end
do
    local m,p,root,r,add,service,adds,removals,released=setup(2)
    service(0)
    r.delivered[1]=true -- Original ecology save used boolean delivery membership.
    r.recipient_icons,r.recipient_messages,r.presentation_checked=nil,nil,nil
    p[1]._native[1].icon={type='virtual',name='signal-fire'}
    local anchor,deadline,id,preferences=r.anchor,r.expires,r.id,root.players
    local legacy=storage.ei.ecology_alerts
    for _,key in ipairs{'items','by_id','coalesced','next_id','next_tick','cursor','cleanup_cursor','anchors','dropped','delivered','roster_epoch'} do legacy[key]=root[key] end
    legacy.alert_delivery_version=nil
    storage.ei.alerts.channels.ecology=nil
    m.initialize(1)
    local core=require('lib/alerts');local adopted=core.channel_state('ecology')
    check(adopted.items[1]==r and r.anchor==anchor and r.id==id and r.expires==deadline,'legacy adoption preserves record identity, marker, ID and deadline')
    check(adopted.players==preferences and legacy.players==preferences,'migration preserves shared preference identity')
    check(adopted.delivered==root.delivered and adopted.anchors==root.anchors,'migration preserves counters')
    m.initialize(2);check(core.channel_state('ecology')==adopted and #adopted.items==1,'migration is idempotent')
    check(r.key=='1:0:0:wildfire','legacy ecology coalescing key is unchanged')
    check(m.record_effect{category='wildfire',surface=r.surface,owner=r.owner,position=r.position,tick=3,count=1},'new receipt coalesces with adopted incident')
    check(#adopted.items==1 and r.count==2 and r.expires==deadline,'post-migration coalescing retains original record and deadline')
    core.updater{tick=32};check(adds[1]==1 and adds[2]==1,'pending legacy traversal completes without duplicate delivery')
    r.expires=33
    for tick=64,256,32 do core.updater{tick=tick} end
    check(#removals==2,'one exact removal per migrated/new recipient')
    local icons={};for _,item in ipairs(removals)do icons[item.player]=item.icon.name end
    check(icons[1]=='signal-fire' and icons[2]=='ei-alert-ecology-wildfire','legacy and new recipient icon filters remain distinct')
    check(released()==1 and #adopted.items==0 and not anchor.valid,'migrated receipt releases once without orphan marker')
end
print('PASS '..checks..' ecology alert assertions; native APIs mocked.')
