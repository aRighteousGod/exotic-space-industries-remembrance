--==============================================================================
-- ESIR FILE MAP
-- owns: gate runtime, GUI, selector flow, and remote dispatch
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, build/destroy, selection/cursor, GUI, script triggers, player cleanup, scheduled tick step 7, and configuration changes
-- forwarded_events: apply_transfer_penalties, attach_wire_proxy_to_container, build_gui, can_gate_transport, can_pay_quote, change_permission, check_for_teleport, check_global_init, choose_position, cleanup_gate_remote_selection, cleanup_position_selection, close_gui, commit_quote, copy_exit, create_gate_user_permission_group, decay_gate_penalties, decay_receiver_penalties, destroy_gate, destroy_receiver, destroy_wire_proxy, distance_multiplier_to_span_ratio, emit_breach_residue, emit_stress_tendril, energy_from_burden, ensure_distance_cache, ensure_gate_defaults, ensure_receiver_defaults, ensure_wire_proxy, entity_check, find_container, find_container_entity, find_gate, gate_state, get_data, get_effective_receiver_data, get_gate_signal_value, get_gate_target_surface, get_gate_upkeep_watts, get_gui_elements, get_lowest_free_receiver_id, get_preview_exit, get_receiver_by_id, get_signal_value, get_span_band, get_surface_anchor, get_transfer_inv, is_gate_armed, is_gate_container_externally_wired, is_receiver_saturated, make_gate, make_item_stack_definition, make_item_with_quality_id, make_receiver_label, measure_transfer_burden, on_built_entity, on_configuration_changed, on_destroyed_entity, on_gui_click, on_gui_opened, on_gui_selection_state_changed, on_init, on_player_cursor_stack_changed, on_player_left_game, on_player_selected_area, open_gui, pay_energy, quote_transfer, rebuild_distance_cache, refresh_gate_live_state, refresh_receivers, register_gate, register_receiver, render_animation, render_exit, resolve_distance_quote, resolve_gate_target, resolve_manual_target, set_manual_receiver, should_lock_input, teleport_player, toggle_state, transfer, transfer_valid, update, update_distance_snapshot, update_energy, update_gui, update_input_lock, update_player_guis, update_player_permissions, update_receiver_selection, update_renders, update_wire_proxy_signals, used_remote
-- storage_roots: storage.ei
-- gui_ids: ei-gate-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, gate topology changes
--==============================================================================
local model = {}
ei_rng = require("lib/rng")
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local ei_surface_anchor = require("lib/surface-anchor")
local clamp = ei_lib.clamp
local get_entity_unit_number = ei_lib.get_entity_unit_number

local function get_gate_storage_entry(gate)
    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit or not storage.ei or not storage.ei.gate or not storage.ei.gate.gate then
        return nil, gate_unit
    end

    return storage.ei.gate.gate[gate_unit], gate_unit
end

local LOW_POWER_J = 100 * 1e9
local SIGNAL_GATE_DESTINATION = {type = "virtual", name = "signal-D", quality = "normal"}
local SIGNAL_GATE_ENABLE = {type = "virtual", name = "signal-E", quality = "normal"}
local SIGNAL_RECEIVER_ID = {type = "virtual", name = "signal-I", quality = "normal"}
local SIGNAL_GATE_ACTIVE = {type = "virtual", name = "ei-gate-active", quality = "normal"}
local SIGNAL_GATE_ENERGY = {type = "virtual", name = "ei-gate-energy", quality = "normal"}
local SIGNAL_GATE_STRESS = {type = "virtual", name = "ei-gate-stress", quality = "normal"}
local GATE_WIRE_PROXY_NAME = "ei-gate-circuit-interface"
local GATE_WIRE_PROXY_OFFSET = {x = 0, y = 0.75}
local GATE_WIRE_SCAN_INTERVAL_TICKS = 60
local GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION = 1
local MAX_GATE_STRESS = 100
local MAX_RECEIVER_SATURATION = 100
local RESIDUE_THRESHOLD = 250
local STRESS_DECAY_PER_SECOND = 1
local RECEIVER_SATURATION_DECAY_PER_SECOND = 1.5
local GATE_ARMED_UPKEEP_W = 30 * 1e6
local GATE_STRESS_UPKEEP_W = 1.5 * 1e6
local GATE_COOLDOWN_UPKEEP_W = 30 * 1e6
local GATE_DISTANCE_SAME_SURFACE_MULT = 0.15
local GATE_DISTANCE_SAME_LOCATION_CROSS_SURFACE_MULT = 2.5
local GATE_DISTANCE_UNKNOWN_INTERSURFACE_MULT = 3.0
local GATE_DISTANCE_INTERLOCATION_MIN_MULT = 2.5
local GATE_DISTANCE_INTERLOCATION_MAX_MULT = 8.0
local GATE_DISTANCE_INTERLOCATION_CURVE_EXPONENT = 0.6
local GATE_TRANSFER_STRESS_CAP = 35
local GATE_DISTANCE_STRESS_MAX_MULT = 1.75
local GATE_TENDRIL_STRESS_FLOOR = 60
local GATE_TENDRIL_MIN_INTERVAL_TICKS = 30
local GATE_TENDRIL_CHANCE_PER_SECOND_AT_FLOOR = 0.1
local GATE_TENDRIL_CHANCE_PER_SECOND_AT_MAX = 0.7
local GATE_TENDRIL_TARGET_RADIUS = 18
local GATE_TENDRIL_DAMAGE_MIN = 20
local GATE_TENDRIL_DAMAGE_MAX = 65
local GATE_TENDRIL_DAMAGE_RADIUS = 0.85
local GATE_TENDRIL_SOURCE_OFFSETS = {
    {x = -3.55, y = -2.95},
    {x = -4.15, y = -0.85},
    {x = -3.55, y = 1.25},
    {x = 3.55, y = -2.95},
    {x = 4.15, y = -0.85},
    {x = 3.55, y = 1.25},
}
local GATE_ANIMATION_LIGHT_COLORS = {
    {r = 0, g = 0.4, b = 1.0},
    {r = 0.4, g = 0.2, b = 1.0},
    {r = 0.2, g = 0.2, b = 1.0},
    {r = 0.4, g = 0.1, b = 0.8},
}
local GATE_RUNTIME_STATUS_STABLE_TEXT = {"exotic-industries.gate-gui-runtime-stable"}
local GATE_RUNTIME_STATUS_COOLING_TEXT = {"exotic-industries.gate-gui-runtime-cooling"}
local GATE_RUNTIME_STATUS_CRITICAL_TEXT = {"exotic-industries.gate-gui-runtime-critical"}
local GATE_RECEIVER_STRAIN_LOW_TEXT = {"exotic-industries.gate-gui-receiver-strain-low"}
local GATE_RECEIVER_STRAIN_MEDIUM_TEXT = {"exotic-industries.gate-gui-receiver-strain-medium"}
local GATE_RECEIVER_STRAIN_HIGH_TEXT = {"exotic-industries.gate-gui-receiver-strain-high"}
local GATE_RECEIVER_STRAIN_SATURATED_TEXT = {"exotic-industries.gate-gui-receiver-strain-saturated"}
local GATE_CONTROL_SOURCE_MANUAL_TEXT = {"exotic-industries.gate-gui-control-source-manual"}
local GATE_CONTROL_SOURCE_CIRCUIT_TEXT = {"exotic-industries.gate-gui-control-source-circuit"}
local GATE_STATE_ON_CAPTION = {"exotic-industries.gate-gui-control-state-button", "ON"}
local GATE_STATE_OFF_CAPTION = {"exotic-industries.gate-gui-control-state-button", "OFF"}
local GATE_CAMERA_FALLBACK_POSITION = {x = 0, y = 0}
local GATE_SPAN_UNRESOLVED_CAPTION = {"exotic-industries.gate-gui-status-span-unresolved"}
local GATE_SPAN_UNRESOLVED_TOOLTIP = {"exotic-industries.gate-gui-status-span-tooltip-unresolved"}
local GATE_LEGACY_STATUS_NONE = {"exotic-industries.gate-gui-legacy-none"}
local EMPTY_GUI_TAGS = {}
local GATE_RED_CONNECTOR_IDS = {
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.combinator_output_red,
    defines.wire_connector_id.combinator_input_red,
}
local GATE_GREEN_CONNECTOR_IDS = {
    defines.wire_connector_id.circuit_green,
    defines.wire_connector_id.combinator_output_green,
    defines.wire_connector_id.combinator_input_green,
}
local migrate_wire_proxy_connections_to_container


local function make_gate_gui_projection_signature(data)
    local preview_pos = data.preview_pos
    local parts = {
        data.gate_unit or 0,
        data.energy_mj_text or "",
        data.energy / data.max_energy,
        data.span_resolved and 1 or 0,
        data.span_target_surface_index or 0,
        data.span_multiplier_raw or 0,
        data.span_distance_raw or 0,
        data.span_value or 0,
        data.stress or 0,
        data.stress_ratio or 0,
        data.receiver_dropdown_generation or 0,
        data.receiver_dropdown_variant or "normal",
        data.receiver_dropdown_variant_id or 0,
        data.selected_index or 0,
        data.legacy_status_mode or "none",
        data.legacy_surface or "",
        data.legacy_x or 0,
        data.legacy_y or 0,
        data.control_source_mode or "manual",
        data.runtime_status_mode or "stable",
        data.receiver_strain_mode or "low",
        data.preview_surface_index or 0,
        preview_pos and preview_pos.x or GATE_CAMERA_FALLBACK_POSITION.x,
        preview_pos and preview_pos.y or GATE_CAMERA_FALLBACK_POSITION.y,
        data.state and 1 or 0,
    }

    for index = 1, #parts do
        parts[index] = tostring(parts[index])
    end

    return table.concat(parts, "|")
end

--====================================================================================================
-- GATE
--====================================================================================================
-- Runtime overview:
-- - `ei-gate` is the invisible EEI and main energy store.
-- - `ei-gate-container` is the visible source inventory, GUI anchor, and circuit input point.
-- - `ei-gate-circuit-interface` is the hidden constant combinator that exports telemetry.
-- - `ei-gate-receiver` is the explicit destination endpoint for all new routing.
--
-- The gate should behave like an expensive burst-transfer device, not a passive logistics
-- backbone. The control script therefore layers three concerns on top of basic transport:
-- route resolution, transfer quoting/payment, and post-transfer penalties.

-- Legacy compatibility for older call sites that still ask for a "player" energy toll.
model.energy_costs = {
    ["player"] = 10,
    ["item"] = 1
}

