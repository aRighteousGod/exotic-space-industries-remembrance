-- Tesla's Legacy runtime for EI.
--
-- This module owns all live Tesla scripting after the internalization work. The vendored
-- `teslas_legacy/control.lua` stays inert on purpose; `control.lua` in the base mod is the
-- only place that registers events, and it forwards the relevant callbacks here just like
-- the rest of EI's control-stage modules.
--
-- Design goals for future edits:
-- - Keep hot-path dispatch narrow and exact; avoid broad combat hooks.
-- - Preserve TL's distinctive tank volatility/vaporize behavior.
-- - Let data-stage prototypes do as much work as possible, with Lua only filling the gaps.
-- - Keep state rebuildable from world + force research instead of trusting old helper state.
local model = {}

require("teslas_legacy.config.research")
require("teslas_legacy.config.settings")

local tl_settings = get_settings()
-- Legacy-fidelity is the owned default and preserves the original TL helper substrate.
-- Hybrid is the explicit opt-in lighter lattice path.
local BEHAVIOR_MODE = tl_settings.behavior_mode or "legacy-fidelity"

-- Runtime bookkeeping windows. These stay intentionally short because they exist only to
-- correlate script-trigger hits with immediate follow-up kill logic.
local RECENT_HIT_TTL = 5
local BURST_GATE_TTL = 1
local BURST_GATE_PRUNE_TTL = 30
local PRUNE_INTERVAL = 600
local VAPORIZE_DAMAGE_THRESHOLD = 5000

-- Ammo categories that the runtime understands. The bridge categories let vanilla Tesla
-- weapons opt into TL-style scripted follow-ups without changing the public TL names.
local LEGACY_CATEGORY = {
    family = "ei-legacy-tesla-family",
    turret = "ei-legacy-tesla-turret",
    tank = "tl-tesla-coil-ammo-category",
}

local BRIDGE_BASE_DAMAGE = {
    family = 30,
    turret = 120,
}

-- Exact script-effect ids injected during data stage. These are the primary runtime entry
-- points, so downstream logic can dispatch by a compact table lookup instead of string scans.
local EFFECT_ID = {
    critical = "tl-critical-hit-effect-id",
    critical_ei = "ei-tl-crit-text",
    legacy_timer = "tl-basic-tesla-coil-timer-effect-id",
    tl_basic_hit = "ei-tl-hit-basic",
    tl_advanced_hit = "ei-tl-hit-advanced",
    tl_tank_hit = "ei-tl-hit-tank",
    tl_basic_chain = "ei-tl-basic-chain-hit",
    tl_basic_chain_h3 = "ei-tl-basic-chain-hit-h3",
    tl_basic_chain_exotic = "ei-tl-basic-chain-hit-exotic",
    tl_advanced_chain = "ei-tl-advanced-chain-hit",
    tl_advanced_chain_h3 = "ei-tl-advanced-chain-hit-h3",
    tl_advanced_chain_exotic = "ei-tl-advanced-chain-hit-exotic",
    tl_tank_chain = "ei-tl-tank-chain-hit",
    tl_tank_chain_h3 = "ei-tl-tank-chain-hit-h3",
    tl_tank_chain_exotic = "ei-tl-tank-chain-hit-exotic",
    bridge_family_hit = "ei-tl-hit-bridge-family",
    bridge_turret_hit = "ei-tl-hit-bridge-turret",
    bridge_family_chain = "ei-tl-bridge-family-chain-hit",
    bridge_turret_chain = "ei-tl-bridge-turret-chain-hit",
    bridge_turret_chain_h3 = "ei-tl-bridge-turret-chain-hit-h3",
    bridge_turret_chain_exotic = "ei-tl-bridge-turret-chain-hit-exotic",
}

local EXOTIC_VARIANT = {
    basic = {
        public = "tl-basic-tesla-coil",
        exotic = "tl-basic-tesla-coil__exotic",
    },
    advanced = {
        public = "tl-advanced-tesla-coil",
        exotic = "tl-advanced-tesla-coil__exotic",
    },
}

-- TL research still exposes the original public technology names. The runtime resolves the
-- researched tiers once per force and caches the resulting numeric values for hot-path use.
local TECH_PREFIX = {
    multi_zap = {
        probability = "tl-multi-zap-probability-technology",
        damage = "tl-multi-zap-damage-technology",
        range = "tl-multi-zap-range-technology",
    },
    slowdown = {
        probability = "tl-slowdown-probability-technology",
        duration = "tl-slowdown-duration-technology",
        multiplier = "tl-slowdown-multiplier-technology",
    },
    single_zap = {
        probability = "tl-single-zap-probability-technology",
        damage = "tl-single-zap-damage-technology",
        count = "tl-single-zap-count-technology",
    },
    flames = {
        probability = "tl-flames-probability-technology",
        explosion = "tl-flames-explosion-technology",
        count = "tl-flames-count-technology",
    },
    volatility = {
        probability = "tl-volatility-probability-technology",
        modulation = "tl-volatility-modulation-technology",
    },
}

-- Floating-text colors stay centralized here so combat readouts remain easy to tweak without
-- spelunking through the damage/vaporize/critical helpers later.
local DAMAGE_TEXT_COLOR = {
    gray = {r = 0.50, g = 0.50, b = 0.50, a = 1},
    white = {r = 1, g = 1, b = 1, a = 1},
    blue = {r = 0.40, g = 0.63, b = 1, a = 1},
    gold = {r = 1, g = 0.84, b = 0.10, a = 1},
    purple = {r = 0.70, g = 0, b = 0.70, a = 1},
    green = {r = 0, g = 0.60, b = 0.20, a = 1},
}

local function starts_with(value, prefix)
    return string.find(value or "", prefix, 1, true) == 1
end

local function get_multi_zap_name(index)
    return "tl-basic-tesla-coil-multi-zap-"
        .. index.multi_zap.range .. "-"
        .. index.multi_zap.damage .. "-"
        .. index.slowdown.duration .. "-"
        .. index.slowdown.multiplier .. "-"
        .. index.slowdown.probability
end

local function get_single_zap_name(index)
    return "tl-basic-tesla-coil-single-zap-"
        .. index.single_zap.damage .. "-"
        .. index.single_zap.count
end

local function get_tesla_coil_zap_fire_name(index)
    return "tl-tesla-coil-zap-fire-" .. index.flames.count
end

local function get_tesla_coil_zap_explosion_name(index)
    return "tl-tesla-coil-zap-explosion-"
        .. index.flames.explosion .. "-"
        .. index.flames.probability
end

local function get_single_zap_range()
    return tl_settings.turret.advanced.range.max / 4
end

local function get_basic_doctrine_helper_name(harmonics_suffix, range_index, storm_level)
    return "ei-tl-basic-field-arc-" .. harmonics_suffix .. "-" .. range_index .. "-" .. storm_level
end

local function get_advanced_doctrine_helper_name(harmonics_suffix, count_index, dielectric_level)
    return "ei-tl-advanced-overcharge-" .. harmonics_suffix .. "-" .. count_index .. "-" .. dielectric_level
end

local function get_tank_doctrine_helper_name(harmonics_suffix, range_index, overdrive_level)
    return "ei-tl-tank-stormbeam-" .. harmonics_suffix .. "-" .. range_index .. "-" .. overdrive_level
end

local function get_basic_exotic_helper_name(range_index)
    return "ei-tl-basic-field-arc-exotic-" .. range_index
end

local function get_advanced_exotic_helper_name(count_index)
    return "ei-tl-advanced-overcharge-exotic-" .. count_index
end

local function get_tank_exotic_helper_name(range_index)
    return "ei-tl-tank-stormbeam-exotic-" .. range_index
end

-- `storage.ei.tesla_legacy` is the only persisted runtime root for the owned TL module.
-- Everything else in this file should derive from or feed back into this one state table.
local function ensure_state()
    storage.ei = storage.ei or {}

    local state = storage.ei.tesla_legacy
    if not state then
        state = {}
        storage.ei.tesla_legacy = state
    end

    state.force_cache = state.force_cache or {}
    state.recent_hits_by_unit = state.recent_hits_by_unit or {}
    state.recent_hits_by_position = state.recent_hits_by_position or {}
    state.burst_gates = state.burst_gates or {}
    state.last_prune_tick = state.last_prune_tick or 0

    return state
end

local function quantize_component(value)
    return math.floor((value * 1000) + 0.5)
end

local function copy_position(position)
    if not position then
        return nil
    end

    return {x = position.x, y = position.y}
end

local function make_position_key(surface_index, position)
    if not surface_index or not position then
        return nil
    end

    return surface_index
        .. ":"
        .. quantize_component(position.x)
        .. ":"
        .. quantize_component(position.y)
end

