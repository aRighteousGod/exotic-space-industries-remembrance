local M={}
local fixture=require("fixture-config")
function M.tick(event,surface,check,receipt,status,helper_count)
    local root=storage.burst
    if not root then
        root={started=event.tick,phase="removed",positions={},helpers=status().helpers}
        storage.burst=root
        local row=math.floor(fixture.performance/1000/2)
        for column=0,999 do
            local entity=assert(surface.find_entity("pipe",{column,row}))
            root.positions[#root.positions+1]=entity.position
            entity.destroy{raise_destroy=true}
        end
        check(#root.positions==1000,"exact matched 1000-pipe interior row removed")
        return
    end
    if root.phase=="done" then return end
    local now=status()
    if now.dirty~=0 or now.pending~=0 then return end
    if root.phase=="removed" and event.tick>root.started+2 then
        check(now.helpers==helper_count(surface),"removal burst has no orphan helpers")
        check(now.helpers==root.helpers-(fixture.mode=="esir" and 2999 or 0),"exact interior-row joint removal")
        root.removal_ticks=event.tick-root.started
        root.construction_started=event.tick
        for _,position in ipairs(root.positions) do surface.create_entity{name="pipe",position=position,force="player",snap_to_grid=false,raise_built=true} end
        root.phase="built"
    elseif root.phase=="built" and event.tick>root.construction_started+2 then
        check(now.helpers==root.helpers and now.helpers==helper_count(surface),"construction burst restores exact helper count")
        check(surface.count_entities_filtered{name="pipe"}==fixture.performance,"construction burst restores exact pipe count")
        check(now.counters.max_processed<=(fixture.budget or 256) and now.counters.unsupported==0,"burst work is bounded and supported")
        root.construction_ticks=event.tick-root.construction_started
        root.idle_started=event.tick
        root.idle={topology=now.counters.topology,created=now.counters.created,destroyed=now.counters.destroyed}
        root.phase="idle"
    elseif root.phase=="idle" and event.tick>root.idle_started+60 then
        check(now.counters.topology==root.idle.topology and now.counters.created==root.idle.created and now.counters.destroyed==root.idle.destroyed,"burst settles without continuing topology work or churn")
        root.phase="done"
        receipt("performance-burst",{entities=surface.count_entities_filtered{name="pipe"},removed=#root.positions,removal_ticks=root.removal_ticks,construction_ticks=root.construction_ticks})
    end
end
return M
