--==============================================================================
-- ESIR FILE MAP
-- owns: combustion turbine fuel-mode GUI and solid/fluid shell swaps
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy/clone/settings-paste/object-destroyed and GUI open/close/click
-- forwarded_events: check_global, close_gui, get_runtime_status, on_built_entity,
--                   on_configuration_changed, on_destroyed_entity,
--                   on_entity_settings_pasted, on_gui_click, on_gui_closed, on_object_destroyed,
--                   on_player_left_game, open_gui, rebuild_runtime_state
-- storage_roots: storage.ei.combustion_turbine
-- gui_ids: ei-combustion-turbine-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, turbine build/destroy/shell swap
--==============================================================================

local model = {}

local ei_lib = require("lib/lib")

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
}

local MODE_TO_ENTITY = {
    [MODE_SOLID] = SOLID_NAME,
    [MODE_FLUID] = FLUID_NAME,
}

model.gui_name = GUI_NAME
model.solid_name = SOLID_NAME
model.fluid_name = FLUID_NAME
model.fluid_open_proxy_name = FLUID_OPEN_PROXY_NAME

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
    local ok, connectors = pcall(entity.get_wire_connectors, entity, false)
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

local function retarget_open_players(runtime, player_indexes, unit_number, entity)
    for _, player_index in ipairs(player_indexes or {}) do
        runtime.open_by_player[player_index] = unit_number
        local player = game and game.get_player(player_index) or nil
        if player and player.valid then
            pcall(function()
                player.opened = entity
            end)
            if is_open_proxy(entity) then
                runtime.proxy_open_tick_by_player[player_index] = game and game.tick or 0
            end
            local root = model.update_gui(player, entity)
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
    if not (script and script.register_on_object_destroyed and (is_turbine(entity) or is_open_proxy(entity))) then
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

local function unregister_record(runtime, unit_number, close_guis)
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
    remove_surface_membership(runtime, record.surface_index, unit_number)
    runtime.turbines_by_unit[unit_number] = nil

    if close_guis then
        close_guis_for_unit(runtime, unit_number)
    end
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
    record.surface_index = entity.surface and entity.surface.index or nil
    record.last_seen_tick = now_tick(event_or_tick)
    add_surface_membership(runtime, record.surface_index, unit_number)

    if record.mode == MODE_FLUID then
        ensure_open_proxy(runtime, record)
    else
        destroy_open_proxy(runtime, record)
        destroy_open_proxies_at_turbine(runtime, entity)
    end

    return record
end

local function resolve_turbine_entity(entity, runtime)
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
            record = register_turbine(runtime, candidate, game and game.tick or 0)
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

local function get_opened_turbine(player, runtime)
    local opened = ei_lib.get_valid_entity(player and player.opened)
    local opened_turbine = resolve_turbine_entity(opened, runtime)
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

