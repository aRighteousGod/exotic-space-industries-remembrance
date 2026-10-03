-- Test real cursor, remote-controller and location handoff through the owner.
local model={}
function model.run(admin,targeting,common,player,tick)
    local checks={}
    local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
    if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
    if not player.character then player.set_controller{type=defines.controllers.god};player.create_character() end
    admin.open(player,"players",tick)
    local state=common.state();local session=state.sessions[player.index]
    local origin_surface=player.physical_surface
    local origin={x=player.physical_position.x,y=player.physical_position.y}
    session.drafts.planet=origin_surface.planet and origin_surface.planet.name or origin_surface.name
    player.clear_cursor();player.cursor_ghost={name="iron-plate",quality="rare"}
    local ok,why=targeting.begin(player,"point",session,tick)
    check("native map picker opens remote controller",ok and player.controller_type==defines.controllers.remote,why)
    check("targeting preserves cursor ghost record",state.pending_selection[player.index] and state.pending_selection[player.index].ghost~=nil)
    local destination=origin_surface.find_non_colliding_position(player.character and player.character.name or "character",{origin.x+8,origin.y},16,0.5)
    assert(destination,"No safe targeting fixture destination")
    targeting.on_selected_area{player_index=player.index,item="ei-admin-location-selector",surface=origin_surface,
        area={left_top={x=destination.x-0.1,y=destination.y-0.1},right_bottom={x=destination.x+0.1,y=destination.y+0.1}},tick=tick}
    check("selection restores original controller before execution",player.controller_type==defines.controllers.character and state.pending_selection[player.index]==nil)
    check("selection restores quality cursor ghost",player.cursor_ghost and player.cursor_ghost.name.name=="iron-plate" and player.cursor_ghost.quality.name=="rare")
    local moved,message=admin.execute(player,"travel",{player_index=player.index,surface_index=origin_surface.index,position=destination},tick)
    check("targeted self travel succeeds",moved,message)
    check("picker restoration cannot undo self teleport",math.abs(player.physical_position.x-destination.x)<0.1 and math.abs(player.physical_position.y-destination.y)<0.1)
    targeting.begin(player,"point",session,tick)
    player.cursor_stack.clear()
    targeting.on_cursor_changed{player_index=player.index,tick=tick}
    check("cleared picker cursor cancels session",state.pending_selection[player.index]==nil and player.controller_type==defines.controllers.character)
    targeting.begin(player,"point",session,tick)
    player.admin=false
    admin.on_player_event{player_index=player.index,tick=tick}
    check("demotion cancels active picker",state.pending_selection[player.index]==nil and player.controller_type==defines.controllers.character)
    player.admin=true
    local body=player.character
    local entered,reason=admin.execute(player,"god",{player_index=player.index,enabled=true},tick)
    check("god picker fixture enters owned mode",entered,reason)
    local god_surface=game.create_surface("ei-admin-qc-god-picker",{width=64,height=64})
    assert(player.teleport({8,12},god_surface))
    local god_origin=player.physical_position
    session.drafts.planet=origin_surface.planet and origin_surface.planet.name or origin_surface.name
    local selected,selection_message=targeting.begin(player,"point",session,tick)
    check("god picker targets another surface",selected and player.surface==origin_surface,selection_message)
    targeting.cancel(player,tick,true)
    check("god picker cancellation restores original surface and position",player.controller_type==defines.controllers.god
        and player.physical_surface==god_surface and player.physical_position.x==god_origin.x and player.physical_position.y==god_origin.y,
        {surface=player.physical_surface.name,position=player.physical_position})
    local returned,return_message=admin.execute(player,"god",{player_index=player.index,enabled=false},tick)
    check("god picker fixture returns original character",returned and player.character==body,return_message)
    return checks
end
return model
