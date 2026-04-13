--==============================================================================
-- ESIR FILE MAP
-- owns: induction matrix GUI, runtime, and tile hooks
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build, destroy, tile changes, GUI dispatch, and every-tick runtime updates
-- forwarded_events: apply_stats, buff_function, calculate_stats, check_connected_tiles, check_global_init, check_tile, close_gui, destroy_wire_proxy, ensure_wire_proxy, entity_check, find_existing_wire_proxy, force_visual_update, get_adjacent_tiles, get_connected_solenoid_count, get_core_entity, get_core_tier, get_gui, get_matrix_capacity, get_matrix_current_stored_power, get_matrix_id, get_matrix_max_IO, get_max_connected_tiles, get_real_circuit_connections, get_sorted_lookup_names, is_core, lookup_tile_for_entity, mark_dirty, on_built_entity, on_built_tile, on_destroyed_entity, on_destroyed_tile, on_gui_click, open_gui, queue_tile_render, rebuild_runtime_state, remove_old_cores, remove_stat_text, render_tile_box, reset_matrix_table, reset_runtime_storage, resolve_duplicate_cores, restore_circuit_connections, retag_matrix_guis, retag_wire_proxy, set_core_state, show_stats, swap_core, swap_global_table, table_concat, to_wire_signal_value, update, update_core, update_dirty, update_gui, update_player_guis, update_render_queue, update_wire_outputs, update_wire_proxy_signals, wire_proxy_has_connections
-- storage_roots: storage.ei
-- gui_ids: ei-induction-matrix-console
-- remote_interfaces: none
-- rebuild_on: tile topology changes, entity topology changes
--==============================================================================
local model = {}
local ei_runtime_scheduler = require("lib/runtime-scheduler")
-- induction-matrix.lua owns the runtime behavior of the matrix multistructure.
--
-- The high-level model is:
-- - tiles define the legal footprint and connected shape of a matrix
-- - exactly one core is the identity anchor for a connected matrix
-- - coils / solenoids / converters contribute derived stats
-- - the connected footprint is rebuilt by flood-fill when something changes
-- - dirty matrices are recomputed on update rather than immediately everywhere
-- - a hidden circuit proxy is kept in sync with the visible core because the actual
--   electric-energy-interface is not the circuit-network endpoint players interact with
local SIGNAL_MATRIX_CHARGE = {type = "virtual", name = "signal-C", quality = "normal", comparator = "="}
local SIGNAL_MATRIX_CAPACITY = {type = "virtual", name = "signal-T", quality = "normal", comparator = "="}
local SIGNAL_MATRIX_MAX_IO = {type = "virtual", name = "signal-M", quality = "normal", comparator = "="}
local MATRIX_WIRE_PROXY_NAME = "ei-induction-matrix-core-circuit-interface"
local MATRIX_SIGNAL_LIMIT = 2147483647
local MATRIX_WIRE_UPDATE_INTERVAL = 60

local function get_matrix_wire_slot(matrix_id)
    return matrix_id % MATRIX_WIRE_UPDATE_INTERVAL
end

local function get_stat_text_key(surface, pos)
    local surface_index = surface and surface.index or 0
    return table.concat({surface_index, pos.x, pos.y}, ":")
end

local function mark_wire_slots_dirty()
    if storage and storage.ei and storage.ei.induction_matrix then
        storage.ei.induction_matrix.wire_slots_rebuild_needed = true
    end
end

--====================================================================================================
--INDUCTION MATRIX
--====================================================================================================

function model.table_concat(t1, t2)
    -- These lookup tables are used as sparse sets, so a shallow key copy is enough.
    for i,v in pairs(t2) do
        t1[i] = v
    end

    return t1
end

function model.get_sorted_lookup_names(lookup)
    -- Factorio filtered entity searches need dense arrays, while the rest of this script
    -- prefers sparse lookup sets for fast membership checks.

    local names = {}

    for name in pairs(lookup) do
        table.insert(names, name)
    end

    table.sort(names)

    return names
end

-- given capacitance of infuction coils in MJ
model.coils = {
    ["ei-induction-matrix-basic-coil"] = 25,
    ["ei-induction-matrix-advanced-coil"] = 100,
    ["ei-induction-matrix-superior-coil"] = 1000,
}


model.solenoids = {
    ["ei-induction-matrix-basic-solenoid"] = 1,
    ["ei-induction-matrix-advanced-solenoid"] = 0.5,
}


-- better converters may count as more than one converter
model.converters = {
    ["ei-induction-matrix-basic-converter"] = 1,
    ["ei-induction-matrix-advanced-converter"] = 2,
    ["ei-induction-matrix-superior-converter"] = 4,
}


model.core = {
    ["ei-induction-matrix-core-0"] = true,
    ["ei-induction-matrix-core-1"] = true,
    ["ei-induction-matrix-core-2"] = true,
    ["ei-induction-matrix-core-3"] = true,
    ["ei-induction-matrix-core-4"] = true,
    ["ei-induction-matrix-core-5"] = true,
    ["ei-induction-matrix-core-6"] = true,
    ["ei-induction-matrix-core-7"] = true,
    ["ei-induction-matrix-core-8"] = true,
    ["ei-induction-matrix-core-9"] = true,
    ["ei-induction-matrix-core-10"] = true,
    ["ei-induction-matrix-core-11"] = true,
    ["ei-induction-matrix-core-12"] = true,
    ["ei-induction-matrix-core-13"] = true,
    ["ei-induction-matrix-core-14"] = true,
    ["ei-induction-matrix-core-15"] = true,
    ["ei-induction-matrix-core-16"] = true,
}

model.proxy = {
    [MATRIX_WIRE_PROXY_NAME] = true,
}


-- `only_on_tile` is the set of matrix entities that are only legal on matrix tiles.
-- `but_cores` is the same set minus cores, used where components and cores need slightly
-- different handling in lifecycle code.
model.only_on_tile = {}
model.only_on_tile = model.table_concat(model.only_on_tile, model.coils)
model.only_on_tile = model.table_concat(model.only_on_tile, model.solenoids)
model.only_on_tile = model.table_concat(model.only_on_tile, model.converters)
model.only_on_tile = model.table_concat(model.only_on_tile, model.core)

model.but_cores = {}
model.but_cores = model.table_concat(model.but_cores, model.coils)
model.but_cores = model.table_concat(model.but_cores, model.solenoids)
model.but_cores = model.table_concat(model.but_cores, model.converters)


--DOC
------------------------------------------------------------------------------------------------------

-- Runtime flow in one pass:
-- 1. a build/tile/gui action identifies a matrix footprint that may have changed
-- 2. `check_connected_tiles()` flood-fills the footprint and rebuilds membership tables
-- 3. the matrix gets marked dirty rather than fully recalculated in every handler
-- 4. `update_dirty()` recomputes stats and swaps the core variant if IO changed
-- 5. `update_wire_outputs()` mirrors the current stats/charge to the hidden proxy
--
-- If a core id is not known ahead of time, the flood-fill tries to discover one while it
-- walks the connected tiles.


--CHECKS
-----------------------------------------------------------------------------------------------------

function model.check_global_init()
    -- The matrix stores everything under one storage subtree:
    -- - render_queue: transient queued rectangle/text renders
    -- - core[matrix_id]: one record per logical matrix
    -- - to_remove: deferred cleanup for old core ids after swaps/tile destruction
    -- - proxy[proxy_unit_number] -> matrix_id: reverse lookup for the hidden wire proxy

    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei.induction_matrix then
        storage.ei.induction_matrix = {}
    end

    if not storage.ei.induction_matrix.render_queue then
        storage.ei.induction_matrix.render_queue = {}
    end

    storage.ei.induction_matrix.render_buckets = ei_runtime_scheduler.ensure_delayed_buckets(storage.ei.induction_matrix.render_buckets)
    storage.ei.induction_matrix.stat_text_index = storage.ei.induction_matrix.stat_text_index or {}
    storage.ei.induction_matrix.dirty_core_queue = ei_runtime_scheduler.ensure_queue(storage.ei.induction_matrix.dirty_core_queue)
    storage.ei.induction_matrix.wire_update_slots = storage.ei.induction_matrix.wire_update_slots or {}

    if not storage.ei.induction_matrix.core then
        storage.ei.induction_matrix.core = { 
            stats = {
                max_IO = 0,
                capacity = 0
            }
        }
    end

    if not storage.ei.induction_matrix.to_remove then
        storage.ei.induction_matrix.to_remove = {}
    end

    if not storage.ei.induction_matrix.proxy then
        storage.ei.induction_matrix.proxy = {}
    end

    if storage.ei.induction_matrix.dirty_queue_backfilled == nil then
        storage.ei.induction_matrix.dirty_queue_backfilled = false
    end

    if storage.ei.induction_matrix.wire_slots_rebuild_needed == nil then
        storage.ei.induction_matrix.wire_slots_rebuild_needed = true
    end

end