-- TL now uses a local math.randomseed/math.random flow instead of EI's shared RNG helper.
-- The seed intentionally mixes together tick, entity identity, force, and effect family so
-- same-tick Tesla hits do not collapse into obviously repetitive rolls.
local function create_seed(...)
    local seed = 1

    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "number" then
            seed = (seed * 1103515245 + math.floor(value * 1000) + 12345) % 2147483647
        elseif type(value) == "string" then
            for byte_index = 1, #value do
                seed = (seed * 33 + string.byte(value, byte_index)) % 2147483647
            end
        end
    end

    if seed <= 0 then
        seed = 1
    end

    return seed
end

local function random_unit(...)
    math.randomseed(create_seed(...))
    return math.random(1, 1000000) / 1000000
end

local function passes_roll(probability, ...)
    if not probability or probability <= 0 then
        return false
    end

    return random_unit(...) < probability
end

local function get_surface_from_index(surface_index)
    if not surface_index then
        return nil
    end

    return game.surfaces[surface_index]
end

local function get_valid_entity(entity)
    if entity and entity.valid then
        return entity
    end

    return nil
end

local function get_origin_cause(subject)
    local cause_entity = subject and subject.cause_entity
    if cause_entity and cause_entity.valid then
        return cause_entity
    end

    local source_entity = subject and subject.source_entity
    if source_entity and source_entity.valid then
        return source_entity
    end

    return nil
end

local function get_origin_source(subject)
    local source_entity = subject and subject.source_entity
    if source_entity and source_entity.valid then
        return source_entity
    end

    return nil
end

local function get_effect_force(event)
    local cause_entity = get_origin_cause(event)
    if cause_entity then
        return cause_entity.force
    end

    local source_entity = get_origin_source(event)
    if source_entity then
        return source_entity.force
    end

    return nil
end

local function get_effect_surface(event)
    local target_entity = get_valid_entity(event and event.target_entity)
    if target_entity then
        return target_entity.surface
    end

    local source_entity = get_origin_source(event)
    if source_entity then
        return source_entity.surface
    end

    local cause_entity = get_origin_cause(event)
    if cause_entity then
        return cause_entity.surface
    end

    return get_surface_from_index(event and event.surface_index)
end

local function get_effect_position(event)
    local target_entity = get_valid_entity(event and event.target_entity)
    if target_entity then
        return target_entity.position
    end

    if event and event.target_position then
        return event.target_position
    end

    local source_entity = get_origin_source(event)
    if source_entity then
        return source_entity.position
    end

    return event and event.source_position or nil
end

local function get_effect_target(event)
    return get_valid_entity(event and event.target_entity)
end

local function create_entity_with_origin(surface, position, name, force, source_entity, cause_entity)
    if not surface or not position or not name then
        return nil
    end

    local params = {
        name = name,
        position = position,
    }

    if force then
        params.force = force
    end

    if source_entity and source_entity.valid and source_entity.surface == surface then
        params.source = source_entity
    end

    if cause_entity and cause_entity.valid then
        params.cause = cause_entity
    end

    return surface.create_entity(params)
end

-- Fidelity-mode helper entities must behave like the original TL mod, which means they are
-- spawned plainly at a position for a force and become the direct damage cause themselves.
-- We intentionally do not thread source/cause metadata through these spawns.
local function create_plain_entity(surface, position, name, force)
    if not surface or not position or not name then
        return nil
    end

    local params = {
        name = name,
        position = position,
    }

    if force then
        params.force = force
    end

    return surface.create_entity(params)
end

local function create_runtime_entity(surface, position, name, force, subject)
    return create_entity_with_origin(
        surface,
        position,
        name,
        force,
        get_origin_source(subject),
        get_origin_cause(subject)
    )
end

local function create_visual(surface, position, name, subject)
    return create_entity_with_origin(
        surface,
        position,
        name,
        nil,
        get_origin_source(subject),
        get_origin_cause(subject)
    )
end

local function legacy_random_number(seed)
    math.randomseed(seed or 1)
    return math.random(1, 9999) / 10000
end

local function has_enemy_in_range(surface, position, distance, force)
    if not surface or not position or not distance then
        return false
    end

    local args = {
        position = position,
        max_distance = distance,
    }

    if force then
        args.force = force
    end

    return surface.find_nearest_enemy(args) ~= nil
end

-- Bridge helpers are allowed to continue only when there is another enemy in the same local
-- geometry neighborhood. That keeps the follow-up arc anchored to the visible exchange instead
-- of waking a helper because some unrelated target happened to be inside a wide wake bubble.
local function bridge_has_other_enemy_in_range(surface, position, distance, force, excluded_entity)
    if not surface or not position or not distance then
        return false
    end

    local excluded_unit_number = excluded_entity and excluded_entity.unit_number or nil
    local entities = surface.find_entities_filtered({
        area = {
            left_top = {
                x = position.x - distance,
                y = position.y - distance,
            },
            right_bottom = {
                x = position.x + distance,
                y = position.y + distance,
            },
        },
    })

    for _, entity in pairs(entities) do
        if entity
            and entity.valid
            and entity.destructible
            and entity.force
            and entity.force.is_enemy(force)
            and entity ~= excluded_entity
            and entity.unit_number ~= excluded_unit_number
        then
            local delta_x = entity.position.x - position.x
            local delta_y = entity.position.y - position.y
            if (delta_x * delta_x) + (delta_y * delta_y) <= (distance * distance) then
                return true
            end
        end
    end

    return false
end

local function get_harmonics_level(force)
    if force.technologies["ei-waveform-harmonics-3"] and force.technologies["ei-waveform-harmonics-3"].researched then
        return 3
    end

    if force.technologies["ei-waveform-harmonics-2"] and force.technologies["ei-waveform-harmonics-2"].researched then
        return 2
    end

    if force.technologies["ei-waveform-harmonics-1"] and force.technologies["ei-waveform-harmonics-1"].researched then
        return 1
    end

    return 0
end

local function get_researched_index(force, prefix, max_level)
    local index = 1

    for level = 1, max_level do
        local technology = force.technologies[prefix .. "-" .. level]
        if technology and technology.researched then
            index = level + 1
        else
            break
        end
    end

    return index
end

local function get_upgrade_level(force, prefix, max_level)
    return get_researched_index(force, prefix, max_level) - 1
end

local function get_damage_multiplier(force, ammo_category)
    if not force or not ammo_category then
        return 1
    end

    return 1 + force.get_ammo_damage_modifier(ammo_category)
end

