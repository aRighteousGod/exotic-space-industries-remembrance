-- Native permission ownership checks; isolated fixture only.
local model={}
function model.run(restrictions,common,player,tick)
    local checks={}
    local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
    local function group_id(group)return group and group.valid and group.group_id or "missing" end
    local previous=player.permission_group
    local original=game.permissions.create_group("ei-admin-qc-original-policy")
    original.set_allows_action(defines.input_action.begin_mining,false)
    original.add_player(player)
    check("native original group assigned",player.permission_group==original,{current=group_id(player.permission_group),original=group_id(original)})
    restrictions.set(player,true,tick)
    local entry=common.peek().restrictions[player.index]
    check("restriction saves original custom policy",entry.previous==original,{current=group_id(player.permission_group),previous=group_id(entry.previous),original=group_id(original),overlay=group_id(entry.group)})
    local overlay=entry.group
    local id=overlay.group_id
    overlay.destroy()
    -- Scripted destruction need not emit the user-management GUI event. Forward
    -- its native payload explicitly, exactly as the central dispatcher does.
    restrictions.on_permission_group_deleted{id=id,tick=tick}
    entry=common.peek().restrictions[player.index]
    check("deleted restriction overlay retains inherited policy",entry.previous==original,{current=group_id(player.permission_group),previous=group_id(entry.previous),original=group_id(original),overlay=group_id(entry.group)})
    check("recreated restriction overlay mirrors inherited denial",entry.group.valid
        and player.permission_group==entry.group and not entry.group.allows_action(defines.input_action.begin_mining))
    restrictions.set(player,false,tick)
    check("restriction release restores original custom group",player.permission_group==original)

    restrictions.set(player,true,tick)
    local external=game.permissions.create_group("ei-admin-qc-external-policy")
    external.add_player(player)
    restrictions.refresh(player,tick)
    check("restriction preserves a distinct external assignment",common.peek().restrictions[player.index].previous==external)
    restrictions.set(player,false,tick)
    check("restriction release restores later external group",player.permission_group==external)
    if previous and previous.valid then previous.add_player(player) else game.permissions.get_group(0).add_player(player) end
    original.destroy();external.destroy()
    return checks
end
return model
