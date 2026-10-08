-- Fixture-only bridge, appended to the STAGED ESIR control.lua by the runner.
-- It has ESIR's storage context and local ei_anisetron; it is never shipped.
local anisetron_qc_art=require("lib/anisetron-graphics")
local anisetron_qc_interface="anisetron-qc-v2"
local function anisetron_qc_valid(entity) return entity and entity.valid end
local function anisetron_qc_payload(burst)
    if not burst then return nil end
    local result={contract_version=burst.contract_version,quality=burst.quality,
        duration=burst.duration,damage=burst.damage,crown_damage=burst.crown_damage,research_multiplier=burst.research_multiplier,
        facade_damage=burst.facade_damage,start_tick=burst.start_tick,end_tick=burst.end_tick,
        crown_range=burst.crown_range,facade_range=burst.facade_range,contact_ticks=burst.contact_ticks,
        lance=burst.lance and {level=burst.lance.level,multiplier=burst.lance.multiplier,phase=burst.lance.phase,
            axial=burst.lance.axial,collapse=burst.lance.collapse,testament=burst.lance.testament,
            wound_step=burst.lance.wound_step,wound_cap=burst.lance.wound_cap,wound_timeout=burst.lance.wound_timeout},
        next_contact=burst.next_contact,force_index=burst.force_index,surface_index=burst.surface_index,
        opening_target=anisetron_qc_valid(burst.opening_target) and burst.opening_target.unit_number or nil}
    for _,emitter in ipairs{"crown","facade"} do
        local channel=burst.channels and burst.channels[emitter]
        if channel then
            local index=channel.muzzle_index
            local offsets=anisetron_qc_art[emitter]
            local beam_valid=anisetron_qc_valid(channel.beam)
            local beam_target=beam_valid and channel.beam.get_beam_target() or nil
            local beam_source=beam_valid and channel.beam.get_beam_source() or nil
            result[emitter]={muzzle_index=index,emitter=channel.emitter,
                aim_angle=channel.aim_angle,acquired=channel.acquired,
                logical_endpoint=channel.endpoint,contact_tip=channel.contact_tip,
                contact_until=channel.contact_until,
                beam=beam_valid,beam_name=beam_valid and channel.beam.name or nil,beam_light_index=channel.beam_light_index,
                target=anisetron_qc_valid(channel.target) and channel.target.unit_number or nil,
                endpoint=beam_target and (beam_target.position or
                    anisetron_qc_valid(beam_target.entity) and beam_target.entity.position) or nil,
                beam_target_entity=beam_target and anisetron_qc_valid(beam_target.entity)
                    and beam_target.entity.unit_number or nil,
                beam_source_entity=beam_source and anisetron_qc_valid(beam_source.entity)
                    and beam_source.entity.unit_number or nil,
                beam_source_position=beam_source and beam_source.position or nil,
                offset=offsets and index and offsets[index] and offsets[index][2] or nil}
        end
    end
    result.legacy_beam=anisetron_qc_valid(burst.beam)
    return result
end
local function anisetron_qc_owner(id)
    local runtime=storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    local owner=runtime and runtime.active and runtime.active[id]
    if not owner then return nil end
    local result={burst=anisetron_qc_payload(owner.burst),queue={}}
    local queue=owner.queue or {}
    for index=queue.head or 1,queue.tail or 0 do
        local burst=queue.items[index]
        if burst then result.queue[#result.queue+1]=anisetron_qc_payload(burst) end
    end
    result.crown_beam=result.burst and result.burst.crown and result.burst.crown.beam or false
    result.facade_beam=result.burst and result.burst.facade and result.burst.facade.beam or false
    return result
end
if remote.interfaces[anisetron_qc_interface] then remote.remove_interface(anisetron_qc_interface) end
remote.add_interface(anisetron_qc_interface,{
    movement_state=function(id)
        local runtime=storage.ei and storage.ei.runtime_scheduler
            and storage.ei.runtime_scheduler.modules.anisetron
        local visual=runtime and runtime.visuals
        local record=visual and visual.tracked[id]
        if not record then return nil end
        local strands=0
        for _,handle in pairs(record.strands or {}) do
            if handle and handle.valid then strands=strands+1 end
        end
        return {last_position=record.last_position,last_tick=record.last_tick,
            surface_index=record.surface_index,moving=record.moving,strands=strands,
            attached=visual.attached and visual.attached[id]~=nil or false}
    end,
    projection=function(entity)
        assert(entity and entity.valid and entity.name=="ei-anisetron")
        local count=anisetron_qc_art.direction_count or #anisetron_qc_art.muzzle
        local index=math.floor(entity.torso_orientation*count+.5)%count+1
        local result={direction_count=count,index=index,keel_tips={},render_attachment_lift=0}
        for tip=1,#anisetron_qc_art.keel_tips do result.keel_tips[tip]=anisetron_qc_art.keel_tips[tip][index][2] end
        return result
    end,
    snapshot=function(id)
        return {visuals=ei_anisetron.get_qc_snapshot(),owner=id and anisetron_qc_owner(id) or nil,
            direction_count=anisetron_qc_art.direction_count or #(anisetron_qc_art.muzzle or {}),
            render_attachment_lift=0}
    end,
    service=function(limit)
        return ei_anisetron.service_visuals_for_qc(limit,{tick=game.tick})
    end,
    rebuild=function()
        ei_anisetron.rebuild_visuals(game.tick)
    end,
    mark_paid_queue_legacy=function(id)
        local runtime=storage.ei and storage.ei.runtime_scheduler
            and storage.ei.runtime_scheduler.modules.anisetron
        local owner=assert(runtime and runtime.active[id],"No native-paid ANISETRON owner")
        local queue=owner.queue
        local converted=0
        for index=queue.head,queue.tail do
            local burst=queue.items[index]
            if burst then
                assert(not burst.start_tick and not burst.channels,"Only unstarted native-paid FIFO entries can be converted")
                assert(burst.damage==240*prototypes.quality[burst.quality].default_multiplier,
                    "Legacy damage must already be the paid ammo-quality snapshot")
                burst.contract_version=nil;burst.crown_damage=nil;burst.facade_damage=nil
                burst.channels=nil;burst.opening_target=nil
                burst.lance=nil;burst.crown_range=nil;burst.facade_range=nil;burst.contact_ticks=nil
                converted=converted+1
            end
        end
        return converted
    end,
})
