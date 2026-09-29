--==============================================================================
-- ESIR FILE MAP
-- owns: persistent radar poses and native depth-sorted visual helpers
-- loaded_by: scripts/control/sweeping-radar
-- cadence: existing four control visits/tick; completion only changes a target
-- rebuild_on: lazy bounded repair; target destruction tears down render objects
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local visuals={}
local config=require("lib/sweeping-radar-config")

---@class ESIRRadarVisual
---@field heading number Last displayed angle, clockwise from north.
---@field from number?
---@field delta number?
---@field started integer?
---@field duration number?
---@field completed_tick integer?
---@field epoch integer?
---@field reverse boolean?
---@field serviced integer?
---@field frame integer?
---@field surface integer?
---@field revision integer?
---@field body LuaEntity? Native visual helper; older saves contain a LuaRenderObject until revision repair.
---@field glow LuaRenderObject? Legacy overlay, removed by revision repair.

---@param record ESIRRadarRecord
function visuals.destroy(record)
    local visual=record.visual
    if not visual then return end
    if visual.body and visual.body.valid then visual.body.destroy() end
    if visual.glow and visual.glow.valid then visual.glow.destroy() end
    record.visual=nil
end

---Discard visual debt on suspension/configuration change, retaining the pose.
---@param record ESIRRadarRecord
function visuals.hold(record)
    if record.visual then record.visual.delta=nil;record.visual.epoch=nil end
end

---Coalesce completed observations into one bounded interpolation, never a queue.
---@param record ESIRRadarRecord
---@param tick integer
function visuals.completed(record,tick)
    local visual=record.visual or {heading=record.heading}
    record.visual=visual
    local delta=(record.heading-visual.heading)%360
    local initial=visual.epoch~=record.epoch or visual.reverse~=record.reverse
    -- Within a one-degree geometry bucket, candidate order can wiggle. Do not
    -- turn that tiny reverse correction into an almost complete revolution.
    if initial or record.effective.mode==5 or math.min(delta,360-delta)<1 then
        delta=(delta+180)%360-180
    elseif record.reverse and delta>0 then delta=delta-360 end
    visual.from=visual.heading;visual.delta=delta;visual.started=tick
    visual.duration=math.max(1,math.min(config.art_max_trail_ticks,
        visual.completed_tick and tick-visual.completed_tick or 60/(record.rate*record.effective.speed/100)))
    visual.completed_tick=tick;visual.epoch=record.epoch;visual.reverse=record.reverse
end

---@param name string
---@param heading number
---@return integer frame Zero-based source frame.
function visuals.frame(name,heading)
    return (math.floor((heading%360)*config.art_frames/360)+config.art[name].north)%config.art_frames
end

---@param record ESIRRadarRecord
---@param tick integer
function visuals.service(record,tick)
    local entity=record.entity
    local visual=record.visual or {heading=record.heading}
    record.visual=visual
    if visual.serviced==tick then return false end
    visual.serviced=tick
    local powered=ei_lib.entity_check(record.power)
        and record.power.energy>=config.hardware[entity.name].idle/60 and not entity.frozen
    if not powered or not record.running or record.reset_pending then visuals.hold(record)
    elseif visual.delta then
        local progress=math.min(1,(tick-visual.started)/visual.duration)
        visual.heading=(visual.from+visual.delta*progress)%360
        if progress==1 then visual.delta=nil end
    end
    if visual.surface~=entity.surface.index or visual.revision~=config.art_revision then
        if visual.body and visual.body.valid then visual.body.destroy() end
        if visual.glow and visual.glow.valid then visual.glow.destroy() end
        visual.body=nil;visual.glow=nil;visual.frame=nil
        visual.surface=entity.surface.index;visual.revision=config.art_revision
    end
    local frame=visuals.frame(entity.name,visual.heading)
    local page=math.floor(frame/config.art_page_frames)+1
    local offset=frame%config.art_page_frames
    -- LuaRendering overlays do not participate in native entity Y sorting.
    -- A single non-colliding native helper composites body, shadow and glow.
    local name=entity.name.."-visual-"..page..(config.art[entity.name].glow and powered and "-lit" or "")
    local object=visual.body
    if object and object.valid and object.name~=name then object.destroy();object=nil end
    if not object or not object.valid then
        object=entity.surface.create_entity{name=name,position=entity.position,force=entity.force,
            create_build_effect_smoke=false}
        visual.body=object
        if not object then return true end
        object.destructible=false;object.operable=false
        object.graphics_variation=offset+1
    else
        local a,b=object.position,entity.position
        if a.x~=b.x or a.y~=b.y then object.teleport(b) end
        if object.force~=entity.force then object.force=entity.force end
        if visual.frame~=frame then object.graphics_variation=offset+1 end
    end
    visual.frame=frame
    return true
end

---Ghost helpers are removed by the owner's destruction registration; no tick service.
---@param root table
---@param entity LuaEntity
function visuals.ghost(root,entity)
    if not config.art[entity.ghost_name] then return end
    root.ghost_art=root.ghost_art or {}
    local id=entity.unit_number
    local previous=root.ghost_art[id]
    if previous and previous.object.valid and previous.revision==config.art_revision then return end
    if previous and previous.object.valid then previous.object.destroy() end
    local object=entity.surface.create_entity{name=entity.ghost_name.."-visual-ghost",position=entity.position,
        force=entity.force,create_build_effect_smoke=false}
    if not object then return end
    object.destructible=false;object.operable=false
    local registration=previous and previous.registration or script.register_on_object_destroyed(entity)
    root.ghost_art[id]={object=object,registration=registration,revision=config.art_revision}
    root.registrations[registration]={id=id,kind="ghost-art"}
end
return visuals
