--==============================================================================
-- ESIR FILE MAP
-- owns: quality placement repair for air-scrubber 0.2.9
-- loaded_by: control.lua
-- cadence: build/clone events and one configuration-change scan; no tick work
-- forwarded_events: normalize, rebuild, is_notifying
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/startup-and-integration.md#contract
-- blueprint-ref: .codex/esir/blueprints/startup-and-integration.md#scrubber
local lib = require("lib/lib")
local model = {}
local notifying

function model.is_notifying(entity) return entity ~= nil and entity == notifying end

---@param entity LuaEntity|nil
---@return LuaEntity|nil
function model.normalize(entity)
    if not lib.entity_check(entity) or entity.name ~= "atan-air-scrubber" or entity.quality.level == 0 then return entity end
    local name = entity.quality.name .. "-atan-air-scrubber"
    local target = prototypes.entity[name]
    if not target then return entity end
    -- The accepted fork has one source slot, one result slot and no fluids or
    -- modules. Refuse unreviewed optional mutations rather than discard overflow.
    local source = entity.prototype
    if entity.fluids_count ~= 0 or next(target.fluidbox_prototypes) ~= nil
        or (source.module_inventory_size or 0) ~= 0 or (target.module_inventory_size or 0) ~= 0
        or source.get_inventory_size(defines.inventory.crafter_input, entity.quality) ~= 1
        or target.get_inventory_size(defines.inventory.crafter_input, entity.quality) ~= 1
        or source.get_inventory_size(defines.inventory.crafter_output, entity.quality) ~= 1
        or target.get_inventory_size(defines.inventory.crafter_output, entity.quality) ~= 1 then
        log("ESIR scrubber normalization skipped: incompatible storage shape")
        return entity
    end
    local parameters = {name=name, position=entity.position, force=entity.force,
        direction=entity.direction, mirror=entity.mirroring, quality=entity.quality}
    local snapshot = {}
    for _, key in ipairs({"health","energy","crafting_progress","bonus_progress","products_finished",
        "disabled_by_script","minable_flag","destructible","operable","rotatable","last_user"}) do
        snapshot[key] = entity[key]
    end
    -- can_fast_replace rejects these hidden identity variants even when native
    -- replacement succeeds. Require our family and verify actual replacement.
    if not source.fast_replaceable_group or source.fast_replaceable_group ~= target.fast_replaceable_group then return entity end
    parameters.fast_replace = true
    parameters.spill = false
    parameters.create_build_effect_smoke = false
    parameters.raise_built = false
    entity.minable_flag = true
    local replacement = entity.surface.create_entity(parameters)
    if not replacement then
        entity.minable_flag = snapshot.minable_flag
        return entity
    end
    if entity.valid then
        -- Native creation may place without replacing. Keep the populated source
        -- authoritative and remove only the new, unnotified candidate in that case.
        if replacement ~= entity then replacement.destroy() end
        entity.minable_flag = snapshot.minable_flag
        return entity
    end
    for key, value in pairs(snapshot) do replacement[key] = value end
    local previous = notifying
    notifying = replacement
    script.raise_script_built{entity=replacement}
    notifying = previous
    return replacement
end

function model.rebuild()
    for _, surface in pairs(game.surfaces) do
        for _, entity in ipairs(surface.find_entities_filtered{name="atan-air-scrubber"}) do model.normalize(entity) end
    end
end

return model
