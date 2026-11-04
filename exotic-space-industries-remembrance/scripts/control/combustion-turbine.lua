--==============================================================================
-- ESIR FILE MAP
-- owns: combustion turbine fuel/oxygen GUI, native compound topology and pressure enforcement
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: lifecycle/GUI events; pressure once per occupied surface every 60 ticks
-- forwarded_events: check_global, close_gui, get_runtime_status, on_built_entity,
--                   on_configuration_changed, on_destroyed_entity,
--                   on_entity_settings_pasted, on_gui_click, on_gui_closed, on_object_destroyed,
--                   on_player_left_game, open_gui, rebuild_runtime_state, on_blueprint,
--                   on_gui_checked_state_changed, on_moved_entity, has_tick_work, updater
--                   swap_to_mode, update_gui
-- storage_roots: storage.ei.combustion_turbine
-- gui_ids: ei-combustion-turbine-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, turbine build/destroy/shell swap
--==============================================================================
-- blueprint: .codex/esir/blueprints/combustion-turbine.md#contract

local model = {}

local ei_lib = require("lib/lib")
local config = require("lib/combustion-turbine-config")
local process = require("scripts/control/combustion-turbine-process")

--====================================================================================================
--CONSTANTS
--====================================================================================================

local RUNTIME_VERSION = 1
local GUI_NAME = "ei-combustion-turbine-console"
local SOLID_NAME = "ei-combustion-turbine"
local FLUID_NAME = "ei-combustion-turbine-fluid"
local FLUID_OPEN_PROXY_NAME = "ei-combustion-turbine-fluid-open-proxy"
local MODE_SOLID = "solid"
local MODE_FLUID = "fluid"
local BLUEPRINT_MODE_TAG = "ei_combustion_turbine_mode"

local ENTITY_TO_MODE = {
    [SOLID_NAME] = MODE_SOLID,
    [FLUID_NAME] = MODE_FLUID,
    [config.oxygen_solid] = MODE_SOLID,
    [config.oxygen_fluid] = MODE_FLUID,
    [config.ash_solid] = MODE_SOLID,
    [config.oxygen_ash_solid] = MODE_SOLID,
}

local MODE_TO_ENTITY = {
    [MODE_SOLID] = SOLID_NAME,
    [MODE_FLUID] = FLUID_NAME,
}

model.gui_name = GUI_NAME
model.solid_name = SOLID_NAME
model.fluid_name = FLUID_NAME
model.fluid_open_proxy_name = FLUID_OPEN_PROXY_NAME
model.oxygen_solid_name = config.oxygen_solid
model.oxygen_fluid_name = config.oxygen_fluid

--====================================================================================================
--GENERAL HELPERS
--====================================================================================================

local function now_tick(event_or_tick)
    if type(event_or_tick) == "number" then
        return event_or_tick
    end
    return ei_lib.get_event_tick(event_or_tick) or (game and game.tick) or 0
end

local function normalize_mode(value)
    if value == MODE_FLUID or value == FLUID_NAME then
        return MODE_FLUID
    end
    if value == MODE_SOLID or value == SOLID_NAME then
        return MODE_SOLID
    end
    return nil
end

local function entity_mode(entity)
    return entity and ENTITY_TO_MODE[entity.name] or nil
end

local function is_turbine_name(name)
    return ENTITY_TO_MODE[name] ~= nil
end

local function is_turbine(entity)
    return ei_lib.entity_check(entity) and is_turbine_name(entity.name)
end
model.is_turbine = is_turbine

local function is_open_proxy(entity)
    return ei_lib.entity_check(entity) and entity.name == FLUID_OPEN_PROXY_NAME
end

