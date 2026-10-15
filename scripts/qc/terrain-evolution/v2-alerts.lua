-- Actual production alert service with mocked native boundaries.
-- Lua 5.4 screening complements, and does not replace, connected Factorio fixtures.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local config=require('lib/terrain-alert-config')
local shipping='exotic-space-industries-remembrance/scripts/control/terrain-alerts.lua'
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function setup(count)
    storage={};defines={alert_type={custom=1}};prototypes={entity={['ei-ecology-alert-anchor']={}}};helpers={}
    local surface={name='nauvis',index=1,valid=true}
    surface.create_entity=function(args)
        local e={valid=true,surface=surface,position=args.position};e.destroy=function()e.valid=false end;return e
    end
    local players,additions,removals={},{},{}
    local released=0
    game={players=players,connected_players={},get_player=function(i)return players[i]end}
    local function add(i)
        local p={index=i,valid=true,connected=true,admin=false,surface=surface,mod_settings={},
            force={is_chunk_visible=function()return true end},print=function()end}
        p.add_custom_alert=function()additions[i]=(additions[i] or 0)+1 end
        p.remove_alert=function(filter)removals[#removals+1]={player=i,entity=filter.entity,type=filter.type} end
        for _,row in ipairs(config.schema)do p.mod_settings[row.name]={value=row.default}end
        players[i]=p;game.connected_players[#game.connected_players+1]=p;return p
    end
    for i=1,count do add(i) end
    local context={valid=function()return true end,retain=function()end,release=function()released=released+1 end,
        maintenance_begin=function()end,maintenance_update=function()end}
    local m=dofile(shipping);m.configure(context);m.initialize(0)
    m.record_effect{category='wildfire',surface=surface,owner={},position={x=0,y=0},tick=0,count=1}
    local root=storage.ei.ecology_alerts;local incident=root.items[1]
    local function service(tick)
        m.updater{tick=tick}
        check(root.last_service.recipient_checks<=2,'two total recipient checks including cleanup')
        check(root.last_service.additions<=1 and root.last_service.creations<=1,'native addition/creation budgets')
    end
    local function reload()
        m=dofile(shipping);m.configure(context)
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
    check(not r.delivered[1] and not r.delivered[4],'reconnect/new player receive no old backlog')
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
    check(root.roster_epoch==epoch,'ordinary preferences do not restart traversal')
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
print('PASS '..checks..' ecology alert assertions; native APIs mocked.')
