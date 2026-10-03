-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- blueprint-ref: .codex/esir/blueprints/admin-tools.md#targeting
-- One native selector for points, rectangles, entities and attack destinations.
-- A completed selection restores the view before any action can teleport a player.
local config=require("lib/admin-tools-config")
local common=require("scripts/control/admin/common")
local model={}
local context
local transitioning={}
function model.configure(ctx) context=ctx end

function model.cancel(player,tick,silent)
    local root=common.peek();local pending=root and root.pending_selection[player.index]
    if not pending then return end
    root.pending_selection[player.index]=nil
    if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name==config.selector then player.cursor_stack.clear() end
    if player.controller_type==defines.controllers.remote then
        if pending.controller==defines.controllers.remote then
            local surface=game.get_surface(pending.surface_index)
            if surface then player.set_controller{type=defines.controllers.remote,surface=surface,position=pending.position} end
        else player.exit_remote_view() end
    end
    -- Native remote view moves a god controller's physical position. Its exit
    -- alone does not restore the location from before the picker was opened.
    if pending.controller==defines.controllers.god and player.controller_type==defines.controllers.god then
        local surface=game.get_surface(pending.surface_index)
        if surface and (player.physical_surface~=surface
            or player.physical_position.x~=pending.position.x or player.physical_position.y~=pending.position.y) then
            local ok,moved=pcall(player.teleport,pending.position,surface)
            if not ok or not moved then common.audit(player,"targeting-return",{surface_index=pending.surface_index,position=pending.position},false) end
        end
    end
    if pending.ghost and prototypes.item[pending.ghost.name] then
        if not prototypes.quality[pending.ghost.quality or "normal"] then pending.ghost.quality="normal" end
        player.cursor_ghost=pending.ghost
    end
    if not silent and context.finished then context.finished(player,tick) end
end

function model.begin(player,kind,session,tick)
    if not common.authorize(player) then return false,"Administrator access is required." end
    if common.state().jails[player.index] then return false,"Release from jail before targeting." end
    model.cancel(player,tick,true)
    local controller=player.controller_type
    if controller~=defines.controllers.character and controller~=defines.controllers.god and controller~=defines.controllers.remote then return false,"This controller cannot target locations." end
    local surface=context.resolve_surface(session.drafts.planet,false)
    if not surface then return false,"Visit this planet to create its surface before targeting it." end
    local ghost=player.cursor_ghost
    ghost=ghost and {name=ghost.name.name,quality=ghost.quality and ghost.quality.name or "normal"}
    if not player.clear_cursor() then return false,"Free an inventory slot before selecting a location." end
    local pending={kind=kind,controller=controller,surface_index=player.surface.index,target_surface_index=surface.index,position=player.position,ghost=ghost}
    common.state().pending_selection[player.index]=pending
    transitioning[player.index]=true
    player.set_controller{type=defines.controllers.remote,surface=surface,position=session.position or player.physical_position}
    local ok=player.cursor_stack and player.cursor_stack.set_stack{name=config.selector,count=1}
    transitioning[player.index]=nil
    if not ok then model.cancel(player,tick);return false,"The targeting cursor is unavailable." end
    if context.hidden then context.hidden(player) end
    player.print({"ei-admin.targeting-hint"})
    return true,"Select a point, rectangle, or entity. Clear the cursor to cancel."
end

function model.on_selected_area(event)
    if event.item~=config.selector then return false end
    local player=game.get_player(event.player_index)
    local root=common.peek();local pending=root and root.pending_selection[event.player_index]
    if not (player and pending and common.authorize(player)) then if player then model.cancel(player,event.tick) end;return true end
    local session=root.sessions[player.index]
    local surface=event.surface or game.get_surface(event.surface_index)
    local area=event.area
    if not (session and surface and surface.valid and area) then model.cancel(player,event.tick);return true end
    local position={x=(area.left_top.x+area.right_bottom.x)/2,y=(area.left_top.y+area.right_bottom.y)/2}
    if pending.kind=="attack" then session.attack_position=position
    else
        session.position=position;session.surface_index=surface.index
        session.drafts.planet=surface.planet and surface.planet.name or surface.name
        session.area=pending.kind=="area" and area or nil
        if pending.kind=="entity" then
            session.entity=event.entities and event.entities[1]
            if session.entity and session.entity.valid then session.position=session.entity.position end
        else session.entity=nil end
    end
    model.cancel(player,event.tick)
    return true
end

function model.on_cursor_changed(event)
    if transitioning[event.player_index] then return end
    local root=common.peek();if not (root and root.pending_selection[event.player_index]) then return end
    local player=game.get_player(event.player_index)
    if player and not (player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name==config.selector) then model.cancel(player,event.tick) end
end

function model.on_player_event(event)
    if transitioning[event.player_index] then return end
    local root=common.peek();local pending=root and root.pending_selection[event.player_index]
    if not pending then return end
    local player=game.get_player(event.player_index)
    if player and (player.controller_type~=defines.controllers.remote
        or player.surface.index~=pending.target_surface_index) then model.cancel(player,event.tick,true) end
end

function model.on_surface_deleted(event)
    local root=common.peek();if not root then return end
    for index,pending in pairs(root.pending_selection) do
        if pending.surface_index==event.surface_index or pending.target_surface_index==event.surface_index then
            local player=game.get_player(index)
            if player then model.cancel(player,event.tick,true) else root.pending_selection[index]=nil end
        end
    end
end

function model.cleanup(tick)
    local root=common.peek();if not root then return end
    for index in pairs(root.pending_selection) do local player=game.get_player(index);if player then model.cancel(player,tick,true) else root.pending_selection[index]=nil end end
end
return model