local function ensure_wire_update_slots()
    local matrix_state = storage.ei.induction_matrix
    if not matrix_state.wire_slots_rebuild_needed and matrix_state.wire_update_slots then
        return matrix_state.wire_update_slots
    end

    local slots = {}
    for matrix_id, matrix_data in pairs(matrix_state.core or {}) do
        if type(matrix_id) == "number" and matrix_data then
            local slot = get_matrix_wire_slot(matrix_id)
            slots[slot] = slots[slot] or {}
            slots[slot][matrix_id] = true
        end
    end

    matrix_state.wire_update_slots = slots
    matrix_state.wire_slots_rebuild_needed = false
    return slots
end

local function backfill_dirty_core_queue()
    local matrix_state = storage.ei.induction_matrix
    if matrix_state.dirty_queue_backfilled then
        return
    end

    matrix_state.dirty_queue_backfilled = true
    for matrix_id, matrix_data in pairs(matrix_state.core or {}) do
        if type(matrix_id) == "number" and matrix_data and matrix_data.dirty then
            ei_runtime_scheduler.queue_push_unique(matrix_state.dirty_core_queue, matrix_id, matrix_id)
        end
    end
end

local function schedule_render_entry(entry)
    local matrix_state = storage.ei.induction_matrix
    matrix_state.render_buckets = ei_runtime_scheduler.delayed_schedule(matrix_state.render_buckets, entry.tick, entry)
end


function model.entity_check(entity)
    -- This helper is intentionally tiny because it is called in many hot paths.

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end


function model.check_tile(entity)
    -- Matrix legality is tile-driven. Components are rejected early if the correct tile
    -- footprint is missing so later flood-fill/stat code can assume the entity is legal.
    -- 1x1 parts only need the center tile; 2x2 parts need all four covered tiles.

    -- exclude ghost entities
    if entity.type == "entity-ghost" or entity.type == "tile-ghost" then
        return false
    end

    -- for matrix core and converter the footprint is 2x2

    if model.core[entity.name] or model.converters[entity.name] then

        local tiles = entity.surface.count_tiles_filtered({
            area = {{entity.position.x - 0.5, entity.position.y - 0.5}, {entity.position.x + 0.5, entity.position.y + 0.5}},
            name = "ei-induction-matrix-tile",
        })

        if tiles ~= 4 then
            rendering.draw_text{
                target = entity,
                text = "This entity must be placed on a induction matrix tile",
                color = {r=1, g=0, b=0},
                surface = entity.surface,
                scale = 1,
                time_to_live = 120
            }
            return false
        end

        return true

    else

        local tile = entity.surface.get_tile(entity.position)

        if tile.name ~= "ei-induction-matrix-tile" then
            rendering.draw_text{
                target = entity,
                text = "This entity must be placed on a induction matrix tile",
                color = {r=1, g=0, b=0},
                surface = entity.surface,
                scale = 1,
                time_to_live = 120
            }
            return false
        end

        return true

    end
end


--FLOODFIL LOGIC RELATED
-----------------------------------------------------------------------------------------------------

function model.check_connected_tiles(pos, surface, render, matrix_id, force, event)
    -- This is the authoritative matrix rebuild pass.
    --
    -- Starting from one tile position, it flood-fills every orthogonally connected matrix
    -- tile, optionally discovering a core if the caller did not already provide one.
    -- While traversing, it rebuilds the matrix membership tables by scanning each tile for
    -- coils / solenoids / converters / cores.
    --
    -- Importantly, when `matrix_id` is provided we reset that matrix's component tables
    -- first and then repopulate them from scratch. This avoids stale membership after tile
    -- edits, removals, or duplicate-core cleanup.

    local max_connected_tiles = model.get_max_connected_tiles(force)
    local tile = surface.get_tile({x=pos.x - 0.25, y=pos.y - 0.25})
    local pos = tile.position

    if not tile then
        return false
    end

    if tile.name ~= "ei-induction-matrix-tile" then
        return false
    end

    local tile_queue = {}
    local known_tiles = {}
    local progress_list = {}
    local matrix_id = matrix_id

    -- add tile to todo que
    table.insert(tile_queue, pos)
    known_tiles[pos.x .. "," .. pos.y] = true

    -- if matrix_id is give nthen reset the matrix table first
    if matrix_id then
        model.reset_matrix_table(matrix_id)
    end

    while true do

        if #tile_queue == 0 then
            break
        end

        -- get first tile in que
        local tile_pos = tile_queue[1]

        -- get all adjacent tiles that are induction matrix tiles
        local adjacent_tiles = model.get_adjacent_tiles(tile_pos, surface)

        -- add adjacent tiles to que
        for _, adjacent_tile in ipairs(adjacent_tiles) do
            if known_tiles[adjacent_tile.position.x .. "," .. adjacent_tile.position.y] == nil then
                table.insert(tile_queue, adjacent_tile.position)
                known_tiles[adjacent_tile.position.x .. "," .. adjacent_tile.position.y] = true
            end
        end

        -- remove tile from que
        table.remove(tile_queue, 1)

        -- add the tile to the progress list
        table.insert(progress_list, tile_pos)

        if matrix_id then
            -- look if there is a entity on tile and if so add it to the matrix table
            local updated_matrix_id = model.lookup_tile_for_entity(tile_pos, surface, matrix_id)
            if updated_matrix_id then
                matrix_id = updated_matrix_id
            end
        else
            -- is a core ontop of this tile? if yes then return the matrix id
            matrix_id = model.is_core(tile_pos, surface)
        end

    end

    -- get lenght of known tiles
    local known_lenght = 0
    for _,_ in pairs(known_tiles) do
        known_lenght = known_lenght + 1
    end

    if known_lenght > max_connected_tiles then
        rendering.draw_text{
            target = pos,
            text = "Matrix overflow!",
            color = {r=1, g=0, b=0},
            surface = surface,
            scale = 1,
            time_to_live = 120
        }

        rendering.draw_text{
            target = {x=pos.x, y=pos.y + 0.5},
            text = "Max supported tiles are: " .. max_connected_tiles,
            color = {r=1, g=0, b=0},
            surface = surface,
            scale = 1,
            time_to_live = 120
        }

        if render == true then
            model.queue_tile_render(surface, progress_list, {r=1, g=0, b=0, a=0.001},event)
        end

        return {["state"] = false, ["matrix_id"] = matrix_id, ["tiles"] = known_lenght}
    end

    if render == true then
        model.queue_tile_render(surface, progress_list, {r=0, g=1, b=0, a=0.001},event)
    end

    return {["state"] = true, ["matrix_id"] = matrix_id, ["tiles"] = known_lenght}

end

---@param surface LuaSurface
function model.lookup_tile_for_entity(pos, surface, matrix_id)
    -- Each tile contributes entities to the logical matrix record. This is the bridge
    -- between the tile flood-fill and the per-matrix component lists.
    model.check_global_init()

    local entities = surface.find_entities({
        {pos.x-0.25, pos.y-0.25},
        {pos.x+0.25, pos.y+0.25}
    })

    for _, entity in ipairs(entities) do

        if not storage.ei.induction_matrix.core[matrix_id] then
            goto contin
        end

        if not entity.valid then
            goto contin
        end

        local unit = entity.unit_number
        -- check for every entity if it is already known, if not add it

        if model.coils[entity.name] then
            if not storage.ei.induction_matrix.core[matrix_id].coils[unit] then
                storage.ei.induction_matrix.core[matrix_id].coils[unit] = entity
            end
        end

        if model.converters[entity.name] then
            if not storage.ei.induction_matrix.core[matrix_id].converters[unit] then
                storage.ei.induction_matrix.core[matrix_id].converters[unit] = entity
            end
        end

        if model.solenoids[entity.name] then
            if not storage.ei.induction_matrix.core[matrix_id].solenoids[unit] then
                storage.ei.induction_matrix.core[matrix_id].solenoids[unit] = entity
            end
        end

        if model.core[entity.name] then

            if not storage.ei.induction_matrix.core[matrix_id] then
                goto continue
            end

            if not storage.ei.induction_matrix.core[matrix_id].core[unit] then
                storage.ei.induction_matrix.core[matrix_id].core[unit] = entity
            end

            matrix_id = model.resolve_duplicate_cores(matrix_id, pos)

            ::continue::

        end

        ::contin::

    end

    return matrix_id

end


function model.retag_matrix_guis(old_id, new_id)
    -- Core swaps change the matrix's unit-number identity. GUIs track matrix_id in tags,
    -- so they must be retagged or the next GUI refresh points at dead storage.

    if old_id == new_id then
        return
    end

    for _, player in pairs(game.connected_players) do
        local root = model.get_gui(player)
        if root and root.tags.matrix_id == old_id then
            root.tags = {matrix_id = new_id}
        end
    end

end


