-- Runs in the actual ESIR sandbox with native GUI handles. Event handlers are
-- invoked directly; this does not simulate physical keyboard input or multiplayer.
local model={}
local checkpoint_requested=false
local function state()
    storage.ei.menu_controls_qc=storage.ei.menu_controls_qc or {checks={}}
    return storage.ei.menu_controls_qc
end
local function check(name,ok)
    assert(ok,name);local s=state();s.checks[#s.checks+1]={name=name,ok=true}
end
local function input(name,player,tick)
    local receiver=assert(script.get_event_handler(name),"missing input handler: "..name)
    receiver{name=name,input_name=name,player_index=player.index,tick=tick,cursor_position={0,0}}
end
local function click(player,element,tick)
    script.get_event_handler(defines.events.on_gui_click){name=defines.events.on_gui_click,
        player_index=player.index,element=element,tick=tick,button=defines.mouse_button_type.left}
end
local function find(root,action)
    if root.tags.action==action then return root end
    for _,child in pairs(root.children) do local result=find(child,action);if result then return result end end
end
local function eco(player) return storage.ei.ecology_gui.players[player.index] end
local function admin(player) return storage.ei.admin_tools.sessions[player.index] end
local function tab(player,p,index,tick)
    p.pane.selected_tab_index=index
    script.get_event_handler(defines.events.on_gui_selected_tab_changed){name=defines.events.on_gui_selected_tab_changed,
        player_index=player.index,element=p.pane,tick=tick}
end
local function refresh(ctx,player,tick)
    local root=storage.ei.ecology_gui;root.cursor=assert(root.indexes[player.index])-1;root.next_tick=tick
    local p=eco(player);p.next_tick=tick
    ctx.gui.updater{tick=tick}
    check("viewer stays within eight native property writes",p.last_update_writes<=8)
end
local function tests(ctx,player,tick)
    local s=state()
    local ecology_enabled=settings.startup["ei-terrain-evolution-enabled"].value
    local admin_enabled=settings.startup["ei-admin-tools-enabled"].value
    if not ecology_enabled and not admin_enabled then
        input("ei-toggle-ecology-menu",player,tick);input("ei-toggle-admin-menu",player,tick)
        check("disabled ecology input creates no window",not player.gui.screen["ei-ecology"])
        check("disabled administration input creates no window",not player.gui.screen["ei-admin-console"])
        s.phase="disabled";return
    end
    check("both startup features enabled",ecology_enabled and admin_enabled)
    local original_admin=player.admin;player.admin=true
    ctx.gui.on_player_event{player_index=player.index,tick=tick}
    local p=eco(player)
    if p.frame and p.frame.valid then input("ei-toggle-ecology-menu",player,tick) end
    p.launcher=nil;ctx.gui.on_player_event{player_index=player.index,tick=tick}
    check("missing preference defaults to visible",p.launcher and p.button and p.button.valid)
    input("ei-toggle-ecology-menu",player,tick)
    check("ecology input opens native window",p.frame and p.frame.valid and player.opened==p.frame)
    check("title icon is 48 GUI units",p.title_icon.valid and p.title_icon.style.minimal_width==48 and p.title_icon.style.minimal_height==48)
    local old_frame=p.frame
    local root=storage.ei.ecology_gui;local other=player.index+10000
    root.players[other]={launcher=true}
    click(player,p.launcher_toggle,tick)
    check("hide leaves window intact",p.frame==old_frame and p.frame.valid)
    check("hide removes button and roster membership",p.launcher==false and not p.button and not root.launcher_indexes[player.index])
    check("toggle displays hidden state",not p.launcher_toggle.toggled)
    check("other stored session preference remains unchanged",root.players[other].launcher==true);root.players[other]=nil
    tab(player,p,3,tick)
    for _,entry in ipairs{{0.125,"spring"},{0.375,"summer"},{0.625,"autumn"},{0.875,"winter"}} do
        check("fixture phase changes to "..entry[2],ctx.terrain.set_season_phase(player.surface,entry[1],tick))
        refresh(ctx,player,tick)
        check("hidden launcher Alerts title follows "..entry[2],p.title_icon.sprite=="ei-ecology-tree-"..entry[2])
        refresh(ctx,player,tick)
        check("unchanged Alerts title performs no writes",p.last_update_writes==0)
    end
    local surface=player.surface
    local utility=game.create_surface("menu-controls-utility",{width=32,height=32})
    player.set_controller{type=defines.controllers.remote,surface=utility,position={0,0}}
    ctx.gui.on_player_event{player_index=player.index,tick=tick}
    -- Native controller changes may close player.opened; reopen through the input.
    p=eco(player);if not p.frame or not p.frame.valid then input("ei-toggle-ecology-menu",player,tick) end
    tab(player,p,3,tick);refresh(ctx,player,tick)
    check("unknown calendar title uses summer tree",p.title_icon.sprite=="ei-ecology-tree-summer")
    player.set_controller{type=defines.controllers.remote,surface=surface,position={0,0}}
    ctx.gui.on_player_event{player_index=player.index,tick=tick}
    p=eco(player);if not p.frame or not p.frame.valid then input("ei-toggle-ecology-menu",player,tick) end
    tab(player,p,3,tick);old_frame=p.frame
    p.frame.location={x=48,y=48};local location=p.frame.location
    p.layout_version=2;refresh(ctx,player,tick);p=eco(player)
    check("old window rebuilt with menu controls",p.layout_version>=3 and p.frame~=old_frame and not old_frame.valid
        and p.title_icon.valid and p.launcher_toggle.valid)
    check("upgrade retains tab location and hidden preference",p.tab==3 and not p.launcher
        and p.frame.location.x==location.x and p.frame.location.y==location.y)
    ctx.gui.initialize(tick);p=eco(player)
    check("configuration preserves hidden preference and open tab",not p.launcher and not p.button and p.tab==3 and p.frame.valid)
    ctx.gui.on_player_left{player_index=player.index,tick=tick}
    ctx.gui.on_player_event{player_index=player.index,tick=tick}
    check("leave and rejoin reconciliation preserves hidden preference",not p.launcher and not p.button and not p.frame)
    input("ei-toggle-ecology-menu",player,tick);check("hidden ecology opens by input",p.frame and p.frame.valid)
    input("ei-toggle-ecology-menu",player,tick);check("repeated ecology input closes",not p.frame and player.opened==nil)
    input("ei-toggle-ecology-menu",player,tick)
    click(player,p.launcher_toggle,tick)
    check("show restores one button and roster membership",p.launcher and p.button.valid and root.launcher_indexes[player.index] and p.launcher_toggle.toggled)
    click(player,p.launcher_toggle,tick)
    input("ei-toggle-ecology-menu",player,tick)
    local snapshots=0;local original=ctx.terrain.public_snapshot
    ctx.terrain.public_snapshot=function(...) snapshots=snapshots+1;return original(...) end
    ctx.gui.updater{tick=tick+600};ctx.gui.launcher_updater{tick=tick+600}
    ctx.terrain.public_snapshot=original
    check("hidden closed ecology performs zero report reads",snapshots==0 and not ctx.gui.has_tick_work(tick+600))
    local a=admin(player)
    if a and a.root and a.root.valid and a.root.visible then input("ei-toggle-admin-menu",player,tick) end
    player.admin=false;input("ei-toggle-admin-menu",player,tick)
    a=admin(player);check("non-admin input denied",not a or not a.root or not a.root.valid or not a.root.visible)
    player.admin=true;input("ei-toggle-admin-menu",player,tick);a=admin(player)
    check("administrator input opens native console",a.root.valid and a.root.visible)
    check("admin toggle reflects saved launcher preference",a.launcher_toggle.valid and a.launcher_toggle.toggled==a.launcher)
    if a.launcher then click(player,find(a.root,"launcher"),tick) end
    check("admin hide clears highlight without closing console",not a.launcher_toggle.toggled and a.root.visible and not a.launcher_element)
    click(player,a.launcher_toggle,tick)
    check("admin show restores highlighted launcher",a.launcher and a.launcher_toggle.toggled and a.launcher_element.valid)
    click(player,a.launcher_toggle,tick)
    a.drafts.x="123.5";local page=a.page;local admin_frame=a.root
    input("ei-toggle-admin-menu",player,tick)
    check("admin input closes retained root",a.root==admin_frame and a.root.valid and not a.root.visible)
    input("ei-toggle-admin-menu",player,tick)
    check("admin input reopens hidden root with page and draft",a.root==admin_frame and a.root.visible and a.page==page and a.drafts.x=="123.5" and not a.launcher)
    local admin_toggle=a.launcher_toggle;a.launcher_toggle=nil;admin_toggle.toggled=true
    input("ei-toggle-admin-menu",player,tick);input("ei-toggle-admin-menu",player,tick)
    check("saved admin toggle adopted in place with hidden highlight",a.root==admin_frame and a.launcher_toggle==admin_toggle
        and not admin_toggle.toggled and a.page==page and a.drafts.x=="123.5")
    input("ei-toggle-admin-menu",player,tick);player.admin=original_admin
    input("ei-toggle-ecology-menu",player,tick);p=eco(player)
    tab(player,p,3,tick);p.frame.location={x=48,y=48}
    s.phase="reload";s.tab=p.tab;s.location=p.frame.location
    game.take_screenshot{player=player,path="menu-controls/alerts-hidden.png",show_gui=true,force_render=true,resolution=player.display_resolution}
    game.auto_save("menu-controls")
    checkpoint_requested=true
end
function model.step(ctx,player,tick)
    local s=state()
    if s.phase=="reload" and not checkpoint_requested then
        local p=eco(player)
        check("native reload retains hidden ecology preference",p and p.launcher==false and not p.button)
        check("native reload retains hidden admin preference",admin(player).launcher==false)
        if p.frame and p.frame.valid then input("ei-toggle-ecology-menu",player,tick) end
        input("ei-toggle-ecology-menu",player,tick)
        check("native reload reopens with saved tab and location",p.tab==s.tab
            and p.frame.location.x==s.location.x and p.frame.location.y==s.location.y and p.title_icon.valid)
        s.phase="reloaded"
    elseif not s.phase then tests(ctx,player,tick) end
    return {complete=true,all_pass=true,checks=s.checks,count=#s.checks,phase=s.phase,
        version=script.active_mods.base,scale=player.display_scale,
        scope="Native windows and direct registered-handler calls; stored-session isolation, not two-player multiplayer or physical key input."}
end
return model