-- Force caches collapse the verbose TL tech tree into the concrete numbers the runtime needs
-- during combat. Recomputing them only on init/config-change/research-finished keeps the
-- event path much cheaper than repeatedly crawling force technologies during hits.
local function build_force_cache(force)
    local research_array = get_research_array()
    local index = get_default_index()

    index.multi_zap.probability = get_researched_index(force, TECH_PREFIX.multi_zap.probability, #research_array.multi_zap.probability - 1)
    index.multi_zap.damage = get_researched_index(force, TECH_PREFIX.multi_zap.damage, #research_array.multi_zap.damage - 1)
    index.multi_zap.range = get_researched_index(force, TECH_PREFIX.multi_zap.range, #research_array.multi_zap.range - 1)

    index.slowdown.probability = get_researched_index(force, TECH_PREFIX.slowdown.probability, #research_array.slowdown.probability - 1)
    index.slowdown.duration = get_researched_index(force, TECH_PREFIX.slowdown.duration, #research_array.slowdown.duration - 1)
    index.slowdown.multiplier = get_researched_index(force, TECH_PREFIX.slowdown.multiplier, #research_array.slowdown.multiplier - 1)

    index.single_zap.probability = get_researched_index(force, TECH_PREFIX.single_zap.probability, #research_array.single_zap.probability - 1)
    index.single_zap.damage = get_researched_index(force, TECH_PREFIX.single_zap.damage, #research_array.single_zap.damage - 1)
    index.single_zap.count = get_researched_index(force, TECH_PREFIX.single_zap.count, #research_array.single_zap.count - 1)

    index.flames.probability = get_researched_index(force, TECH_PREFIX.flames.probability, #research_array.flames.probability - 1)
    index.flames.explosion = get_researched_index(force, TECH_PREFIX.flames.explosion, #research_array.flames.explosion - 1)
    index.flames.count = get_researched_index(force, TECH_PREFIX.flames.count, #research_array.flames.count - 1)

    index.volatility.probability = get_researched_index(force, TECH_PREFIX.volatility.probability, #research_array.volatility.probability - 1)
    index.volatility.modulation = get_researched_index(force, TECH_PREFIX.volatility.modulation, #research_array.volatility.modulation - 1)

    local research = get_research(index)
    local bridge_aftershock_range = math.max(3, math.floor(get_single_zap_range()))
    local storm_lattice_level = get_upgrade_level(force, "ei-storm-lattice", 3)
    local dielectric_rupture_level = get_upgrade_level(force, "ei-dielectric-rupture", 3)
    local bridge_coupling_level = get_upgrade_level(force, "ei-bridge-coupling", 2)
    local reactance_overdrive_level = get_upgrade_level(force, "ei-reactance-overdrive", 3)
    local exotic_convergence = force.technologies["ei-exotic-waveform-convergence"]
        and force.technologies["ei-exotic-waveform-convergence"].researched
        or false
    local basic_chain_range = 6 + research.multi_zap.range + storm_lattice_level
    local advanced_chain_range = bridge_aftershock_range + dielectric_rupture_level
    local tank_chain_range = 6 + research.multi_zap.range + reactance_overdrive_level
    local basic_chain_h3_range = basic_chain_range * 1.15
    local advanced_chain_h3_range = advanced_chain_range * 1.15
    local tank_chain_h3_range = tank_chain_range * 1.15
    local basic_chain_exotic_range = (6 + research.multi_zap.range + math.max(storm_lattice_level, 3)) * 1.25
    local advanced_chain_exotic_range = (bridge_aftershock_range + math.max(dielectric_rupture_level, 3) + 1) * 1.20
    local tank_chain_exotic_range = (6 + research.multi_zap.range + math.max(reactance_overdrive_level, 3)) * 1.10
    local bridge_aftershock_exotic_range = bridge_aftershock_range * 1.30

    return {
        index = index,
        research = research,
        harmonics_level = get_harmonics_level(force),
        levels = {
            storm_lattice = storm_lattice_level,
            dielectric_rupture = dielectric_rupture_level,
            bridge_coupling = bridge_coupling_level,
            reactance_overdrive = reactance_overdrive_level,
        },
        exotic_convergence = exotic_convergence,
        names = {
            multi_zap = get_multi_zap_name(index),
            single_zap = get_single_zap_name(index),
            fire = get_tesla_coil_zap_fire_name(index),
            explosion = get_tesla_coil_zap_explosion_name(index),
            bridge_family_burst = "ei-legacy-tesla-family-burst-" .. index.multi_zap.range,
            bridge_turret_burst = "ei-legacy-tesla-turret-burst-" .. index.multi_zap.range,
            bridge_aftershock = "ei-legacy-tesla-turret-aftershock-" .. index.single_zap.count,
            bridge_aftershock_h3 = "ei-legacy-tesla-turret-aftershock-h3-" .. index.single_zap.count,
            bridge_aftershock_exotic = "ei-legacy-tesla-turret-aftershock-exotic-" .. index.single_zap.count,
            basic_chain_h2 = get_basic_doctrine_helper_name("h2", index.multi_zap.range, storm_lattice_level),
            basic_chain_h3 = get_basic_doctrine_helper_name("h3", index.multi_zap.range, storm_lattice_level),
            basic_chain_exotic = get_basic_exotic_helper_name(index.multi_zap.range),
            advanced_chain_h2 = get_advanced_doctrine_helper_name("h2", index.single_zap.count, dielectric_rupture_level),
            advanced_chain_h3 = get_advanced_doctrine_helper_name("h3", index.single_zap.count, dielectric_rupture_level),
            advanced_chain_exotic = get_advanced_exotic_helper_name(index.single_zap.count),
            tank_chain_h2 = get_tank_doctrine_helper_name("h2", index.multi_zap.range, reactance_overdrive_level),
            tank_chain_h3 = get_tank_doctrine_helper_name("h3", index.multi_zap.range, reactance_overdrive_level),
            tank_chain_exotic = get_tank_exotic_helper_name(index.multi_zap.range),
            advanced_exotic_impact = "ei-tl-advanced-overcharge-impact",
            tank_exotic_impact = "ei-tl-tank-stormbeam-impact",
        },
        ranges = {
            single_zap = get_single_zap_range(),
            bridge_burst = 6 + research.multi_zap.range,
            bridge_aftershock = bridge_aftershock_range,
            bridge_aftershock_h3 = bridge_aftershock_range * 1.15,
            bridge_aftershock_exotic = bridge_aftershock_exotic_range,
            basic_chain = basic_chain_range,
            basic_chain_h3 = basic_chain_h3_range,
            basic_chain_exotic = basic_chain_exotic_range,
            advanced_chain = advanced_chain_range,
            advanced_chain_h3 = advanced_chain_h3_range,
            advanced_chain_exotic = advanced_chain_exotic_range,
            tank_chain = tank_chain_range,
            tank_chain_h3 = tank_chain_h3_range,
            tank_chain_exotic = tank_chain_exotic_range,
        },
        damage = {
            basic_reference = tl_settings.turret.basic.damage * get_damage_multiplier(force, "tl-basic-tesla-coil-turret-category"),
            advanced_reference = tl_settings.turret.advanced.damage * get_damage_multiplier(force, "tl-advanced-tesla-coil-turret-category"),
            tank_reference = tl_settings.vehicle.tank.damage * get_damage_multiplier(force, LEGACY_CATEGORY.tank),
            bridge_family = BRIDGE_BASE_DAMAGE.family * get_damage_multiplier(force, LEGACY_CATEGORY.family),
            bridge_turret = BRIDGE_BASE_DAMAGE.turret * get_damage_multiplier(force, LEGACY_CATEGORY.turret),
        },
    }
end

local function sync_force_cache(state, force)
    state.force_cache[force.index] = build_force_cache(force)
    return state.force_cache[force.index]
end

local function get_force_cache(state, force)
    if not force then
        return nil
    end

    local cache = state.force_cache[force.index]
    if not cache then
        cache = sync_force_cache(state, force)
    end

    return cache
end

local function sync_all_force_caches(state)
    for _, force in pairs(game.forces) do
        sync_force_cache(state, force)
    end
end

local function get_variant_target_name(entity_name, cache)
    if entity_name == EXOTIC_VARIANT.basic.public or entity_name == EXOTIC_VARIANT.basic.exotic then
        if cache and cache.exotic_convergence then
            return EXOTIC_VARIANT.basic.exotic
        end
        return EXOTIC_VARIANT.basic.public
    end

    if entity_name == EXOTIC_VARIANT.advanced.public or entity_name == EXOTIC_VARIANT.advanced.exotic then
        if cache and cache.exotic_convergence then
            return EXOTIC_VARIANT.advanced.exotic
        end
        return EXOTIC_VARIANT.advanced.public
    end

    return nil
end

local function replace_coil_entity(entity, target_name)
    if not entity or not entity.valid or not target_name or entity.name == target_name then
        return entity
    end

    local surface = entity.surface
    local force = entity.force
    local position = entity.position
    local direction = entity.direction
    local health = entity.health
    local energy = entity.energy or 0
    local destructible = entity.destructible
    local minable = entity.minable
    local quality = entity.quality

    entity.destroy({raise_destroy = false})

    local replacement = surface.create_entity({
        name = target_name,
        position = position,
        force = force,
        direction = direction,
        quality = quality,
        raise_built = false,
        create_build_effect_smoke = false,
    })

    if replacement and replacement.valid then
        if health then
            -- The public/exotic coil variants are data-stage deep copies of the same base
            -- turret bodies; only the beam/effect families differ. Preserve the live health
            -- value directly here instead of querying `prototype.max_health`, because Factorio
            -- 2.0 does not expose that field on the runtime entity prototype in this path.
            replacement.health = health
        end
        replacement.energy = energy
        replacement.destructible = destructible
        replacement.minable = minable
    end

    return replacement
end

local function sync_entity_variant(state, entity)
    if not entity or not entity.valid or not entity.force then
        return entity
    end

    local cache = get_force_cache(state, entity.force)
    local target_name = get_variant_target_name(entity.name, cache)
    if not target_name then
        return entity
    end

    return replace_coil_entity(entity, target_name)
end

local function sync_force_variants(state, force)
    if not force then
        return
    end

    for _, surface in pairs(game.surfaces) do
        for _, name in pairs({
            EXOTIC_VARIANT.basic.public,
            EXOTIC_VARIANT.basic.exotic,
            EXOTIC_VARIANT.advanced.public,
            EXOTIC_VARIANT.advanced.exotic,
        }) do
            for _, entity in pairs(surface.find_entities_filtered({name = name, force = force})) do
                sync_entity_variant(state, entity)
            end
        end
    end
end

local function sync_all_variants(state)
    for _, force in pairs(game.forces) do
        sync_force_variants(state, force)
    end
end

-- ---------------------------------------------------------------------------
-- Legacy-fidelity substrate helpers
-- ---------------------------------------------------------------------------
-- These helpers deliberately mirror the original TL runtime model. The fidelity path uses
-- timer cleanup plus helper persistence keyed by the exact spawn position instead of the
-- lighter burst-gate abstractions used elsewhere in the owned runtime.

local function ensure_legacy_lookup_root()
    storage.tl_entity_lookup = storage.tl_entity_lookup or {}
    return storage.tl_entity_lookup
end

local function legacy_lookup_bucket(position)
    if not position then
        return {}
    end

    local root = ensure_legacy_lookup_root()
    root[position.x] = root[position.x] or {}
    root[position.x][position.y] = root[position.x][position.y] or {}
    return root[position.x][position.y]
end

local function clear_legacy_lookup_bucket(position)
    if not storage.tl_entity_lookup or not position then
        return
    end

    local x_lookup = storage.tl_entity_lookup[position.x]
    if not x_lookup then
        return
    end

    x_lookup[position.y] = nil
    if next(x_lookup) == nil then
        storage.tl_entity_lookup[position.x] = nil
    end
end

local function add_legacy_lookup_entity(position, entity)
    if not position or not entity then
        return
    end

    local bucket = legacy_lookup_bucket(position)
    bucket[#bucket + 1] = entity
end

local function is_legacy_location_free(surface, position)
    if not surface or not position then
        return false
    end

    local offset = 1
    local entities = surface.find_entities_filtered({
        area = {
            left_top = {position.x - offset, position.y - offset},
            right_bottom = {position.x + offset, position.y + offset},
        },
    })

    for _, entity in pairs(entities) do
        if entity.valid and starts_with(entity.name, "tl-basic-tesla-coil-timer") then
            return false
        end
    end

    return true
end

local function legacy_are_enemies_in_range(surface, position, distance, force)
    if not surface or not position or not distance then
        return nil
    end

    local args = {
        position = position,
        max_distance = distance,
    }

    if force then
        args.force = force
    end

    return surface.find_nearest_enemy(args)
end

local function prune_state(state, tick)
    if tick - state.last_prune_tick < PRUNE_INTERVAL then
        return
    end

    state.last_prune_tick = tick

    for unit_number, record in pairs(state.recent_hits_by_unit) do
        local ttl = record.ttl or RECENT_HIT_TTL
        if tick - record.tick > ttl then
            state.recent_hits_by_unit[unit_number] = nil
        end
    end

    for position_key, record in pairs(state.recent_hits_by_position) do
        local ttl = record.ttl or RECENT_HIT_TTL
        if tick - record.tick > ttl then
            state.recent_hits_by_position[position_key] = nil
        end
    end

    for gate_key, last_tick in pairs(state.burst_gates) do
        if tick - last_tick > BURST_GATE_PRUNE_TTL then
            state.burst_gates[gate_key] = nil
        end
    end
end

local function draw_critical_hit_text(surface, position)
    if not tl_settings.text.critical or not surface or not position then
        return
    end

    rendering.draw_text({
        text = "Critical Hit!",
        surface = surface,
        target = position,
        color = DAMAGE_TEXT_COLOR.green,
        scale = 2,
        time_to_live = 120,
    })
end

local function draw_vaporized_text(entity)
    if not tl_settings.text.vaporize or not entity or not entity.valid then
        return
    end

    rendering.draw_text({
        text = "Vaporized!",
        surface = entity.surface,
        target = entity.position,
        color = DAMAGE_TEXT_COLOR.green,
        scale = 2,
        time_to_live = 120,
    })
end

local function draw_simple_damage_text(entity, damage, reference)
    if not tl_settings.text.damage or not entity or not entity.valid then
        return
    end

    local damage_text = math.floor(damage) .. " Damage"
    if damage > 0 then
        damage_text = "+" .. damage_text
    end

    local text_color = DAMAGE_TEXT_COLOR.gray
    local scale = 1

    if 0 < damage and damage < 0.5 * reference then
        text_color = DAMAGE_TEXT_COLOR.white
    elseif 0.5 * reference < damage and damage < reference then
        text_color = DAMAGE_TEXT_COLOR.blue
        scale = 1.5
    elseif reference < damage and damage < 2 * reference then
        text_color = DAMAGE_TEXT_COLOR.gold
        scale = 2
    elseif 2 * reference < damage then
        text_color = DAMAGE_TEXT_COLOR.purple
        scale = 3
    end

    rendering.draw_text({
        text = damage_text,
        surface = entity.surface,
        target = entity.position,
        color = text_color,
        scale = scale,
        time_to_live = 120,
    })
end

local function is_named_like(entity, value)
    return entity and entity.valid and string.find(entity.name, value, 1, true) ~= nil
end

local function is_vaporize_target(entity)
    return entity
        and entity.valid
        and not is_named_like(entity, "spawner")
        and (is_named_like(entity, "biter")
            or is_named_like(entity, "spitter")
            or is_named_like(entity, "worm"))
end

-- Recent-hit tracking exists solely for kill-gated aftershocks. We record both unit-number
-- and quantized-position lookups so the runtime can still correlate a death even when the
-- original target entity vanishes before we consume the record.
local function remember_recent_hit(state, event, hit_kind, force, ttl)
    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position or not force then
        return
    end

    local target = get_effect_target(event)
    local record = {
        tick = game.tick,
        hit_kind = hit_kind,
        force_name = force.name,
        surface_index = surface.index,
        position = copy_position(position),
        source_entity = get_origin_source(event),
        cause_entity = get_origin_cause(event),
        ttl = ttl or RECENT_HIT_TTL,
    }

    if target and target.unit_number then
        record.unit_number = target.unit_number
        state.recent_hits_by_unit[target.unit_number] = record
    end

    local position_key = make_position_key(surface.index, position)
    if position_key then
        state.recent_hits_by_position[position_key] = record
    end
end

local function clear_recent_hit(state, record, unit_number, position_key)
    if unit_number then
        state.recent_hits_by_unit[unit_number] = nil
    end

    if position_key then
        local existing = state.recent_hits_by_position[position_key]
        if existing
            and existing.tick == record.tick
            and existing.hit_kind == record.hit_kind
            and existing.force_name == record.force_name
        then
            state.recent_hits_by_position[position_key] = nil
        end
    end
end

local function take_recent_hit(state, entity, expected_hit_kind, allow_position_fallback)
    if not entity or not entity.valid then
        return nil
    end

    local tick = game.tick
    local unit_number = entity.unit_number
    local position_key = make_position_key(entity.surface.index, entity.position)
    local record = unit_number and state.recent_hits_by_unit[unit_number] or nil

    if record then
        local ttl = record.ttl or RECENT_HIT_TTL
        if tick - record.tick > ttl then
            state.recent_hits_by_unit[unit_number] = nil
        elseif not expected_hit_kind or record.hit_kind == expected_hit_kind then
            clear_recent_hit(state, record, unit_number, position_key)
            return record
        else
            return nil
        end
    end

    if not allow_position_fallback then
        return nil
    end

    if position_key then
        record = state.recent_hits_by_position[position_key]
        if record then
            local ttl = record.ttl or RECENT_HIT_TTL
            if tick - record.tick > ttl then
                state.recent_hits_by_position[position_key] = nil
            elseif not expected_hit_kind or record.hit_kind == expected_hit_kind then
                clear_recent_hit(state, record, record.unit_number, position_key)
                return record
            else
                return nil
            end
        end
    end

    return nil
end

local function can_spawn_burst(state, gate_kind, surface_index, position)
    local position_key = make_position_key(surface_index, position)
    if not position_key then
        return false
    end

    local gate_key = gate_kind .. ":" .. position_key
    local last_tick = state.burst_gates[gate_key]
    if last_tick and game.tick - last_tick <= BURST_GATE_TTL then
        return false
    end

    state.burst_gates[gate_key] = game.tick
    return true
end

-- These helpers gate bursty scripted follow-ups so multiple same-tick Tesla effects do not
-- stack helper entities at the same position and create avoidable UPS spikes.
local function maybe_spawn_fire_and_explosion(event, force, cache, salt)
    if not cache.research.flames.probability then
        return
    end

    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    local target = get_effect_target(event)
    local target_unit = target and target.unit_number or 0
    local roll = random_unit(game.tick, surface.index, target_unit, salt)

    if roll < cache.research.flames.probability then
        create_runtime_entity(surface, position, cache.names.fire, force, event)
    end

    if roll < (cache.research.flames.probability / 2) then
        create_runtime_entity(surface, position, cache.names.explosion, force, event)
    end
end

local function maybe_spawn_multi_zap(state, event, force, cache, gate_kind)
    if not cache.research.multi_zap.probability then
        return
    end

    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    if not can_spawn_burst(state, gate_kind, surface.index, position) then
        return
    end

    if not has_enemy_in_range(surface, position, cache.research.multi_zap.range, force) then
        return
    end

    local target = get_effect_target(event)
    local target_unit = target and target.unit_number or 0
    if not passes_roll(cache.research.multi_zap.probability, game.tick, surface.index, target_unit, gate_kind) then
        return
    end

    create_runtime_entity(surface, position, cache.names.multi_zap, force, event)
end

local function maybe_spawn_bridge_burst(state, event, force, cache, bridge_kind)
    if not cache.research.multi_zap.probability then
        return
    end

    local target = get_effect_target(event)
    if not target or not target.valid then
        return
    end

    local surface = target.surface
    local position = target.position
    if not surface or not position then
        return
    end

    local gate_kind = "bridge-" .. bridge_kind
    if not can_spawn_burst(state, gate_kind, surface.index, position) then
        return
    end

    -- Bridge bursts only stay on-theme when there is another enemy in the same local cluster.
    -- That keeps the helper from waking on a lone target that merely sat inside the wake bubble.
    if not bridge_has_other_enemy_in_range(surface, position, cache.ranges.bridge_burst, force, target) then
        return
    end

    local target_unit = target.unit_number or 0
    if not passes_roll(cache.research.multi_zap.probability, game.tick, surface.index, target_unit, gate_kind) then
        return
    end

    local helper_name = cache.names.bridge_family_burst
    if bridge_kind == "turret" then
        helper_name = cache.names.bridge_turret_burst
    end

    create_runtime_entity(surface, position, helper_name, force, event)
end

local function maybe_spawn_single_zap_fire(event, force, cache, salt)
    if not cache.research.flames.probability then
        return
    end

    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    local target = get_effect_target(event)
    local target_unit = target and target.unit_number or 0
    if not passes_roll(cache.research.flames.probability / 2, game.tick, surface.index, target_unit, salt) then
        return
    end

    create_runtime_entity(surface, position, cache.names.fire, force, event)
end

local function maybe_spawn_basic_chain_burst(state, event, force, cache)
    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    if not can_spawn_burst(state, "basic-doctrine-burst", surface.index, position) then
        return
    end

    local helper_name = cache.names.basic_chain_h2
    local helper_range = cache.ranges.basic_chain
    local salt = "basic-doctrine-h2"
    if cache.harmonics_level >= 3 or cache.exotic_convergence then
        helper_name = cache.names.basic_chain_h3
        helper_range = cache.ranges.basic_chain_h3
        salt = "basic-doctrine-h3"
    end

    if not has_enemy_in_range(surface, position, helper_range, force) then
        return
    end

    local target = get_effect_target(event)
    local target_unit = target and target.unit_number or 0
    if not passes_roll(cache.research.multi_zap.probability, game.tick, surface.index, target_unit, salt) then
        return
    end

    create_runtime_entity(surface, position, helper_name, force, event)
end

-- Exotic convergence gives the basic coil one guaranteed side-branch burst on successful
-- primary hits. This uses its own lighter helper family so the capstone feels distinct
-- from H3 without turning the basic coil into an advanced-style execution tower.
local function maybe_spawn_basic_exotic_branch(state, event, force, cache)
    if not cache or not cache.exotic_convergence then
        return
    end

    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    if not can_spawn_burst(state, "basic-exotic-branch", surface.index, position) then
        return
    end

    if not has_enemy_in_range(surface, position, cache.ranges.basic_chain_exotic, force) then
        return
    end

    create_runtime_entity(surface, position, cache.names.basic_chain_exotic, force, event)
end

local function maybe_spawn_tank_chain_burst(state, event, force, cache)
    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if not surface or not position then
        return
    end

    if not can_spawn_burst(state, "tank-doctrine-burst", surface.index, position) then
        return
    end

    local helper_name = cache.names.tank_chain_h2
    local helper_range = cache.ranges.tank_chain
    local salt = "tank-doctrine-h2"
    if cache.harmonics_level >= 3 or cache.exotic_convergence then
        helper_name = cache.names.tank_chain_h3
        helper_range = cache.ranges.tank_chain_h3
        salt = "tank-doctrine-h3"
    end

    if not has_enemy_in_range(surface, position, helper_range, force) then
        return
    end

    local target = get_effect_target(event)
    local target_unit = target and target.unit_number or 0
    if not passes_roll(cache.research.multi_zap.probability, game.tick, surface.index, target_unit, salt) then
        return
    end

    create_runtime_entity(surface, position, helper_name, force, event)
end

-- Kill-confirmed exotic execution storms are the advanced coil's unique capstone payoff.
-- They always layer on top of the restored TL single-zap/aftershock flow instead of
-- replacing it, so fidelity keeps the original cadence and hybrid still gets a distinct
-- final overcharge family.
local function maybe_spawn_advanced_exotic_execution_storm(state, surface, position, force, cache, subject)
    if not cache or not cache.exotic_convergence or not surface or not position then
        return
    end

    if not can_spawn_burst(state, "advanced-exotic-execution", surface.index, position) then
        return
    end

    if not has_enemy_in_range(surface, position, cache.ranges.advanced_chain_exotic, force) then
        return
    end

    create_runtime_entity(surface, position, cache.names.advanced_chain_exotic, force, subject)
    if cache.names.advanced_exotic_impact then
        create_visual(surface, position, cache.names.advanced_exotic_impact, subject)
    end
end

-- The tank only gets a partial exotic capstone, tied directly to its volatility model.
-- Positive overcharge spikes and vaporization events can kick off this extra stormfront
-- discharge, but ordinary tank hits still lean on the existing TL/reactance behavior.
local function maybe_spawn_tank_exotic_stormfront(state, surface, position, force, cache, subject)
    if not cache or not cache.exotic_convergence or not surface or not position then
        return
    end

    if not can_spawn_burst(state, "tank-exotic-stormfront", surface.index, position) then
        return
    end

    if not has_enemy_in_range(surface, position, cache.ranges.tank_chain_exotic, force) then
        return
    end

    create_runtime_entity(surface, position, cache.names.tank_chain_exotic, force, subject)
end

-- Harmonics/doctrine techs can modernize the TL coil follow-up model, but only when the
-- player has actually chosen the lighter hybrid mode. Legacy-fidelity is meant to preserve
-- the original high-density helper recursion even at the end of the tech tree, so the
-- modern chain-helper families should not silently replace that damage model there.
local function should_use_modern_tl_chain(cache)
    return BEHAVIOR_MODE ~= "legacy-fidelity"
        and cache
        and (cache.harmonics_level >= 2 or cache.exotic_convergence)
end

local function apply_damage_modulation(event, target, force, cache, salt)
    if not target or not target.valid or not target.health then
        return 0
    end

    local modulation = cache.research.volatility.modulation
    local base_damage = cache.damage.tank_reference
    if not modulation or base_damage <= 0 then
        return 0
    end

    local roll = random_unit(game.tick, target.unit_number or 0, target.health, salt)
    local overdrive_scale = 1 + (0.15 * cache.levels.reactance_overdrive)
    local min_multiplier = math.max(0.1, 1 - ((1 - modulation.minimal) * overdrive_scale))
    local max_multiplier = 1 + ((modulation.maximal - 1) * overdrive_scale)
    local final_multiplier = min_multiplier + (max_multiplier - min_multiplier) * roll
    local extra_damage = base_damage * final_multiplier - base_damage
    if extra_damage == 0 then
        return 0
    end

    draw_simple_damage_text(target, extra_damage, base_damage)

    if extra_damage > 0 then
        target.damage(extra_damage, force, "electric", get_origin_source(event), get_origin_cause(event))
    else
        target.health = target.health - extra_damage
    end

    return extra_damage
end

-- Vaporization stays scripted because it is one of the signature TL behaviors that cannot be
-- cleanly expressed as a static prototype bonus without losing its thresholded "erase target"
-- identity.
local function apply_vaporization(event, target, force, cache, salt)
    if not target or not target.valid or not target.health or target.health <= 0 then
        return false
    end

    if not cache.research.volatility.probability or not is_vaporize_target(target) then
        return false
    end

    if not passes_roll(cache.research.volatility.probability, game.tick, target.unit_number or 0, salt) then
        return false
    end

    if target.health <= VAPORIZE_DAMAGE_THRESHOLD then
        local surface = target.surface
        local position = target.position
        draw_vaporized_text(target)
        create_visual(surface, position, "small-scorchmark", event)
        create_visual(surface, position, "blood-explosion-small", event)
        create_visual(surface, position, "blood-explosion-big", event)
        create_visual(surface, position, "blood-explosion-huge", event)
        create_visual(surface, position, "explosion", event)
        target.destroy()
        return true
    end

    target.damage(
        VAPORIZE_DAMAGE_THRESHOLD,
        force,
        "electric",
        get_origin_source(event),
        get_origin_cause(event)
    )
    return true
end

local function apply_bridge_chain_damage(event, force, cache, base_damage, salt)
    local target = get_effect_target(event)
    if not target or not target.valid then
        return
    end

    local multiplier = cache.research.multi_zap.damage
    if salt == EFFECT_ID.bridge_turret_chain_h3 then
        multiplier = cache.research.single_zap.damage
    elseif salt == EFFECT_ID.bridge_turret_chain_exotic then
        multiplier = cache.research.single_zap.damage * 1.20
    end

    local amount = base_damage * multiplier
    if amount <= 0 then
        return
    end

    target.damage(amount, force, "electric", get_origin_source(event), get_origin_cause(event))

    if salt == EFFECT_ID.bridge_turret_chain_h3 then
        maybe_spawn_fire_and_explosion(event, force, cache, 709)
    elseif salt == EFFECT_ID.bridge_turret_chain_exotic then
        maybe_spawn_fire_and_explosion(event, force, cache, 719)
    end
end

local function apply_tank_chain_damage(event, force, cache, flavor)
    local target = get_effect_target(event)
    if not target or not target.valid then
        return
    end

    local multiplier = cache.research.multi_zap.damage * (1 + (0.15 * cache.levels.reactance_overdrive))
    if flavor == "tank-h3" then
        multiplier = multiplier * 1.15
    elseif flavor == "tank-exotic" then
        multiplier = multiplier * 0.90
    end

    local amount = cache.damage.tank_reference * multiplier
    if amount <= 0 then
        return
    end

    target.damage(amount, force, "electric", get_origin_source(event), get_origin_cause(event))

    if cache.exotic_convergence then
        create_visual(target.surface, target.position, cache.names.tank_exotic_impact, event)
    end

    if flavor == "tank-h3" or cache.levels.reactance_overdrive >= 2 then
        maybe_spawn_fire_and_explosion(event, force, cache, 743)
    end
end

local function apply_tl_chain_damage(event, force, cache, flavor)
    local target = get_effect_target(event)
    if not target or not target.valid then
        return
    end

    local amount = 0
    if flavor == "basic-h2" or flavor == "basic-h3" then
        amount = cache.damage.basic_reference * cache.research.multi_zap.damage
    elseif flavor == "basic-exotic" then
        amount = cache.damage.basic_reference * cache.research.multi_zap.damage * 0.72
    elseif flavor == "advanced-h2" or flavor == "advanced-h3" then
        amount = cache.damage.advanced_reference
            * cache.research.single_zap.damage
            * (1 + (0.15 * cache.levels.dielectric_rupture))
    elseif flavor == "advanced-exotic" then
        amount = cache.damage.advanced_reference
            * cache.research.single_zap.damage
            * (1 + (0.15 * cache.levels.dielectric_rupture))
            * 1.20
    end

    if amount <= 0 then
        return
    end

    target.damage(amount, force, "electric", get_origin_source(event), get_origin_cause(event))

    if flavor == "advanced-h3"
        or flavor == "advanced-exotic"
        or (flavor == "advanced-h2" and cache.levels.dielectric_rupture >= 2)
    then
        maybe_spawn_fire_and_explosion(event, force, cache, 727)
    end
end

local function get_force_from_record(record)
    if not record or not record.force_name then
        return nil
    end

    return game.forces[record.force_name]
end

local function handle_legacy_aftershock(state, dead_entity, record)
    local force = get_force_from_record(record)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache or not cache.research.single_zap.probability then
        return
    end

    local surface = dead_entity.surface
    local position = dead_entity.position
    maybe_spawn_advanced_exotic_execution_storm(state, surface, position, force, cache, record)
    if not can_spawn_burst(state, "legacy-aftershock", surface.index, position) then
        return
    end

    if not passes_roll(cache.research.single_zap.probability, game.tick, dead_entity.unit_number or 0, "legacy-aftershock") then
        return
    end

    local use_doctrine_chain = should_use_modern_tl_chain(cache)
    local helper_name = cache.names.single_zap
    local helper_range = cache.ranges.single_zap
    if use_doctrine_chain then
        helper_name = cache.names.advanced_chain_h2
        helper_range = cache.ranges.advanced_chain
        if cache.harmonics_level >= 3 or cache.exotic_convergence then
            helper_name = cache.names.advanced_chain_h3
            helper_range = cache.ranges.advanced_chain_h3
        end
    end

    if not has_enemy_in_range(surface, position, helper_range, force) then
        return
    end

    if use_doctrine_chain then
        create_runtime_entity(surface, position, helper_name, force, record)
        return
    end

    for _ = 1, cache.research.single_zap.count do
        create_runtime_entity(surface, position, helper_name, force, record)
    end
end

local function handle_bridge_turret_aftershock(state, dead_entity, record)
    local force = get_force_from_record(record)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache or cache.harmonics_level < 2 or not cache.research.single_zap.probability then
        return
    end

    local surface = dead_entity.surface
    local position = dead_entity.position
    if cache.exotic_convergence
        and can_spawn_burst(state, "bridge-aftershock-exotic", surface.index, position)
        -- The aftershock follows the same rule: if the local cluster has already collapsed,
        -- do not wake a follow-up helper from a corpse alone.
        and bridge_has_other_enemy_in_range(surface, position, cache.ranges.bridge_aftershock_exotic, force, dead_entity)
    then
        create_runtime_entity(surface, position, cache.names.bridge_aftershock_exotic, force, record)
    end

    if not can_spawn_burst(state, "bridge-aftershock", surface.index, position) then
        return
    end

    if not passes_roll(cache.research.single_zap.probability, game.tick, dead_entity.unit_number or 0, "bridge-aftershock") then
        return
    end

    local helper_name = cache.names.bridge_aftershock
    local helper_range = cache.ranges.bridge_aftershock
    if cache.harmonics_level >= 3 or cache.levels.bridge_coupling >= 2 then
        helper_name = cache.names.bridge_aftershock_h3
        helper_range = cache.ranges.bridge_aftershock_h3
    end

    if not bridge_has_other_enemy_in_range(surface, position, helper_range, force, dead_entity) then
        return
    end

    create_runtime_entity(surface, position, helper_name, force, record)
end

local function handle_critical_text(event)
    local target = get_effect_target(event)
    if target then
        draw_critical_hit_text(target.surface, target.position)
        return
    end

    local surface = get_effect_surface(event)
    local position = get_effect_position(event)
    if surface and position then
        draw_critical_hit_text(surface, position)
    end
end

local function handle_legacy_timer(event)
    if not storage.tl_entity_lookup or not event.source_position then
        return
    end

    local x_lookup = storage.tl_entity_lookup[event.source_position.x]
    if not x_lookup then
        return
    end

    local entities = x_lookup[event.source_position.y]
    if not entities then
        return
    end

    for _, entity in pairs(entities) do
        if entity and entity.valid then
            entity.die()
        end
    end

    x_lookup[event.source_position.y] = nil
    if next(x_lookup) == nil then
        storage.tl_entity_lookup[event.source_position.x] = nil
    end
end

local function legacy_apply_damage_modulation(event, force, cache)
    if not event or not event.entity or not event.entity.valid then
        return 0
    end

    local final_health = event.final_health
    if final_health ~= nil and final_health <= 0 then
        return 0
    end

    local modulation = cache and cache.research and cache.research.volatility and cache.research.volatility.modulation or nil
    if not modulation then
        return 0
    end

    local reference = event.original_damage_amount or 0
    if reference <= 0 then
        return 0
    end

    local roll = legacy_random_number(event.tick)
    local final_multiplier = modulation.minimal + ((modulation.maximal - modulation.minimal) * roll)
    local extra_damage = reference * final_multiplier - reference
    draw_simple_damage_text(event.entity, extra_damage, reference)

    if extra_damage > 0 then
        event.entity.damage(extra_damage, force, "electric")
    elseif event.entity.health then
        event.entity.health = event.entity.health - extra_damage
    end

    return extra_damage
end

local function legacy_apply_vaporization(event, force, cache)
    if not event or not event.entity or not event.entity.valid then
        return false
    end

    local final_health = event.final_health
    if final_health ~= nil and final_health <= 0 then
        return false
    end

    local probability = cache and cache.research and cache.research.volatility and cache.research.volatility.probability or nil
    if not probability then
        return false
    end

    local roll = legacy_random_number(event.tick)
    if roll >= probability or not is_vaporize_target(event.entity) then
        return false
    end

    local damage_threshold = VAPORIZE_DAMAGE_THRESHOLD
    if event.entity.health and event.entity.health <= damage_threshold then
        local surface = event.entity.surface
        local position = event.entity.position
        draw_vaporized_text(event.entity)
        create_plain_entity(surface, position, "small-scorchmark")
        create_plain_entity(surface, position, "blood-explosion-small")
        create_plain_entity(surface, position, "blood-explosion-big")
        create_plain_entity(surface, position, "blood-explosion-huge")
        create_plain_entity(surface, position, "explosion")
        return event.entity.destroy()
    end

    event.entity.damage(damage_threshold, force, "electric")
    return true
end

local function maybe_spawn_fidelity_basic_overlay(state, event, force, cache)
    if not cache or (cache.harmonics_level < 2 and cache.levels.storm_lattice <= 0 and not cache.exotic_convergence) then
        return
    end

    maybe_spawn_basic_chain_burst(state, event, force, cache)
    maybe_spawn_basic_exotic_branch(state, event, force, cache)
end

local function maybe_spawn_fidelity_advanced_overlay(state, surface, position, force, cache, subject)
    if not cache or (cache.harmonics_level < 2 and cache.levels.dielectric_rupture <= 0 and not cache.exotic_convergence) then
        return
    end

    local helper_name = cache.names.advanced_chain_h2
    local helper_range = cache.ranges.advanced_chain
    if cache.harmonics_level >= 3 or cache.exotic_convergence then
        helper_name = cache.names.advanced_chain_h3
        helper_range = cache.ranges.advanced_chain_h3
    end

    if has_enemy_in_range(surface, position, helper_range, force) then
        create_runtime_entity(surface, position, helper_name, force, subject)
    end
end

local function maybe_spawn_fidelity_tank_overlay(state, event, force, cache)
    if not cache or (cache.harmonics_level < 2 and cache.levels.reactance_overdrive <= 0 and not cache.exotic_convergence) then
        return
    end

    maybe_spawn_tank_chain_burst(state, event, force, cache)
end

local function run_exact_legacy_basic_hit(state, event, force, cache)
    local target = event.entity
    if not target or not target.valid then
        return
    end

    local surface = target.surface
    local position = target.position
    local research = cache.research
    if not research.multi_zap.probability then
        return
    end

    if is_legacy_location_free(surface, position)
        and legacy_are_enemies_in_range(surface, position, research.multi_zap.range, force)
    then
        if legacy_random_number(event.tick) < research.multi_zap.probability then
            create_plain_entity(surface, position, "tl-basic-tesla-coil-timer", force)
            local helper = create_plain_entity(surface, position, cache.names.multi_zap, force)
            if helper then
                add_legacy_lookup_entity(position, helper)
            end
        end
    end

    if event.cause
        and starts_with(event.cause.name, "tl-basic-tesla-coil")
        and not starts_with(event.cause.name, "tl-basic-tesla-coil-multi-zap")
        and not starts_with(event.cause.name, "tl-basic-tesla-coil-single-zap")
    then
        maybe_spawn_fidelity_basic_overlay(state, {
            target_entity = target,
            source_entity = event.cause,
            cause_entity = event.cause,
            surface_index = surface.index,
            target_position = position,
            source_position = event.cause.position,
        }, force, cache)
    end
end

local function run_exact_legacy_advanced_hit(state, event, force, cache)
    local target = event.entity
    if not target or not target.valid then
        return
    end

    local position = target.position
    local surface = target.surface
    local research = cache.research
    if research.flames.probability then
        local roll = legacy_random_number(event.tick)
        if roll < research.flames.probability then
            create_plain_entity(surface, position, cache.names.fire, force)
        end
        if roll < (research.flames.probability / 2) then
            create_plain_entity(surface, position, cache.names.explosion, force)
        end
    end
end

local function run_exact_legacy_single_zap_hit(event, force, cache)
    local target = event.entity
    if not target or not target.valid then
        return
    end

    local research = cache.research
    if not research.flames.probability then
        return
    end

    if legacy_random_number(event.tick) < (research.flames.probability / 2) then
        create_plain_entity(target.surface, target.position, cache.names.fire, force)
    end
end

local function run_exact_legacy_tank_hit(state, event, force, cache)
    local surface = event.entity and event.entity.valid and event.entity.surface or nil
    local position = event.entity and event.entity.valid and copy_position(event.entity.position) or nil
    run_exact_legacy_basic_hit(state, event, force, cache)

    local vaporized = legacy_apply_vaporization(event, force, cache)
    local extra_damage = 0
    if not vaporized then
        extra_damage = legacy_apply_damage_modulation(event, force, cache) or 0
    end

    if cache.exotic_convergence and surface and position then
        create_visual(surface, position, cache.names.tank_exotic_impact, {
            source_entity = event.cause,
            cause_entity = event.cause,
        })
    end

    if vaporized or extra_damage > 0 then
        maybe_spawn_tank_exotic_stormfront(state, surface, position, force, cache, {
            source_entity = event.cause,
            cause_entity = event.cause,
            target_position = position,
            surface_index = surface and surface.index or nil,
        })
    end

    maybe_spawn_fidelity_tank_overlay(state, {
        target_entity = event.entity and event.entity.valid and event.entity or nil,
        source_entity = event.cause,
        cause_entity = event.cause,
        surface_index = surface and surface.index or nil,
        target_position = position,
        source_position = event.cause and event.cause.position or position,
    }, force, cache)
end

local function run_exact_legacy_advanced_kill(state, event, force, cache)
    local target = event.entity
    if not target or not target.valid then
        return
    end

    local research = cache.research
    if not research.single_zap.probability then
        return
    end

    local surface = target.surface
    local position = target.position
    local spawned_original_aftershock = false
    if legacy_random_number(event.tick) <= research.single_zap.probability then
        if legacy_are_enemies_in_range(surface, position, cache.ranges.single_zap, force) then
            create_plain_entity(surface, position, "tl-basic-tesla-coil-timer", force)
            for _ = 1, research.single_zap.count do
                local helper = create_plain_entity(surface, position, cache.names.single_zap, force)
                if helper then
                    add_legacy_lookup_entity(position, helper)
                end
            end
            spawned_original_aftershock = true
        end
    end

    if spawned_original_aftershock then
        maybe_spawn_fidelity_advanced_overlay(state, surface, position, force, cache, {
            cause_entity = event.cause,
        })
    end

    maybe_spawn_advanced_exotic_execution_storm(state, surface, position, force, cache, {
        cause_entity = event.cause,
    })
end

local function handle_tl_basic_hit(state, event)
    if BEHAVIOR_MODE == "legacy-fidelity" then
        return
    end

    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    if should_use_modern_tl_chain(cache) then
        maybe_spawn_basic_chain_burst(state, event, force, cache)
        maybe_spawn_basic_exotic_branch(state, event, force, cache)
        return
    end

    maybe_spawn_multi_zap(state, event, force, cache, "legacy-basic-burst")
    maybe_spawn_basic_exotic_branch(state, event, force, cache)
end

local function handle_tl_advanced_hit(state, event)
    if BEHAVIOR_MODE == "legacy-fidelity" then
        return
    end

    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    remember_recent_hit(state, event, "legacy-advanced", force)
    maybe_spawn_fire_and_explosion(event, force, cache, 211)
end

local function handle_tl_tank_hit(state, event)
    if BEHAVIOR_MODE == "legacy-fidelity" then
        return
    end

    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    if should_use_modern_tl_chain(cache) then
        maybe_spawn_tank_chain_burst(state, event, force, cache)
    else
        maybe_spawn_multi_zap(state, event, force, cache, "legacy-tank-burst")
    end

    local target = get_effect_target(event)
    if not target then
        return
    end

    local surface = target.surface
    local position = copy_position(target.position)

    if cache.exotic_convergence then
        create_visual(surface, position, cache.names.tank_exotic_impact, event)
    end

    local vaporized = apply_vaporization(event, target, force, cache, 307)
    local extra_damage = 0
    if not vaporized then
        extra_damage = apply_damage_modulation(event, target, force, cache, 311) or 0
    end

    if vaporized or extra_damage > 0 then
        maybe_spawn_tank_exotic_stormfront(state, surface, position, force, cache, event)
    end
end

local function handle_bridge_family_hit(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    if cache.harmonics_level >= 1 or cache.levels.bridge_coupling >= 1 then
        maybe_spawn_fire_and_explosion(event, force, cache, 389)
    end

    if cache.harmonics_level >= 2 or cache.levels.bridge_coupling >= 1 then
        maybe_spawn_bridge_burst(state, event, force, cache, "family")
    end
end

local function handle_bridge_turret_hit(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    if cache.harmonics_level >= 1 or cache.levels.bridge_coupling >= 1 then
        -- Keep the bridge kill-confirm memory window at 5 ticks, but only for an exact
        -- bridge-turret match with electric deaths. That preserves the feel without reopening
        -- the older loose position-fallback path.
        remember_recent_hit(state, event, "bridge-turret", force, 5)
        maybe_spawn_fire_and_explosion(event, force, cache, 401)
    end

    if cache.harmonics_level >= 2 or cache.levels.bridge_coupling >= 1 then
        maybe_spawn_bridge_burst(state, event, force, cache, "turret")
    end
end

local function handle_bridge_family_chain(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_bridge_chain_damage(event, force, cache, cache.damage.bridge_family, EFFECT_ID.bridge_family_chain)
end

local function handle_bridge_turret_chain(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_bridge_chain_damage(event, force, cache, cache.damage.bridge_turret, EFFECT_ID.bridge_turret_chain)
end

local function handle_bridge_turret_chain_h3(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_bridge_chain_damage(event, force, cache, cache.damage.bridge_turret, EFFECT_ID.bridge_turret_chain_h3)
end

local function handle_bridge_turret_chain_exotic(state, event)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_bridge_chain_damage(event, force, cache, cache.damage.bridge_turret, EFFECT_ID.bridge_turret_chain_exotic)
end

local function handle_tl_basic_chain(state, event, flavor)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_tl_chain_damage(event, force, cache, flavor)
end

local function handle_tl_advanced_chain(state, event, flavor)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_tl_chain_damage(event, force, cache, flavor)
end

local function handle_tl_tank_chain(state, event, flavor)
    local force = get_effect_force(event)
    if not force then
        return
    end

    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    apply_tank_chain_damage(event, force, cache, flavor)
end

-- Exact effect-id dispatch table. `on_script_trigger_effect` should stay as close to a table
-- lookup as possible, with the real behavior branching inside the focused handlers below.
local SCRIPT_EFFECT_HANDLERS = {
    [EFFECT_ID.critical] = function(_, event)
        handle_critical_text(event)
    end,
    [EFFECT_ID.critical_ei] = function(_, event)
        handle_critical_text(event)
    end,
    [EFFECT_ID.legacy_timer] = function(_, event)
        handle_legacy_timer(event)
    end,
    [EFFECT_ID.tl_basic_hit] = handle_tl_basic_hit,
    [EFFECT_ID.tl_advanced_hit] = handle_tl_advanced_hit,
    [EFFECT_ID.tl_tank_hit] = handle_tl_tank_hit,
    [EFFECT_ID.tl_basic_chain] = function(state, event)
        handle_tl_basic_chain(state, event, "basic-h2")
    end,
    [EFFECT_ID.tl_basic_chain_h3] = function(state, event)
        handle_tl_basic_chain(state, event, "basic-h3")
    end,
    [EFFECT_ID.tl_basic_chain_exotic] = function(state, event)
        handle_tl_basic_chain(state, event, "basic-exotic")
    end,
    [EFFECT_ID.tl_advanced_chain] = function(state, event)
        handle_tl_advanced_chain(state, event, "advanced-h2")
    end,
    [EFFECT_ID.tl_advanced_chain_h3] = function(state, event)
        handle_tl_advanced_chain(state, event, "advanced-h3")
    end,
    [EFFECT_ID.tl_advanced_chain_exotic] = function(state, event)
        handle_tl_advanced_chain(state, event, "advanced-exotic")
    end,
    [EFFECT_ID.tl_tank_chain] = function(state, event)
        handle_tl_tank_chain(state, event, "tank-h2")
    end,
    [EFFECT_ID.tl_tank_chain_h3] = function(state, event)
        handle_tl_tank_chain(state, event, "tank-h3")
    end,
    [EFFECT_ID.tl_tank_chain_exotic] = function(state, event)
        handle_tl_tank_chain(state, event, "tank-exotic")
    end,
    [EFFECT_ID.bridge_family_hit] = handle_bridge_family_hit,
    [EFFECT_ID.bridge_turret_hit] = handle_bridge_turret_hit,
    [EFFECT_ID.bridge_family_chain] = handle_bridge_family_chain,
    [EFFECT_ID.bridge_turret_chain] = handle_bridge_turret_chain,
    [EFFECT_ID.bridge_turret_chain_h3] = handle_bridge_turret_chain_h3,
    [EFFECT_ID.bridge_turret_chain_exotic] = handle_bridge_turret_chain_exotic,
}

local function cleanup_legacy_helpers()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered({name = "tl-basic-tesla-coil-timer"})) do
            if entity.valid then
                entity.destroy()
            end
        end
    end

    storage.tl_entity_lookup = nil
    storage.tl_index = nil
end

-- Event entrypoints: these are intentionally tiny adapters because base `control.lua`
-- registers every hook and forwards here, matching EI's normal module shape.
function model.on_init()
    local state = ensure_state()
    ensure_legacy_lookup_root()
    sync_all_force_caches(state)
    sync_all_variants(state)
    prune_state(state, game.tick)
end

function model.on_load()
end

function model.on_configuration_changed()
    local state = ensure_state()
    state.recent_hits_by_unit = {}
    state.recent_hits_by_position = {}
    state.burst_gates = {}
    cleanup_legacy_helpers()
    ensure_legacy_lookup_root()
    sync_all_force_caches(state)
    sync_all_variants(state)
    prune_state(state, game.tick)
end

function model.on_research_finished(event)
    if not event or not event.research or not event.research.force then
        return
    end

    local state = ensure_state()
    sync_force_cache(state, event.research.force)
    if starts_with(event.research.name, "ei-waveform-harmonics-")
        or starts_with(event.research.name, "ei-storm-lattice-")
        or starts_with(event.research.name, "ei-dielectric-rupture-")
        or starts_with(event.research.name, "ei-bridge-coupling-")
        or starts_with(event.research.name, "ei-reactance-overdrive-")
        or event.research.name == "ei-exotic-waveform-convergence"
    then
        sync_force_variants(state, event.research.force)
    end
end

function model.on_script_trigger_effect(event)
    if not event or not event.effect_id then
        return
    end

    local handler = SCRIPT_EFFECT_HANDLERS[event.effect_id]
    if not handler then
        return
    end

    local state = ensure_state()
    prune_state(state, game.tick)
    handler(state, event)
end

function model.on_entity_died(event)
    if not event or not event.entity or not event.entity.valid then
        return
    end

    local state = ensure_state()
    prune_state(state, game.tick)

    if BEHAVIOR_MODE == "legacy-fidelity"
        and event.cause
        and event.cause.valid
        and event.damage_type
        and event.damage_type.name == "electric"
        and starts_with(event.cause.name, "tl-advanced-tesla-coil")
    then
        local force = event.cause.force
        local cache = get_force_cache(state, force)
        if cache then
            run_exact_legacy_advanced_kill(state, event, force, cache)
        end
    end

    -- Replica Fulgoran aftershocks should stay visually anchored to real turret kills.
    -- Only consume the bridge record when the entity actually died to electric damage,
    -- and require an exact unit-number match instead of the looser position fallback.
    if event.damage_type and event.damage_type.name == "electric" then
        local bridge_record = take_recent_hit(state, event.entity, "bridge-turret", false)
        if bridge_record then
            handle_bridge_turret_aftershock(state, event.entity, bridge_record)
            return
        end
    end

    local legacy_record = take_recent_hit(state, event.entity, "legacy-advanced", true)
    if legacy_record then
        handle_legacy_aftershock(state, event.entity, legacy_record)
    end
end

function model.on_entity_damaged(event)
    -- Hybrid intentionally keeps the old global damage hook dormant for TL-owned weapons.
    -- Legacy-fidelity re-enables it and routes the exact 1.0-era helper recursion first,
    -- then layers the owned doctrine overlays on top.
    if not event or not event.entity or not event.entity.valid or not event.cause or not event.cause.valid then
        return
    end

    if not event.damage_type or event.damage_type.name ~= "electric" then
        return
    end

    local state = ensure_state()
    prune_state(state, game.tick)

    local force = event.cause.force
    local cache = get_force_cache(state, force)
    if not cache then
        return
    end

    if BEHAVIOR_MODE == "legacy-fidelity" then
        if starts_with(event.cause.name, "tl-basic-tesla-coil-single-zap") then
            run_exact_legacy_single_zap_hit(event, force, cache)
            return
        elseif starts_with(event.cause.name, "tl-advanced-tesla-coil") then
            run_exact_legacy_advanced_hit(state, event, force, cache)
            return
        elseif starts_with(event.cause.name, "tl-basic-tesla-coil-multi-zap")
            or starts_with(event.cause.name, "tl-basic-tesla-coil")
        then
            run_exact_legacy_basic_hit(state, event, force, cache)
            return
        elseif starts_with(event.cause.name, "tl-tesla-tank") then
            run_exact_legacy_tank_hit(state, event, force, cache)
            return
        end

        return
    end
end

function model.on_built_entity(event)
    if not event or not event.entity or not event.entity.valid then
        return
    end

    local state = ensure_state()
    sync_entity_variant(state, event.entity)
end

return model
