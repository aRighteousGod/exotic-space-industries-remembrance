--==============================================================================
-- ESIR FILE MAP
-- owns: per-surface enemy birth policy, retained rafts and bounded silent removal
-- loaded_by: control.lua, scripts/control/map-settings.lua
-- cadence: birth/lifecycle events; mandatory service for due removals or owned raft restoration
-- forwarded_events: on_script_trigger_effect, on_segmented_unit_created, on_object_destroyed, on_surface_deleted, on_policy_changed, on_configuration_changed, has_tick_work, updater
-- storage_roots: storage.ei.planet_enemies
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration change (generation-setting migration; no entity scan or purge)
-- dependency_sources: __Explosive_biters__/control.lua, __Cold_biters__/control.lua, __Electric_flying_enemies__/control.lua,
-- __Arachnids_enemy__/control.lua, __Toxic_biters__/control.lua, __ArmouredBiters__/data.lua
-- shared_config: lib/planet-enemies-config.lua
--==============================================================================
-- blueprint: .codex/esir/blueprints/planet-enemies.md#contract
local config = require("lib/planet-enemies-config")
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local model = {created_effect = config.created_effect}
-- Synchronous, one-birth authorization; never saved or left active across ticks.
local summon

local function state()
    storage.ei = storage.ei or {}
    local root = scheduler.ensure_queue(storage.ei.planet_enemies)
    storage.ei.planet_enemies = root
    root.rafts = root.rafts or {}
    root.raft_surfaces = root.raft_surfaces or {}
    root.restoring = scheduler.ensure_queue(root.restoring)
    return root
end

---@param force LuaForce
---@return boolean
local function hostile_force(force)
    if force.name == "enemy" then return true end
    if force.name == "neutral" or force.name == "player" or #force.players > 0 then return false end
    -- Vault guardians can inherit another hostile force from a nearby creature.
    -- Respect allies/ceasefires of the default or any player-controlled force.
    for _, other in pairs(game.forces) do
        if other.name == "player" or #other.players > 0 then
            if force.get_friend(other) or force.get_cease_fire(other) then return false end
        end
    end
    return true
end

---@class EiPlanetEnemyRemoval
---@field entity LuaEntity
---@field due_tick MapTick
---@field key uint32

---@param surface LuaSurface
---@return string
local function planet_name(surface)
    if surface.planet then return surface.planet.name end
    if surface.name == "Gaia" or (storage.gaia_surfaces and storage.gaia_surfaces[surface.name]) then return "gaia" end
    return surface.name
end
model.planet_name = planet_name

---@param surface LuaSurface
---@param name string
---@param force LuaForce
---@param create fun():LuaEntity|LuaSegmentedUnit|nil
---@return LuaEntity|LuaSegmentedUnit|nil
function model.create_admin_enemy(surface, name, force, create)
    local previous = summon
    summon = {surface = surface.index, name = name, force = force.index}
    local ok, result = pcall(create)
    summon = previous
    if not ok then error(result) end
    return result
end

local function summoned(surface, name, force)
    if summon and summon.surface == surface.index and summon.name == name and summon.force == force.index then
        summon = nil
        return true
    end
    return false
end

