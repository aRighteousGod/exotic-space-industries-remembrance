-- Actual Administration GUI owner; native GUI/player boundaries are mocked.
package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local config=require('lib/admin-tools-config')
local state={sessions={}}
local player={index=1,valid=true,admin=true,gui={top={}}}
game={get_player=function()return player end}
package.loaded['scripts/control/admin/common']={peek=function()return state end,state=function()return state end,
    authorize=function(p)return p.valid and p.admin end}
package.loaded['lib/lib']={}
package.loaded['lib/runtime-scheduler']={}
package.loaded['scripts/control/rebuild-monitor']={}
local flow,created,writes={},0,0
flow.add=function(spec)
    created=created+1
    local element={valid=true,sprite=spec.sprite}
    element.destroy=function()element.valid=false;flow[spec.name]=nil end
    flow[spec.name]=element;return element
end
player.gui.top.mod_gui_button_flow=flow
package.loaded['__core__/lualib/mod-gui']={button_style='mod_gui_button',get_button_flow=function()return flow end}
local gui=require('scripts/control/admin/gui')
gui.configure{ecology={on_gui_click=function()return false end},map_settings={on_gui_click=function()return false end}}
local values={valid=true,toggled=false,tags={parent_gui=config.gui,action='launcher'}}
local toggle=setmetatable({}, {__index=values,__newindex=function(_,key,value)values[key]=value;writes=writes+1 end})
local frame={valid=true,visible=true,location={x=48,y=60}}
local session={root=frame,toolbar={valid=true,children={{children={toggle}}}},
    drafts={x='123.5'},page='players',auto_refresh=true,auto_due_tick=600}
state.sessions[1]=session;state.sessions[2]={launcher=false}
player.opened=frame
local count=0
local function check(name,ok)assert(ok,name);count=count+1 end
local function click()gui.on_gui_click{player_index=1,element=toggle,tick=300}end

gui.launcher(player)
check('legacy preference defaults shown and highlights existing toggle',session.launcher and toggle.toggled and session.launcher_toggle==toggle)
check('shown launcher exists exactly once',created==1 and session.launcher_element.valid)
local before=writes;gui.launcher(player)
check('unchanged reconciliation performs no toggle writes',writes==before and created==1)
local first=session.launcher_element
click()
check('hide removes launcher and clears highlight',not session.launcher and not toggle.toggled and not first.valid and not session.launcher_element)
check('hide leaves open window and view state intact',session.root==frame and frame.valid and frame.visible and player.opened==frame
    and frame.location.x==48 and session.page=='players' and session.drafts.x=='123.5')
check('hide preserves explicit auto-refresh and other player preference',session.auto_refresh and session.auto_due_tick==600 and state.sessions[2].launcher==false)
gui.launcher(player)
check('hidden reconciliation creates no launcher',created==1 and not toggle.toggled)
click()
check('show restores launcher and highlight',session.launcher and toggle.toggled and session.launcher_element.valid and created==2)
session.launcher_toggle=nil;values.toggled=false
gui.launcher(player)
check('saved window adopts original toggle without rebuilding',session.launcher_toggle==toggle and toggle.toggled and session.root==frame)
session.launcher_toggle={valid=false};session.launcher=false
gui.launcher(player)
check('stale handle recovers existing control and explicit Off',session.launcher_toggle==toggle and not toggle.toggled and not session.launcher_element)
session.launcher=nil
click()
check('click on a legacy shown preference hides it like Ecology',session.launcher==false and not toggle.toggled)
print('PASS '..count..' Administration launcher checks; native boundaries mocked')