function model.resolve_duplicate_cores(matrix_id, pos)
    -- Only one core is allowed per connected matrix.
    --
    -- Because the flood-fill may discover multiple core entities in one footprint, this
    -- function selects one survivor, repairs storage/gui/proxy ownership to match that
    -- survivor, spills the extra cores back as items, and destroys the duplicates.
    --
    -- The caller's matrix_id is treated as the preferred survivor when possible so
    -- behavior stays deterministic for the matrix that triggered the rebuild.

    model.check_global_init()

    local matrix_table = storage.ei.induction_matrix.core[matrix_id]

    if not matrix_table then
        return matrix_id
    end

    local valid_cores = {}
    local core_count = 0

    for unit, core in pairs(matrix_table.core) do
        if model.entity_check(core) then
            valid_cores[unit] = core
            core_count = core_count + 1
        else
            storage.ei.induction_matrix.core[unit] = nil
        end
    end

    matrix_table.core = valid_cores

    local original_matrix_id = matrix_id
    local survivor = valid_cores[matrix_id]

    if not survivor and core_count > 0 then
        for unit, core in pairs(valid_cores) do
            matrix_id = unit
            survivor = core
            break
        end

        storage.ei.induction_matrix.core[matrix_id] = matrix_table
        storage.ei.induction_matrix.core[original_matrix_id] = nil
        model.retag_matrix_guis(original_matrix_id, matrix_id)

        local proxy = matrix_table.wire_proxy
        if model.entity_check(proxy) then
            model.retag_wire_proxy(proxy, matrix_id)
        end
    end

    if core_count <= 1 then
        matrix_table.core = survivor and {[matrix_id] = survivor} or {}
        return matrix_id
    end

    matrix_table.core = {[matrix_id] = survivor}

    for unit, duplicate in pairs(valid_cores) do
        if unit ~= matrix_id then
            model.destroy_wire_proxy(unit)
            storage.ei.induction_matrix.core[unit] = nil

            rendering.draw_text{
                target = duplicate,
                text = "Only one core per matrix allowed",
                color = {r=1, g=0, b=0},
                surface = duplicate.surface,
                scale = 1,
                time_to_live = 120
            }

            duplicate.surface.spill_item_stack{
                position = duplicate.position,
                stack = {name = "ei-induction-matrix-core", count = 1},
                enable_looted = true
            }

            rendering.draw_animation({
                animation = "ei-overload-animation",
                target = {pos.x, pos.y},
                surface = duplicate.surface,
                render_layer = 139,
                time_to_live = 60,
                x_scale = 2,
                y_scale = 2,
            })

            duplicate.destroy({raise_destroy=false})
        end
    end

    return matrix_id

end


function model.get_adjacent_tiles(pos, surface)
    -- Matrix connectivity is orthogonal only; diagonals never connect separate matrix tiles.

    local tiles = {}
    -- get tiles to north, east, south, west
    local north_tile = surface.get_tile({pos.x, pos.y-1})
    local east_tile = surface.get_tile({pos.x+1, pos.y})
    local south_tile = surface.get_tile({pos.x, pos.y+1})
    local west_tile = surface.get_tile({pos.x-1, pos.y})

    if north_tile.name == "ei-induction-matrix-tile" then
        table.insert(tiles, north_tile)
    end

    if east_tile.name == "ei-induction-matrix-tile" then
        table.insert(tiles, east_tile)
    end

    if south_tile.name == "ei-induction-matrix-tile" then
        table.insert(tiles, south_tile)
    end

    if west_tile.name == "ei-induction-matrix-tile" then
        table.insert(tiles, west_tile)
    end

    return tiles
end


--UTIL
-----------------------------------------------------------------------------------------------------

function model.get_matrix_id(entity)
    -- Players may interact with either the visible core or the hidden proxy. This helper
    -- resolves both to the logical matrix id expected by the rest of the script.

    if model.entity_check(entity) == false then
        return nil
    end

    if model.core[entity.name] then
        return entity.unit_number
    end

    if model.proxy[entity.name] then
        model.check_global_init()
        return storage.ei.induction_matrix.proxy[entity.unit_number]
    end

    return nil

end

function model.to_wire_signal_value(value)
    -- Circuit network values are bounded ints. Matrix capacity is measured in MJ and can
    -- grow large enough that the script should clamp defensively before writing signals.
    -- Use the same rounding convention as the GUI text so hovered values and wire values
    -- do not drift by 1 MJ due to floor-vs-round differences.

    value = tonumber(string.format("%.0f", value or 0)) or 0

    if value > MATRIX_SIGNAL_LIMIT then
        return MATRIX_SIGNAL_LIMIT
    end

    if value < -MATRIX_SIGNAL_LIMIT then
        return -MATRIX_SIGNAL_LIMIT
    end

    return value

end

function model.remove_old_cores()
    -- Core swaps leave the old storage key scheduled for deferred cleanup because callers
    -- may still be iterating the old table in the same overall update pass.

    if not storage.ei.induction_matrix.to_remove then
        return
    end

    -- loop over storage.ei.induction_matrix.to_remove
    for _, matrix_id in ipairs(storage.ei.induction_matrix.to_remove) do

        if storage.ei.induction_matrix.core[matrix_id] then
            storage.ei.induction_matrix.core[matrix_id] = nil
        end

    end

    storage.ei.induction_matrix.to_remove = {}

end


function model.get_real_circuit_connections(entity)
    -- When the core prototype changes tier, the entity is replaced rather than mutated in
    -- place. We therefore snapshot real circuit wire peers so the new core can reconnect.

    if model.entity_check(entity) == false then
        return {}
    end

    local saved_connections = {}
    local connectors = entity.get_wire_connectors(false)

    for connector_id, connector in pairs(connectors) do
        if not connector.valid then
            goto continue
        end

        for _, connection in ipairs(connector.real_connections) do
            if connection.target and connection.target.valid then
                table.insert(saved_connections, {
                    source_id = connector_id,
                    target = connection.target,
                    origin = connection.origin,
                })
            end
        end

        ::continue::
    end

    return saved_connections

end


function model.retag_wire_proxy(proxy, matrix_id)
    -- The proxy -> matrix_id reverse mapping is the runtime link that lets GUI opening and
    -- proxy destruction find the real matrix record again.

    model.check_global_init()

    if model.entity_check(proxy) == false then
        return
    end

    storage.ei.induction_matrix.proxy[proxy.unit_number] = matrix_id

end


function model.destroy_wire_proxy(matrix_id)
    -- Proxy teardown is a first-class operation because the proxy can outlive the visible
    -- core if not explicitly cleaned up during duplicate-core removal or tile destruction.

    model.check_global_init()

    local matrix = storage.ei.induction_matrix.core[matrix_id]
    if not matrix then
        return
    end

    local proxy = matrix.wire_proxy
    if model.entity_check(proxy) then
        storage.ei.induction_matrix.proxy[proxy.unit_number] = nil
        proxy.destroy({raise_destroy=false})
    end

    matrix.wire_proxy = nil
    matrix.signal_cache = nil

end


function model.ensure_wire_proxy(matrix_id)
    -- Old saves, core swaps, and various rebuild paths can all end up with a valid matrix
    -- but no proxy entity. This helper makes proxy existence idempotent.

    model.check_global_init()

    local matrix = storage.ei.induction_matrix.core[matrix_id]
    if not matrix then
        return nil
    end

    local proxy = matrix.wire_proxy
    if model.entity_check(proxy) then
        model.retag_wire_proxy(proxy, matrix_id)
        return proxy
    end

    local core = model.get_core_entity(matrix_id)
    if model.entity_check(core) == false then
        return nil
    end

    proxy = core.surface.create_entity{
        name = MATRIX_WIRE_PROXY_NAME,
        position = core.position,
        force = core.force,
        create_build_effect_smoke = false,
        raise_built = false,
    }

    if model.entity_check(proxy) == false then
        return nil
    end

    matrix.wire_proxy = proxy
    matrix.signal_cache = nil
    model.retag_wire_proxy(proxy, matrix_id)

    return proxy

end


function model.wire_proxy_has_connections(proxy)
    -- Constant-combinator writes are only useful when the proxy is actually wired into
    -- a circuit network, so we cheaply scan its connectors before doing signal work.

    if model.entity_check(proxy) == false then
        return false
    end

    local connectors = proxy.get_wire_connectors(false)
    for _, connector in pairs(connectors) do
        if connector.valid and #connector.real_connections > 0 then
            return true
        end
    end

    return false

end


function model.find_existing_wire_proxy(core)
    -- Manual/runtime rescans try to preserve already-wired proxy entities instead of
    -- recreating them, which would otherwise drop player circuit connections.

    if model.entity_check(core) == false then
        return nil
    end

    local fallback = nil
    local proxies = core.surface.find_entities_filtered{
        position = core.position,
        name = MATRIX_WIRE_PROXY_NAME,
    }

    for _, proxy in ipairs(proxies) do
        if model.entity_check(proxy) then
            if model.wire_proxy_has_connections(proxy) then
                return proxy
            end

            if not fallback then
                fallback = proxy
            end
        end
    end

    return fallback

end


