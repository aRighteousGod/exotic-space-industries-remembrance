--==============================================================================
-- ESIR FILE MAP
-- owns: gleba auric inoculation vat runtime, basin claims, telemetry proxies, GUI, and placement guide rendering
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy, tile changes, GUI open/close/click, player cursor/position/surface/alt, object-destroyed, scheduled vat wakes, and UI due gate
-- storage_roots: storage.ei.auric_inoculation_vat
-- gui_ids: ei-auric-inoculation-vat-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, prototype schema changes
--==============================================================================

local model = {}
model.DEFAULT_DUE_ACTIVATION_LIMIT = 32
model.PLACEMENT_GUIDE_SKIPPED_CHUNK_RETRY_TICKS = 60

-- Runtime shape, in one breath:
-- A visible vat owns one contiguous wetland basin, drives a locked hidden-recipe
-- cycle, and wakes only when its current phase or UI session is due. The script
-- keeps the Gleba flavor in runtime state: vigor and contamination are biological
-- pressure, basin claims are tile ownership, cyst nodes are spawned world output,
-- and the hidden telemetry proxy is just a circuit-readable mirror of that state.
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")

local MODULE_NAME = "auric-inoculation-vat"
local GUI_NAME = "ei-auric-inoculation-vat-console"
local VAT_NAME = "ei-auric-inoculation-vat"
local IDLE_RECIPE_NAME = "ei-auric-vat-idle"
local TELEMETRY_PROXY_NAME = "ei-auric-inoculation-vat-circuit-interface"
local MARKER_FLUID_NAME = "ei-auric-inoculation-vat-marker"
local INFORMATRON_PAGE = "auric_inoculation_vat"
local CYST_NODE_NAME = "ei-auric-cyst-node"

local RUNTIME_VERSION = 1
model.BLOOM_MIN_VIGOR = 40
model.BLOOM_MAX_CONTAMINATION = 60
model.BASIN_RESTORE_SUCCESS_STREAK = 3
model.BASIN_RESTORE_TILE_PERCENT = 15
model.BASIN_RESTORE_MAX_CONTAMINATION = 20
model.BASIN_RESTORE_MIN_VIGOR = 70
model.CYST_SPAWN_EFFECT_TICKS = 42
local BASIN_RADIUS = 20
local BASIN_RADIUS_SQR = BASIN_RADIUS * BASIN_RADIUS
local MIN_BASIN_TILES = 24
local MAX_BASIN_TILES = 160
local UI_REFRESH_DELAY = 1
local MANUAL_FEEDBACK_TICKS = 180
local FERMENT_ENRICHMENT_WINDOW_TICKS = 15 * 60
local ACTIVE_SAMPLE_INTERVAL_TICKS = 30
local WAITING_SAMPLE_INTERVAL_TICKS = 120
local BLOCKED_DRAIN_SAMPLE_INTERVAL_TICKS = 60
local STATUS_UPDATE_INTERVAL_TICKS = 60
local STARVATION_PENALTY_INTERVAL_TICKS = 1800
local BLOCKED_DRAIN_PENALTY_INTERVAL_TICKS = 600
local PLACEMENT_GUIDE_CHUNK_SIZE = 32
local PLACEMENT_GUIDE_HORIZONTAL_CHUNKS = 4
local PLACEMENT_GUIDE_VERTICAL_CHUNKS = 2
local PLACEMENT_GUIDE_RADIUS = 0.10
local PLACEMENT_GUIDE_ALT_RADIUS = 0.20
local PLACEMENT_GUIDE_AVAILABLE_COLOR = {r = 1.00, g = 0.76, b = 0.18, a = 0.62}
local PLACEMENT_GUIDE_UNAVAILABLE_COLOR = {r = 1.00, g = 0.16, b = 0.10, a = 0.70}

local STATUS_GREEN = defines.entity_status_diode and defines.entity_status_diode.green or 1
local STATUS_YELLOW = defines.entity_status_diode and defines.entity_status_diode.yellow or 2
local STATUS_RED = defines.entity_status_diode and defines.entity_status_diode.red or 3

local ENTITY_STATUS = defines.entity_status or {}
local ENTITY_STATUS_WORKING = ENTITY_STATUS.working
local ENTITY_STATUS_FULL_OUTPUT = ENTITY_STATUS.full_output
local ENTITY_STATUS_NO_POWER = ENTITY_STATUS.no_power
local ENTITY_STATUS_LOW_POWER = ENTITY_STATUS.low_power
local ENTITY_STATUS_NOT_PLUGGED = ENTITY_STATUS.not_plugged_in_electric_network
local ENTITY_STATUS_DISABLED = ENTITY_STATUS.disabled_by_control_behavior
local ENTITY_STATUS_DISABLED_BY_SCRIPT = ENTITY_STATUS.disabled_by_script
local STARVED_STATUSES = {}
if ENTITY_STATUS.item_ingredient_shortage then STARVED_STATUSES[ENTITY_STATUS.item_ingredient_shortage] = true end
if ENTITY_STATUS.fluid_ingredient_shortage then STARVED_STATUSES[ENTITY_STATUS.fluid_ingredient_shortage] = true end
if ENTITY_STATUS.no_ingredients then STARVED_STATUSES[ENTITY_STATUS.no_ingredients] = true end
if ENTITY_STATUS.no_input_fluid then STARVED_STATUSES[ENTITY_STATUS.no_input_fluid] = true end
if ENTITY_STATUS.insufficient_input then STARVED_STATUSES[ENTITY_STATUS.insufficient_input] = true end

-- Phase order is the gameplay contract. Data stage provides one recipe per
-- banded input step plus fixed drain/bloom/rest recipes; runtime only decides
-- which recipe should be locked in and whether a completed marker advances the
-- vat or punishes the basin.
local PHASE_ORDER = {
    "seed",
    "flood",
    "ferment",
    "drain",
    "bloom",
    "rest",
}

local PHASE_INDEX = {}
for index, phase_key in ipairs(PHASE_ORDER) do
    PHASE_INDEX[phase_key] = index
end
PHASE_INDEX["ferment-enriched"] = PHASE_INDEX["ferment"]

local PHASE_DEFS = {
    ["seed"] = {
        duration_ticks = 10 * 60,
        active = true,
    },
    ["flood"] = {
        duration_ticks = 15 * 60,
        active = true,
    },
    ["ferment"] = {
        duration_ticks = 30 * 60,
        active = true,
    },
    ["ferment-enriched"] = {
        duration_ticks = 30 * 60,
        active = true,
    },
    ["drain"] = {
        duration_ticks = 15 * 60,
        active = true,
    },
    ["bloom"] = {
        duration_ticks = 45 * 60,
        active = true,
    },
    ["rest"] = {
        duration_ticks = 60 * 60,
        active = true,
    },
}

-- Bands convert a physical marsh claim into both recipe scale and biological
-- reward. Keeping these numbers beside runtime behavior makes the later drain
-- output, bloom yield, and telemetry code read from the same source of truth.
local BAND_DEFS = {
    {key = "b1", min = 24, max = 39, node_yield = 1, cyst_capacity = 3, dirty_water = 25, acidic_water = 5, enrich_bonus = 1, enrich_bioflux = 1},
    {key = "b2", min = 40, max = 55, node_yield = 1, cyst_capacity = 4, dirty_water = 35, acidic_water = 5, enrich_bonus = 1, enrich_bioflux = 1},
    {key = "b3", min = 56, max = 71, node_yield = 2, cyst_capacity = 6, dirty_water = 45, acidic_water = 10, enrich_bonus = 1, enrich_bioflux = 2},
    {key = "b4", min = 72, max = 87, node_yield = 2, cyst_capacity = 8, dirty_water = 55, acidic_water = 10, enrich_bonus = 1, enrich_bioflux = 2},
    {key = "b5", min = 88, max = 103, node_yield = 3, cyst_capacity = 10, dirty_water = 65, acidic_water = 15, enrich_bonus = 1, enrich_bioflux = 3},
    {key = "b6", min = 104, max = 127, node_yield = 4, cyst_capacity = 12, dirty_water = 80, acidic_water = 15, enrich_bonus = 1, enrich_bioflux = 3},
    {key = "b7", min = 128, max = 160, node_yield = 5, cyst_capacity = 14, dirty_water = 95, acidic_water = 20, enrich_bonus = 1, enrich_bioflux = 4},
}

local BAND_INDEX = {}
for index, band_def in ipairs(BAND_DEFS) do
    band_def.index = index
    BAND_INDEX[band_def.key] = index
end

local SIGNAL_VIGOR = {type = "virtual", name = "ei-auric-vat-vigor", quality = "normal", comparator = "="}
local SIGNAL_CONTAMINATION = {type = "virtual", name = "ei-auric-vat-contamination", quality = "normal", comparator = "="}
local SIGNAL_BAND = {type = "virtual", name = "ei-auric-vat-band", quality = "normal", comparator = "="}
local SIGNAL_CLAIMS = {type = "virtual", name = "ei-auric-vat-claims", quality = "normal", comparator = "="}
local SIGNAL_BLOOM = {type = "virtual", name = "ei-auric-vat-bloom", quality = "normal", comparator = "="}

local wire = {}
wire.connector_ids = defines.wire_connector_id or {}
wire.origin = defines.wire_origin and defines.wire_origin.script or nil
wire.red_connector_ids = {
    wire.connector_ids.circuit_red,
    wire.connector_ids.combinator_output_red,
    wire.connector_ids.combinator_input_red,
}
wire.green_connector_ids = {
    wire.connector_ids.circuit_green,
    wire.connector_ids.combinator_output_green,
    wire.connector_ids.combinator_input_green,
}

local TELEMETRY_SIGNAL_SLOTS = {
    {key = "vigor", slot = 1, signal = SIGNAL_VIGOR},
    {key = "contamination", slot = 2, signal = SIGNAL_CONTAMINATION},
    {key = "band", slot = 3, signal = SIGNAL_BAND},
    {key = "claims", slot = 4, signal = SIGNAL_CLAIMS},
    {key = "bloom", slot = 5, signal = SIGNAL_BLOOM},
}

-- Vigor and contamination intentionally overlap rather than acting as simple
-- opposites. A basin can be healthy but dirty, clean but exhausted, or fully
-- ruptured; status, failure rolls, and bloom permission all read from these
-- thresholds.
local VIGOR_STRAINED_THRESHOLD = 55
local VIGOR_FAILURE_THRESHOLD = 20
local CONTAMINATION_STRAINED_THRESHOLD = 45
local CONTAMINATION_FAILURE_THRESHOLD = 100
local FAILURE_TILE_DOWNGRADE_PERCENT = 25
local DEFAULT_FAILURE_TILE = "wetland-dead-skin"

-- Failure is not a generic damage tick. It biologically pushes the claimed marsh
-- one step deeper into Gleba's wetland palette, so repeated bad operation leaves
-- a visible scar while still staying inside eligible basin terrain.
local WETLAND_TILE_DOWNGRADE = {
    ["wetland-light-green-slime"] = "wetland-green-slime",
    ["wetland-green-slime"] = "wetland-light-dead-skin",
    ["wetland-light-dead-skin"] = "wetland-dead-skin",
    ["wetland-dead-skin"] = "wetland-pink-tentacle",
    ["wetland-pink-tentacle"] = "wetland-red-tentacle",
    ["wetland-red-tentacle"] = "wetland-red-tentacle",
}

model.WETLAND_TILE_RANK = {
    ["wetland-light-green-slime"] = 1,
    ["wetland-green-slime"] = 2,
    ["wetland-light-dead-skin"] = 3,
    ["wetland-dead-skin"] = 4,
    ["wetland-pink-tentacle"] = 5,
    ["wetland-red-tentacle"] = 6,
}

model.WETLAND_TILE_RECOVERY = {
    ["wetland-green-slime"] = "wetland-light-green-slime",
    ["wetland-light-dead-skin"] = "wetland-green-slime",
    ["wetland-dead-skin"] = "wetland-light-dead-skin",
    ["wetland-pink-tentacle"] = "wetland-dead-skin",
    ["wetland-red-tentacle"] = "wetland-pink-tentacle",
}

local ELIGIBLE_TILES = {
    ["wetland-light-green-slime"] = true,
    ["wetland-green-slime"] = true,
    ["wetland-light-dead-skin"] = true,
    ["wetland-dead-skin"] = true,
    ["wetland-pink-tentacle"] = true,
    ["wetland-red-tentacle"] = true,
}

