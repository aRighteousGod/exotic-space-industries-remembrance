-- Native console access must never opt players into sandbox modes.
local model={}
function model.run(admin,gui,common,player,tick)
    local checks={}
    local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
    if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
    if player.controller_type==defines.controllers.editor then player.toggle_map_editor() end
    if player.character and player.character.valid then
        player.set_controller{type=defines.controllers.character,character=player.character}
    else player.set_controller{type=defines.controllers.god};assert(player.create_character()) end
    player.cheat_mode=false;player.character.destructible=true
    local body=player.character
    admin.on_player_event{name=defines.events.on_player_promoted,player_index=player.index,tick=tick}
    check("admin promotion leaves cheat mode off",not player.cheat_mode)
    check("admin promotion leaves god mode off",player.controller_type==defines.controllers.character and player.character==body)
    check("admin promotion leaves invulnerability off",body.destructible)
    admin.open(player,"players",tick)
    local root=common.peek();local session=root.sessions[player.index]
    check("opening console creates no sandbox mode ownership",root.modes[player.index]==nil)
    check("opening console retains all player modes off",not player.cheat_mode and body.destructible
        and player.controller_type==defines.controllers.character and player.character==body)
    local caption=session.readout.caption
    check("player readout explicitly displays default modes off",caption[1]=="ei-admin.player-readout"
        and caption[2]=="Off" and caption[3]=="Off" and caption[4]=="Off")
    local frame=session.root
    local scale=player.display_scale;local resolution=player.display_resolution
    local dragged={x=math.max(0,math.floor(resolution.width-frame.style.minimal_width*scale-8*scale)),
        y=math.max(0,math.floor(resolution.height-frame.style.minimal_height*scale-8*scale))}
    frame.location=dragged
    local function retained(name)
        check(name,session.root==frame and frame.location.x==dragged.x and frame.location.y==dragged.y,
            {expected=dragged,actual=frame.location})
    end
    gui.refresh(player.index,tick);retained("ordinary console refresh preserves dragged position")
    gui.result(player.index,"Native position check",tick);retained("feedback layout preserves dragged position")
    admin.open(player,"diagnostics",tick);retained("page change preserves dragged position")
    gui.on_display_changed{player_index=player.index,tick=tick};retained("same display refresh preserves dragged position")
    gui.close(player.index);admin.open(player,"players",tick);retained("console reopen preserves dragged position")
    gui.close(player.index,true);admin.open(player,"players",tick)
    check("root recreation restores last dragged position",session.root.valid and session.root.location.x==dragged.x
        and session.root.location.y==dragged.y)
    frame=session.root
    check("auto refresh defaults off without scheduled work",not session.auto_refresh and not session.auto_due_tick
        and not root.auto_refresh_due_tick and session.auto_refresh_button.caption[1]=="ei-admin.auto-refresh-off")
    local original_refresh=gui.refresh;local refreshes=0
    gui.refresh=function(...)refreshes=refreshes+1;return original_refresh(...)end
    local function click()gui.on_gui_click{player_index=player.index,element=session.auto_refresh_button,tick=tick}end
    click()
    check("auto refresh toggle schedules selected default interval",session.auto_refresh and session.auto_due_tick==tick+300
        and session.auto_refresh_button.caption[1]=="ei-admin.auto-refresh-on")
    gui.refresh_automatically(tick+299)
    check("auto refresh performs no early display work",refreshes==0)
    session.drafts.reason="Unapplied automatic refresh draft"
    gui.refresh_automatically(tick+300)
    check("auto refresh services once and reschedules",refreshes==1 and session.auto_due_tick==tick+600)
    check("auto refresh retains native root position and drafts",session.root==frame and frame.location.x==dragged.x
        and frame.location.y==dragged.y and session.drafts.reason=="Unapplied automatic refresh draft")
    local interval=session.fields.auto_refresh_interval;interval.selected_index=2
    gui.on_gui_change{player_index=player.index,element=interval,tick=tick+301}
    check("interval selection replaces outstanding timer",session.drafts.auto_refresh_interval==2 and session.auto_due_tick==tick+421
        and root.auto_refresh_buckets[tick+600]==nil)
    gui.close(player.index)
    check("closed console cancels all automatic refresh work",not session.auto_due_tick and not root.auto_refresh_due_tick
        and not next(root.auto_refresh_buckets))
    gui.refresh_automatically(tick+700)
    check("closed console performs no timed refresh",refreshes==1)
    admin.open(player,"players",tick+701)
    check("reopening restores explicit preference and interval",session.auto_refresh and session.auto_due_tick==tick+821)
    local before=refreshes
    root.auto_refresh_buckets[tick+800]={player.index};root.auto_refresh_due_tick=tick+800
    gui.refresh_automatically(tick+800)
    check("stale refresh entry cannot consume newer timer",refreshes==before and session.auto_due_tick==tick+821
        and root.auto_refresh_due_tick==tick+821)
    click()
    check("auto refresh off removes timer and reports off",not session.auto_refresh and not session.auto_due_tick
        and not root.auto_refresh_due_tick and session.auto_refresh_button.caption[1]=="ei-admin.auto-refresh-off")
    gui.refresh_automatically(tick+1000)
    check("disabled auto refresh performs no display work",refreshes==before)
    click();gui.close(player.index,true)
    check("destroyed or revoked console ends automatic refresh",not session.auto_refresh and not session.auto_due_tick
        and not root.auto_refresh_due_tick)
    admin.open(player,"players",tick);click()
    player.admin=false
    gui.refresh_automatically(tick+120)
    check("queued auto refresh revalidates native administrator status",not session.root and not session.auto_refresh
        and not session.auto_due_tick and not root.auto_refresh_due_tick)
    player.admin=true
    admin.open(player,"players",tick);click()
    local enabled_before=common.enabled
    common.enabled=function()return false end
    admin.on_configuration_changed(tick)
    common.enabled=enabled_before
    check("toolkit shutdown clears automatic refresh ownership",not session.root and not session.auto_refresh
        and not root.auto_refresh_due_tick and root.auto_refresh_buckets==nil)
    check("shutdown of default modes preserves ordinary character",not player.cheat_mode and body.destructible
        and player.controller_type==defines.controllers.character and player.character==body)
    gui.refresh=original_refresh
    admin.open(player,"players",tick)
    local previous_root=session.root;previous_root.location=dragged
    local previous_draft=session.drafts.reason
    session.auto_refresh_button.destroy()
    admin.open(player,"players",tick)
    check("legacy console toolbar receives one structural rebuild",session.root.valid and session.root~=previous_root)
    check("legacy toolbar rebuild retains position and unapplied draft",session.root.location.x==dragged.x
        and session.root.location.y==dragged.y and session.drafts.reason==previous_draft)
    check("legacy toolbar rebuild defaults timed refresh off",session.auto_refresh_button.valid
        and not session.auto_refresh and not session.auto_due_tick and not root.auto_refresh_due_tick)
    return checks
end
return model