function model.update_wire_proxy_signals(matrix_id)
    -- The hidden constant combinator is the matrix's circuit-network surface area.
    -- It emits:
    -- - signal-C: current charge in MJ
    -- - signal-T: total capacity in MJ
    -- - signal-M: max IO in MW
    --
    -- Writes are skipped when the values are unchanged to reduce section churn.

    model.check_global_init()

    local matrix = storage.ei.induction_matrix.core[matrix_id]
    if not matrix then
        return
    end

    local proxy = model.ensure_wire_proxy(matrix_id)
    if model.entity_check(proxy) == false then
        return
    end

    if model.wire_proxy_has_connections(proxy) == false then
        return
    end

    local charge = model.to_wire_signal_value(model.get_matrix_current_stored_power(matrix_id))
    local capacity = model.to_wire_signal_value(model.get_matrix_capacity(matrix_id))
    local max_io = model.to_wire_signal_value(model.get_matrix_max_IO(matrix_id))

    if matrix.signal_cache
    and matrix.signal_cache.charge == charge
    and matrix.signal_cache.capacity == capacity
    and matrix.signal_cache.max_io == max_io then
        return
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return
    end

    control.enabled = true

    local section = control.get_section(1)
    if not section then
        section = control.add_section("induction-matrix")
    end

    if not section then
        return
    end

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end

    if charge ~= 0 then
        section.set_slot(1, {value = SIGNAL_MATRIX_CHARGE, min = charge})
    end

    if capacity ~= 0 then
        section.set_slot(2, {value = SIGNAL_MATRIX_CAPACITY, min = capacity})
    end

    if max_io ~= 0 then
        section.set_slot(3, {value = SIGNAL_MATRIX_MAX_IO, min = max_io})
    end

    matrix.signal_cache = {
        charge = charge,
        capacity = capacity,
        max_io = max_io,
    }

end


function model.restore_circuit_connections(entity, saved_connections)
    -- Reconnect every captured wire after a core swap. Missing/invalid peers are ignored
    -- so a half-disconnected network does not abort the whole restoration pass.

    if model.entity_check(entity) == false then
        return
    end

    for _, connection in ipairs(saved_connections) do
        local source = entity.get_wire_connector(connection.source_id, true)

        if source and source.valid and connection.target and connection.target.valid then
            source.connect_to(connection.target, false, connection.origin)
        end
    end

end


function model.swap_core(old_id, core, max_IO)
    -- Core IO is encoded in the prototype tier name, so changing IO means replacing the
    -- entity with another prototype, not just changing a number on the existing core.
    --
    -- This helper preserves the pieces players expect to survive that swap:
    -- - copied settings
    -- - circuit wire connections
    -- - later, stored energy via apply_stats()
    -- - GUI matrix retags through retag_matrix_guis()

    local saved_connections = model.get_real_circuit_connections(core)

    local new_core = core.surface.create_entity{
        name = "ei-induction-matrix-core-"..math.floor(max_IO),
        position = core.position,
        force = core.force,
        create_build_effect_smoke = false,
        raise_built = false,
    }

    pcall(function()
        new_core.copy_settings(core)
    end)
    core.destroy({raise_destroy=false})
    model.restore_circuit_connections(new_core, saved_connections)

    storage.ei.induction_matrix.core[old_id].core = {}
    storage.ei.induction_matrix.core[old_id].core[new_core.unit_number] = new_core

    model.retag_matrix_guis(old_id, new_core.unit_number)

    return new_core.unit_number

end


function model.swap_global_table(old_id, new_id)
    -- Storage is keyed by the core entity's unit number, so a core swap also means moving
    -- the entire matrix record to the new unit number.

    local old_table = storage.ei.induction_matrix.core[old_id]

    storage.ei.induction_matrix.core[new_id] = old_table

    local proxy = old_table and old_table.wire_proxy
    if model.entity_check(proxy) then
        model.retag_wire_proxy(proxy, new_id)
    end

    if not storage.ei.induction_matrix.to_remove then
        storage.ei.induction_matrix.to_remove = {}
    end

    table.insert(storage.ei.induction_matrix.to_remove, old_id)

end


function model.apply_stats(matrix_id, old_stats, new_stats, core, state)
    -- This is the commit step after stat recomputation:
    -- - if IO tier changed or the matrix became invalid, swap the core prototype
    -- - move storage ownership if needed
    -- - update the core buffer capacity in-place
    -- - preserve stored energy across the swap
    --
    -- `state == false` forces the matrix onto the tier-0 core so an invalid matrix cannot
    -- keep a higher throughput shell than its current footprint supports.

    -- get current energy stored in the core
    local energy = core.energy
    local matrix_id = matrix_id
    local new_id = nil
    local core = core

    -- first check if the core needs to be swapped for another one
    if old_stats.max_IO ~= new_stats.max_IO or state == false then

        if state == false then
            new_id = model.swap_core(matrix_id, core, 0)
        else
            new_id = model.swap_core(matrix_id, core, new_stats.max_IO)
        end

        model.swap_global_table(matrix_id, new_id)
        storage.ei.induction_matrix.core[new_id].stats = new_stats

        -- set the new cores energy to the old one
        core = storage.ei.induction_matrix.core[new_id].core[new_id]

    else
        -- just update the stats
        storage.ei.induction_matrix.core[matrix_id].stats = new_stats

    end

    -- set the capacity of the core
    core.electric_buffer_size = new_stats.capacity*1000000

    if new_id then
        core.energy = energy
        return new_id
    else
        return matrix_id
    end

end


function model.reset_matrix_table(matrix_id)
    -- Flood-fill rebuilds component membership from scratch, but some state belongs to the
    -- logical matrix rather than the transient component lists, so we preserve it here.
    -- Notably:
    -- - stats: last known values used by GUI / wire output / comparison
    -- - wire_proxy: the hidden circuit endpoint
    -- - signal_cache: last wire values written to the proxy

    model.check_global_init()

    -- preserve old stats
    local stats = {}
    local wire_proxy = nil
    local signal_cache = nil
    if storage.ei.induction_matrix.core[matrix_id] then
        stats = storage.ei.induction_matrix.core[matrix_id].stats
        wire_proxy = storage.ei.induction_matrix.core[matrix_id].wire_proxy
        signal_cache = storage.ei.induction_matrix.core[matrix_id].signal_cache
    end

    -- reset the table
    storage.ei.induction_matrix.core[matrix_id] = {}
    storage.ei.induction_matrix.core[matrix_id].coils = {}
    storage.ei.induction_matrix.core[matrix_id].converters = {}
    storage.ei.induction_matrix.core[matrix_id].solenoids = {}
    storage.ei.induction_matrix.core[matrix_id].stats = {}
    storage.ei.induction_matrix.core[matrix_id].core = {}
    storage.ei.induction_matrix.core[matrix_id].wire_proxy = wire_proxy
    storage.ei.induction_matrix.core[matrix_id].signal_cache = signal_cache

    -- restore stats
    storage.ei.induction_matrix.core[matrix_id].stats = stats

end


function model.is_core(pos, surface)
    -- Used when a rebuild starts from tiles/components and does not already know which
    -- matrix core owns the connected footprint.

    local entities = surface.find_entities({
        {pos.x-0.25, pos.y-0.25},
        {pos.x+0.25, pos.y+0.25}
    })

    for _, entity in ipairs(entities) do
        if model.core[entity.name] then
            return entity.unit_number
        end
    end

    return nil

end


function model.mark_dirty(matrix_id)
    -- Dirty matrices are recomputed later by update_dirty() so handlers can stay small
    -- and multiple same-tick edits collapse into one rebuild.

    model.check_global_init()

    if not storage.ei.induction_matrix.core[matrix_id] then
        return
    end

    storage.ei.induction_matrix.core[matrix_id].dirty = true
    ei_runtime_scheduler.queue_push_unique(storage.ei.induction_matrix.dirty_core_queue, matrix_id, matrix_id)
    ei_runtime_scheduler.bump_counter("induction-matrix", "dirty_marked", 1)

end


function model.set_core_state(matrix_id, state)
    -- `state` is the assembled/valid flag for the current connected footprint.

    if not storage.ei.induction_matrix.core[matrix_id] then
        return
    end

    storage.ei.induction_matrix.core[matrix_id].state = state

end


function model.calculate_stats(coils, solenoids, converters)
    -- Stat calculation is intentionally separate from flood-fill membership:
    -- flood-fill answers "what belongs to this matrix?"
    -- this function answers "what does that membership imply?"
    --
    -- Capacity comes from coils, then receives buffs/penalties from nearby and chained
    -- solenoids. Converter count determines IO tier and is later exponentiated to MW.

    local capacity = 0
    local connected_solenoids = 0
    local coil_number = 0
    local converter_number = 0

    -- calculate capacitity for each coil
    for _,coil in pairs(coils) do

        local single_capacity = model.coils[coil.name]
        local solenoids_around = 0

        coil_number = coil_number + 1


        -- count solenoids in 3x3 area around coil
        local coil_solenoids = coil.surface.find_entities({
            {coil.position.x-1, coil.position.y-1},
            {coil.position.x+1, coil.position.y+1}
        })

        for _, solenoid in pairs(coil_solenoids) do

            if model.solenoids[solenoid.name] then
                solenoids_around = solenoids_around + model.solenoids[solenoid.name]
            end

        end

        -- add the buff through solenoids around coil
        if solenoids_around > 0 then
            single_capacity = single_capacity * (2 - 0.057*(solenoids_around-1))
        end

        capacity = capacity + single_capacity

    end

    -- add the buff for solenoids in series
    for _, solenoid in pairs(solenoids) do

        -- how many solenoids are connected to this one
        local in_series = model.get_connected_solenoid_count(solenoid)

        connected_solenoids = connected_solenoids + in_series

    end

    -- count the converter value
    for _, converter in pairs(converters) do

        local converter_value = model.converters[converter.name]

        converter_number = converter_number + converter_value

    end

    -- buff capacity
    local coil_avg = capacity / coil_number
    capacity = capacity + connected_solenoids * model.buff_function(connected_solenoids) * coil_avg

    -- calc max IO
    if converter_number > 16 then
        converter_number = 16
    end

    if coil_number == 0 then
        capacity = 0
    end

    return {
        ["capacity"] = capacity,
        ["max_IO"] = converter_number,
    }