-- Legacy raw surface pairing is kept only so pre-receiver saves still load and function until
-- the player explicitly migrates that gate to a receiver ID.
model.inverse_surface = {
    ["gaia"] = "nauvis",
    ["nauvis"] = "gaia"
}
model.mass_weights = {
    -- base
    ["active-provider-chest"] = 4,
    ["advanced-circuit"] = 1,
    ["arithmetic-combinator"] = 4,
    ["artillery-shell"] = 100,
    ["artillery-targeting-remote"] = 50,
    ["artillery-turret"] = 25,
    ["artillery-wagon"] = 200,
    ["atomic-bomb"] = 25,
    ["barrel"] = 200,
    ["battery"] = 2,
    ["battery-equipment"] = 25,
    ["battery-mk2-equipment"] = 25,
    ["belt-immunity-equipment"] = 10,
    ["big-electric-pole"] = 10,
    ["blueprint"] = 1,
    ["blueprint-book"] = 1,
    ["boiler"] = 25,
    ["buffer-chest"] = 4,
    ["bulk-inserter"] = 4,
    ["burner-inserter"] = 4,
    ["burner-mining-drill"] = 10,
    ["cannon-shell"] = 2,
    ["car"] = 200,
    ["cargo-landing-pad"] = 500,
    ["cb_alien_cold_extract-barrel"] = 200,
    ["cliff-explosives"] = 10,
    ["cluster-grenade"] = 2,
    ["coal"] = 4,
    ["concrete"] = 2,
    ["constant-combinator"] = 4,
    ["construction-robot"] = 4,
    ["copper-cable"] = 1,
    ["copper-wire"] = 50,
    ["crude-oil-barrel"] = 200,
    ["decider-combinator"] = 4,
    ["deconstruction-planner"] = 1,
    ["defender-capsule"] = 2,
    ["destroyer-capsule"] = 2,
    ["discharge-defense-equipment"] = 10,
    ["discharge-defense-remote"] = 50,
    ["display-panel"] = 4,
    ["distractor-capsule"] = 2,
    ["ee-infinity-accumulator"] = 10,
    ["ee-infinity-cargo-wagon"] = 200,
    ["ee-infinity-fission-reactor-equipment"] = 4,
    ["ee-infinity-fluid-wagon"] = 200,
    ["ee-infinity-heat-pipe"] = 4,
    ["ee-infinity-loader"] = 4,
    ["ee-infinity-pipe"] = 4,
    ["ee-linked-belt"] = 4,
    ["ee-super-battery-equipment"] = 10,
    ["ee-super-beacon"] = 25,
    ["ee-super-construction-robot"] = 4,
    ["ee-super-electric-pole"] = 10,
    ["ee-super-energy-shield-equipment"] = 4,
    ["ee-super-exoskeleton-equipment"] = 4,
    ["ee-super-fuel"] = 4,
    ["ee-super-inserter"] = 4,
    ["ee-super-lab"] = 25,
    ["ee-super-locomotive"] = 200,
    ["ee-super-logistic-robot"] = 4,
    ["ee-super-night-vision-equipment"] = 4,
    ["ee-super-personal-roboport-equipment"] = 4,
    ["ee-super-pump"] = 10,
    ["ee-super-radar"] = 25,
    ["ee-super-roboport"] = 50,
    ["ee-super-substation"] = 10,
    ["electric-engine-unit"] = 4,
    ["electric-furnace"] = 25,
    ["electronic-circuit"] = 1,
    ["energy-shield-equipment"] = 10,
    ["energy-shield-mk2-equipment"] = 10,
    ["engine-unit"] = 4,
    ["explosive-cannon-shell"] = 2,
    ["explosive-rocket"] = 2,
    ["explosive-uranium-cannon-shell"] = 2,
    ["explosives"] = 2,
    ["express-splitter"] = 10,
    ["express-transport-belt"] = 4,
    ["express-underground-belt"] = 4,
    ["fast-inserter"] = 4,
    ["fast-splitter"] = 10,
    ["fast-transport-belt"] = 4,
    ["fast-underground-belt"] = 4,
    ["firearm-magazine"] = 2,
    ["fission-reactor-equipment"] = 10,
    ["flamethrower"] = 10,
    ["flamethrower-ammo"] = 2,
    ["flamethrower-turret"] = 10,
    ["flying-robot-frame"] = 4,
    ["gate"] = 25,
    ["green-wire"] = 50,
    ["grenade"] = 2,
    ["hazard-concrete"] = 2,
    ["heavy-armor"] = 10,
    ["heavy-oil-barrel"] = 200,
    ["inserter"] = 4,
    ["iron-chest"] = 4,
    ["lab"] = 25,
    ["land-mine"] = 4,
    ["landfill"] = 2,
    ["laser-turret"] = 10,
    ["light-armor"] = 10,
    ["light-oil-barrel"] = 200,
    ["logistic-robot"] = 4,
    ["long-handed-inserter"] = 4,
    ["low-density-structure"] = 4,
    ["lubricant-barrel"] = 200,
    ["medium-electric-pole"] = 4,
    ["modding_radar"] = 25,
    ["modular-armor"] = 25,
    ["night-vision-equipment"] = 10,
    ["nuclear-reactor"] = 100,
    ["offshore-pump"] = 10,
    ["passive-provider-chest"] = 4,
    ["petroleum-gas-barrel"] = 200,
    ["piercing-rounds-magazine"] = 2,
    ["piercing-shotgun-shell"] = 2,
    ["pipe"] = 4,
    ["pipe-to-ground"] = 4,
    ["piranha-solution-barrel"] = 200,
    ["plastic-bar"] = 2,
    ["poison-capsule"] = 2,
    ["power-armor"] = 25,
    ["power-armor-mk2"] = 100,
    ["power-switch"] = 10,
    ["processing-unit"] = 1,
    ["programmable-speaker"] = 4,
    ["pump"] = 10,
    ["radar"] = 25,
    ["rail"] = 2,
    ["rail-chain-signal"] = 4,
    ["rail-signal"] = 4,
    ["raw-fish"] = 2,
    ["red-wire"] = 50,
    ["refined-concrete"] = 2,
    ["refined-hazard-concrete"] = 2,
    ["repair-pack"] = 1,
    ["requester-chest"] = 4,
    ["roboport"] = 50,
    ["rocket"] = 2,
    ["rocket-fuel"] = 25,
    ["rocket-launcher"] = 10,
    ["rocket-silo"] = 500,
    ["rp-steam-pump"] = 10,
    ["selector-combinator"] = 4,
    ["shotgun-shell"] = 2,
    ["slowdown-capsule"] = 2,
    ["small-electric-pole"] = 4,
    ["small-lamp"] = 4,
    ["solid-fuel"] = 10,
    ["spidertron"] = 200,
    ["spidertron-remote"] = 1,
    ["ei-gaian-saucer"] = 240,
    ["splitter"] = 10,
    ["steam-engine"] = 50,
    ["steam-turbine"] = 50,
    ["steel-chest"] = 4,
    ["steel-furnace"] = 10,
    ["stone"] = 10,
    ["stone-brick"] = 4,
    ["stone-furnace"] = 10,
    ["storage-chest"] = 4,
    ["storage-tank"] = 25,
    ["substation"] = 10,
    ["sulfur"] = 4,
    ["sulfuric-acid-barrel"] = 200,
    ["tank"] = 200,
    ["train-stop"] = 4,
    ["transport-belt"] = 4,
    ["underground-belt"] = 4,
    ["upgrade-planner"] = 1,
    ["uranium-235"] = 4,
    ["uranium-238"] = 4,
    ["uranium-cannon-shell"] = 2,
    ["uranium-fuel-cell"] = 10,
    ["uranium-ore"] = 10,
    ["uranium-rounds-magazine"] = 2,
    ["water-barrel"] = 200,
    ["wood"] = 2,
    ["wooden-chest"] = 4,
    -- dependency mods
    ["accumulator"] = 10,
    ["assembling-machine-1"] = 25,
    ["assembling-machine-2"] = 25,
    ["assembling-machine-3"] = 25,
    ["atan-air-scrubber"] = 25,
    ["atan-ash"] = 2,
    ["atan-pollution-filter"] = 4,
    ["atan-spore-filter"] = 4,
    ["atan-used-pollution-filter"] = 4,
    ["atan-used-spore-filter"] = 4,
    ["cb-coldjet-ammo"] = 2,
    ["cb-modular-armor"] = 25,
    ["cb-power-armor"] = 25,
    ["cb-power-armor-mk2"] = 100,
    ["cb_alien_cold_artifact"] = 4,
    ["cb_alien_cold_gland"] = 4,
    ["chcs-heliostat-mirror"] = 25,
    ["chcs-solar-laser-tower"] = 100,
    ["chcs-solar-power-tower"] = 100,
    ["cold-capsule"] = 2,
    ["cold-jetthrower-rifle"] = 10,
    ["data-dd-flare-capsule"] = 10,
    ["elevated-pipe"] = 4,
    ["extinguisher"] = 10,
    ["extinguisher-ammo"] = 2,
    ["fe_resonance_shard"] = 50,
    ["pc-pollution-combinator"] = 4,
    ["quality-module"] = 1,
    ["quality-module-2"] = 1,
    ["quality-module-3"] = 1,
    ["rail-ramp"] = 25,
    ["rail-support"] = 25,
    ["recycler"] = 25,
    ["rp-steam-calculator"] = 4,
    ["rp-steam-construction-bot"] = 4,
    ["rp-steam-logistic-bot"] = 4,
    ["rp-steam-logistic-chest-active-provider"] = 10,
    ["rp-steam-logistic-chest-buffer"] = 10,
    ["rp-steam-logistic-chest-passive-provider"] = 10,
    ["rp-steam-logistic-chest-requester"] = 10,
    ["rp-steam-logistic-chest-storage"] = 10,
    ["rp-steam-piston"] = 4,
    ["rp-steam-roboport"] = 50,
    ["rp-steam-soul"] = 4,
    ["tl-tesla-coil-ammo"] = 1,
    ["tl-tesla-tank"] = 200,
    ["zeus-wrath-lightning-ammo"] = 4,
    ["zeus-wrath-zeus-gun"] = 10,
    ["zeus-wrath-zeus-turret"] = 100,
    -- space-age
    ["agricultural-tower"] = 25,
    ["asteroid-collector"] = 25,
    ["battery-mk3-equipment"] = 25,
    ["big-mining-drill"] = 100,
    ["biochamber"] = 25,
    ["bioflux"] = 2,
    ["biolab"] = 100,
    ["biter-egg"] = 2,
    ["calcite"] = 4,
    ["captive-biter-spawner"] = 100,
    ["capture-robot-rocket"] = 25,
    ["carbon"] = 4,
    ["carbon-fiber"] = 2,
    ["carbonic-asteroid-chunk"] = 200,
    ["cargo-bay"] = 50,
    ["copper-bacteria"] = 2,
    ["crusher"] = 10,
    ["cryogenic-plant"] = 100,
    ["electromagnetic-plant"] = 50,
    ["fluoroketone-cold-barrel"] = 200,
    ["fluoroketone-hot-barrel"] = 200,
    ["foundation"] = 4,
    ["foundry"] = 100,
    ["fusion-generator"] = 50,
    ["fusion-power-cell"] = 4,
    ["fusion-reactor"] = 500,
    ["fusion-reactor-equipment"] = 10,
    ["heating-tower"] = 25,
    ["holmium-ore"] = 10,
    ["holmium-plate"] = 2,
    ["ice"] = 4,
    ["ice-platform"] = 2,
    ["iron-bacteria"] = 2,
    ["jelly"] = 2,
    ["jellynut"] = 4,
    ["jellynut-seed"] = 10,
    ["lithium"] = 4,
    ["lithium-plate"] = 2,
    ["mech-armor"] = 100,
    ["metallic-asteroid-chunk"] = 200,
    ["nutrients"] = 1,
    ["oxide-asteroid-chunk"] = 200,
    ["pentapod-egg"] = 10,
    ["promethium-asteroid-chunk"] = 200,
    ["quantum-processor"] = 1,
    ["railgun"] = 10,
    ["railgun-ammo"] = 25,
    ["railgun-turret"] = 50,
    ["rocket-turret"] = 25,
    ["scrap"] = 4,
    ["ei-gaia-relic-debris"] = 6,
    ["space-platform-foundation"] = 2,
    ["space-platform-starter-pack"] = 1000,
    ["spoilage"] = 1,
    ["stack-inserter"] = 4,
    ["supercapacitor"] = 1,
    ["superconductor"] = 1,
    ["tesla-ammo"] = 2,
    ["tesla-turret"] = 50,
    ["teslagun"] = 10,
    ["thruster"] = 50,
    ["toolbelt-equipment"] = 10,
    ["tree-seed"] = 4,
    ["tungsten-carbide"] = 4,
    ["tungsten-ore"] = 10,
    ["tungsten-plate"] = 4,
    ["turbo-splitter"] = 10,
    ["turbo-transport-belt"] = 4,
    ["turbo-underground-belt"] = 4,
    ["yumako"] = 4,
    ["yumako-mash"] = 2,
    ["yumako-seed"] = 10,
    -- exotic
    ["agricultural-science-pack"] = 1,
    ["artificial-jellynut-soil"] = 2,
    ["artificial-yumako-soil"] = 2,
    ["beacon"] = 25,
    ["cargo-wagon"] = 200,
    ["centrifuge"] = 25,
    ["chemical-plant"] = 25,
    ["combat-shotgun"] = 10,
    ["copper-plate"] = 2,
    ["cryogenic-science-pack"] = 1,
    ["depleted-uranium-fuel-cell"] = 25,
    ["efficiency-module"] = 1,
    ["efficiency-module-2"] = 1,
    ["efficiency-module-3"] = 1,
    ["ei-1x1-container"] = 10,
    ["ei-1x1-container-blue"] = 10,
    ["ei-1x1-container-filter"] = 10,
    ["ei-1x1-container-green"] = 10,
    ["ei-1x1-container-pink"] = 10,
    ["ei-1x1-container-red"] = 10,
    ["ei-1x1-container-yellow"] = 10,
    ["ei-2x2-container"] = 25,
    ["ei-2x2-container-blue"] = 25,
    ["ei-2x2-container-filter"] = 25,
    ["ei-2x2-container-green"] = 25,
    ["ei-2x2-container-pink"] = 25,
    ["ei-2x2-container-red"] = 25,
    ["ei-2x2-container-yellow"] = 25,
    ["ei-6x6-container"] = 200,
    ["ei-6x6-container-blue"] = 200,
    ["ei-6x6-container-filter"] = 200,
    ["ei-6x6-container-green"] = 200,
    ["ei-6x6-container-pink"] = 200,
    ["ei-6x6-container-red"] = 200,
    ["ei-6x6-container-yellow"] = 200,
    ["ei-accelerator"] = 500,
    ["ei-acidic-water-barrel"] = 200,
    ["ei-acidthrower-turret"] = 10,
    ["ei-advanced-base-semiconductor"] = 2,
    ["ei-advanced-bot-engine"] = 4,
    ["ei-advanced-cargo-wagon"] = 25,
    ["ei-advanced-centrifuge"] = 100,
    ["ei-advanced-chem-plant"] = 100,
    ["ei-advanced-computer-age-tech"] = 1,
    ["ei-advanced-construction-bot"] = 10,
    ["ei-advanced-crusher"] = 25,
    ["ei-advanced-deep-drill"] = 100,
    ["ei-advanced-destill-tower"] = 25,
    ["ei-advanced-electric-mining-drill"] = 25,
    ["ei-advanced-logistic-bot"] = 10,
    ["ei-advanced-motor"] = 4,
    ["ei-advanced-port"] = 500,
    ["ei-advanced-refinery"] = 500,
    ["ei-advanced-rocket-fuel"] = 50,
    ["ei-advanced-semiconductor"] = 2,
    ["ei-alien-beacon"] = 500,
    ["ei-alien-beacon-repair"] = 1,
    ["ei-alien-beacon_off-1"] = 500,
    ["ei-alien-computer-age-tech"] = 1,
    ["ei-alien-flowers-1"] = 100,
    ["ei-alien-resin"] = 4,
    ["ei-alien-seed"] = 500,
    ["ei-alien-stabilizer"] = 50,
    ["ei-ammonia-gas-barrel"] = 200,
    ["ei-arc-furnace"] = 100,
    ["ei-auto-shotgun-turret"] = 10,
    ["ei-basic-heat-exchanger"] = 25,
    ["ei-basic-heat-pipe"] = 4,
    ["ei-benzol-barrel"] = 200,
    ["ei-big-inserter-normal"] = 10,
    ["ei-big-lab"] = 500,
    ["ei-big-turbine"] = 500,
    ["ei-bio-armor"] = 10,
    ["ei-bio-chamber"] = 25,
    ["ei-bio-matter"] = 25,
    ["ei-bio-oil-barrel"] = 200,
    ["ei-bio-reactor"] = 100,
    ["ei-bio-sludge-barrel"] = 200,
    ["ei-black-hole"] = 500,
    ["ei-black-hole-data"] = 1,
    ["ei-black-hole-exotic-age-tech"] = 1,
    ["ei-blooming-alien-seed"] = 500,
    ["ei-blooming-evolved-alien-seed"] = 2,
    ["ei-breach-residue"] = 10,
    ["ei-bug-zapper"] = 100,
    ["ei-bug-zapper-remote"] = 50,
    ["ei-burner-assembler"] = 25,
    ["ei-burner-heater"] = 25,
    ["ei-burner-quarry"] = 10,
    ["ei-burner-surface-harvester"] = 25,
    ["ei-camp-fire"] = 25,
    ["ei-cannon-turret"] = 25,
    ["ei-cannon-turret-mk1"] = 10,
    ["ei-carbon"] = 2,
    ["ei-carbon-nanotube"] = 2,
    ["ei-carbon-structure"] = 25,
    ["ei-cargo-bot"] = 4,
    ["ei-caster"] = 25,
    ["ei-castor"] = 25,
    ["ei-cavity"] = 25,
    ["ei-ceramic"] = 2,
    ["ei-charcoal"] = 4,
    ["ei-charged-grenade"] = 2,
    ["ei-charged-neutron-container"] = 4,
    ["ei-chemical-asteroid-chunk"] = 200,
    ["ei-chrono-fossil-shard"] = 2,
    ["ei-circuit-board"] = 1,
    ["ei-clean-plating"] = 2,
    ["ei-coal-chunk"] = 4,
    ["ei-coal-gas-barrel"] = 200,
    ["ei-coke"] = 4,
    ["ei-coke-furnace"] = 10,
    ["ei-coke-pellets"] = 4,
    ["ei-cold-coolant-barrel"] = 200,
    ["ei-combustion-turbine"] = 500,
    ["ei-compound-ammo"] = 2,
    ["ei-corrosive-ammo"] = 2,
    ["ei-computer-age-tech"] = 1,
    ["ei-computer-core"] = 100,
    ["ei-computing-unit"] = 4,
    ["ei-concentrated-morphium-barrel"] = 200,
    ["ei-condensed-cryodust"] = 2,
    ["ei-construction-bot"] = 10,
    ["ei-cooler"] = 100,
    ["ei-copper-beacon"] = 25,
    ["ei-copper-beam"] = 2,
    ["ei-copper-chunk"] = 4,
    ["ei-copper-mechanical-parts"] = 2,
    ["ei-cpu"] = 4,
    ["ei-critical-steam-barrel"] = 200,
    ["ei-crushed-coal"] = 2,
    ["ei-crushed-coke"] = 2,
    ["ei-crushed-copper"] = 2,
    ["ei-crushed-gold"] = 2,
    ["ei-crushed-iron"] = 2,
    ["ei-crushed-neodym"] = 2,
    ["ei-crushed-pure-uranium"] = 2,
    ["ei-crushed-sulfur"] = 2,
    ["ei-crushed-uranium"] = 2,
    ["ei-crusher"] = 25,
    ["ei-cryo-ammo"] = 2,
    ["ei-cryo-container-nitrogen"] = 10,
    ["ei-cryo-container-oxygen"] = 10,
    ["ei-cryocondensate"] = 10,
    ["ei-cryodust"] = 2,
    ["ei-cryoflux-barrel"] = 200,
    ["ei-crystal-accumulator"] = 50,
    ["ei-crystal-accumulator-gaia"] = 50,
    ["ei-crystal-accumulator-repair"] = 1,
    ["ei-crystal-accumulator_off-1"] = 125,
    ["ei-crystal-accumulator_off-2"] = 125,
    ["ei-crystal-accumulator_off-3"] = 125,
    ["ei-crystal-accumulator_off-4"] = 125,
    ["ei-crystal-solution-barrel"] = 200,
    ["ei-dark-age-lab"] = 25,
    ["ei-dark-age-tech"] = 1,
    ["ei-data-pipe"] = 4,
    ["ei-deep-drill"] = 100,
    ["ei-deep-pumpjack"] = 100,
    ["ei-destill-tower"] = 25,
    ["ei-deuterium-barrel"] = 200,
    ["ei-diesel-barrel"] = 200,
    ["ei-diesel-fuel-unit"] = 50,
    ["ei-diesel-fuel-unit-empty"] = 50,
    ["ei-diluted-morphium-barrel"] = 200,
    ["ei-dinitrogen-tetroxide-gas-barrel"] = 200,
    ["ei-dinitrogen-tetroxide-water-solution-barrel"] = 200,
    ["ei-dirty-water-barrel"] = 200,
    ["ei-dragons-breath-shotgun-shell"] = 2,
    ["ei-drill-fluid-barrel"] = 200,
    ["ei-dt-mix"] = 2,
    ["ei-efficiency-module-4"] = 1,
    ["ei-efficiency-module-5"] = 1,
    ["ei-efficiency-module-6"] = 1,
    ["ei-electric-quarry"] = 25,
    ["ei-electric-surface-harvester"] = 25,
    ["ei-electricity-age-tech"] = 1,
    ["ei-electron-tube"] = 2,
    ["ei-electronic-parts"] = 1,
    ["ei-empty-cryo-container"] = 10,
    ["ei-energy-crystal"] = 4,
    ["ei-energy-extractor-pylon"] = 100,
    ["ei-energy-injector-pylon"] = 100,
    ["ei-enriched-cryodust"] = 2,
    ["ei-eu-circuit"] = 1,
    ["ei-eu-magnet"] = 2,
    ["ei-evolved-alien-seed"] = 2,
    ["ei-excavator"] = 500,
    ["ei-exchanger"] = 25,
    ["ei-exotic-age-tech"] = 1,
    ["ei-exotic-assembler"] = 25,
    ["ei-exotic-matter-down"] = 2,
    ["ei-exotic-matter-up"] = 2,
    ["ei-exotic-ore"] = 10,
    ["ei-express-loader"] = 4,
    ["ei-farstation"] = 200,
    ["ei-farstation-repair"] = 2,
    ["ei-farstation_off-1"] = 100,
    ["ei-fast-loader"] = 4,
    ["ei-faulty-advanced-semiconductor"] = 2,
    ["ei-faulty-semiconductor"] = 2,
    ["ei-fission-facility"] = 100,
    ["ei-fission-tech"] = 1,
    ["ei-fluid-boiler"] = 25,
    ["ei-fluid-heater"] = 25,
    ["ei-fluorite"] = 2,
    ["ei-fueler"] = 50,
    ["ei-fusion-data"] = 1,
    ["ei-fusion-drive"] = 2,
    ["ei-fusion-quantum-age-tech"] = 1,
    ["ei-fusion-reactor"] = 500,
    ["ei-gaia-pump"] = 10,
    ["ei-gate"] = 1000,
    ["ei-gate-receiver"] = 500,
    ["ei-gatling-turret"] = 25,
    ["ei-gauss-module"] = 1,
    ["ei-glass"] = 2,
    ["ei-gluon-cavity"] = 25,
    ["ei-gold-chunk"] = 4,
    ["ei-gold-ingot"] = 2,
    ["ei-gravity-braided-ore"] = 4,
    ["ei-grower"] = 100,
    ["ei-heat-chemical-plant"] = 25,
    ["ei-heat-steel-furnace"] = 10,
    ["ei-heavy-destilate-barrel"] = 200,
    ["ei-heavy-minigun"] = 10,
    ["ei-hexafluoride-ammo"] = 2,
    ["ei-helium-3-barrel"] = 200,
    ["ei-high-energy-crystal"] = 4,
    ["ei-high-tech-parts"] = 2,
    ["ei-high-temperature-reactor"] = 100,
    ["ei-holo-asteroid"] = 10,
    ["ei-holo-black-hole"] = 10,
    ["ei-holo-galaxy"] = 10,
    ["ei-holo-gas-giant"] = 10,
    ["ei-holo-mars"] = 10,
    ["ei-holo-moon"] = 10,
    ["ei-holo-nauvis-orbit"] = 10,
    ["ei-holo-sulf"] = 10,
    ["ei-holo-sun"] = 10,
    ["ei-holo-uran"] = 10,
    ["ei-hot-coolant-barrel"] = 200,
    ["ei-hydrofluoric-acid-barrel"] = 200,
    ["ei-hydrogen-gas-barrel"] = 200,
    ["ei-induction-matrix-advanced-coil"] = 4,
    ["ei-induction-matrix-advanced-converter"] = 10,
    ["ei-induction-matrix-advanced-solenoid"] = 4,
    ["ei-induction-matrix-basic-coil"] = 4,
    ["ei-induction-matrix-basic-converter"] = 10,
    ["ei-induction-matrix-basic-solenoid"] = 4,
    ["ei-induction-matrix-core"] = 10,
    ["ei-induction-matrix-superior-coil"] = 4,
    ["ei-induction-matrix-superior-converter"] = 10,
    ["ei-induction-matrix-tile"] = 4,
    ["ei-insulated-pipe"] = 4,
    ["ei-insulated-tank"] = 25,
    ["ei-insulated-underground-pipe"] = 4,
    ["ei-insulated-wire"] = 2,
    ["ei-iron-beacon"] = 25,
    ["ei-iron-beam"] = 2,
    ["ei-iron-chunk"] = 4,
    ["ei-iron-mechanical-parts"] = 2,
    ["ei-isotopic-ghost-shell"] = 2,
    ["ei-kerosene-barrel"] = 200,
    ["ei-lead-chunk"] = 4,
    ["ei-lead-ingot"] = 2,
    ["ei-lithium-6-barrel"] = 200,
    ["ei-lithium-7-barrel"] = 200,
    ["ei-lithium-crystal"] = 4,
    ["ei-loader"] = 4,
    ["ei-lube-destilate-barrel"] = 200,
    ["ei-lufter"] = 25,
    ["ei-magnet"] = 2,
    ["ei-magnet-data"] = 1,
    ["ei-matter-stabilizer"] = 100,
    ["ei-mechanical-inserter"] = 4,
    ["ei-mechanical-long-inserter"] = 4,
    ["ei-medium-destilate-barrel"] = 200,
    ["ei-metalworks-1"] = 10,
    ["ei-metalworks-2"] = 10,
    ["ei-metalworks-3"] = 10,
    ["ei-metalworks-4"] = 10,
    ["ei-minigun"] = 10,
    ["ei-morphium-ammo"] = 2,
    ["ei-module-base"] = 4,
    ["ei-module-part"] = 4,
    ["ei-monosilicon"] = 2,
    ["ei-morphium-barrel"] = 200,
    ["ei-nano-factory"] = 100,
    ["ei-neo-assembler"] = 25,
    ["ei-neo-belt"] = 4,
    ["ei-neo-loader"] = 4,
    ["ei-neo-splitter"] = 10,
    ["ei-neo-underground-belt"] = 4,
    ["ei-neodym-chunk"] = 10,
    ["ei-neodym-ingot"] = 2,
    ["ei-neodym-solution-barrel"] = 200,
    ["ei-neuro-reactive-residue"] = 2,
    ["ei-neutron-ammo"] = 2,
    ["ei-neutron-activator"] = 25,
    ["ei-neutron-collector"] = 25,
    ["ei-neutron-container"] = 10,
    ["ei-nitric-acid-barrel"] = 200,
    ["ei-nitric-acid-plutonium-239-barrel"] = 200,
    ["ei-nitric-acid-thorium-232-barrel"] = 200,
    ["ei-nitric-acid-uranium-233-barrel"] = 200,
    ["ei-nitric-acid-uranium-235-barrel"] = 200,
    ["ei-nitrogen-gas-barrel"] = 200,
    ["ei-nuclear-locomotive"] = 25,
    ["ei-nuclear-waste"] = 100,
    ["ei-odd-plating"] = 2,
    ["ei-oxyfluoride-ammo"] = 2,
    ["ei-orbital-combinator"] = 4,
    ["ei-organic-asteroid-chunk"] = 200,
    ["ei-oxygen-difluoride-barrel"] = 200,
    ["ei-oxygen-gas-barrel"] = 200,
    ["ei-personal-laser"] = 10,
    ["ei-personal-leg"] = 10,
    ["ei-personal-reactor"] = 100,
    ["ei-personal-shield"] = 25,
    ["ei-personal-solar-2"] = 10,
    ["ei-personal-solar-3"] = 10,
    ["ei-petrified-asteroid-chunk"] = 200,
    ["ei-photon-cavity"] = 25,
    ["ei-phythogas-barrel"] = 200,
    ["ei-plasma-cube"] = 25,
    ["ei-plasma-data"] = 1,
    ["ei-plasma-heater"] = 100,
    ["ei-plasma-turret"] = 100,
    ["ei-plutonium-239"] = 4,
    ["ei-plutonium-239-fuel"] = 50,
    ["ei-poor-copper-chunk"] = 4,
    ["ei-poor-iron-chunk"] = 4,
    ["ei-poor-uranium-chunk"] = 4,
    ["ei-pre-circuit-board"] = 1,
    ["ei-productivity-module-4"] = 1,
    ["ei-productivity-module-5"] = 1,
    ["ei-productivity-module-6"] = 1,
    ["ei-protium-barrel"] = 200,
    ["ei-pure-copper"] = 2,
    ["ei-pure-crushed-neodym"] = 2,
    ["ei-pure-gold"] = 2,
    ["ei-pure-iron"] = 2,
    ["ei-pure-lead"] = 2,
    ["ei-purifier"] = 100,
    ["ei-quantum-age-tech"] = 1,
    ["ei-quantum-computer"] = 500,
    ["ei-residual-oil-barrel"] = 200,
    ["ei-rift-stabilizer"] = 50,
    ["ei-rock-asteroid-chunk"] = 200,
    ["ei-rocket-control-unit"] = 2,
    ["ei-rocket-parts"] = 2,
    ["ei-sand"] = 1,
    ["ei-scrap-asteroid-chunk"] = 200,
    ["ei-semiconductor"] = 2,
    ["ei-shotgun-turret"] = 10,
    ["ei-silicon"] = 2,
    ["ei-simulation-data"] = 1,
    ["ei-simulation-data-chemical"] = 1,
    ["ei-simulation-data-organic"] = 1,
    ["ei-simulation-data-petrified"] = 1,
    ["ei-simulation-data-scrap"] = 1,
    ["ei-simulation-data-stone"] = 1,
    ["ei-simulation-data-uranium"] = 1,
    ["ei-slag"] = 2,
    ["ei-small-inserter-normal"] = 10,
    ["ei-small-simulator"] = 25,
    ["ei-solar-panel-2"] = 25,
    ["ei-solar-panel-3"] = 25,
    ["ei-space-data"] = 1,
    ["ei-spawner-tool"] = 1,
    ["ei-speed-module-4"] = 1,
    ["ei-speed-module-5"] = 1,
    ["ei-speed-module-6"] = 1,
    ["ei-sporeglass-heart"] = 2,
    ["ei-steam-advanced-fluid-wagon"] = 25,
    ["ei-steam-advanced-locomotive"] = 25,
    ["ei-steam-advanced-wagon"] = 25,
    ["ei-steam-age-tech"] = 1,
    ["ei-steam-assembler"] = 25,
    ["ei-steam-basic-locomotive"] = 25,
    ["ei-steam-basic-wagon"] = 25,
    ["ei-steam-crusher"] = 25,
    ["ei-steam-engine"] = 4,
    ["ei-steam-inserter"] = 4,
    ["ei-steam-long-inserter"] = 4,
    ["ei-steam-miner"] = 10,
    ["ei-steam-oil-pumpjack"] = 25,
    ["ei-steam-quarry"] = 10,
    ["ei-steam-surface-harvester"] = 25,
    ["ei-steampunk-lamp"] = 4,
    ["ei-steel-beam"] = 2,
    ["ei-steel-blend"] = 2,
    ["ei-steel-mechanical-parts"] = 2,
    ["ei-stone-well-pump"] = 100,
    ["ei-sulfur-chunk"] = 4,
    ["ei-superior-data"] = 1,
    ["ei-superior-electric-mining-drill"] = 25,
    ["ei-sus-plating"] = 2,
    ["ei-tank-1"] = 100,
    ["ei-tank-2"] = 500,
    ["ei-tank-3"] = 500,
    ["ei-thermal-furnace"] = 25,
    ["ei-thorium-232"] = 4,
    ["ei-thorium-232-fuel"] = 50,
    ["ei-tile-tool"] = 1,
    ["ei-tritium-barrel"] = 200,
    ["ei-turbo-loader"] = 4,
    ["ei-uranium-233"] = 4,
    ["ei-arc-ammo"] = 2,
    ["ei-uranium-233-fuel"] = 50,
    ["ei-uranium-235-fuel"] = 50,
    ["ei-uranium-asteroid-chunk"] = 200,
    ["ei-uranium-chunk"] = 4,
    ["ei-uranium-hexafluorite-barrel"] = 200,
    ["ei-uranium-solution-barrel"] = 200,
    ["ei-uranium-test-fuel"] = 50,
    ["ei-used-plutonium-239-fuel"] = 50,
    ["ei-used-thorium-232-fuel"] = 50,
    ["ei-used-uranium-233-fuel"] = 50,
    ["ei-used-uranium-235-fuel"] = 50,
    ["ei-warp-beacon"] = 100,
    ["ei-waver-factory"] = 25,
    ["ei-worm-torn-relay-core"] = 2,
    ["ei-z-boson-cavity"] = 25,
    ["ei_charger"] = 100,
    ["ei_em-cargo-wagon"] = 25,
    ["ei_em-fielder"] = 25,
    ["ei_em-fluid-wagon"] = 25,
    ["ei_em-locomotive"] = 25,
    ["electric-mining-drill"] = 25,
    ["electromagnetic-science-pack"] = 1,
    ["exoskeleton-equipment"] = 10,
    ["fluid-wagon"] = 200,
    ["gun-turret"] = 10,
    ["heat-exchanger"] = 25,
    ["heat-pipe"] = 4,
    ["iron-plate"] = 2,
    ["lightning-collector"] = 10,
    ["lightning-rod"] = 4,
    ["locomotive"] = 200,
    ["metallurgic-science-pack"] = 1,
    ["nuclear-fuel"] = 25,
    ["oil-refinery"] = 100,
    ["overgrowth-jellynut-soil"] = 2,
    ["overgrowth-yumako-soil"] = 2,
    ["personal-laser-defense-equipment"] = 10,
    ["personal-roboport-equipment"] = 10,
    ["personal-roboport-mk2-equipment"] = 10,
    ["pistol"] = 10,
    ["plated-wall"] = 4,
    ["productivity-module"] = 1,
    ["productivity-module-2"] = 1,
    ["productivity-module-3"] = 1,
    ["promethium-science-pack"] = 1,
    ["pumpjack"] = 25,
    ["shotgun"] = 10,
    ["solar-panel"] = 25,
    ["solar-panel-equipment"] = 10,
    ["space-science-pack"] = 1,
    ["speed-module"] = 1,
    ["speed-module-2"] = 1,
    ["speed-module-3"] = 1,
    ["steel-plate"] = 2,
    ["stone-wall"] = 4,
    ["submachine-gun"] = 10,
    ["tl-advanced-tesla-coil"] = 25,
    ["tl-basic-tesla-coil"] = 10,
    ["tough-wall"] = 4,
}

