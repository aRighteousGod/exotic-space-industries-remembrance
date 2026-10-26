-- Production alert owner with mocked native boundaries. Native save/UI checks are separate.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local catalog=require('lib/alert-catalog')
local icon_mock=dofile('scripts/qc/alerts/icon-mock.lua')
package.loaded['lib/lib']={get_valid_entity=function(e)return e and e.valid and e or nil end,
    entity_check=function(e)return e and e.valid or false end}
package.loaded['lib/runtime-scheduler']={bump_counter=function()end}
local function setup()
    storage={};defines={alert_type={custom=1}}
    icon_mock.install(catalog)
    package.loaded['lib/alerts']=nil;package.loaded['scripts/control/terrain-alerts']=nil
    local force={index=1,valid=true,is_chunk_visible=function()return true end}
    local other={index=2,valid=true,is_chunk_visible=function()return true end}
    local surface={index=1,name='nauvis',valid=true};local anchors,adds,removes={},{},{}
    surface.create_entity=function(options)
        local e={valid=true,surface=surface,position=options.position}
        e.destroy=function()e.valid=false end;anchors[#anchors+1]=e;return e
    end
    local players={}
    game={players=players,connected_players={},get_player=function(i)return players[i]end}
    local function add_player(index,owner)
        local p={index=index,valid=true,connected=true,force=owner or force,surface=surface,mod_settings={}}
        for _,entry in ipairs(catalog.entries) do
            p.mod_settings[entry.setting_name]={value=true}
            if entry.master then p.mod_settings[entry.master]={value=true} end
        end
        p.mod_settings['ei-alert-icon-set']={value='original'}
        icon_mock.player(p,function(entity,icon,message,map)
            check(entity.valid and map,'native target valid/map enabled')
            adds[#adds+1]={player=index,entity=entity,icon=icon.name,message=message,tick=game.tick}
        end,function(filter) removes[#removes+1]={player=index,filter=filter} end)
        players[index]=p;game.connected_players[#game.connected_players+1]=p;return p
    end
    add_player(1);add_player(2);add_player(3,other)
    local m=require('lib/alerts');m.initialize(0)
    local entity={valid=true,unit_number=42,force=force,surface=surface,position={x=2,y=3}}
    local function service(first,last)
        for tick=first,last do game.tick=tick;m.updater{tick=tick} end
    end
    return m,players,entity,service,adds,removes,anchors,add_player,force
end
do
    local m,p,e,service,adds,removes=setup()
    check(m.set_condition('operational',42,'gate-low-power',true,{entity=e,message={'test'}},0),'condition admitted at tick zero')
    service(0,5);check(#adds==2,'owning force only')
    service(6,250);check(#adds>=4,'condition renewed')
    local state=m.channel_state('operational')
    check(#state.items==1 and state.last_service.steps<=32,'deduplication and bounded service')
    p[1].mod_settings['ei-alert-gate-low-power']={value=false}
    m.on_settings_changed{player_index=1,setting_type='runtime-per-user',setting='ei-alert-gate-low-power'}
    local before=#adds;service(251,260)
    check(#removes>0 and removes[#removes].filter.icon.name=='ei-alert-gate-low-power','personal mute exact icon removal')
    for i=before+1,#adds do check(adds[i].player~=1,'muted user receives no renewal') end
    p[1].mod_settings['ei-alert-gate-low-power']={value=true}
    m.on_settings_changed{player_index=1,setting_type='runtime-per-user',setting='ei-alert-gate-low-power'}
    service(261,400);check(#state.players[1].live==1,'re-enabled condition returns')
    m.clear_source('operational',42,401);check(#state.players[1].live==0,'source mute immediately clears recipients')
    service(401,403);check(#state.items==0 and not m.has_tick_work(500),'retirement and idle')
end
do
    local m,p,e,service,adds,removes,anchors,add=setup()
    check(m.record_incident('operational','fluid-thermal',{entity=e},0),'incident admitted')
    e.valid=false;service(0,5)
    check(#anchors==1 and #adds==2,'destroyed source uses shared surviving marker')
    local newcomer=add(4);m.on_player_event{player_index=4}
    p[1].connected=false;game.connected_players={p[2],p[3],newcomer};m.on_player_event{player_index=1}
    p[1].connected=true;game.connected_players={p[1],p[2],p[3],newcomer};m.on_player_event{player_index=1}
    local before=#adds;service(6,250)
    for i=before+1,#adds do check(adds[i].player==2,'no join/reconnect backlog') end
    local state=m.channel_state('operational');local record=state.items[1]
    check(m.record_incident('operational','fluid-thermal',{surface=e.surface,position={x=4,y=5},force=e.force},200),'coalesced event')
    check(#state.items==1 and record.count==2 and record.expires==3800 and record.position.x==2,'count/expiry/first location')
    service(251,3810);check(#state.items==0 and not anchors[1].valid,'finite expiry destroys marker')
end
do
    local m,p,e,service,adds=setup()
    for _,entry in ipairs(catalog.entries) do
        check(m.player_allows(p[1],entry.id),'each enabled type accepted')
        p[1].mod_settings[entry.setting_name]={value=false};check(not m.player_allows(p[1],entry.id),'each false type denied')
        p[1].mod_settings[entry.setting_name]=nil;check(not m.player_allows(p[1],entry.id),'each missing type denied')
        p[1].mod_settings[entry.setting_name]={value=true}
        if entry.master then p[1].mod_settings[entry.master]={value=false};check(not m.player_allows(p[1],entry.id),'master dominates');p[1].mod_settings[entry.master]={value=true} end
    end
    check(not m.record_incident('operational','undeclared',{entity=e},0),'unknown alert rejected')
    p[1].mod_settings['ei-alert-fluid-data']={value=false}
    m.record_incident('operational','fluid-data',{entity=e},0);service(0,8)
    p[1].mod_settings['ei-alert-fluid-data']={value=true}
    m.on_settings_changed{player_index=1,setting_type='runtime-per-user',setting='ei-alert-fluid-data'}
    local before=#adds;service(9,200)
    for i=before+1,#adds do check(adds[i].player~=1,'enabling incident type does not replay') end
    local after_enable=#adds
    m.record_incident('operational','fluid-data',{entity=e},201);service(201,220)
    local received_fresh=false
    for i=after_enable+1,#adds do if adds[i].player==1 then received_fresh=true end end
    check(received_fresh,'a fresh coalesced report after enable is delivered without replay on enable alone')
    m.on_surface_removed{surface_index=1};service(221,230)
    check(#m.channel_state('operational').items==0,'surface cleanup')
end
do
    local m,p,e,service,adds=setup()
    m.record_incident('operational','matter-cascade',{entity=e},0);service(0,5)
    package.loaded['lib/alerts']=nil;m=require('lib/alerts');m.initialize(6)
    game.tick=6;m.updater{tick=6}
    check(#m.channel_state('operational').items==1 and #adds==2,'table-preserving reload retains records without duplicate delivery')
end
do
    local n=#catalog.entries
    catalog.add{id='fixture',channel='operational',setting_name='ei-alert-fixture',default_enabled=false,icon_signal='ei-alert-fixture',
        localised_name={'fixture.name'},localised_description={'fixture.description'},order='z'}
    local definitions=catalog.setting_definitions()
    check(#definitions==n+1 and definitions[#definitions].setting_type=='runtime-per-user' and definitions[#definitions].hidden==false,'future type automatically generates visible toggle')
    check(not pcall(catalog.add,{id='bad'}),'incomplete definitions rejected')
    check(not pcall(catalog.add,{id='duplicate',channel='operational',default_enabled=true,setting_name='ei-alert-fixture'}),'duplicate setting rejected')
end
do
    local m,p,e,service,adds,removes=setup()
    m.set_condition('operational','one','gate-low-power',true,{entity=e,source_id=42},0)
    m.set_condition('operational','two','gate-low-power',true,{entity=e,source_id=42},0)
    service(0,8)
    m.set_condition('operational','one','gate-low-power',false,{},9)
    service(9,15)
    check(#m.channel_state('operational').items==1,'clearing one key preserves sibling conditions on the source')
    local replacement={valid=true,unit_number=99,force=e.force,surface=e.surface,position={x=5,y=6}}
    local before=#removes
    m.set_condition('operational','two','gate-low-power',true,{entity=replacement,source_id=42},16)
    check(#removes>before and removes[#removes].filter.entity==e,'target replacement cleans the old native target')
    service(16,25)
    check(#m.channel_state('operational').items==1 and adds[#adds].entity==replacement,'replacement retains stable logical condition identity')
end
do
    local m,p,e,service,adds,removes=setup()
    for i=1,100 do
        local target={valid=true,unit_number=i,force=e.force,surface=e.surface,position={x=i,y=0}}
        m.set_condition('operational',i,'gate-low-power',true,{entity=target},0)
    end
    for tick=0,400 do service(tick,tick);check(m.channel_state('operational').last_service.steps<=32,'loaded operational service stays bounded') end
    check(#adds>=200,'loaded condition audience progresses')
    p[1].force=p[3].force;m.on_player_event{player_index=1}
    service(401,800);check(#m.channel_state('operational').players[1].live==0,'force change removes old-force conditions')
    for i=1,100 do m.clear_source('operational',i,801) end
    service(801,1005);check(not m.has_tick_work(1006),'large retired cohort returns to idle')
end
print('PASS '..checks..' shared alert assertions (native boundaries mocked)')
