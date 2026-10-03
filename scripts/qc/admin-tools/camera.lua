-- Native camera action/UI lifecycle checks through the real ESIR coordinator.
-- Demotion callback forwarding is explicit; this does not claim that assigning
-- LuaPlayer.admin itself raises a native event.
local model={}
function model.run(admin,lib,common,player,tick)
    local checks={}
    local function check(name,ok,detail) checks[#checks+1]={name=name,ok=not not ok,detail=detail} end
    local function action(name,args) return admin.execute(player,name,args,tick) end
    lib.camera_close_owner("admin",player.index)
    local ok=action("camera-entity",{})
    check("camera action rejects missing entity",not ok)
    local item=assert(player.physical_surface.create_entity{name="item-on-ground",position=player.physical_position,stack={name="iron-plate",count=1}})
    item.destroy()
    ok=action("camera-entity",{entity=item})
    check("camera action rejects destroyed entity",not ok)
    ok=action("camera-player",{player_index=4294967295})
    check("camera action rejects nonexistent player",not ok)
    ok=action("camera-player",{})
    check("camera action rejects missing player",not ok)
    local windows=storage.ei_camera_windows and storage.ei_camera_windows.windows or {}
    check("rejected camera actions create no admin windows",not windows[player.index..":admin:player"] and not windows[player.index..":admin:entity"])
    ok=action("camera-player",{player_index=player.index})
    local entry=storage.ei_camera_windows.windows[player.index..":admin:player"]
    check("valid camera player action opens",ok and entry and entry.root.valid)
    assert(entry,"Native player camera missing")
    local frame=entry.root
    local zoom=entry.camera.zoom
    admin.on_gui_click{player_index=player.index,element=frame,tick=tick}
    check("camera frame click does not change zoom",entry.camera.zoom==zoom)
    local plus,minus
    for _,element in pairs(entry.title.children) do
        if element.tags.action=="plus" then plus=element elseif element.tags.action=="minus" then minus=element end
    end
    admin.on_gui_click{player_index=player.index,element=plus,tick=tick}
    check("camera explicit plus changes zoom",entry.camera.zoom>zoom)
    admin.on_gui_click{player_index=player.index,element=minus,tick=tick}
    check("camera explicit minus restores zoom",math.abs(entry.camera.zoom-zoom)<0.000001)
    local independent=assert(lib.camera_open(player,{owner="camera_qc",id="independent",player_index=player.index},tick))
    admin.open(player,"cameras",tick)
    local session=common.peek().sessions[player.index]
    local console=session.root
    player.admin=false
    admin.on_player_event{player_index=player.index,name=defines.events.on_player_demoted,tick=tick}
    check("forwarded demotion destroys admin console",not console.valid)
    check("forwarded demotion closes admin cameras",not frame.valid and not storage.ei_camera_windows.windows[player.index..":admin:player"])
    check("admin demotion preserves independent camera owner",independent.valid)
    ok=action("camera-player",{player_index=player.index})
    check("demoted actor cannot reopen admin camera",not ok and not storage.ei_camera_windows.windows[player.index..":admin:player"])
    lib.camera_close_owner("camera_qc",player.index)
    player.admin=true
    admin.on_player_event{player_index=player.index,name=defines.events.on_player_promoted,tick=tick}
    return checks
end
return model