-- File map:
-- - receiver registry + circuit ID refresh
-- - target resolution and transport gating
-- - quoted transfer cost, stress, cooldown, residue, and scripted upkeep
-- - GUI and remote helpers

--UTIL
-----------------------------------------------------------------------------------------------------

function model.entity_check(entity)
    return ei_lib.entity_check(entity)
end


function model.check_global_init()

    if not storage.ei.gate then
        storage.ei.gate = {}
    end

    if not storage.ei.gate.gate then
        storage.ei.gate.gate = {}
    end

    if not storage.ei.gate.receiver then
        storage.ei.gate.receiver = {}
    end

    if not storage.ei.gate.receiver_by_force then
        storage.ei.gate.receiver_by_force = {}
    end

    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

    if not storage.ei.gate.open_redirect then
        storage.ei.gate.open_redirect = {}
    end

    if not storage.ei.gate.open_gui_players then
        storage.ei.gate.open_gui_players = {}
    end

    if not storage.ei.gate.gui_projection_cache then
        storage.ei.gate.gui_projection_cache = {}
    end

    if not storage.ei.gate.gui_elements_cache then
        storage.ei.gate.gui_elements_cache = {}
    end

    if storage.ei.gate.receiver_registry_dirty == nil then
        storage.ei.gate.receiver_registry_dirty = false
    end

    if storage.ei.gate.receiver_registry_generation == nil then
        storage.ei.gate.receiver_registry_generation = 0
    end

    if not storage.ei.gate.receiver_dropdown_cache then
        storage.ei.gate.receiver_dropdown_cache = {
            generation = -1,
            by_force = {},
            variants = {},
        }
    end

end


function model.get_transfer_inv(transfer)
    -- transfer is either a player index, a robot, or nil
    -- needed to prevent unregistration when the transferer cant mine due to full inv

    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        -- player index
        local player = game.get_player(transfer)
        return player and player.valid and player.get_main_inventory() or nil
    end

    if transfer.valid then
        -- robot
        local robot = transfer
        return robot.get_inventory(defines.inventory.robot_cargo)
    end

    return nil

end