function model.swap_to_mode(entity, requested_mode, event_or_tick, player_index)
    requested_mode = normalize_mode(requested_mode)
    if not (is_turbine(entity) and requested_mode) then
        return entity
    end

    local current_mode = entity_mode(entity)
    local runtime = get_runtime()
    local record = register_turbine(runtime, entity, event_or_tick)
    if current_mode == requested_mode then
        return entity
    end

    local target_name = MODE_TO_ENTITY[requested_mode]
    if not target_name then
        return entity
    end

    local old_unit_number = record and record.unit_number or ei_lib.get_entity_unit_number(entity)
    local open_players = collect_open_players(runtime, old_unit_number)
    local old_name = entity.name
    local surface = entity.surface
    local force = entity.force
    local position = entity.position
    local direction = entity.direction
    local quality = entity.quality
    local health = entity.health
    local energy = tonumber(entity.energy) or 0
    local saved_connections = get_real_circuit_connections(entity)

    if requested_mode == MODE_SOLID then
        destroy_open_proxies_at_turbine(runtime, entity)
    end

    if requested_mode == MODE_FLUID then
        spill_burner_inventories(entity)
    end

    unregister_record(runtime, old_unit_number, false)
    entity.destroy({raise_destroy = false})

    local replacement = create_turbine_shell(surface, target_name, position, force, direction, quality)

    if not is_turbine(replacement) then
        local restored = create_turbine_shell(surface, old_name, position, force, direction, quality)
        if is_turbine(restored) then
            clamp_health(restored, health)
            pcall(function()
                restored.energy = energy
            end)
            restore_circuit_connections(restored, saved_connections)
            local restored_record = register_turbine(runtime, restored, event_or_tick)
            local restored_unit_number = restored_record and restored_record.unit_number or ei_lib.get_entity_unit_number(restored)
            local restored_opened_entity = restored_record
                and restored_record.mode == MODE_FLUID
                and ei_lib.get_valid_entity(restored_record.proxy)
                or restored
            retarget_open_players(runtime, open_players, restored_unit_number, restored_opened_entity)
        else
            for _, open_player_index in ipairs(open_players) do
                close_gui_for_player(runtime, open_player_index)
            end
        end

        if player_index and game then
            local player = game.get_player(player_index)
            if player then
                player.print({"exotic-industries.combustion-turbine-gui-swap-failed"})
            end
        end
        return restored
    end

    clamp_health(replacement, health)
    pcall(function()
        replacement.energy = energy
    end)
    restore_circuit_connections(replacement, saved_connections)

    local new_record = register_turbine(runtime, replacement, event_or_tick)
    local new_unit_number = new_record and new_record.unit_number or ei_lib.get_entity_unit_number(replacement)
    local opened_entity = new_record
        and new_record.mode == MODE_FLUID
        and ei_lib.get_valid_entity(new_record.proxy)
        or replacement
    retarget_open_players(runtime, open_players, new_unit_number, opened_entity)

    return replacement
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

    main.add{
        type = "frame",
        style = "ei_subheader_frame_with_top_border",
    }.add{
        type = "label",
        caption = {"exotic-industries.combustion-turbine-gui-mode-title"},
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

    return root
end

function model.update_gui(player, entity)
    local runtime = get_runtime()
    local opened_entity = ei_lib.get_valid_entity(entity)
    local opened_via_proxy = is_open_proxy(opened_entity)
    entity = resolve_turbine_entity(opened_entity, runtime)
        or get_opened_turbine(player, runtime)
    if not is_turbine(entity) then
        model.close_gui(player)
        return nil
    end

    local record = register_turbine(runtime, entity, game and game.tick or 0)
    if not record then
        model.close_gui(player)
        return nil
    end

    local force_screen = opened_via_proxy or record.mode == MODE_FLUID
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
    status_flow["mode-label"].caption = {
        "exotic-industries.combustion-turbine-gui-mode",
        get_mode_caption(mode),
    }
    status_flow["agent-label"].caption = mode == MODE_FLUID
        and {"exotic-industries.combustion-turbine-gui-agent-fluid"}
        or {"exotic-industries.combustion-turbine-gui-agent-solid"}
    if status_flow["fluid-hotspot-tip-label"] then
        status_flow["fluid-hotspot-tip-label"].visible = mode == MODE_FLUID
        status_flow["fluid-hotspot-tip-label"].caption = mode == MODE_FLUID
            and {"exotic-industries.combustion-turbine-gui-fluid-hotspot-tip"}
            or ""
    end

    button_flow["solid-mode-button"].style = mode == MODE_SOLID and "ei_green_button" or "button"
    button_flow["fluid-mode-button"].style = mode == MODE_FLUID and "ei_green_button" or "button"
    return root
end

function model.open_gui(player, entity)
    if not (player and player.valid) then
        return
    end
    local runtime = get_runtime()
    local opened_entity = ei_lib.get_valid_entity(entity)
    local opened_via_proxy = is_open_proxy(opened_entity)
    entity = resolve_turbine_entity(opened_entity, runtime)
        or get_opened_turbine(player, runtime)
    if not is_turbine(entity) then
        model.close_gui(player)
        return
    end

    local record = register_turbine(runtime, entity, game and game.tick or 0)
    if not record then
        model.close_gui(player)
        return
    end
    runtime.open_by_player[player.index] = record.unit_number
    if opened_via_proxy then
        runtime.proxy_open_tick_by_player[player.index] = game and game.tick or 0
    end
    local root = model.update_gui(player, opened_entity or entity)
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
    local entity = get_opened_turbine(player, runtime)
    if not is_turbine(entity) then
        model.close_gui(player)
        return
    end

    local replacement = model.swap_to_mode(entity, element.tags.mode, event, player.index)
    if is_turbine(replacement) then
        model.update_gui(player, replacement)
    else
        model.close_gui(player)
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
        for _, entity in pairs(surface.find_entities_filtered{name = {SOLID_NAME, FLUID_NAME}}) do
            register_turbine(runtime, entity, event_or_tick)
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

function model.on_built_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not is_turbine(entity) then
        return
    end

    local tags = nil
    local player_index = nil
    if not ei_lib.entity_check(event_or_entity) and type(event_or_entity) == "table" then
        tags = event_or_entity.tags
        player_index = event_or_entity.player_index
    end

    local requested_mode = mode_from_tags(tags)
    local runtime = get_runtime()
    register_turbine(runtime, entity, event_or_entity)

    if requested_mode and requested_mode ~= entity_mode(entity) then
        model.swap_to_mode(entity, requested_mode, event_or_entity, player_index)
    end
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
    local source = resolve_turbine_entity(event and event.source or nil, runtime)
    local destination = resolve_turbine_entity(event and event.destination or nil, runtime)
    if not (is_turbine(source) and is_turbine(destination)) then
        return
    end

    local source_mode = entity_mode(source)
    local replacement = model.swap_to_mode(destination, source_mode, event, event.player_index)
    if is_turbine(replacement) then
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
            if entity.name == FLUID_NAME then
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

return model
