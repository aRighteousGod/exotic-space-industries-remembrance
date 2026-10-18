-- Actual GUI owner with native player/element boundaries mocked. No engine.
local flow={}
package.loaded['__core__/lualib/mod-gui']={get_button_flow=function()return flow end}
package.loaded['lib/terrain-alert-config']={}
package.loaded['lib/terrain-evolution-config']={}
package.loaded['scripts/control/terrain-field-report']={}
local gui=dofile('exotic-space-industries-remembrance/scripts/control/terrain-gui.lua')
local surface={name='nauvis'}
local player={index=1,connected=false,surface=surface}
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