function model.transfer_valid(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        -- case for when destroyed by gun f.e. -> need to unregister
        return true
    end

    -- check if target has space for gate item
    if target_inv.can_insert({name = "ei-gate", count = 1}) then
        target_inv.insert({name = "ei-gate", count = 1})
        return true
    end

    return false

end


function model.transfer(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        return
    end

    target_inv.insert({name = "ei-gate", count = 1})
end


function model.copy_exit(exit)

    if not exit then
        return nil
    end

    return {
        surface = exit.surface,
        surface_index = exit.surface_index,
        x = exit.x,
        y = exit.y
    }

end


local function lerp(minimum, maximum, ratio)
    return minimum + ((maximum - minimum) * ratio)
end


local function mark_gate_resolution_dirty(gate_data)
    if not gate_data then
        return
    end

    gate_data.resolve_revision = (gate_data.resolve_revision or 0) + 1
    gate_data.last_resolve_tick = nil
    gate_data.distance_snapshot = nil
end


local function make_surface_label(surface)
    if not surface then
        return {"exotic-industries.gate-gui-status-span-unresolved-anchor"}
    end

    if surface.localised_name then
        return surface.localised_name
    end

    return surface.name
end


function model.rebuild_distance_cache()
    model.check_global_init()

    -- The distance cache is intentionally rebuilt only at load/config-change time.
    -- Static starmap coordinates never need to be recomputed during normal gate updates,
    -- and keeping this work out of the quote path lets moving-platform routes pay only for
    -- their final interpolation step at runtime.
    local cache = ei_surface_anchor.build_distance_cache(prototypes and prototypes.space_location)

    storage.ei.gate.distance_cache = cache
    return cache
end


function model.ensure_distance_cache()
    model.check_global_init()

    local cache = ei_surface_anchor.ensure_distance_cache(
        storage.ei.gate.distance_cache,
        prototypes and prototypes.space_location
    )
    storage.ei.gate.distance_cache = cache

    return cache
end


function model.get_surface_anchor(surface)
    -- Moving platforms are priced from live route progress instead of simply snapping
    -- to the orbit they most recently visited. This keeps gate cost understandable when
    -- the receiver is in transit between two astronomical anchors.
    return ei_surface_anchor.get_surface_anchor(
        surface,
        model.ensure_distance_cache(),
        prototypes and prototypes.space_location
    )
end


function model.get_span_band(multiplier)
    if multiplier <= GATE_DISTANCE_SAME_SURFACE_MULT then
        return {"exotic-industries.gate-gui-span-band-local"}
    end

    if multiplier < 3.5 then
        return {"exotic-industries.gate-gui-span-band-orbital"}
    end

    if multiplier <= 6.0 then
        return {"exotic-industries.gate-gui-span-band-interplanetary"}
    end

    return {"exotic-industries.gate-gui-span-band-deep-space"}
end


function model.distance_multiplier_to_span_ratio(multiplier)
    return clamp(
        (multiplier - GATE_DISTANCE_SAME_SURFACE_MULT)
            / (GATE_DISTANCE_INTERLOCATION_MAX_MULT - GATE_DISTANCE_SAME_SURFACE_MULT),
        0,
        1
    )
end


local function decorate_distance_snapshot(snapshot, source_surface, target_surface)
    if not snapshot then
        return nil
    end

    local resolved = snapshot.resolved or target_surface ~= nil
    local multiplier = snapshot.distance_multiplier or 0
    local raw_distance = snapshot.raw_distance or 0

    snapshot.gui_target_surface_index = target_surface and ei_lib.get_surface_index(target_surface) or 0
    snapshot.gui_multiplier_raw = multiplier
    snapshot.gui_distance_raw = raw_distance
    snapshot.gui_resolved = resolved

    local multiplier_text = snapshot.gui_multiplier_text
    if not multiplier_text or snapshot.gui_multiplier_value ~= multiplier then
        multiplier_text = string.format("%.2f", multiplier)
        snapshot.gui_multiplier_text = multiplier_text
        snapshot.gui_multiplier_value = multiplier
    end

    local distance_text = snapshot.gui_distance_text
    if not distance_text or snapshot.gui_distance_value ~= raw_distance then
        distance_text = string.format("%.1f", raw_distance)
        snapshot.gui_distance_text = distance_text
        snapshot.gui_distance_value = raw_distance
    end

    if resolved then
        snapshot.gui_caption = {
            "exotic-industries.gate-gui-status-span",
            snapshot.span_band or {"exotic-industries.gate-gui-span-band-local"},
            multiplier_text
        }
        snapshot.gui_tooltip = {
            "exotic-industries.gate-gui-status-span-tooltip",
            snapshot.source_anchor_name or make_surface_label(source_surface),
            snapshot.target_anchor_name or {"exotic-industries.gate-gui-status-span-unresolved-anchor"},
            distance_text,
            multiplier_text
        }
        snapshot.gui_value = snapshot.span_ratio or 0
    else
        snapshot.gui_caption = GATE_SPAN_UNRESOLVED_CAPTION
        snapshot.gui_tooltip = GATE_SPAN_UNRESOLVED_TOOLTIP
        snapshot.gui_value = 0
    end

    return snapshot
end


function model.resolve_distance_quote(source_surface, target_surface)
    -- Distance pricing is layered on top of cargo burden:
    -- - same surface: almost free
    -- - same astronomical anchor, different surface: large fixed floor
    -- - different anchors: geometry-driven multiplier
    --
    -- The interpolation uses an ease-out curve instead of a raw linear ramp so outer planets
    -- like Aquilo sit much closer to the high end even though the full cache still contains
    -- farther destinations such as solar-system-edge style endpoints.
    local default_result = {
        raw_distance = 0,
        distance_multiplier = 1,
        span_ratio = 0,
        source_anchor_name = make_surface_label(source_surface),
        target_anchor_name = make_surface_label(target_surface),
        span_band = {"exotic-industries.gate-gui-span-band-local"},
        resolved = false,
    }

    if not source_surface or not target_surface then
        return default_result
    end

    if source_surface.index == target_surface.index then
        return {
            raw_distance = 0,
            distance_multiplier = GATE_DISTANCE_SAME_SURFACE_MULT,
            span_ratio = model.distance_multiplier_to_span_ratio(GATE_DISTANCE_SAME_SURFACE_MULT),
            source_anchor_name = make_surface_label(source_surface),
            target_anchor_name = make_surface_label(target_surface),
            span_band = {"exotic-industries.gate-gui-span-band-local"},
            resolved = true,
        }
    end

    local cache = model.ensure_distance_cache()
    local source_anchor = model.get_surface_anchor(source_surface)
    local target_anchor = model.get_surface_anchor(target_surface)

    if not source_anchor or not target_anchor then
        return {
            raw_distance = 0,
            distance_multiplier = GATE_DISTANCE_UNKNOWN_INTERSURFACE_MULT,
            span_ratio = model.distance_multiplier_to_span_ratio(GATE_DISTANCE_UNKNOWN_INTERSURFACE_MULT),
            source_anchor_name = source_anchor and source_anchor.label or make_surface_label(source_surface),
            target_anchor_name = target_anchor and target_anchor.label or make_surface_label(target_surface),
            span_band = model.get_span_band(GATE_DISTANCE_UNKNOWN_INTERSURFACE_MULT),
            resolved = false,
        }
    end

    if source_anchor.location_name
    and target_anchor.location_name
    and source_anchor.location_name == target_anchor.location_name then
        return {
            raw_distance = 0,
            distance_multiplier = GATE_DISTANCE_SAME_LOCATION_CROSS_SURFACE_MULT,
            span_ratio = model.distance_multiplier_to_span_ratio(GATE_DISTANCE_SAME_LOCATION_CROSS_SURFACE_MULT),
            source_anchor_name = source_anchor.label,
            target_anchor_name = target_anchor.label,
            span_band = {"exotic-industries.gate-gui-span-band-orbital"},
            resolved = true,
        }
    end

    local raw_distance
    if source_anchor.location_name and target_anchor.location_name then
        raw_distance = cache.pair_distance[source_anchor.location_name]
            and cache.pair_distance[source_anchor.location_name][target_anchor.location_name]
    end

    if raw_distance == nil then
        local dx = source_anchor.x - target_anchor.x
        local dy = source_anchor.y - target_anchor.y
        raw_distance = math.sqrt((dx * dx) + (dy * dy))
    end

    local normalized_distance = clamp(raw_distance / cache.max_pair_distance, 0, 1)
    normalized_distance = normalized_distance ^ GATE_DISTANCE_INTERLOCATION_CURVE_EXPONENT
    local distance_multiplier = lerp(
        GATE_DISTANCE_INTERLOCATION_MIN_MULT,
        GATE_DISTANCE_INTERLOCATION_MAX_MULT,
        normalized_distance
    )

    return {
        raw_distance = raw_distance,
        distance_multiplier = distance_multiplier,
        span_ratio = model.distance_multiplier_to_span_ratio(distance_multiplier),
        source_anchor_name = source_anchor.label,
        target_anchor_name = target_anchor.label,
        span_band = model.get_span_band(distance_multiplier),
        resolved = true,
    }
end


function model.get_gate_target_surface(gate_data)
    if not gate_data then
        return nil
    end

    if model.entity_check(gate_data.effective_target_entity) then
        return gate_data.effective_target_entity.surface
    end

    local exit = gate_data.effective_exit or gate_data.legacy_exit
    if exit then
        local surface = exit.surface_index and game.surfaces[exit.surface_index] or nil
        if surface then
            return surface
        end

        if exit.surface then
            surface = game.get_surface(exit.surface)
            if surface then
                exit.surface_index = surface.index
            end
            return surface
        end
    end

    return nil
end


function model.update_distance_snapshot(gate, gate_data)
    if not model.entity_check(gate) or not gate_data then
        return nil
    end

    local target_surface = model.get_gate_target_surface(gate_data)
    gate_data.distance_snapshot = decorate_distance_snapshot(
        model.resolve_distance_quote(gate.surface, target_surface),
        gate.surface,
        target_surface
    )
    return gate_data.distance_snapshot
end


local function get_cached_legacy_status(exit)
    if not exit then
        return GATE_LEGACY_STATUS_NONE
    end

    local cached_status = exit.legacy_status_caption
    if not cached_status
    or exit.legacy_status_surface ~= exit.surface
    or exit.legacy_status_x ~= exit.x
    or exit.legacy_status_y ~= exit.y then
        cached_status = {
            "exotic-industries.gate-gui-legacy-destination",
            exit.surface,
            exit.x,
            exit.y,
            exit.surface
        }
        exit.legacy_status_caption = cached_status
        exit.legacy_status_surface = exit.surface
        exit.legacy_status_x = exit.x
        exit.legacy_status_y = exit.y
    end

    return cached_status
end


local function get_gate_tendril_source_position(gate)
    local pick = GATE_TENDRIL_SOURCE_OFFSETS[math.random(1, #GATE_TENDRIL_SOURCE_OFFSETS)]
    return {
        x = gate.position.x + pick.x,
        y = gate.position.y + pick.y
    }
end


local function get_gate_tendril_target_position(gate)
    -- Sample inside the same broad footprint as the gate glow so the arcs feel like
    -- local instability around the machine rather than long-range artillery fire.
    local angle = math.random() * math.pi * 2
    local radius = math.sqrt(math.random()) * GATE_TENDRIL_TARGET_RADIUS
    return {
        x = gate.position.x + (math.cos(angle) * radius),
        y = gate.position.y + (math.sin(angle) * radius)
    }
end


local function get_tendril_damage_amount(stress)
    local normalized = ei_lib.clamp((stress - GATE_TENDRIL_STRESS_FLOOR) / (MAX_GATE_STRESS - GATE_TENDRIL_STRESS_FLOOR), 0, 1)
    return lerp(GATE_TENDRIL_DAMAGE_MIN, GATE_TENDRIL_DAMAGE_MAX, normalized)
end


function model.emit_stress_tendril(gate, gate_data, event)
    if not model.entity_check(gate) or not gate_data then
        return
    end

    local stress = gate_data.stress or 0
    if stress < GATE_TENDRIL_STRESS_FLOOR then
        gate_data.last_tendril_roll_tick = ei_lib.get_event_tick(event)
        return
    end

    local current_tick = ei_lib.get_event_tick(event)
    local last_roll_tick = gate_data.last_tendril_roll_tick or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_roll_tick)
    gate_data.last_tendril_roll_tick = current_tick

    if elapsed_ticks <= 0 then
        return
    end

    if current_tick < ((gate_data.last_tendril_strike_tick or -GATE_TENDRIL_MIN_INTERVAL_TICKS) + GATE_TENDRIL_MIN_INTERVAL_TICKS) then
        return
    end

    local normalized = clamp((stress - GATE_TENDRIL_STRESS_FLOOR) / (MAX_GATE_STRESS - GATE_TENDRIL_STRESS_FLOOR), 0, 1)
    local chance_per_second = lerp(GATE_TENDRIL_CHANCE_PER_SECOND_AT_FLOOR, GATE_TENDRIL_CHANCE_PER_SECOND_AT_MAX, normalized)
    local roll_chance = clamp(chance_per_second * (elapsed_ticks / 60), 0, 1)

    if math.random() > roll_chance then
        return
    end

    local source_position = get_gate_tendril_source_position(gate)
    local target_position = get_gate_tendril_target_position(gate)

    gate.surface.create_entity{
        name = "electric-beam-no-sound",
        position = source_position,
        source = source_position,
        target = target_position,
        duration = 18,
        force = gate.force
    }

    gate.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = target_position
    }
    gate.surface.create_trivial_smoke{
        name = "electric-smoke",
        position = {
            x = target_position.x + ((math.random() - 0.5) * 0.6),
            y = target_position.y + ((math.random() - 0.5) * 0.6)
        }
    }

    local damage_amount = get_tendril_damage_amount(stress)
    local victims = gate.surface.find_entities_filtered{
        position = target_position,
        radius = GATE_TENDRIL_DAMAGE_RADIUS
    }

    for _, victim in ipairs(victims) do
        if victim.valid
        and victim ~= gate
        and victim ~= gate_data.container
        and victim ~= gate_data.wire_proxy
        and victim.name ~= "ei-gate-receiver"
        and ei_lib.entity_can_take_health_damage(victim) then
            victim.damage(damage_amount, game.forces.neutral, "electric")
        end
    end

    gate_data.last_tendril_strike_tick = current_tick
end


function model.make_item_with_quality_id(item_stack)
    return ei_lib.make_item_with_quality_id(item_stack)
end


function model.make_item_stack_definition(item_stack, count)
    return ei_lib.make_item_stack_definition(item_stack, count)
end


function model.ensure_gate_defaults(gate_unit, event)

    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return nil
    end

    if gate_data.manual_enabled == nil then
        gate_data.manual_enabled = gate_data.state == true
    end

    if gate_data.manual_receiver_id ~= nil then
        gate_data.manual_receiver_id = tonumber(gate_data.manual_receiver_id)
        if gate_data.manual_receiver_id then
            gate_data.manual_receiver_id = math.floor(gate_data.manual_receiver_id)
        end
        if not gate_data.manual_receiver_id or gate_data.manual_receiver_id < 1 then
            gate_data.manual_receiver_id = nil
        end
    end

    if gate_data.legacy_exit == nil and gate_data.exit then
        gate_data.legacy_exit = model.copy_exit(gate_data.exit)
    end

    if gate_data.last_low_power == nil then
        gate_data.last_low_power = false
    end

    if gate_data.resolve_revision == nil then
        gate_data.resolve_revision = 0
    end

    if gate_data.last_resolve_tick == nil then
        gate_data.last_resolve_tick = -1
    end

    if gate_data.last_resolve_revision == nil then
        gate_data.last_resolve_revision = -1
    end

    if gate_data.last_resolve_registry_generation == nil then
        gate_data.last_resolve_registry_generation = -1
    end

    if gate_data.stress == nil then
        gate_data.stress = 0
    end

    if gate_data.cooldown_until_tick == nil then
        gate_data.cooldown_until_tick = 0
    end

    if gate_data.residue_progress == nil then
        gate_data.residue_progress = 0
    end

    if gate_data.last_energy_tick == nil then
        gate_data.last_energy_tick = ei_lib.get_event_tick(event)
    end

    if gate_data.wire_proxy ~= nil and model.entity_check(gate_data.wire_proxy) == false then
        gate_data.wire_proxy = nil
        gate_data.wire_proxy_connected = nil
    end

    if gate_data.signal_cache ~= nil and type(gate_data.signal_cache) ~= "table" then
        gate_data.signal_cache = nil
    end

    if gate_data.last_signal_update_tick == nil then
        gate_data.last_signal_update_tick = -60
    end

    if gate_data.last_wire_probe_tick == nil then
        gate_data.last_wire_probe_tick = -GATE_WIRE_SCAN_INTERVAL_TICKS
    end

    if gate_data.wire_proxy_wired == nil then
        gate_data.wire_proxy_wired = false
    end

    if gate_data.wire_proxy_connection_migration_version == nil then
        gate_data.wire_proxy_connection_migration_version = 0
    end

    if gate_data.wire_proxy_connection_migration_version < GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION then
        migrate_wire_proxy_connections_to_container(gate_data)
    end

    if gate_data.last_tendril_roll_tick == nil then
        gate_data.last_tendril_roll_tick = ei_lib.get_event_tick(event)
    end

    if gate_data.last_tendril_strike_tick == nil then
        gate_data.last_tendril_strike_tick = -GATE_TENDRIL_MIN_INTERVAL_TICKS
    end

    gate_data.state = gate_data.manual_enabled

    return gate_data

end


function model.get_lowest_free_receiver_id(force_index, skip_unit)

    local used = {}

    for unit, data in pairs(storage.ei.gate.receiver) do
        if unit ~= skip_unit then
            local receiver = data.entity
            if model.entity_check(receiver) and receiver.force.index == force_index then
                local auto_id = tonumber(data.auto_id)
                if auto_id and auto_id > 0 then
                    used[math.floor(auto_id)] = true
                end
            end
        end
    end

    local next_id = 1
    while used[next_id] do
        next_id = next_id + 1
    end

    return next_id

end


function model.ensure_receiver_defaults(receiver_unit, event)

    local receiver_data = storage.ei.gate.receiver[receiver_unit]
    if not receiver_data then
        return nil
    end

    local receiver = receiver_data.entity
    if not model.entity_check(receiver) then
        return nil
    end

    local force_index = receiver.force.index
    local auto_id = tonumber(receiver_data.auto_id)

    if not auto_id or auto_id < 1 or receiver_data.force_index ~= force_index then
        receiver_data.auto_id = model.get_lowest_free_receiver_id(force_index, receiver_unit)
    else
        receiver_data.auto_id = math.floor(auto_id)
    end

    receiver_data.force_index = force_index
    receiver_data.effective_id = receiver_data.effective_id or receiver_data.auto_id
    receiver_data.conflict = false

    if receiver_data.saturation == nil then
        receiver_data.saturation = 0
    end

    if receiver_data.residue_progress == nil then
        receiver_data.residue_progress = 0
    end

    if receiver_data.last_penalty_tick == nil then
        receiver_data.last_penalty_tick = ei_lib.get_event_tick(event)
    end

    return receiver_data

end


function model.register_receiver(receiver, event)

    model.check_global_init()

    local unit = get_entity_unit_number(receiver)
    if not unit then
        return
    end

    storage.ei.gate.receiver[unit] = storage.ei.gate.receiver[unit] or {}
    storage.ei.gate.receiver[unit].entity = receiver
    model.refresh_receivers(event)

end


function model.destroy_receiver(receiver, event)

    model.check_global_init()

    local unit = get_entity_unit_number(receiver)
    if not unit then
        return
    end

    storage.ei.gate.receiver[unit] = nil
    model.refresh_receivers(event)

end


function model.get_signal_value(entity, signal)
    local seen_networks = {}
    local total = 0

    local function add_entity_signal(source)
        if not model.entity_check(source) then
            return
        end

        local ok, connectors = pcall(source.get_wire_connectors, false)
        if not ok or type(connectors) ~= "table" then
            return
        end

        for connector_id, connector in pairs(connectors) do
            if connector and connector.valid and connector.real_connections and #connector.real_connections > 0 then
                local network_ok, network = pcall(source.get_circuit_network, connector_id)
                if network_ok and network and not seen_networks[network.network_id] then
                    seen_networks[network.network_id] = true

                    local signal_ok, value = pcall(network.get_signal, signal)
                    if signal_ok and value then
                        total = total + value
                    end
                end
            end
        end
    end

    if not model.entity_check(entity) then
        return 0
    end

    add_entity_signal(entity)
    return total

end


local function get_gate_wire_proxy_position(gate)
    return {
        x = gate.position.x + GATE_WIRE_PROXY_OFFSET.x,
        y = gate.position.y + GATE_WIRE_PROXY_OFFSET.y
    }
end


function model.get_gate_signal_value(gate_data, signal)
    if not gate_data then
        return 0
    end

    local seen_networks = {}
    local total = 0

    local function add_entity_signal(source)
        if not model.entity_check(source) then
            return
        end

        local ok, connectors = pcall(source.get_wire_connectors, false)
        if not ok or type(connectors) ~= "table" then
            return
        end

        for connector_id, connector in pairs(connectors) do
            if connector and connector.valid and connector.real_connections and #connector.real_connections > 0 then
                local network_ok, network = pcall(source.get_circuit_network, connector_id)
                if network_ok and network and not seen_networks[network.network_id] then
                    seen_networks[network.network_id] = true

                    local signal_ok, value = pcall(network.get_signal, signal)
                    if signal_ok and value then
                        total = total + value
                    end
                end
            end
        end
    end

    add_entity_signal(gate_data.container)
    add_entity_signal(gate_data.wire_proxy)

    return total

end


local GATE_CONTROL_SIGNAL_DEFS = {
    {key = "enable", signal = SIGNAL_GATE_ENABLE},
    {key = "destination", signal = SIGNAL_GATE_DESTINATION},
}


local function get_gate_control_signals(gate_data)
    local totals = {
        enable = 0,
        destination = 0,
    }

    if not gate_data then
        return totals
    end

    local seen_networks = {}

    local function add_entity_signals(source)
        if not model.entity_check(source) then
            return
        end

        local ok, connectors = pcall(source.get_wire_connectors, false)
        if not ok or type(connectors) ~= "table" then
            return
        end

        for connector_id, connector in pairs(connectors) do
            if connector and connector.valid and connector.real_connections and #connector.real_connections > 0 then
                local network_ok, network = pcall(source.get_circuit_network, connector_id)
                if network_ok and network and not seen_networks[network.network_id] then
                    seen_networks[network.network_id] = true

                    for _, signal_def in ipairs(GATE_CONTROL_SIGNAL_DEFS) do
                        local signal_ok, value = pcall(network.get_signal, signal_def.signal)
                        if signal_ok and value then
                            totals[signal_def.key] = totals[signal_def.key] + value
                        end
                    end
                end
            end
        end
    end

    add_entity_signals(gate_data.container)
    add_entity_signals(gate_data.wire_proxy)

    return totals
end


function model.measure_transfer_burden(entries)
    local total_burden = 0

    for _, entry in ipairs(entries) do
        if type(entry) == "string" and entry == "player" then
            total_burden = total_burden + model.energy_costs.player
        elseif type(entry) == "table" and entry.name and entry.count then
            local count = tonumber(entry.count) or 0
            if count > 0 then
                total_burden = total_burden + ((model.mass_weights[entry.name] or 1) * count)
            end
        end
    end

    return total_burden
end


-- Convert the mass-table burden into the actual joule toll charged to the gate. The curve is
-- intentionally superlinear so bulk cargo becomes increasingly unattractive compared to normal
-- logistics once the gate is unlocked.
function model.energy_from_burden(burden)
    if not burden or burden <= 0 then
        return 0
    end

    return (burden ^ 1.2) * 100 * 1e6
end


-- Quote once from the amount we can actually move this update. The quote is then reused for:
-- - affordability checks
-- - final payment
-- - stress / cooldown / residue penalties
-- Keeping these values together avoids the old mismatch where the gate could reason about one
-- transfer size and end up paying for a different one.
--
-- Distance affects energy and gate stress, but receiver saturation and residue stay tied to
-- physical burden. That keeps long-span transfers feeling harsher on the breach itself without
-- making every remote receiver saturate purely because it lives far away.
function model.quote_transfer(entries, source_surface, target_surface)
    local total_count = 0
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.count then
            total_count = total_count + (tonumber(entry.count) or 0)
        end
    end

    local burden = model.measure_transfer_burden(entries)
    local distance_quote = model.resolve_distance_quote(source_surface, target_surface)
    local base_energy = model.energy_from_burden(burden)
    local distance_multiplier = distance_quote and distance_quote.distance_multiplier or 1
    local span_ratio = distance_quote and distance_quote.span_ratio or 0
    local base_stress = math.sqrt(math.max(burden, 0))
    local stress_multiplier = lerp(1, GATE_DISTANCE_STRESS_MAX_MULT, span_ratio)

    return {
        count = total_count,
        burden = burden,
        base_energy_j = base_energy,
        raw_distance = distance_quote.raw_distance or 0,
        distance_multiplier = distance_multiplier,
        span_ratio = span_ratio,
        source_anchor_name = distance_quote.source_anchor_name,
        target_anchor_name = distance_quote.target_anchor_name,
        span_band = distance_quote.span_band,
        energy_j = math.floor(base_energy * distance_multiplier),
        stress_delta = math.min(GATE_TRANSFER_STRESS_CAP, base_stress * stress_multiplier),
        saturation_delta = math.min(20, math.sqrt(math.max(burden, 0)) * 0.8),
        residue_delta = burden,
    }
end


function model.can_pay_quote(gate, quote)
    return model.entity_check(gate) and quote and gate.energy >= (quote.energy_j or 0)
end


function model.commit_quote(gate, quote)
    if not quote then
        return false
    end

    if not model.can_pay_quote(gate, quote) then
        ei_lib.crystal_echo_floating("☠ [Insufficient Offering] — " .. math.floor((quote.energy_j or 0)/1e6) .. " MJ demanded; ritual aborted.", gate, 60, "serenity")
        return false
    end

    gate.energy = math.max(0, gate.energy - (quote.energy_j or 0))
    ei_lib.crystal_echo_floating("⚡ [Void Toll Paid] — " .. math.floor((quote.energy_j or 0)/1e6) .. " MJ consumed.", gate, 60, "wrath")
    return true
end


-- A successful transfer hurts both ends of the route:
-- - the source gate takes stress and cooldown
-- - the receiver takes saturation
-- - the route sheds breach residue once enough burden has accumulated
function model.apply_transfer_penalties(gate, gate_data, receiver_data, quote, event)
    if not gate_data or not quote then
        return
    end

    gate_data.stress = clamp((gate_data.stress or 0) + (quote.stress_delta or 0), 0, MAX_GATE_STRESS)
    gate_data.residue_progress = (gate_data.residue_progress or 0) + (quote.residue_delta or 0)

    if receiver_data then
        receiver_data.saturation = clamp((receiver_data.saturation or 0) + (quote.saturation_delta or 0), 0, MAX_RECEIVER_SATURATION)
        receiver_data.residue_progress = (receiver_data.residue_progress or 0) + (quote.residue_delta or 0)
        receiver_data.last_penalty_tick = ei_lib.get_event_tick(event)
    end

    local tick = ei_lib.get_event_tick(event)
    local cooldown_ticks = 30
        + math.floor(math.sqrt(math.max(quote.burden or 0, 0)) * 15)
        + math.floor((gate_data.stress or 0) * 2)
    gate_data.cooldown_until_tick = math.max(gate_data.cooldown_until_tick or 0, tick + cooldown_ticks)

    local residue_count = math.floor((gate_data.residue_progress or 0) / RESIDUE_THRESHOLD)
    if residue_count > 0 then
        gate_data.residue_progress = (gate_data.residue_progress or 0) - (residue_count * RESIDUE_THRESHOLD)
        local receiver_entity = receiver_data and receiver_data.entity or nil
        model.emit_breach_residue(gate, gate_data, receiver_entity, residue_count)
    end
end


function model.get_effective_receiver_data(gate_data, event)
    if not gate_data or gate_data.effective_target_type ~= "receiver" then
        return nil
    end

    local receiver = gate_data.effective_target_entity
    if not model.entity_check(receiver) then
        return nil
    end

    local receiver_unit = get_entity_unit_number(receiver)
    if not receiver_unit then
        return nil
    end

    local receiver_data = storage.ei.gate.receiver[receiver_unit]
    if not receiver_data then
        return nil
    end

    return model.ensure_receiver_defaults(receiver_unit, event)
end


function model.is_receiver_saturated(receiver_data)
    return receiver_data and (receiver_data.saturation or 0) >= MAX_RECEIVER_SATURATION
end


-- "Armed" is the state exposed to circuits. The gate must be manually/circuit enabled, have a
-- resolved destination, and sit above the low-power floor before it should accept work.
function model.is_gate_armed(gate, gate_data)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])

    if not model.entity_check(gate) or not gate_data then
        return false
    end

    if not gate_data.effective_enabled then
        return false
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return false
    end

    if gate.energy < LOW_POWER_J then
        return false
    end

    return true
