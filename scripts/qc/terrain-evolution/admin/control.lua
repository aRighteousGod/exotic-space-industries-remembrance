-- This fixture requires --load-game and a real connected player, never --benchmark.
local function report(done)
    local pass=done
    for _,entry in ipairs(storage.checks or {}) do if not entry.ok then pass=false end end
    helpers.write_file("terrain-admin-qc.json",helpers.table_to_json{
        all_pass=pass,complete=done,checks=storage.checks or {},version=script.active_mods.base,tick=game.tick},false)
    if done then log("TERRAIN_ADMIN_QC COMPLETE") end
end
local function append(entries)
    storage.checks=storage.checks or {}
    for _,entry in ipairs(entries or {}) do storage.checks[#storage.checks+1]=entry end
end
script.on_event(defines.events.on_tick,function(event)
    if storage.complete then return end
    local player=game.connected_players[1]
    if not player then return end
    local ok,error=pcall(function()
        if not storage.started then
            storage.started=event.tick;storage.player_index=player.index
            append(remote.call("esir-terrain-admin-qc","start",player.index,event.tick))
            report(false)
        elseif not storage.idle_started and event.tick>=storage.started+60 then
            local ready,entries=remote.call("esir-terrain-admin-qc","idle_begin",player.index,event.tick)
            append(entries)
            if ready then storage.idle_started=event.tick
            elseif event.tick>storage.started+600 then error("Admin console never became idle") end
        elseif storage.idle_started and event.tick>=storage.idle_started+180 then
            append(remote.call("esir-terrain-admin-qc","finish",player.index,event.tick))
            storage.complete=true;report(true)
        end
    end)
    if not ok then
        append{{name="connected fixture completed without a Lua error",ok=false,detail=tostring(error)}}
        pcall(remote.call,"esir-terrain-admin-qc","cleanup",player.index,event.tick)
        storage.complete=true;report(true)
    end
end)