end


function model.get_connected_solenoid_count(entity)
    -- Solenoid chain bonuses only care about direct orthogonal neighbors. This helper
    -- reduces the immediate local shape around one solenoid into a small weighting value.
    local north_entities = entity.surface.find_entities_filtered({
        position = {entity.position.x, entity.position.y-1},
    })

    local south_entities = entity.surface.find_entities_filtered({
        position = {entity.position.x, entity.position.y+1},
    })

    local east_entities = entity.surface.find_entities_filtered({
        position = {entity.position.x+1, entity.position.y},
    })

    local west_entities = entity.surface.find_entities_filtered({
        position = {entity.position.x-1, entity.position.y},
    })

    local north_entity = nil
    local south_entity = nil
    local east_entity = nil
    local west_entity = nil

    -- make sure theses entities are solenoids
    for _, entity in ipairs(north_entities) do
        if model.solenoids[entity.name] then
           north_entity = entity 
        end
    end

    for _, entity in ipairs(south_entities) do
        if model.solenoids[entity.name] then
           south_entity = entity 
        end
    end

    for _, entity in ipairs(east_entities) do
        if model.solenoids[entity.name] then
           east_entity = entity 
        end
    end

    for _, entity in ipairs(west_entities) do
        if model.solenoids[entity.name] then
           west_entity = entity 
        end
    end

    if north_entity == nil and south_entity == nil then

        if east_entity == nil and west_entity == nil then
            return 0
        end

        return 1

    end

    if east_entity == nil and west_entity == nil then

        if north_entity == nil and south_entity == nil then
            return 0
        end

        return 1

    end

    if east_entity == nil and north_entity == nil then

        if south_entity ~= nil and west_entity ~= nil then
            return 1.2
        end

        return 1

    end

    if east_entity == nil and south_entity == nil then

        if north_entity ~= nil and west_entity ~= nil then
            return 1.2
        end

        return 1

    end

    if west_entity == nil and north_entity == nil then

        if south_entity ~= nil and east_entity ~= nil then
            return 1.2
        end

        return 1

    end

    if west_entity == nil and south_entity == nil then

        if north_entity ~= nil and east_entity ~= nil then
            return 1.2
        end

        return 1

    end

    return 0

end


function model.buff_function(n)
    -- Empirical piecewise curve used by the original matrix design:
    -- rising benefit through moderate chain counts, then tapering off.

    if n <= 48 then
        return 1/24 * n
    end

    if n <= 96 then
        return 2 - 1/48 * (n-48)
    end

    return 1
end


function model.get_max_connected_tiles(force)
    -- Matrix footprint limits are gated by researched technology tier.

    if not force then
        return 8*8
    end

    if force.technologies["ei-superior-induction-matrix"].researched then
        return 12*12
    end

    if force.technologies["ei-advanced-induction-matrix"].researched then
        return 10*10
    end

    if force.technologies["ei-induction-matrix"].researched then
        return 8*8
    end

    return 8*8

end


--UPDATE RELATED
-----------------------------------------------------------------------------------------------------

function model.update_core(matrix_id, event)
    -- A dirty matrix update always starts from the current core entity and re-runs the
    -- whole rebuild/stat/apply pipeline. This is more brute-force than incremental edits,
    -- but it is predictable and keeps the invariants simple.

    local core = model.get_core_entity(matrix_id)

    if core == nil then
        return
    end

    if core.valid == false then
        return
    end

    -- first redo the floodfill to be sure that all entities are picked up
    local dict = model.check_connected_tiles(core.position, core.surface, false, matrix_id, core.force, event)

    local coils = storage.ei.induction_matrix.core[matrix_id].coils
    local solenoids = storage.ei.induction_matrix.core[matrix_id].solenoids
    local converters = storage.ei.induction_matrix.core[matrix_id].converters

    if dict == false then
        return
    end

    local tiles = dict["tiles"]
    local state = dict["state"]
    local matrix_id = dict["matrix_id"]

    -- calc new stats and apply them if needed
    local new_stats = model.calculate_stats(coils, solenoids, converters)

    model.show_stats(core.surface, core.position, new_stats, event)
    model.set_core_state(matrix_id, state)

    local old_stats = storage.ei.induction_matrix.core[matrix_id].stats
    local new_id = model.apply_stats(matrix_id, old_stats, new_stats, core, state)

    storage.ei.induction_matrix.core[new_id].dirty = false
    mark_wire_slots_dirty()
    ei_runtime_scheduler.bump_counter("induction-matrix", "dirty_processed", 1)

end


function model.update_dirty(event)
    -- Dirty matrices are processed in one pass, then any retired core ids from swaps or
    -- destruction are cleaned out at the end of the pass.
    model.check_global_init()

    if not storage.ei.induction_matrix.core then
        return
    end

    backfill_dirty_core_queue()

    while true do
        local matrix_id = ei_runtime_scheduler.queue_pop(storage.ei.induction_matrix.dirty_core_queue)
        if matrix_id == nil then
            break
        end

        local matrix_data = storage.ei.induction_matrix.core[matrix_id]
        if matrix_data and matrix_data.dirty then
            model.update_core(matrix_id, event)
        end
    end

    model.remove_old_cores()

end


function model.update_wire_outputs(event)
    -- Wire output refresh is decoupled from dirty recomputation so the visible charge can
    -- continue changing when the footprint itself is stable.
    --
    -- Matrix charge can drift every tick, but rewriting every proxy every tick is costly.
    -- We only touch a matrix when:
    -- - its once-per-second slot comes up, and
    -- - the hidden proxy actually has a circuit wire attached.

    model.check_global_init()

    local tick = event and event.tick
    if not tick then
        return
    end

    local slots = ensure_wire_update_slots()
    local active_slot = slots[tick % MATRIX_WIRE_UPDATE_INTERVAL]
    if not active_slot then
        return
    end

    for matrix_id in pairs(active_slot) do
        local matrix_data = storage.ei.induction_matrix.core[matrix_id]
        if type(matrix_id) == "number" and matrix_data then
            model.update_wire_proxy_signals(matrix_id)
        else
            active_slot[matrix_id] = nil
        end
    end

end


--RENDERING
-----------------------------------------------------------------------------------------------------