end


-- This is stricter than "armed": cooldown and receiver saturation both pause transport, but they
-- do not necessarily mean the gate should reject further insertion or report itself as unpowered.
function model.can_gate_transport(gate, gate_data, receiver_data, event)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])
    receiver_data = receiver_data or model.get_effective_receiver_data(gate_data, event)

    if not model.is_gate_armed(gate, gate_data) then
        return false
    end

    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        return false
    end

    if model.is_receiver_saturated(receiver_data) then
        return false
    end

    return true
end


-- Input locking is reserved for truly inactive states where buffering more cargo is misleading:
-- disabled, unresolved, or below the minimum operating energy floor.
function model.should_lock_input(gate, gate_data)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])

    if not model.entity_check(gate) or not gate_data then
        return true
    end

    if not gate_data.effective_enabled then
        return true
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return true
    end

    if gate.energy < LOW_POWER_J then
        return true
    end

    return false
end


function model.decay_gate_penalties(gate_data, elapsed_ticks, event)
    if not gate_data or elapsed_ticks <= 0 then
        return
    end

    local decay = (elapsed_ticks / 60) * STRESS_DECAY_PER_SECOND
    gate_data.stress = clamp((gate_data.stress or 0) - decay, 0, MAX_GATE_STRESS)

    if (gate_data.cooldown_until_tick or 0) <= ei_lib.get_event_tick(event) then
        gate_data.cooldown_until_tick = 0
    end
end


function model.decay_receiver_penalties(receiver_data, elapsed_ticks)
    if not receiver_data or elapsed_ticks <= 0 then
        return
    end

    local decay = (elapsed_ticks / 60) * RECEIVER_SATURATION_DECAY_PER_SECOND
    receiver_data.saturation = clamp((receiver_data.saturation or 0) - decay, 0, MAX_RECEIVER_SATURATION)
end


-- Residue is first treated as inventory clutter so automation can clean it up. Only when neither
-- endpoint can accept it do we spill it into the world.
function model.emit_breach_residue(gate, gate_data, receiver_entity, residue_count)
    if residue_count <= 0 or not model.entity_check(gate) or not gate_data then
        return
    end

    local remaining = residue_count
    local source_inv = model.entity_check(gate_data.container) and gate_data.container.get_inventory(defines.inventory.chest) or nil
    local receiver_inv = model.entity_check(receiver_entity) and receiver_entity.get_inventory(defines.inventory.chest) or nil

    if source_inv then
        remaining = remaining - source_inv.insert({name = "ei-breach-residue", count = remaining})
    end

    if remaining > 0 and receiver_inv then
        remaining = remaining - receiver_inv.insert({name = "ei-breach-residue", count = remaining})
    end

    if remaining > 0 then
        gate.surface.spill_item_stack{
            position = gate.position,
            stack = {name = "ei-breach-residue", count = remaining},
            enable_looted = true,
            force = gate.force
        }
    end
end


function model.update_input_lock(gate, gate_data)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])
    if not gate_data or not model.entity_check(gate_data.container) then
        return
    end

    local inventory = gate_data.container.get_inventory(defines.inventory.chest)
    if not inventory then
        return
    end

    local container_unit = get_entity_unit_number(gate_data.container) or 0
    if gate_data.last_input_bar_container_unit ~= container_unit then
        gate_data.last_input_bar_container_unit = container_unit
        gate_data.last_input_bar = nil
    end

    local bar = model.should_lock_input(gate, gate_data) and 0 or (#inventory + 1)
    if gate_data.last_input_bar == bar then
        return
    end

    local ok = pcall(inventory.set_bar, bar)
    if ok then
        gate_data.last_input_bar = bar
        return
    end

    if bar == 0 then
        pcall(inventory.set_bar, 1)
        gate_data.last_input_bar = bar
    end
end


function model.destroy_wire_proxy(gate_unit)
    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return
    end

    local proxy = gate_data.wire_proxy
    if model.entity_check(proxy) then
        proxy.destroy({raise_destroy = false})
    end

    gate_data.wire_proxy = nil
    gate_data.wire_proxy_connected = nil
    gate_data.signal_cache = nil
end


-- The visible gate container is the player-facing circuit endpoint. The hidden proxy is only a
-- script-owned signal source, so it must be physically bridged into the container's red/green
-- networks for players to see telemetry on the same wires they already use for control input.
local function connector_targets_match(source, target)
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


local function ensure_connector_wire(source, target, origin)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    if connector_targets_match(source, target) then
        return true
    end

    local ok, connected = pcall(source.connect_to, target, false, origin)
    if not ok then
        return false
    end

    if connected then
        return true
    end

    return connector_targets_match(source, target)
end


local function disconnect_connector_wire(source, target, origin)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    if not connector_targets_match(source, target) then
        return true
    end

    local ok, disconnected = pcall(source.disconnect_from, target, origin)
    if not ok then
        return false
    end

    if disconnected then
        return true
    end

    return not connector_targets_match(source, target)
end


local function ensure_internal_wire(source_entity, source_id, target_entity, target_id)
    local source = source_entity.get_wire_connector(source_id, true)
    local target = target_entity.get_wire_connector(target_id, true)

    return ensure_connector_wire(source, target, defines.wire_origin.script)
end


local function resolve_wire_connector_id(entity, preferred_ids)
    if not model.entity_check(entity) then
        return nil
    end

    local ok, connectors = pcall(entity.get_wire_connectors, true)
    if not ok or type(connectors) ~= "table" then
        return nil
    end

    for _, connector_id in ipairs(preferred_ids) do
        local connector = connectors[connector_id]
        if connector and connector.valid then
            return connector_id
        end
    end

    return nil
end


local function get_gate_connector_preferences(connector_id)
    if connector_id == defines.wire_connector_id.circuit_green
    or connector_id == defines.wire_connector_id.combinator_output_green
    or connector_id == defines.wire_connector_id.combinator_input_green then
        return GATE_GREEN_CONNECTOR_IDS
    end

    return GATE_RED_CONNECTOR_IDS
end


local function collect_external_proxy_connections(proxy, ignored_owner)
    if model.entity_check(proxy) == false then
        return {}
    end

    local saved_connections = {}
    local ok, connectors = pcall(proxy.get_wire_connectors, false)
    if not ok or type(connectors) ~= "table" then
        return saved_connections
    end

    for connector_id, connector in pairs(connectors) do
        if not (connector and connector.valid) then
            goto continue
        end

        for _, connection in ipairs(connector.real_connections) do
            local target = connection.target
            if target and target.valid and target.owner ~= ignored_owner then
                saved_connections[#saved_connections + 1] = {
                    source_id = connector_id,
                    target = target,
                    origin = connection.origin,
                }
            end
        end

        ::continue::
    end

    return saved_connections
end


migrate_wire_proxy_connections_to_container = function(gate_data)
    if not gate_data then
        return false
    end

    local proxy = gate_data.wire_proxy
    local container = gate_data.container
    if model.entity_check(proxy) == false or model.entity_check(container) == false then
        return false
    end

    local saved_connections = collect_external_proxy_connections(proxy, container)
    if #saved_connections == 0 then
        gate_data.wire_proxy_connection_migration_version = GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION
        return false
    end

    local changed_any = false

    for _, connection in ipairs(saved_connections) do
        local container_connector_id = resolve_wire_connector_id(
            container,
            get_gate_connector_preferences(connection.source_id)
        )
        local container_connector = container_connector_id and container.get_wire_connector(container_connector_id, true) or nil
        local proxy_connector = proxy.get_wire_connector(connection.source_id, true)

        if ensure_connector_wire(container_connector, connection.target, connection.origin)
        and disconnect_connector_wire(proxy_connector, connection.target, connection.origin) then
            changed_any = true
        end
    end

    if #collect_external_proxy_connections(proxy, container) == 0 then
        gate_data.wire_proxy_connection_migration_version = GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION
    else
        gate_data.wire_proxy_connection_migration_version = 0
    end

    if changed_any then
        gate_data.signal_cache = nil
        gate_data.wire_proxy_wired = false
        gate_data.last_wire_probe_tick = -GATE_WIRE_SCAN_INTERVAL_TICKS
    end

    return changed_any
end


local function connector_has_external_peer(connector, ignored_owner)
    if not connector or not connector.valid then
        return false
    end

    for _, connection in ipairs(connector.real_connections) do
        local peer = connection.target
        if peer and peer.valid and peer.owner ~= ignored_owner then
            return true
        end
    end

    return false
end


function model.is_gate_container_externally_wired(gate_data)
    if not gate_data then
        return false
    end

    local container = gate_data.container
    if model.entity_check(container) == false then
        return false
    end

    local ok, container_connectors = pcall(container.get_wire_connectors, false)
    if ok and type(container_connectors) == "table" then
        for _, connector in pairs(container_connectors) do
            if connector_has_external_peer(connector, nil) then
                return true
            end
        end
    end

    return false
end


function model.attach_wire_proxy_to_container(gate_data)
    if not gate_data then
        return false
    end

    local proxy = gate_data.wire_proxy
    local container = gate_data.container
    if model.entity_check(proxy) == false or model.entity_check(container) == false then
        return false
    end

    local container_red_id = resolve_wire_connector_id(container, {
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local container_green_id = resolve_wire_connector_id(container, {
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.combinator_input_green,
    })
    local proxy_red_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local proxy_green_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_input_green,
    })

    if (not container_red_id and not container_green_id) or (not proxy_red_id and not proxy_green_id) then
        gate_data.wire_proxy_connected = false
        return false
    end

    local connected = false
    if container_red_id and proxy_red_id then
        connected = ensure_internal_wire(
            container,
            container_red_id,
            proxy,
            proxy_red_id
        ) or connected
    end

    if container_green_id and proxy_green_id then
        connected = ensure_internal_wire(
            container,
            container_green_id,
            proxy,
            proxy_green_id
        ) or connected
    end

    gate_data.wire_proxy_connected = connected
    gate_data.signal_cache = nil
    return connected
end


function model.ensure_wire_proxy(gate_unit)
    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return nil
    end

    local gate = gate_data.gate
    if not model.entity_check(gate) then
        return nil
    end

    local expected_position = get_gate_wire_proxy_position(gate)

    local proxy = gate_data.wire_proxy
    if model.entity_check(proxy) then
        if math.abs(proxy.position.x - expected_position.x) > 0.01
        or math.abs(proxy.position.y - expected_position.y) > 0.01 then
            pcall(proxy.teleport, expected_position)
        end
        if gate_data.wire_proxy_connected ~= true then
            model.attach_wire_proxy_to_container(gate_data)
        end
        return proxy
    end

    local ok, created_proxy = pcall(
        gate.surface.create_entity,
        {
            name = GATE_WIRE_PROXY_NAME,
            position = expected_position,
            force = gate.force,
            create_build_effect_smoke = false,
            raise_built = false,
        }
    )
    proxy = ok and created_proxy or nil

    if model.entity_check(proxy) == false then
        return nil
    end

    gate_data.wire_proxy = proxy
    gate_data.wire_proxy_connected = nil
    gate_data.signal_cache = nil
    gate_data.wire_proxy_wired = false
    gate_data.last_wire_probe_tick = -GATE_WIRE_SCAN_INTERVAL_TICKS
    gate_data.wire_proxy_connection_migration_version = GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION
    model.attach_wire_proxy_to_container(gate_data)

    return proxy
end


-- The wire proxy mirrors only a tiny summary of the gate state so circuit logic can react without
-- poking at internal storage: armed flag, stored MJ, and stress.
function model.update_wire_proxy_signals(gate, gate_data, event)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])
    if not model.entity_check(gate) or not gate_data then
        return
    end

    local proxy = model.ensure_wire_proxy(gate_unit)
    if model.entity_check(proxy) == false then
        return
    end

    local current_tick = ei_lib.get_event_tick(event)
    local cached_wired = gate_data.wire_proxy_wired == true
    local externally_wired = cached_wired

    if current_tick >= ((gate_data.last_wire_probe_tick or -GATE_WIRE_SCAN_INTERVAL_TICKS) + GATE_WIRE_SCAN_INTERVAL_TICKS) then
        externally_wired = model.is_gate_container_externally_wired(gate_data)
        gate_data.wire_proxy_wired = externally_wired
        gate_data.last_wire_probe_tick = current_tick
    end

    if not externally_wired then
        if cached_wired then
            local control = proxy.get_control_behavior()
            if control and control.valid then
                control.enabled = false

                local section = control.get_section(1)
                if section then
                    for i = 1, section.filters_count do
                        section.clear_slot(i)
                    end
                end
            end

            gate_data.signal_cache = nil
        end

        return
    end

    if gate_data.signal_cache and current_tick < ((gate_data.last_signal_update_tick or -60) + 60) then
        return
    end

    local active = model.is_gate_armed(gate, gate_data) and 1 or 0
    local energy = math.max(0, math.floor(((gate.energy or 0) / 1e6) + 0.5))
    local stress = math.max(0, math.floor((gate_data.stress or 0) + 0.5))

    if gate_data.signal_cache
    and gate_data.signal_cache.active == active
    and gate_data.signal_cache.energy == energy
    and gate_data.signal_cache.stress == stress then
        return
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return
    end

    control.enabled = true

    local section = control.get_section(1)
    if not section then
        section = control.add_section("gate")
    end

    if not section then
        return
    end

    section.active = true

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end

    section.set_slot(1, {value = SIGNAL_GATE_ACTIVE, min = active})

    if energy ~= 0 then
        section.set_slot(2, {value = SIGNAL_GATE_ENERGY, min = energy})
    end

    section.set_slot(3, {value = SIGNAL_GATE_STRESS, min = stress})

    gate_data.signal_cache = {
        active = active,
        energy = energy,
        stress = stress,
    }
    gate_data.last_signal_update_tick = current_tick
end


-- Scripted upkeep replaces the old always-on EEI drain. Dormant or invalid gates are free, while
-- armed, cooling, and stressed gates pay progressively more to stay ready.
function model.get_gate_upkeep_watts(gate, gate_data, event)
    local gate_unit = get_entity_unit_number(gate)
    gate_data = gate_data or (gate_unit and storage.ei.gate.gate[gate_unit])
    if not gate_data then
        return 0
    end

    if not gate_data.effective_enabled then
        return 0
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return 0
    end

    if not model.entity_check(gate) or gate.energy < LOW_POWER_J then
        return 0
    end

    local upkeep = GATE_ARMED_UPKEEP_W
    local stress = gate_data.stress or 0
    if stress > 0 then
        upkeep = upkeep + (stress * GATE_STRESS_UPKEEP_W)
    end
    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        upkeep = upkeep + GATE_COOLDOWN_UPKEEP_W
    end

    return upkeep
end


function model.refresh_gate_live_state(gate, event)
    if not model.entity_check(gate) then
        return
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return
    end

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    if not gate_data then
        return
    end

    model.resolve_gate_target(gate, event)
    model.update_input_lock(gate, gate_data)
    model.update_wire_proxy_signals(gate, gate_data, event)
end


-- Rebuild the per-force receiver registry from live entities so both the manual dropdown and the
-- circuit destination signal resolve against the same table. Duplicate effective IDs are marked as
-- conflicts and become unroutable until the conflict is removed.
function model.refresh_receivers(event)

    model.check_global_init()

    local registry_by_force = {}
    local stale_units = {}
    local registry_changed = false
    local tick = ei_lib.get_event_tick(event)
    local previous_conflict_by_unit = {}

    for unit, receiver_data in pairs(storage.ei.gate.receiver) do
        previous_conflict_by_unit[unit] = receiver_data and receiver_data.conflict == true or false
    end

    for unit, receiver_data in pairs(storage.ei.gate.receiver) do
        local receiver = receiver_data.entity
        if not model.entity_check(receiver) then
            table.insert(stale_units, unit)
            registry_changed = true
            goto continue
        end

        receiver_data = model.ensure_receiver_defaults(unit, event)
        if not receiver_data then
            table.insert(stale_units, unit)
            registry_changed = true
            goto continue
        end

        local elapsed_ticks = math.max(0, tick - (receiver_data.last_penalty_tick or 0))
        model.decay_receiver_penalties(receiver_data, elapsed_ticks)
        receiver_data.last_penalty_tick = tick

        local previous_effective_id = receiver_data.effective_id
        local previous_conflict = receiver_data.conflict
        local previous_surface = receiver_data.surface
        local previous_surface_index = receiver_data.surface_index
        local previous_position = receiver_data.position
        local receiver_surface = receiver.surface.name
        local receiver_surface_index = ei_lib.get_surface_index(receiver.surface)
        local receiver_position_x = receiver.position.x
        local receiver_position_y = receiver.position.y

        local override_id = model.get_signal_value(receiver, SIGNAL_RECEIVER_ID)
        if override_id and override_id > 0 then
            receiver_data.effective_id = math.floor(override_id)
        else
            receiver_data.effective_id = receiver_data.auto_id
        end

        receiver_data.conflict = false
        receiver_data.surface = receiver_surface
        receiver_data.surface_index = receiver_surface_index

        local position_changed = not previous_position
            or previous_position.x ~= receiver_position_x
            or previous_position.y ~= receiver_position_y
        if position_changed then
            receiver_data.position = {x = receiver_position_x, y = receiver_position_y}
        end

        local force_index = receiver.force.index
        local force_registry = registry_by_force[force_index]
        if not force_registry then
            force_registry = {
                valid = {},
                conflicts = {}
            }
            registry_by_force[force_index] = force_registry
        end

        local effective_id = receiver_data.effective_id
        local existing_unit = force_registry.valid[effective_id]

        if existing_unit then
            force_registry.valid[effective_id] = nil
            force_registry.conflicts[effective_id] = {existing_unit, unit}
            receiver_data.conflict = true
            local existing_data = storage.ei.gate.receiver[existing_unit]
            if existing_data then
                existing_data.conflict = true
                if previous_conflict_by_unit[existing_unit] ~= true then
                    registry_changed = true
                end
            end
        elseif force_registry.conflicts[effective_id] then
            table.insert(force_registry.conflicts[effective_id], unit)
            receiver_data.conflict = true
        else
            force_registry.valid[effective_id] = unit
        end

        if previous_effective_id ~= receiver_data.effective_id
        or previous_conflict ~= receiver_data.conflict
        or previous_surface ~= receiver_surface
        or previous_surface_index ~= receiver_surface_index
        or position_changed then
            registry_changed = true
        end

        ::continue::
    end

    for _, unit in ipairs(stale_units) do
        storage.ei.gate.receiver[unit] = nil
    end

    if registry_changed or not storage.ei.gate.receiver_by_force then
        storage.ei.gate.receiver_by_force = registry_by_force
    end
    storage.ei.gate.receiver_registry_dirty = registry_changed
    if registry_changed then
        storage.ei.gate.receiver_registry_generation = (storage.ei.gate.receiver_registry_generation or 0) + 1
    end

end


