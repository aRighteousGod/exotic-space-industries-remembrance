-- Must run in an isolated graphical --load-game client, not --benchmark.
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local player=game.connected_players[1];if not player then return end
    storage.start=storage.start or event.tick;storage.phase=storage.phase or 0
    if storage.phase>0 and storage.captured~=storage.phase and event.tick>=storage.start+(storage.phase-1)*300+240 then
        remote.call("ei-ecology-v2-qc","capture",player.index,storage.phase-1,event.tick);storage.captured=storage.phase
    end
    if event.tick<storage.start+storage.phase*300 then return end
    local ok,result=pcall(remote.call,"ei-ecology-v2-qc","step",player.index,storage.phase,event.tick)
    storage.checks=storage.checks or {}
    if ok then for _,check in ipairs(result or {}) do storage.checks[#storage.checks+1]=check end
    else storage.checks[#storage.checks+1]={name="native fixture exception",ok=false,detail=tostring(result)} end
    storage.phase=storage.phase+1;storage.done=not ok or storage.phase>15
    local pass=true;for _,check in ipairs(storage.checks) do if not check.ok then pass=false end end
    if storage.done then game.set_wait_for_screenshots_to_finish() end
    helpers.write_file("terrain-admin-qc.json",helpers.table_to_json{complete=storage.done,all_pass=pass,checks=storage.checks,version=script.active_mods.base,tick=event.tick},false)
end)
