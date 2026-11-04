--==============================================================================
-- ESIR FILE MAP
-- owns: native combustion process custody during turbine topology changes
-- loaded_by: scripts/control/combustion-turbine.lua
-- cadence: build, clone, mode switch and pressure transitions only
-- forwarded_events: none
-- storage_roots: storage.ei.combustion_turbine.turbines_by_unit
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner rebuild and configuration change
--==============================================================================
-- blueprint: .codex/esir/blueprints/combustion-turbine.md#contract
-- Native process custody at topology changes; never called to produce energy.
local config = require("lib/combustion-turbine-config")
local model = {}

---@class EiCombustionProcess
---@field oxygen Fluid?
---@field working Fluid?
---@field progress number
---@field energy number

---@class EiCombustionProcessOwner
---@field generator LuaEntity?
---@field dormant_process EiCombustionProcess?
---@field atmospheric_heat number?
---@field electrical_reserve number?

---@class EiCombustionProcessSnapshot
---@field process EiCombustionProcess?
---@field atmospheric_heat number
---@field electrical_energy number
---@field fuel Fluid?
---@field fuel_segment boolean?

function model.is_oxygen(entity)
    return entity.name==config.oxygen_solid or entity.name==config.oxygen_fluid or entity.name==config.oxygen_ash_solid
end

function model.is_ash(entity)
    return entity.name==config.ash_solid or entity.name==config.oxygen_ash_solid
end

function model.generator_name(entity)
    return model.is_ash(entity) and config.ash_generator or config.generator
end

function model.forced(surface)
    return surface.get_property("pressure") < config.atmospheric_oxygen_min_pressure
end

function model.oxygen_index(entity) return entity.name==config.oxygen_fluid and 2 or 1 end
function model.working_index(entity) return entity.name==config.oxygen_fluid and 3 or 2 end
function model.fuel_index(entity)
    return (entity.name==config.fluid or entity.name==config.oxygen_fluid) and 1 or nil
end

---@param entity LuaEntity
---@return LuaEntity|nil
function model.create_generator(entity)
    local ok, generator=pcall(entity.surface.create_entity,{
        name=model.generator_name(entity),position=entity.position,direction=entity.direction,
        force=entity.force,quality="normal",create_build_effect_smoke=false,raise_built=false})
    if not ok or not (generator and generator.valid) then return nil end
    generator.destructible=false
    generator.minable_flag=false
    generator.operable=false
    generator.disabled_by_script=true
    return generator
end

---@param entity LuaEntity
---@param generator LuaEntity
function model.connect(entity,generator)
    if model.is_oxygen(entity) then
        entity.add_fluid_box_linked_connection(1,generator,1)
        generator.disabled_by_script=entity.disabled_by_script
    else
        generator.remove_fluid_box_linked_connection(1)
        generator.disabled_by_script=true
    end
end

---@param entity LuaEntity
---@param record EiCombustionProcessOwner
---@return EiCombustionProcessSnapshot
function model.capture(entity,record)
    local state={process=record.dormant_process,atmospheric_heat=record.atmospheric_heat or 0,
        electrical_energy=entity.energy+(record.electrical_reserve or 0)}
    local generator=record.generator
    if model.is_oxygen(entity) then
        state.process={oxygen=entity.get_fluid(model.oxygen_index(entity)),
            working=entity.get_fluid(model.working_index(entity)),
            progress=entity.crafting_progress,energy=entity.energy}
        state.electrical_energy=(generator and generator.valid and generator.energy or 0)
            +(record.electrical_reserve or 0)
    elseif entity.burner then
        state.atmospheric_heat=entity.burner.heat
    end
    local index=model.fuel_index(entity)
    if index then
        state.fuel_segment=entity.has_fluid_segment(index)
        state.fuel=state.fuel_segment and entity.get_fluid_segment_fluid(index) or entity.get_fluid(index)
    end
    return state
end