function model.get_receiver_by_id(force_index, receiver_id)

    if not receiver_id then
        return nil, false
    end

    local force_registry = storage.ei.gate.receiver_by_force[force_index]
    if not force_registry then
        return nil, false
    end

    if force_registry.conflicts[receiver_id] then
        return nil, true
    end

    local unit = force_registry.valid[receiver_id]
    if not unit then
        return nil, false
    end

    local receiver_data = storage.ei.gate.receiver[unit]
    if not receiver_data or not model.entity_check(receiver_data.entity) then
        return nil, false
    end

    return receiver_data, false

end


function model.make_receiver_label(receiver_data)
    local position = receiver_data and receiver_data.position
    local effective_id = receiver_data and receiver_data.effective_id or 0
    local surface = receiver_data and receiver_data.surface or ""
    local position_x = position and position.x or 0
    local position_y = position and position.y or 0

    local cached = receiver_data and receiver_data.dropdown_label or nil
    if cached
    and receiver_data.dropdown_label_effective_id == effective_id
    and receiver_data.dropdown_label_surface == surface
    and receiver_data.dropdown_label_x == position_x
    and receiver_data.dropdown_label_y == position_y then
        return cached
    end

    cached = string.format(
        "ID %d | %s | %.1f, %.1f",
        effective_id,
        surface,
        position_x,
        position_y
    )

    if receiver_data then
        receiver_data.dropdown_label = cached
        receiver_data.dropdown_label_effective_id = effective_id
        receiver_data.dropdown_label_surface = surface
        receiver_data.dropdown_label_x = position_x
        receiver_data.dropdown_label_y = position_y
    end

    return cached

end


local function copy_array_shallow(source)
    local copy = {}
    for index = 1, #source do
        copy[index] = source[index]
    end
    return copy
end


function model.get_receiver_dropdown_snapshot(force_index)
    model.check_global_init()

    local dropdown_cache = storage.ei.gate.receiver_dropdown_cache
    local registry_generation = storage.ei.gate.receiver_registry_generation or 0
    if dropdown_cache.generation ~= registry_generation then
        dropdown_cache.generation = registry_generation
        dropdown_cache.by_force = {}
        dropdown_cache.variants = {}
    end

    local cached = dropdown_cache.by_force[force_index]
    if cached then
        return cached
    end

    local receiver_items = {
        {"exotic-industries.gate-gui-no-receivers"}
    }
    local receiver_ids = {
        [1] = false
    }
    local selected_index_by_receiver_id = {}

    local force_registry = storage.ei.gate.receiver_by_force[force_index]
    if force_registry then
        local sorted_ids = {}
        for receiver_id, _ in pairs(force_registry.valid) do
            table.insert(sorted_ids, receiver_id)
        end
        table.sort(sorted_ids)

        for _, receiver_id in ipairs(sorted_ids) do
            local unit = force_registry.valid[receiver_id]
            local receiver_data = storage.ei.gate.receiver[unit]
            if receiver_data then
                table.insert(receiver_items, model.make_receiver_label(receiver_data))
                receiver_ids[#receiver_items] = receiver_id
                selected_index_by_receiver_id[receiver_id] = #receiver_items
            end
        end
    end

    cached = {
        receiver_items = receiver_items,
        receiver_ids = receiver_ids,
        selected_index_by_receiver_id = selected_index_by_receiver_id
    }
    dropdown_cache.by_force[force_index] = cached

    return cached
end


local function get_receiver_dropdown_variant_items(force_index, base_items, variant, receiver_id)
    local dropdown_cache = storage.ei.gate.receiver_dropdown_cache
    local force_variants = dropdown_cache.variants[force_index]
    if not force_variants then
        force_variants = {}
        dropdown_cache.variants[force_index] = force_variants
    end

    local variant_key = string.format("%s:%d", variant, receiver_id)
    local cached = force_variants[variant_key]
    if cached then
        return cached
    end

    local items = copy_array_shallow(base_items)
    if variant == "conflict" then
        items[1] = {"exotic-industries.gate-gui-receiver-conflict", receiver_id}
    else
        items[1] = {"exotic-industries.gate-gui-receiver-unavailable", receiver_id}
    end

    force_variants[variant_key] = items
    return items
end


function model.find_container_entity(surface, position)

    if not surface or not position then
        return nil
    end

    local containers = surface.find_entities_filtered{
        area = {
            {position.x - 0.3, position.y - 0.3},
            {position.x + 0.3, position.y + 0.3}
        },
        type = {
            "container",
            "logistic-container",
        }
    }

    for _, container in ipairs(containers) do
        if container.name ~= "ei-gate-container" then
            return container
        end
    end

    return nil

end


function model.resolve_manual_target(gate_data, force_index)

    if gate_data.manual_receiver_id then
        local receiver_data, conflicted = model.get_receiver_by_id(force_index, gate_data.manual_receiver_id)
        if receiver_data then
            return {
                target_type = "receiver",
                entity = receiver_data.entity,
                exit = {
                    surface = receiver_data.surface,
                    surface_index = receiver_data.surface_index,
                    x = receiver_data.position.x,
                    y = receiver_data.position.y
                },
                receiver_id = receiver_data.effective_id,
                conflicted = false
            }
        end

        return {
            target_type = nil,
            entity = nil,
            exit = nil,
            receiver_id = gate_data.manual_receiver_id,
            conflicted = conflicted
        }
    end

    if gate_data.legacy_exit then
        local exit = model.copy_exit(gate_data.legacy_exit)
        local legacy_entity = nil

        if model.entity_check(gate_data.exit_container) then
            legacy_entity = gate_data.exit_container
        elseif exit and exit.surface then
            local surface = (exit.surface_index and game.surfaces[exit.surface_index]) or game.get_surface(exit.surface)
            if surface then
                exit.surface_index = surface.index
                gate_data.legacy_exit.surface_index = surface.index
                legacy_entity = model.find_container_entity(surface, exit)
            end
            gate_data.exit_container = legacy_entity
        end

        return {
            target_type = "legacy",
            entity = legacy_entity,
            exit = exit,
            receiver_id = nil,
            conflicted = false
        }
    end

    return {
        target_type = nil,
        entity = nil,
        exit = nil,
        receiver_id = nil,
        conflicted = false
    }

end


-- Resolve the gate state once and cache it onto gate_data. This keeps GUI, transport, upkeep, and
-- circuit telemetry consistent even when the destination is being overridden live by circuits.
function model.resolve_gate_target(gate, event)
    if not model.entity_check(gate) then
        return nil
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return nil
    end

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    if not gate_data then
        return nil
    end

    local current_tick = ei_lib.get_event_tick(event)
    local registry_generation = storage.ei.gate.receiver_registry_generation or 0
    if gate_data.last_resolve_tick == current_tick
    and gate_data.last_resolve_revision == (gate_data.resolve_revision or 0)
    and gate_data.last_resolve_registry_generation == registry_generation then
        return gate_data
    end

    local manual_target = model.resolve_manual_target(gate_data, gate.force.index)
    local resolved_target = manual_target
    local control_source = "manual"
    local effective_enabled = gate_data.manual_enabled == true
    local control_signals = get_gate_control_signals(gate_data)
    local enable_signal = control_signals.enable

    if enable_signal ~= 0 then
        effective_enabled = enable_signal > 0
    end

    local circuit_receiver_id = control_signals.destination
    if circuit_receiver_id and circuit_receiver_id > 0 then
        circuit_receiver_id = math.floor(circuit_receiver_id)
        local circuit_target = model.get_receiver_by_id(gate.force.index, circuit_receiver_id)
        if circuit_target then
            resolved_target = {
                target_type = "receiver",
                entity = circuit_target.entity,
                exit = {
                    surface = circuit_target.surface,
                    surface_index = circuit_target.surface_index or ei_lib.get_surface_index(circuit_target.entity and circuit_target.entity.surface),
                    x = circuit_target.position.x,
                    y = circuit_target.position.y
                },
                receiver_id = circuit_target.effective_id,
                conflicted = false
            }
            control_source = "circuit"

            if enable_signal == 0 then
                effective_enabled = true
            end
        end
    end

    gate_data.control_source = control_source
    gate_data.effective_enabled = effective_enabled
    gate_data.effective_target_type = resolved_target.target_type
    gate_data.effective_target_entity = resolved_target.entity
    gate_data.effective_exit = resolved_target.exit
    gate_data.effective_receiver_id = resolved_target.receiver_id
    gate_data.manual_target_conflicted = manual_target.conflicted
    model.update_distance_snapshot(gate, gate_data)
    gate_data.last_resolve_tick = current_tick
    gate_data.last_resolve_revision = gate_data.resolve_revision or 0
    gate_data.last_resolve_registry_generation = registry_generation

    return gate_data

end


function model.get_preview_exit(gate_data)

    if gate_data.effective_exit then
        return gate_data.effective_exit
    end

    local gate = gate_data.gate
    if gate_data.manual_receiver_id and model.entity_check(gate) then
        local receiver_data = model.get_receiver_by_id(gate.force.index, gate_data.manual_receiver_id)
        if receiver_data then
            return {
                surface = receiver_data.surface,
                surface_index = receiver_data.surface_index,
                x = receiver_data.position.x,
                y = receiver_data.position.y
            }
        end
    end

    return gate_data.legacy_exit

end


function model.set_manual_receiver(gate_unit, receiver_id, event)

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    receiver_id = tonumber(receiver_id)
    if receiver_id then
        receiver_id = math.floor(receiver_id)
    end

    if not gate_data or not receiver_id or receiver_id < 1 then
        return false
    end

    if gate_data.manual_receiver_id == receiver_id
    and gate_data.legacy_exit == nil
    and gate_data.exit == nil
    and gate_data.exit_container == nil then
        return false
    end

    gate_data.manual_receiver_id = receiver_id
    gate_data.legacy_exit = nil
    gate_data.exit = nil
    gate_data.exit_container = nil
    mark_gate_resolution_dirty(gate_data)
    return true

end


function model.register_gate(gate, container, event)

    model.check_global_init()

    if not model.entity_check(gate) or not model.entity_check(container) then
        log("ei register_gate returned early due to pre-existing gate_unit or non-existent gate or non-existent container")
        return
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit or storage.ei.gate.gate[gate_unit] then
        log("ei register_gate returned early due to pre-existing gate_unit or non-existent gate or non-existent container")
        return
    end

    storage.ei.gate.gate[gate_unit] = {}
    storage.ei.gate.gate[gate_unit].gate = gate
    storage.ei.gate.gate[gate_unit].container = container
    storage.ei.gate.gate[gate_unit].manual_enabled = false
    storage.ei.gate.gate[gate_unit].state = false
    storage.ei.gate.gate[gate_unit].manual_receiver_id = nil
    storage.ei.gate.gate[gate_unit].legacy_exit = nil
    storage.ei.gate.gate[gate_unit].last_low_power = false
    storage.ei.gate.gate[gate_unit].wire_proxy_connection_migration_version = GATE_WIRE_PROXY_CONNECTION_MIGRATION_VERSION

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    if gate_data then
        gate_data.gate = gate
        gate_data.container = container
    end
    model.refresh_gate_live_state(gate, event)

end


function model.find_gate(container)

    if not container or not container.valid then
        return nil
    end

    if container.name == "ei-gate" then
        return container
    end

    if container.name ~= "ei-gate-container" then
        return nil
    end

    local gate = container.surface.find_entity("ei-gate", container.position)

    if not gate then
        return nil
    end

    return gate

end

--GATE LOGIC
-----------------------------------------------------------------------------------------------------

function model.make_gate(container, event)

    if not model.entity_check(container) then
        return
    end

    -- The player places the visible container. Script then spawns the hidden EEI that actually
    -- stores energy and drives transport so placement preview and in-world interaction both use
    -- the visible gate silhouette.
    local gate = container.surface.create_entity({
        name = "ei-gate",
        position = container.position,
        force = container.force
    })

    model.register_gate(gate, container, event)

end


function model.destroy_gate(gate, container, event)

    if not gate then
        -- look for gate at container position
        gate = container.surface.find_entity("ei-gate", container.position)
    end

    if not container then
        -- look for container at gate position
        container = gate.surface.find_entity("ei-gate-container", gate.position)
    end

    if not gate or not container then
        return
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return
    end

    model.cleanup_gate_remote_selection(gate_unit)
    model.destroy_wire_proxy(gate_unit)

    if model.entity_check(gate) then
        gate.destroy()
    end

    if model.entity_check(container) then
        container.destroy()
    end

    if storage.ei.gate.gate[gate_unit] then
        storage.ei.gate.gate[gate_unit] = nil
    end

end


function model.check_for_teleport(unit, gate, event)

    -- Transport intentionally stops after the first successful stack. Sustained throughput is
    -- supposed to look bursty and pay cooldown/stress costs instead of emptying a chest instantly.

    local gate_data = model.ensure_gate_defaults(unit, event)
    if not gate_data then
        return
    end

    local receiver_data = model.get_effective_receiver_data(gate_data, event)
    if not model.can_gate_transport(gate, gate_data, receiver_data, event) then
        return
    end

    local exit_container = gate_data.effective_target_entity
    if not model.entity_check(exit_container) then
        return
    end

    local source_container = gate_data.container
    local source_inv = model.entity_check(source_container) and source_container.get_inventory(defines.inventory.chest) or nil
    if not source_inv then return end
    if source_inv.is_empty() then return end

    local target_inv = exit_container.get_inventory(defines.inventory.chest)
    if not target_inv or target_inv.is_full() then return end
    local target_surface = exit_container.surface

    local success = false

    for i = 1, #source_inv do
        if source_inv[i].valid_for_read then
            local item_stack = source_inv[i]
            local item_name = item_stack.name
            local item_count = item_stack.count
            local insertable_probe = model.make_item_with_quality_id(item_stack) or item_name

            local ok, insertable_count = pcall(target_inv.get_insertable_count, insertable_probe)
            local movable_count = math.min(item_count, ok and insertable_count or item_count)
            if movable_count > 0 then
                local transfer_stack = model.make_item_stack_definition(item_stack, movable_count)
                local quote = model.quote_transfer({{name = item_name, count = movable_count}}, gate.surface, target_surface)
                if transfer_stack and model.can_pay_quote(gate, quote) then
                    local transfer_count = target_inv.insert(transfer_stack)
                    if transfer_count > 0 then
                        local actual_quote = quote
                        if transfer_count ~= movable_count then
                            actual_quote = model.quote_transfer({{name = item_name, count = transfer_count}}, gate.surface, target_surface)
                        end

                        if model.commit_quote(gate, actual_quote) then
                            item_stack.count = item_stack.count - transfer_count
                            model.apply_transfer_penalties(gate, gate_data, receiver_data, actual_quote, event)
                            success = true
                            ei_victory.count_value("gate_items_transported", transfer_count)
                            break
                        end

                        local rollback_stack = model.make_item_stack_definition(item_stack, transfer_count)
                        local removed_count = rollback_stack and target_inv.remove(rollback_stack) or 0
                        if removed_count < transfer_count then
                            gate.surface.spill_item_stack{
                                position = gate.position,
                                stack = model.make_item_stack_definition(item_stack, transfer_count - removed_count),
                                enable_looted = true,
                                force = gate.force
                            }
                        end
                    end
                end
            end
        end
    end

    if success then
        model.render_exit(gate, exit_container.bounding_box)
    end

    return

end


function model.find_container(gate, surface, position, print_out, event)

    print_out = print_out or false
    if not model.entity_check(gate) then
        return false
    end

    local unit = get_entity_unit_number(gate)
    if not unit then
        return false
    end

    local gate_data = model.ensure_gate_defaults(unit, event)
    local container = model.find_container_entity(surface, position)

    if container then
        position = container.position
        gate_data.exit_container = container
        gate_data.legacy_exit = {
            surface = surface.name,
            surface_index = ei_lib.get_surface_index(surface),
            x = position.x,
            y = position.y
        }
        gate_data.exit = model.copy_exit(gate_data.legacy_exit)
        gate_data.manual_receiver_id = nil
        mark_gate_resolution_dirty(gate_data)

        if print_out then
            ei_lib.notify_connected_players(
                "gate",
                {"exotic-industries.gate-exit-container-set", surface.name, position.x, position.y, container.name}
            )
        end
    else
        gate_data.exit_container = nil
        gate_data.legacy_exit = {
            surface = surface.name,
            surface_index = ei_lib.get_surface_index(surface),
            x = position.x,
            y = position.y
        }
        gate_data.exit = model.copy_exit(gate_data.legacy_exit)
        gate_data.manual_receiver_id = nil
        mark_gate_resolution_dirty(gate_data)

        if print_out then
            ei_lib.notify_connected_players(
                "gate",
                {"exotic-industries.gate-exit-set", surface.name, position.x, position.y}
            )
        end
        model.refresh_gate_live_state(gate, event)
        return false
    end

    model.refresh_gate_live_state(gate, event)

    return true

end


function model.gate_state(gate)
    local gate_data = select(1, get_gate_storage_entry(gate))
    return model.is_gate_armed(gate, gate_data)
end

-- Active payment path. Older versions tried to recurse recipe graphs at runtime; the gate now
-- relies on the static mass table and the quote helpers above so energy, stress, and residue all
-- derive from the same measured transfer.
function model.pay_energy(gate, tablein, actuallypay)
    local gate_data = select(1, get_gate_storage_entry(gate))
    local target_surface = gate_data and model.get_gate_target_surface(gate_data) or nil
    local quote = model.quote_transfer(tablein, gate and gate.surface or nil, target_surface)

    if not actuallypay then
        return model.can_pay_quote(gate, quote)
    end

    return model.commit_quote(gate, quote)
end


function model.teleport_player(character, gate)

    local player = character.player
    if not player then
        return
    end

    local gate_data = select(1, get_gate_storage_entry(gate))
    local exit = gate_data and gate_data.effective_exit or nil
    if not exit then
        return
    end

    -- teleport player
    player.teleport({exit.x, exit.y}, exit.surface)

end


function model.update_energy(unit, gate, event)
    local gate_data = storage.ei.gate.gate[unit]
    if not gate_data then
        return
    end

    -- The global updater touches gates incrementally, so decay and scripted upkeep both need to be
    -- expressed in elapsed time rather than "once per tick" assumptions.
    local current_tick = ei_lib.get_event_tick(event)
    local last_tick = gate_data.last_energy_tick or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_tick)

    if elapsed_ticks > 0 then
        local elapsed_seconds = elapsed_ticks / 60
        local start_stress = gate_data.stress or 0
        local end_stress = clamp(start_stress - (elapsed_seconds * STRESS_DECAY_PER_SECOND), 0, MAX_GATE_STRESS)

        if model.is_gate_armed(gate, gate_data) then
            local drain = GATE_ARMED_UPKEEP_W * elapsed_seconds
            local average_stress = (start_stress + end_stress) / 2

            if average_stress > 0 then
                drain = drain + (average_stress * GATE_STRESS_UPKEEP_W * elapsed_seconds)
            end

            local cooldown_until_tick = gate_data.cooldown_until_tick or 0
            local cooling_ticks = 0
            if cooldown_until_tick > last_tick then
                cooling_ticks = math.max(0, math.min(current_tick, cooldown_until_tick) - last_tick)
            end

            if cooling_ticks > 0 then
                drain = drain + (GATE_COOLDOWN_UPKEEP_W * (cooling_ticks / 60))
            end

            gate.energy = math.max(0, gate.energy - drain)
        end

        gate_data.stress = end_stress
        if (gate_data.cooldown_until_tick or 0) <= current_tick then
            gate_data.cooldown_until_tick = 0
        end
        gate_data.last_energy_tick = current_tick
    end

    local wants_power = gate_data.effective_enabled and model.entity_check(gate_data.effective_target_entity)
    if gate.energy < LOW_POWER_J then
        if wants_power and not gate_data.last_low_power then
            ei_lib.notify_connected_players(
                "gate",
                {"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name}
            )
        end
        gate_data.last_low_power = wants_power
    else
        gate_data.last_low_power = false
    end

    model.update_input_lock(gate, gate_data)
    model.update_wire_proxy_signals(gate, gate_data, event)

end


function model.create_gate_user_permission_group()

    local group = game.permissions.create_group("gate-user")

    -- disable all
    for action,_ in pairs(defines.input_action) do
        group.set_allows_action(defines.input_action[action], false)
    end

    -- allow movement + items
    group.set_allows_action(defines.input_action.start_walking, true)
    group.set_allows_action(defines.input_action.use_item, true)

end


--RENDERING
-----------------------------------------------------------------------------------------------------

function model.render_exit(gate, box)
    if not box or not model.entity_check(gate) then
        return
    end

    local gate_data, gate_unit = get_gate_storage_entry(gate)
    if not gate_data or not gate_unit then
        return
    end

    local exit = gate_data.effective_exit
    if not exit then
        return
    end
    local animation

    -- check if exit already exists, if at same pos and surface extend time to live
    if gate_data.exit_animation then

        animation = gate_data.exit_animation  --[[@as LuaRenderObject]]

        -- check if still valid, might be very old
        if animation.valid then

            -- also test pos and surface  
            local target = animation.target
            local surface = animation.surface
            
            if target.position.x == exit.x and target.position.y == exit.y and surface.name == exit.surface then
                
                -- extend time to live
                animation.time_to_live = 180
                return
            end
        end
    end

    local x_scale = 1
    local y_scale = 1

    if box then
        -- bounding box of container
        -- both x,y = 1 <=> width: 6tiles, height: 5tiles

        local width = math.abs(box.right_bottom.x - box.left_top.x)
        local height = math.abs(box.right_bottom.y - box.left_top.y)

        x_scale = (width / 6) * 1.2
        y_scale = (height / 5) * 1.2
    end

    -- create new exit
    animation = rendering.draw_animation{
        animation = "ei-exit-simple",
        target = {exit.x, exit.y},
        surface = exit.surface,
        render_layer = "object",
        animation_speed = 0.6,
        x_scale = x_scale,
        y_scale = y_scale,
        time_to_live = 180,
    }

    gate_data.exit_animation = animation
    
end


function model.render_animation(gate, gate_data)
    if not model.entity_check(gate) or not gate_data then
        return
    end

    local surface = gate.surface
    local color = GATE_ANIMATION_LIGHT_COLORS[math.random(1, #GATE_ANIMATION_LIGHT_COLORS)]

    -- Reuse the glow render instead of recreating a fresh light object every active visit.
    local light = gate_data.light
    if light and light.valid then
        light.color = color
        light.time_to_live = ei_ticksPerFullUpdate * 2
    else
        light = rendering.draw_light {
            sprite = "gate_glow",
            scale = 4,
            intensity = 0.22,
            color = color,
            target = gate,
            surface = surface,
            time_to_live = ei_ticksPerFullUpdate * 2,
            blend_mode = "multiplicative",
            apply_runtime_tint = true,
            draw_as_glow = true,
        }
        gate_data.light = light
    end

    if gate_data.animation and gate_data.animation.valid then return end
    gate_data.animation = nil

    local animation = rendering.draw_animation{
        animation = "ei-gate-running",
        target = gate,
        surface = surface,
        render_layer = "object",
        x_scale = 1,
        y_scale = 1
    }

    gate_data.animation = animation

end


function model.update_renders(unit, gate, event)
    local gate_data = storage.ei.gate.gate[unit]
    if not gate_data then
        return
    end

    local state = model.gate_state(gate)
    -- if state true -> check if need to render animation
    -- if state false -> check if need to destroy animation + cleanup

    if not state then
        if gate_data.animation then
            if gate_data.animation.valid then
                gate_data.animation.destroy()
            end
            gate_data.animation = nil
        end
        if gate_data.light then
            if gate_data.light.valid then
                gate_data.light.destroy()
            end
            gate_data.light = nil
        end
    else
        -- update_renders already resolved gate_data for this gate, so pass it through instead of
        -- paying for another storage lookup on the active render path.
        model.render_animation(gate, gate_data)
        -- High stress can leak out as short-range electrical tendrils around the gate body.
        -- These are purely local hazards: they stay inside the glow footprint, originate from
        -- the six outer cylinder extensions, and only roll while the gate is actually active.
        model.emit_stress_tendril(gate, gate_data, event)
    end

end


--GUI
-----------------------------------------------------------------------------------------------------

local function gui_elements_valid(elements)
    return elements
        and elements.root and elements.root.valid
        and elements.energy and elements.energy.valid
        and elements.span and elements.span.valid
        and elements.stress and elements.stress.valid
        and elements.dropdown and elements.dropdown.valid
        and elements.legacy_status and elements.legacy_status.valid
        and elements.control_source and elements.control_source.valid
        and elements.runtime and elements.runtime.valid
        and elements.receiver_strain and elements.receiver_strain.valid
        and elements.camera and elements.camera.valid
        and elements.state and elements.state.valid
end


local function clear_gate_gui_session(player_index, player, destroy_root)
    local gate_storage = storage.ei and storage.ei.gate or nil
    if not gate_storage or not player_index then
        return
    end

    if gate_storage.open_gui_players then
        gate_storage.open_gui_players[player_index] = nil
    end

    if gate_storage.gui_elements_cache then
        gate_storage.gui_elements_cache[player_index] = nil
    end

    if gate_storage.gui_projection_cache then
        gate_storage.gui_projection_cache[player_index] = nil
    end

    if gate_storage.open_redirect then
        gate_storage.open_redirect[player_index] = nil
    end

    if destroy_root and player and player.valid then
        local root = player.gui.relative["ei-gate-console"]
        if root then
            root.destroy()
        end
    end
end


function model.get_gui_elements(player)

    if not player or not player.valid then
        return nil
    end

    local gate_storage = storage.ei and storage.ei.gate
    local gui_elements_cache = gate_storage and gate_storage.gui_elements_cache or nil
    local cached = gui_elements_cache and gui_elements_cache[player.index] or nil
    if gui_elements_valid(cached) then
        return cached
    end
    if gui_elements_cache then
        gui_elements_cache[player.index] = nil
    end

    local root = player.gui.relative["ei-gate-console"]
    if not (root and root.valid) then
        return nil
    end

    local main_container = root["main-container"]
    local status_flow = main_container and main_container["status-flow"]
    local control_flow = main_container and main_container["control-flow"]
    local target_flow = control_flow and control_flow["target-flow"]
    local dropdown_flow = target_flow and target_flow["dropdown-flow"]
    local camera_frame = control_flow and control_flow["camera-frame"]

    local elements = {
        root = root,
        energy = status_flow and status_flow["energy"],
        span = status_flow and status_flow["span"],
        stress = status_flow and status_flow["stress"],
        dropdown = dropdown_flow and dropdown_flow["receiver"],
        legacy_status = target_flow and target_flow["legacy-status"],
        control_source = target_flow and target_flow["control-source"],
        runtime = target_flow and target_flow["runtime-state"],
        receiver_strain = target_flow and target_flow["receiver-strain"],
        camera = camera_frame and camera_frame["target-camera"],
        state = target_flow and target_flow["state-button"],
    }

    if not gui_elements_valid(elements) then
        return nil
    end

    if gui_elements_cache then
        gui_elements_cache[player.index] = elements
    end

    return elements

end


function model.build_gui(player, gate)

    if not player or not player.valid then
        return nil
    end

    if not model.entity_check(gate) then
        return nil
    end

    if player.gui.relative["ei-gate-console"] then
        model.close_gui(player)
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return nil
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-gate-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-gate-container",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
        tags = { gate_unit = gate_unit }
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_nondraggable_spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-gate-console",
                action = "goto-informatron",
                page = "gate"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do -- Status subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-status-title"},
            style = "subheader_caption_label",
        }
    
        local status_flow = main_container.add{
            type = "flow",
            name = "status-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        status_flow.add{
            type = "progressbar",
            name = "energy",
            caption = {"exotic-industries.gate-gui-status-energy", 0},
            tooltip = {"exotic-industries.gate-gui-status-energy-tooltip"},
            style = "ei_status_progressbar"
        }
        status_flow.add{
            type = "progressbar",
            name = "span",
            caption = {"exotic-industries.gate-gui-status-span-unresolved"},
            tooltip = {"exotic-industries.gate-gui-status-span-tooltip-unresolved"},
            style = "ei_status_progressbar_purple"
        }
        status_flow.add{
            type = "progressbar",
            name = "stress",
            caption = {"exotic-industries.gate-gui-status-stress", 0},
            tooltip = {"exotic-industries.gate-gui-status-stress-tooltip"},
            style = "ei_status_progressbar_red"
        }

    end


    do -- Control subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-title"},
            style = "subheader_caption_label",
        }
    
        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "horizontal",
            style = "ei_inner_content_flow_horizontal",
        }

        local target_flow = control_flow.add{
            type = "flow",
            name = "target-flow",
            direction = "vertical"
        }

        local dropdown_flow = target_flow.add{
            type = "flow",
            name = "dropdown-flow",
            direction = "vertical"
        }
    
        dropdown_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-dropdown-label"},
            tooltip = {"exotic-industries.gate-gui-control-dropdown-label-tooltip"}
        }
        dropdown_flow.add{
            type = "drop-down",
            name = "receiver",
            tags = {
                parent_gui = "ei-gate-console",
                action = "set-receiver",
                gate_unit = gate_unit
            }
        }

        target_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-legacy-label"},
            tooltip = {"exotic-industries.gate-gui-legacy-label-tooltip"},
        }
        target_flow.add{
            type = "label",
            name = "legacy-status",
            caption = {"exotic-industries.gate-gui-legacy-none"}
        }

        target_flow.add{
            type = "label",
            name = "control-source",
            caption = {"exotic-industries.gate-gui-control-source-label", {"exotic-industries.gate-gui-control-source-manual"}},
            tooltip = {"exotic-industries.gate-gui-control-source-label-tooltip"},
        }
        target_flow.add{
            type = "label",
            name = "runtime-state",
            caption = {"exotic-industries.gate-gui-control-runtime-label", {"exotic-industries.gate-gui-runtime-stable"}},
            tooltip = {"exotic-industries.gate-gui-control-runtime-label-tooltip"},
        }
        target_flow.add{
            type = "label",
            name = "receiver-strain",
            caption = {"exotic-industries.gate-gui-receiver-strain-label", {"exotic-industries.gate-gui-receiver-strain-low"}},
            tooltip = {"exotic-industries.gate-gui-receiver-strain-label-tooltip"},
        }
        target_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-state-label"},
        }
        target_flow.add{
            type = "button",
            name = "state-button",
            caption = {"exotic-industries.gate-gui-control-state-button", "OFF"},
            tooltip = {"exotic-industries.gate-gui-control-state-button-tooltip"},
            style = "ei_small_red_button",
            tags = {
                action = "set-state",
                parent_gui = "ei-gate-console",
                gate_unit = gate_unit
            }
        }

        -- Target cam
        -- Shows the currently resolved destination. This follows manual receiver selection,
        -- circuit receiver overrides, and legacy exits for old saves.
        local camera_frame = control_flow.add{
            type = "frame",
            name = "camera-frame",
            style = "ei_small_camera_frame"
        }
        camera_frame.add{
            type = "camera",
            name = "target-camera",
            position = {0, 0},
            surface_index = 1,
            zoom = 0.25,
            style = "ei_small_camera"
        }

    end

    storage.ei.gate.open_gui_players[player.index] = gate_unit
    storage.ei.gate.gui_projection_cache[player.index] = nil

    return model.get_gui_elements(player)