local function table_count(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local function get_event_entity(event_or_entity)
    if ei_lib.entity_check(event_or_entity) then
        return event_or_entity
    end
    return event_or_entity
        and (event_or_entity.entity or event_or_entity.created_entity or event_or_entity.destination)
        or nil
end

local function mode_from_tags(tags)
    if type(tags) ~= "table" then
        return nil
    end
    return normalize_mode(tags[BLUEPRINT_MODE_TAG] or tags.mode)
end

local function clamp_health(entity, health)
    health = tonumber(health)
    if not health then
        return
    end
    local max_health = tonumber(entity.max_health) or health
    entity.health = math.max(0.01, math.min(max_health, health))
end

local function safe_copy_settings(target, source)
    if not (is_turbine(target) and is_turbine(source)) then
        return
    end
    pcall(function()
        target.copy_settings(source)
    end)
end

local function spill_inventory(entity, inventory_id)
    if not (is_turbine(entity) and inventory_id) then
        return
    end

    local ok, inventory = pcall(function()
        return entity.get_inventory(inventory_id)
    end)
    if not ok or not inventory or not inventory.valid or inventory.is_empty() then
        return
    end

    local contents = inventory.get_contents()
    if type(contents) ~= "table" then
        return
    end

    for _, stack in ipairs(contents) do
        if stack and stack.name and (stack.count or 0) > 0 then
            entity.surface.spill_item_stack{
                position = entity.position,
                stack = stack,
                enable_looted = true,
                force = entity.force,
            }
        end
    end

    inventory.clear()
end

local function spill_burner_inventories(entity)
    if not (defines and defines.inventory) then
        return
    end
    spill_inventory(entity, defines.inventory.fuel)
    spill_inventory(entity, defines.inventory.burnt_result)
end

local function get_real_circuit_connections(entity)
    if not is_turbine(entity) then
        return {}
    end

    local saved_connections = {}
    local ok, connectors = pcall(entity.get_wire_connectors, false)
    if not ok or type(connectors) ~= "table" then
        return saved_connections
    end

    for connector_id, connector in pairs(connectors) do
        if connector and connector.valid then
            for _, connection in ipairs(connector.real_connections or {}) do
                if connection.target and connection.target.valid then
                    saved_connections[#saved_connections + 1] = {
                        source_id = connector_id,
                        target = connection.target,
                        origin = connection.origin,
                    }
                end
            end
        end
    end

    return saved_connections
end

local function restore_circuit_connections(entity, saved_connections)
    if not is_turbine(entity) then
        return
    end

    for _, connection in ipairs(saved_connections or {}) do
        local ok, source = pcall(function()
            return entity.get_wire_connector(connection.source_id, true)
        end)
        if ok and source and source.valid and connection.target and connection.target.valid then
            pcall(function()
                source.connect_to(connection.target, false, connection.origin)
            end)
        end
    end
end

--====================================================================================================
--RUNTIME STORAGE
--====================================================================================================

local function build_runtime()
    return {
        version = RUNTIME_VERSION,
        turbines_by_unit = {},
        units_by_surface = {},
        registrations = {},
        proxy_to_unit = {},
        proxy_open_tick_by_player = {},
        open_by_player = {},
        pressure_by_surface = {},
        retry_units = {},
    }
end

local function get_runtime()
    storage.ei = storage.ei or {}
    local runtime = storage.ei.combustion_turbine
    if type(runtime) ~= "table" or runtime.version ~= RUNTIME_VERSION then
        runtime = build_runtime()
        storage.ei.combustion_turbine = runtime
    end

    runtime.turbines_by_unit = type(runtime.turbines_by_unit) == "table" and runtime.turbines_by_unit or {}
    runtime.units_by_surface = type(runtime.units_by_surface) == "table" and runtime.units_by_surface or {}
    runtime.registrations = type(runtime.registrations) == "table" and runtime.registrations or {}
    runtime.proxy_to_unit = type(runtime.proxy_to_unit) == "table" and runtime.proxy_to_unit or {}
    runtime.proxy_open_tick_by_player = type(runtime.proxy_open_tick_by_player) == "table" and runtime.proxy_open_tick_by_player or {}
    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.pressure_by_surface = runtime.pressure_by_surface or {}
    runtime.retry_units = runtime.retry_units or {}
    return runtime
end

local function add_surface_membership(runtime, surface_index, unit_number)
    if not (surface_index and unit_number) then
        return
    end
    runtime.units_by_surface[surface_index] = runtime.units_by_surface[surface_index] or {}
    runtime.units_by_surface[surface_index][unit_number] = true
end

local function remove_surface_membership(runtime, surface_index, unit_number)
    local bucket = surface_index and runtime.units_by_surface[surface_index] or nil
    if not bucket then
        return
    end
    bucket[unit_number] = nil
    if next(bucket) == nil then
        runtime.units_by_surface[surface_index] = nil
        runtime.pressure_by_surface[surface_index] = nil
    end
end

local function destroy_gui_root(player)
    if not (player and player.valid and player.gui) then
        return
    end

    local relative_root = player.gui.relative and player.gui.relative[GUI_NAME] or nil
    if relative_root and relative_root.valid then
        relative_root.destroy()
    end

    local screen_root = player.gui.screen and player.gui.screen[GUI_NAME] or nil
    if screen_root and screen_root.valid then
        screen_root.destroy()
    end
end

local function get_gui_root(player)
    if not (player and player.valid and player.gui) then
        return nil
    end
    local relative_root = player.gui.relative and player.gui.relative[GUI_NAME] or nil
    if relative_root and relative_root.valid then
        return relative_root
    end
    local screen_root = player.gui.screen and player.gui.screen[GUI_NAME] or nil
    if screen_root and screen_root.valid then
        return screen_root
    end
    return nil
end

local function close_gui_for_player(runtime, player_index)
    runtime.open_by_player[player_index] = nil
    runtime.proxy_open_tick_by_player[player_index] = nil
    local player = game and game.get_player(player_index) or nil
    destroy_gui_root(player)
end

local function close_guis_for_unit(runtime, unit_number)
    for player_index, opened_unit_number in pairs(runtime.open_by_player) do
        if opened_unit_number == unit_number then
            close_gui_for_player(runtime, player_index)
        end
    end
end

local function collect_open_players(runtime, unit_number)
    local players = {}
    for player_index, opened_unit_number in pairs(runtime.open_by_player) do
        if opened_unit_number == unit_number then
            players[#players + 1] = player_index
        end
    end
    return players
end

local function retarget_open_players(runtime, player_indexes, unit_number, entity, event_or_tick)
    for _, player_index in ipairs(player_indexes or {}) do
        runtime.open_by_player[player_index] = unit_number
        local player = game and game.get_player(player_index) or nil
        if player and player.valid then
            pcall(function()
                player.opened = entity
            end)
            if is_open_proxy(entity) then
                runtime.proxy_open_tick_by_player[player_index] = now_tick(event_or_tick)
            end
            local root = model.update_gui(player, entity, event_or_tick)
            if is_open_proxy(entity) and root and root.valid then
                pcall(function()
                    player.opened = root
                end)
            end
        end
    end
end

local function create_turbine_shell(surface, name, position, force, direction, quality)
    local ok, entity = pcall(function()
        return surface.create_entity{
            name = name,
            position = position,
            force = force,
            direction = direction,
            quality = quality,
            create_build_effect_smoke = false,
            raise_built = false,
        }
    end)

    if ok then
        return entity
    end
    return nil
end

local function register_destroy(runtime, entity, kind, unit_number)
    if not (script and script.register_on_object_destroyed and (is_turbine(entity) or is_open_proxy(entity)
        or (ei_lib.entity_check(entity) and (entity.name==config.generator or entity.name==config.ash_generator)))) then
        return nil
    end

    local ok, registration_number = pcall(script.register_on_object_destroyed, entity)
    if not ok or not registration_number then
        return nil
    end

    runtime.registrations[registration_number] = {
        kind = kind or "turbine",
        unit_number = unit_number,
    }
    return registration_number
end

local function destroy_open_proxy(runtime, record)
    if not record then
        return
    end

    if record.proxy_registration then
        runtime.registrations[record.proxy_registration] = nil
    end

    if record.proxy_unit_number then
        runtime.proxy_to_unit[record.proxy_unit_number] = nil
    end

    local proxy = ei_lib.get_valid_entity(record.proxy)
    record.proxy = nil
    record.proxy_unit_number = nil
    record.proxy_registration = nil

    if proxy and proxy.valid then
        proxy.destroy({raise_destroy = false})
    end
end

local function destroy_open_proxies_at_turbine(runtime, entity)
    if not (is_turbine(entity) and entity.surface) then
        return
    end

    for _, proxy in pairs(entity.surface.find_entities_filtered{
        name = FLUID_OPEN_PROXY_NAME,
        position = entity.position,
        radius = 0.1,
        force = entity.force,
    }) do
        if is_open_proxy(proxy) then
            local proxy_unit_number = ei_lib.get_entity_unit_number(proxy)
            local mapped_unit_number = proxy_unit_number and runtime.proxy_to_unit[proxy_unit_number] or nil
            local mapped_record = mapped_unit_number and runtime.turbines_by_unit[mapped_unit_number] or nil

            if proxy_unit_number then
                runtime.proxy_to_unit[proxy_unit_number] = nil
            end

            if mapped_record and mapped_record.proxy_unit_number == proxy_unit_number then
                if mapped_record.proxy_registration then
                    runtime.registrations[mapped_record.proxy_registration] = nil
                end
                mapped_record.proxy = nil
                mapped_record.proxy_unit_number = nil
                mapped_record.proxy_registration = nil
            end

            proxy.destroy({raise_destroy = false})
        end
    end
end

local function proxy_matches_turbine(proxy, entity)
    if not (is_open_proxy(proxy) and is_turbine(entity)) then
        return false
    end
    return proxy.surface == entity.surface
        and proxy.force == entity.force
        and proxy.position.x == entity.position.x
        and proxy.position.y == entity.position.y
end

local function ensure_open_proxy(runtime, record)
    local entity = ei_lib.get_valid_entity(record and record.entity)
    if not (entity and entity.name == FLUID_NAME) then
        destroy_open_proxy(runtime, record)
        return nil
    end

    local proxy = ei_lib.get_valid_entity(record.proxy)
    if not proxy_matches_turbine(proxy, entity) then
        destroy_open_proxy(runtime, record)
        proxy = nil
    end

    if not proxy then
        for _, candidate in pairs(entity.surface.find_entities_filtered{
            name = FLUID_OPEN_PROXY_NAME,
            position = entity.position,
            radius = 0.1,
            force = entity.force,
        }) do
            if proxy_matches_turbine(candidate, entity) then
                proxy = candidate
                break
            end
        end
    end

    if not proxy then
        local ok, created = pcall(function()
            return entity.surface.create_entity{
                name = FLUID_OPEN_PROXY_NAME,
                position = entity.position,
                force = entity.force,
                direction = entity.direction,
                quality = entity.quality,
                create_build_effect_smoke = false,
                raise_built = false,
            }
        end)
        if ok then
            proxy = created
        end
    end

    if not is_open_proxy(proxy) then
        return nil
    end

    pcall(function()
        proxy.direction = entity.direction
    end)
    pcall(function()
        proxy.destructible = false
    end)

    local proxy_unit_number = ei_lib.get_entity_unit_number(proxy)
    if not proxy_unit_number then
        return proxy
    end

    record.proxy = proxy
    record.proxy_unit_number = proxy_unit_number
    record.proxy_registration = record.proxy_registration
        or register_destroy(runtime, proxy, "proxy", record.unit_number)
    runtime.proxy_to_unit[proxy_unit_number] = record.unit_number
    return proxy
end

local function unregister_record(runtime, unit_number, close_guis, retain_process)
    if not unit_number then
        return
    end

    local record = runtime.turbines_by_unit[unit_number]
    if not record then
        return
    end

    if record.registration then
        runtime.registrations[record.registration] = nil
    end
    destroy_open_proxy(runtime, record)
    if record.generator_registration then runtime.registrations[record.generator_registration]=nil end
    if not retain_process then
        if ei_lib.entity_check(record.generator) then record.generator.destroy{raise_destroy=false} end
    end
    runtime.retry_units[unit_number]=nil
    remove_surface_membership(runtime, record.surface_index, unit_number)
    runtime.turbines_by_unit[unit_number] = nil

    if close_guis then
        close_guis_for_unit(runtime, unit_number)
    end
end

---@class EiCombustionOptions
---@field ash_requested boolean
---@field enabled boolean
---@field external_disabled boolean
---@field applied_disabled boolean?

-- Player preference and safety holds are independent; never enable through a hold.
local function apply_operation(record)
    local entity=record.entity
    entity.disabled_by_script=not record.enabled or record.external_disabled or record.pressure_disabled~=nil
    record.applied_disabled=entity.disabled_by_script
    if ei_lib.entity_check(record.generator) then process.connect(entity,record.generator) end
end

local function register_turbine(runtime, entity, event_or_tick)
    if not is_turbine(entity) then
        return nil
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return nil
    end

    local record = runtime.turbines_by_unit[unit_number]
    if not record then
        record = {
            unit_number = unit_number,
            registration = register_destroy(runtime, entity, "turbine", unit_number),
        }
        runtime.turbines_by_unit[unit_number] = record
    elseif record.surface_index and record.surface_index ~= entity.surface.index then
        remove_surface_membership(runtime, record.surface_index, unit_number)
    end

    record.registration = record.registration or register_destroy(runtime, entity, "turbine", unit_number)
    record.entity = entity
    record.mode = entity_mode(entity) or MODE_SOLID
    record.entity_name = entity.name
    record.oxygen_requested = record.oxygen_requested==true
    if record.ash_requested==nil then record.ash_requested=process.is_ash(entity) end
    if record.enabled==nil then record.enabled=true end
    if record.external_disabled==nil then
        if record.pressure_disabled then record.external_disabled=record.pressure_disabled.previous
        else record.external_disabled=entity.disabled_by_script end
    elseif record.applied_disabled~=nil and entity.disabled_by_script~=record.applied_disabled then
        record.external_disabled=entity.disabled_by_script
    end
    record.surface_index = entity.surface and entity.surface.index or nil
    record.last_seen_tick = now_tick(event_or_tick)
    add_surface_membership(runtime, record.surface_index, unit_number)

    if process.is_oxygen(entity) and not ei_lib.entity_check(record.generator) then
        record.generator=process.create_generator(entity)
    end
    if ei_lib.entity_check(record.generator) then
        local aligned,reserve=process.align_generator(entity,record.generator)
        record.electrical_reserve=(record.electrical_reserve or 0)+(reserve or 0)
        if aligned and aligned~=record.generator then
            if record.generator_registration then runtime.registrations[record.generator_registration]=nil end
            record.generator_registration=nil
            record.generator=aligned
        end
        record.generator_registration=record.generator_registration
            or register_destroy(runtime,record.generator,"generator",unit_number)
        process.connect(entity,record.generator)
        if not aligned then
            record.pressure_disabled=record.pressure_disabled or {previous=entity.disabled_by_script}
            entity.disabled_by_script=true
            record.generator.disabled_by_script=true
            runtime.retry_units[unit_number]=true
        end
    elseif process.is_oxygen(entity) then
        record.pressure_disabled=record.pressure_disabled or {previous=entity.disabled_by_script}
        entity.disabled_by_script=true
        runtime.retry_units[unit_number]=true
    end
    if record.mode == MODE_FLUID and not process.is_oxygen(entity) then
        ensure_open_proxy(runtime, record)
    else
        destroy_open_proxy(runtime, record)
        destroy_open_proxies_at_turbine(runtime, entity)
    end

    apply_operation(record)
    return record
end

local function resolve_turbine_entity(entity, runtime, event_or_tick)
    if is_turbine(entity) then
        return entity
    end

    if not is_open_proxy(entity) then
        return nil
    end

    local proxy_unit_number = ei_lib.get_entity_unit_number(entity)
    local unit_number = proxy_unit_number and runtime.proxy_to_unit[proxy_unit_number] or nil
    local record = unit_number and runtime.turbines_by_unit[unit_number] or nil
    local turbine = ei_lib.get_valid_entity(record and record.entity)
    if is_turbine(turbine) then
        return turbine
    end

    for _, candidate in pairs(entity.surface.find_entities_filtered{
        name = FLUID_NAME,
        position = entity.position,
        radius = 0.1,
        force = entity.force,
    }) do
        if is_turbine(candidate) then
            record = register_turbine(runtime, candidate, event_or_tick)
            if record then
                record.proxy = entity
                record.proxy_unit_number = proxy_unit_number
                record.proxy_registration = record.proxy_registration
                    or register_destroy(runtime, entity, "proxy", record.unit_number)
                if proxy_unit_number then
                    runtime.proxy_to_unit[proxy_unit_number] = record.unit_number
                end
            end
            return candidate
        end
    end

    return nil
end

local function get_opened_turbine(player, runtime, event_or_tick)
    local opened = ei_lib.get_valid_entity(player and player.opened)
    local opened_turbine = resolve_turbine_entity(opened, runtime, event_or_tick)
    if opened_turbine then
        return opened_turbine
    end

    local unit_number = player and runtime.open_by_player[player.index] or nil
    local record = unit_number and runtime.turbines_by_unit[unit_number] or nil
    return ei_lib.get_valid_entity(record and record.entity)
end

local function get_mode_caption(mode)
    if mode == MODE_FLUID then
        return {"exotic-industries.combustion-turbine-gui-mode-fluid"}
    end
    return {"exotic-industries.combustion-turbine-gui-mode-solid"}
end

--====================================================================================================
--SHELL SWAP
--====================================================================================================

---@param ash_requested boolean? Retained but inactive in fluid mode.
---@param enabled_requested boolean? Player preference, independent of safety holds.
---@return LuaEntity entity
---@return boolean? success
function model.swap_to_mode(entity, requested_mode, event_or_tick, player_index, oxygen_requested, ash_requested, enabled_requested)
    requested_mode = normalize_mode(requested_mode)
    if not (is_turbine(entity) and requested_mode) then
        return entity
    end

    local current_mode = entity_mode(entity)
    local runtime = get_runtime()
    local record = register_turbine(runtime, entity, event_or_tick)
    local preference=oxygen_requested
    if preference==nil then preference=record.oxygen_requested end
    if ash_requested==nil then ash_requested=record.ash_requested end
    if enabled_requested==nil then enabled_requested=record.enabled end
    local forced=process.forced(entity.surface)
    local oxygen=forced or preference==true
    local target_name = oxygen and (requested_mode==MODE_SOLID and config.oxygen_solid or config.oxygen_fluid)
        or MODE_TO_ENTITY[requested_mode]
    if requested_mode==MODE_SOLID and ash_requested then
        target_name=oxygen and config.oxygen_ash_solid or config.ash_solid
    end
    local residue=entity.get_burnt_result_inventory()
    if residue and not residue.is_empty() and not (requested_mode==MODE_SOLID and ash_requested) then
        local player=player_index and game.get_player(player_index)
        if player then player.print({"exotic-industries.combustion-turbine-empty-residue"}) end
        return entity,false
    end
    if entity.name==target_name then
        record.oxygen_requested=preference==true
        record.ash_requested=ash_requested==true
        record.enabled=enabled_requested~=false
        if record.pressure_disabled and (not oxygen or (ei_lib.entity_check(record.generator)
            and record.generator.direction==entity.direction)) then
            entity.disabled_by_script=record.pressure_disabled.previous
            record.pressure_disabled=nil
            runtime.retry_units[record.unit_number]=nil
            if ei_lib.entity_check(record.generator) then process.connect(entity,record.generator) end
        end
        apply_operation(record)
        return entity,true
    end
    if not target_name then
        return entity
    end

    local old_unit_number = record and record.unit_number or ei_lib.get_entity_unit_number(entity)
    local open_players = collect_open_players(runtime, old_unit_number)
    local surface = entity.surface
    local force = entity.force
    local position = entity.position
    local direction = entity.direction
    local quality = entity.quality
    local health = entity.health
    local energy = tonumber(entity.energy) or 0
    local flags = {
        minable_flag = entity.minable_flag,
        destructible = entity.destructible,
        operable = entity.operable,
        rotatable = entity.rotatable,
        disabled_by_script = entity.disabled_by_script,
    }
    local saved_connections = get_real_circuit_connections(entity)
    local saved_process=process.capture(entity,record)
    local saved_generator=ei_lib.entity_check(record.generator) and process.capture_generator(record.generator) or nil

    -- blueprint-ref: .codex/esir/blueprints/combustion-turbine.md#transaction
    -- These unlike native shells can briefly overlap. Keep the original alive
    -- until creation succeeds, so failure preserves its fluids, fuel and viewers.
    local replacement = create_turbine_shell(surface, target_name, position, force, direction, quality)
    local generator=ei_lib.get_valid_entity(record.generator)
    local old_generator=generator
    if is_turbine(replacement) and (oxygen or generator) and
        (not generator or generator.name~=process.generator_name(replacement)) then
        generator=process.create_generator(replacement)
        if not generator then replacement.destroy{raise_destroy=false};replacement=nil end
    end

    if not is_turbine(replacement) then
        if forced and not process.is_oxygen(entity) then
            record.pressure_disabled=record.pressure_disabled or {previous=entity.disabled_by_script}
            entity.disabled_by_script=true
            runtime.retry_units[old_unit_number]=true
            apply_operation(record)
        end
        if player_index and game then
            local player = game.get_player(player_index)
            if player then
                player.print({"exotic-industries.combustion-turbine-gui-swap-failed"})
            end
        end
        return entity,false
    end

    clamp_health(replacement, health)
    for name, value in pairs(flags) do replacement[name] = value end
    pcall(function()
        replacement.energy = energy
    end)

    if record.pressure_disabled then
        replacement.disabled_by_script=record.pressure_disabled.previous
    end
    if current_mode==requested_mode then process.copy_burner(entity,replacement) end
    if requested_mode == MODE_SOLID then
        destroy_open_proxies_at_turbine(runtime, entity)
    elseif current_mode~=requested_mode then
        spill_burner_inventories(entity)
    end
    unregister_record(runtime, old_unit_number, false, true)
    entity.destroy({raise_destroy = false})
    if old_generator and old_generator~=generator then
        old_generator.destroy{raise_destroy=false}
        process.restore_generator(generator,saved_generator)
    end
    restore_circuit_connections(replacement, saved_connections)

    runtime.turbines_by_unit[replacement.unit_number]={unit_number=replacement.unit_number,
        generator=generator,oxygen_requested=preference==true,ash_requested=ash_requested==true,
        enabled=enabled_requested~=false,external_disabled=record.external_disabled}
    local new_record = register_turbine(runtime, replacement, event_or_tick)
    process.restore(replacement,new_record,saved_process,current_mode==requested_mode)
    apply_operation(new_record)
    local new_unit_number = new_record and new_record.unit_number or ei_lib.get_entity_unit_number(replacement)
    local opened_entity = new_record
        and new_record.mode == MODE_FLUID
        and ei_lib.get_valid_entity(new_record.proxy)
        or replacement
    retarget_open_players(runtime, open_players, new_unit_number, opened_entity, event_or_tick)

    return replacement,true
end

--====================================================================================================
--GUI
--====================================================================================================

local function get_relative_gui_types(anchor_entity)
    local relative_types = defines and defines.relative_gui_type or {}
    local candidates = {}
    local function add(value)
        if value then
            candidates[#candidates + 1] = value
        end
    end
    if is_open_proxy(anchor_entity) then
        add(relative_types.constant_combinator_gui)
    elseif is_turbine(anchor_entity) and process.is_oxygen(anchor_entity) then
        add(relative_types.assembling_machine_gui)
    end
    add(relative_types.entity_with_energy_source_gui)
    add(relative_types.burner_generator_gui)
    add(relative_types.generator_gui)
    add(relative_types.electric_network_gui)
    return candidates
end

local function get_gui_anchor_entity(entity, record)
    local proxy = ei_lib.get_valid_entity(record and record.proxy)
    if proxy then
        return proxy
    end
    return entity
end

local function add_titlebar(root, detached)
    local titlebar = root.add{type = "flow", direction = "horizontal"}
    if detached then
        titlebar.drag_target = root
    end
    titlebar.add{
        type = "label",
        caption = {"exotic-industries.combustion-turbine-gui-title"},
        style = "frame_title",
    }
    titlebar.add{
        type = "empty-widget",
        style = "ei_titlebar_nondraggable_spacer",
        ignored_by_interaction = true,
    }
    if detached then
        titlebar.add{
            type = "sprite-button",
            style = "close_button",
            sprite = "utility/close",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            tags = {
                parent_gui = GUI_NAME,
                action = "close-gui",
            },
        }
    end
end

local function add_mode_button(parent, name, mode, caption, tooltip)
    local button = parent.add{
        type = "button",
        name = name,
        caption = caption,
        tooltip = tooltip,
        tags = {
            parent_gui = GUI_NAME,
            action = "set-mode",
            mode = mode,
        },
    }
    button.style.minimal_width = 130
    return button
end

local function build_gui(player, entity, record, force_screen)
    destroy_gui_root(player)

    if not (player and player.valid and player.gui) then
        return nil
    end

    local root
    local detached = false
    local anchor_entity = get_gui_anchor_entity(entity, record)

    if not force_screen and player.gui.relative and anchor_entity then
        for _, gui_type in ipairs(get_relative_gui_types(anchor_entity)) do
            local ok, relative_root = pcall(function()
                return player.gui.relative.add{
                    type = "frame",
                    name = GUI_NAME,
                    anchor = {
                        gui = gui_type,
                        name = anchor_entity.name,
                        position = defines.relative_gui_position.right,
                    },
                    direction = "vertical",
                    tags = {
                        parent_gui = GUI_NAME,
                        unit_number = record.unit_number,
                        gui_mode = "relative",
                    },
                }
            end)
            if ok and relative_root and relative_root.valid then
                root = relative_root
                break
            end
        end
    end

    if not root and player.gui.screen then
        detached = true
        root = player.gui.screen.add{
            type = "frame",
            name = GUI_NAME,
            direction = "vertical",
            tags = {
                parent_gui = GUI_NAME,
                unit_number = record.unit_number,
                gui_mode = "screen",
            },
        }
        root.force_auto_center()
    end

    if not root then
        return nil
    end

    root.style.minimal_width = 360
    add_titlebar(root, detached)

    local main = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    main.add{
        type = "frame",
        style = "ei_subheader_frame",
    }.add{
        type = "label",
        caption = {"exotic-industries.combustion-turbine-gui-status-title"},
        style = "subheader_caption_label",
    }
    local status_flow = main.add{
        type = "flow",
        name = "status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    status_flow.add{
        type = "label",
        name = "mode-label",
        caption = "",
    }
    status_flow.add{
        type = "label",
        name = "agent-label",
        caption = "",
        style = "caption_label",
    }
    local fluid_hotspot_tip = status_flow.add{
        type = "label",
        name = "fluid-hotspot-tip-label",
        caption = "",
        style = "caption_label",
    }
    fluid_hotspot_tip.style.single_line = false
    fluid_hotspot_tip.style.maximal_width = 320

    main.add{type="frame",name="generation-header",style="ei_subheader_frame_with_top_border"}.add{
        type="label",caption={"exotic-industries.combustion-turbine-generation"},style="subheader_caption_label"}
    local generation=main.add{type="flow",name="generation-flow",direction="vertical",style="ei_inner_content_flow"}
    for _,name in ipairs({"power","load","fuel","oxygen","exhaust","residue"}) do
        local label=generation.add{type="label",name=name,caption=""}
        label.style.single_line=false
        label.style.maximal_width=340
    end

    main.add{
        type = "frame",
        style = "ei_subheader_frame_with_top_border",
    }.add{
        type = "label",
        caption = {"exotic-industries.combustion-turbine-options"},
        style = "subheader_caption_label",
    }
    local button_flow = main.add{
        type = "flow",
        name = "mode-button-flow",
        direction = "horizontal",
        style = "ei_inner_content_flow_horizontal",
    }
    add_mode_button(
        button_flow,
        "solid-mode-button",
        MODE_SOLID,
        {"exotic-industries.combustion-turbine-gui-mode-solid"},
        {"exotic-industries.combustion-turbine-gui-mode-solid-tooltip"}
    )
    add_mode_button(
        button_flow,
        "fluid-mode-button",
        MODE_FLUID,
        {"exotic-industries.combustion-turbine-gui-mode-fluid"},
        {"exotic-industries.combustion-turbine-gui-mode-fluid-tooltip"}
    )

    local options=main.add{type="flow",name="options-flow",direction="vertical",style="ei_inner_content_flow"}
    for _,action in ipairs({"enabled","ash"}) do
        options.add{type="checkbox",name=action.."-toggle",state=false,
            caption={"exotic-industries.combustion-turbine-"..action},
            tags={parent_gui=GUI_NAME,action=action}}
    end
    options.add{type="checkbox",name="oxygen-fed-toggle",state=false,
        caption={"exotic-industries.combustion-turbine-oxygen-toggle"},tags={parent_gui=GUI_NAME,action="oxygen-fed"}}
    return root
end

-- Read only for an open panel. No persistent samples or production accounting.
---@param record table
---@return table snapshot
local function read_generation(record)
    local entity=record.entity
    local generator=ei_lib.get_valid_entity(record.generator)
    local result={status="running"}
    if not process.is_oxygen(entity) or not generator then return result end
    local oxygen=entity.get_fluid(process.oxygen_index(entity))
    local exhaust=generator.get_fluid(2)
    result.oxygen=oxygen and oxygen.amount or 0
    result.exhaust=exhaust and exhaust.amount or 0
    result.oxygen_capacity=entity.get_fluid_capacity(process.oxygen_index(entity))
    result.exhaust_capacity=generator.get_fluid_capacity(2)
    result.power=generator.energy_generated_last_tick*60
    result.capacity=generator.prototype.get_max_energy_production(generator.quality)*60
    result.load=result.capacity>0 and result.power/result.capacity*100 or 0
    local fuel_index=process.fuel_index(entity)
    if fuel_index then
        local fuel=entity.get_fluid(fuel_index)
        result.fuel=fuel and {"",{"fluid-name."..fuel.name}," (",string.format("%.1f",fuel.amount),")"} or {"exotic-industries.combustion-turbine-none"}
    else
        local burner=entity.burner
        local fuel=burner.currently_burning
        result.fuel=fuel and fuel.name.localised_name or {"exotic-industries.combustion-turbine-none"}
        local residue=entity.get_burnt_result_inventory()
        result.residue_slots=residue and #residue or 0
        result.residue_used=residue and (#residue-residue.count_empty_stacks()) or 0
    end
    local statuses=defines.entity_status
    if entity.disabled_by_script or generator.disabled_by_script then result.status="disabled"
    elseif not generator.is_connected_to_electric_network() then result.status="disconnected"
    elseif result.exhaust>=result.exhaust_capacity-0.01 then result.status="exhaust-blocked"
    elseif entity.status==statuses.full_burnt_result_output then result.status="residue-blocked"
    elseif entity.status==statuses.no_fuel then result.status="no-fuel"
    elseif result.oxygen<1 and result.power==0 then result.status="no-oxygen"
    elseif result.power==0 then result.status="no-demand" end
    return result
end

---@param event_or_tick EventData|MapTick|nil
---@param generation table? Refresh-local snapshot shared by viewers.
function model.update_gui(player, entity, event_or_tick, generation)
    event_or_tick = event_or_tick or (game and game.tick) or 0
    local runtime = get_runtime()
    local opened_entity = ei_lib.get_valid_entity(entity)
    local opened_via_proxy = is_open_proxy(opened_entity)
    entity = resolve_turbine_entity(opened_entity, runtime, event_or_tick)
        or get_opened_turbine(player, runtime, event_or_tick)
    if not is_turbine(entity) then
        model.close_gui(player)
        return nil
    end

    local record = register_turbine(runtime, entity, event_or_tick)
    if not record then
        model.close_gui(player)
        return nil
    end

    local force_screen = opened_via_proxy or (record.mode == MODE_FLUID and not process.is_oxygen(entity))
    local root = get_gui_root(player)
    local root_tags = root and root.valid and root.tags or {}
    if not root
    or not root.valid
    or not root["main-container"]
    or root_tags.unit_number ~= record.unit_number
    or (force_screen and root_tags.gui_mode ~= "screen") then
        root = build_gui(player, entity, record, force_screen)
    end
    if not root then
        return nil
    end

    root.tags = {
        parent_gui = GUI_NAME,
        unit_number = record.unit_number,
        gui_mode = root.tags and root.tags.gui_mode or "relative",
    }

    local main = root["main-container"]
    local status_flow = main and main["status-flow"] or nil
    local button_flow = main and main["mode-button-flow"] or nil
    if not (status_flow and button_flow) then
        return
    end

    local mode = record.mode or entity_mode(entity) or MODE_SOLID
    local forced=process.forced(entity.surface)
    local options=main["options-flow"]
    local oxygen_toggle=options["oxygen-fed-toggle"]
    -- Keep the pressure explanation in Status; controls live in Options.
    if not status_flow["oxygen-fed-status"] then
        local label=status_flow.add{type="label",name="oxygen-fed-status",caption=""}
        label.style.single_line=false
        label.style.maximal_width=320
    end
    oxygen_toggle.state=forced or record.oxygen_requested
    oxygen_toggle.enabled=not forced
    oxygen_toggle.tooltip={"exotic-industries.combustion-turbine-oxygen-tooltip",config.atmospheric_oxygen_min_pressure}
    options["ash-toggle"].state=record.ash_requested
    options["ash-toggle"].enabled=mode==MODE_SOLID
    options["ash-toggle"].tooltip={"exotic-industries.combustion-turbine-ash-"..(mode==MODE_SOLID and "tooltip" or "fluid")}
    options["enabled-toggle"].state=record.enabled
    options["enabled-toggle"].tooltip={"exotic-industries.combustion-turbine-enabled-tooltip"}
    local oxygen_operation=process.is_oxygen(entity)
    main["generation-header"].visible=oxygen_operation
    local flow=main["generation-flow"]
    flow.visible=oxygen_operation
    if oxygen_operation then
        generation=generation or read_generation(record)
        if generation.capacity then
            flow.power.caption={"exotic-industries.combustion-turbine-power",string.format("%.2f",generation.power/1e6),string.format("%.2f",generation.capacity/1e6)}
            flow.load.caption={"exotic-industries.combustion-turbine-load",string.format("%.1f",generation.load)}
            flow.fuel.caption={"exotic-industries.combustion-turbine-fuel",generation.fuel}
            flow.oxygen.caption={"exotic-industries.combustion-turbine-oxygen-buffer",string.format("%.1f",generation.oxygen),generation.oxygen_capacity}
            flow.exhaust.caption={"exotic-industries.combustion-turbine-exhaust-buffer",string.format("%.1f",generation.exhaust),generation.exhaust_capacity}
            flow.residue.visible=(generation.residue_slots or 0)>0
            flow.residue.caption={"exotic-industries.combustion-turbine-residue",generation.residue_used or 0,generation.residue_slots or 0}
        end
    end
    status_flow["oxygen-fed-status"].caption=forced
        and {"exotic-industries.combustion-turbine-oxygen-forced",config.atmospheric_oxygen_min_pressure}
        or (record.oxygen_requested and {"exotic-industries.combustion-turbine-oxygen-selected"}
            or {"exotic-industries.combustion-turbine-oxygen-atmospheric"})
    status_flow["mode-label"].caption = {
        "exotic-industries.combustion-turbine-gui-mode",
        get_mode_caption(mode),
    }
    status_flow["agent-label"].caption = mode == MODE_FLUID
        and {"exotic-industries.combustion-turbine-gui-agent-fluid"}
        or {"exotic-industries.combustion-turbine-gui-agent-solid"}
    if oxygen_operation then
        status_flow["agent-label"].caption={"exotic-industries.combustion-turbine-state-"..generation.status}
    elseif entity.disabled_by_script then
        status_flow["agent-label"].caption={"exotic-industries.combustion-turbine-state-disabled"}
    end
    if status_flow["fluid-hotspot-tip-label"] then
        status_flow["fluid-hotspot-tip-label"].visible = entity.name == FLUID_NAME
        status_flow["fluid-hotspot-tip-label"].caption = mode == MODE_FLUID
            and {"exotic-industries.combustion-turbine-gui-fluid-hotspot-tip"}
            or ""
    end

    button_flow["solid-mode-button"].style = mode == MODE_SOLID and "ei_green_button" or "button"
    button_flow["fluid-mode-button"].style = mode == MODE_FLUID and "ei_green_button" or "button"
    return root
end

---@param event_or_tick EventData|MapTick|nil
function model.open_gui(player, entity, event_or_tick)
    event_or_tick = event_or_tick or (game and game.tick) or 0
    if not (player and player.valid) then
        return
    end
    local runtime = get_runtime()
    local opened_entity = ei_lib.get_valid_entity(entity)
    local opened_via_proxy = is_open_proxy(opened_entity)
    entity = resolve_turbine_entity(opened_entity, runtime, event_or_tick)
        or get_opened_turbine(player, runtime, event_or_tick)
    if not is_turbine(entity) then
        model.close_gui(player)
        return
    end

    local record = register_turbine(runtime, entity, event_or_tick)
    if not record then
        model.close_gui(player)
        return
    end
    runtime.open_by_player[player.index] = record.unit_number
    if opened_via_proxy then
        runtime.proxy_open_tick_by_player[player.index] = now_tick(event_or_tick)
    end
    local root = model.update_gui(player, opened_entity or entity, event_or_tick)
    if opened_via_proxy and root and root.valid then
        pcall(function()
            player.opened = root
        end)
    end
end

function model.close_gui(player)
    if not (player and player.valid) then
        return
    end
    local runtime = get_runtime()
    runtime.open_by_player[player.index] = nil
    runtime.proxy_open_tick_by_player[player.index] = nil
    destroy_gui_root(player)
end

function model.on_gui_closed(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return
    end

    local runtime = get_runtime()
    local closed_entity = ei_lib.get_valid_entity(event and event.entity)
    -- blueprint-ref: .codex/esir/blueprints/combustion-turbine.md#gui-transfer
    -- Opening a fluid console can synchronously close a different turbine's
    -- native window. That old close must not tear down the newly assigned owner.
    local closed_unit = is_turbine(closed_entity) and closed_entity.unit_number
        or (is_open_proxy(closed_entity) and runtime.proxy_to_unit[closed_entity.unit_number])
    local current_unit = runtime.open_by_player[player.index]
    if closed_unit and current_unit and closed_unit ~= current_unit then return end
    if is_open_proxy(closed_entity) then
        local opened_tick = runtime.proxy_open_tick_by_player[player.index]
        local close_tick = now_tick(event)
        if opened_tick and close_tick <= opened_tick + 1 and get_gui_root(player) then
            return
        end
    end

    model.close_gui(player)
end

function model.on_gui_click(event)
    local element = event and event.element
    if not (element and element.valid and element.tags) then
        return
    end

    local player = game and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return
    end

    if element.tags.action == "close-gui" then
        model.close_gui(player)
        return
    end

    if element.tags.action ~= "set-mode" then
        return
    end

    local runtime = get_runtime()
    local entity = get_opened_turbine(player, runtime, event)
    if not is_turbine(entity) then
        model.close_gui(player)
        return
    end

    local replacement = model.swap_to_mode(entity, element.tags.mode, event, player.index)
    if is_turbine(replacement) then
        model.update_gui(player, replacement, event)
    else
        model.close_gui(player)
    end
end

---@param event EventData.on_gui_checked_state_changed
function model.on_gui_checked_state_changed(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI_NAME) then return end
    local action=element.tags.action
    if action~="oxygen-fed" and action~="ash" and action~="enabled" then return end
    local player=game.get_player(event.player_index)
    local entity=get_opened_turbine(player,get_runtime(),event)
    if not is_turbine(entity) then return end
    if action=="ash" and entity_mode(entity)==MODE_SOLID then
        entity=model.swap_to_mode(entity,entity_mode(entity),event,event.player_index,nil,element.state)
    elseif action=="enabled" then
        entity=model.swap_to_mode(entity,entity_mode(entity),event,event.player_index,nil,nil,element.state)
    elseif action=="oxygen-fed" and not process.forced(entity.surface) then
        entity=model.swap_to_mode(entity,entity_mode(entity),event,event.player_index,element.state)
    end
    model.update_gui(player,entity,event)
end

---@param event EventData.on_player_setup_blueprint
function model.on_blueprint(event)
    local player=game.get_player(event.player_index)
    if not player then return end
    local stack=event.record
    if not stack then
        stack=event.stack or player.blueprint_to_setup
        if not (stack and stack.valid_for_read and stack.is_blueprint) then stack=player.cursor_stack end
        if not (stack and stack.valid_for_read and stack.is_blueprint) then return end
    end
    local runtime=get_runtime()
    for index,entity in pairs(event.mapping.get()) do
        if is_turbine(entity) then
            local record=register_turbine(runtime,entity,event)
            stack.set_blueprint_entity_tag(index,BLUEPRINT_MODE_TAG,entity_mode(entity))
            stack.set_blueprint_entity_tag(index,config.oxygen_tag,record.oxygen_requested)
            stack.set_blueprint_entity_tag(index,config.ash_tag,record.ash_requested)
            stack.set_blueprint_entity_tag(index,config.enabled_tag,record.enabled)
        end
    end
end

--====================================================================================================
--EVENT ENTRYPOINTS
--====================================================================================================

function model.check_global()
    return get_runtime()
end

function model.rebuild_runtime_state(reason, event_or_tick)
    local old_runtime = get_runtime()
    local old_records=old_runtime.turbines_by_unit
    for player_index in pairs(old_runtime.open_by_player) do
        local player = game and game.get_player(player_index) or nil
        destroy_gui_root(player)
    end

    local runtime = build_runtime()
    storage.ei.combustion_turbine = runtime

    for _, surface in pairs(game and game.surfaces or {}) do
        for _, proxy in pairs(surface.find_entities_filtered{name = FLUID_OPEN_PROXY_NAME}) do
            proxy.destroy({raise_destroy = false})
        end
        for _, entity in pairs(surface.find_entities_filtered{name = {SOLID_NAME, FLUID_NAME,config.oxygen_solid,config.oxygen_fluid,config.ash_solid,config.oxygen_ash_solid}}) do
            local previous=old_records[entity.unit_number]
            if previous then
                previous.registration=nil
                previous.proxy_registration=nil
                previous.generator_registration=nil
                runtime.turbines_by_unit[entity.unit_number]=previous
            end
            register_turbine(runtime, entity, event_or_tick)
            model.swap_to_mode(entity,entity_mode(entity),event_or_tick)
        end
    end
    local owned={}
    for _,record in pairs(runtime.turbines_by_unit) do
        if ei_lib.entity_check(record.generator) then owned[record.generator.unit_number]=true end
    end
    for _,surface in pairs(game.surfaces) do
        for _,generator in pairs(surface.find_entities_filtered{name={config.generator,config.ash_generator}}) do
            if not owned[generator.unit_number] then generator.destroy{raise_destroy=false} end
        end
    end

    runtime.rebuild_reason = reason
    runtime.rebuild_tick = now_tick(event_or_tick)
    return runtime
end

function model.on_configuration_changed(event)
    model.check_global()
    model.rebuild_runtime_state("configuration-changed", event)
end

---@param event_or_entity table|LuaEntity
---@return LuaEntity|nil surviving_entity
function model.on_built_entity(event_or_entity)
    local entity = ei_lib.get_valid_entity(get_event_entity(event_or_entity))
    if entity and (entity.name==config.generator or entity.name==config.ash_generator) and event_or_entity~=entity and event_or_entity.is_clone then
        entity.destroy{raise_destroy=false}
        return nil
    end
    if not entity or not is_turbine_name(entity.name) then
        return entity
    end

    local tags = nil
    local player_index = nil
    if event_or_entity ~= entity and type(event_or_entity) == "table" then
        tags = event_or_entity.tags
        player_index = event_or_entity.player_index
    end

    local requested_mode = mode_from_tags(tags)
    local runtime = get_runtime()
    local record=register_turbine(runtime, entity, event_or_entity)
    local preference=record.oxygen_requested
    local ash_requested,enabled_requested=record.ash_requested,record.enabled
    if tags and type(tags[config.oxygen_tag])=="boolean" then preference=tags[config.oxygen_tag] end
    if tags and type(tags[config.ash_tag])=="boolean" then ash_requested=tags[config.ash_tag] end
    if tags and type(tags[config.enabled_tag])=="boolean" then enabled_requested=tags[config.enabled_tag] end
    if event_or_entity~=entity and event_or_entity.is_clone and is_turbine(event_or_entity.source) then
        local source=runtime.turbines_by_unit[event_or_entity.source.unit_number]
        if source then
            preference=source.oxygen_requested
            ash_requested,enabled_requested=source.ash_requested,source.enabled
            record.external_disabled=source.external_disabled
            record.dormant_process=table.deepcopy(source.dormant_process)
            record.atmospheric_heat=source.atmospheric_heat
            record.electrical_reserve=source.electrical_reserve
            if ei_lib.entity_check(source.generator) then
                record.generator=record.generator or process.create_generator(entity)
                if ei_lib.entity_check(record.generator) then
                    process.copy_generator(source.generator,record.generator)
                end
            end
        end
    end
    return ei_lib.get_valid_entity(model.swap_to_mode(entity,requested_mode or entity_mode(entity),
        event_or_entity,player_index,preference,ash_requested,enabled_requested))
end

function model.on_destroyed_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not is_turbine(entity) then
        return
    end

    local unit_number = ei_lib.get_entity_unit_number(entity)
    if unit_number then
        unregister_record(get_runtime(), unit_number, true)
    end
end

function model.on_entity_settings_pasted(event)
    local runtime = get_runtime()
    local source = resolve_turbine_entity(event and event.source or nil, runtime, event)
    local destination = resolve_turbine_entity(event and event.destination or nil, runtime, event)
    if not (is_turbine(source) and is_turbine(destination)) then
        return
    end

    local source_mode = entity_mode(source)
    local source_record=register_turbine(runtime,source,event)
    local replacement,success = model.swap_to_mode(destination, source_mode, event, event.player_index,
        source_record.oxygen_requested,source_record.ash_requested,source_record.enabled)
    if success and is_turbine(replacement) then
        safe_copy_settings(replacement, source)
    end
end

function model.on_object_destroyed(event)
    local runtime = get_runtime()
    local registration_number = event and event.registration_number
    local payload = registration_number and runtime.registrations[registration_number] or nil
    local unit_number = type(payload) == "table" and payload.unit_number or payload
    local kind = type(payload) == "table" and payload.kind or "turbine"
    if not unit_number then
        return
    end

    runtime.registrations[registration_number] = nil

    if kind=="generator" then
        local record=runtime.turbines_by_unit[unit_number]
        if record then
            record.generator=nil
            record.generator_registration=nil
            if is_turbine(record.entity) then register_turbine(runtime,record.entity,event) end
        end
        return
    end
    if kind == "proxy" then
        local record = runtime.turbines_by_unit[unit_number]
        if record then
            if record.proxy_unit_number then
                runtime.proxy_to_unit[record.proxy_unit_number] = nil
            end
            record.proxy = nil
            record.proxy_unit_number = nil
            record.proxy_registration = nil

            local entity = ei_lib.get_valid_entity(record.entity)
            if entity and entity.name == FLUID_NAME then
                ensure_open_proxy(runtime, record)
            else
                unregister_record(runtime, unit_number, true)
            end
        else
            for proxy_unit_number, mapped_unit_number in pairs(runtime.proxy_to_unit) do
                if mapped_unit_number == unit_number then
                    runtime.proxy_to_unit[proxy_unit_number] = nil
                end
            end
        end
        return
    end

    unregister_record(runtime, unit_number, true)
end

function model.on_player_left_game(player_index)
    local player = game and game.get_player(player_index) or nil
    if player then
        model.close_gui(player)
    else
        get_runtime().open_by_player[player_index] = nil
    end
end

function model.get_runtime_status()
    local runtime = get_runtime()
    local tracked = 0
    local fluid = 0
    local solid = 0
    local stale = nil

    for unit_number, record in pairs(runtime.turbines_by_unit) do
        local entity = ei_lib.get_valid_entity(record.entity)
        if entity and is_turbine(entity) then
            tracked = tracked + 1
            if entity_mode(entity) == MODE_FLUID then
                fluid = fluid + 1
            else
                solid = solid + 1
            end
        else
            stale = stale or {}
            stale[#stale + 1] = unit_number
        end
    end

    if stale then
        for _, unit_number in ipairs(stale) do
            unregister_record(runtime, unit_number, true)
        end
    end

    return {
        tracked_turbines = tracked,
        solid_mode_turbines = solid,
        fluid_mode_turbines = fluid,
        open_gui_count = table_count(runtime.open_by_player),
    }
end

---@param event EventData.script_raised_teleported
function model.on_moved_entity(event)
    local turbine = event.entity
    if not is_turbine(turbine) then return turbine end
    local runtime = get_runtime()
    local record = runtime.turbines_by_unit[turbine.unit_number]
    local proxy = record and ei_lib.get_valid_entity(record.proxy)
    -- Passing a surface invokes native cross-surface teleport, which is not
    -- supported for machines even when that surface equals the current one.
    if proxy then proxy.teleport(turbine.position) end
    register_turbine(runtime, turbine, event)
    return model.swap_to_mode(turbine,entity_mode(turbine),event)
end

function model.has_tick_work()
    local runtime=storage.ei and storage.ei.combustion_turbine
    return runtime and next(runtime.units_by_surface)~=nil
end

-- One pressure query per occupied surface; native entities own all production.
function model.updater(event)
    if event.tick % config.pressure_interval~=0 then return end
    local runtime=get_runtime()
    local pending={}
    for surface_index,units in pairs(runtime.units_by_surface) do
        local surface=game.get_surface(surface_index)
        if surface then
            local forced=process.forced(surface)
            if runtime.pressure_by_surface[surface_index]~=forced then
                runtime.pressure_by_surface[surface_index]=forced
                for unit in pairs(units) do pending[unit]=true end
            end
        end
    end
    for unit in pairs(runtime.retry_units) do pending[unit]=true end
    for unit in pairs(pending) do
        local record=runtime.turbines_by_unit[unit]
        if record and is_turbine(record.entity) then
            model.swap_to_mode(record.entity,entity_mode(record.entity),event)
        end
    end
    local snapshots={}
    for player_index,unit in pairs(runtime.open_by_player) do
        local record=runtime.turbines_by_unit[unit]
        local player=game.get_player(player_index)
        if player and player.connected and record and is_turbine(record.entity) then
            snapshots[unit]=snapshots[unit] or read_generation(record)
            model.update_gui(player,record.entity,event,snapshots[unit])
        else close_gui_for_player(runtime,player_index) end
    end
end

return model
