-- Helper-mod audio lifecycle checks called by the native fixture.
-- It creates one isolated, genuinely paid source; all other lifecycle actors
-- are reused. No shipping state, payment or damage is fabricated.
local module={}
local NAMES={"ei-anisetron-crown-voice","ei-anisetron-facade-voice"}
local INTERFACE="anisetron-qc-v2"

local function voices(surface,position)
    return surface.find_entities_filtered{name=NAMES,position=position,radius=.75}
end

local function by_name(surface,position)
    local result={}
    for _,entity in ipairs(voices(surface,position)) do
        result[entity.name]=result[entity.name] or {}
        table.insert(result[entity.name],entity)
    end
    return result
end

local function core(source)
    local result={}
    for _,entity in ipairs(source.surface.find_entities_filtered{type="beam",
        area={{source.position.x-32,source.position.y-32},{source.position.x+32,source.position.y+32}}}) do
        local base_name=entity.name:gsub("%-light%-%d+$", "")
        if base_name=="ei-anisetron-crown-beam" or base_name=="ei-anisetron-beam" then
            local origin=entity.get_beam_source()
            if origin and origin.entity==source then result[base_name]=entity end
        end
    end
    return result
end

local function owned_pair(source)
    local found=by_name(source.surface,source.position)
    local pair={};local valid=true
    for _,name in ipairs(NAMES) do
        local list=found[name] or {}
        valid=valid and #list==1
        local entity=list[1]
        if entity then
            valid=valid and not entity.destructible and not entity.is_military_target
                and entity.force==source.force and entity.surface==source.surface
                and math.abs(entity.position.x-source.position.x)<.01
                and math.abs(entity.position.y-source.position.y)<.01
            pair[name]=entity
        end
    end
    return valid,pair
end

function module.setup(tick,vehicle,target)
    local source=vehicle(storage.surface,{250,190},1,true)
    storage.voice_qc={source=source,target=target(storage.surface,{250,170}),
        started=tick,source_position={x=250,y=190}}
end

-- Register this as the helper fixture's on_entity_cloned callback. The event is
-- native and instant; a nil return alone could otherwise mean clone failure.
function module.on_cloned(event)
    local value=storage.voice_qc
    if value and value.clone_source and event.source==value.clone_source then
        value.clone_observed=true
        value.clone_destination_survived=event.destination and event.destination.valid or false
    end
end

local function channel_presence(source)
    local beams=core(source)
    local found=by_name(source.surface,source.position)
    local result={};local matches=true
    for _,emitter in ipairs{"crown","facade"} do
        local beam=beams[emitter=="crown" and "ei-anisetron-crown-beam" or "ei-anisetron-beam"]
        local list=found["ei-anisetron-"..emitter.."-voice"] or {}
        matches=matches and #list==(beam and 1 or 0)
        local target=beam and beam.get_beam_target()
        result[emitter]={beam=beam~=nil,voices=#list,endpoint=target and target.position,
            target_entity=target and target.entity and target.entity.valid and target.entity.unit_number or nil}
    end
    return matches,result
end