-- Copy while the source survives, so a failed candidate never consumes fuel.
function model.copy_burner(source,destination)
    local before,after=source.burner,destination.burner
    if not (before and after) then return end
    for index=1,#before.inventory do after.inventory[index].set_stack(before.inventory[index]) end
    after.currently_burning=before.currently_burning
    after.remaining_burning_fuel=before.remaining_burning_fuel
    if before.burnt_result_inventory and after.burnt_result_inventory then
        for index=1,math.min(#before.burnt_result_inventory,#after.burnt_result_inventory) do
            after.burnt_result_inventory[index].set_stack(before.burnt_result_inventory[index])
        end
    end
end

local function restore_local(entity,index,fluid)
    if fluid then entity.set_fluid(index,fluid) else entity.clear_fluid(index) end
end

-- Exhaust can be connected to player pipes. Snapshot before creating an
-- overlapping helper; restore the segment total only after removing the old one.
---@param generator LuaEntity
---@return table
function model.capture_generator(generator)
    return {working=generator.get_fluid(1),exhaust=generator.has_fluid_segment(2)
        and generator.get_fluid_segment_fluid(2) or generator.get_fluid(2),energy=generator.energy}
end

---@param generator LuaEntity
---@param state table
function model.restore_generator(generator,state)
    restore_local(generator,1,state.working)
    if generator.has_fluid_segment(2) then
        if state.exhaust then generator.set_fluid_segment_fluid(2,state.exhaust)
        else generator.clear_fluid_segment_fluid(2) end
    else restore_local(generator,2,state.exhaust) end
    generator.energy=state.energy
end

-- Filled generators cannot change their axis through direction/rotate. Create
-- the new orientation first, then transfer the native buffers without ticking.
---@param entity LuaEntity
---@param generator LuaEntity
---@return LuaEntity|nil
function model.align_generator(entity,generator)
    if generator.direction==entity.direction and generator.name==model.generator_name(entity) then
        if generator.position.x~=entity.position.x or generator.position.y~=entity.position.y then
            if not generator.teleport(entity.position) then return nil end
        end
        return generator
    end
    local saved=model.capture_generator(generator)
    local replacement=model.create_generator(entity)
    if not replacement then return nil end
    generator.destroy{raise_destroy=false}
    model.restore_generator(replacement,saved)
    return replacement, math.max(0,saved.energy-replacement.energy)
end

-- Clone is explicitly duplicative; its hidden companion must follow the body.
---@param source LuaEntity
---@param destination LuaEntity
function model.copy_generator(source,destination)
    restore_local(destination,1,source.get_fluid(1))
    restore_local(destination,2,source.get_fluid(2))
    destination.energy=source.energy
end

-- Restore connected totals only after the overlapping old shell is removed.
---@param entity LuaEntity
---@param record EiCombustionProcessOwner
---@param state EiCombustionProcessSnapshot
---@param preserve_fuel boolean
function model.restore(entity,record,state,preserve_fuel)
    record.dormant_process=state.process
    record.atmospheric_heat=state.atmospheric_heat
    local index=model.fuel_index(entity)
    if preserve_fuel and index then
        if entity.has_fluid_segment(index) then
            if state.fuel then entity.set_fluid_segment_fluid(index,state.fuel)
            else entity.clear_fluid_segment_fluid(index) end
        else restore_local(entity,index,state.fuel) end
    end
    local generator=record.generator
    if model.is_oxygen(entity) then
        local process=state.process or {}
        restore_local(entity,model.oxygen_index(entity),process.oxygen)
        restore_local(entity,model.working_index(entity),process.working)
        entity.crafting_progress=process.progress or 0
        entity.energy=process.energy or 0
        record.dormant_process=nil
        generator.energy=state.electrical_energy
        -- Quality can give the atmospheric body a larger electrical buffer.
        -- Keep charge that the fixed-12-MW companion cannot accept dormant,
        -- to be restored at a later topology change. Never service it on tick.
        record.electrical_reserve=math.max(0,state.electrical_energy-generator.energy)
    else
        entity.energy=state.electrical_energy
        record.electrical_reserve=math.max(0,state.electrical_energy-entity.energy)
        if entity.burner then entity.burner.heat=state.atmospheric_heat end
        if generator and generator.valid then generator.energy=0 end
    end
    if generator and generator.valid then model.connect(entity,generator) end
end

return model