function model.queue_tile_render(surface, progress_list, color, event)
    -- The animated tile render is a queued effect rather than immediate rendering so the
    -- matrix flood-fill can be visualized as a sweep across the footprint.

    model.check_global_init()

    if #progress_list == 0 or not event then
        return
    end


    local speed = 8
    local tick = event.tick
    local Dt = #progress_list/speed + 10

    -- loop over all tiles in the progress list and add them to the render que
    for i, pos in ipairs(progress_list) do

        -- add tile to render queue
        schedule_render_entry({
            tick = tick + math.floor(i/speed),
            surface = surface,
            position = pos,
            color = color,
            rtype = "tile-box",
        })

        -- also add the "reflection"
        schedule_render_entry({
            tick = tick + Dt + math.floor((#progress_list - i)/speed),
            surface = surface,
            position = pos,
            color = color,
            rtype = "tile-box",
        })

    end

end


function model.update_render_queue(tick)
    -- Rendering queue entries are transient instructions. Once their tick is reached they
    -- are rendered or cleaned up and then removed from the queue.

    model.check_global_init()

    local due_entries = ei_runtime_scheduler.delayed_take_due(storage.ei.induction_matrix.render_buckets, tick)
    for _, v in ipairs(due_entries) do
        if v.rtype == "tile-box" then
            model.render_tile_box(v)
        elseif v.rtype == "stat-text" then
            local stat_index = storage.ei.induction_matrix.stat_text_index
            local active = stat_index and v.stat_key and stat_index[v.stat_key] or nil
            if active and active.token == v.token then
                model.remove_stat_text(active)
                stat_index[v.stat_key] = nil
            elseif v.capacity_text or v.IO_text then
                model.remove_stat_text(v)
            end
        end
    end

    if next(storage.ei.induction_matrix.render_queue) == nil then
        return
    end

    -- Save compatibility: old saves may still have a flat render queue. It drains here,
    -- while new entries use exact tick buckets above.
    for i = #storage.ei.induction_matrix.render_queue, 1, -1 do
        local v = storage.ei.induction_matrix.render_queue[i]

        if v.tick <= tick then

            if v.rtype == "tile-box" then
                model.render_tile_box(v)
            end

            if v.rtype == "stat-text" then
                model.remove_stat_text(v)
            end

            table.remove(storage.ei.induction_matrix.render_queue, i)

        end

    end

end


function model.render_tile_box(data)
    -- One queued tile-box entry becomes one short-lived filled rectangle on the ground.

    local surface = data.surface
    local pos = data.position
    local color = data.color

    local box = {
        left_top = {pos.x, pos.y},
        right_bottom = {pos.x+1, pos.y+1},
    }

    rendering.draw_rectangle{
        color = color,
        filled = true,
        left_top = box.left_top,
        right_bottom = box.right_bottom,
        surface = surface,
        time_to_live = 20,
        draw_on_ground = true,
    }

end


function model.show_stats(surface, pos, stats, event)
    -- Matrix stat popups are indexed by position so repeated rebuilds can
    -- replace/refresh the existing texts without scanning every pending render effect.

    local stat_index = storage.ei.induction_matrix.stat_text_index
    local stat_key = get_stat_text_key(surface, pos)
    local existing = stat_index[stat_key]
    local token = (existing and existing.token or 0) + 1

    if existing then
        model.remove_stat_text(existing)
    end

    local capacity_text = rendering.draw_text{
        text = "Capacity: " .. math.floor(stats.capacity) .. "MJ",
        surface = surface,
        target = {pos.x, pos.y - 1.5},
        color = {r=0, g=1, b=0},
        scale = 0.75,
        font = "default-game",
        alignment = "center",
        scale_with_zoom = false,
    }

    local IO_text = rendering.draw_text{
        text = "Max IO: " .. math.floor(2^stats.max_IO) .. "MW",
        surface = surface,
        target = {pos.x, pos.y - 2.5},
        color = {r=1, g=1, b=1},
        scale = 0.75,
        font = "default-game",
        alignment = "center",
        scale_with_zoom = false,
    }

    local entry = {
        tick = event.tick + 120,
        capacity_text = capacity_text,
        IO_text = IO_text,
        pos = pos,
        surface = surface,
        stat_key = stat_key,
        token = token,
        rtype = "stat-text",
    }

    stat_index[stat_key] = entry
    schedule_render_entry(entry)

end


function model.remove_stat_text(data)
    -- Cleanup companion for queued stat-text render entries.

    if data.capacity_text then
        pcall(function()
            data.capacity_text.destroy()
        end)
    end

    if data.IO_text then
        pcall(function()
            data.IO_text.destroy()
        end)
    end

end

--GETTERS
-----------------------------------------------------------------------------------------------------

function model.get_matrix_capacity(matrix_id)
    -- Public getter used by GUI and wire outputs. Returns MJ.

    model.check_global_init()

    if not storage.ei.induction_matrix.core[matrix_id] or not storage.ei.induction_matrix.core[matrix_id].stats or not storage.ei.induction_matrix.core[matrix_id].stats.capacity then
        return 0
    end

    -- in MJ
    return storage.ei.induction_matrix.core[matrix_id].stats.capacity

end


function model.get_matrix_max_IO(matrix_id)
    -- Stored stats keep the converter tier exponent; this getter exposes the player-facing
    -- MW value instead.

    model.check_global_init()

    if not storage.ei.induction_matrix.core[matrix_id] or not storage.ei.induction_matrix.core[matrix_id].stats or not storage.ei.induction_matrix.core[matrix_id].stats.max_IO then
        return 0
    end

    -- in MW
    return 2^storage.ei.induction_matrix.core[matrix_id].stats.max_IO

end

function model.get_matrix_current_stored_power(matrix_id)
    -- The actual stored energy lives on the core entity, not in storage. Returns MJ.

    model.check_global_init()

    if not storage.ei.induction_matrix.core[matrix_id] then
        return 0
    end

    local core = model.get_core_entity(matrix_id)

    if core == nil then
        return
    end

    -- in MJ
    return core.energy/1000000

end


function model.force_visual_update(matrix_id, event)
    -- GUI-triggered "reanalyze" path: rerun the flood-fill with render enabled and then
    -- mark the matrix dirty so the real update pass commits any derived changes.

    model.check_global_init()

    if not storage.ei.induction_matrix.core[matrix_id] then
        return
    end

    local core = model.get_core_entity(matrix_id)

    if core == nil then
        return
    end

    local dict = model.check_connected_tiles(core.position, core.surface, true, matrix_id, core.force, event)

    if dict == false then
        return
    end

    model.set_core_state(dict.matrix_id, dict.state)

    model.mark_dirty(dict.matrix_id)

end


function model.get_core_entity(matrix_id)
    -- Logical matrices should have exactly one live core entity. This helper is the
    -- canonical place where that assumption is enforced and stale entity refs are pruned.

    model.check_global_init()

    local matrix = storage.ei.induction_matrix.core[matrix_id]
    if not matrix or not matrix.core then
        return nil
    end

    local core = nil

    for unit, entity in pairs(matrix.core) do

        if model.entity_check(entity) == false then
            matrix.core[unit] = nil
            goto continue
        end

        if core == nil then
            core = entity
        else
            game.print("ERROR: multiple cores found for matrix_id: " .. matrix_id)
            return nil
        end

        ::continue::
    end

    return core

end


function model.get_core_tier(core)
    -- Core tier is encoded in the prototype suffix and is used as the stored IO exponent.

    if model.entity_check(core) == false then
        return 0
    end

    return tonumber(string.match(core.name, "(%d+)$")) or 0

end


function model.reset_runtime_storage()
    -- Manual rescans rebuild the logical matrix tables from the live world, so any stale
    -- serialized membership/proxy bookkeeping is discarded up front.

    model.check_global_init()

    storage.ei.induction_matrix.render_queue = {}
    storage.ei.induction_matrix.render_buckets = {}
    storage.ei.induction_matrix.stat_text_index = {}
    storage.ei.induction_matrix.dirty_core_queue = ei_runtime_scheduler.ensure_queue(nil)
    storage.ei.induction_matrix.dirty_queue_backfilled = true
    storage.ei.induction_matrix.wire_update_slots = {}
    storage.ei.induction_matrix.wire_slots_rebuild_needed = true
    storage.ei.induction_matrix.core = {
        stats = {
            max_IO = 0,
            capacity = 0
        }
    }
    storage.ei.induction_matrix.to_remove = {}
    storage.ei.induction_matrix.proxy = {}

end


function model.rebuild_runtime_state(reason)
    -- Rebuild every logical matrix from live entities on every surface.
    -- Existing proxy entities are reused when possible so circuit wiring survives the
    -- repair pass, while orphaned proxies are removed afterward.

    model.check_global_init()
    model.reset_runtime_storage()

    local core_names = model.get_sorted_lookup_names(model.core)
    local rebuilt_matrices = 0
    local removed_orphan_proxies = 0

    for _, surface in pairs(game.surfaces) do
        local cores = surface.find_entities_filtered{
            name = core_names,
        }

        for _, core in ipairs(cores) do
            if model.entity_check(core) == false then
                goto continue
            end

            local dict = model.check_connected_tiles(core.position, core.surface, false, core.unit_number, core.force)
            if dict == false then
                goto continue
            end

            local matrix_id = dict.matrix_id
            local live_core = model.get_core_entity(matrix_id)
            local matrix = storage.ei.induction_matrix.core[matrix_id]

            if model.entity_check(live_core) == false or not matrix then
                goto continue
            end

            local proxy = model.find_existing_wire_proxy(live_core)
            if model.entity_check(proxy) then
                matrix.wire_proxy = proxy
            end
            matrix.signal_cache = nil

            model.set_core_state(matrix_id, dict.state)

            local old_stats = matrix.stats or {}
            if old_stats.max_IO == nil then
                old_stats.max_IO = model.get_core_tier(live_core)
            end

            local new_stats = model.calculate_stats(matrix.coils, matrix.solenoids, matrix.converters)
            local new_id = model.apply_stats(matrix_id, old_stats, new_stats, live_core, dict.state)

            if storage.ei.induction_matrix.core[new_id] then
                storage.ei.induction_matrix.core[new_id].dirty = false
                storage.ei.induction_matrix.core[new_id].signal_cache = nil
                model.ensure_wire_proxy(new_id)
                model.update_wire_proxy_signals(new_id)
                rebuilt_matrices = rebuilt_matrices + 1
            end

            ::continue::
        end
    end

    model.remove_old_cores()

    for _, surface in pairs(game.surfaces) do
        local proxies = surface.find_entities_filtered{
            name = MATRIX_WIRE_PROXY_NAME,
        }

        for _, proxy in ipairs(proxies) do
            if model.entity_check(proxy)
            and not storage.ei.induction_matrix.proxy[proxy.unit_number] then
                proxy.destroy({raise_destroy=false})
                removed_orphan_proxies = removed_orphan_proxies + 1
            end
        end
    end

    return {
        reason = reason,
        rebuilt_matrices = rebuilt_matrices,
        removed_orphan_proxies = removed_orphan_proxies,
    }

end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(event)
    -- Entity build path:
    -- - reject irrelevant or illegally placed entities
    -- - if a core was placed, rebuild from that core and ensure its proxy exists
    -- - if a non-core component was placed, discover the owning matrix and mark it dirty
    model.check_global_init()

    local entity = event.entity
    if model.entity_check(entity) == false then
        return
    end

    if not model.only_on_tile[entity.name] then
        return
    end

    if model.check_tile(entity) == false then
        return
    end

    if model.core[entity.name] then

        local dict = model.check_connected_tiles(entity.position, entity.surface, true, entity.unit_number, entity.force,event)

        model.set_core_state(dict.matrix_id, dict.state)

        model.mark_dirty(dict.matrix_id)

        if model.entity_check(entity) then
            model.ensure_wire_proxy(entity.unit_number)
        end

    end

    if model.but_cores[entity.name] then

        local dict = model.check_connected_tiles(entity.position, entity.surface, false, nil, entity.force,event)

        model.set_core_state(dict.matrix_id, dict.state)

        model.mark_dirty(dict.matrix_id)

    end

end


function model.on_destroyed_entity(event)
    -- Entity destroy path has to handle three different cases:
    -- 1. the hidden proxy was removed directly
    -- 2. a core was removed
    -- 3. a non-core component was removed from a valid matrix footprint
    --
    -- Case 1 is special because the proxy is the selectable entity players interact with,
    -- so mining it needs to tear down the real matrix core as well.
    model.check_global_init()

    local entity = event.entity
    if model.entity_check(entity) == false then
        return
    end

    if model.proxy[entity.name] then
        local matrix_id = storage.ei.induction_matrix.proxy[entity.unit_number]
        storage.ei.induction_matrix.proxy[entity.unit_number] = nil

        if not matrix_id or not storage.ei.induction_matrix.core[matrix_id] then
            return
        end

        storage.ei.induction_matrix.core[matrix_id].wire_proxy = nil
        storage.ei.induction_matrix.core[matrix_id].signal_cache = nil

        local core = model.get_core_entity(matrix_id)
        if model.entity_check(core) then
            core.destroy({raise_destroy=false})
        end

        storage.ei.induction_matrix.core[matrix_id] = nil
        return
    end

    if not model.only_on_tile[entity.name] then
        return
    end

    if model.core[entity.name] then
        model.destroy_wire_proxy(entity.unit_number)

        -- remove core from storage
        if storage.ei.induction_matrix.core[entity.unit_number] then
            storage.ei.induction_matrix.core[entity.unit_number] = nil
        end

    end

    if model.check_tile(entity) == false then
        return
    end

    if model.but_cores[entity.name] then

        local dict = model.check_connected_tiles(entity.position, entity.surface, false, nil, entity.force,event)

        model.set_core_state(dict.matrix_id, dict.state)

        model.mark_dirty(dict.matrix_id)

    end

end


function model.on_built_tile(event)
    -- Tile placement can complete or expand a matrix under already-placed components, so
    -- every placed matrix tile probes the connected footprint and marks discovered matrices dirty.
    model.check_global_init()

    local surface = game.surfaces[event.surface_index]
    local tiles = event.tiles
    local tile = event.tile
    local source = event.robot or game.get_player(event.player_index)

    --if tile.name ~= "ei-induction-matrix-tile" then
    --    return
    --end

    for _, v in ipairs(tiles) do

        local pos = v.position

        surface.destroy_decoratives{
            area = {{pos.x-1, pos.y-1}, {pos.x+1, pos.y+1}},
        }

    end

    if tile.name ~= "ei-induction-matrix-tile" then
        return
    end

    for _, v in ipairs(tiles) do

        local pos = v.position

        pos = {x = pos.x + 0.25, y = pos.y + 0.25}

        local dict = model.check_connected_tiles(pos, surface, false, nil, source.force,event)

        if dict == false then
            goto continue
        end

        model.set_core_state(dict.matrix_id, dict.state)

        model.mark_dirty(dict.matrix_id)

        ::continue::

    end

end


function model.on_destroyed_tile(event)
    -- Tile removal is the most destructive path because it can invalidate the ground under
    -- 2x2 cores/converters. The handler therefore:
    -- - spills and destroys unsupported cores/converters
    -- - tears down proxies for removed cores
    -- - rechecks adjacent surviving matrix fragments
    model.check_global_init()

    local surface = game.surfaces[event.surface_index]
    local tiles = event.tiles
    local source = event.robot or game.get_player(event.player_index)

    for _, v in ipairs(tiles) do

        if v.old_tile.name ~= "ei-induction-matrix-tile" then
            goto continue
        end

        local pos = v.position

        -- check if there is a core on the tile
        -- if so spill it and remove it from storage

        local core = surface.find_entities_filtered{
            position = pos,
        }

        for _, entity in ipairs(core) do

            if model.core[entity.name] then

                -- remove core from storage
                if storage.ei.induction_matrix.core[entity.unit_number] then
                    table.insert(storage.ei.induction_matrix.to_remove, entity.unit_number)
                end

                model.destroy_wire_proxy(entity.unit_number)

                -- spill core
                entity.surface.spill_item_stack{position=entity.position, stack={name = "ei-induction-matrix-core", count = 1}, enable_looted=true}

                -- destroy core
                entity.destroy()

            end

        end

        -- also check all tiles around if a core is on them
        -- and if so if it is connected to this tile (its 2x2)

        core = surface.find_entities_filtered{
            area = {{pos.x-1.5, pos.y-1.5}, {pos.x+1.5, pos.y+1.5}},
        }

        for _, entity in ipairs(core) do

            if model.core[entity.name] then

                -- get the 4 positions of tiles under the core
                -- if one of them matches the destroyed tile then
                -- destroy the core and spill it

                local core_pos = entity.position
                -- north tile
                local north_pos = {x = core_pos.x, y = core_pos.y - 1}
                -- north west tile
                local north_west_pos = {x = core_pos.x - 1, y = core_pos.y - 1}
                -- west tile
                local west_pos = {x = core_pos.x - 1, y = core_pos.y}
                -- core tile
                local core_tile_pos = {x = core_pos.x, y = core_pos.y}

                if (north_pos.x == pos.x and north_pos.y == pos.y) or (north_west_pos.x == pos.x and north_west_pos.y == pos.y) or (west_pos.x == pos.x and west_pos.y == pos.y) or (core_tile_pos.x == pos.x and core_tile_pos.y == pos.y) then
                
                    -- remove core from storage
                    if storage.ei.induction_matrix.core[entity.unit_number] then
                        table.insert(storage.ei.induction_matrix.to_remove, entity.unit_number)
                    end

                    model.destroy_wire_proxy(entity.unit_number)

                    -- spill core
                    entity.surface.spill_item_stack{position=entity.position, stack={name = "ei-induction-matrix-core", count = 1}, enable_looted=true}

                    -- destroy core
                    entity.destroy()
                    
                end

            end

        end

        -- do the same check for 2x2 converters

        local converter = surface.find_entities_filtered{
            area = {{pos.x-1.5, pos.y-1.5}, {pos.x+1.5, pos.y+1.5}},
        }

        for _, entity in ipairs(converter) do

            if model.converters[entity.name] then

                -- get the 4 positions of tiles under the core
                -- if one of them matches the destroyed tile then
                -- destroy the core and spill it

                local converter_pos = entity.position
                -- north tile
                local north_pos = {x = converter_pos.x, y = converter_pos.y - 1}
                -- north west tile
                local north_west_pos = {x = converter_pos.x - 1, y = converter_pos.y - 1}
                -- west tile
                local west_pos = {x = converter_pos.x - 1, y = converter_pos.y}
                -- core tile
                local converter_tile_pos = {x = converter_pos.x, y = converter_pos.y}

                if (north_pos.x == pos.x and north_pos.y == pos.y) or (north_west_pos.x == pos.x and north_west_pos.y == pos.y) or (west_pos.x == pos.x and west_pos.y == pos.y) or (converter_tile_pos.x == pos.x and converter_tile_pos.y == pos.y) then
                
                    -- spill item
                    entity.surface.spill_item_stack{position=entity.position, stack={name = entity.name, count = 1}, enable_looted=true}

                    -- destroy core
                    entity.destroy()
                    
                end

            end

        end


        -- get north, south, east, west induction matrix tiles
        -- and do the check for them
        local adjacent_tiles = model.get_adjacent_tiles(pos, surface)

        for _, y in ipairs(adjacent_tiles) do

            if y.name == "ei-induction-matrix-tile" then

                local shifted_pos = {x = y.position.x + 0.25, y = y.position.y + 0.25}
                local dict = model.check_connected_tiles(shifted_pos, surface, false, nil, source.force,event)

                if dict == false then
                    goto contin
                end

                model.set_core_state(dict.matrix_id, dict.state)

                model.mark_dirty(dict.matrix_id)

            end

            ::contin::

        end

        ::continue::
    end

end


function model.update(event)
    -- Per-tick local update for the matrix system:
    -- - process queued renders
    -- - recompute dirty matrices
    -- - refresh circuit outputs
    -- - refresh open GUIs at a lower cadence
    --
    -- This local update is called every tick from top-level control.lua, unlike the broader
    -- staggered scheduler used by heavier global subsystems there.

    local tick = event.tick

    model.update_render_queue(tick)
    model.update_dirty(event)
    model.update_wire_outputs(event)
    if tick % 15 == 0 then
        model.update_player_guis()
    end

end


--GUI HANDLERS
------------------------------------------------------------------------------------------------------

function model.get_gui(player)
    return player.gui.screen["ei-induction-matrix-console"]
end

---Opens the induction matrix core GUI.
---@param player LuaPlayer Player
function model.open_gui(player)
    -- The GUI may be opened from either the visible core or the hidden proxy, so it always
    -- resolves back to matrix_id first and then anchors the camera against the real core.
    if model.get_gui(player) then
        model.update_gui(player)
        return
    end

    local entity = player.opened_gui_type == defines.gui_type.entity and player.opened --[[@as LuaEntity]]
    local matrix_id = model.get_matrix_id(entity)
    if not matrix_id then return end

    local core = model.get_core_entity(matrix_id)
    if model.entity_check(core) == false then
        return
    end

    local root = player.gui.screen.add{
        type = "frame",
        name = "ei-induction-matrix-console",
        direction = "vertical",
        tags = {
            matrix_id = matrix_id
        }
    } --[[@as LuaGuiElement]]
    root.force_auto_center()
    root.style.width = 330

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}  --[[@as LuaGuiElement]]
        titlebar.drag_target = root
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.induction-matrix-gui-title"},
            style = "frame_title",
            ignored_by_interaction = true
        }
        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_draggable_spacer",
            ignored_by_interaction = true
        }
        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-induction-matrix-console",
                action = "goto-informatron",
                page = "induction_matrix"
            }
        }
        titlebar.add{
            type = "sprite-button",
            style = "close_button",
            sprite = "utility/close",
            hovered_sprite = "utility/close_black",
            clicked_sprite = "utility/close_black",
            tags = {
                parent_gui = "ei-induction-matrix-console",
                action = "close-gui"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame"
    } --[[@as LuaGuiElement]]

    main_container.add{ -- Console subheader
        type = "frame",
        style = "ei_subheader_frame"
    }.add{
        type = "label",
        caption = {"exotic-industries.induction-matrix-gui-console-title"},
        style = "subheader_caption_label"
    }

    local console_flow = main_container.add{
        type = "flow",
        name = "console-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    } --[[@as LuaGuiElement]]

    local camera_frame = console_flow.add{
        type = "frame",
        name = "camera-frame",
        style = "ei_camera_frame"
    } --[[@as LuaGuiElement]]

    camera_frame.add{
        type = "camera",
        name = "camera",
        position = core.position,
        surface_index = core.surface.index,
        style = "ei_camera"
    }



    local max_et = console_flow.add{type = "flow", name = "max-et-flow", direction = "horizontal"} --[[@as LuaGuiElement]]
    max_et.add{
        type = "label",
        caption = {"exotic-industries.induction-matrix-gui-max-energy-transfer"},
        tooltip = {"exotic-industries.induction-matrix-gui-max-energy-transfer-tooltip"}
    }
    max_et.add{type = "empty-widget", style = "ei_horizontal_pusher"}
    max_et.add{
        type = "label",
        name = "max-et-value"
    }
    local capacity = console_flow.add{type = "flow", name = "capacity-flow", direction = "vertical"} --[[@as LuaGuiElement]]
    capacity.add{type = "line"}
    capacity.add{
        type = "label",
        caption = {"exotic-industries.induction-matrix-gui-capacity"},
        tooltip = {"exotic-industries.induction-matrix-gui-capacity-tooltip"}
    }
    local power_bar = capacity.add{
        type = "progressbar",
        name = "stored-power-value",
        style = "ei_status_progressbar",
        tooltip = {"exotic-industries.induction-matrix-gui-capacity-tooltip"}
    }
    power_bar.style.horizontal_align = "right"

    console_flow.add{
        type = "empty-widget",
        style = "ei_vertical_pusher"
    }

    local button_flow = console_flow.add{type = "flow"} --[[@as LuaGuiElement]]
    button_flow.style.horizontal_align = "right"
    button_flow.style.horizontally_stretchable = true
    button_flow.add{
        type = "button",
        caption = {"exotic-industries.induction-matrix-gui-reanalyze-caption"},
        tooltip = {"exotic-industries.induction-matrix-gui-reanalyze-tooltip"},
        tags = {
            parent_gui = "ei-induction-matrix-console",
            action = "reanalyze-matrix"
        }
    }

    player.opened = root

    -- Verify that root is still valid since another mod may have destroyed it
    if root.valid then model.update_gui(player) end
end


function model.update_player_guis()
    -- GUI refresh is intentionally separate from the actual data recomputation. By running
    -- it on a lower cadence the matrix can keep its state current every tick without
    -- rebuilding GUI captions/bars for every connected player every tick.

    for _, player in pairs(game.connected_players) do
        if player.gui.screen["ei-induction-matrix-console"] then
            if not player.opened or not player.opened.valid then
                model.close_gui(player)
                goto continue
            end

            model.update_gui(player)
        end

        ::continue::
    end

end

---Updates the induction matrix GUI.
---@param player LuaPlayer Player
function model.update_gui(player)
    -- GUI values are derived from getters rather than cached from the open event so the
    -- window always reflects the latest matrix id/state, even across core swaps.
    local root = model.get_gui(player)
    if not root then return end

    local matrix_id = root.tags.matrix_id

    local info = root["main-container"]["console-flow"] --[[@as LuaGuiElement]]

    local max_et = info["max-et-flow"]["max-et-value"]
    local stored_power = info["capacity-flow"]["stored-power-value"]

    local max_power = model.get_matrix_capacity(matrix_id)
    local current_power = model.get_matrix_current_stored_power(matrix_id)
    local rounded_max_power = model.to_wire_signal_value(max_power)
    local rounded_current_power = model.to_wire_signal_value(current_power)

    max_et.caption = string.format("[font=default-bold]%.0f MW[/font]", model.get_matrix_max_IO(matrix_id))

    stored_power.caption = string.format("[font=default-bold]%d/%d MJ[/font]", rounded_current_power, rounded_max_power)
    if max_power == 0 then 
        stored_power.value = 0
    else
        stored_power.value = current_power/max_power 
    end

end

function model.close_gui(player)
    -- Close is idempotent so callers can safely use it from stale-opened checks.
    local root = player.gui.screen["ei-induction-matrix-console"]
    if root then root.destroy() end
end

---Handles buttons clicks for the induction matrix GUI.
---@param event EventData.on_gui_click Event data
function model.on_gui_click(event)
    -- Buttons are tag-driven:
    -- - close-gui: destroy the local window
    -- - goto-informatron: open the related documentation page
    -- - reanalyze-matrix: rerun the visual flood-fill + stat refresh from the current matrix_id
    local action = event.element.tags.action

    if action == "close-gui" then
        model.close_gui(game.get_player(event.player_index) --[[@as LuaPlayer]])
    elseif action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = event.element.tags.page,
          })
    elseif action == "reanalyze-matrix" then
        local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
        local root = player.gui.screen["ei-induction-matrix-console"] --[[@as LuaGuiElement]]

        model.force_visual_update(root.tags.matrix_id, event)
        model.update_gui(player)
    end