-- Registry membership is event-fed. Pre-v2 disabled rafts have no ownership proof.
local function retain_raft(entity)
    local root = state()
    local registration = script.register_on_object_destroyed(entity)
    local index = entity.surface.index
    local pool = root.raft_surfaces[index] or {ids = {}, positions = {}}
    root.raft_surfaces[index] = pool
    if pool.positions[registration] then return end
    pool.ids[#pool.ids + 1] = registration
    pool.positions[registration] = #pool.ids
    root.rafts[registration] = {entity = entity, surface = index}
end

local function release_raft(root, registration)
    local record = root.rafts[registration]
    if not record then return end
    local pool = root.raft_surfaces[record.surface]
    if pool then
        local position = pool.positions[registration]
        local last = pool.ids[#pool.ids]
        pool.ids[position] = last
        pool.positions[last] = position
        pool.ids[#pool.ids] = nil
        pool.positions[registration] = nil
        if #pool.ids == 0 then root.raft_surfaces[record.surface] = nil end
    end
    root.rafts[registration] = nil
end

---@param event EventData.on_object_destroyed
function model.on_object_destroyed(event)
    local root = storage.ei and storage.ei.planet_enemies
    if root and root.rafts then release_raft(root, event.registration_number) end
end

---@param surface LuaSurface
---@param tick MapTick
function model.on_policy_changed(surface, tick)
    local root = storage.ei and storage.ei.planet_enemies
    if root and root.raft_surfaces and root.raft_surfaces[surface.index] and not model.is_disabled(surface, "pentapod") then
        scheduler.queue_push_unique(root.restoring, surface.index, {key = surface.index, due_tick = tick})
    end
end

---@param event EventData.on_surface_deleted
function model.on_surface_deleted(event)
    local root = storage.ei and storage.ei.planet_enemies
    if root and root.raft_surfaces and root.raft_surfaces[event.surface_index] then
        -- Invalid handles drain through the same bounded service after deletion.
        scheduler.queue_push_unique(root.restoring, event.surface_index, {key = event.surface_index, due_tick = event.tick})
    end
end

---@param surface LuaSurface
---@param family string
---@return boolean
function model.is_disabled(surface, family)
    local controls = config.controls[planet_name(surface)]
    local control = controls and controls[family]
    -- Shared vanilla nests keep their snappers. The independent row applies only
    -- when Armoured Biters' separate-nest startup option is enabled.
    if family == "armoured" and controls and settings.startup["ab-enable-nest"]
        and not settings.startup["ab-enable-nest"].value then control=controls.ordinary end
    if not control then return false end
    if surface.no_enemies_mode then return true end
    local values = surface.map_gen_settings.autoplace_controls
    values = values and values[control]
    -- Missing controls on old/custom surfaces preserve existing behavior.
    return values ~= nil and (values.frequency == 0 or values.size == 0)
end

---@param event EventData.on_script_trigger_effect
function model.on_script_trigger_effect(event)
    local entity = ei_lib.get_valid_entity(event.target_entity)
    if not entity or not hostile_force(entity.force) then return end
    if summoned(entity.surface, entity.name, entity.force) then return end
    local family = config.family(entity.name, entity.type)
    if not family or not model.is_disabled(entity.surface, family) then return end
    if config.is_raft(entity.name) then
        if not entity.disabled_by_script then retain_raft(entity);entity.disabled_by_script = true end
        return
    end
    entity.disabled_by_script = true
    -- blueprint-ref: .codex/esir/blueprints/planet-enemies.md#births
    -- Dependency code still uses the returned creature after create_entity.
    -- Keep it valid and inert until that callback unwinds; prevent death loot/offspring.
    entity.destructible = false
    local queue = state()
    local key = entity.unit_number
    scheduler.queue_push_unique(queue, key, {entity = entity, key = key, due_tick = event.tick + 1})
end

---@param event EventData.on_segmented_unit_created
function model.on_segmented_unit_created(event)
    local unit = event.segmented_unit
    if unit.valid and summoned(unit.surface, unit.prototype.name, unit.force) then return end
    if unit.valid and hostile_force(unit.force) and config.is_demolisher(unit.prototype.name) and model.is_disabled(unit.surface, "demolisher") then
        -- create_segmented_unit explicitly permits destruction during creation.
        -- A head segment can reappear on an OLD unit; never treat that as a new birth.
        unit.destroy()
    end
end

---@param tick MapTick
---@return boolean
function model.has_tick_work(tick)
    local queue = storage.ei and storage.ei.planet_enemies
    local first = queue and queue.items[queue.head]
    local restore = queue and queue.restoring and queue.restoring.items[queue.restoring.head]
    return (first ~= nil and first.due_tick <= tick) or (restore ~= nil and restore.due_tick <= tick)
end

---@param event EventData.on_tick
function model.updater(event)
    local queue = storage.ei.planet_enemies
    for _ = 1, config.removals_per_tick do
        local first = scheduler.queue_peek(queue)
        if not first or first.due_tick > event.tick then break end
        scheduler.queue_pop(queue, first.key)
        local entity = ei_lib.get_valid_entity(first.entity)
        if entity then entity.destroy() end
    end
    local budget = config.rafts_per_tick
    while budget > 0 do
        local job = queue.restoring and scheduler.queue_peek(queue.restoring)
        if not job or job.due_tick > event.tick then break end
        scheduler.queue_pop(queue.restoring, job.key)
        local surface = game.get_surface(job.key)
        local pool = queue.raft_surfaces[job.key]
        if pool and (not surface or not model.is_disabled(surface, "pentapod")) then
            while budget > 0 and #pool.ids > 0 do
                local registration = pool.ids[#pool.ids]
                local entity = ei_lib.get_valid_entity(queue.rafts[registration].entity)
                if entity then entity.disabled_by_script = false end
                release_raft(queue, registration)
                budget = budget - 1
            end
            if #pool.ids > 0 then scheduler.queue_push_unique(queue.restoring, job.key, job) end
        else budget = budget - 1 end
    end
end

-- Upgrade only generation settings. No entity scan, purge or chunk regeneration.
---@param event ConfigurationChangedData
function model.on_configuration_changed(event)
    local change = event.mod_changes and event.mod_changes["exotic-space-industries-remembrance"]
    local old_major, old_minor
    if change and change.old_version then old_major, old_minor = change.old_version:match("^(%d+)%.(%d+)") end
    -- Explicit saved markers and old owned aliases take precedence over this fallback.
    local legacy = (event.old_version and event.old_version:match("^2%.0%."))
        or (old_major and (tonumber(old_major) < 1 or tonumber(old_major) == 1 and tonumber(old_minor) < 4))
    local fallback = legacy and config.legacy_revision or config.native_revision
    for _, surface in pairs(game.surfaces) do
        local name = planet_name(surface)
        if config.controls[name] then
            local prototype = prototypes.space_location[name]
            local defaults = prototype and prototype.map_gen_settings
            if defaults then
                local settings = surface.map_gen_settings
                settings.autoplace_controls = settings.autoplace_controls or {}
                if name == "nauvis" then
                    for _, family in ipairs(config.nauvis_splits) do
                        local control = config.controls.nauvis[family]
                        if not settings.autoplace_controls[control] then
                            settings.autoplace_controls[control] = table.deepcopy(settings.autoplace_controls["enemy-base"]
                                or defaults.autoplace_controls[control] or {frequency = 1, size = 1})
                        end
                    end
                end
                for _, binding in ipairs(config.rebindings) do
                    if binding.planet == name and defaults.autoplace_controls[binding.control] then
                        if not settings.autoplace_controls[binding.control] then
                            settings.autoplace_controls[binding.control] = settings.autoplace_controls[binding.legacy]
                                or defaults.autoplace_controls[binding.control]
                        end
                        settings.autoplace_controls[binding.legacy] = nil
                    end
                end
                if name == "vulcanus" and not settings.autoplace_controls[config.demolisher_control] then
                    settings.autoplace_controls[config.demolisher_control] = {frequency = 1, size = 1}
                end
                if name == "gleba" then
                    settings.autoplace_settings = settings.autoplace_settings or {}
                    settings.autoplace_settings.entity = settings.autoplace_settings.entity or {settings = {}}
                    local entities = settings.autoplace_settings.entity.settings
                    for _, raft in ipairs({"gleba-spawner", "gleba-spawner-small"}) do
                        entities[raft] = entities[raft] or {}
                    end
                end
                settings.property_expression_names = settings.property_expression_names or {}
                config.merge_generation_aliases(settings.property_expression_names,
                    defaults.property_expression_names or {}, name, fallback)
                surface.map_gen_settings = settings
            end
        end
    end
end

return model