function module.tick(event,check)
    local value=storage.voice_qc
    if not value then return end
    local t=event.tick-storage.started
    local source=value.source
    -- Capture native helpers before the existing source-removal block runs.
    if storage.remove_source and storage.remove_source.valid then
        local candidates=voices(storage.surface,storage.remove_source.position)
        if #candidates==2 then
            value.remove_refs=candidates
            value.remove_position=storage.remove_source.position
        end
    end
    if storage.source_removed_tick and event.tick==storage.source_removed_tick+1 then
        local gone=value.remove_refs and #value.remove_refs==2
        for _,entity in ipairs(value.remove_refs or {}) do gone=gone and not entity.valid end
        check("native-voices-cancel-with-source",gone and
            #voices(storage.surface,value.remove_position or {x=-90,y=-90})==0)
    end
    if t==40 then
        local valid,pair=owned_pair(source)
        check("two-native-voices-owned-by-two-channels",valid)
        value.initial=pair;value.initial_core=core(source)
        check("native-voice-core-pair-ready",value.initial_core["ei-anisetron-crown-beam"]~=nil
            and value.initial_core["ei-anisetron-beam"]~=nil)
        check("idle-has-no-native-firing-voice",#voices(storage.surface,storage.fx_idle.position)==0)
    elseif t==44 then
        source.active=false
        source.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        source.orientation=.03125;source.torso_orientation=.03125
    elseif t==50 then
        source.orientation=.0625;source.torso_orientation=.0625
    elseif t==55 then
        local valid,pair=owned_pair(source)
        local beams=core(source)
        local reused=value.initial and valid
        for _,name in ipairs(NAMES) do reused=reused and pair[name]==value.initial[name] end
        check("native-voice-survives-muzzle-index-recreation",reused)
        check("native-core-recreated-during-voice-probe",beams["ei-anisetron-crown-beam"]
            and beams["ei-anisetron-beam"] and value.initial_core
            and beams["ei-anisetron-crown-beam"]~=value.initial_core["ei-anisetron-crown-beam"]
            and beams["ei-anisetron-beam"]~=value.initial_core["ei-anisetron-beam"])
    elseif t==75 then
        local valid,pair=owned_pair(source)
        local original=valid and pair[NAMES[1]]
        value.clone_source=original
        local clone=original and original.clone{position={253,190},surface=source.surface,
            force=source.force,create_build_effect_smoke=false}
        local destination_count=#voices(source.surface,{253,190})
        local observed_removed=value.clone_observed==true and value.clone_destination_survived==false
            and (not clone or not clone.valid) and destination_count==0
        local native_refusal=clone==nil and value.clone_observed~=true and destination_count==0
        check("native-clone-cannot-leave-unowned-voice",(observed_removed or native_refusal)
            and original and original.valid,
            {mode=observed_removed and "native-event-cleanup" or native_refusal and "native-refusal-no-event" or "unexpected",
             event_observed=value.clone_observed==true,destination_survived=value.clone_destination_survived,
             return_nil=clone==nil,return_valid=clone and clone.valid or false,
             destination_count=destination_count,original_valid=original and original.valid or false})
        local still_owned,after=owned_pair(source)
        check("native-clone-preserves-original-voice",still_owned and after[NAMES[1]]==original)
    elseif t==80 then
        -- No raised build event: deliberate ownerless helper for exact config cleanup.
        value.orphan=source.surface.create_entity{name=NAMES[1],position={290,190},force=source.force}
        check("native-orphan-voice-prepared",value.orphan and value.orphan.valid)
    elseif t==140 then
        -- The crown may legally retarget another nearby enemy after the original
        -- target becomes friendly. Voice presence must follow actual core beams.
        local matches,detail=channel_presence(storage.switcher)
        local paid=remote.call(INTERFACE,"snapshot",storage.switcher.unit_number).owner
        local targets=paid and paid.burst
        local friendly_id=storage.switch_target.unit_number
        local skips_friend=targets and targets.crown and targets.facade
            and targets.crown.target~=friendly_id and targets.facade.target~=friendly_id
        check("friendly-target-skipped-native-voices-match-core",matches and skips_friend,detail)
        local cease_matches,cease_detail=channel_presence(storage.cease)
        check("cease-fire-voices-follow-hostile-retarget",cease_matches,cease_detail)
    elseif t==150 then
        -- Call this module AFTER v2.tick, whose existing branch invokes rebuild.
        check("cosmetic-rebuild-purges-orphan-voice",value.orphan and not value.orphan.valid
            and #voices(source.surface,{290,190})==0)
        check("cosmetic-rebuild-leaves-no-duplicate-voice",#voices(source.surface,source.position)<=2)
    elseif t==160 then
        local valid,pair=owned_pair(source)
        check("paid-native-voices-return-after-rebuild",valid)
        value.after_rebuild=pair
    elseif t==200 then
        check("force-change-cleans-native-voices",#voices(storage.surface,storage.source_force.position)==0)
        check("surface-change-cleans-old-native-voices",#voices(storage.surface,{x=-220,y=100})==0)
        check("surface-change-cleans-new-native-voices",#voices(storage.source_transfer.surface,
            storage.source_transfer.position)==0)
    elseif t==1230 then
        local owner=remote.call(INTERFACE,"snapshot",source.unit_number).owner
        local record=storage.source_damage[source.unit_number]
        check("native-voices-expire-with-paid-deadline",owner==nil and
            #voices(source.surface,source.position)==0)
        check("native-voice-probe-preserves-paid-combat",record and record.crown.count==100
            and record.facade.count==100 and record.crown.total==32000 and record.facade.total==16000
            and record.legacy.count==0 and record.unexpected==0
            and storage.openers[source.unit_number].count==1)
    end
end

return module