end

function model.get_runtime_status()
    model.check_global_init()

    local matrix_state = storage.ei.induction_matrix
    local core_count = 0
    local dirty_flag_count = 0
    for matrix_id, matrix_data in pairs(matrix_state.core or {}) do
        if type(matrix_id) == "number" then
            core_count = core_count + 1
            if matrix_data and matrix_data.dirty then
                dirty_flag_count = dirty_flag_count + 1
            end
        end
    end

    local wire_slot_entries = 0
    for _, slot in pairs(ensure_wire_update_slots()) do
        wire_slot_entries = wire_slot_entries + ei_runtime_scheduler.table_count(slot)
    end

    local status = {
        core_count = core_count,
        dirty_flag_count = dirty_flag_count,
        dirty_queue = ei_runtime_scheduler.queue_item_count(matrix_state.dirty_core_queue),
        dirty_queue_audit = ei_runtime_scheduler.audit_queue(matrix_state.dirty_core_queue),
        render_bucket_count = ei_runtime_scheduler.delayed_bucket_count(matrix_state.render_buckets),
        render_item_count = ei_runtime_scheduler.delayed_item_count(matrix_state.render_buckets),
        legacy_render_queue_count = #(matrix_state.render_queue or {}),
        stat_text_count = ei_runtime_scheduler.table_count(matrix_state.stat_text_index),
        wire_slot_entries = wire_slot_entries,
        wire_slots_rebuild_needed = matrix_state.wire_slots_rebuild_needed == true,
        dirty_cores = dirty_flag_count,
        render_queue = #(matrix_state.render_queue or {}),
        render_buckets = ei_runtime_scheduler.delayed_bucket_count(matrix_state.render_buckets),
        render_bucket_items = ei_runtime_scheduler.delayed_item_count(matrix_state.render_buckets),
        stat_texts = ei_runtime_scheduler.table_count(matrix_state.stat_text_index),
    }

    ei_runtime_scheduler.set_module_status("induction-matrix", status)
    return status
end

commands.add_command("rescan_induction_matrix", "Rebuilds induction matrix runtime state, proxy mappings, and circuit output bookkeeping.", function(command)
    local player = command.player_index and game.get_player(command.player_index) or nil
    if player and not player.admin then
        return
    end

    ei_lib.crystal_echo("Induction matrix runtime rescan initiated.")

    local summary = model.rebuild_runtime_state("manual")

    ei_lib.crystal_echo(
        "Induction matrix runtime rescan complete. Rebuilt "
        .. summary.rebuilt_matrices
        .. " matrices and removed "
        .. summary.removed_orphan_proxies
        .. " orphan proxies."
    )
end)

return model
