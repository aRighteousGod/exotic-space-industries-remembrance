-- Native-paid FIFO rebuild checks for the three-charge Timing profile.
local module={}
local INTERFACE="anisetron-qc-v2"
local NAMES={"ei-anisetron-crown-voice","ei-anisetron-facade-voice"}

local function signature(owner)
    if not owner then return nil end
    local function paid(burst)
        if not burst then return nil end
        return {contract_version=burst.contract_version,quality=burst.quality,
            duration=burst.duration,damage=burst.damage,crown_damage=burst.crown_damage,research_multiplier=burst.research_multiplier,
            facade_damage=burst.facade_damage,start_tick=burst.start_tick,
            crown_range=burst.crown_range,facade_range=burst.facade_range,contact_ticks=burst.contact_ticks,lance=burst.lance,
            end_tick=burst.end_tick,next_contact=burst.next_contact,
            force_index=burst.force_index,surface_index=burst.surface_index,
            opening_target=burst.opening_target}
    end
    local result={burst=paid(owner.burst),queue={}}
    for _,burst in ipairs(owner.queue or {}) do result.queue[#result.queue+1]=paid(burst) end
    return result
end

local function same(left,right)
    if type(left)~=type(right) then return false end
    if type(left)~="table" then return left==right end
    for key,value in pairs(left) do if not same(value,right[key]) then return false end end
    for key in pairs(right) do if left[key]==nil then return false end end
    return true
end

local function try_rebuild(event,check)
    local source=storage.persistence_source
    local value=storage.voice_qc_timing or {}
    storage.voice_qc_timing=value
    local owner=remote.call(INTERFACE,"snapshot",source.unit_number).owner
    if not value.rebuild_tick and owner and owner.burst and #owner.queue>0 then
        local before=signature(owner)
        remote.call(INTERFACE,"rebuild")
        local after=signature(remote.call(INTERFACE,"snapshot",source.unit_number).owner)
        value.rebuild_tick=event.tick
        check("real-nonempty-paid-fifo-rebuild-observed",#before.queue>0,
            {tick=event.tick,queued=#before.queue,openers=storage.openers[source.unit_number].count})
        check("real-nonempty-paid-fifo-rebuild-preserved",same(before,after),{before=before,after=after})
    end
end

-- Invoke after the helper fixture records each native script opener. This can
-- see a just-paid FIFO entry even if main on_tick hands it off before the helper
-- fixture's next on_tick. It never inserts records or ammunition itself.
function module.after_payment(event,check) try_rebuild(event,check) end

function module.tick(event,check)
    try_rebuild(event,check)
    local source=storage.persistence_source
    local value=storage.voice_qc_timing
    if value.rebuild_tick and event.tick==value.rebuild_tick+1 then
        local native=source.surface.find_entities_filtered{name=NAMES,position=source.position,radius=.75}
        local seen={}
        for _,entity in ipairs(native) do seen[entity.name]=(seen[entity.name] or 0)+1 end
        check("native-voices-return-after-nonempty-fifo-rebuild",#native==2
            and seen[NAMES[1]]==1 and seen[NAMES[2]]==1)
    end
    -- This runs BEFORE the Timing profile's completion/report branch at 3650.
    if event.tick-storage.started==3649 then
        check("real-nonempty-paid-fifo-rebuild-required",value.rebuild_tick~=nil)
    end
end

return module
