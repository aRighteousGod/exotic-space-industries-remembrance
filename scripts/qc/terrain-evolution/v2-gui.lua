-- Actual GUI owner with native player/element boundaries mocked. No engine.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local flow={}
package.loaded['__core__/lualib/mod-gui']={get_button_flow=function()return flow end}
local preferences=require('lib/terrain-alert-config')
local catalog=require('lib/alert-catalog')
local personal_sets={[1]='original',[2]='svg'}
local setting_calls={}
package.loaded['lib/alert-icon-sets']={setting_name='ei-alert-icon-set',sentinel='startup-default',
    available_sets=function()return {'original','svg','rendered','vanilla'} end,
    player_set=function(p)return personal_sets[p.index] end,
    choice_caption=function(id)return {'string-mod-setting.ei-alert-icon-set-'..id} end,
    signal_name=function(id,alert_id)return 'ei-alert-'..id..'-'..alert_id end}
package.loaded['lib/alerts']={set_icon_set=function(p,id,tick)
    personal_sets[p.index]=id=='startup-default' and 'rendered' or id
    setting_calls[#setting_calls+1]={player=p.index,id=id,tick=tick}
    return personal_sets[p.index]
end}
package.loaded['lib/terrain-evolution-config']={}
package.loaded['scripts/control/terrain-field-report']={}
local gui=dofile('exotic-space-industries-remembrance/scripts/control/terrain-gui.lua')
local surface={name='nauvis'}
local player={index=1,connected=false,surface=surface,gui={top={mod_gui_button_flow=flow}}}
local snapshots,seasons,destroyed=0,0,0
local function frame()
    local f={valid=true,location={x=0,y=0}}
    f.destroy=function() destroyed=destroyed+1;f.valid=false end
    return f
end
local function fresh()
    local root={players={[1]={frame=frame(),rows={[1]={{element={},key='surface'}}},tab=1,row_cursor=0,next_tick=0,surface=surface}},
        viewers={1},indexes={[1]=1},cursor=0,next_tick=0,launchers={1},launcher_indexes={[1]=1},launcher_cursor=0,launcher_next_tick=0}
    storage={ei={ecology_gui=root}};return root
end
game={get_player=function()return player end,players={player},surfaces={nauvis=surface}}
settings={startup={['ei-terrain-evolution-enabled']={value=true}}}
gui.configure{terrain={public_snapshot=function() snapshots=snapshots+1;return {status='enabled',effects={},global={}} end,
    season_index=function()seasons=seasons+1;return 1 end}}
local root=fresh()
gui.updater{tick=16}
assert(snapshots==0 and #root.viewers==0 and not root.players[1].frame and destroyed==1)
assert(not gui.has_tick_work(1000),'offline retained viewer becomes idle before any snapshot')
gui.launcher_updater{tick=16}
assert(seasons==0 and #root.launchers==0 and not gui.launcher_has_tick_work(1000),'offline launcher retires before season read')
root=fresh()
flow['ei-ecology-button']={valid=true,type='sprite-button'}
root.players[1].button_season=1
-- No screen.add stub: reopening an offline window fails immediately.
gui.initialize(20)
assert(#root.viewers==0 and #root.launchers==0 and not root.players[1].frame,'configuration closes but never reopens offline frame')
print('PASS 3 actual-owner offline GUI lifecycle checks; native boundaries mocked')

-- Current v4 panes are upgraded in place because Factorio exposes no readable
-- scroll offset. Count native property assignments independently of GUI telemetry.
local element_id,writes=0,0
local function element(spec,parent)
    element_id=element_id+1
    local data={valid=true,index=element_id,player_index=1,children={},style={},parent=parent,location={x=40,y=48}}
    for key,value in pairs(spec or {}) do if key~='index' then data[key]=value end end
    local handle=setmetatable({}, {__index=data,__newindex=function(_,key,value)data[key]=value;writes=writes+1 end})
    data.add=function(child)
        local added=element(child,handle)
        table.insert(data.children,child.index or #data.children+1,added)
        return added
    end
    data.clear=function() data.children={} end
    data.destroy=function() data.valid=false;destroyed=destroyed+1 end
    return handle
end
local prefs={surfaces='all',selected={}}
for _,row in ipairs(preferences.schema) do if row.type=='bool-setting' then prefs[row.key]=row.default end end
gui.configure{terrain={public_snapshot=function()snapshots=snapshots+1;return {} end,
    season_index=function()return 1 end},alerts={preferences=function()return prefs end}}
player.connected=true;player.admin=true
local old_frame=element{type='frame',name='ei-ecology'}
local scroll=element{type='scroll-pane'};scroll.saved_native_scroll=212
local checks={}
for _,row in ipairs(preferences.schema) do
    if row.type=='bool-setting' then checks[row.key]=element{type='checkbox',state=prefs[row.key],caption='legacy'} end
end
local session={frame=old_frame,layout_version=4,tab=3,location={x=40,y=48},launcher=false,
    bodies={element{},element{},scroll},checks=checks,title_season=1,title_icon=element{sprite='ei-ecology-tree-spring'},
    surface=surface,surface_epoch=1,surface_selection='all',row_cursor=0,next_tick=0,rows={}}
root={players={[1]=session},viewers={1},indexes={[1]=1},cursor=0,next_tick=0,
    surface_epoch=1,surface_names={'nauvis'},surface_known={nauvis=true},launchers={},launcher_indexes={}}
storage={ei={ecology_gui=root}}
writes=0;gui.updater{tick=32}
assert(session.layout_version==5 and session.frame==old_frame and session.bodies[3]==scroll,'v4 migration retains native pane identities')
assert(session.tab==3 and scroll.saved_native_scroll==212 and not session.launcher and old_frame.location.x==40,'migration retains tab, native scroll, position and hidden launcher')
assert(scroll.children[1].children[2]==session.icon_selector and #session.icon_rows==17,'selector precedes all existing preferences')
assert(session.last_update_writes<=8,'migration captions use viewer allowance')
for tick=48,96,16 do writes=0;gui.updater{tick=tick};assert(writes<=8 and writes==session.last_update_writes,'native assignment count matches bounded telemetry') end
for _,row in ipairs(session.icon_rows) do assert(row.set_id=='original' and row.element.caption[2]:find('original',1,true)) end

local old_pane=session.bodies[3];local old_choice=session.icon_selector
flow['ei-ecology-button']=nil
gui.initialize(100)
assert(session.frame==old_frame and session.bodies[3]==old_pane and session.icon_selector==old_choice,'configuration preserves current native panes and selector')
assert(session.tab==3 and not session.launcher and scroll.saved_native_scroll==212,'configuration preserves saved view and launcher')

local function settings_changed(tick)
    writes=0
    gui.on_settings_changed{player_index=1,setting_type='runtime-per-user',setting='ei-alert-icon-set',tick=tick}
    assert(writes==0,'setting event does not rewrite any native caption or selector')
end
personal_sets[1]='svg';settings_changed(101)
writes=0;gui.updater{tick=112};assert(writes<=8 and writes==session.last_update_writes)
local partially_svg=0
for _,row in ipairs(session.icon_rows) do if row.set_id=='svg' then partially_svg=partially_svg+1 end end
assert(partially_svg>0 and partially_svg<17,'caption replacement spans bounded opportunities')
personal_sets[1]='rendered';settings_changed(113)
for tick=128,176,16 do writes=0;gui.updater{tick=tick};assert(writes<=8 and writes==session.last_update_writes) end
for _,row in ipairs(session.icon_rows) do assert(row.set_id=='rendered','rapid second choice replaces current target without obsolete queue') end
assert(personal_sets[2]=='svg','personal icon change leaves another player unchanged')
assert(session.frame==old_frame and scroll.saved_native_scroll==212,'style refresh leaves frame and scroll intact')

session.icon_selector.selected_index=1
gui.on_gui_change{player_index=1,element=session.icon_selector,tick=181}
assert(#setting_calls==1 and setting_calls[1].id=='startup-default' and setting_calls[1].tick==181,'dropdown calls shared owner with original tick')
assert(personal_sets[1]=='rendered','startup action copies a concrete configured default')
writes=0;gui.updater{tick=192};assert(session.icon_selector.selected_index==4 and writes<=8,'startup action reconciles dropdown to concrete choice')
local correct_tags=session.icon_selector.tags
session.icon_selector.tags={parent_gui='ei-ecology',action='icon-set',player_index=2,frame_index=old_frame.index}
gui.on_gui_change{player_index=1,element=session.icon_selector,tick=193}
session.icon_selector.tags={parent_gui='ei-ecology',action='icon-set',player_index=1,frame_index=old_frame.index+1}
gui.on_gui_change{player_index=1,element=session.icon_selector,tick=194}
session.icon_selector.tags=correct_tags
local stale=element{type='drop-down',tags=correct_tags,selected_index=2}
gui.on_gui_change{player_index=1,element=stale,tick=195}
session.icon_selector.selected_index=999
gui.on_gui_change{player_index=1,element=session.icon_selector,tick=196}
assert(#setting_calls==1,'wrong-player tags, stale frame, stale element and unknown choice are rejected')
print('PASS actual-owner icon selector, shared change path, per-player isolation, rapid changes, eight-write budget and in-place migration checks; native boundaries mocked')