end


function model.open_gui(player, event)
    model.check_global_init()

    local gate = model.find_gate(player.opened)
    if not gate then
        return
    end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return
    end

    if storage.ei.gate.last_housekeeping_tick ~= ei_lib.get_event_tick(event) then
        model.refresh_receivers(event)
    end

    local gui = model.get_gui_elements(player)
    local current_gate_unit = gui and gui.root and gui.root.tags and gui.root.tags.gate_unit or nil
    if current_gate_unit ~= gate_unit then
        gui = model.build_gui(player, gate)
        if not gui then
            return
        end
    else
        storage.ei.gate.open_gui_players[player.index] = gate_unit
    end

    local data = model.get_data(gate, event)
    model.update_gui(player, data, false, gate, gui)

end


function model.update_gui(player, data, ontick, gate, gui)

    if not data then return end
    if not gui_elements_valid(gui) then
        gui = model.get_gui_elements(player)
    end
    if not gui then
        local open_gate = model.find_gate(player.opened)
        if not gate or gate ~= open_gate then
            model.close_gui(player)
            return
        end

        gui = model.build_gui(player, gate)
        if not gui then
            model.close_gui(player)
            return
        end
    end

    local energy = gui.energy
    local span = gui.span
    local stress = gui.stress
    local dropdown = gui.dropdown
    local legacy_status = gui.legacy_status
    local control_source = gui.control_source
    local runtime = gui.runtime
    local receiver_strain = gui.receiver_strain
    local camera = gui.camera
    local state = gui.state
    local projection_cache = storage.ei.gate and storage.ei.gate.gui_projection_cache
    local previous_projection = projection_cache and projection_cache[player.index] or nil

    if previous_projection
    and previous_projection.gate_unit == data.gate_unit
    and previous_projection.signature == data.gui_projection_signature then
        return
    end

    -- Update the view from a precomputed gate snapshot. update_gui should stay dumb and avoid
    -- poking back into storage except when it needs to rebuild a stale GUI shell.
    energy.caption = {"exotic-industries.gate-gui-status-energy", data.energy_mj_text}
    energy.value = data.energy / data.max_energy
    span.caption = data.span_caption
    span.tooltip = data.span_tooltip
    span.value = data.span_value
    stress.caption = {"exotic-industries.gate-gui-status-stress", data.stress}
    stress.value = data.stress_ratio

    local previous_dropdown_tags = dropdown.tags or EMPTY_GUI_TAGS
    if previous_dropdown_tags.receiver_dropdown_generation ~= data.receiver_dropdown_generation
    or previous_dropdown_tags.receiver_dropdown_variant ~= data.receiver_dropdown_variant
    or previous_dropdown_tags.receiver_dropdown_variant_id ~= data.receiver_dropdown_variant_id then
        dropdown.items = data.receiver_items
    end
    dropdown.selected_index = data.selected_index
    local gate_unit = data.gate_unit or previous_dropdown_tags.gate_unit
    if previous_dropdown_tags.parent_gui ~= "ei-gate-console"
    or previous_dropdown_tags.action ~= "set-receiver"
    or previous_dropdown_tags.gate_unit ~= gate_unit
    or previous_dropdown_tags.receiver_dropdown_generation ~= data.receiver_dropdown_generation
    or previous_dropdown_tags.receiver_dropdown_variant ~= data.receiver_dropdown_variant
    or previous_dropdown_tags.receiver_dropdown_variant_id ~= data.receiver_dropdown_variant_id then
        dropdown.tags = {
            parent_gui = "ei-gate-console",
            action = "set-receiver",
            receiver_ids = data.receiver_ids,
            gate_unit = gate_unit,
            receiver_dropdown_generation = data.receiver_dropdown_generation,
            receiver_dropdown_variant = data.receiver_dropdown_variant,
            receiver_dropdown_variant_id = data.receiver_dropdown_variant_id
        }
    end

    legacy_status.caption = data.legacy_status
    control_source.caption = {"exotic-industries.gate-gui-control-source-label", data.control_source_text}
    runtime.caption = {"exotic-industries.gate-gui-control-runtime-label", data.runtime_status}
    receiver_strain.caption = {"exotic-industries.gate-gui-receiver-strain-label", data.receiver_strain_text}

    if data.preview_surface_index and data.preview_pos then
        camera.surface_index = data.preview_surface_index
        camera.position = data.preview_pos
    else
        camera.position = GATE_CAMERA_FALLBACK_POSITION
    end

    -- State button
    if data.state then
        state.style = "ei_small_green_button"
        state.caption = GATE_STATE_ON_CAPTION
    else
        state.style = "ei_small_red_button"
        state.caption = GATE_STATE_OFF_CAPTION
    end

    if projection_cache then
        projection_cache[player.index] = {
            gate_unit = data.gate_unit,
            signature = data.gui_projection_signature,
        }
    end

end


function model.update_player_guis(event)
    local gate_storage = storage.ei and storage.ei.gate or nil
    local open_gui_players = gate_storage and gate_storage.open_gui_players or nil
    if not open_gui_players or not next(open_gui_players) then
        return
    end

    local gate_registry = gate_storage and gate_storage.gate or nil
    local gui_elements_cache = gate_storage and gate_storage.gui_elements_cache or nil
    local projection_cache = gate_storage and gate_storage.gui_projection_cache or nil
    local data_by_gate_unit = {}

    for player_index, gate_unit in pairs(open_gui_players) do
        local player = game.get_player(player_index)
        if not player or not player.valid then
            clear_gate_gui_session(player_index)
            goto continue
        end

        local cached_gui = gui_elements_cache and gui_elements_cache[player_index] or nil
        local root = nil
        if gui_elements_valid(cached_gui) then
            root = cached_gui.root
        else
            if gui_elements_cache then
                gui_elements_cache[player_index] = nil
            end
            cached_gui = nil
            root = player.gui.relative["ei-gate-console"]
        end

        if not root then
            clear_gate_gui_session(player_index)
            goto continue
        end

        gate_unit = gate_unit or (root.tags and root.tags.gate_unit)
        local gate_entry = gate_unit and gate_registry and gate_registry[gate_unit] or nil
        if not gate_unit or not gate_entry then
            model.close_gui(player)
            goto continue
        end

        local gate = gate_entry.gate
        if not gate or not gate.valid then
            model.close_gui(player)
            goto continue
        end

        local data = data_by_gate_unit[gate_unit]
        if not data then
            data = model.get_data(gate, event)
            data_by_gate_unit[gate_unit] = data
        end

        local previous_projection = projection_cache and projection_cache[player_index] or nil
        if previous_projection
        and previous_projection.gate_unit == data.gate_unit
        and previous_projection.signature == data.gui_projection_signature
        and gui_elements_valid(cached_gui) then
            goto continue
        end

        model.update_gui(player, data, true, gate, cached_gui)
        ::continue::
    end

end