local ELIGIBLE_TILE_NAMES = {}
for tile_name in pairs(ELIGIBLE_TILES) do
    ELIGIBLE_TILE_NAMES[#ELIGIBLE_TILE_NAMES + 1] = tile_name
end

-- Basin discovery is deliberately four-way contiguous rather than diagonal.
-- That makes skinny channels, cut banks, and neighboring vat claims matter in a
-- way players can read from the tile shape.
local CARDINAL_OFFSETS = {
    {x = 1, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 1},
    {x = 0, y = -1},
}

-- Every public event path passes its event object through here, keeping event.tick
-- authoritative when available and falling back to game.tick only for utility or
-- rebuild paths that do not arrive from a normal event.
local function now_tick(event_or_tick)
    if type(event_or_tick) == "number" then
        return math.max(0, math.floor(event_or_tick))
    end

    if type(event_or_tick) == "table" and event_or_tick.tick ~= nil then
        return math.max(0, math.floor(tonumber(event_or_tick.tick) or 0))
    end

    return (game and game.tick) or 0
end

local function entity_check(entity)
    return ei_lib.entity_check(entity)
end

local function get_event_entity(event_or_entity)
    local entity = ei_lib.get_valid_entity(event_or_entity)
    if entity then
        return entity
    end

    if type(event_or_entity) ~= "table" then
        return nil
    end

    return ei_lib.get_valid_entity(event_or_entity.entity)
        or ei_lib.get_valid_entity(event_or_entity.created_entity)
        or ei_lib.get_valid_entity(event_or_entity.destination)
end

-- Hot dispatcher queries only need to know whether an auric runtime already
-- exists. They should not create or normalize storage every idle tick in a world
-- with no vats, so they use this raw view before falling back to get_runtime().
local function get_existing_runtime()
    local runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if type(runtime) == "table" and runtime.version == RUNTIME_VERSION then
        return runtime
    end

    return nil
end

local function get_unit_number(entity)
    return ei_lib.get_entity_unit_number(entity)
end

-- Factorio 2.0 exposes runtime prototypes through the global `prototypes`
-- object. Older compatibility paths used `game.entity_prototypes`, but reading a
-- missing LuaGameScript key now throws, so the legacy branch must be pcall-gated.
local function get_entity_prototypes()
    if prototypes and prototypes.entity then
        return prototypes.entity
    end

    if game then
        local ok, legacy_entity_prototypes = pcall(function()
            return game.entity_prototypes
        end)
        if ok then
            return legacy_entity_prototypes
        end
    end

    return nil
end

local function entity_prototype_exists(entity_name)
    local entity_prototypes = get_entity_prototypes()
    return entity_prototypes and entity_prototypes[entity_name] ~= nil
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function seconds_text(ticks)
    return string.format("%.1f", math.max(0, (tonumber(ticks) or 0) / 60))
end

local function get_phase_locale(phase_key)
    if PHASE_DEFS[phase_key] then
        return {"exotic-industries.auric-inoculation-vat-phase-" .. phase_key}
    end

    return tostring(phase_key or "rest")
end

local function get_status_locale(status_key)
    if status_key == "conflict"
    or status_key == "invalid"
    or status_key == "invalid-no-basin"
    or status_key == "invalid-too-small"
    or status_key == "invalid-too-large"
    or status_key == "failure"
    or status_key == "blocked-drain"
    or status_key == "starved"
    or status_key == "strained"
    or status_key == "resting" then
        return {"exotic-industries.auric-inoculation-vat-status-" .. status_key}
    end

    return {"exotic-industries.auric-inoculation-vat-status-stable"}
end

local function get_bloom_state_value(record)
    if not record or record.claim_valid ~= true then
        return 0
    end

    if record.contamination >= CONTAMINATION_FAILURE_THRESHOLD or record.vigor <= VIGOR_FAILURE_THRESHOLD then
        return 3
    end

    if record.contamination >= CONTAMINATION_STRAINED_THRESHOLD
    or record.vigor <= VIGOR_STRAINED_THRESHOLD
    or record.blocked_drain_streak > 0
    or record.starvation_streak > 0 then
        return 2
    end

    return 1
end

local function get_bloom_state_locale(bloom_state)
    if bloom_state == 0 then
        return {"exotic-industries.auric-inoculation-vat-gui-bloom-unavailable"}
    end

    if bloom_state == 3 then
        return {"exotic-industries.auric-inoculation-vat-gui-bloom-failed"}
    end

    if bloom_state == 2 then
        return {"exotic-industries.auric-inoculation-vat-gui-bloom-strained"}
    end

    return {"exotic-industries.auric-inoculation-vat-gui-bloom-stable"}
end

local function get_tile_key(surface_index, x, y)
    return tostring(tonumber(surface_index) or 0) .. ":" .. tostring(tonumber(x) or 0) .. ":" .. tostring(tonumber(y) or 0)
end

local function is_eligible_tile_name(tile_name)
    return ELIGIBLE_TILES[tile_name] == true
end

local function get_downgraded_tile_name(tile_name)
    if not is_eligible_tile_name(tile_name) then
        return nil
    end

    return WETLAND_TILE_DOWNGRADE[tile_name] or DEFAULT_FAILURE_TILE
end

function model._get_recovered_tile_name(tile_name, original_tile_name)
    if not (is_eligible_tile_name(tile_name) and is_eligible_tile_name(original_tile_name)) then
        return nil
    end

    local tile_rank = model.WETLAND_TILE_RANK[tile_name]
    local original_rank = model.WETLAND_TILE_RANK[original_tile_name]
    if not tile_rank or not original_rank or tile_rank <= original_rank then
        return nil
    end

    local recovered_name = model.WETLAND_TILE_RECOVERY[tile_name]
    local recovered_rank = recovered_name and model.WETLAND_TILE_RANK[recovered_name]
    if not recovered_rank or recovered_rank < original_rank then
        return original_tile_name
    end

    return recovered_name
end

local function safe_runtime_field(object, field_name)
    if object == nil then
        return nil
    end

    local ok, value = pcall(function()
        return object[field_name]
    end)
    if ok then
        return value
    end

    return nil
end

local function get_runtime_prototype_name(prototype)
    local name = safe_runtime_field(prototype, "name")
    if type(name) == "table" then
        return name.name
    end

    return name
end

local function prototype_places_vat(prototype)
    if get_runtime_prototype_name(prototype) == VAT_NAME then
        return true
    end

    local place_result = safe_runtime_field(prototype, "place_result")
    return get_runtime_prototype_name(place_result) == VAT_NAME
end

-- Blueprint cursor detection is intentionally narrow. Blueprint books and remote
-- libraries have extra record semantics; the placement guide only needs to wake
-- for the concrete cursor blueprint that can immediately place vat ghosts.
local function blueprint_stack_contains_vat(stack)
    if safe_runtime_field(stack, "is_blueprint") ~= true then
        return false
    end

    local ok, blueprint_entities = pcall(function()
        return stack.get_blueprint_entities()
    end)
    if not ok or type(blueprint_entities) ~= "table" then
        return false
    end

    for _, blueprint_entity in ipairs(blueprint_entities) do
        if blueprint_entity and blueprint_entity.name == VAT_NAME then
            return true
        end
    end

    return false
end

local function cursor_stack_places_vat(stack)
    if not (stack and safe_runtime_field(stack, "valid_for_read") == true) then
        return false
    end

    if blueprint_stack_contains_vat(stack) then
        return true
    end

    if safe_runtime_field(stack, "name") == VAT_NAME then
        return true
    end

    return prototype_places_vat(safe_runtime_field(stack, "prototype"))
end

local function player_holds_vat_placement(player)
    if not (player and player.valid) then
        return false
    end

    if cursor_stack_places_vat(safe_runtime_field(player, "cursor_stack")) then
        return true
    end

    return prototype_places_vat(safe_runtime_field(player, "cursor_ghost"))
end

function model._set_player_cursor_intent(runtime, player_index, holds_vat)
    if not (runtime and player_index) then
        return holds_vat == true
    end

    runtime.placement_cursor_intent_by_player = type(runtime.placement_cursor_intent_by_player) == "table"
        and runtime.placement_cursor_intent_by_player
        or {}
    runtime.placement_cursor_intent_by_player[player_index] = holds_vat == true and true or nil
    return holds_vat == true
end

function model._get_player_cursor_intent(runtime, player)
    if not (runtime and player and player.valid) then
        return false
    end

    local intents = runtime.placement_cursor_intent_by_player
    if type(intents) == "table" and intents[player.index] ~= nil then
        return intents[player.index] == true
    end

    return model._set_player_cursor_intent(runtime, player.index, player_holds_vat_placement(player))
end

function model._clear_player_cursor_intent(runtime, player_index)
    if runtime and runtime.placement_cursor_intent_by_player then
        runtime.placement_cursor_intent_by_player[player_index] = nil
    end
end

local function get_player_alt_mode(player, fallback)
    local game_view_settings = safe_runtime_field(player, "game_view_settings")
    if game_view_settings then
        return game_view_settings.show_entity_info == true
    end

    return fallback == true
end

local function get_placement_radius(alt_mode)
    if alt_mode then
        return PLACEMENT_GUIDE_ALT_RADIUS
    end

    return PLACEMENT_GUIDE_RADIUS
end

local function get_placement_chunk_key(chunk_x, chunk_y)
    return tostring(tonumber(chunk_x) or 0) .. ":" .. tostring(tonumber(chunk_y) or 0)
end

local function get_placement_viewport_key(surface_index, center_chunk)
    return tostring(surface_index or 0) .. ":" .. get_placement_chunk_key(center_chunk.x, center_chunk.y)
end

local function get_placement_chunk_position(position)
    return {
        x = math.floor((position.x or 0) / PLACEMENT_GUIDE_CHUNK_SIZE),
        y = math.floor((position.y or 0) / PLACEMENT_GUIDE_CHUNK_SIZE),
    }
end

local function get_placement_viewport_chunks(center_chunk)
    local wanted = {}
    local ordered = {}

    for chunk_y = center_chunk.y - PLACEMENT_GUIDE_VERTICAL_CHUNKS, center_chunk.y + PLACEMENT_GUIDE_VERTICAL_CHUNKS do
        for chunk_x = center_chunk.x - PLACEMENT_GUIDE_HORIZONTAL_CHUNKS, center_chunk.x + PLACEMENT_GUIDE_HORIZONTAL_CHUNKS do
            local key = get_placement_chunk_key(chunk_x, chunk_y)
            wanted[key] = true
            ordered[#ordered + 1] = {
                key = key,
                x = chunk_x,
                y = chunk_y,
            }
        end
    end

    return wanted, ordered
end

function model._set_placement_viewport_bounds(state, center_chunk)
    state.view_left_chunk = center_chunk.x - PLACEMENT_GUIDE_HORIZONTAL_CHUNKS
    state.view_right_chunk = center_chunk.x + PLACEMENT_GUIDE_HORIZONTAL_CHUNKS
    state.view_top_chunk = center_chunk.y - PLACEMENT_GUIDE_VERTICAL_CHUNKS
    state.view_bottom_chunk = center_chunk.y + PLACEMENT_GUIDE_VERTICAL_CHUNKS
end

function model._placement_view_intersects(state, left_chunk, top_chunk, right_chunk, bottom_chunk)
    if not (state and state.view_left_chunk and state.view_right_chunk and state.view_top_chunk and state.view_bottom_chunk) then
        return true
    end

    return not (
        right_chunk < state.view_left_chunk
        or left_chunk > state.view_right_chunk
        or bottom_chunk < state.view_top_chunk
        or top_chunk > state.view_bottom_chunk
    )
end

local function add_placement_stale_cleanup(runtime, count)
    count = math.max(0, math.floor(tonumber(count) or 0))
    if count <= 0 then
        return
    end

    runtime.placement_stale_cleanup_count = (tonumber(runtime.placement_stale_cleanup_count) or 0) + count
end

local function destroy_placement_chunk(runtime, chunk, count_as_stale)
    local cleanup_count = 0
    for _, render_object in ipairs(chunk and chunk.render_objects or {}) do
        if render_object then
            cleanup_count = cleanup_count + 1
            if render_object.valid then
                render_object.destroy()
            end
        end
    end

    if count_as_stale then
        add_placement_stale_cleanup(runtime, cleanup_count)
    end

    return cleanup_count
end

function model._clear_skipped_placement_chunks(state)
    local cleared_count = 0
    for chunk_key, chunk in pairs(state and state.chunks or {}) do
        if chunk and chunk.skipped_ungenerated then
            state.chunks[chunk_key] = nil
            cleared_count = cleared_count + 1
        end
    end

    state.skipped_ungenerated_chunk_count = 0
    return cleared_count
end

local function add_placement_surface_membership(runtime, player_index, surface_index)
    if not (runtime and player_index and surface_index) then
        return
    end

    runtime.placement_guides_by_surface = runtime.placement_guides_by_surface or {}
    surface_index = tonumber(surface_index) or 0
    runtime.placement_guides_by_surface[surface_index] = runtime.placement_guides_by_surface[surface_index] or {}
    runtime.placement_guides_by_surface[surface_index][player_index] = true
end

local function remove_placement_surface_membership(runtime, player_index, surface_index)
    if not (runtime and runtime.placement_guides_by_surface and player_index and surface_index) then
        return
    end

    surface_index = tonumber(surface_index) or 0
    local bucket = runtime.placement_guides_by_surface[surface_index]
    if not bucket then
        return
    end

    bucket[player_index] = nil
    if next(bucket) == nil then
        runtime.placement_guides_by_surface[surface_index] = nil
    end
end

local function get_placement_player_indices_for_surface(runtime, surface_index)
    if not (runtime and runtime.placement_guides_by_surface) then
        return {}
    end

    surface_index = tonumber(surface_index) or 0
    local bucket = runtime.placement_guides_by_surface[surface_index]
    local player_indices = {}
    for player_index in pairs(bucket or {}) do
        player_indices[#player_indices + 1] = player_index
    end
    return player_indices
end

local function destroy_player_placement_guide(runtime, player_index, count_as_stale)
    local state = runtime.placement_guides and runtime.placement_guides[player_index]
    if not state then
        return false
    end

    for _, chunk in pairs(state.chunks or {}) do
        destroy_placement_chunk(runtime, chunk, count_as_stale)
    end

    remove_placement_surface_membership(runtime, player_index, state.surface_index)
    runtime.placement_guides[player_index] = nil
    model._clear_player_cursor_intent(runtime, player_index)
    return true
end

local function destroy_all_placement_guides(runtime, count_as_stale)
    if not (runtime and type(runtime.placement_guides) == "table") then
        return
    end

    local player_indices = {}
    for player_index in pairs(runtime.placement_guides) do
        player_indices[#player_indices + 1] = player_index
    end

    for _, player_index in ipairs(player_indices) do
        destroy_player_placement_guide(runtime, player_index, count_as_stale)
    end
end

local function clear_placement_guide_chunks(runtime, state, count_as_stale)
    for _, chunk in pairs(state.chunks or {}) do
        destroy_placement_chunk(runtime, chunk, count_as_stale)
    end

    state.chunks = {}
    state.last_viewport_key = nil
    state.skipped_ungenerated_chunk_count = 0
    state.view_left_chunk = nil
    state.view_right_chunk = nil
    state.view_top_chunk = nil
    state.view_bottom_chunk = nil
    state.next_skipped_ungenerated_retry_tick = nil
end

local function ensure_placement_guide(runtime, player)
    local surface = player.surface
    if not (surface and surface.valid) then
        return nil
    end

    local state = runtime.placement_guides[player.index]
    if state and state.surface_index ~= surface.index then
        destroy_player_placement_guide(runtime, player.index, false)
        state = nil
    end

    if not state then
        state = {
            player_index = player.index,
            surface_index = surface.index,
            chunks = {},
            last_viewport_key = nil,
            alt_mode = get_player_alt_mode(player, false),
        }
        runtime.placement_guides[player.index] = state
        add_placement_surface_membership(runtime, player.index, state.surface_index)
    else
        add_placement_surface_membership(runtime, player.index, state.surface_index)
    end

    state.alt_mode = get_player_alt_mode(player, state.alt_mode)
    return state
end

local function render_placement_chunk(runtime, player, state, chunk_position)
    local surface = player.surface
    local chunk = {
        x = chunk_position.x,
        y = chunk_position.y,
        render_objects = {},
        render_object_count = 0,
    }
    if surface.is_chunk_generated and not surface.is_chunk_generated({x = chunk_position.x, y = chunk_position.y}) then
        chunk.skipped_ungenerated = true
        state.chunks[chunk_position.key] = chunk
        state.skipped_ungenerated_chunk_count = (state.skipped_ungenerated_chunk_count or 0) + 1
        runtime.placement_skipped_ungenerated_chunk_count = (runtime.placement_skipped_ungenerated_chunk_count or 0) + 1
        return chunk
    end

    local left_top = {
        x = chunk_position.x * PLACEMENT_GUIDE_CHUNK_SIZE,
        y = chunk_position.y * PLACEMENT_GUIDE_CHUNK_SIZE,
    }
    local right_bottom = {
        x = left_top.x + PLACEMENT_GUIDE_CHUNK_SIZE,
        y = left_top.y + PLACEMENT_GUIDE_CHUNK_SIZE,
    }
    local tiles = surface.find_tiles_filtered{
        area = {left_top, right_bottom},
        name = ELIGIBLE_TILE_NAMES,
    }
    local radius = get_placement_radius(state.alt_mode)
    local claims_by_tile = runtime.claims_by_tile or {}
    local has_claims = next(claims_by_tile) ~= nil
    local player_filter = {player.index}

    for _, tile in ipairs(tiles) do
        local position = tile.position
        local claimed = false
        if has_claims then
            claimed = claims_by_tile[get_tile_key(surface.index, position.x, position.y)] ~= nil
        end
        local render_object = rendering.draw_circle{
            surface = surface,
            target = {position.x + 0.5, position.y + 0.5},
            radius = radius,
            color = claimed and PLACEMENT_GUIDE_UNAVAILABLE_COLOR or PLACEMENT_GUIDE_AVAILABLE_COLOR,
            filled = true,
            draw_on_ground = true,
            players = player_filter,
        }

        if render_object then
            chunk.render_objects[#chunk.render_objects + 1] = render_object
            chunk.render_object_count = chunk.render_object_count + 1
        end
    end

    state.chunks[chunk_position.key] = chunk
    return chunk
end

local function prune_placement_chunks(runtime, state, wanted_chunks)
    local changed = false
    for chunk_key, chunk in pairs(state.chunks or {}) do
        if not wanted_chunks[chunk_key] then
            destroy_placement_chunk(runtime, chunk, true)
            state.chunks[chunk_key] = nil
            changed = true
        end
    end

    return changed
end

local function sync_player_placement_guide(runtime, player, allow_start, skip_hold_check_when_viewport_unchanged, known_holds_vat, current_tick)
    if not (player and player.valid) then
        return false
    end

    local existing = runtime.placement_guides[player.index]
    local surface = player.surface
    local center_chunk = get_placement_chunk_position(player.position)
    local viewport_key = get_placement_viewport_key(surface and surface.index, center_chunk)

    -- Position changes fire constantly while walking. If an already-active guide
    -- remains inside the same chunk window, cursor-stack contents cannot change
    -- because of movement alone; the cursor-change event owns that cleanup path.
    -- This avoids rescanning large blueprints on every small step.
    if skip_hold_check_when_viewport_unchanged
    and existing
    and existing.surface_index == (surface and surface.index)
    and existing.last_viewport_key == viewport_key
    and (existing.skipped_ungenerated_chunk_count or 0) <= 0 then
        return false
    end

    local holds_vat = known_holds_vat
    if holds_vat == nil then
        holds_vat = model._get_player_cursor_intent(runtime, player)
    else
        model._set_player_cursor_intent(runtime, player.index, holds_vat)
    end

    if not holds_vat then
        return destroy_player_placement_guide(runtime, player.index, false)
    end

    if not existing and allow_start == false then
        return false
    end

    local state = ensure_placement_guide(runtime, player)
    if not state then
        return false
    end

    if state.last_viewport_key == viewport_key then
        if (state.skipped_ungenerated_chunk_count or 0) > 0 and current_tick then
            local next_retry_tick = tonumber(state.next_skipped_ungenerated_retry_tick) or 0
            if next_retry_tick > current_tick then
                return false
            end
            state.next_skipped_ungenerated_retry_tick = current_tick + model.PLACEMENT_GUIDE_SKIPPED_CHUNK_RETRY_TICKS
        end
        if model._clear_skipped_placement_chunks(state) <= 0 then
            return false
        end
    end

    local wanted_chunks, ordered_chunks = get_placement_viewport_chunks(center_chunk)
    local changed = prune_placement_chunks(runtime, state, wanted_chunks)
    model._set_placement_viewport_bounds(state, center_chunk)

    for _, chunk_position in ipairs(ordered_chunks) do
        if not state.chunks[chunk_position.key] then
            render_placement_chunk(runtime, player, state, chunk_position)
            changed = true
        end
    end

    state.last_viewport_key = viewport_key
    return changed
end

local function redraw_player_placement_guide(runtime, player, known_holds_vat)
    local state = player and runtime.placement_guides[player.index]
    if not state then
        return false
    end

    clear_placement_guide_chunks(runtime, state, false)
    return sync_player_placement_guide(runtime, player, true, false, known_holds_vat)
end

local function redraw_active_placement_guides(runtime)
    if not (game and type(runtime.placement_guides) == "table") then
        return false
    end

    local changed = false
    local player_indices = {}
    for player_index in pairs(runtime.placement_guides) do
        player_indices[#player_indices + 1] = player_index
    end

    for _, player_index in ipairs(player_indices) do
        local player = game.get_player(player_index)
        if player and player.valid and model._get_player_cursor_intent(runtime, player) then
            changed = redraw_player_placement_guide(runtime, player, true) or changed
        else
            changed = destroy_player_placement_guide(runtime, player_index, false) or changed
        end
    end

    return changed
end

local function redraw_placement_guides_for_surface(runtime, surface_index)
    if not (game and type(runtime.placement_guides) == "table") then
        return false
    end

    surface_index = tonumber(surface_index) or 0
    local changed = false
    local player_indices = get_placement_player_indices_for_surface(runtime, surface_index)

    for _, player_index in ipairs(player_indices) do
        local player = game.get_player(player_index)
        if player and player.valid and model._get_player_cursor_intent(runtime, player) then
            changed = redraw_player_placement_guide(runtime, player, true) or changed
        else
            changed = destroy_player_placement_guide(runtime, player_index, false) or changed
        end
    end

    return changed
end

local function has_placement_guide_on_surface(runtime, surface_index)
    if not (runtime and type(runtime.placement_guides_by_surface) == "table") then
        return false
    end

    surface_index = tonumber(surface_index) or 0
    local bucket = runtime.placement_guides_by_surface[surface_index]
    return bucket and next(bucket) ~= nil
end

local function redraw_placement_guides_for_area(runtime, surface_index, left_top, right_bottom)
    if not (game and type(runtime.placement_guides) == "table" and left_top and right_bottom) then
        return false
    end

    surface_index = tonumber(surface_index) or 0
    local changed = false
    local player_indices = get_placement_player_indices_for_surface(runtime, surface_index)
    local left_chunk = math.floor((left_top.x or 0) / PLACEMENT_GUIDE_CHUNK_SIZE)
    local top_chunk = math.floor((left_top.y or 0) / PLACEMENT_GUIDE_CHUNK_SIZE)
    local right_chunk = math.floor(((right_bottom.x or 0) - 0.001) / PLACEMENT_GUIDE_CHUNK_SIZE)
    local bottom_chunk = math.floor(((right_bottom.y or 0) - 0.001) / PLACEMENT_GUIDE_CHUNK_SIZE)

    for _, player_index in ipairs(player_indices) do
        local player = game.get_player(player_index)
        local state = runtime.placement_guides[player_index]
        if player and player.valid and state and model._get_player_cursor_intent(runtime, player) then
            local removed = false

            if model._placement_view_intersects(state, left_chunk, top_chunk, right_chunk, bottom_chunk) then
                for chunk_y = top_chunk, bottom_chunk do
                    for chunk_x = left_chunk, right_chunk do
                        local chunk_key = get_placement_chunk_key(chunk_x, chunk_y)
                        local chunk = state.chunks and state.chunks[chunk_key]
                        if chunk then
                            destroy_placement_chunk(runtime, chunk, false)
                            state.chunks[chunk_key] = nil
                            removed = true
                        end
                    end
                end
            else
                runtime.placement_dirty_player_skip_count = (runtime.placement_dirty_player_skip_count or 0) + 1
            end

            if removed then
                state.last_viewport_key = nil
                changed = sync_player_placement_guide(runtime, player, false, false, true) or true
            end
        else
            changed = destroy_player_placement_guide(runtime, player_index, false) or changed
        end
    end

    return changed
end

local function redraw_placement_guides_for_regions(runtime, surface_index, regions)
    if not (game and type(runtime.placement_guides) == "table" and regions and #regions > 0) then
        return false
    end

    local dirty_regions = {}
    local dirty_chunk_count = 0
    local dirty_left_chunk = nil
    local dirty_top_chunk = nil
    local dirty_right_chunk = nil
    local dirty_bottom_chunk = nil
    for _, region in ipairs(regions) do
        local left_top = region and region.left_top
        local right_bottom = region and region.right_bottom
        if left_top and right_bottom then
            local left_chunk = math.floor(((left_top.x or 0) - BASIN_RADIUS) / PLACEMENT_GUIDE_CHUNK_SIZE)
            local top_chunk = math.floor(((left_top.y or 0) - BASIN_RADIUS) / PLACEMENT_GUIDE_CHUNK_SIZE)
            local right_chunk = math.floor((((right_bottom.x or 0) + BASIN_RADIUS) - 0.001) / PLACEMENT_GUIDE_CHUNK_SIZE)
            local bottom_chunk = math.floor((((right_bottom.y or 0) + BASIN_RADIUS) - 0.001) / PLACEMENT_GUIDE_CHUNK_SIZE)
            dirty_left_chunk = dirty_left_chunk and math.min(dirty_left_chunk, left_chunk) or left_chunk
            dirty_top_chunk = dirty_top_chunk and math.min(dirty_top_chunk, top_chunk) or top_chunk
            dirty_right_chunk = dirty_right_chunk and math.max(dirty_right_chunk, right_chunk) or right_chunk
            dirty_bottom_chunk = dirty_bottom_chunk and math.max(dirty_bottom_chunk, bottom_chunk) or bottom_chunk
            dirty_regions[#dirty_regions + 1] = {
                left = left_chunk,
                top = top_chunk,
                right = right_chunk,
                bottom = bottom_chunk,
            }
            dirty_chunk_count = dirty_chunk_count + ((right_chunk - left_chunk + 1) * (bottom_chunk - top_chunk + 1))
        end
    end

    if #dirty_regions == 0 then
        return false
    end

    surface_index = tonumber(surface_index) or 0
    runtime.last_tile_change_dirty_chunk_count = dirty_chunk_count
    local changed = false
    local player_indices = get_placement_player_indices_for_surface(runtime, surface_index)

    for _, player_index in ipairs(player_indices) do
        local player = game.get_player(player_index)
        local state = runtime.placement_guides[player_index]
        if player and player.valid and state and model._get_player_cursor_intent(runtime, player) then
            local removed = false
            local chunks = state.chunks or {}
            if model._placement_view_intersects(state, dirty_left_chunk, dirty_top_chunk, dirty_right_chunk, dirty_bottom_chunk) then
                for chunk_key, chunk in pairs(chunks) do
                    local chunk_x = chunk and chunk.x
                    local chunk_y = chunk and chunk.y
                    if chunk_x and chunk_y then
                        for _, dirty_region in ipairs(dirty_regions) do
                            if chunk_x >= dirty_region.left
                            and chunk_x <= dirty_region.right
                            and chunk_y >= dirty_region.top
                            and chunk_y <= dirty_region.bottom then
                                destroy_placement_chunk(runtime, chunk, false)
                                chunks[chunk_key] = nil
                                removed = true
                                break
                            end
                        end
                    end
                end
            else
                runtime.placement_dirty_player_skip_count = (runtime.placement_dirty_player_skip_count or 0) + 1
            end

            if removed then
                state.last_viewport_key = nil
                changed = sync_player_placement_guide(runtime, player, false, false, true) or true
            end
        else
            changed = destroy_player_placement_guide(runtime, player_index, false) or changed
        end
    end

    return changed
end

local function sync_connected_placement_guides(runtime)
    if not (game and game.connected_players) then
        return false
    end

    local changed = false
    for _, player in pairs(game.connected_players) do
        if model._get_player_cursor_intent(runtime, player) then
            changed = sync_player_placement_guide(runtime, player, true) or changed
        end
    end

    return changed
end

local function set_placement_guide_alt_mode(runtime, player_index, alt_mode)
    local state = runtime.placement_guides and runtime.placement_guides[player_index]
    if not state then
        return false
    end

    alt_mode = alt_mode == true
    if state.alt_mode == alt_mode then
        return false
    end

    state.alt_mode = alt_mode
    local radius = get_placement_radius(state.alt_mode)
    local cleaned = 0

    for _, chunk in pairs(state.chunks or {}) do
        local live_render_objects = {}
        for _, render_object in ipairs(chunk.render_objects or {}) do
            if render_object and render_object.valid then
                render_object.radius = radius
                live_render_objects[#live_render_objects + 1] = render_object
            elseif render_object then
                cleaned = cleaned + 1
            end
        end
        chunk.render_objects = live_render_objects
        chunk.render_object_count = #live_render_objects
    end

    add_placement_stale_cleanup(runtime, cleaned)
    return true
end

local function get_placement_guide_counts(runtime, detailed)
    if detailed == false then
        return {
            active_player_count = scheduler.table_count(runtime.placement_guides),
            surface_count = scheduler.table_count(runtime.placement_guides_by_surface),
            cursor_intent_cached_player_count = scheduler.table_count(runtime.placement_cursor_intent_by_player),
            rendered_chunk_count = 0,
            render_object_count = 0,
            stale_cleanup_count = tonumber(runtime.placement_stale_cleanup_count) or 0,
            skipped_ungenerated_chunk_count = tonumber(runtime.placement_skipped_ungenerated_chunk_count) or 0,
            dirty_player_skip_count = tonumber(runtime.placement_dirty_player_skip_count) or 0,
        }
    end

    local active_player_count = 0
    local rendered_chunk_count = 0
    local render_object_count = 0

    for _, state in pairs(runtime.placement_guides or {}) do
        active_player_count = active_player_count + 1
        for _, chunk in pairs(state.chunks or {}) do
            rendered_chunk_count = rendered_chunk_count + 1
            render_object_count = render_object_count + (tonumber(chunk.render_object_count) or #(chunk.render_objects or {}))
        end
    end

    return {
        active_player_count = active_player_count,
        surface_count = scheduler.table_count(runtime.placement_guides_by_surface),
        cursor_intent_cached_player_count = scheduler.table_count(runtime.placement_cursor_intent_by_player),
        rendered_chunk_count = rendered_chunk_count,
        render_object_count = render_object_count,
        stale_cleanup_count = tonumber(runtime.placement_stale_cleanup_count) or 0,
        skipped_ungenerated_chunk_count = tonumber(runtime.placement_skipped_ungenerated_chunk_count) or 0,
        dirty_player_skip_count = tonumber(runtime.placement_dirty_player_skip_count) or 0,
    }
end

-- Serialized runtime is intentionally plain tables plus shared scheduler queues.
-- `due_tick_by_unit` is the authority for whether a delayed bucket entry is still
-- real; old bucket entries are allowed to become harmless stale echoes.
local function new_runtime()
    return {
        version = RUNTIME_VERSION,
        vats_by_unit = {},
        units_by_surface = {},
        claims_by_tile = {},
        proxy_owner_by_unit = {},
        registrations = {},
        due_buckets = scheduler.ensure_delayed_buckets(nil),
        due_tick_by_unit = {},
        ready_queue = scheduler.ensure_queue(nil),
        ready_queue_count = 0,
        next_due_tick = 0,
        open_by_player = {},
        ui_due_buckets = scheduler.ensure_delayed_buckets(nil),
        ui_pending_by_player = {},
        next_ui_due_tick = 0,
        last_status_tick = 0,
        placement_guides = {},
        placement_guides_by_surface = {},
        placement_cursor_intent_by_player = {},
        placement_stale_cleanup_count = 0,
        placement_skipped_ungenerated_chunk_count = 0,
        placement_dirty_player_skip_count = 0,
        last_tile_change_region_count = 0,
        last_tile_change_dirty_chunk_count = 0,
        last_tile_change_scan_region_count = 0,
        tile_change_region_refresh_count = 0,
        ui_stale_bucket_entry_count = 0,
        last_ui_refresh_player_count = 0,
        telemetry_proxy_available = nil,
        orphan_telemetry_proxy_cleanup_count = 0,
        due_stale_bucket_entry_count = 0,
        ready_stale_dequeue_count = 0,
        due_activation_deferred_count = 0,
        last_due_activation_scanned_count = 0,
        last_due_activation_activated_count = 0,
    }
end

local function reconcile_ready_queue_count(runtime)
    runtime.ready_queue = scheduler.ensure_queue(runtime.ready_queue)
    runtime.ready_queue_count = scheduler.table_count(runtime.ready_queue.queued)
    return runtime.ready_queue_count
end

local function bump_ready_queue_count(runtime, delta)
    local count = tonumber(runtime.ready_queue_count)
    if not count then
        count = reconcile_ready_queue_count(runtime)
    end

    count = math.max(0, count + delta)
    runtime.ready_queue_count = count
    return count
end

local function push_ready_unit(runtime, unit_number)
    if tonumber(runtime.ready_queue_count) == nil then
        reconcile_ready_queue_count(runtime)
    end

    local pushed = scheduler.queue_push_unique(runtime.ready_queue, unit_number, unit_number)
    if pushed then
        bump_ready_queue_count(runtime, 1)
    end

    return pushed
end

local function remove_ready_unit(runtime, unit_number)
    runtime.ready_queue = scheduler.ensure_queue(runtime.ready_queue)
    if tonumber(runtime.ready_queue_count) == nil then
        reconcile_ready_queue_count(runtime)
    end

    local was_queued = runtime.ready_queue.queued and runtime.ready_queue.queued[unit_number] == true
    local removed = scheduler.queue_remove_value(runtime.ready_queue, unit_number)
    if was_queued then
        bump_ready_queue_count(runtime, -1)
    end

    return removed or was_queued
end

local function pop_ready_unit(runtime)
    if tonumber(runtime.ready_queue_count) == nil then
        reconcile_ready_queue_count(runtime)
    end

    local unit_number = scheduler.queue_pop_queued(runtime.ready_queue)
    if unit_number then
        bump_ready_queue_count(runtime, -1)
    end

    return unit_number
end

-- Storage repair is cheap and local. It normalizes tables and scheduler helper
-- shapes without scanning the world, leaving full reconstruction to
-- rebuild_runtime_state() on init/configuration changes.
local function get_runtime()
    storage.ei = storage.ei or {}

    local runtime = storage.ei.auric_inoculation_vat
    if type(runtime) ~= "table" or runtime.version ~= RUNTIME_VERSION then
        runtime = new_runtime()
        storage.ei.auric_inoculation_vat = runtime
    end

    runtime.vats_by_unit = type(runtime.vats_by_unit) == "table" and runtime.vats_by_unit or {}
    runtime.units_by_surface = type(runtime.units_by_surface) == "table" and runtime.units_by_surface or {}
    runtime.claims_by_tile = type(runtime.claims_by_tile) == "table" and runtime.claims_by_tile or {}
    runtime.proxy_owner_by_unit = type(runtime.proxy_owner_by_unit) == "table" and runtime.proxy_owner_by_unit or {}
    runtime.registrations = type(runtime.registrations) == "table" and runtime.registrations or {}
    runtime.due_buckets = scheduler.ensure_delayed_buckets(runtime.due_buckets)
    runtime.due_tick_by_unit = type(runtime.due_tick_by_unit) == "table" and runtime.due_tick_by_unit or {}
    runtime.ready_queue = scheduler.ensure_queue(runtime.ready_queue)
    if tonumber(runtime.ready_queue_count) == nil then
        reconcile_ready_queue_count(runtime)
    end
    runtime.next_due_tick = tonumber(runtime.next_due_tick) or 0
    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.ui_due_buckets = scheduler.ensure_delayed_buckets(runtime.ui_due_buckets)
    runtime.ui_pending_by_player = type(runtime.ui_pending_by_player) == "table" and runtime.ui_pending_by_player or {}
    runtime.next_ui_due_tick = tonumber(runtime.next_ui_due_tick) or 0
    runtime.last_status_tick = tonumber(runtime.last_status_tick) or 0
    runtime.placement_guides = type(runtime.placement_guides) == "table" and runtime.placement_guides or {}
    runtime.placement_guides_by_surface = type(runtime.placement_guides_by_surface) == "table" and runtime.placement_guides_by_surface or {}
    runtime.placement_cursor_intent_by_player = type(runtime.placement_cursor_intent_by_player) == "table" and runtime.placement_cursor_intent_by_player or {}
    if next(runtime.placement_guides) ~= nil and next(runtime.placement_guides_by_surface) == nil then
        for player_index, state in pairs(runtime.placement_guides) do
            if state and state.surface_index then
                add_placement_surface_membership(runtime, player_index, state.surface_index)
            end
        end
    end
    runtime.placement_stale_cleanup_count = tonumber(runtime.placement_stale_cleanup_count) or 0
    runtime.placement_skipped_ungenerated_chunk_count = tonumber(runtime.placement_skipped_ungenerated_chunk_count) or 0
    runtime.placement_dirty_player_skip_count = tonumber(runtime.placement_dirty_player_skip_count) or 0
    runtime.last_tile_change_region_count = tonumber(runtime.last_tile_change_region_count) or 0
    runtime.last_tile_change_dirty_chunk_count = tonumber(runtime.last_tile_change_dirty_chunk_count) or 0
    runtime.last_tile_change_scan_region_count = tonumber(runtime.last_tile_change_scan_region_count) or 0
    runtime.tile_change_region_refresh_count = tonumber(runtime.tile_change_region_refresh_count) or 0
    runtime.ui_stale_bucket_entry_count = tonumber(runtime.ui_stale_bucket_entry_count) or 0
    runtime.last_ui_refresh_player_count = tonumber(runtime.last_ui_refresh_player_count) or 0
    runtime.orphan_telemetry_proxy_cleanup_count = tonumber(runtime.orphan_telemetry_proxy_cleanup_count) or 0
    runtime.due_stale_bucket_entry_count = tonumber(runtime.due_stale_bucket_entry_count) or 0
    runtime.ready_stale_dequeue_count = tonumber(runtime.ready_stale_dequeue_count) or 0
    runtime.due_activation_deferred_count = tonumber(runtime.due_activation_deferred_count) or 0
    runtime.last_due_activation_scanned_count = tonumber(runtime.last_due_activation_scanned_count) or 0
    runtime.last_due_activation_activated_count = tonumber(runtime.last_due_activation_activated_count) or 0
    if runtime.telemetry_proxy_available == nil then
        runtime.telemetry_proxy_available = entity_prototype_exists(TELEMETRY_PROXY_NAME) == true
    end

    return runtime
end

-- Debug status wants stable keys even when no vats are present, so phase and band
-- counters start prefilled rather than appearing only after the first matching
-- record exists.
local function new_phase_counts()
    local counts = {}
    for _, phase_key in ipairs(PHASE_ORDER) do
        counts[phase_key] = 0
    end
    counts["ferment-enriched"] = 0
    counts.invalid = 0
    return counts
end

local function new_band_counts()
    local counts = {unclaimed = 0}
    for _, band_def in ipairs(BAND_DEFS) do
        counts[band_def.key] = 0
    end
    return counts
end

local function get_band_for_size(basin_size)
    basin_size = tonumber(basin_size) or 0
    for _, band_def in ipairs(BAND_DEFS) do
        if basin_size >= band_def.min and basin_size <= band_def.max then
            return band_def
        end
    end
    return nil
end

-- The scheduler stores work in delayed buckets, but control.lua needs one cheap
-- "next wake" number. Recalculating is reserved for the moments where the current
-- frontier may have been removed or consumed.
local function recalculate_next_due_tick(runtime)
    local next_due_tick = 0
    local stale_count = 0
    local compacted_buckets = {}
    for bucket_tick, bucket in pairs(runtime.due_buckets) do
        if bucket_tick > 0 and type(bucket) == "table" then
            local live_bucket = {}
            for _, unit_number in ipairs(bucket) do
                if runtime.due_tick_by_unit[unit_number] == bucket_tick then
                    live_bucket[#live_bucket + 1] = unit_number
                    if next_due_tick == 0 or bucket_tick < next_due_tick then
                        next_due_tick = bucket_tick
                    end
                else
                    stale_count = stale_count + 1
                end
            end
            if #live_bucket > 0 then
                compacted_buckets[bucket_tick] = live_bucket
            end
        end
    end
    runtime.due_buckets = compacted_buckets
    if stale_count > 0 then
        runtime.due_stale_bucket_entry_count = (runtime.due_stale_bucket_entry_count or 0) + stale_count
    end
    runtime.next_due_tick = next_due_tick
    return next_due_tick
end

-- UI refreshes use a separate delayed-bucket spine from vat simulation. A player
-- opening or closing the console should not pull biological phase processing
-- forward, and a busy vat should not rebuild GUI every tick.
local function recalculate_next_ui_due_tick(runtime)
    local next_ui_due_tick = 0
    local stale_count = 0
    local compacted_buckets = {}
    for bucket_tick, bucket in pairs(runtime.ui_due_buckets) do
        if bucket_tick > 0 and type(bucket) == "table" then
            local live_bucket = {}
            for _, player_index in ipairs(bucket) do
                if runtime.ui_pending_by_player[player_index] == bucket_tick then
                    live_bucket[#live_bucket + 1] = player_index
                    if next_ui_due_tick == 0 or bucket_tick < next_ui_due_tick then
                        next_ui_due_tick = bucket_tick
                    end
                else
                    stale_count = stale_count + 1
                end
            end
            if #live_bucket > 0 then
                compacted_buckets[bucket_tick] = live_bucket
            end
        end
    end
    runtime.ui_due_buckets = compacted_buckets
    if stale_count > 0 then
        runtime.ui_stale_bucket_entry_count = (runtime.ui_stale_bucket_entry_count or 0) + stale_count
    end
    runtime.next_ui_due_tick = next_ui_due_tick
    return next_ui_due_tick
end

-- Per-player UI refreshes are coalesced by earliest due tick. Later requests do
-- not replace earlier ones, which lets rapid GUI events collapse into one render
-- without losing the next visible update.
local function queue_ui_refresh_for_player(runtime, player_index, due_tick)
    due_tick = math.max(0, math.floor(tonumber(due_tick) or 0))
    local existing = runtime.ui_pending_by_player[player_index]
    if due_tick <= 0 then
        runtime.ui_pending_by_player[player_index] = nil
        if existing and runtime.next_ui_due_tick == existing then
            recalculate_next_ui_due_tick(runtime)
        end
        return
    end

    if existing and existing <= due_tick then
        return
    end

    runtime.ui_pending_by_player[player_index] = due_tick
    scheduler.delayed_schedule(runtime.ui_due_buckets, due_tick, player_index)
    if runtime.next_ui_due_tick == 0 or due_tick < runtime.next_ui_due_tick then
        runtime.next_ui_due_tick = due_tick
    end
end

-- Unit refreshes fan out only to players with an open vat session. This avoids a
-- global player scan after every phase change while still keeping attached GUI
-- panels fresh.
local function queue_ui_refresh_for_unit(runtime, unit_number, due_tick)
    for player_index, session in pairs(runtime.open_by_player) do
        if session and session.unit_number == unit_number then
            queue_ui_refresh_for_player(runtime, player_index, due_tick)
        end
    end
end

-- Vat wakeups follow the same "authoritative map, lazy stale bucket" pattern used
-- elsewhere in ESIR runtime. The delayed bucket says "maybe due"; due_tick_by_unit
-- says whether that old scheduling decision still counts.
local function queue_vat_due(runtime, unit_number, due_tick)
    due_tick = math.max(0, math.floor(tonumber(due_tick) or 0))
    local previous_due_tick = runtime.due_tick_by_unit[unit_number]
    if due_tick <= 0 then
        remove_ready_unit(runtime, unit_number)
        runtime.due_tick_by_unit[unit_number] = nil
        if previous_due_tick and runtime.next_due_tick == previous_due_tick then
            recalculate_next_due_tick(runtime)
        end
        return
    end

    if previous_due_tick == due_tick then
        if runtime.next_due_tick == 0 or due_tick < runtime.next_due_tick then
            runtime.next_due_tick = due_tick
        end
        return
    end

    if previous_due_tick then
        remove_ready_unit(runtime, unit_number)
    end
    runtime.due_tick_by_unit[unit_number] = due_tick
    scheduler.delayed_schedule(runtime.due_buckets, due_tick, unit_number)
    if runtime.next_due_tick == 0 or due_tick < runtime.next_due_tick then
        runtime.next_due_tick = due_tick
    elseif previous_due_tick and runtime.next_due_tick == previous_due_tick and due_tick > previous_due_tick then
        recalculate_next_due_tick(runtime)
    end
end

-- The vat console is intentionally relative to the assembling-machine GUI. The
-- machine remains the player's real interaction surface; this script only adds a
-- biological status panel beside it.
local function get_gui_root(player)
    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    local root = player.gui.relative[GUI_NAME]
    if root and root.valid then
        return root
    end

    return nil
end

local function destroy_gui_root(player)
    local root = get_gui_root(player)
    if root then
        root.destroy()
    end
end

-- Only an opened vat counts as the authoritative GUI target. Selection is not
-- enough here because the vat already has a native crafting window and we want
-- the panel lifecycle to match that window.
local function get_opened_vat(player)
    local entity = ei_lib.get_valid_entity(player and player.opened)
    if entity and entity.object_name == "LuaEntity" and entity.name == VAT_NAME then
        return entity
    end

    return nil
end

local function set_progressbar_style(element, style_name)
    if element and element.valid and element.style.name ~= style_name then
        element.style = style_name
    end
end

-- Telemetry proxies are hidden combinator-like entities. If no wire is attached,
-- there is no reason to keep writing circuit slots, so proxy output is cleared
-- and the next connected pass can repopulate it.
function wire.entity_has_connections(entity, ignored_owner)
    if not entity_check(entity) then
        return false
    end

    local connectors = wire.get_connectors(entity, false)
    if type(connectors) ~= "table" then
        return false
    end

    for _, connector in pairs(connectors) do
        if connector and connector.valid then
            for _, connection in ipairs(connector.real_connections) do
                local target = connection.target
                if target and target.valid and target.owner ~= ignored_owner then
                    return true
                end
            end
        end
    end

    return false
end

function wire.get_connectors(entity, include_internal)
    if not entity_check(entity) then
        return nil
    end

    local ok, connectors = pcall(entity.get_wire_connectors, include_internal)
    if ok and type(connectors) == "table" then
        return connectors
    end

    ok, connectors = pcall(entity.get_wire_connectors, entity, include_internal)
    if ok and type(connectors) == "table" then
        return connectors
    end

    return nil
end

function wire.connector_targets_match(source, target)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    for _, connection in ipairs(source.real_connections) do
        local target_connection = connection.target
        if target_connection
        and target_connection.valid
        and target_connection.owner == target.owner
        and target_connection.wire_connector_id == target.wire_connector_id then
            return true
        end
    end

    return false
end

function wire.ensure_connector(source, target)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    if wire.connector_targets_match(source, target) then
        return true
    end

    local ok, connected = pcall(source.connect_to, target, false, wire.origin)
    if not ok then
        ok, connected = pcall(source.connect_to, source, target, false, wire.origin)
    end
    return (ok and connected) or wire.connector_targets_match(source, target)
end

function wire.resolve_connector_id(entity, preferred_ids)
    if not entity_check(entity) then
        return nil
    end

    local connectors = wire.get_connectors(entity, true)
    if type(connectors) ~= "table" then
        return nil
    end

    for _, connector_id in ipairs(preferred_ids) do
        local connector = connector_id and connectors[connector_id] or nil
        if connector and connector.valid then
            return connector_id
        end
    end

    return nil
end

-- The player wires the visible vat, while telemetry is produced by a hidden
-- constant-combinator proxy. A script-owned red/green bridge lets both entities
-- share the same circuit network without exposing the proxy as another buildable
-- thing.
function wire.ensure_bridge(entity, proxy)
    if not (entity_check(entity) and entity_check(proxy)) then
        return false
    end

    local proxy_red = wire.resolve_connector_id(proxy, wire.red_connector_ids)
    local proxy_green = wire.resolve_connector_id(proxy, wire.green_connector_ids)
    local entity_red = wire.resolve_connector_id(entity, wire.red_connector_ids)
    local entity_green = wire.resolve_connector_id(entity, wire.green_connector_ids)
    local bridged = false

    if proxy_red and entity_red then
        local source = proxy.get_wire_connector(proxy_red, true)
        local target = entity.get_wire_connector(entity_red, true)
        bridged = wire.ensure_connector(source, target) or bridged
    end

    if proxy_green and entity_green then
        local source = proxy.get_wire_connector(proxy_green, true)
        local target = entity.get_wire_connector(entity_green, true)
        bridged = wire.ensure_connector(source, target) or bridged
    end

    return bridged
end

function wire.ensure_record_bridge(record, entity, proxy)
    if not (record and entity_check(proxy)) then
        return false
    end

    if record.telemetry_bridge_ready == true
    and record.telemetry_bridge_proxy_unit_number == proxy.unit_number then
        return true
    end

    record.telemetry_bridge_ready = wire.ensure_bridge(entity, proxy)
    record.telemetry_bridge_proxy_unit_number = proxy.unit_number
    return record.telemetry_bridge_ready
end

local function clear_proxy_output(proxy)
    if not entity_check(proxy) then
        return
    end

    local control = proxy.get_control_behavior()
    if not (control and control.valid) then
        return
    end

    control.enabled = false

    local section = control.get_section(1)
    if not section then
        return
    end

    for slot_index = 1, tonumber(section.filters_count) or 0 do
        section.clear_slot(slot_index)
    end
end

-- Custom status is the compact player-facing health layer. It gives the entity
-- hover tooltip the same broad state as the GUI without forcing players to open
-- the vat just to notice conflict, strain, starvation, or failure.
local function set_custom_status(entity, diode, label)
    if not entity_check(entity) then
        return
    end

    if not diode or not label then
        entity.custom_status = nil
        return
    end

    entity.custom_status = {
        diode = diode,
        label = label,
    }
end

-- Status priority is ordered from structural impossibility to biological stress.
-- Claim validity beats everything else because an invalid basin cannot honestly
-- report a healthy cycle no matter what its vigor numbers say.
local function get_status_key(record)
    if not record.claim_valid then
        if record.invalid_reason == "conflict" then
            return "conflict"
        end
        if record.invalid_reason == "no-basin"
        or record.invalid_reason == "too-small"
        or record.invalid_reason == "too-large" then
            return "invalid-" .. record.invalid_reason
        end
        return "invalid"
    end

    if record.contamination >= CONTAMINATION_FAILURE_THRESHOLD or record.vigor <= VIGOR_FAILURE_THRESHOLD then
        return "failure"
    end

    if record.blocked_drain_streak > 0 then
        return "blocked-drain"
    end

    if record.starvation_streak > 0 then
        return "starved"
    end

    if record.contamination >= CONTAMINATION_STRAINED_THRESHOLD or record.vigor <= VIGOR_STRAINED_THRESHOLD then
        return "strained"
    end

    if record.phase == "rest" then
        return "resting"
    end

    return "stable"
end

-- The entity status diode is a lossy summary of the detailed record. Red means
-- the basin cannot produce or is already failing, yellow means production can
-- continue but is accruing harm, and green means the current pressure is stable.
local function apply_status_to_entity(record)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        return
    end

    local status_key = get_status_key(record)
    if record.applied_status_key == status_key then
        return
    end

    if status_key == "conflict" then
        set_custom_status(entity, STATUS_RED, get_status_locale("conflict"))
    elseif status_key == "invalid"
    or status_key == "invalid-no-basin"
    or status_key == "invalid-too-small"
    or status_key == "invalid-too-large" then
        set_custom_status(entity, STATUS_RED, get_status_locale(status_key))
    elseif status_key == "failure" then
        set_custom_status(entity, STATUS_RED, get_status_locale("failure"))
    elseif status_key == "blocked-drain" then
        set_custom_status(entity, STATUS_YELLOW, get_status_locale("blocked-drain"))
    elseif status_key == "starved" then
        set_custom_status(entity, STATUS_YELLOW, get_status_locale("starved"))
    elseif status_key == "strained" then
        set_custom_status(entity, STATUS_YELLOW, get_status_locale("strained"))
    elseif status_key == "resting" then
        set_custom_status(entity, STATUS_GREEN, get_status_locale("resting"))
    else
        set_custom_status(entity, STATUS_GREEN, get_status_locale("stable"))
    end
    record.applied_status_key = status_key
end

local function get_band_def(record)
    local band_index = tonumber(record and record.band_index) or 0
    return BAND_DEFS[band_index]
end

-- Recipe introspection is wrapped in pcall because Factorio entity surfaces can
-- be in transitional states during script-built, mined, cloned, or prototype
-- migration paths. A failed read should degrade to nil, not crash the mod.
local function get_recipe_name(entity)
    if not entity_check(entity) then
        return nil
    end

    local ok, recipe = pcall(function()
        return entity.get_recipe()
    end)
    if not ok or not recipe then
        return nil
    end

    return recipe.name
end

local function get_input_inventory(entity)
    if not entity_check(entity) then
        return nil
    end

    local ok, inventory = pcall(function()
        return entity.get_inventory(defines.inventory.assembling_machine_input)
    end)
    if ok then
        return inventory
    end

    return nil
end

local function inventory_item_count(entity, item_name)
    local inventory = get_input_inventory(entity)
    if not inventory then
        return 0
    end

    return inventory.get_item_count(item_name)
end

local function is_recipe_in_progress(entity)
    local ok_progress, progress = pcall(function()
        return entity.crafting_progress or 0
    end)
    if ok_progress and (tonumber(progress) or 0) > 0 then
        return true
    end

    local ok_crafting, crafting = pcall(function()
        return entity.is_crafting()
    end)
    return ok_crafting and crafting == true
end

-- Fermentation has a soft branch. The vat briefly exposes the enriched recipe
-- so inserters can supply bioflux; if none arrives, it falls back to ordinary
-- ferment instead of starving forever on an optional upgrade path.
local function select_phase_key(record, current_tick)
    if record.phase == "ferment-enriched" then
        return "ferment-enriched"
    end

    if record.phase ~= "ferment" then
        return record.phase
    end

    current_tick = tonumber(current_tick) or 0
    local entity = ei_lib.get_valid_entity(record.entity)
    local band_def = get_band_def(record)
    if not (entity and band_def) then
        return "ferment"
    end

    local enriched_recipe_name = "ei-auric-vat-ferment-enriched-" .. band_def.key
    if get_recipe_name(entity) == enriched_recipe_name and is_recipe_in_progress(entity) then
        record.ferment_enrichment_until_tick = nil
        return "ferment-enriched", true
    end

    if inventory_item_count(entity, "bioflux") >= (band_def.enrich_bioflux or 0) then
        record.ferment_enrichment_until_tick = nil
        return "ferment-enriched", true
    end

    local enrichment_until_tick = tonumber(record.ferment_enrichment_until_tick)
    if not enrichment_until_tick then
        enrichment_until_tick = current_tick + FERMENT_ENRICHMENT_WINDOW_TICKS
        record.ferment_enrichment_until_tick = enrichment_until_tick
    end

    if current_tick <= enrichment_until_tick then
        return "ferment-enriched", false
    end

    return "ferment"
end

-- Hidden recipe names encode the runtime decision. Banded phases scale by basin
-- size, and drain is banded too so Factorio owns the runoff output routing.
local function get_phase_recipe_name(record, current_tick)
    local phase_key, lock_phase = select_phase_key(record, current_tick)
    local band_def = get_band_def(record)

    if phase_key == "drain" then
        if not band_def then
            return "ei-auric-vat-drain", phase_key, lock_phase
        end
        if record.pending_acidic_runoff == true then
            return "ei-auric-vat-drain-acidic-" .. band_def.key, phase_key, lock_phase
        end
        return "ei-auric-vat-drain-" .. band_def.key, phase_key, lock_phase
    end

    if phase_key == "bloom" or phase_key == "rest" then
        return "ei-auric-vat-" .. phase_key, phase_key, lock_phase
    end

    if not band_def then
        return nil, phase_key, lock_phase
    end

    return "ei-auric-vat-" .. phase_key .. "-" .. band_def.key, phase_key, lock_phase
end

-- Recipe locking is what turns the visible vat into a guided runtime machine
-- instead of a general assembler. Invalid claims pause the machine by clearing
-- activity; valid claims keep the player-facing recipe synchronized to phase.
local function apply_phase_recipe(record, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        return false
    end

    local recipe_name = nil
    local recipe_active = false
    local phase_key = record.phase
    local lock_phase = false
    if record.claim_valid then
        recipe_name, phase_key, lock_phase = get_phase_recipe_name(record, current_tick)
        if phase_key ~= "ferment-enriched" or lock_phase then
            record.phase = phase_key
        end
        record.active_phase_key = phase_key
        recipe_active = recipe_name ~= nil
    else
        record.active_phase_key = record.phase
    end

    if not recipe_name then
        recipe_name = IDLE_RECIPE_NAME
    end

    local recipe_ready = false
    if recipe_name then
        local current_recipe_name = get_recipe_name(entity)
        if recipe_name == current_recipe_name then
            recipe_ready = true
        else
            local ok = pcall(function()
                return entity.set_recipe(recipe_name)
            end)
            recipe_ready = ok and get_recipe_name(entity) == recipe_name
        end
    end

    record.active_recipe_name = recipe_ready and recipe_name or nil

    local desired_active = recipe_ready
        and recipe_active
        and PHASE_DEFS[record.phase]
        and PHASE_DEFS[record.phase].active == true
        and not (record.phase == "drain" and record.drain_runoff_pending == true)
    if entity.recipe_locked ~= true then
        entity.recipe_locked = true
    end
    local desired_script_disabled = not desired_active
    if entity.disabled_by_script ~= desired_script_disabled then
        entity.disabled_by_script = desired_script_disabled
    end
    return recipe_active and recipe_ready
end

-- Fluidbox access is guarded because this prototype intentionally has sealed
-- internal boxes mixed with player-facing inputs/outputs. Bad indices should
-- fail closed, especially across prototype edits or save migrations.
local function fluidbox_count(entity)
    if not entity_check(entity) or not entity.fluidbox then
        return 0
    end

    local ok, count = pcall(function()
        return #entity.fluidbox
    end)
    if ok then
        return math.max(0, tonumber(count) or 0)
    end

    return 0
end

local function get_fluidbox_contents(entity, index, known_count)
    known_count = known_count or fluidbox_count(entity)
    if not entity_check(entity) or not entity.fluidbox or index < 1 or index > known_count then
        return nil
    end

    local ok, contents = pcall(function()
        return entity.fluidbox[index]
    end)
    if ok then
        return contents
    end

    return nil
end

local function set_fluidbox_contents(entity, index, contents, known_count)
    known_count = known_count or fluidbox_count(entity)
    if not entity_check(entity) or not entity.fluidbox or index < 1 or index > known_count then
        return false
    end

    local ok = pcall(function()
        entity.fluidbox[index] = contents
    end)
    return ok == true
end

local function get_filtered_output_fluidbox_index(entity, fluid_name, known_count)
    if not entity_check(entity) then
        return nil
    end

    known_count = known_count or fluidbox_count(entity)
    local fluidbox_prototypes = entity.prototype and entity.prototype.fluidbox_prototypes
    if not fluidbox_prototypes then
        return nil
    end

    for index = 1, known_count do
        local fluidbox_proto = fluidbox_prototypes[index]
        if fluidbox_proto then
            local production_type = fluidbox_proto.production_type
            local filter = fluidbox_proto.filter
            local filter_name = type(filter) == "string" and filter or filter and filter.name
            if (production_type == "output" or production_type == "input-output") and filter_name == fluid_name then
                return index
            end
        end
    end

    return nil
end

local function fluidbox_has_fluid(entity, index, known_count)
    local contents = get_fluidbox_contents(entity, index, known_count)
    return contents and contents.name and (tonumber(contents.amount) or 0) > 0.001
end

local function drain_outputs_are_clear(record, entity)
    local count = fluidbox_count(entity)
    local dirty_index = get_filtered_output_fluidbox_index(entity, "ei-dirty-water", count)
    local acidic_index = get_filtered_output_fluidbox_index(entity, "ei-acidic-water", count)

    if dirty_index and fluidbox_has_fluid(entity, dirty_index, count) then
        return false
    end
    if acidic_index and fluidbox_has_fluid(entity, acidic_index, count) then
        return false
    end

    return true
end

-- The hidden marker fluid is the phase-completion pulse emitted by every hidden
-- recipe. Fluidbox reads return a plain fluid table, not an inventory stack, so
-- marker detection keys off the fluid name instead of stack.valid_for_read.
local function get_marker_amount(entity)
    if not entity_check(entity) then
        return 0
    end

    local total = 0
    local count = fluidbox_count(entity)
    for index = 1, count do
        local marker = get_fluidbox_contents(entity, index, count)
        if marker and marker.name == MARKER_FLUID_NAME then
            total = total + (marker.amount or 0)
        end
    end

    return total
end

-- Marker clearing must be index-safe. Earlier prototype iterations changed
-- fluidbox layout, so this helper walks only the actual live count and clears
-- marker boxes by name rather than assuming a fixed sealed slot.
local function clear_marker(entity)
    if not entity_check(entity) then
        return
    end

    local count = fluidbox_count(entity)
    for index = 1, count do
        local marker = get_fluidbox_contents(entity, index, count)
        if marker and marker.name == MARKER_FLUID_NAME then
            set_fluidbox_contents(entity, index, nil, count)
        end
    end
end

-- Products-finished is another completion signal, but it is only a backup. The
-- marker fluid remains the cleanest "the hidden recipe fired" channel; this value
-- catches cases where Factorio increments products while marker state was missed.
local function get_products_finished(entity)
    if not entity_check(entity) then
        return 0
    end

    local ok, products_finished = pcall(function()
        return entity.products_finished or 0
    end)
    if ok then
        return math.max(0, tonumber(products_finished) or 0)
    end

    return 0
end

-- Completing a phase consumes any hidden marker and records the new product
-- counter baseline. Without both, a vat could repeatedly advance on one finished
-- craft or leave sealed marker fluid behind for the next phase.
local function consume_phase_completion(record, entity)
    clear_marker(entity)
    if record then
        record.last_products_finished = get_products_finished(entity)
    end
end

-- Object-destroy registrations are the safety net for entities removed outside
-- the normal build/mine handlers. Both vats and hidden telemetry proxies register
-- here so orphaned claims and stale circuit ownership can be cleaned immediately.
local function register_destroy(runtime, entity, kind, unit_number)
    if not entity_check(entity) then
        return nil
    end

    local registration = script.register_on_object_destroyed(entity)
    local position = entity.position
    runtime.registrations[registration] = {
        kind = kind,
        unit_number = unit_number,
        surface_index = entity.surface and entity.surface.index or nil,
        position = position and {x = position.x, y = position.y} or nil,
    }
    return registration
end

local function unregister_destroy(runtime, registration)
    if registration then
        runtime.registrations[registration] = nil
    end
end

-- When a player rewires the invisible proxy, keeping the wired proxy is better
-- than destroying and recreating it. This search prefers connected proxies first
-- and falls back to an unwired one at the vat's position.
local function find_existing_proxy(runtime, entity, owner_unit_number)
    if not entity_check(entity) then
        return nil
    end

    local fallback = nil
    local proxies = entity.surface.find_entities_filtered{
        position = entity.position,
        name = TELEMETRY_PROXY_NAME,
        force = entity.force,
    }

    for _, proxy in ipairs(proxies) do
        if entity_check(proxy) then
            local proxy_owner_unit_number = runtime.proxy_owner_by_unit[proxy.unit_number]
            if proxy_owner_unit_number and proxy_owner_unit_number ~= owner_unit_number then
                goto continue
            end

            if wire.entity_has_connections(proxy, entity) then
                return proxy
            end

            if not fallback then
                fallback = proxy
            end
        end

        ::continue::
    end

    return fallback
end

-- Destroying the proxy is symmetrical with claim release: remove the physical
-- helper, clear its destroy registration, forget reverse ownership, and force
-- the next ensure/update pass to rebuild from the visible vat.
local function destroy_telemetry_proxy(runtime, record)
    local proxy = ei_lib.get_valid_entity(record.telemetry_proxy)
    local proxy_unit_number = record.telemetry_proxy_unit_number or get_unit_number(proxy)
    if proxy then
        proxy.destroy()
    end

    unregister_destroy(runtime, record.telemetry_registration)
    if proxy_unit_number then
        runtime.proxy_owner_by_unit[proxy_unit_number] = nil
    end
    record.telemetry_proxy = nil
    record.telemetry_proxy_unit_number = nil
    record.telemetry_registration = nil
    record.telemetry_bridge_ready = nil
    record.telemetry_bridge_proxy_unit_number = nil
    record.signal_cache = nil
end

-- The telemetry proxy is derived state, not gameplay state. It is recreated or
-- reattached as needed from the visible vat, made non-operable, and registered so
-- script deletion or external removal can be reconciled through on_object_destroyed.
local function ensure_telemetry_proxy(runtime, record)
    if runtime.telemetry_proxy_available == nil then
        runtime.telemetry_proxy_available = entity_prototype_exists(TELEMETRY_PROXY_NAME) == true
    end
    if runtime.telemetry_proxy_available ~= true then
        return nil
    end

    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        return nil
    end

    local proxy = ei_lib.get_valid_entity(record.telemetry_proxy)
    if proxy and proxy.name == TELEMETRY_PROXY_NAME then
        local previous_proxy_unit_number = record.telemetry_proxy_unit_number
        if previous_proxy_unit_number and previous_proxy_unit_number ~= proxy.unit_number then
            runtime.proxy_owner_by_unit[previous_proxy_unit_number] = nil
            unregister_destroy(runtime, record.telemetry_registration)
            record.telemetry_registration = nil
            record.telemetry_bridge_ready = nil
            record.telemetry_bridge_proxy_unit_number = nil
        end
        proxy.destructible = false
        proxy.operable = false
        record.telemetry_proxy = proxy
        record.telemetry_proxy_unit_number = proxy.unit_number
        runtime.proxy_owner_by_unit[proxy.unit_number] = record.unit_number
        if not record.telemetry_registration then
            record.telemetry_registration = register_destroy(runtime, proxy, "proxy", record.unit_number)
        end
        wire.ensure_record_bridge(record, entity, proxy)
        return proxy
    end

    proxy = find_existing_proxy(runtime, entity, record.unit_number)
    if not proxy then
        proxy = entity.surface.create_entity{
            name = TELEMETRY_PROXY_NAME,
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false,
        }
    end

    if not entity_check(proxy) then
        return nil
    end

    proxy.destructible = false
    proxy.operable = false

    record.telemetry_proxy = proxy
    record.telemetry_proxy_unit_number = proxy.unit_number
    runtime.proxy_owner_by_unit[proxy.unit_number] = record.unit_number
    unregister_destroy(runtime, record.telemetry_registration)
    record.telemetry_registration = register_destroy(runtime, proxy, "proxy", record.unit_number)
    record.telemetry_bridge_ready = nil
    record.telemetry_bridge_proxy_unit_number = nil
    wire.ensure_record_bridge(record, entity, proxy)
    return proxy
end

-- Circuit output is write-gated by both connection presence and value cache. Vats
-- with no wires do no combinator work, and wired vats rewrite slots only when a
-- visible signal value actually changed.
local function update_telemetry_proxy(runtime, record)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        record.signal_cache = nil
        return false
    end

    local proxy = ei_lib.get_valid_entity(record.telemetry_proxy)
    if not proxy and not wire.entity_has_connections(entity, nil) then
        unregister_destroy(runtime, record.telemetry_registration)
        if record.telemetry_proxy_unit_number then
            runtime.proxy_owner_by_unit[record.telemetry_proxy_unit_number] = nil
        end
        record.telemetry_proxy = nil
        record.telemetry_proxy_unit_number = nil
        record.telemetry_registration = nil
        record.telemetry_bridge_ready = nil
        record.telemetry_bridge_proxy_unit_number = nil
        if not (record.signal_cache and record.signal_cache.disconnected == true) then
            record.signal_cache = {disconnected = true}
        end
        return false
    end

    proxy = ensure_telemetry_proxy(runtime, record)
    if not entity_check(proxy) then
        record.signal_cache = nil
        return false
    end

    local has_external_wires = wire.entity_has_connections(entity, proxy)
        or wire.entity_has_connections(proxy, entity)
    if not has_external_wires then
        if not (record.signal_cache and record.signal_cache.disconnected == true) then
            clear_proxy_output(proxy)
            record.signal_cache = {disconnected = true}
        end
        return false
    end

    local values = {
        vigor = math.floor(clamp(record.vigor or 0, 0, 100) + 0.5),
        contamination = math.floor(clamp(record.contamination or 0, 0, 100) + 0.5),
        band = math.floor(tonumber(record.band_index) or 0),
        claims = math.floor(tonumber(record.basin_size) or 0),
        bloom = get_bloom_state_value(record),
    }

    local cache = record.signal_cache
    if cache
    and cache.vigor == values.vigor
    and cache.contamination == values.contamination
    and cache.band == values.band
    and cache.claims == values.claims
    and cache.bloom == values.bloom then
        return false
    end

    local control = proxy.get_control_behavior()
    if not (control and control.valid) then
        return false
    end

    control.enabled = true

    local section = control.get_section(1)
    if not section then
        section = control.add_section("auric-inoculation")
    end

    if not section then
        return false
    end

    local filters_count = tonumber(section.filters_count) or 0
    local cold_write = not cache or cache.disconnected == true
    if cold_write then
        for slot_index = 1, filters_count do
            section.clear_slot(slot_index)
        end
    end

    for _, slot_def in ipairs(TELEMETRY_SIGNAL_SLOTS) do
        if (slot_def.slot or 0) <= filters_count then
            local value = values[slot_def.key] or 0
            if cold_write or cache[slot_def.key] ~= value then
                if value ~= 0 then
                    section.set_slot(slot_def.slot, {value = slot_def.signal, min = value})
                else
                    section.clear_slot(slot_def.slot)
                end
            end
        end
    end

    record.signal_cache = values
    return true
end

-- Surface membership lets tile-change events and rebuild/debug paths reason
-- about vats by surface without scanning every tracked record.
local function add_surface_membership(runtime, surface_index, unit_number)
    runtime.units_by_surface[surface_index] = runtime.units_by_surface[surface_index] or {}
    runtime.units_by_surface[surface_index][unit_number] = true
end

local function remove_surface_membership(runtime, surface_index, unit_number)
    local bucket = runtime.units_by_surface[surface_index]
    if not bucket then
        return
    end

    bucket[unit_number] = nil
    if next(bucket) == nil then
        runtime.units_by_surface[surface_index] = nil
    end
end

-- Claim release is deliberately broader than "mark invalid". Tile ownership,
-- band/yield expectations, conflicts, and the current valid flag are all reset
-- together so the next claim pass cannot inherit old basin geometry.
local function release_claim(runtime, record)
    for _, tile in ipairs(record.claim_tiles or {}) do
        local key = get_tile_key(record.surface_index, tile.x, tile.y)
        if runtime.claims_by_tile[key] == record.unit_number then
            runtime.claims_by_tile[key] = nil
        end
    end

    record.claim_tiles = {}
    record.basin_size = 0
    record.band_key = "unclaimed"
    record.band_index = 0
    record.expected_yield = 0
    record.claim_valid = false
    record.claim_conflicts = {}
    record.conflict_tile_count = 0
    record.claim_footprint_signature = ""
end

local function get_claim_footprint_signature(record)
    local tiles = record and record.claim_tiles or nil
    if not tiles or #tiles == 0 then
        return ""
    end

    local keys = {}
    for index, tile in ipairs(tiles) do
        keys[index] = tostring(tile.x or 0) .. ":" .. tostring(tile.y or 0)
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

function model._update_original_basin_tiles(record)
    record.original_basin_tiles = type(record.original_basin_tiles) == "table" and record.original_basin_tiles or {}

    local live_keys = {}
    for _, tile in ipairs(record.claim_tiles or {}) do
        local key = get_tile_key(record.surface_index, tile.x, tile.y)
        live_keys[key] = true
        if record.original_basin_tiles[key] == nil and is_eligible_tile_name(tile.name) then
            record.original_basin_tiles[key] = tile.name
        end
    end

    for key in pairs(record.original_basin_tiles) do
        if not live_keys[key] then
            record.original_basin_tiles[key] = nil
        end
    end
end

-- Basin discovery starts from the nearest eligible wetland tile to the vat, not
-- necessarily the tile under the entity. That supports "firm ground beside marsh"
-- placement while still binding the machine to one adjacent biological patch.
local function find_seed_tile(surface, position)
    local best = nil
    local best_distance = math.huge
    local base_x = math.floor(position.x)
    local base_y = math.floor(position.y)

    local tiles = surface.find_tiles_filtered{
        area = {
            {base_x - BASIN_RADIUS, base_y - BASIN_RADIUS},
            {base_x + BASIN_RADIUS + 1, base_y + BASIN_RADIUS + 1},
        },
        name = ELIGIBLE_TILE_NAMES,
    }

    for _, tile in ipairs(tiles) do
        local tile_position = tile.position
        local x = tile_position.x
        local y = tile_position.y
        local dx = (x + 0.5) - position.x
        local dy = (y + 0.5) - position.y
        local distance_sqr = (dx * dx) + (dy * dy)
        if distance_sqr <= BASIN_RADIUS_SQR then
            if distance_sqr < best_distance
            or (distance_sqr == best_distance and best and (y < best.y or (y == best.y and x < best.x))) then
                best = {x = x, y = y}
                best_distance = distance_sqr
            end
        end
    end

    return best
end

-- The basin flood-fill enforces every placement rule in one pass: radius, four
-- way contiguity, size cap, size floor, and overlap conflicts. Runtime records
-- invalid basins too so the GUI can explain why the vat is idle.
local function discover_basin(runtime, surface, position, unit_number)
    local seed = find_seed_tile(surface, position)
    if not seed then
        return {
            valid = false,
            reason = "no-basin",
            tiles = {},
            conflicts = {},
            conflict_tile_count = 0,
            basin_size = 0,
        }
    end

    local queue = {seed}
    local queue_head = 1
    local seen = {
        [get_tile_key(surface.index, seed.x, seed.y)] = true,
    }
    local tiles = {}
    local conflicts = {}
    local conflict_tile_count = 0

    while queue_head <= #queue do
        local entry = queue[queue_head]
        queue_head = queue_head + 1

        local tile = surface.get_tile(entry.x, entry.y)
        if tile and is_eligible_tile_name(tile.name) then
            tiles[#tiles + 1] = {
                x = entry.x,
                y = entry.y,
                name = tile.name,
            }

            if #tiles > MAX_BASIN_TILES then
                return {
                    valid = false,
                    reason = "too-large",
                    tiles = tiles,
                    conflicts = conflicts,
                    conflict_tile_count = conflict_tile_count,
                    basin_size = #tiles,
                }
            end

            local tile_key = get_tile_key(surface.index, entry.x, entry.y)
            local owner = runtime.claims_by_tile[tile_key]
            if owner and owner ~= unit_number then
                if runtime.vats_by_unit[owner] then
                    conflicts[owner] = true
                    conflict_tile_count = conflict_tile_count + 1
                else
                    runtime.claims_by_tile[tile_key] = nil
                    runtime.orphan_claim_cleanup_count = (runtime.orphan_claim_cleanup_count or 0) + 1
                end
            end

            for _, offset in ipairs(CARDINAL_OFFSETS) do
                local next_x = entry.x + offset.x
                local next_y = entry.y + offset.y
                local key = get_tile_key(surface.index, next_x, next_y)
                if not seen[key] then
                    local dx = (next_x + 0.5) - position.x
                    local dy = (next_y + 0.5) - position.y
                    if (dx * dx) + (dy * dy) <= BASIN_RADIUS_SQR then
                        seen[key] = true
                        queue[#queue + 1] = {x = next_x, y = next_y}
                    end
                end
            end
        end
    end

    if #tiles < MIN_BASIN_TILES then
        return {
            valid = false,
            reason = "too-small",
            tiles = tiles,
            conflicts = conflicts,
            conflict_tile_count = conflict_tile_count,
            basin_size = #tiles,
        }
    end

    if next(conflicts) ~= nil then
        return {
            valid = false,
            reason = "conflict",
            tiles = tiles,
            conflicts = conflicts,
            conflict_tile_count = conflict_tile_count,
            basin_size = #tiles,
        }
    end

    return {
        valid = true,
        reason = nil,
        tiles = tiles,
        conflicts = conflicts,
        conflict_tile_count = conflict_tile_count,
        basin_size = #tiles,
    }
end

-- Refreshing a claim is the hinge between terrain and the recipe cycle. It first
-- drops old ownership, rediscovers the basin, reapplies band state, then either
-- wakes the vat immediately or leaves it inert with an invalid/resting status.
local function refresh_claim(runtime, record, current_tick, queue_immediately)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        return false
    end

    if queue_immediately == nil then
        queue_immediately = true
    end

    release_claim(runtime, record)

    local basin = discover_basin(runtime, entity.surface, entity.position, record.unit_number)
    record.claim_tiles = basin.tiles or {}
    record.basin_size = basin.basin_size or 0
    record.claim_conflicts = basin.conflicts or {}
    record.conflict_tile_count = basin.conflict_tile_count or 0
    record.claim_footprint_signature = get_claim_footprint_signature(record)
    record.claim_valid = basin.valid == true
    record.invalid_reason = basin.reason

    if record.claim_valid then
        for _, tile in ipairs(record.claim_tiles) do
            runtime.claims_by_tile[get_tile_key(record.surface_index, tile.x, tile.y)] = record.unit_number
        end
        model._update_original_basin_tiles(record)

        local band_def = get_band_for_size(record.basin_size)
        if band_def then
            record.band_key = band_def.key
            record.band_index = band_def.index
            record.expected_yield = band_def.node_yield
        else
            record.band_key = "unclaimed"
            record.band_index = 0
            record.expected_yield = 0
        end

        if not PHASE_DEFS[record.phase] or record.phase == "invalid" then
            record.phase = "seed"
            record.phase_progress = 0
            record.phase_started_tick = current_tick
        end

        if queue_immediately then
            queue_vat_due(runtime, record.unit_number, current_tick)
        end
    else
        record.band_key = "unclaimed"
        record.band_index = 0
        record.expected_yield = 0
        record.phase = "rest"
        record.active_phase_key = "rest"
        record.phase_progress = 0
        record.phase_started_tick = current_tick
        record.enriched_bloom = false
        record.ferment_enrichment_until_tick = nil
        record.pending_acidic_runoff = nil
        record.drain_runoff_pending = false
        clear_marker(entity)
        record.last_products_finished = get_products_finished(entity)
        queue_vat_due(runtime, record.unit_number, nil)
    end

    apply_phase_recipe(record, current_tick)
    apply_status_to_entity(record)
    update_telemetry_proxy(runtime, record)
    queue_ui_refresh_for_unit(runtime, record.unit_number, current_tick + UI_REFRESH_DELAY)
    return record.claim_valid
end

-- Snapshots are the only data shape the GUI consumes. Keeping derived values here
-- prevents UI code from re-implementing biological rules and keeps signature
-- comparisons small and deterministic.
local function get_phase_progress_ratio(record)
    local phase_def = PHASE_DEFS[record.phase]
    if not phase_def or phase_def.duration_ticks <= 0 then
        return 0
    end

    return clamp((record.phase_progress or 0) / phase_def.duration_ticks, 0, 1)
end

-- The GUI signature contains only values that change rendered text, bars, or
-- timers. If the signature is unchanged, the scheduled UI refresh can exit
-- without touching the player's element tree.
local function get_signature(snapshot)
    return table.concat({
        tostring(snapshot.unit_number or 0),
        tostring(snapshot.claim_valid and 1 or 0),
        tostring(snapshot.invalid_reason or ""),
        tostring(snapshot.phase or ""),
        tostring(snapshot.band_key or ""),
        tostring(snapshot.basin_size or 0),
        tostring(snapshot.conflict_count or 0),
        tostring(snapshot.conflict_tile_count or 0),
        tostring(snapshot.vigor or 0),
        tostring(snapshot.contamination or 0),
        tostring(snapshot.starvation_streak or 0),
        tostring(snapshot.blocked_drain_streak or 0),
        tostring(snapshot.expected_yield or 0),
        tostring(snapshot.ready_nodes or 0),
        tostring(snapshot.cyst_nodes or 0),
        tostring(snapshot.cyst_capacity or 0),
        tostring(snapshot.dirty_water or 0),
        tostring(snapshot.bloom_state or 0),
        tostring(math.floor((snapshot.phase_progress_ratio or 0) * 1000 + 0.5)),
        tostring(math.floor(snapshot.phase_seconds_remaining or 0)),
        tostring(snapshot.due_tick or 0),
    }, "|")
end

function model._count_cyst_nodes_in_basin(record, entity)
    entity = entity or ei_lib.get_valid_entity(record and record.entity)
    if not (entity and record and record.claim_tiles and #record.claim_tiles > 0) then
        return 0, {}
    end

    local left_top = {x = math.huge, y = math.huge}
    local right_bottom = {x = -math.huge, y = -math.huge}
    local claimed_tile_keys = {}
    for _, tile in ipairs(record.claim_tiles) do
        claimed_tile_keys[get_tile_key(record.surface_index, tile.x, tile.y)] = true
        if tile.x < left_top.x then left_top.x = tile.x end
        if tile.y < left_top.y then left_top.y = tile.y end
        if tile.x + 1 > right_bottom.x then right_bottom.x = tile.x + 1 end
        if tile.y + 1 > right_bottom.y then right_bottom.y = tile.y + 1 end
    end

    local existing_nodes = {}
    local existing_basin_nodes = 0
    for _, node in ipairs(entity.surface.find_entities_filtered{area = {left_top, right_bottom}, name = CYST_NODE_NAME}) do
        if entity_check(node) then
            local tile_key = get_tile_key(record.surface_index, math.floor(node.position.x), math.floor(node.position.y))
            existing_nodes[tile_key] = true
            if claimed_tile_keys[tile_key] then
                existing_basin_nodes = existing_basin_nodes + 1
            end
        end
    end

    return existing_basin_nodes, existing_nodes
end

function model._get_claim_signature(snapshot)
    if not snapshot then
        return ""
    end

    return table.concat({
        tostring(snapshot.claim_valid and 1 or 0),
        tostring(snapshot.invalid_reason or ""),
        tostring(snapshot.basin_size or 0),
        tostring(snapshot.conflict_count or 0),
        tostring(snapshot.conflict_tile_count or 0),
        tostring(snapshot.band_index or 0),
        tostring(snapshot.claim_footprint_signature or ""),
    }, "|")
end

-- Snapshot construction is intentionally read-only. It freezes the record into
-- rounded, locale-friendly, UI-safe values while leaving all phase mutation in
-- process_due_vat().
local function build_snapshot(runtime, record, current_tick)
    current_tick = tonumber(current_tick) or 0
    local phase_def = PHASE_DEFS[record.phase] or PHASE_DEFS.rest
    local due_tick = math.max(0, math.floor(tonumber(runtime and runtime.due_tick_by_unit and runtime.due_tick_by_unit[record.unit_number]) or 0))
    local band_def = get_band_def(record)
    local display_phase = record.active_phase_key or record.phase
    local expected_yield = record.expected_yield or 0
    if band_def and (record.enriched_bloom or record.phase == "ferment-enriched") then
        expected_yield = math.min(6, expected_yield + (band_def.enrich_bonus or 0))
    end
    local cyst_nodes = model._count_cyst_nodes_in_basin(record)
    local snapshot = {
        unit_number = record.unit_number,
        phase = display_phase,
        phase_index = PHASE_INDEX[display_phase] or 0,
        phase_progress_ratio = get_phase_progress_ratio(record),
        phase_seconds_remaining = math.max(0, phase_def.duration_ticks - (record.phase_progress or 0)) / 60,
        basin_size = record.basin_size or 0,
        band_key = record.band_key or "unclaimed",
        band_index = record.band_index or 0,
        expected_yield = expected_yield,
        ready_nodes = record.ready_nodes or 0,
        cyst_nodes = cyst_nodes or 0,
        cyst_capacity = band_def and band_def.cyst_capacity or 0,
        dirty_water = band_def and band_def.dirty_water or 0,
        bloom_state = get_bloom_state_value(record),
        vigor = math.floor(clamp(record.vigor or 0, 0, 100) + 0.5),
        contamination = math.floor(clamp(record.contamination or 0, 0, 100) + 0.5),
        claim_valid = record.claim_valid == true,
        invalid_reason = record.invalid_reason,
        starvation_streak = record.starvation_streak or 0,
        blocked_drain_streak = record.blocked_drain_streak or 0,
        due_tick = due_tick,
        due_in_seconds = math.max(0, due_tick - current_tick) / 60,
        status_key = get_status_key(record),
        conflict_count = scheduler.table_count(record.claim_conflicts),
        conflict_tile_count = record.conflict_tile_count or 0,
        claim_footprint_signature = record.claim_footprint_signature or "",
    }

    snapshot.signature = get_signature(snapshot)
    return snapshot
end

-- Most vat lines can wrap because localization and rich status text are longer
-- than the English keys suggest. This tiny builder keeps the panel stable across
-- all seven locale files.
local function add_wrapped_label(parent, name)
    local label = parent.add{
        type = "label",
        name = name,
        style = "caption_label",
    }
    label.style.single_line = false
    label.style.horizontally_stretchable = true
    label.style.maximal_width = 356
    return label
end

-- The panel is built once per opened vat session and then updated by signature.
-- It intentionally shows basin, cycle, and pressure as separate sections because
-- those are the three levers a player can diagnose: placement, recipe progress,
-- and biological damage.
local function build_gui(player)
    destroy_gui_root(player)

    if not (player and player.valid and player.gui and player.gui.relative) then
        return nil
    end

    local ok, root = pcall(function()
        return player.gui.relative.add{
            type = "frame",
            name = GUI_NAME,
            anchor = {
                gui = defines.relative_gui_type.assembling_machine_gui,
                name = VAT_NAME,
                position = defines.relative_gui_position.right,
            },
            direction = "vertical",
            tags = {
                parent_gui = GUI_NAME,
                gui_mode = "relative",
            },
        }
    end)

    if not ok or not (root and root.valid) then
        return nil
    end

    root.style.minimal_width = 380
    root.style.maximal_width = 380

    local titlebar = root.add{type = "flow", name = "titlebar", direction = "horizontal"}
    local title_label = titlebar.add{
        type = "label",
        caption = {"exotic-industries.auric-inoculation-vat-gui-title"},
        style = "frame_title",
    }
    title_label.style.single_line = false
    title_label.style.maximal_width = 302
    titlebar.add{
        type = "empty-widget",
        style = "ei_titlebar_nondraggable_spacer",
        ignored_by_interaction = true,
    }
    titlebar.add{
        type = "sprite-button",
        name = "informatron-button",
        sprite = "virtual-signal/informatron",
        tooltip = {"exotic-industries.auric-inoculation-vat-gui-open-informatron"},
        style = "frame_action_button",
        tags = {
            parent_gui = GUI_NAME,
            action = "goto-informatron",
            page = INFORMATRON_PAGE,
        },
    }

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }
    main_container.style.minimal_width = 380
    main_container.style.maximal_width = 380

    main_container.add{type = "frame", style = "ei_subheader_frame"}.add{
        type = "label",
        caption = {"exotic-industries.auric-inoculation-vat-gui-claims-title"},
        style = "subheader_caption_label",
    }

    local basin_flow = main_container.add{
        type = "flow",
        name = "basin-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    basin_flow.style.vertical_spacing = 4
    add_wrapped_label(basin_flow, "cyst-count-line")
    add_wrapped_label(basin_flow, "basin-line")
    add_wrapped_label(basin_flow, "basin-detail-line")
    add_wrapped_label(basin_flow, "status-line")
    add_wrapped_label(basin_flow, "telemetry-line")
    add_wrapped_label(basin_flow, "bloom-line")

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.auric-inoculation-vat-gui-cycle-title"},
        style = "subheader_caption_label",
    }

    local cycle_flow = main_container.add{
        type = "flow",
        name = "cycle-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    cycle_flow.style.vertical_spacing = 6
    add_wrapped_label(cycle_flow, "phase-line")
    cycle_flow.add{
        type = "progressbar",
        name = "phase-bar",
        style = "ei_status_progressbar_cyan",
    }
    add_wrapped_label(cycle_flow, "vigor-line")
    cycle_flow.add{
        type = "progressbar",
        name = "vigor-bar",
        style = "ei_status_progressbar_cyan",
    }
    add_wrapped_label(cycle_flow, "contamination-line")
    cycle_flow.add{
        type = "progressbar",
        name = "contamination-bar",
        style = "ei_status_progressbar_purple",
    }
    add_wrapped_label(cycle_flow, "timer-line")

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.auric-inoculation-vat-gui-status-title"},
        style = "subheader_caption_label",
    }

    local pressure_flow = main_container.add{
        type = "flow",
        name = "pressure-flow",
        direction = "vertical",
        style = "ei_inner_content_flow",
    }
    pressure_flow.style.vertical_spacing = 4
    add_wrapped_label(pressure_flow, "starvation-line")
    add_wrapped_label(pressure_flow, "drain-line")
    add_wrapped_label(pressure_flow, "runoff-line")

    local button_flow = main_container.add{
        type = "flow",
        name = "button-flow",
        direction = "horizontal",
        style = "ei_inner_content_flow_horizontal",
    }
    button_flow.style.horizontal_spacing = 8
    button_flow.add{
        type = "button",
        name = "refresh-claim-button",
        caption = {"exotic-industries.auric-inoculation-vat-gui-refresh-basin"},
        tooltip = {"exotic-industries.auric-inoculation-vat-gui-refresh-basin-tooltip"},
        tags = {
            parent_gui = GUI_NAME,
            action = "refresh-claim",
        },
    }

    local feedback_line = add_wrapped_label(main_container, "feedback-line")
    feedback_line.visible = false

    return root
end

local function get_invalid_basin_detail_locale(snapshot)
    local invalid_reason = snapshot and snapshot.invalid_reason
    if invalid_reason == "no-basin" then
        return {"exotic-industries.auric-inoculation-vat-gui-basin-no-basin-detail", BASIN_RADIUS}
    end
    if invalid_reason == "too-small" then
        return {
            "exotic-industries.auric-inoculation-vat-gui-basin-too-small-detail",
            snapshot.basin_size or 0,
            MIN_BASIN_TILES,
        }
    end
    if invalid_reason == "too-large" then
        return {
            "exotic-industries.auric-inoculation-vat-gui-basin-too-large-detail",
            snapshot.basin_size or 0,
            MAX_BASIN_TILES,
        }
    end
    if invalid_reason == "conflict" then
        return {
            "exotic-industries.auric-inoculation-vat-gui-basin-conflict-detail",
            snapshot.conflict_tile_count or 0,
            snapshot.conflict_count or 0,
        }
    end

    return {
        "exotic-industries.auric-inoculation-vat-gui-basin-invalid-detail",
        snapshot and snapshot.basin_size or 0,
        MIN_BASIN_TILES,
        MAX_BASIN_TILES,
    }
end

-- GUI mutation is centralized here so event handlers only establish sessions.
-- All labels consume snapshot fields, not live records, which keeps rendering
-- side-effect free and safe to call after a delayed UI wake.
local function update_gui(player, snapshot)
    if not (player and player.valid and snapshot) then
        return false
    end

    local root = nil
    local main_container = nil
    local basin_flow = nil
    local cycle_flow = nil
    local pressure_flow = nil
    local titlebar = nil
    local button_flow = nil
    local rebuilt = false
    while true do
        root = get_gui_root(player) or build_gui(player)
        titlebar = root and root["titlebar"] or nil
        main_container = root and root["main-container"] or nil
        basin_flow = main_container and main_container["basin-flow"] or nil
        cycle_flow = main_container and main_container["cycle-flow"] or nil
        pressure_flow = main_container and main_container["pressure-flow"] or nil
        button_flow = main_container and main_container["button-flow"] or nil
        if root and main_container and basin_flow and cycle_flow and pressure_flow
        and titlebar and titlebar["informatron-button"]
        and basin_flow["basin-line"] and basin_flow["basin-detail-line"] and basin_flow["status-line"]
        and basin_flow["cyst-count-line"] and basin_flow["telemetry-line"] and basin_flow["bloom-line"]
        and cycle_flow["phase-line"] and cycle_flow["phase-bar"] and cycle_flow["timer-line"]
        and cycle_flow["vigor-line"] and cycle_flow["vigor-bar"]
        and cycle_flow["contamination-line"] and cycle_flow["contamination-bar"]
        and pressure_flow["starvation-line"] and pressure_flow["drain-line"] and pressure_flow["runoff-line"]
        and button_flow and button_flow["refresh-claim-button"] and main_container["feedback-line"] then
            break
        end

        if rebuilt then
            return false
        end

        destroy_gui_root(player)
        rebuilt = true
    end

    if snapshot.claim_valid then
        basin_flow["cyst-count-line"].caption = {
            "exotic-industries.auric-inoculation-vat-gui-basin-cyst-count",
            snapshot.cyst_nodes or 0,
            snapshot.cyst_capacity or 0,
        }
        basin_flow["basin-line"].caption = {
            "",
            {"exotic-industries.auric-inoculation-vat-gui-band", snapshot.band_index or 0},
            "  ",
            {"exotic-industries.auric-inoculation-vat-gui-claimed-nodes", snapshot.basin_size or 0},
        }
    else
        basin_flow["cyst-count-line"].caption = {
            "exotic-industries.auric-inoculation-vat-gui-basin-cyst-count",
            0,
            0,
        }
        basin_flow["basin-line"].caption = get_status_locale(snapshot.status_key)
    end

    local basin_detail_line = basin_flow["basin-detail-line"]
    if basin_detail_line then
        if snapshot.claim_valid then
            basin_detail_line.visible = false
            basin_detail_line.caption = ""
        else
            basin_detail_line.visible = true
            basin_detail_line.caption = get_invalid_basin_detail_locale(snapshot)
        end
    end

    if (snapshot.conflict_count or 0) > 0
    and (snapshot.status_key == "conflict" or snapshot.invalid_reason == "conflict") then
        basin_flow["status-line"].caption = {
            "exotic-industries.auric-inoculation-vat-gui-status-line-conflicts",
            get_status_locale(snapshot.status_key),
            snapshot.conflict_count or 0,
        }
    else
        basin_flow["status-line"].caption = {
            "exotic-industries.auric-inoculation-vat-gui-status-line",
            get_status_locale(snapshot.status_key),
        }
    end
    basin_flow["telemetry-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-cysts",
        tostring(snapshot.ready_nodes or 0) .. "/" .. tostring(snapshot.expected_yield or 0),
    }
    basin_flow["bloom-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-bloom",
        get_bloom_state_locale(snapshot.bloom_state),
    }

    cycle_flow["phase-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-phase-line",
        get_phase_locale(snapshot.phase),
    }

    local phase_bar = cycle_flow["phase-bar"]
    phase_bar.value = snapshot.phase_progress_ratio or 0
    phase_bar.caption = "~" .. tostring(math.floor(((snapshot.phase_progress_ratio or 0) * 100) + 0.5)) .. "%"
    phase_bar.tooltip = {
        "exotic-industries.auric-inoculation-vat-gui-phase-tooltip",
        seconds_text((snapshot.phase_seconds_remaining or 0) * 60),
    }

    local vigor_bar = cycle_flow["vigor-bar"]
    local vigor_line = cycle_flow["vigor-line"]
    if vigor_line then
        vigor_line.caption = {"exotic-industries.auric-inoculation-vat-gui-vigor", snapshot.vigor or 0}
    end
    set_progressbar_style(vigor_bar, (snapshot.vigor or 0) <= VIGOR_STRAINED_THRESHOLD and "ei_status_progressbar_purple" or "ei_status_progressbar_cyan")
    vigor_bar.value = clamp((snapshot.vigor or 0) / 100, 0, 1)
    vigor_bar.caption = tostring(snapshot.vigor or 0) .. "%"
    vigor_bar.tooltip = {
        "exotic-industries.auric-inoculation-vat-gui-vigor-tooltip",
        VIGOR_STRAINED_THRESHOLD,
        VIGOR_FAILURE_THRESHOLD,
    }

    local contamination_bar = cycle_flow["contamination-bar"]
    local contamination_line = cycle_flow["contamination-line"]
    if contamination_line then
        contamination_line.caption = {"exotic-industries.auric-inoculation-vat-gui-contamination", snapshot.contamination or 0}
    end
    set_progressbar_style(contamination_bar, (snapshot.contamination or 0) >= CONTAMINATION_STRAINED_THRESHOLD and "ei_status_progressbar_red" or "ei_status_progressbar_purple")
    contamination_bar.value = clamp((snapshot.contamination or 0) / 100, 0, 1)
    contamination_bar.caption = tostring(snapshot.contamination or 0) .. "%"
    contamination_bar.tooltip = {
        "exotic-industries.auric-inoculation-vat-gui-contamination-tooltip",
        CONTAMINATION_STRAINED_THRESHOLD,
        CONTAMINATION_FAILURE_THRESHOLD,
    }

    if (snapshot.due_tick or 0) > 0 then
        cycle_flow["timer-line"].caption = {
            "exotic-industries.auric-inoculation-vat-gui-next-wake",
            string.format("%.1f", snapshot.due_in_seconds or 0),
        }
    else
        cycle_flow["timer-line"].caption = {"exotic-industries.auric-inoculation-vat-gui-not-scheduled"}
    end

    pressure_flow["starvation-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-starvation-streak",
        snapshot.starvation_streak or 0,
    }
    pressure_flow["drain-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-blocked-drain-streak",
        snapshot.blocked_drain_streak or 0,
    }
    pressure_flow["runoff-line"].caption = {
        "exotic-industries.auric-inoculation-vat-gui-dirty-water",
        snapshot.dirty_water or 0,
    }

    local feedback_line = main_container["feedback-line"]
    if feedback_line then
        feedback_line.caption = ""
        feedback_line.visible = false
    end
    return true
end

local function set_gui_feedback(player, caption, kind)
    local root = get_gui_root(player)
    local main_container = root and root["main-container"] or nil
    local feedback_line = main_container and main_container["feedback-line"] or nil
    if not feedback_line then
        return
    end

    feedback_line.caption = caption or ""
    feedback_line.visible = caption ~= nil and caption ~= ""
    if kind == "valid" then
        feedback_line.style.font_color = {r = 0.30, g = 0.95, b = 0.44}
    elseif kind == "invalid" then
        feedback_line.style.font_color = {r = 1.00, g = 0.34, b = 0.28}
    elseif kind == "unchanged" then
        feedback_line.style.font_color = {r = 1.00, g = 0.78, b = 0.25}
    else
        feedback_line.style.font_color = {r = 0.90, g = 0.90, b = 0.90}
    end
end

-- One delayed UI wake services one player session. If the player closed the
-- underlying vat, the session is removed; if the snapshot signature is unchanged,
-- the existing relative GUI is left untouched.
local function refresh_player_gui(runtime, player_index, current_tick)
    local player = game and game.get_player(player_index) or nil
    local session = runtime.open_by_player[player_index]
    if not session then
        return
    end

    local entity = get_opened_vat(player)
    local opened_unit_number = get_unit_number(entity)
    if not (player and player.valid) or opened_unit_number ~= session.unit_number then
        runtime.open_by_player[player_index] = nil
        runtime.ui_pending_by_player[player_index] = nil
        if player and player.valid then
            destroy_gui_root(player)
        end
        return
    end

    local record = runtime.vats_by_unit[session.unit_number]
    if not record or not entity_check(record.entity) then
        runtime.open_by_player[player_index] = nil
        runtime.ui_pending_by_player[player_index] = nil
        destroy_gui_root(player)
        return
    end

    local snapshot = build_snapshot(runtime, record, current_tick)
    local signature_changed = session.last_signature ~= snapshot.signature or not get_gui_root(player)
    local feedback_is_live = session.manual_feedback_until_tick
        and current_tick < session.manual_feedback_until_tick
        and session.manual_feedback_caption ~= nil
    if signature_changed then
        if not update_gui(player, snapshot) then
            runtime.open_by_player[player_index] = nil
            runtime.ui_pending_by_player[player_index] = nil
            destroy_gui_root(player)
            return
        end
        session.last_signature = snapshot.signature
        if feedback_is_live then
            set_gui_feedback(player, session.manual_feedback_caption, session.manual_feedback_kind)
        else
            session.manual_feedback_until_tick = nil
            session.manual_feedback_caption = nil
            session.manual_feedback_kind = nil
        end
    elseif session.manual_feedback_until_tick and current_tick >= session.manual_feedback_until_tick then
        set_gui_feedback(player, nil)
        session.manual_feedback_until_tick = nil
        session.manual_feedback_caption = nil
        session.manual_feedback_kind = nil
    end

    runtime.ui_pending_by_player[player_index] = nil
    if session.manual_feedback_until_tick and session.manual_feedback_until_tick > current_tick then
        queue_ui_refresh_for_player(runtime, player_index, session.manual_feedback_until_tick)
    end
end

-- Unit teardown closes every panel watching that unit. This prevents a destroyed
-- vat from leaving behind a relative GUI whose tags still look plausible but no
-- longer point to a live record.
local function close_sessions_for_unit(runtime, unit_number)
    local removed_session = false
    for player_index, session in pairs(runtime.open_by_player) do
        if session and session.unit_number == unit_number then
            runtime.open_by_player[player_index] = nil
            runtime.ui_pending_by_player[player_index] = nil
            removed_session = true
            local player = game and game.get_player(player_index) or nil
            if player and player.valid then
                destroy_gui_root(player)
            end
        end
    end

    if removed_session then
        recalculate_next_ui_due_tick(runtime)
    end
end

local function destroy_open_gui_roots(runtime)
    if not runtime then
        return
    end

    if type(runtime.open_by_player) == "table" then
        for player_index in pairs(runtime.open_by_player) do
            local player = game and game.get_player(player_index) or nil
            if player and player.valid then
                destroy_gui_root(player)
            end
        end
    end

    for _, player in pairs(game and game.connected_players or {}) do
        destroy_gui_root(player)
    end
end

-- Unregistration is the reverse of register_vat(): destroy registration, wakeup,
-- basin claim, telemetry proxy, surface membership, UI sessions, and record all
-- disappear as one transaction.
local function unregister_vat(runtime, unit_number)
    local record = runtime.vats_by_unit[unit_number]
    if not record then
        return
    end

    unregister_destroy(runtime, record.destroy_registration)
    record.destroy_registration = nil
    queue_vat_due(runtime, unit_number, nil)
    release_claim(runtime, record)
    destroy_telemetry_proxy(runtime, record)
    remove_surface_membership(runtime, record.surface_index, unit_number)
    close_sessions_for_unit(runtime, unit_number)
    apply_status_to_entity(record)
    runtime.vats_by_unit[unit_number] = nil
end

-- Registration is idempotent for a visible vat unit. It creates or refreshes the
-- durable record, optionally carries biological state across rebuilds, binds the
-- visible entity, clears stale marker fluid, and immediately reclaims terrain.
local function register_vat(runtime, entity, current_tick, carried_state)
    local unit_number = get_unit_number(entity)
    if not unit_number then
        return nil
    end

    local record = runtime.vats_by_unit[unit_number]
    local old_registration = record and record.destroy_registration or nil
    if not record then
        record = {
            unit_number = unit_number,
            vigor = 100,
            contamination = 0,
            phase = "seed",
            active_phase_key = "seed",
            phase_progress = 0,
            phase_started_tick = current_tick,
            last_tick = current_tick,
            claim_tiles = {},
            original_basin_tiles = {},
            claim_conflicts = {},
            claim_valid = false,
            invalid_reason = "no-basin",
            claim_footprint_signature = "",
            basin_size = 0,
            band_key = "unclaimed",
            band_index = 0,
            expected_yield = 0,
            conflict_tile_count = 0,
            starvation_streak = 0,
            blocked_drain_streak = 0,
            completed_cycles = 0,
            successful_bloom_streak = 0,
            ready_nodes = 0,
            enriched_bloom = false,
            ferment_enrichment_until_tick = nil,
            pending_acidic_runoff = nil,
            drain_runoff_pending = false,
            active_recipe_name = nil,
            last_products_finished = 0,
            signal_cache = nil,
            last_starvation_penalty_tick = current_tick,
            last_blocked_drain_penalty_tick = current_tick,
        }
        runtime.vats_by_unit[unit_number] = record
    end

    if carried_state then
        record.vigor = clamp(carried_state.vigor or record.vigor, 0, 100)
        record.contamination = clamp(carried_state.contamination or record.contamination, 0, 100)
        record.phase = carried_state.phase or record.phase
        if PHASE_DEFS[carried_state.active_phase_key] then
            record.active_phase_key = carried_state.active_phase_key
        end
        record.phase_progress = math.max(0, math.floor(tonumber(carried_state.phase_progress) or record.phase_progress or 0))
        record.phase_started_tick = tonumber(carried_state.phase_started_tick) or record.phase_started_tick
        record.last_tick = tonumber(carried_state.last_tick) or record.last_tick
        record.starvation_streak = tonumber(carried_state.starvation_streak) or record.starvation_streak
        record.blocked_drain_streak = tonumber(carried_state.blocked_drain_streak) or record.blocked_drain_streak
        record.completed_cycles = tonumber(carried_state.completed_cycles) or record.completed_cycles
        record.successful_bloom_streak = tonumber(carried_state.successful_bloom_streak) or record.successful_bloom_streak
        record.ready_nodes = tonumber(carried_state.ready_nodes) or record.ready_nodes
        if type(carried_state.original_basin_tiles) == "table" then
            record.original_basin_tiles = carried_state.original_basin_tiles
        end
        record.enriched_bloom = carried_state.enriched_bloom == true
        record.ferment_enrichment_until_tick = tonumber(carried_state.ferment_enrichment_until_tick)
        record.pending_acidic_runoff = carried_state.pending_acidic_runoff
        record.drain_runoff_pending = carried_state.drain_runoff_pending == true
        record.last_products_finished = tonumber(carried_state.last_products_finished) or record.last_products_finished
        record.last_starvation_penalty_tick = tonumber(carried_state.last_starvation_penalty_tick) or record.last_starvation_penalty_tick
        record.last_blocked_drain_penalty_tick = tonumber(carried_state.last_blocked_drain_penalty_tick) or record.last_blocked_drain_penalty_tick
    end

    record.entity = entity
    local new_surface_index = entity.surface.index
    local old_surface_index = record.surface_index
    if old_surface_index and old_surface_index ~= new_surface_index then
        release_claim(runtime, record)
        remove_surface_membership(runtime, old_surface_index, unit_number)
        destroy_telemetry_proxy(runtime, record)
    end

    record.surface_index = new_surface_index
    record.position = {x = entity.position.x, y = entity.position.y}
    record.last_tick = current_tick
    if not carried_state then
        record.last_products_finished = get_products_finished(entity)
        clear_marker(entity)
    end
    record.applied_status_key = nil

    add_surface_membership(runtime, record.surface_index, unit_number)
    unregister_destroy(runtime, old_registration)
    record.destroy_registration = register_destroy(runtime, entity, "vat", unit_number)
    refresh_claim(runtime, record, current_tick, true)
    return record
end

-- Failure tile selection is deterministic from tile position, unit, and tick.
-- That gives each failure an organic scatter without storing random state or
-- depending on global RNG sequence.
local function failure_roll(tile, unit_number, current_tick)
    local x = tonumber(tile.x) or 0
    local y = tonumber(tile.y) or 0
    local seed = (x * 73856093) + (y * 19349663) + ((tonumber(unit_number) or 0) * 83492791) + (tonumber(current_tick) or 0)
    local normalized = math.abs(seed) % 100
    return normalized < FAILURE_TILE_DOWNGRADE_PERCENT
end

function model._recovery_roll(tile, unit_number, current_tick)
    local x = tonumber(tile.x) or 0
    local y = tonumber(tile.y) or 0
    local seed = (x * 19349663) + (y * 73856093) + ((tonumber(unit_number) or 0) * 2654435761) + (tonumber(current_tick) or 0)
    local normalized = math.abs(seed) % 100
    return normalized < (model.BASIN_RESTORE_TILE_PERCENT or 0)
end

-- A failed bloom or ruptured basin leaves terrain evidence. Only a percentage of
-- claimed tiles downgrade, making the wound readable without instantly erasing
-- the whole wetland patch.
local function apply_failure_downgrade(runtime, record, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        return
    end

    local tiles = {}
    for _, tile in ipairs(record.claim_tiles or {}) do
        local downgrade_name = get_downgraded_tile_name(tile.name)
        if downgrade_name and downgrade_name ~= tile.name and failure_roll(tile, record.unit_number, current_tick) then
            tiles[#tiles + 1] = {
                name = downgrade_name,
                position = {x = tile.x, y = tile.y},
            }
        end
    end

    if #tiles > 0 then
        entity.surface.set_tiles(tiles, true, false)
    end
end

-- Successful blooms can heal scars, but only toward the tile each basin first
-- claimed. That keeps recovery from bleaching every long-running basin into one
-- idealized wetland type.
function model._apply_success_recovery(runtime, record, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity or type(record.original_basin_tiles) ~= "table" then
        return 0
    end

    local tiles = {}
    for _, tile in ipairs(record.claim_tiles or {}) do
        local key = get_tile_key(record.surface_index, tile.x, tile.y)
        local original_name = record.original_basin_tiles[key]
        local current_tile = entity.surface.get_tile(tile.x, tile.y)
        local current_name = current_tile and current_tile.name or tile.name
        local recovered_name = model._get_recovered_tile_name(current_name, original_name)
        if recovered_name and model._recovery_roll(tile, record.unit_number, current_tick) then
            tiles[#tiles + 1] = {
                name = recovered_name,
                position = {x = tile.x, y = tile.y},
            }
        end
    end

    if #tiles <= 0 then
        return 0
    end

    entity.surface.set_tiles(tiles, true, false)
    refresh_claim(runtime, record, current_tick, false)
    return #tiles
end

-- Acidic-water runoff is chance-based but deterministic per cycle. It adds risk
-- and recapture value to the drain phase without requiring another persistent
-- counter in the vat record.
local function acid_roll(record, current_tick)
    local seed = ((record.unit_number or 0) * 1103515245) + ((record.completed_cycles or 0) * 97) + (current_tick or 0)
    return (math.abs(seed) % 100) < 35
end

local function get_crafting_progress(entity)
    if not entity_check(entity) then
        return 0
    end

    local ok, progress = pcall(function()
        return entity.crafting_progress or 0
    end)
    if ok then
        return clamp(progress, 0, 1)
    end

    return 0
end

-- Cyst nodes are spawned into the world rather than returned by the assembler.
-- This keeps the reward Gleban and lets agriculture towers harvest the bloom as
-- living output instead of a normal craft result.
function model._play_cyst_spawn_effect(surface, position)
    if not (surface and surface.valid and position) then
        return
    end

    local ttl = model.CYST_SPAWN_EFFECT_TICKS or 42
    pcall(function()
        rendering.draw_circle{
            surface = surface,
            target = position,
            radius = 0.42,
            width = 3,
            color = {r = 0.95, g = 0.66, b = 0.18, a = 0.72},
            filled = false,
            draw_on_ground = true,
            time_to_live = ttl,
        }
    end)
    pcall(function()
        rendering.draw_circle{
            surface = surface,
            target = position,
            radius = 0.24,
            color = {r = 0.20, g = 0.90, b = 0.74, a = 0.22},
            filled = true,
            draw_on_ground = true,
            time_to_live = math.max(12, math.floor(ttl * 0.65)),
        }
    end)
    pcall(function()
        rendering.draw_light{
            sprite = "utility/light_medium",
            surface = surface,
            target = position,
            color = {r = 1.0, g = 0.62, b = 0.18},
            intensity = 0.75,
            scale = 1.15,
            time_to_live = math.max(12, math.floor(ttl * 0.7)),
        }
    end)
    pcall(function()
        surface.create_trivial_smoke{
            name = "water-splash",
            position = position,
            starting_frame_deviation = 12,
        }
    end)
end

-- Node placement walks the claimed basin with a deterministic offset so repeated
-- cycles distribute cysts around the marsh instead of always filling the first
-- tiles in flood-fill order.
local function spawn_cyst_nodes(record, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    local band_def = get_band_def(record)
    if not (entity and band_def and record.claim_tiles and #record.claim_tiles > 0) then
        record.ready_nodes = 0
        return 0
    end

    local target = math.min(6, (band_def.node_yield or 0) + (record.enriched_bloom and (band_def.enrich_bonus or 0) or 0))
    local spawned = 0
    local tile_count = #record.claim_tiles
    local offset_seed = ((record.completed_cycles or 0) * 13 + (record.unit_number or 0)) % tile_count
    local existing_basin_nodes, existing_nodes = model._count_cyst_nodes_in_basin(record, entity)

    target = math.min(target, math.max(0, (band_def.cyst_capacity or 0) - existing_basin_nodes))
    if target <= 0 then
        record.ready_nodes = 0
        return 0
    end

    for offset = 0, tile_count - 1 do
        if spawned >= target then
            break
        end

        local index = ((offset_seed + offset) % tile_count) + 1
        local tile = record.claim_tiles[index]
        local tile_key = get_tile_key(record.surface_index, tile.x, tile.y)
        local position = {x = tile.x + 0.5, y = tile.y + 0.5}
        if not existing_nodes[tile_key] then
            local ok, node = pcall(function()
                return entity.surface.create_entity{
                    name = CYST_NODE_NAME,
                    position = position,
                    force = "neutral",
                    raise_built = false,
                    create_build_effect_smoke = false,
                    register_plant = true,
                    tick_grown = current_tick,
                }
            end)
            if ok and entity_check(node) then
                spawned = spawned + 1
                existing_nodes[tile_key] = true
                model._play_cyst_spawn_effect(entity.surface, position)
            end
        end
    end

    record.ready_nodes = spawned
    return spawned
end

-- Advancing a phase resets the short-term pressure streaks because the vat has
-- successfully escaped the current failure mode. Long-term health remains in
-- vigor and contamination.
local function advance_phase(record, current_tick, next_phase, completed_phase_override)
    local current_index = PHASE_INDEX[record.phase] or 0
    local resolved_next_phase = next_phase or PHASE_ORDER[current_index + 1] or PHASE_ORDER[1]
    local completed_phase = completed_phase_override or record.active_phase_key or record.phase
    if completed_phase == "ferment-enriched" and resolved_next_phase == "drain" then
        record.enriched_bloom = true
        if record.pending_acidic_runoff == nil then
            record.pending_acidic_runoff = acid_roll(record, current_tick)
        end
    elseif completed_phase == "ferment" and resolved_next_phase == "drain" then
        record.enriched_bloom = false
        if record.pending_acidic_runoff == nil then
            record.pending_acidic_runoff = acid_roll(record, current_tick)
        end
    elseif record.phase == "drain" and resolved_next_phase ~= "drain" then
        record.pending_acidic_runoff = nil
        record.drain_runoff_pending = false
    end
    if record.phase == "bloom" then
        record.completed_cycles = (record.completed_cycles or 0) + 1
    end

    record.phase = resolved_next_phase
    record.active_phase_key = resolved_next_phase
    record.phase_progress = 0
    record.phase_started_tick = current_tick
    record.starvation_streak = 0
    record.blocked_drain_streak = 0
    record.last_starvation_penalty_tick = current_tick
    record.last_blocked_drain_penalty_tick = current_tick
    if resolved_next_phase == "ferment" then
        record.ferment_enrichment_until_tick = current_tick + FERMENT_ENRICHMENT_WINDOW_TICKS
    elseif resolved_next_phase ~= "ferment-enriched" then
        record.ferment_enrichment_until_tick = nil
    end
    if resolved_next_phase == "seed" then
        record.ready_nodes = 0
        record.enriched_bloom = false
    end
end

-- is_crafting can throw around invalid or transitional entities, so the script
-- treats a failed read as "not crafting" and lets the normal waiting cadence
-- handle the next wake.
local function safe_is_crafting(entity)
    if not entity_check(entity) then
        return false
    end

    local ok, crafting = pcall(function()
        return entity.is_crafting()
    end)
    return ok and crafting == true
end

-- One due vat pass is the whole biological engine:
-- 1. validate the visible vat and clear the authoritative due slot;
-- 2. keep the hidden recipe locked to the current phase and basin band;
-- 3. interpret recipe marker/progress/products-finished as phase completion;
-- 4. penalize starvation or blocked drain only on their long intervals;
-- 5. apply bloom success/failure, drain completion, rest recovery, and tile scarring;
-- 6. rewrite status, telemetry, and any open GUI exactly once at the end.
local function process_due_vat(runtime, record, current_tick)
    local entity = ei_lib.get_valid_entity(record.entity)
    if not entity then
        unregister_vat(runtime, record.unit_number)
        return false
    end

    record.due_tick = nil
    runtime.due_tick_by_unit[record.unit_number] = nil

    record.last_tick = current_tick

    if not record.claim_valid then
        apply_phase_recipe(record, current_tick)
        apply_status_to_entity(record)
        update_telemetry_proxy(runtime, record)
        queue_ui_refresh_for_unit(runtime, record.unit_number, current_tick + UI_REFRESH_DELAY)
        return true
    end

    local pre_apply_recipe_name = get_recipe_name(entity)
    local pre_apply_phase_key = record.active_phase_key or record.phase
    local pre_apply_products_finished = get_products_finished(entity)
    local pre_apply_product_ready = pre_apply_products_finished > (record.last_products_finished or pre_apply_products_finished)
    local pre_apply_progress = get_crafting_progress(entity)
    local pre_apply_progress_ready = pre_apply_progress >= 1
    local pre_apply_marker_ready = false
    if not (pre_apply_product_ready or pre_apply_progress_ready) then
        pre_apply_marker_ready = get_marker_amount(entity) > 0
    end
    local pre_apply_phase_ready = pre_apply_marker_ready or pre_apply_product_ready or pre_apply_progress_ready
    local pre_apply_completed_phase = nil
    if pre_apply_phase_ready then
        if type(pre_apply_recipe_name) == "string"
        and string.sub(pre_apply_recipe_name, 1, #"ei-auric-vat-ferment-enriched-") == "ei-auric-vat-ferment-enriched-" then
            pre_apply_completed_phase = "ferment-enriched"
        else
            pre_apply_completed_phase = pre_apply_phase_key
        end
    end

    local recipe_available = apply_phase_recipe(record, current_tick)
    local phase_def = PHASE_DEFS[record.phase] or PHASE_DEFS.rest
    local entity_status = entity.status
    local active_recipe_name = record.active_recipe_name or get_recipe_name(entity)
    local recipe_dirty = false
    local working = safe_is_crafting(entity)
    local progress = get_crafting_progress(entity)
    local products_finished = get_products_finished(entity)
    local product_ready = pre_apply_product_ready or products_finished > (record.last_products_finished or products_finished)
    local progress_ready = progress >= 1
    local marker_ready = pre_apply_marker_ready
    if not (product_ready or progress_ready) then
        marker_ready = get_marker_amount(entity) > 0
    end
    local phase_ready = marker_ready or product_ready or progress_ready
    local completed_phase = pre_apply_completed_phase
    if not completed_phase and phase_ready then
        if type(active_recipe_name) == "string"
        and string.sub(active_recipe_name, 1, #"ei-auric-vat-ferment-enriched-") == "ei-auric-vat-ferment-enriched-" then
            completed_phase = "ferment-enriched"
        else
            completed_phase = record.active_phase_key or record.phase
        end
    end
    local starved = STARVED_STATUSES[entity_status] == true
    local blocked = entity_status == ENTITY_STATUS_FULL_OUTPUT
    local power_blocked = entity_status == ENTITY_STATUS_NO_POWER
        or entity_status == ENTITY_STATUS_LOW_POWER
        or entity_status == ENTITY_STATUS_NOT_PLUGGED
        or entity_status == ENTITY_STATUS_DISABLED
        or entity_status == ENTITY_STATUS_DISABLED_BY_SCRIPT

    -- products_finished is monotonically increasing on the entity, so any newly
    -- observed product count becomes the new baseline before phase logic runs.
    if product_ready then
        record.last_products_finished = math.max(products_finished, pre_apply_products_finished)
    end

    -- Runtime follows the assembler's reported progress until a completion pulse
    -- arrives. Once completion is detected, the phase is treated as fully elapsed
    -- even if the visual progress bar was between samples.
    if phase_ready then
        record.phase_progress = phase_def.duration_ticks
    else
        record.phase_progress = math.floor(progress * phase_def.duration_ticks)
    end

    if phase_ready then
        -- Drain runoff is engine-owned. This branch only runs after Factorio has
        -- completed the recipe, which means its dirty/acidic outputs already found
        -- valid room in the indexed output fluidboxes.
        if record.phase == "drain" then
            consume_phase_completion(record, entity)
            record.drain_runoff_pending = true
            recipe_dirty = true
            queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
        -- Bloom is the payoff and the risk point. Healthy basins spawn cyst nodes;
        -- tired or contaminated basins lose the bloom, scar the marsh, and force a
        -- recovery rest instead.
        elseif record.phase == "bloom" then
            consume_phase_completion(record, entity)
            if record.vigor >= model.BLOOM_MIN_VIGOR and record.contamination <= model.BLOOM_MAX_CONTAMINATION then
                spawn_cyst_nodes(record, current_tick)
                record.vigor = clamp(record.vigor - 12, 0, 100)
                record.contamination = clamp(record.contamination - 15, 0, 100)
                if record.contamination <= model.BASIN_RESTORE_MAX_CONTAMINATION
                or record.vigor >= model.BASIN_RESTORE_MIN_VIGOR then
                    record.successful_bloom_streak = (record.successful_bloom_streak or 0) + 1
                    if record.successful_bloom_streak >= model.BASIN_RESTORE_SUCCESS_STREAK then
                        model._apply_success_recovery(runtime, record, current_tick)
                        record.successful_bloom_streak = 0
                    end
                else
                    record.successful_bloom_streak = 0
                end
                advance_phase(record, current_tick, nil, completed_phase)
                recipe_dirty = true
            else
                record.ready_nodes = 0
                record.successful_bloom_streak = 0
                apply_failure_downgrade(runtime, record, current_tick)
                record.vigor = clamp(record.vigor - 20, 0, 100)
                record.contamination = clamp(record.contamination + 15, 0, 100)
                advance_phase(record, current_tick, "rest", completed_phase)
                recipe_dirty = true
                refresh_claim(runtime, record, current_tick, false)
            end
            queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
        -- Rest is active recovery, not idle time. It repairs vigor and cleans some
        -- contamination before returning the cycle to seed.
        elseif record.phase == "rest" then
            consume_phase_completion(record, entity)
            record.vigor = clamp(record.vigor + 8, 0, 100)
            record.contamination = clamp(record.contamination - 5, 0, 100)
            if record.vigor < model.BLOOM_MIN_VIGOR or record.contamination > model.BLOOM_MAX_CONTAMINATION then
                advance_phase(record, current_tick, "rest", completed_phase)
            else
                advance_phase(record, current_tick, nil, completed_phase)
            end
            recipe_dirty = true
            queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
        else
            consume_phase_completion(record, entity)
            advance_phase(record, current_tick, nil, completed_phase)
            recipe_dirty = true
            queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
        end
    elseif record.phase == "drain" and record.drain_runoff_pending == true then
        if drain_outputs_are_clear(record, entity) then
            record.drain_runoff_pending = false
            advance_phase(record, current_tick, nil, record.active_phase_key or record.phase)
            recipe_dirty = true
            queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
        else
            if current_tick >= ((record.last_blocked_drain_penalty_tick or current_tick) + BLOCKED_DRAIN_PENALTY_INTERVAL_TICKS) then
                record.blocked_drain_streak = (record.blocked_drain_streak or 0) + 1
                record.contamination = clamp(record.contamination + 10, 0, 100)
                record.last_blocked_drain_penalty_tick = current_tick
            end
            queue_vat_due(runtime, record.unit_number, current_tick + BLOCKED_DRAIN_SAMPLE_INTERVAL_TICKS)
        end
    elseif power_blocked then
        -- Power problems do not punish the basin. They only slow sampling because
        -- the player has not supplied the machine, not because the biology is
        -- fermenting wrong inputs.
        queue_vat_due(runtime, record.unit_number, current_tick + WAITING_SAMPLE_INTERVAL_TICKS)
    elseif blocked and record.phase == "drain" then
        -- A blocked drain is harmful only during drain. The long penalty interval
        -- keeps contamination growth readable without converting a full pipe into
        -- a per-tick UPS or balance problem.
        if current_tick >= ((record.last_blocked_drain_penalty_tick or current_tick) + BLOCKED_DRAIN_PENALTY_INTERVAL_TICKS) then
            record.blocked_drain_streak = (record.blocked_drain_streak or 0) + 1
            record.contamination = clamp(record.contamination + 10, 0, 100)
            record.last_blocked_drain_penalty_tick = current_tick
        end
        queue_vat_due(runtime, record.unit_number, current_tick + BLOCKED_DRAIN_SAMPLE_INTERVAL_TICKS)
    elseif starved and record.phase ~= "drain" and record.phase ~= "bloom" and record.phase ~= "rest" then
        -- Starvation is a cost for leaving the active input phases enabled without
        -- their biological feedstock. Drain, bloom, and rest are excluded because
        -- they are output/recovery phases rather than input demand.
        if current_tick >= ((record.last_starvation_penalty_tick or current_tick) + STARVATION_PENALTY_INTERVAL_TICKS) then
            record.starvation_streak = (record.starvation_streak or 0) + 1
            record.contamination = clamp(record.contamination + 10, 0, 100)
            record.last_starvation_penalty_tick = current_tick
        end
        queue_vat_due(runtime, record.unit_number, current_tick + WAITING_SAMPLE_INTERVAL_TICKS)
    elseif working or recipe_available then
        record.starvation_streak = 0
        record.blocked_drain_streak = 0
        queue_vat_due(runtime, record.unit_number, current_tick + ACTIVE_SAMPLE_INTERVAL_TICKS)
    else
        -- No clear progress and no meaningful failure mode. Sleep longer and let
        -- normal events or the waiting sample cadence pull the vat back in.
        queue_vat_due(runtime, record.unit_number, current_tick + WAITING_SAMPLE_INTERVAL_TICKS)
    end

    -- All side effects that players can observe are refreshed after phase logic
    -- settles, which avoids transient UI/circuit states from the middle of a
    -- branch.
    if recipe_dirty then
        apply_phase_recipe(record, current_tick)
    end
    apply_status_to_entity(record)
    update_telemetry_proxy(runtime, record)
    record.due_tick = runtime.due_tick_by_unit[record.unit_number]
    queue_ui_refresh_for_unit(runtime, record.unit_number, current_tick + UI_REFRESH_DELAY)
    return true
end

function model._get_due_activation_limit(limit)
    limit = math.floor(tonumber(limit) or model.DEFAULT_DUE_ACTIVATION_LIMIT)
    if limit < 1 then
        return 0
    end

    return limit
end

function model._put_back_due_bucket(runtime, bucket_tick, entries)
    if not (bucket_tick and entries and #entries > 0) then
        return
    end

    local bucket = runtime.due_buckets[bucket_tick]
    if bucket then
        for _, unit_number in ipairs(bucket) do
            entries[#entries + 1] = unit_number
        end
    end

    runtime.due_buckets[bucket_tick] = entries
    if runtime.next_due_tick == 0 or bucket_tick < runtime.next_due_tick then
        runtime.next_due_tick = bucket_tick
    end
end

-- Delayed buckets are activated into the ready queue only when the frontier says
-- something is due, and only up to the same budget family that will process the
-- ready work. A huge synchronized wake therefore bleeds across ticks instead of
-- front-loading all bucket scans before control.lua's service budget applies.
local function activate_due_units(runtime, current_tick, limit)
    local activated = 0
    local scanned = 0
    local activation_limit = model._get_due_activation_limit(limit)
    if activation_limit <= 0 then
        runtime.last_due_activation_scanned_count = 0
        runtime.last_due_activation_activated_count = 0
        return 0, 0
    end

    local stale_count = 0

    while scanned < activation_limit do
        local bucket_tick = math.max(0, math.floor(tonumber(runtime.next_due_tick) or 0))
        if bucket_tick <= 0 or bucket_tick > current_tick then
            break
        end

        local bucket = scheduler.delayed_take_due(runtime.due_buckets, bucket_tick)
        if #bucket == 0 then
            recalculate_next_due_tick(runtime)
        else
            local deferred_entries = nil
            for _, unit_number in ipairs(bucket) do
                if scanned >= activation_limit then
                    deferred_entries = deferred_entries or {}
                    deferred_entries[#deferred_entries + 1] = unit_number
                else
                    scanned = scanned + 1
                    if runtime.due_tick_by_unit[unit_number] == bucket_tick then
                        if push_ready_unit(runtime, unit_number) then
                            activated = activated + 1
                        end
                    else
                        stale_count = stale_count + 1
                    end
                end
            end

            if deferred_entries then
                runtime.due_activation_deferred_count = (runtime.due_activation_deferred_count or 0) + #deferred_entries
                model._put_back_due_bucket(runtime, bucket_tick, deferred_entries)
            else
                recalculate_next_due_tick(runtime)
            end
        end
    end

    if stale_count > 0 then
        runtime.due_stale_bucket_entry_count = (runtime.due_stale_bucket_entry_count or 0) + stale_count
    end
    runtime.last_due_activation_scanned_count = scanned
    runtime.last_due_activation_activated_count = activated
    return activated, scanned
end

-- This count is intentionally queue-based, not bucket-based. It tells control.lua
-- how much immediate budget can be spent without looking through future delayed
-- work.
local function get_ready_vat_queue_count(runtime)
    if not runtime then
        return 0
    end

    local count = tonumber(runtime.ready_queue_count)
    if count == nil then
        return reconcile_ready_queue_count(runtime)
    end

    return count
end

-- Due count is a debug/status number, so it may do a small authoritative scan
-- only when the next frontier is already due. Idle worlds return the ready queue
-- count without walking every tracked vat.
local function get_due_vat_count(runtime, current_tick)
    local count = get_ready_vat_queue_count(runtime)
    if runtime.next_due_tick == 0 or current_tick < runtime.next_due_tick then
        return count
    end

    for unit_number, due_tick in pairs(runtime.due_tick_by_unit) do
        if due_tick and due_tick <= current_tick and not runtime.ready_queue.queued[unit_number] then
            count = count + 1
        end
    end
    return count
end

-- Status export is rate-limited because it exists for debug, telemetry, and QC
-- visibility, not gameplay. Forced calls happen on structural events such as
-- build/destroy and tile changes where immediate counters are useful; ordinary
-- release-path calls reuse the last snapshot unless telemetry is enabled.
local function update_runtime_status(runtime, current_tick, force)
    current_tick = tonumber(current_tick) or 0
    if not force and not scheduler.telemetry_enabled() then
        local cached_status = scheduler.get_module_status(MODULE_NAME)
        if cached_status then
            return cached_status
        end
    end

    if not force
    and runtime.last_status_tick > 0
    and current_tick > 0
    and current_tick < (runtime.last_status_tick + STATUS_UPDATE_INTERVAL_TICKS) then
        return scheduler.get_module_status(MODULE_NAME)
    end

    runtime.last_status_tick = current_tick
    return model.get_runtime_status(current_tick, false)
end

-- The debug snapshot intentionally includes both gameplay counts and scheduler
-- audit counts. That lets `/ei_runtime_status` show whether the vat system is
-- asleep, backed up, leaking claims, missing proxies, or accumulating stale queue
-- entries.
function model.get_runtime_status(current_tick, detailed)
    local runtime = get_runtime()
    current_tick = tonumber(current_tick) or (game and game.tick) or 0
    detailed = detailed ~= false

    local tracked_vat_count = 0
    local active_vat_count = 0
    local claim_count = 0
    local conflict_count = 0
    local conflict_tile_count = 0
    local telemetry_proxy_count = 0
    local missing_telemetry_proxy_count = 0
    local stale_entity_count = 0
    local telemetry_proxy_unavailable_count = 0
    local telemetry_unwired_vat_count = 0
    local phase_counts = new_phase_counts()
    local band_counts = new_band_counts()
    local status_counts = {}
    local invalid_reason_counts = {}
    local placement_guide_counts = get_placement_guide_counts(runtime, detailed)
    if runtime.telemetry_proxy_available == nil then
        runtime.telemetry_proxy_available = entity_prototype_exists(TELEMETRY_PROXY_NAME) == true
    end
    local telemetry_proxy_available = runtime.telemetry_proxy_available == true

    for _, record in pairs(runtime.vats_by_unit) do
        tracked_vat_count = tracked_vat_count + 1
        local record_status_key = get_status_key(record)
        status_counts[record_status_key] = (status_counts[record_status_key] or 0) + 1
        if not record.claim_valid then
            local invalid_reason = record.invalid_reason or "unknown"
            invalid_reason_counts[invalid_reason] = (invalid_reason_counts[invalid_reason] or 0) + 1
        end
        if record.claim_valid then
            claim_count = claim_count + 1
            if PHASE_DEFS[record.phase] and PHASE_DEFS[record.phase].active then
                active_vat_count = active_vat_count + 1
            end
        end
        local record_conflict_tile_count = tonumber(record.conflict_tile_count)
        if record_conflict_tile_count and record_conflict_tile_count > 0 then
            conflict_count = conflict_count + 1
            conflict_tile_count = conflict_tile_count + record_conflict_tile_count
        elseif not record_conflict_tile_count and scheduler.table_count(record.claim_conflicts) > 0 then
            conflict_count = conflict_count + 1
        end
        local vat_entity = ei_lib.get_valid_entity(record.entity)
        if entity_check(record.telemetry_proxy) then
            telemetry_proxy_count = telemetry_proxy_count + 1
        elseif vat_entity and record.signal_cache and record.signal_cache.disconnected == true then
            telemetry_unwired_vat_count = telemetry_unwired_vat_count + 1
        elseif vat_entity and telemetry_proxy_available then
            missing_telemetry_proxy_count = missing_telemetry_proxy_count + 1
        elseif vat_entity then
            telemetry_proxy_unavailable_count = telemetry_proxy_unavailable_count + 1
        else
            stale_entity_count = stale_entity_count + 1
        end

        if record.claim_valid then
            band_counts[record.band_key] = (band_counts[record.band_key] or 0) + 1
            phase_counts[record.phase] = (phase_counts[record.phase] or 0) + 1
        else
            band_counts.unclaimed = (band_counts.unclaimed or 0) + 1
            phase_counts.invalid = (phase_counts.invalid or 0) + 1
        end
    end

    local orphan_claim_units = nil
    local claimed_tile_count = nil
    if detailed then
        orphan_claim_units = {}
        claimed_tile_count = 0
        for _, owner_unit_number in pairs(runtime.claims_by_tile) do
            claimed_tile_count = claimed_tile_count + 1
            if not runtime.vats_by_unit[owner_unit_number] then
                orphan_claim_units[owner_unit_number] = true
            end
        end
    end

    local status = {
        tick = current_tick,
        status_schema_version = 1,
        detailed = detailed,
        tracked_vat_count = tracked_vat_count,
        active_vat_count = active_vat_count,
        queued_vat_count = scheduler.table_count(runtime.due_tick_by_unit),
        due_vat_count = get_due_vat_count(runtime, current_tick),
        ready_queue_items = get_ready_vat_queue_count(runtime),
        ready_queue_audit = detailed and scheduler.audit_queue(runtime.ready_queue) or nil,
        next_due_tick = runtime.next_due_tick or 0,
        open_gui_count = scheduler.table_count(runtime.open_by_player),
        telemetry_proxy_count = telemetry_proxy_count,
        telemetry_unwired_vat_count = telemetry_unwired_vat_count,
        missing_telemetry_proxy_count = missing_telemetry_proxy_count,
        stale_entity_count = stale_entity_count,
        telemetry_proxy_unavailable_count = telemetry_proxy_unavailable_count,
        claim_count = claim_count,
        claimed_tile_count = claimed_tile_count,
        conflict_count = conflict_count,
        conflict_tile_count = conflict_tile_count,
        orphan_claim_count = detailed and scheduler.table_count(orphan_claim_units) or nil,
        phase_counts = phase_counts,
        band_counts = band_counts,
        status_counts = status_counts,
        invalid_reason_counts = invalid_reason_counts,
        due_bucket_count = scheduler.delayed_bucket_count(runtime.due_buckets),
        due_bucket_items = detailed and scheduler.delayed_item_count(runtime.due_buckets) or nil,
        due_stale_bucket_entry_count = runtime.due_stale_bucket_entry_count or 0,
        ready_stale_dequeue_count = runtime.ready_stale_dequeue_count or 0,
        due_activation_deferred_count = runtime.due_activation_deferred_count or 0,
        last_due_activation_scanned_count = runtime.last_due_activation_scanned_count or 0,
        last_due_activation_activated_count = runtime.last_due_activation_activated_count or 0,
        ui_bucket_count = scheduler.delayed_bucket_count(runtime.ui_due_buckets),
        ui_bucket_items = detailed and scheduler.delayed_item_count(runtime.ui_due_buckets) or nil,
        pending_ui_refresh_count = scheduler.table_count(runtime.ui_pending_by_player),
        next_ui_due_tick = runtime.next_ui_due_tick or 0,
        ui_stale_bucket_entry_count = runtime.ui_stale_bucket_entry_count or 0,
        last_ui_refresh_player_count = runtime.last_ui_refresh_player_count or 0,
        placement_guide_active_player_count = placement_guide_counts.active_player_count,
        placement_guide_surface_count = placement_guide_counts.surface_count,
        placement_cursor_intent_cached_player_count = placement_guide_counts.cursor_intent_cached_player_count,
        placement_guide_rendered_chunk_count = placement_guide_counts.rendered_chunk_count,
        placement_guide_render_object_count = placement_guide_counts.render_object_count,
        placement_guide_stale_cleanup_count = placement_guide_counts.stale_cleanup_count,
        placement_guide_skipped_ungenerated_chunk_count = placement_guide_counts.skipped_ungenerated_chunk_count,
        placement_guide_dirty_player_skip_count = placement_guide_counts.dirty_player_skip_count,
        last_tile_change_region_count = runtime.last_tile_change_region_count or 0,
        last_tile_change_dirty_chunk_count = runtime.last_tile_change_dirty_chunk_count or 0,
        last_tile_change_scan_region_count = runtime.last_tile_change_scan_region_count or 0,
        tile_change_region_refresh_count = runtime.tile_change_region_refresh_count or 0,
        orphan_telemetry_proxy_cleanup_count = runtime.orphan_telemetry_proxy_cleanup_count or 0,
        orphan_claim_cleanup_count = runtime.orphan_claim_cleanup_count or 0,
    }

    scheduler.set_module_status(MODULE_NAME, status)
    return status
end

-- Rebuilds discard the old reverse proxy ownership table. After visible vats have
-- reattached their own helpers, this sweep removes leftover circuit interfaces so
-- migrated saves do not accumulate invisible, wireable ghosts.
local function destroy_orphan_telemetry_proxies(runtime)
    if runtime.telemetry_proxy_available == nil then
        runtime.telemetry_proxy_available = entity_prototype_exists(TELEMETRY_PROXY_NAME) == true
    end
    if runtime.telemetry_proxy_available ~= true then
        return 0
    end

    local destroyed_count = 0
    for _, surface in pairs(game and game.surfaces or {}) do
        for _, proxy in ipairs(surface.find_entities_filtered{name = TELEMETRY_PROXY_NAME}) do
            local proxy_unit_number = get_unit_number(proxy)
            if not (proxy_unit_number and runtime.proxy_owner_by_unit[proxy_unit_number]) then
                proxy.destroy()
                destroyed_count = destroyed_count + 1
            end
        end
    end

    runtime.orphan_telemetry_proxy_cleanup_count = (runtime.orphan_telemetry_proxy_cleanup_count or 0) + destroyed_count
    return destroyed_count
end

function model.check_global()
    local existing = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if type(existing) == "table" and existing.version ~= RUNTIME_VERSION then
        destroy_all_placement_guides(existing, false)
        destroy_open_gui_roots(existing)
        return existing
    end

    return get_runtime()
end

-- Rebuild is the heavy repair path. It creates a fresh runtime table, rescans
-- visible vats, and carries record state by unit number so configuration changes
-- repair helper tables without wiping biological progress.
function model.rebuild_runtime_state(reason, current_tick)
    current_tick = tonumber(current_tick) or 0

    local old_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    local old_records = old_runtime and old_runtime.vats_by_unit or {}
    if old_runtime then
        destroy_all_placement_guides(old_runtime, false)
        destroy_open_gui_roots(old_runtime)
    end

    local runtime = new_runtime()
    storage.ei = storage.ei or {}
    storage.ei.auric_inoculation_vat = runtime

    for _, surface in pairs(game and game.surfaces or {}) do
        for _, entity in ipairs(surface.find_entities_filtered{name = VAT_NAME}) do
            local unit_number = get_unit_number(entity)
            register_vat(runtime, entity, current_tick, unit_number and old_records[unit_number] or nil)
        end
    end

    destroy_orphan_telemetry_proxies(runtime)
    sync_connected_placement_guides(runtime)
    for _, player in pairs(game and game.connected_players or {}) do
        if get_opened_vat(player) then
            model.open_gui(player, current_tick)
        end
    end

    local status = model.get_runtime_status(current_tick)
    status.rebuild_reason = reason
    scheduler.set_module_status(MODULE_NAME, status)
    return status
end

local function get_dispatcher_state(event)
    local raw_runtime = get_existing_runtime()
    if not raw_runtime then
        return 0, 0, 0
    end

    local ready_count = get_ready_vat_queue_count(raw_runtime)
    local next_due_tick = tonumber(raw_runtime.next_due_tick) or 0
    local next_ui_due_tick = tonumber(raw_runtime.next_ui_due_tick) or 0
    return ready_count, next_due_tick, next_ui_due_tick
end

-- control.lua calls this once per tick to decide whether either vat simulation or
-- its separate UI due gate needs service. This is deliberately side-effect free:
-- actual due-bucket activation happens in update(), under the normal budget.
function model.get_dispatcher_state(event)
    return get_dispatcher_state(event)
end

function model.get_pending_work_count(event)
    local ready_count = get_dispatcher_state(event)
    return ready_count
end

-- Top-level control hands the vat module one tick event and one budget. The
-- module owns the dispatcher policy so control.lua does not need to know about
-- ready queues, delayed vat buckets, or the separate UI gate.
function model.updater(limit, event)
    local current_tick = now_tick(event)
    local pending_work_count, next_due_tick, ui_next_due_tick = get_dispatcher_state(event)

    if pending_work_count > 0
    or (next_due_tick > 0 and current_tick >= next_due_tick) then
        model.update(limit, event)
    end

    if ui_next_due_tick > 0 and current_tick >= ui_next_due_tick then
        model.service_ui(event)
    end
end

function model.get_next_due_tick()
    local runtime = get_existing_runtime()
    if not runtime then
        return 0
    end

    return runtime.next_due_tick or 0
end

-- The main service loop is budgeted by ready units. It exits early when the
-- frontier is in the future, then processes at most `limit` authoritative due
-- vats and returns the remaining due count for the dispatcher.
function model.update(limit, event)
    local runtime = get_runtime()
    local current_tick = now_tick(event)
    limit = math.max(0, math.floor(tonumber(limit) or 0))
    if runtime.next_due_tick == 0 or current_tick < runtime.next_due_tick then
        if get_ready_vat_queue_count(runtime) == 0 then
            update_runtime_status(runtime, current_tick, false)
            return 0, 0
        end
    end

    local ready_before_activation = get_ready_vat_queue_count(runtime)
    activate_due_units(runtime, current_tick, math.max(0, limit - ready_before_activation))
    if get_ready_vat_queue_count(runtime) == 0 then
        update_runtime_status(runtime, current_tick, false)
        return 0, 0
    end

    local processed = 0
    local attempted = 0
    local stale_ready_count = 0
    while attempted < limit do
        local unit_number = pop_ready_unit(runtime)
        if not unit_number then
            break
        end

        attempted = attempted + 1
        local authoritative_due_tick = runtime.due_tick_by_unit[unit_number]
        if authoritative_due_tick and authoritative_due_tick <= current_tick then
            local record = runtime.vats_by_unit[unit_number]
            if record and process_due_vat(runtime, record, current_tick) then
                processed = processed + 1
            elseif not record then
                runtime.due_tick_by_unit[unit_number] = nil
                stale_ready_count = stale_ready_count + 1
            end
        elseif not authoritative_due_tick then
            stale_ready_count = stale_ready_count + 1
        else
            scheduler.delayed_schedule(runtime.due_buckets, authoritative_due_tick, unit_number)
            if runtime.next_due_tick == 0 or authoritative_due_tick < runtime.next_due_tick then
                runtime.next_due_tick = authoritative_due_tick
            end
            stale_ready_count = stale_ready_count + 1
        end
    end
    if stale_ready_count > 0 then
        runtime.ready_stale_dequeue_count = (runtime.ready_stale_dequeue_count or 0) + stale_ready_count
    end

    update_runtime_status(runtime, current_tick, false)
    return processed, get_ready_vat_queue_count(runtime)
end

function model.get_next_ui_due_tick()
    local runtime = get_existing_runtime()
    if not runtime then
        return 0
    end

    return runtime.next_ui_due_tick or 0
end

-- UI has its own due gate and deduplicates by player index before rendering.
-- Multiple vat changes can queue the same player, but only one GUI refresh runs
-- for that tick.
function model.service_ui(event)
    local runtime = get_runtime()
    local current_tick = now_tick(event)
    if runtime.next_ui_due_tick == 0 or current_tick < runtime.next_ui_due_tick then
        runtime.last_ui_refresh_player_count = 0
        return false
    end

    local due_players = {}
    local compacted_buckets = {}
    local next_ui_due_tick = 0
    local stale_count = 0

    -- Service all matured UI buckets in one pass. The player pending map is the
    -- authority; delayed buckets are only wake hints and can contain old echoes
    -- after rapid open/close or feedback refresh coalescing.
    for bucket_tick, bucket in pairs(runtime.ui_due_buckets) do
        if bucket_tick > 0 and type(bucket) == "table" then
            if bucket_tick <= current_tick then
                for _, player_index in ipairs(bucket) do
                    local pending_tick = runtime.ui_pending_by_player[player_index]
                    if pending_tick and pending_tick <= current_tick then
                        due_players[player_index] = true
                    else
                        stale_count = stale_count + 1
                    end
                end
            else
                local live_bucket = {}
                for _, player_index in ipairs(bucket) do
                    if runtime.ui_pending_by_player[player_index] == bucket_tick then
                        live_bucket[#live_bucket + 1] = player_index
                    else
                        stale_count = stale_count + 1
                    end
                end
                if #live_bucket > 0 then
                    compacted_buckets[bucket_tick] = live_bucket
                    if next_ui_due_tick == 0 or bucket_tick < next_ui_due_tick then
                        next_ui_due_tick = bucket_tick
                    end
                end
            end
        end
    end

    runtime.ui_due_buckets = compacted_buckets
    runtime.next_ui_due_tick = next_ui_due_tick
    if stale_count > 0 then
        runtime.ui_stale_bucket_entry_count = (runtime.ui_stale_bucket_entry_count or 0) + stale_count
    end

    local refreshed_count = 0
    for player_index in pairs(due_players) do
        refresh_player_gui(runtime, player_index, current_tick)
        refreshed_count = refreshed_count + 1
    end
    runtime.last_ui_refresh_player_count = refreshed_count

    return next(due_players) ~= nil
end

-- Build handling is intentionally small: only the visible vat enters runtime.
-- Everything else, including proxy creation and basin claim, is derived from
-- register_vat() so blueprint, robot, and script placement share one path.
function model.on_built_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not (entity_check(entity) and entity.name == VAT_NAME) then
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event_or_entity)
    local surface_index = entity.surface.index
    register_vat(runtime, entity, current_tick, nil)
    redraw_placement_guides_for_area(
        runtime,
        surface_index,
        {x = entity.position.x - BASIN_RADIUS, y = entity.position.y - BASIN_RADIUS},
        {x = entity.position.x + BASIN_RADIUS, y = entity.position.y + BASIN_RADIUS}
    )
    update_runtime_status(runtime, current_tick, true)
end

-- Destroy handling covers both first-class vats and hidden proxies. Vat removal
-- releases terrain immediately; proxy removal simply clears derived state and
-- schedules the owner so it can recreate telemetry if still needed.
function model.on_destroyed_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    if not entity_check(entity) then
        return
    end

    local entity_name = entity.name
    if entity_name ~= VAT_NAME and entity_name ~= TELEMETRY_PROXY_NAME then
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event_or_entity)

    if entity_name == VAT_NAME then
        local unit_number = get_unit_number(entity)
        local surface_index = entity.surface and entity.surface.index or nil
        local position = entity.position
        if unit_number then
            unregister_vat(runtime, unit_number)
        end
        if position then
            redraw_placement_guides_for_area(
                runtime,
                surface_index,
                {x = position.x - BASIN_RADIUS, y = position.y - BASIN_RADIUS},
                {x = position.x + BASIN_RADIUS, y = position.y + BASIN_RADIUS}
            )
        else
            redraw_placement_guides_for_surface(runtime, surface_index)
        end
        update_runtime_status(runtime, current_tick, true)
        return
    end

    if entity_name == TELEMETRY_PROXY_NAME then
        local status_changed = false
        local owner_unit_number = runtime.proxy_owner_by_unit[get_unit_number(entity)]
        if owner_unit_number then
            local record = runtime.vats_by_unit[owner_unit_number]
            if record then
                unregister_destroy(runtime, record.telemetry_registration)
                if record.telemetry_proxy_unit_number then
                    runtime.proxy_owner_by_unit[record.telemetry_proxy_unit_number] = nil
                end
                record.telemetry_proxy = nil
                record.telemetry_proxy_unit_number = nil
                record.telemetry_registration = nil
                record.signal_cache = nil
                queue_vat_due(runtime, owner_unit_number, current_tick)
                queue_ui_refresh_for_unit(runtime, owner_unit_number, current_tick + UI_REFRESH_DELAY)
                status_changed = true
            end
        end
        if status_changed then
            update_runtime_status(runtime, current_tick, true)
        end
    end
end

-- Tile events arrive as a set of changed positions. Relevant edits are grouped
-- into coarse local regions and each region is expanded by basin radius, so a
-- few distant marsh edits do not become one giant vat scan.
-- Many tile events are decorative landfill/concrete churn far away from Gleba
-- wetlands. This helper does the cheap rejection and region collection in one
-- pass so big tile edits do not pay two walks before the local vat scan.
local function summarize_changed_wetland_tiles(runtime, surface, tiles, event_tile)
    local function get_tile_prototype_name(tile_or_name)
        if type(tile_or_name) == "string" then
            return tile_or_name
        end

        local name = get_runtime_prototype_name(tile_or_name)
        if name then
            return name
        end

        return get_runtime_prototype_name(safe_runtime_field(tile_or_name, "prototype"))
    end

    local touches_eligible = false
    local regions = {}
    local regions_by_key = {}
    local claims_by_tile = runtime.claims_by_tile or {}
    local has_claims = next(claims_by_tile) ~= nil
    local event_tile_name = get_tile_prototype_name(event_tile)
    local event_tile_is_eligible = event_tile_name and is_eligible_tile_name(event_tile_name) == true

    for _, tile in ipairs(tiles or {}) do
        local position = tile.position or tile
        local include_position = false
        if position and position.x and position.y then
            local new_tile_name = get_tile_prototype_name(tile.name) or event_tile_name
            local old_tile_name = get_tile_prototype_name(tile.old_tile)
            if has_claims and claims_by_tile[get_tile_key(surface.index, position.x, position.y)] then
                include_position = true
            elseif old_tile_name and is_eligible_tile_name(old_tile_name) then
                include_position = true
            elseif new_tile_name and is_eligible_tile_name(new_tile_name) then
                include_position = true
            elseif event_tile_is_eligible then
                include_position = true
            elseif not new_tile_name and surface and surface.valid then
                local current_tile = surface.get_tile(position.x, position.y)
                if current_tile and current_tile.valid and is_eligible_tile_name(current_tile.name) then
                    include_position = true
                end
            end
        end

        if include_position then
            touches_eligible = true
            local region_x = math.floor(position.x / PLACEMENT_GUIDE_CHUNK_SIZE)
            local region_y = math.floor(position.y / PLACEMENT_GUIDE_CHUNK_SIZE)
            local region_key = tostring(region_x) .. ":" .. tostring(region_y)
            local region = regions_by_key[region_key]
            if not region then
                region = {
                    left_top = {x = position.x, y = position.y},
                    right_bottom = {x = position.x + 1, y = position.y + 1},
                }
                regions_by_key[region_key] = region
                regions[#regions + 1] = region
            else
                region.left_top.x = math.min(region.left_top.x, position.x)
                region.left_top.y = math.min(region.left_top.y, position.y)
                region.right_bottom.x = math.max(region.right_bottom.x, position.x + 1)
                region.right_bottom.y = math.max(region.right_bottom.y, position.y + 1)
            end
        end
    end

    return touches_eligible, regions
end

-- Tile-change claim repair is local to the changed area. Any vat found in range
-- either refreshes its existing claim or gets registered if it slipped through a
-- prior lifecycle hook.
local function refresh_claims_near_tiles(event)
    local surface = event and event.surface
    if not (surface and surface.valid) and event and event.surface_index and game then
        surface = game.get_surface(event.surface_index)
    end

    if not (surface and surface.valid) then
        return
    end

    local runtime = get_existing_runtime()
    if not runtime then
        return
    end

    local has_surface_vats = runtime.units_by_surface
        and runtime.units_by_surface[surface.index]
        and next(runtime.units_by_surface[surface.index]) ~= nil
    local has_surface_guides = has_placement_guide_on_surface(runtime, surface.index)
    if not has_surface_vats and not has_surface_guides then
        return
    end

    local event_tile = event and event.tile
    local touches_eligible, regions = summarize_changed_wetland_tiles(runtime, surface, event.tiles, event_tile)
    if not touches_eligible then
        return
    end

    if not (regions and #regions > 0) then
        return
    end

    local current_tick = now_tick(event)
    local claim_changed = false
    local placement_changed = false
    local seen_units = {}
    runtime.last_tile_change_region_count = #(regions or {})
    runtime.tile_change_region_refresh_count = (runtime.tile_change_region_refresh_count or 0) + runtime.last_tile_change_region_count

    local scan_regions = nil
    if has_surface_vats then
        scan_regions = {}
        for _, region in ipairs(regions or {}) do
            local pending = {
                left_top = {x = region.left_top.x - BASIN_RADIUS, y = region.left_top.y - BASIN_RADIUS},
                right_bottom = {x = region.right_bottom.x + BASIN_RADIUS, y = region.right_bottom.y + BASIN_RADIUS},
            }
            local merged = true
            while merged do
                merged = false
                for index = #scan_regions, 1, -1 do
                    local existing = scan_regions[index]
                    if not (
                        pending.right_bottom.x < existing.left_top.x
                        or pending.left_top.x > existing.right_bottom.x
                        or pending.right_bottom.y < existing.left_top.y
                        or pending.left_top.y > existing.right_bottom.y
                    ) then
                        pending.left_top.x = math.min(pending.left_top.x, existing.left_top.x)
                        pending.left_top.y = math.min(pending.left_top.y, existing.left_top.y)
                        pending.right_bottom.x = math.max(pending.right_bottom.x, existing.right_bottom.x)
                        pending.right_bottom.y = math.max(pending.right_bottom.y, existing.right_bottom.y)
                        table.remove(scan_regions, index)
                        merged = true
                    end
                end
            end
            scan_regions[#scan_regions + 1] = pending
        end
        runtime.last_tile_change_scan_region_count = #scan_regions
    else
        runtime.last_tile_change_scan_region_count = 0
    end

    if has_surface_vats then
        for _, region in ipairs(scan_regions or {}) do
            local area = {
                region.left_top,
                region.right_bottom,
            }
            for _, entity in ipairs(surface.find_entities_filtered{area = area, name = VAT_NAME}) do
                local unit_number = get_unit_number(entity)
                if unit_number and not seen_units[unit_number] then
                    seen_units[unit_number] = true
                    local record = runtime.vats_by_unit[unit_number]
                    if record then
                        refresh_claim(runtime, record, current_tick)
                    else
                        register_vat(runtime, entity, current_tick, nil)
                    end
                    claim_changed = true
                end
            end
        end
    end

    if has_surface_guides then
        placement_changed = redraw_placement_guides_for_regions(runtime, surface.index, regions) or placement_changed
    end

    if claim_changed or (placement_changed and scheduler.telemetry_enabled()) then
        update_runtime_status(runtime, current_tick, false)
    end
end

function model.on_built_tile(event)
    refresh_claims_near_tiles(event)
end

function model.on_destroyed_tile(event)
    refresh_claims_near_tiles(event)
end

-- Object-destroyed is the callback for registered entities that disappear without
-- a normal entity event carrying a LuaEntity. The registration table gives enough
-- identity to clean vat state or proxy state from storage alone.
function model.on_object_destroyed(event)
    local runtime = get_existing_runtime()
    if not runtime then
        return
    end

    local entry = runtime.registrations[event.registration_number]
    if not entry then
        return
    end

    runtime.registrations[event.registration_number] = nil
    local current_tick = now_tick(event)

    local placement_needs_redraw = false
    local placement_surface_index = nil
    local placement_position = entry.position
    local status_changed = false

    if entry.kind == "vat" then
        local record = runtime.vats_by_unit[entry.unit_number]
        if record then
            placement_surface_index = record.surface_index or entry.surface_index
            placement_position = record.position or placement_position
            unregister_vat(runtime, entry.unit_number)
            placement_needs_redraw = true
            status_changed = true
        end
    elseif entry.kind == "proxy" then
        local record = runtime.vats_by_unit[entry.unit_number]
        if record then
            if record.telemetry_proxy_unit_number then
                runtime.proxy_owner_by_unit[record.telemetry_proxy_unit_number] = nil
            end
            record.telemetry_proxy = nil
            record.telemetry_proxy_unit_number = nil
            record.telemetry_registration = nil
            record.signal_cache = nil
            queue_vat_due(runtime, record.unit_number, current_tick)
            queue_ui_refresh_for_unit(runtime, record.unit_number, current_tick + UI_REFRESH_DELAY)
            status_changed = true
        end
    end

    if placement_needs_redraw then
        if placement_surface_index and placement_position then
            redraw_placement_guides_for_area(
                runtime,
                placement_surface_index,
                {x = placement_position.x - BASIN_RADIUS, y = placement_position.y - BASIN_RADIUS},
                {x = placement_position.x + BASIN_RADIUS, y = placement_position.y + BASIN_RADIUS}
            )
        else
            redraw_placement_guides_for_surface(runtime, placement_surface_index)
        end
    end
    if status_changed or placement_needs_redraw then
        update_runtime_status(runtime, current_tick, true)
    end
end

-- Opening the native assembling-machine window creates the relative console
-- session, registers the vat defensively, renders an immediate snapshot, and
-- queues the normal UI refresh to catch any one-tick state changes.
function model.open_gui(player, event_or_tick)
    if not (player and player.valid) then
        return
    end

    local entity = get_opened_vat(player)
    if not entity then
        model.close_gui(player)
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event_or_tick)
    local unit_number = get_unit_number(entity)
    local record = unit_number and runtime.vats_by_unit[unit_number] or nil
    if not record or ei_lib.get_valid_entity(record.entity) ~= entity then
        record = register_vat(runtime, entity, current_tick, unit_number and runtime.vats_by_unit[unit_number] or nil)
    end
    if not record then
        model.close_gui(player)
        return
    end

    runtime.open_by_player[player.index] = runtime.open_by_player[player.index] or {}
    runtime.open_by_player[player.index].unit_number = record.unit_number
    runtime.open_by_player[player.index].last_signature = nil
    runtime.open_by_player[player.index].manual_feedback_until_tick = nil
    runtime.open_by_player[player.index].manual_feedback_caption = nil
    runtime.open_by_player[player.index].manual_feedback_kind = nil

    local snapshot = build_snapshot(runtime, record, current_tick)
    if not update_gui(player, snapshot) then
        model.close_gui(player)
        return
    end
    runtime.open_by_player[player.index].last_signature = snapshot.signature
    queue_ui_refresh_for_player(runtime, player.index, current_tick + UI_REFRESH_DELAY)
end

-- Closing a session removes both the runtime player watch and the visible root.
-- Recalculating the UI frontier keeps stale delayed bucket entries from becoming
-- the apparent next wake after the last panel closes. Some GUI events can arrive
-- after the player object is unavailable, so the cleanup accepts either a live
-- player or a player index.
function model.close_gui(player_or_index)
    local player = nil
    local player_index = nil

    if type(player_or_index) == "number" then
        player_index = player_or_index
        player = game and game.get_player(player_index) or nil
    elseif player_or_index then
        player = player_or_index
        player_index = player.index
    end

    if not player_index then
        return
    end

    local runtime = get_runtime()
    runtime.open_by_player[player_index] = nil
    runtime.ui_pending_by_player[player_index] = nil
    if player and player.valid then
        destroy_gui_root(player)
    end
    recalculate_next_ui_due_tick(runtime)
end

function model.has_open_gui_session(player_index)
    local raw_runtime = get_existing_runtime()
    return raw_runtime
        and type(raw_runtime.open_by_player) == "table"
        and raw_runtime.open_by_player[player_index] ~= nil
end

function model.has_active_placement_guide(player_index)
    local raw_runtime = get_existing_runtime()
    return raw_runtime
        and type(raw_runtime.placement_guides) == "table"
        and raw_runtime.placement_guides[player_index] ~= nil
end

-- Native GUI open/close events are the source of truth for relative panel life.
-- If some other entity is opened while this module still has a session, the old
-- vat console is closed immediately.
function model.on_gui_opened(event)
    local player = game and game.get_player(event.player_index) or nil
    local opened = get_opened_vat(player)

    if opened then
        model.open_gui(player, event)
        return
    end

    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if raw_runtime
    and type(raw_runtime.open_by_player) == "table"
    and raw_runtime.open_by_player[event.player_index] then
        model.close_gui(player or event.player_index)
    end
end

-- Closed GUI events can reference either the native entity or our relative root.
-- The checks below close only when the player no longer has the matching vat
-- window open, preserving the panel during ordinary Factorio GUI transitions.
function model.on_gui_closed(event)
    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if not raw_runtime
    or type(raw_runtime.open_by_player) ~= "table"
    or not raw_runtime.open_by_player[event.player_index] then
        return
    end

    local player = game and game.get_player(event.player_index) or nil
    local opened = get_opened_vat(player)
    local element = event and event.element or nil
    local closed_entity = ei_lib.get_valid_entity(event and event.entity)
    local closed_vat = closed_entity
        and closed_entity.object_name == "LuaEntity"
        and closed_entity.name == VAT_NAME
    if closed_vat or not opened or (element and element.valid and element.name == GUI_NAME) then
        model.close_gui(player or event.player_index)
    end
end

-- Button handling is tag-driven: the Informatron button opens documentation, and
-- the refresh button lets a player force basin re-evaluation after terrain edits
-- without waiting for another tile event or scheduled vat wake.
function model.on_gui_click(event)
    local element = event and event.element or nil
    if not (element and element.valid and element.tags) then
        return
    end

    if element.tags.parent_gui ~= GUI_NAME then
        return
    end

    local action = element.tags.action
    if action ~= "goto-informatron" and action ~= "refresh-claim" then
        return
    end

    local player = game and game.get_player(event.player_index) or nil
    local entity = get_opened_vat(player)
    if not entity then
        model.close_gui(player or event.player_index)
        return
    end

    if action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = element.tags.page or INFORMATRON_PAGE,
        })
        return
    end

    local runtime = get_runtime()
    local current_tick = now_tick(event)
    local unit_number = get_unit_number(entity)
    local record = unit_number and runtime.vats_by_unit[unit_number] or nil
    if not record or ei_lib.get_valid_entity(record.entity) ~= entity then
        record = register_vat(runtime, entity, current_tick, unit_number and runtime.vats_by_unit[unit_number] or nil)
    end
    if not record then
        model.close_gui(player or event.player_index)
        return
    end

    local before_snapshot = build_snapshot(runtime, record, current_tick)
    local before_claim_signature = model._get_claim_signature(before_snapshot)
    refresh_claim(runtime, record, current_tick)
    local position = entity.position
    if position then
        redraw_placement_guides_for_area(
            runtime,
            entity.surface and entity.surface.index or record.surface_index,
            {x = position.x - BASIN_RADIUS, y = position.y - BASIN_RADIUS},
            {x = position.x + BASIN_RADIUS, y = position.y + BASIN_RADIUS}
        )
    end
    local snapshot = build_snapshot(runtime, record, current_tick)
    local after_claim_signature = model._get_claim_signature(snapshot)
    if not update_gui(player, snapshot) then
        model.close_gui(player or event.player_index)
        return
    end
    local feedback_caption = nil
    local feedback_kind = nil
    if before_claim_signature == after_claim_signature then
        feedback_kind = "unchanged"
        feedback_caption = {
            "exotic-industries.auric-inoculation-vat-gui-refresh-unchanged",
            snapshot.basin_size or 0,
        }
    elseif snapshot.claim_valid then
        feedback_kind = "valid"
        feedback_caption = {
            "exotic-industries.auric-inoculation-vat-gui-refresh-valid",
            snapshot.basin_size or 0,
        }
    else
        feedback_kind = "invalid"
        feedback_caption = {
            "exotic-industries.auric-inoculation-vat-gui-refresh-invalid",
            get_status_locale(snapshot.status_key),
            snapshot.basin_size or 0,
        }
    end
    set_gui_feedback(player, feedback_caption, feedback_kind)
    runtime.open_by_player[player.index] = runtime.open_by_player[player.index] or {}
    runtime.open_by_player[player.index].unit_number = record.unit_number
    -- refresh_claim already schedules a UI wake. Store the fresh signature so
    -- that one-tick wake clears pending state without immediately erasing the
    -- manual feedback line; the feedback timeout below handles the calm case.
    runtime.open_by_player[player.index].last_signature = snapshot.signature
    runtime.open_by_player[player.index].manual_feedback_until_tick = current_tick + MANUAL_FEEDBACK_TICKS
    runtime.open_by_player[player.index].manual_feedback_caption = feedback_caption
    runtime.open_by_player[player.index].manual_feedback_kind = feedback_kind
    queue_ui_refresh_for_player(runtime, player.index, current_tick + MANUAL_FEEDBACK_TICKS)
    update_runtime_status(runtime, current_tick, true)
end

-- Cursor and viewport handlers own the wetland placement guide. There is no
-- tick service here: the guide wakes only when player intent or chunk position
-- changes, then chunk-caches every tile render until the viewport moves away.
function model.on_player_cursor_stack_changed(event)
    local player = game and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        return
    end

    local holds_vat = player_holds_vat_placement(player)
    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    local has_guide = raw_runtime
        and type(raw_runtime.placement_guides) == "table"
        and raw_runtime.placement_guides[event.player_index] ~= nil
    if raw_runtime and type(raw_runtime.placement_cursor_intent_by_player) == "table" then
        raw_runtime.placement_cursor_intent_by_player[event.player_index] = holds_vat == true and true or nil
    end
    if not holds_vat and not has_guide then
        return
    end

    local runtime = get_runtime()
    model._set_player_cursor_intent(runtime, event.player_index, holds_vat)
    if sync_player_placement_guide(runtime, player, true, false, holds_vat) then
        update_runtime_status(runtime, now_tick(event), false)
    end
end

function model.on_player_ready(player_index, event_or_tick)
    model.on_player_cursor_stack_changed{
        player_index = player_index,
        tick = now_tick(event_or_tick),
    }
end

function model.on_player_changed_position(event)
    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if not raw_runtime
    or type(raw_runtime.placement_guides) ~= "table"
    or not raw_runtime.placement_guides[event.player_index] then
        return
    end

    local runtime = get_runtime()
    local player = game and game.get_player(event.player_index) or nil
    if not (player and player.valid) then
        if destroy_player_placement_guide(runtime, event.player_index, true) then
            update_runtime_status(runtime, now_tick(event), false)
        end
        return
    end

    local current_tick = now_tick(event)
    if sync_player_placement_guide(runtime, player, false, true, nil, current_tick) then
        update_runtime_status(runtime, current_tick, false)
    end
end

function model.on_player_changed_surface(event)
    local player = game and game.get_player(event.player_index) or nil
    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    -- Surface changes are rare enough to re-read the cursor. Keeping this fresh
    -- avoids carrying stale false intent across teleport or surface transitions.
    local holds_vat = player_holds_vat_placement(player)
    local had_guide = raw_runtime
        and type(raw_runtime.placement_guides) == "table"
        and raw_runtime.placement_guides[event.player_index] ~= nil
    if not holds_vat and not had_guide then
        return
    end

    local runtime = get_runtime()
    model._set_player_cursor_intent(runtime, event.player_index, holds_vat)

    if not (player and player.valid) then
        if had_guide and destroy_player_placement_guide(runtime, event.player_index, true) then
            update_runtime_status(runtime, now_tick(event), false)
        end
        return
    end

    if had_guide then
        destroy_player_placement_guide(runtime, event.player_index, true)
    end

    if sync_player_placement_guide(runtime, player, true, false, holds_vat) or had_guide then
        update_runtime_status(runtime, now_tick(event), false)
    end
end

function model.on_player_toggled_alt_mode(event)
    local raw_runtime = storage and storage.ei and storage.ei.auric_inoculation_vat or nil
    if not raw_runtime
    or type(raw_runtime.placement_guides) ~= "table"
    or not raw_runtime.placement_guides[event.player_index] then
        return
    end

    local runtime = get_runtime()
    local player = game and game.get_player(event.player_index) or nil
    if not (player and player.valid and model._get_player_cursor_intent(runtime, player)) then
        if destroy_player_placement_guide(runtime, event.player_index, false) then
            update_runtime_status(runtime, now_tick(event), false)
        end
        return
    end

    if set_placement_guide_alt_mode(runtime, event.player_index, event.alt_mode == true) then
        update_runtime_status(runtime, now_tick(event), false)
    end
end

function model.on_pre_surface_deleted(event_or_surface_index)
    local surface_index = nil
    if type(event_or_surface_index) == "table" then
        surface_index = event_or_surface_index.surface_index
    else
        surface_index = event_or_surface_index
    end
    surface_index = tonumber(surface_index)
    if not surface_index then
        return
    end

    local runtime = get_existing_runtime()
    if not runtime then
        return
    end

    runtime.placement_guides_by_surface = runtime.placement_guides_by_surface or {}
    runtime.units_by_surface = runtime.units_by_surface or {}
    runtime.claims_by_tile = runtime.claims_by_tile or {}

    local changed = false
    local guide_player_indices = get_placement_player_indices_for_surface(runtime, surface_index)
    for _, player_index in ipairs(guide_player_indices) do
        changed = destroy_player_placement_guide(runtime, player_index, true) or changed
    end
    runtime.placement_guides_by_surface[surface_index] = nil

    local vat_unit_numbers = {}
    for unit_number in pairs(runtime.units_by_surface and runtime.units_by_surface[surface_index] or {}) do
        vat_unit_numbers[unit_number] = true
    end
    for unit_number, record in pairs(runtime.vats_by_unit or {}) do
        if record and tonumber(record.surface_index) == surface_index then
            vat_unit_numbers[unit_number] = true
        end
    end
    for unit_number in pairs(vat_unit_numbers) do
        unregister_vat(runtime, unit_number)
        changed = true
    end
    runtime.units_by_surface[surface_index] = nil

    local surface_prefix = tostring(surface_index) .. ":"
    for tile_key in pairs(runtime.claims_by_tile) do
        if string.sub(tile_key, 1, #surface_prefix) == surface_prefix then
            runtime.claims_by_tile[tile_key] = nil
            changed = true
        end
    end

    if changed then
        local status_tick = type(event_or_surface_index) == "table" and now_tick(event_or_surface_index) or now_tick(nil)
        update_runtime_status(runtime, status_tick, true)
    end
end

-- Player departure is session and render cleanup. Vat simulation continues
-- normally, and any stale UI bucket entries for the player are ignored once the
-- session is gone.
function model.on_player_left_game(player_index, event_or_tick)
    local runtime = get_existing_runtime()
    if not runtime then
        return
    end

    local player = game and game.get_player(player_index) or nil
    local had_open_session = runtime.open_by_player[player_index] ~= nil
    local placement_changed = destroy_player_placement_guide(runtime, player_index, false)
    runtime.open_by_player[player_index] = nil
    runtime.ui_pending_by_player[player_index] = nil
    model._clear_player_cursor_intent(runtime, player_index)
    if player and player.valid then
        destroy_gui_root(player)
    end
    recalculate_next_ui_due_tick(runtime)
    if placement_changed or had_open_session then
        update_runtime_status(runtime, now_tick(event_or_tick), false)
    end
end

return model