function model.update_receiver_selection(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gui = model.get_gui_elements(player)
    if not gui then return end

    local dropdown = gui.dropdown
    if not dropdown.tags or not dropdown.tags.receiver_ids then
        return
    end
    local receiver_id = dropdown.tags.receiver_ids[dropdown.selected_index]
    if not receiver_id then
        return
    end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    if not model.set_manual_receiver(gate_unit, receiver_id, event) then
        return
    end
    model.refresh_gate_live_state(gate, event)

    local data = model.get_data(gate, event)
    model.update_gui(player, data, false, gate, gui)

end


function model.toggle_state(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    gate_data.manual_enabled = not gate_data.manual_enabled
    gate_data.state = gate_data.manual_enabled
    mark_gate_resolution_dirty(gate_data)

    if gate_data.manual_enabled and gate.energy < LOW_POWER_J then
        ei_lib.notify_connected_players(
            "gate",
            {"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name}
        )
    end

    model.refresh_gate_live_state(gate, event)

    -- GUI update is cosmetic — guard against missing GUI
    local gui = model.get_gui_elements(player)
    if gui then
        local data = model.get_data(gate, event)
        model.update_gui(player, data, false, gate, gui)
    end

end


function model.choose_position(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    -- if currently a selection is in progress for this player
    if storage.ei.gate.remote and storage.ei.gate.remote[player.index] then return end

    local gate_data = storage.ei.gate.gate[gate_unit]
    local target_exit = gate_data.legacy_exit or gate_data.effective_exit or gate_data.exit
    local target_surface_name = target_exit and target_exit.surface or gate.surface.name
    local target_surface = game.get_surface(target_surface_name)
    if not target_surface then target_surface = gate.surface end

    local center_pos = {0, 0}
    if target_exit and target_exit.x then
        center_pos = {target_exit.x, target_exit.y}
    end

    -- Store state
    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

    local was_remote = player.controller_type == defines.controllers.remote
    storage.ei.gate.remote[player.index] = {
        gate_unit = gate_unit,
        was_remote = was_remote,
        original_character = not was_remote and player.character or nil
    }

    -- Switch to remote view on target surface
    if not was_remote then
        player.set_controller{type = defines.controllers.remote, surface = target_surface, position = center_pos}
    end

    -- Give player the selection tool
    player.cursor_stack.set_stack({name = "ei-gate-position-selector", count = 1})

    player.print({"exotic-industries.gate-position-selection-instructions"})

end


function model.get_data(gate, event)

    if not model.entity_check(gate) then return end

    local gate_unit = get_entity_unit_number(gate)
    if not gate_unit then
        return nil
    end

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    if not gate_data then
        return nil
    end

    -- Package everything the GUI needs up front so the renderer can stay declarative and does not
    -- need to understand storage layout or receiver resolution rules.
    model.resolve_gate_target(gate, event)

    local data = {
        gate_unit = gate_unit,
    }
    if gate.electric_buffer_size then
        data.max_energy = gate.electric_buffer_size
    end
    if gate.energy then
        data.energy = gate.energy
    else
        data.energy = 0
    end
    data.energy_mj_text = string.format("%.0f", data.energy / 1000000)
    data.max_energy = math.max(data.max_energy or 0, 1)
    data.stress = math.floor((gate_data.stress or 0) + 0.5)
    data.stress_ratio = clamp((gate_data.stress or 0) / MAX_GATE_STRESS, 0, 1)

    local target_surface = model.get_gate_target_surface(gate_data)
    local span_data = gate_data.distance_snapshot or model.update_distance_snapshot(gate, gate_data)
    if span_data and (span_data.gui_caption == nil or span_data.gui_tooltip == nil or span_data.gui_value == nil) then
        span_data = decorate_distance_snapshot(span_data, gate.surface, target_surface)
        gate_data.distance_snapshot = span_data
    end
    data.span_target_surface_index = span_data and (span_data.gui_target_surface_index or 0) or 0
    data.span_multiplier_raw = span_data and (span_data.gui_multiplier_raw or 0) or 0
    data.span_distance_raw = span_data and (span_data.gui_distance_raw or 0) or 0
    data.span_resolved = span_data and (span_data.gui_resolved == true) or false
    data.span_caption = span_data and span_data.gui_caption or GATE_SPAN_UNRESOLVED_CAPTION
    data.span_tooltip = span_data and span_data.gui_tooltip or GATE_SPAN_UNRESOLVED_TOOLTIP
    data.span_value = span_data and (span_data.gui_value or 0) or 0

    local dropdown_snapshot = model.get_receiver_dropdown_snapshot(gate.force.index)
    local receiver_items = dropdown_snapshot.receiver_items
    local receiver_ids = dropdown_snapshot.receiver_ids
    local selected_index = dropdown_snapshot.selected_index_by_receiver_id[gate_data.manual_receiver_id] or 1
    local receiver_dropdown_variant = "normal"
    local receiver_dropdown_variant_id = 0

    if gate_data.manual_receiver_id and selected_index == 1 then
        receiver_dropdown_variant_id = gate_data.manual_receiver_id
        if gate_data.manual_target_conflicted then
            receiver_dropdown_variant = "conflict"
        else
            receiver_dropdown_variant = "unavailable"
        end
        receiver_items = get_receiver_dropdown_variant_items(
            gate.force.index,
            receiver_items,
            receiver_dropdown_variant,
            gate_data.manual_receiver_id
        )
    end

    local preview_exit = model.get_preview_exit(gate_data)
    if preview_exit then
        local preview_surface_index = preview_exit.surface_index
        if not preview_surface_index and preview_exit.surface then
            local preview_surface = game.get_surface(preview_exit.surface)
            preview_surface_index = preview_surface and preview_surface.index or nil
            preview_exit.surface_index = preview_surface_index
        end

        if preview_surface_index then
            data.preview_surface_index = preview_surface_index
            local preview_position = preview_exit.preview_position
            if not preview_position
            or preview_position.x ~= preview_exit.x
            or preview_position.y ~= preview_exit.y then
                preview_position = {
                    x = preview_exit.x,
                    y = preview_exit.y
                }
                preview_exit.preview_position = preview_position
            end
            data.preview_pos = preview_position
        end
    end

    if gate_data.legacy_exit and not gate_data.manual_receiver_id then
        data.legacy_status_mode = "destination"
        data.legacy_surface = gate_data.legacy_exit.surface
        data.legacy_x = gate_data.legacy_exit.x
        data.legacy_y = gate_data.legacy_exit.y
        data.legacy_status = get_cached_legacy_status(gate_data.legacy_exit)
    else
        data.legacy_status_mode = "none"
        data.legacy_surface = ""
        data.legacy_x = 0
        data.legacy_y = 0
        data.legacy_status = GATE_LEGACY_STATUS_NONE
    end

    data.receiver_items = receiver_items
    data.receiver_ids = receiver_ids
    data.selected_index = selected_index
    data.receiver_dropdown_generation = storage.ei.gate.receiver_dropdown_cache.generation or 0
    data.receiver_dropdown_variant = receiver_dropdown_variant
    data.receiver_dropdown_variant_id = receiver_dropdown_variant_id
    data.state = gate_data.manual_enabled

    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        data.runtime_status_mode = "cooling"
        data.runtime_status = GATE_RUNTIME_STATUS_COOLING_TEXT
    elseif (gate_data.stress or 0) >= 75 then
        data.runtime_status_mode = "critical"
        data.runtime_status = GATE_RUNTIME_STATUS_CRITICAL_TEXT
    else
        data.runtime_status_mode = "stable"
        data.runtime_status = GATE_RUNTIME_STATUS_STABLE_TEXT
    end

    local receiver_data = model.get_effective_receiver_data(gate_data, event)
    local receiver_saturation = receiver_data and receiver_data.saturation or 0
    if receiver_saturation >= MAX_RECEIVER_SATURATION then
        data.receiver_strain_mode = "saturated"
        data.receiver_strain_text = GATE_RECEIVER_STRAIN_SATURATED_TEXT
    elseif receiver_saturation >= 60 then
        data.receiver_strain_mode = "high"
        data.receiver_strain_text = GATE_RECEIVER_STRAIN_HIGH_TEXT
    elseif receiver_saturation >= 25 then
        data.receiver_strain_mode = "medium"
        data.receiver_strain_text = GATE_RECEIVER_STRAIN_MEDIUM_TEXT
    else
        data.receiver_strain_mode = "low"
        data.receiver_strain_text = GATE_RECEIVER_STRAIN_LOW_TEXT
    end

    if gate_data.control_source == "circuit" then
        data.control_source_mode = "circuit"
        data.control_source_text = GATE_CONTROL_SOURCE_CIRCUIT_TEXT
    else
        data.control_source_mode = "manual"
        data.control_source_text = GATE_CONTROL_SOURCE_MANUAL_TEXT
    end

    data.gui_projection_signature = make_gate_gui_projection_signature(data)

    return data

end


function model.change_permission(player, new_group, old_group)

    new_group = new_group or "Default"
    old_group = old_group or "Default"

    if not game.permissions.get_group(new_group) then
        -- print error
        game.print("Error: Permission group '" .. new_group .. "' does not exist!")
        return
    end

    if not game.permissions.get_group(old_group) then
        -- print error
        game.print("Error: Permission group '" .. old_group .. "' does not exist!")
        return
    end

    player.permission_group = game.permissions.get_group(new_group)

end

--[[
function model.update_player_permissions()

    if not script.active_mods["RemoteConfiguration"] then
        return
    end

    if not storage.ei.gate.gate_user_permission then
        return
    end

    for player_id,tick in pairs(storage.ei.gate.gate_user_permission) do
        if game.tick > tick then
            local player = game.get_player(player_id)
            if player then
                player.permission_group = game.permissions.get_group("gate-user")
            end
            storage.ei.gate.gate_user_permission[player_id] = nil
        end
    end

end
]]

local function migrate_existing_gate_proxy_connections(event)
    if not storage.ei or not storage.ei.gate or not storage.ei.gate.gate then
        return
    end

    for gate_unit, _ in pairs(storage.ei.gate.gate) do
        model.ensure_gate_defaults(gate_unit, event)
    end
end

--HANDLERS
-----------------------------------------------------------------------------------------------------

function model.on_init(event)
    model.check_global_init()
    model.rebuild_distance_cache()
    migrate_existing_gate_proxy_connections(event)
end


function model.on_configuration_changed(event)
    model.check_global_init()
    model.rebuild_distance_cache()
    migrate_existing_gate_proxy_connections(event)
end

function model.on_built_entity(event)

    local entity = event and event.entity

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate-container" then
        model.make_gate(entity, event)
        return
    end

    if entity.name == "ei-gate-receiver" then
        model.register_receiver(entity, event)
    end

end


function model.on_destroyed_entity(event)

    local entity = event and event.entity
    local transfer = nil or (event and event.robot) or (event and event.player_index)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate-receiver" then
        model.destroy_receiver(entity, event)
        return
    end

    if entity.name ~= "ei-gate" and entity.name ~= "ei-gate-container" then
        return
    end

    if not model.transfer_valid(transfer) then
        return
    end

    if entity.name == "ei-gate" then

        model.destroy_gate(entity, nil, event)
        return

    end

    -- normaly gate gets mined/destroyed first
    if entity.name == "ei-gate-container" then

        model.destroy_gate(nil, entity, event)
        return

    end

end


function model.update(event)

    model.check_global_init()

    if not storage.ei.gate then
        return false
    end

    local gate_registry = storage.ei.gate.gate
    if not gate_registry then
        return false
    end

    local tick = event and event.tick or game.tick
    local live_state_refreshed_this_tick = false
    if storage.ei.gate.last_housekeeping_tick ~= tick then
        storage.ei.gate.last_housekeeping_tick = tick

        model.refresh_receivers(event)
        if storage.ei.gate.receiver_registry_dirty then
            for gate_unit, gate_data in pairs(gate_registry) do
                local gate = gate_data.gate
                if model.entity_check(gate) then
                    model.refresh_gate_live_state(gate, event)
                end
            end
            live_state_refreshed_this_tick = true
            storage.ei.gate.receiver_registry_dirty = false
        end

        model.update_player_guis(event)
    end

    local first_gate = nil
    if not storage.ei.gate.gate_break_point then
        first_gate = next(gate_registry)
    end

    if first_gate then
       storage.ei.gate.gate_break_point = first_gate
    end

    if not storage.ei.gate.gate_break_point then
        return false
    end

    local break_id = storage.ei.gate.gate_break_point
    local gate_entry = break_id and gate_registry[break_id] or nil
    local current_gate_exists = gate_entry ~= nil
    if gate_entry then
        local gate = gate_entry.gate
        if model.entity_check(gate) then
            if not live_state_refreshed_this_tick then
                model.ensure_gate_defaults(break_id, event)
                model.resolve_gate_target(gate, event)
            end
            model.update_energy(break_id, gate, event)
            model.check_for_teleport(break_id, gate, event)
            model.update_renders(break_id, gate, event)
        else
            gate_registry[break_id] = nil
            current_gate_exists = false
        end
    end

    local next_break_id
    if current_gate_exists then
        next_break_id = next(gate_registry, break_id)
    else
        next_break_id = next(gate_registry)
    end

    if next_break_id then
        storage.ei.gate.gate_break_point = next_break_id
        return true
    else
       storage.ei.gate.gate_break_point = nil
       return false
    end

end

function model.get_runtime_status()
    model.check_global_init()

    local gate_count = ei_runtime_scheduler.table_count(storage.ei.gate.gate)

    local status = {
        gate_count = gate_count,
        receiver_count = ei_runtime_scheduler.table_count(storage.ei.gate.receiver),
        receiver_force_count = ei_runtime_scheduler.table_count(storage.ei.gate.receiver_by_force),
        receiver_registry_dirty = storage.ei.gate.receiver_registry_dirty == true,
        gate_break_point = storage.ei.gate.gate_break_point,
        last_housekeeping_tick = storage.ei.gate.last_housekeeping_tick or -1,
        gates = gate_count,
        breakpoint = storage.ei.gate.gate_break_point,
    }

    ei_runtime_scheduler.set_module_status("gate", status)
    return status
end

function model.used_remote(event)

    local position = event.target_position
    local surface = game.get_surface(event.surface_index)

    -- Identify the player from the source entity (the character that threw the capsule)
    if not event.source_entity or not event.source_entity.valid then return end
    local player = event.source_entity.player
    if not player then return end

    local player_index = player.index
    if not storage.ei.gate.remote or not storage.ei.gate.remote[player_index] then return end

    local gate_unit = storage.ei.gate.remote[player_index].gate_unit
    if not gate_unit then
        model.cleanup_position_selection(player_index)
        return
    end

    -- Set the gate exit position
    if storage.ei.gate.gate[gate_unit] then
        model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true, event)
    end

    model.cleanup_position_selection(player_index)

end


function model.on_player_selected_area(event)
    if event.item ~= "ei-gate-position-selector" then return end

    local player_index = event.player_index
    if not storage.ei.gate.remote or not storage.ei.gate.remote[player_index] then return end

    local gate_unit = storage.ei.gate.remote[player_index].gate_unit
    if not gate_unit then
        model.cleanup_position_selection(player_index)
        return
    end

    -- Calculate center of selection area (single-click = tiny area, center ≈ click pos)
    local area = event.area
    local position = {
        x = (area.left_top.x + area.right_bottom.x) / 2,
        y = (area.left_top.y + area.right_bottom.y) / 2
    }
    local surface = event.surface

    -- Set the gate exit position
    if storage.ei.gate.gate[gate_unit] then
        model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true, event)
    end

    model.cleanup_position_selection(player_index)
end


function model.cleanup_position_selection(player_index)
    if not storage.ei.gate.remote then return end
    local remote_data = storage.ei.gate.remote[player_index]
    if not remote_data then return end

    local player = game.get_player(player_index)
    if player then
        -- Clear selection tool from cursor if still held
        if player.cursor_stack and player.cursor_stack.valid_for_read
           and player.cursor_stack.name == "ei-gate-position-selector" then
            player.cursor_stack.clear()
        end

        -- Exit remote view if we entered it
        if not remote_data.was_remote and player.controller_type == defines.controllers.remote then
            local character = remote_data.original_character
            if character and character.valid then
                player.set_controller{type = defines.controllers.character, character = character}
            elseif player.character and player.character.valid then
                player.set_controller{type = defines.controllers.character, character = player.character}
            else
                player.set_controller{type = defines.controllers.character}
                log("[ESI:R gate] cleanup: no valid character for player " .. player.name .. ", created new one")
            end
        end
    end

    storage.ei.gate.remote[player_index] = nil
end


function model.cleanup_gate_remote_selection(gate_unit)
    if not storage.ei.gate or not storage.ei.gate.remote then
        return
    end

    local affected_players = {}
    for player_index, remote_data in pairs(storage.ei.gate.remote) do
        if remote_data and remote_data.gate_unit == gate_unit then
            affected_players[#affected_players + 1] = player_index
        end
    end

    for _, player_index in ipairs(affected_players) do
        model.cleanup_position_selection(player_index)
    end
end


--GUI HANDLER
-----------------------------------------------------------------------------------------------------

function model.on_gui_selection_state_changed(event)
    local tags = event.element.tags

    if tags.action == "set-receiver" then
        model.update_receiver_selection(game.get_player(event.player_index), tags.gate_unit, event)
    end
end


function model.close_gui(player)
    if not player or not player.valid then
        return
    end

    clear_gate_gui_session(player.index, player, true)
end


function model.on_gui_opened(event)
    local player = game.get_player(event.player_index)
    if not player then
        return
    end

    model.check_global_init()

    local entity = event.entity
    if model.entity_check(entity) and entity.name == "ei-gate" then
        local gate_unit = get_entity_unit_number(entity)
        local gate_data = gate_unit and storage.ei.gate.gate and storage.ei.gate.gate[gate_unit] or nil
        if gate_data and model.entity_check(gate_data.container) then
            storage.ei.gate.open_redirect[event.player_index] = true
            player.opened = gate_data.container
            return
        end
    end

    if storage.ei.gate.open_redirect[event.player_index] then
        storage.ei.gate.open_redirect[event.player_index] = nil
    end

    model.open_gui(player, event)
end


function model.on_gui_click(event)
    local tags = event.element.tags
    local gate_unit = tags.gate_unit

    if tags.action == "set-state" then
        model.toggle_state(game.get_player(event.player_index), gate_unit, event)
        return
    end

    if tags.action == "set-position" then
        model.choose_position(game.get_player(event.player_index), gate_unit, event)
        return
    end

    if tags.action == "goto-informatron" then
        local player = game.get_player(event.player_index)
        if player and player.force.technologies["ei-gate"].enabled == true then
            remote.call("informatron", "informatron_open_to_page", {
                player_index = event.player_index,
                interface = "exotic-industries-informatron",
                page_name = tags.page
            })
            return
        end
    end
end


function model.on_player_left_game(player_index)
    if not storage.ei.gate then return end

    clear_gate_gui_session(player_index)

    if not storage.ei.gate.remote then return end
    if not storage.ei.gate.remote[player_index] then return end

    -- Only clear cursor and storage, skip controller restoration (Factorio handles player state on disconnect)
    local player = game.get_player(player_index)
    if player then
        if player.cursor_stack and player.cursor_stack.valid_for_read
           and player.cursor_stack.name == "ei-gate-position-selector" then
            player.cursor_stack.clear()
        end
    end
    storage.ei.gate.remote[player_index] = nil
end


function model.on_player_cursor_stack_changed(event)
    if not storage.ei.gate then return end
    if not storage.ei.gate.remote then return end

    local player_index = event.player_index
    local remote_data = storage.ei.gate.remote[player_index]
    if not remote_data then return end

    local player = game.get_player(player_index)
    if not player then
        storage.ei.gate.remote[player_index] = nil
        return
    end

    -- If cursor no longer holds the gate position selector, clean up
    if not player.cursor_stack or not player.cursor_stack.valid_for_read
       or player.cursor_stack.name ~= "ei-gate-position-selector" then
        model.cleanup_position_selection(player_index)
    end
end

return model
