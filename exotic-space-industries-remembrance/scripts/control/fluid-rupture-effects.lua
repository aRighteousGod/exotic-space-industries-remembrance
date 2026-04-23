--==============================================================================
-- ESIR FILE MAP
-- owns: shared contextual fluid rupture and vent effect construction
-- loaded_by: exotic-space-industries-remembrance\scripts\control\flammable-fluids.lua, scripts\control\fluid-safety.lua
-- cadence: on-demand job creation only
-- forwarded_events: queue_effect, queue_vent
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime prototype changes
--==============================================================================

local ei_lib = require("lib/lib")
local rupture_scheduler = require("scripts/control/flammable-rupture-scheduler")

local model = {}

local ENERGY_THRESHOLD_MJ = 10
local RADIUS_MULT = 0.5
local RADIUS_POWER = 1 / 3
local DAMAGE_MULT = 6.5
local DAMAGE_POWER = 1 / 3
local DAMAGE_FALLOFF_POWER = 1.35
local DAMAGE_SEARCH_PADDING = 1.25
local SCORCH_THRESHOLD_MJ = 45
local DIRECT_PIPELINE_FIRE_TYPES = {
    pipe = true,
    ["pipe-to-ground"] = true,
}
local DIRECT_PIPELINE_FIRE_CAPS = {
    lean = 12,
    standard = 28,
    cinematic = 48,
}
local DIRECT_PIPELINE_FIRE_RADIUS_MULT = 0.40
local DIRECT_PIPELINE_FIRE_RADIUS_MIN = 2.50
local DIRECT_PIPELINE_FIRE_RADIUS_MAX = 18
local PIPELINE_TRAVERSAL_VISIT_MULT = 4
local PIPELINE_TRAVERSAL_MIN_VISITS = 64
local PIPELINE_TRAVERSAL_UNBOUNDED_VISITS = 512
local PLATFORM_VISUAL_RADIUS_MULT = 0.72
local PLATFORM_EXPLOSION_COUNT_MULT = 0.82
local PLATFORM_SMOKE_COUNT_MULT = 0.55
local PLATFORM_SECONDARY_SMOKE_MULT = 0.45
local PLATFORM_SECONDARY_EFFECT_MULT = 0.60
local PLATFORM_EFFECT_RADIUS_MULT = 0.76
local PLATFORM_MASSIVE_CAP = 1
local PLATFORM_SOURCE_TILE_DAMAGE_DIVISOR = 600
local PLATFORM_SOURCE_TILE_DAMAGE_MIN = 1.00
local PLATFORM_SOURCE_TILE_DAMAGE_MAX = 4.00
local PLATFORM_PIPE_TILE_DAMAGE_MULT = 0.55
local PLATFORM_PIPE_TILE_DAMAGE_MIN = 0.50
local PLATFORM_PIPE_TILE_DAMAGE_MAX = 2.00
local LAVA_GROUND_PATCH_SPRITE = "ei-lava-ground-patch"
local LAVA_GROUND_PATCH_TTL = 180
local LAVA_GROUND_PATCH_SCALE = 0.98
local LAVA_GROUND_PATCH_TINT = {r = 1.0, g = 0.88, b = 0.74, a = 0.88}
local PLATFORM_TILE_DAMAGE_FAMILY_MULT = {
    oil = 1.00,
    gas = 1.18,
    exotic = 1.08,
    thermal = 1.08,
    chemical = 0.55,
    cryo = 0.45,
    data = 0.35,
}

local EFFECT_STYLES = {
    oil = {
        family = "oil",
        damage_type = "fire",
        fire_name = "ei-oil-fire-flame",
        platform_fire_name = "ei-oil-platform-fire-flame",
        smoke_name = "ei-oil-rupture-smoke",
        pair_explosion_name = "explosion",
        explosion_bias = 0.85,
        fire_bias = 1.35,
        smoke_bias = 1.50,
        scorch_bias = 1.30,
        ring_bias = 0.95,
        shockwave_bias = 1.00,
        massive_bias = 0.28,
        secondary_bias = 0.85,
        allow_fire = true,
        allow_scorch = true,
        allow_secondary = true,
        default_pipeline_fire = true,
        default_platform_tile_damage = true,
    },
    gas = {
        family = "gas",
        damage_type = "explosion",
        fire_name = "ei-gas-fire-flame",
        platform_fire_name = "ei-gas-platform-fire-flame",
        smoke_name = "ei-gas-rupture-smoke",
        pair_explosion_name = "medium-explosion",
        explosion_bias = 1.45,
        fire_bias = 0.40,
        smoke_bias = 0.90,
        scorch_bias = 0.55,
        ring_bias = 1.45,
        shockwave_bias = 1.35,
        massive_bias = 0.80,
        secondary_bias = 1.15,
        allow_fire = true,
        allow_scorch = true,
        allow_secondary = true,
        default_pipeline_fire = true,
        default_platform_tile_damage = true,
    },
    exotic = {
        family = "exotic",
        damage_type = "fire",
        fire_name = "ei-exotic-fire-flame",
        platform_fire_name = "ei-exotic-platform-fire-flame",
        smoke_name = "ei-exotic-rupture-smoke",
        pair_explosion_name = "medium-explosion",
        explosion_bias = 1.10,
        fire_bias = 0.75,
        smoke_bias = 1.25,
        scorch_bias = 0.95,
        ring_bias = 1.20,
        shockwave_bias = 1.15,
        massive_bias = 0.52,
        secondary_bias = 1.00,
        allow_fire = true,
        allow_scorch = true,
        allow_secondary = true,
        default_pipeline_fire = true,
        default_platform_tile_damage = true,
    },
    data = {
        family = "data",
        damage_type = "electric",
        smoke_name = "ei-data-rupture-smoke",
        pair_explosion_name = "spark-explosion-higher",
        explosion_bias = 0.68,
        fire_bias = 0,
        smoke_bias = 0.72,
        scorch_bias = 0,
        ring_bias = 0.90,
        shockwave_bias = 0.92,
        massive_bias = 0,
        secondary_bias = 0,
        allow_fire = false,
        allow_scorch = false,
        allow_secondary = false,
        default_pipeline_fire = false,
        default_platform_tile_damage = false,
    },
    cryo = {
        family = "cryo",
        damage_type = "cold",
        smoke_name = "ei-cryo-rupture-smoke",
        pair_explosion_name = "water-splash",
        explosion_bias = 0.60,
        fire_bias = 0,
        smoke_bias = 1.15,
        scorch_bias = 0,
        ring_bias = 0.78,
        shockwave_bias = 0.82,
        massive_bias = 0,
        secondary_bias = 0,
        allow_fire = false,
        allow_scorch = false,
        allow_secondary = false,
        default_pipeline_fire = false,
        default_platform_tile_damage = false,
    },
    thermal = {
        family = "thermal",
        damage_type = "fire",
        fire_name = "ei-exotic-fire-flame",
        platform_fire_name = "ei-exotic-platform-fire-flame",
        smoke_name = "ei-exotic-rupture-smoke",
        pair_explosion_name = "medium-explosion",
        explosion_bias = 1.05,
        fire_bias = 0.78,
        smoke_bias = 1.15,
        scorch_bias = 1.00,
        ring_bias = 1.05,
        shockwave_bias = 1.02,
        massive_bias = 0.20,
        secondary_bias = 0,
        allow_fire = true,
        allow_scorch = true,
        allow_secondary = false,
        default_pipeline_fire = true,
        default_platform_tile_damage = true,
    },
    chemical = {
        family = "chemical",
        damage_type = "acid",
        smoke_name = "ei-chemical-rupture-smoke",
        pair_explosion_name = "explosion",
        explosion_bias = 0.74,
        fire_bias = 0,
        smoke_bias = 1.30,
        scorch_bias = 0,
        ring_bias = 0.84,
        shockwave_bias = 0.88,
        massive_bias = 0,
        secondary_bias = 0,
        allow_fire = false,
        allow_scorch = false,
        allow_secondary = false,
        default_pipeline_fire = false,
        default_platform_tile_damage = false,
        cloud_name = "ei-corrosive-rocket-cloud",
    },
}

local CARRIER_CLASS_BIASES = {
    line = {visual_scale = 1.00, smoke_scale = 1.00, scorch_scale = 1.00, stage_scale = 1.00, shockwave_scale = 1.00},
    ["elevated-line"] = {visual_scale = 0.92, smoke_scale = 0.92, scorch_scale = 0.85, stage_scale = 0.90, shockwave_scale = 0.88},
    ["signal-line"] = {visual_scale = 0.98, smoke_scale = 0.95, scorch_scale = 0.00, stage_scale = 0.92, shockwave_scale = 0.95},
    vessel = {visual_scale = 1.70, smoke_scale = 1.60, scorch_scale = 1.45, stage_scale = 1.60, shockwave_scale = 1.45},
}

local SEVERITY_SCALE = {
    small = 1.00,
    medium = 1.60,
}

local CONTEXTUAL_EXPLOSION_FAMILIES = {
    data = "signal",
    cryo = "steam",
    thermal = "combustion",
    chemical = "chemical",
}

local function shallow_copy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function get_effect_style(spec)
    local base_style = EFFECT_STYLES[spec.effect_family]
    if not base_style then
        return nil
    end

    local style = shallow_copy(base_style)
    local variant = spec.effect_variant or ""
    if spec.effect_family == "thermal" then
        if variant == "lava" then
            style.fire_name = "ei-lava-fire-flame"
            style.platform_fire_name = "ei-lava-platform-fire-flame"
            style.smoke_name = "ei-lava-rupture-smoke"
            style.pair_explosion_name = "explosion"
            style.explosion_bias = style.explosion_bias * 0.58
            style.fire_bias = style.fire_bias * 1.18
            style.smoke_bias = style.smoke_bias * 1.12
            style.scorch_bias = style.scorch_bias * 1.45
            style.ring_bias = style.ring_bias * 0.66
            style.shockwave_bias = style.shockwave_bias * 0.60
            style.massive_bias = style.massive_bias * 0.30
            style.visual_radius_scale = 0.62
            style.pipeline_fire_radius_scale = 0.58
            style.ground_overlay_sprite = LAVA_GROUND_PATCH_SPRITE
            style.ground_overlay_ttl = LAVA_GROUND_PATCH_TTL
            style.ground_overlay_scale = LAVA_GROUND_PATCH_SCALE
            style.ground_overlay_tint = LAVA_GROUND_PATCH_TINT
            style.ground_overlay_allowed = true
        elseif string.find(variant, "ei%-heated%-", 1) == 1 then
            style.fire_bias = style.fire_bias * 0.92
            style.smoke_bias = style.smoke_bias * 0.95
        end
    elseif spec.effect_family == "chemical" then
        if variant == "electrolyte" then
            style.explosion_bias = style.explosion_bias * 1.12
            style.smoke_bias = style.smoke_bias * 0.92
            style.pair_explosion_name = "spark-explosion"
        elseif variant == "fluoroketone-cold" or variant == "fluoroketone-hot" then
            style.explosion_bias = style.explosion_bias * 0.72
            style.smoke_bias = style.smoke_bias * 1.10
            style.pair_explosion_name = "water-splash"
        end
    elseif spec.effect_family == "data" and spec.carrier_class == "signal-line" then
        style.explosion_bias = style.explosion_bias * 0.95
        style.smoke_bias = style.smoke_bias * 0.90
    end

    return style
end

local function get_entity_radius(entity)
    local box = entity and entity.bounding_box or nil
    if not box then
        return 0.5
    end

    local pos = entity.position
    return 0.5 * ((box.right_bottom.x - pos.x) + (box.right_bottom.y - pos.y))
end

local function get_entity_class_bias(entity, carrier_class)
    if carrier_class and CARRIER_CLASS_BIASES[carrier_class] then
        return CARRIER_CLASS_BIASES[carrier_class]
    end

    if not entity or not entity.valid then
        return CARRIER_CLASS_BIASES.line
    end

    local entity_type = entity.type
    if entity_type == "storage-tank" or entity_type == "fluid-wagon" then
        return CARRIER_CLASS_BIASES.vessel
    end

    if entity_type == "assembling-machine"
        or entity_type == "furnace"
        or entity_type == "boiler"
        or entity_type == "generator"
        or entity_type == "reactor"
        or entity_type == "lab"
        or entity_type == "mining-drill"
    then
        return {visual_scale = 1.25, smoke_scale = 1.20, scorch_scale = 1.15, stage_scale = 1.22, shockwave_scale = 1.15}
    end

    if entity_type == "pipe-to-ground" then
        return {visual_scale = 1.08, smoke_scale = 1.05, scorch_scale = 1.00, stage_scale = 1.05, shockwave_scale = 1.00}
    end

    return CARRIER_CLASS_BIASES.line
end

local function get_explosion_metrics(total_energy_mj)
    local scaled_energy = math.max(0, total_energy_mj * 10)
    return RADIUS_MULT * math.pow(scaled_energy, RADIUS_POWER), DAMAGE_MULT * math.pow(scaled_energy, DAMAGE_POWER)
end

local function get_contextual_explosion_bucket(carrier_class, severity, effect_visual_radius)
    if carrier_class == "vessel" then
        return severity == "medium" and "medium" or "small"
    end

    if effect_visual_radius <= 1.15 then
        return "micro"
    end

    return "small"
end

local function get_contextual_explosion_name(effect_family, carrier_class, severity, effect_visual_radius)
    local family = effect_family and CONTEXTUAL_EXPLOSION_FAMILIES[effect_family] or nil
    if not family then
        return nil
    end

    local bucket = get_contextual_explosion_bucket(carrier_class, severity, effect_visual_radius)
    return string.format("ei-death-explosion-%s-%s", family, bucket)
end

local function is_low_signature_line_break(effect_family, carrier_class, severity)
    return severity == "small"
        and carrier_class ~= "vessel"
        and (effect_family == "data" or effect_family == "cryo" or effect_family == "chemical")
end

local function is_compact_lava_break(spec)
    return spec
        and spec.effect_family == "thermal"
        and spec.effect_variant == "lava"
        and spec.carrier_class ~= "vessel"
end

local function total_entry_count(entries)
    local total = 0
    for _, entry in ipairs(entries or {}) do
        total = total + math.max(0, entry.count or 0)
    end
    return total
end

local function get_entry_count(entries, key)
    for _, entry in ipairs(entries or {}) do
        if entry.key == key then
            return math.max(0, entry.count or 0)
        end
    end
    return 0
end

local function apply_cap(entries, cap)
    if cap == nil then
        return
    end

    local total = total_entry_count(entries)
    if total <= cap then
        return
    end

    local scale = cap / total
    local rounded_total = 0
    local remainders = {}
    for index, entry in ipairs(entries) do
        local raw = math.max(0, entry.count or 0) * scale
        entry.count = math.floor(raw)
        rounded_total = rounded_total + entry.count
        remainders[#remainders + 1] = {index = index, remainder = raw - entry.count, raw = raw}
    end

    table.sort(remainders, function(left, right) return left.remainder > right.remainder end)
    local remaining = cap - rounded_total
    local cursor = 1
    while remaining > 0 and #remainders > 0 do
        local target = remainders[cursor]
        if target.raw > 0 then
            entries[target.index].count = entries[target.index].count + 1
            remaining = remaining - 1
        end
        cursor = cursor + 1
        if cursor > #remainders then
            cursor = 1
        end
    end
end

local function scale_entry_counts(entries, scale)
    if scale == nil or scale == 1 then
        return
    end

    for _, entry in ipairs(entries or {}) do
        local count = math.max(0, entry.count or 0)
        if count > 0 then
            entry.count = math.max(0, math.floor((count * scale) + 0.5))
        end
    end
end

local function get_surface_context(surface)
    local platform = surface and surface.valid and surface.platform or nil
    return {
        is_platform = platform ~= nil,
        has_pollutant = surface and surface.valid and surface.pollutant_type ~= nil or false,
    }
end

local function get_platform_fire_name(style, surface_context)
    if surface_context and surface_context.is_platform and style.platform_fire_name then
        return style.platform_fire_name
    end
    return style.fire_name
end

local function get_platform_tile_damage(style, explosion_damage, is_pipeline)
    local family_mult = PLATFORM_TILE_DAMAGE_FAMILY_MULT[style.family] or 1
    local scaled = (explosion_damage / PLATFORM_SOURCE_TILE_DAMAGE_DIVISOR) * family_mult
    if is_pipeline then
        return ei_lib.clamp(scaled * PLATFORM_PIPE_TILE_DAMAGE_MULT, PLATFORM_PIPE_TILE_DAMAGE_MIN, PLATFORM_PIPE_TILE_DAMAGE_MAX)
    end
    return ei_lib.clamp(scaled, PLATFORM_SOURCE_TILE_DAMAGE_MIN, PLATFORM_SOURCE_TILE_DAMAGE_MAX)
end

local function get_tile_key(position)
    local tile_x = math.floor(position.x)
    local tile_y = math.floor(position.y)
    return string.format("%d,%d", tile_x, tile_y), tile_x, tile_y
end

local function add_platform_tile_damage(ring, seen_tiles, position, damage)
    if not (ring and position and damage and damage > 0) then
        return
    end

    local key, tile_x, tile_y = get_tile_key(position)
    if seen_tiles[key] then
        return
    end

    seen_tiles[key] = true
    ring.platform_tile_damage[#ring.platform_tile_damage + 1] = {
        position = {x = tile_x, y = tile_y},
        damage = damage,
    }
end

local function add_entity_platform_tile_damage(ring, seen_tiles, entity, damage)
    local box = entity and entity.bounding_box
    if not box then
        return
    end

    local left = math.floor(box.left_top.x)
    local right = math.ceil(box.right_bottom.x) - 1
    local top = math.floor(box.left_top.y)
    local bottom = math.ceil(box.right_bottom.y) - 1

    for tile_x = left, right do
        for tile_y = top, bottom do
            add_platform_tile_damage(ring, seen_tiles, {x = tile_x + 0.5, y = tile_y + 0.5}, damage)
        end
    end
end

local function distribute_count(total, weights)
    local distribution, weight_total = {}, 0
    for _, weight in ipairs(weights or {}) do
        weight_total = weight_total + weight
    end
    if total <= 0 or weight_total <= 0 then
        for index = 1, #(weights or {}) do
            distribution[index] = 0
        end
        return distribution
    end

    local cumulative, assigned = 0, 0
    for index, weight in ipairs(weights) do
        cumulative = cumulative + weight
        local quota = math.floor((cumulative / weight_total) * total + 0.00001)
        distribution[index] = quota - assigned
        assigned = quota
    end
    if assigned < total then
        distribution[#weights] = (distribution[#weights] or 0) + (total - assigned)
    end
    return distribution
end

local function build_ring_weights(ring_count)
    local weights = {cluster = {}, shock = {}, fire = {}, smoke = {}, scorch = {}, accent = {}}
    for index = 1, ring_count do
        weights.cluster[index] = math.pow((ring_count - index) + 1, 1.15)
        weights.shock[index] = math.pow(index, 1.25)
        weights.fire[index] = math.max(0.35, math.pow((ring_count - index) + 1, 0.85))
        weights.smoke[index] = 0.75 + math.pow(index, 1.05)
        weights.scorch[index] = math.pow(index, 1.6)
        weights.accent[index] = 0.5 + math.pow(index, 1.1)
    end
    return weights
end

local function new_ring()
    return {
        center_entities = {},
        entity_layers = {},
        smoke_layers = {},
        fire_layers = {},
        scorch_layers = {},
        damage_victims = {},
        platform_tile_damage = {},
    }
end

local function add_layer(ring, field_name, layer)
    if layer and layer.name and (layer.count or 0) > 0 then
        local list = ring[field_name]
        list[#list + 1] = layer
    end
end

local function add_distributed_layers(rings, total_count, weights, field_name, name, emitter, max_radius, force_name)
    if total_count <= 0 or max_radius <= 0 then
        return
    end

    local ring_count = #rings
    local distribution = distribute_count(total_count, weights)
    for index, count in ipairs(distribution) do
        if count > 0 then
            local inner_radius = max_radius * ((index - 1) / ring_count)
            add_layer(rings[index], field_name, {
                name = name,
                count = count,
                emitter = emitter,
                inner_radius = inner_radius,
                outer_radius = math.max(inner_radius, max_radius * (index / ring_count)),
                force_name = force_name,
            })
        end
    end
end

local function is_pipeline_entity(entity, spec)
    if spec and spec.allow_pipeline_fire == false then
        return false
    end

    return entity and entity.valid and DIRECT_PIPELINE_FIRE_TYPES[entity.type]
end

local function get_entity_visit_key(entity)
    if not (entity and entity.valid) then
        return nil
    end

    if entity.unit_number then
        return "unit:" .. entity.unit_number
    end

    return string.format("%s@%.3f,%.3f", entity.type or "entity", entity.position.x, entity.position.y)
end

local function get_pipeline_fire_cap(mode)
    return DIRECT_PIPELINE_FIRE_CAPS[mode]
end

local function get_pipeline_fire_radius(search_radius, explosion_radius, entity_radius)
    local seeded_radius = (explosion_radius * DIRECT_PIPELINE_FIRE_RADIUS_MULT) + entity_radius + 1
    seeded_radius = math.max(DIRECT_PIPELINE_FIRE_RADIUS_MIN, seeded_radius)
    seeded_radius = math.min(DIRECT_PIPELINE_FIRE_RADIUS_MAX, seeded_radius)
    return math.min(search_radius, seeded_radius)
end

local function copy_position(position)
    return {x = position.x, y = position.y}
end

local function collect_nearby_entities(entity, radius)
    if not (entity and entity.valid and radius and radius > 0) then
        return {}
    end

    return entity.surface.find_entities_filtered{position = entity.position, radius = radius}
end

local function get_connected_fluid_owners(entity)
    if not (entity and entity.valid and entity.fluidbox and #entity.fluidbox > 0) then
        return {}
    end

    local owners = {}
    local seen = {}
    for index = 1, #entity.fluidbox do
        local ok, connections = pcall(function()
            return entity.fluidbox.get_connections(index)
        end)
        if ok and connections then
            for _, connection in pairs(connections) do
                local owner = connection and connection.owner or nil
                local key = get_entity_visit_key(owner)
                if owner and owner.valid and key and not seen[key] then
                    seen[key] = true
                    owners[#owners + 1] = owner
                end
            end
        end
    end

    return owners
end

local function get_connection_step_distance(source, target)
    if not (source and source.valid and target and target.valid) then
        return 0
    end

    local dx = target.position.x - source.position.x
    local dy = target.position.y - source.position.y
    return math.sqrt((dx * dx) + (dy * dy))
end

local function compare_fire_targets(left, right)
    if left.distance ~= right.distance then
        return left.distance < right.distance
    end

    return (left.order or 0) < (right.order or 0)
end

local function sort_fire_targets(targets)
    table.sort(targets, compare_fire_targets)
    return targets
end

local function rebuild_worst_fire_target(targets, target_cap_state)
    local worst_index = nil
    local worst_target = nil

    for index, target in ipairs(targets) do
        if not worst_target or compare_fire_targets(worst_target, target) then
            worst_index = index
            worst_target = target
        end
    end

    target_cap_state.worst_index = worst_index
    target_cap_state.worst_distance = worst_target and worst_target.distance or nil
    return worst_target
end

local function new_fire_target_cap_state(fire_cap)
    return {
        fire_cap = fire_cap,
        next_order = 0,
        worst_index = nil,
        worst_distance = nil,
    }
end

local function push_nearest_fire_target(targets, target_cap_state, target)
    local fire_cap = target_cap_state and target_cap_state.fire_cap or nil
    if not target then
        return false
    end

    target_cap_state.next_order = (target_cap_state.next_order or 0) + 1
    target.order = target_cap_state.next_order

    if not fire_cap then
        targets[#targets + 1] = target
        return true
    end

    if #targets < fire_cap then
        targets[#targets + 1] = target
        rebuild_worst_fire_target(targets, target_cap_state)
        return true
    end

    local worst_target = targets[target_cap_state.worst_index] or rebuild_worst_fire_target(targets, target_cap_state)
    if not worst_target or not compare_fire_targets(target, worst_target) then
        return false
    end

    targets[target_cap_state.worst_index] = target
    rebuild_worst_fire_target(targets, target_cap_state)
    return true
end

local function collect_local_pipeline_fire_targets(entity, nearby_entities, fire_radius, profile)
    local fire_cap = get_pipeline_fire_cap(profile.mode)
    local targets = {}
    local target_cap_state = new_fire_target_cap_state(fire_cap)
    local limit = fire_radius * fire_radius

    for _, other in ipairs(nearby_entities or {}) do
        if other ~= entity and is_pipeline_entity(other) then
            local dx = other.position.x - entity.position.x
            local dy = other.position.y - entity.position.y
            local distance_sq = (dx * dx) + (dy * dy)
            if distance_sq <= limit then
                push_nearest_fire_target(targets, target_cap_state, {
                    entity = other,
                    position = copy_position(other.position),
                    distance = math.sqrt(distance_sq),
                })
            end
        end
    end

    return sort_fire_targets(targets)
end

local function collect_pipeline_fire_targets(entity, nearby_entities, fire_radius, profile)
    if not is_pipeline_entity(entity) then
        return {}
    end

    local visit_cap = get_pipeline_fire_cap(profile.mode)
    if visit_cap then
        visit_cap = math.max(PIPELINE_TRAVERSAL_MIN_VISITS, visit_cap * PIPELINE_TRAVERSAL_VISIT_MULT)
    else
        visit_cap = PIPELINE_TRAVERSAL_UNBOUNDED_VISITS
    end

    local fire_cap = get_pipeline_fire_cap(profile.mode)
    local targets = {}
    local target_cap_state = new_fire_target_cap_state(fire_cap)
    local visited = {}
    local visited_count = 0
    local queue = {}
    local queue_index = 1

    local function enqueue(target, path_distance)
        local key = get_entity_visit_key(target)
        if not key or visited[key] then
            return true
        end

        visited[key] = true
        visited_count = visited_count + 1

        if target ~= entity
            and fire_cap
            and #targets >= fire_cap
            and target_cap_state.worst_distance
            and path_distance >= target_cap_state.worst_distance
        then
            return true
        end

        queue[#queue + 1] = {entity = target, path_distance = path_distance}
        if target ~= entity then
            push_nearest_fire_target(targets, target_cap_state, {
                entity = target,
                position = copy_position(target.position),
                distance = path_distance,
            })
        end

        return true
    end

    enqueue(entity, 0)

    while queue_index <= #queue and visited_count < visit_cap do
        local current = queue[queue_index]
        queue_index = queue_index + 1

        if fire_cap
            and #targets >= fire_cap
            and target_cap_state.worst_distance
            and current.path_distance >= target_cap_state.worst_distance
        then
            goto continue_pipeline_queue
        end

        for _, owner in ipairs(get_connected_fluid_owners(current.entity)) do
            if owner.valid then
                local next_distance = current.path_distance + get_connection_step_distance(current.entity, owner)
                local owner_budget = fire_radius + get_entity_radius(owner)
                if next_distance <= owner_budget then
                    enqueue(owner, next_distance)
                end
            end
        end

        ::continue_pipeline_queue::
    end

    sort_fire_targets(targets)

    if #targets == 0 then
        return collect_local_pipeline_fire_targets(entity, nearby_entities, fire_radius, profile)
    end

    return targets
end

local function add_pipeline_fire_layers(rings, entity, nearby_entities, fire_name, profile, surface_context, explosion_radius, search_radius, entity_radius, seen_platform_tiles, platform_pipe_tile_damage, spec, style)
    if not fire_name or #rings == 0 or spec.allow_pipeline_fire == false then
        return
    end

    local fire_radius = get_pipeline_fire_radius(search_radius, explosion_radius, entity_radius)
    fire_radius = fire_radius * math.max(0.2, tonumber(style and style.pipeline_fire_radius_scale) or 1)
    if fire_radius <= 0 then
        return
    end

    local targets = collect_pipeline_fire_targets(entity, nearby_entities, fire_radius, profile)
    local divisor = math.max(fire_radius, 0.001)
    local ring_count = #rings
    for _, target in ipairs(targets) do
        local ring_index = math.max(1, math.min(ring_count, math.ceil((target.distance / divisor) * ring_count)))
        add_layer(rings[ring_index], "fire_layers", {
            name = fire_name,
            count = 1,
            emitter = "center",
            inner_radius = 0,
            outer_radius = 0,
            force_name = "neutral",
            position = target.position,
        })

        if surface_context.is_platform and spec.allow_platform_tile_damage ~= false then
            add_platform_tile_damage(rings[ring_index], seen_platform_tiles, target.position, platform_pipe_tile_damage)
        end
    end
end

local function select_secondary_mix(rupture, primary_family, profile)
    local selected = {}
    local threshold = profile.secondary_threshold or 1
    local limit = profile.secondary_limit
    if limit == nil then
        limit = math.huge
    end

    local ranked = {}
    for family, share in pairs(rupture.family_share or {}) do
        if share and share > 0 then
            ranked[#ranked + 1] = {family = family, share = share}
        end
    end
    table.sort(ranked, function(left, right) return left.share > right.share end)

    for _, mix in ipairs(ranked) do
        if mix.family ~= primary_family and mix.share >= threshold then
            selected[#selected + 1] = mix
            if #selected >= limit then
                break
            end
        end
    end
    return selected
end

local function build_damage_rings(entity, nearby_entities, ring_count, explosion_radius, explosion_damage)
    local damage_rings = {}
    local source_position = entity and entity.position or nil
    for index = 1, ring_count do
        damage_rings[index] = {}
    end

    if explosion_radius <= 0 or explosion_damage <= 0 then
        return damage_rings
    end

    for _, victim in ipairs(nearby_entities or {}) do
        if victim ~= entity and victim.valid and ei_lib.entity_can_take_health_damage(victim) then
            local dx = victim.position.x - source_position.x
            local dy = victim.position.y - source_position.y
            local distance_sq = (dx * dx) + (dy * dy)
            local victim_radius = get_entity_radius(victim)
            local max_distance = explosion_radius + victim_radius
            if distance_sq <= (max_distance * max_distance) then
                local distance = math.sqrt(distance_sq)
                local effective_distance = math.max(0, distance - victim_radius)
                local distance_ratio = math.min(1, effective_distance / explosion_radius)
                local amount = math.max(0, explosion_damage * (1 - math.pow(distance_ratio, DAMAGE_FALLOFF_POWER)))
                if amount > 0 then
                    local ring_index = math.max(1, math.min(ring_count, math.ceil((effective_distance / explosion_radius) * ring_count)))
                    local ring = damage_rings[ring_index]
                    ring[#ring + 1] = {entity = victim, damage = amount}
                end
            end
        end
    end

    return damage_rings
end

local function build_pair_child_jobs(entity, style, source_force_name, pair_fire_name, platform_pipe_tile_damage, explosion_damage, mode, surface_context, spec)
    if spec.allow_pipeline_fire == false or entity.type ~= "pipe-to-ground" or not entity.neighbours then
        return {}
    end

    local pair_explosion_name = nil
    if is_compact_lava_break(spec) then
        pair_explosion_name = style.pair_explosion_name
    else
        pair_explosion_name = get_contextual_explosion_name(spec.effect_family, spec.carrier_class, "small", 0.95) or style.pair_explosion_name
    end

    for _, neighbour_group in pairs(entity.neighbours) do
        if neighbour_group and neighbour_group.object_name == "LuaEntity" then
            neighbour_group = {neighbour_group}
        end

        if type(neighbour_group) == "table" then
            for _, neighbour in pairs(neighbour_group) do
                if neighbour and neighbour.valid and neighbour.type == "pipe-to-ground" then
                    local ring = {
                        center_entities = {{name = pair_explosion_name}},
                        entity_layers = {},
                        smoke_layers = {{name = style.smoke_name, count = 1, emitter = "center", inner_radius = 0, outer_radius = 0}},
                        fire_layers = {},
                        scorch_layers = {},
                        damage_victims = {{entity = neighbour, damage = explosion_damage}},
                        platform_tile_damage = {},
                    }

                    if pair_fire_name then
                        ring.fire_layers = {{
                            name = pair_fire_name,
                            count = 1,
                            emitter = "center",
                            inner_radius = 0,
                            outer_radius = 0,
                            force_name = "neutral",
                        }}
                    end

                    if surface_context.is_platform and spec.allow_platform_tile_damage ~= false then
                        local seen_tiles = {}
                        add_platform_tile_damage(ring, seen_tiles, neighbour.position, platform_pipe_tile_damage)
                    end

                    return {{
                        mode = mode,
                        damage_type = style.damage_type,
                        source_force_name = source_force_name,
                        surface_index = entity.surface.index,
                        surface_kind = surface_context.is_platform and "platform" or "planetary",
                        position = {x = neighbour.position.x, y = neighbour.position.y},
                        ring_count = 1,
                        initial_delay = 1,
                        rings = {ring},
                    }}
                end
            end
        end
    end

    return {}
end

local function build_primary_layers(rings, profile, rupture, style, fire_name, class_bias, visual_radius, surface_context, spec)
    local total_energy_mj = rupture.total_energy_mj
    local gas_share = rupture.family_share.gas or 0
    local energy_root = math.sqrt(total_energy_mj)
    local weights = build_ring_weights(#rings)
    local effect_visual_radius = surface_context.is_platform and math.max(visual_radius * PLATFORM_VISUAL_RADIUS_MULT, 0.45) or visual_radius
    local outer_radius = math.max(effect_visual_radius * (1.05 + (0.08 * class_bias.shockwave_scale)), 0.8)
    local shock_base = math.max(1, math.ceil((visual_radius + (energy_root * 0.055)) * style.ring_bias * class_bias.stage_scale))
    local shock_extra = total_energy_mj >= 220 or class_bias.stage_scale >= 1.35
    local contextual_explosion_name = get_contextual_explosion_name(spec.effect_family, spec.carrier_class, spec.severity, effect_visual_radius)
    local low_signature_line_break = is_low_signature_line_break(spec.effect_family, spec.carrier_class, spec.severity)
    local compact_lava_break = is_compact_lava_break(spec)

    local explosion_entries = {
        {key = "cluster_medium", count = math.max(1, math.ceil((visual_radius + (energy_root * 0.045)) * style.explosion_bias * class_bias.stage_scale))},
        {key = "cluster_big", count = math.max(0, math.floor(energy_root * (0.12 + (gas_share * 0.35)) * style.explosion_bias * class_bias.visual_scale))},
        {key = "shock_big", count = shock_base},
        {key = "shock_medium", count = shock_extra and math.max(1, math.ceil(shock_base * 0.8)) or 0},
    }
    if contextual_explosion_name and (spec.effect_family == "data" or spec.effect_family == "cryo" or spec.effect_family == "chemical") then
        for _, entry in ipairs(explosion_entries) do
            if entry.key == "cluster_big" then
                entry.count = 0
            elseif entry.key == "shock_big" then
                entry.count = math.max(0, math.floor(entry.count * 0.35))
            elseif entry.key == "cluster_medium" then
                entry.count = math.max(1, math.floor(entry.count * 0.55))
            elseif entry.key == "shock_medium" then
                entry.count = math.max(0, math.floor(entry.count * 0.45))
            end
        end
    end
    if low_signature_line_break then
        for _, entry in ipairs(explosion_entries) do
            if entry.key == "cluster_big" then
                entry.count = 0
            elseif entry.key == "shock_big" or entry.key == "shock_medium" then
                entry.count = 0
            elseif entry.key == "cluster_medium" then
                entry.count = math.max(0, math.floor(entry.count * 0.25))
            end
        end
    end
    if compact_lava_break then
        for _, entry in ipairs(explosion_entries) do
            if entry.key == "cluster_big" then
                entry.count = 0
            elseif entry.key == "shock_big" or entry.key == "shock_medium" then
                entry.count = 0
            elseif entry.key == "cluster_medium" then
                entry.count = 0
            end
        end
    end
    local fire_entries = {}
    if spec.allow_fire ~= false and fire_name then
        fire_entries = {
            {key = "core", count = math.max(1, math.ceil(((visual_radius * visual_radius) + energy_root) * style.fire_bias * class_bias.visual_scale))},
            {key = "rim", count = math.max(1, math.ceil(((visual_radius * 2) + math.sqrt(total_energy_mj * 0.5)) * style.fire_bias * class_bias.visual_scale * 0.75))},
        }
    end
    if compact_lava_break then
        for _, entry in ipairs(fire_entries) do
            if entry.key == "rim" then
                entry.count = math.max(0, math.floor(entry.count * 0.25))
            elseif entry.key == "core" then
                entry.count = math.max(1, math.floor(entry.count * 1.05))
            end
        end
    end
    local smoke_base = math.max(2, math.ceil(((visual_radius * 1.8) + (energy_root * 0.11)) * style.smoke_bias * class_bias.smoke_scale))
    local smoke_entries = {
        {key = "core", count = smoke_base},
        {key = "rim", count = math.max(1, math.ceil(smoke_base * 0.45))},
        {key = "shock", count = math.max(2, math.ceil(shock_base * (0.85 + (style.shockwave_bias * 0.2))))},
        {key = "shock_extra", count = shock_extra and math.max(2, math.ceil(math.max(2, math.ceil(shock_base * (0.85 + (style.shockwave_bias * 0.2)))) * 0.6)) or 0},
    }
    if compact_lava_break then
        for _, entry in ipairs(smoke_entries) do
            if entry.key == "rim" then
                entry.count = math.max(0, math.floor(entry.count * 0.30))
            elseif entry.key == "shock" or entry.key == "shock_extra" then
                entry.count = 0
            elseif entry.key == "core" then
                entry.count = math.max(2, math.floor(entry.count * 0.72))
            end
        end
    end
    local scorch_entries = {}
    if spec.allow_scorch ~= false and total_energy_mj >= SCORCH_THRESHOLD_MJ then
        scorch_entries = {
            {key = "core", count = math.max(1, math.ceil(((visual_radius * 1.2) + (energy_root * 0.05)) * style.scorch_bias * class_bias.scorch_scale))},
            {key = "rim", count = visual_radius >= 1.2 and math.max(1, math.floor(math.max(1, math.ceil(((visual_radius * 1.2) + (energy_root * 0.05)) * style.scorch_bias * class_bias.scorch_scale)) * 0.5)) or 0},
        }
    end
    if compact_lava_break then
        for _, entry in ipairs(scorch_entries) do
            if entry.key == "core" then
                entry.count = math.max(1, math.floor(entry.count * 1.25))
            elseif entry.key == "rim" then
                entry.count = math.max(0, math.floor(entry.count * 0.25))
            end
        end
    end

    if surface_context.is_platform then
        scale_entry_counts(explosion_entries, PLATFORM_EXPLOSION_COUNT_MULT)
        scale_entry_counts(smoke_entries, PLATFORM_SMOKE_COUNT_MULT)
        fire_entries = {}
        scorch_entries = {}
    end

    apply_cap(explosion_entries, profile.explosion_cap)
    apply_cap(fire_entries, profile.fire_cap)
    apply_cap(smoke_entries, profile.smoke_cap)
    apply_cap(scorch_entries, profile.scorch_cap)

    local massive_count = math.max(0, math.floor(math.sqrt(total_energy_mj / 1000) * style.massive_bias * class_bias.shockwave_scale))
    if compact_lava_break then
        massive_count = 0
    end
    if surface_context.is_platform then
        massive_count = math.min(massive_count, PLATFORM_MASSIVE_CAP)
    end
    if profile.massive_cap ~= nil then
        massive_count = math.min(massive_count, profile.massive_cap)
    end

    local center_explosion_name = contextual_explosion_name or (effect_visual_radius <= 1 and "explosion" or "medium-explosion")
    if compact_lava_break then
        center_explosion_name = "explosion"
    end
    if low_signature_line_break then
        if spec.effect_family == "data" then
            center_explosion_name = spec.carrier_class == "signal-line" and "spark-explosion-higher" or "spark-explosion"
        elseif spec.effect_family == "cryo" then
            center_explosion_name = "water-splash"
        elseif spec.effect_family == "chemical" then
            if spec.effect_variant == "electrolyte" then
                center_explosion_name = "spark-explosion-higher"
            else
                center_explosion_name = "water-splash"
            end
        end
    end
    rings[1].center_entities[#rings[1].center_entities + 1] = {
        name = center_explosion_name
    }
    if contextual_explosion_name then
        add_distributed_layers(
            rings,
            low_signature_line_break and 0 or (compact_lava_break and 0 or (spec.effect_family == "thermal" and 1 or math.max(1, math.min(2, math.ceil(effect_visual_radius * 0.75))))),
            weights.cluster,
            "entity_layers",
            contextual_explosion_name,
            "vogel",
            math.max(effect_visual_radius * (compact_lava_break and 0.28 or 0.45), 0.30)
        )
    end
    if compact_lava_break and fire_name then
        add_layer(rings[1], "fire_layers", {
            name = fire_name,
            count = math.max(1, math.min(2, math.ceil(effect_visual_radius))),
            emitter = "center",
            inner_radius = 0,
            outer_radius = math.max(0.18, math.min(effect_visual_radius * 0.22, 0.45)),
            force_name = "neutral",
        })
        add_layer(rings[1], "smoke_layers", {
            name = style.smoke_name,
            count = 1,
            emitter = "center",
            inner_radius = 0,
            outer_radius = 0,
        })
    end
    if low_signature_line_break then
        local accent_name = nil
        if spec.effect_family == "data" then
            accent_name = "spark-explosion"
        elseif spec.effect_family == "cryo" then
            accent_name = "water-splash"
        elseif spec.effect_family == "chemical" then
            accent_name = spec.effect_variant == "electrolyte" and "spark-explosion" or "water-splash"
        end

        if accent_name then
            add_distributed_layers(
                rings,
                math.max(2, math.ceil(effect_visual_radius * 1.4)),
                weights.accent,
                "entity_layers",
                accent_name,
                "vogel",
                math.max(effect_visual_radius * 0.72, 0.4)
            )
        end
    end
    add_distributed_layers(rings, get_entry_count(explosion_entries, "cluster_medium"), weights.cluster, "entity_layers", "medium-explosion", "vogel", math.max(effect_visual_radius, 0.5))
    add_distributed_layers(
        rings,
        get_entry_count(explosion_entries, "cluster_big"),
        weights.cluster,
        "entity_layers",
        "big-explosion",
        "rim",
        math.max(effect_visual_radius * (surface_context.is_platform and PLATFORM_EFFECT_RADIUS_MULT or 0.88), 0.5)
    )
    add_distributed_layers(rings, get_entry_count(explosion_entries, "shock_big"), weights.shock, "entity_layers", "big-explosion", "rim", outer_radius)
    add_distributed_layers(rings, get_entry_count(explosion_entries, "shock_medium"), weights.shock, "entity_layers", "medium-explosion", "rim", outer_radius * 1.18)
    add_distributed_layers(rings, massive_count, weights.shock, "entity_layers", "massive-explosion", "rim", math.max(effect_visual_radius * 0.68, 0.5))

    add_distributed_layers(rings, get_entry_count(fire_entries, "core"), weights.fire, "fire_layers", fire_name, "vogel", math.max(effect_visual_radius * 0.92, 0.5), "neutral")
    add_distributed_layers(rings, get_entry_count(fire_entries, "rim"), weights.fire, "fire_layers", fire_name, "rim", math.max(effect_visual_radius * 1.08, 0.75), "neutral")
    add_distributed_layers(rings, get_entry_count(smoke_entries, "core"), weights.smoke, "smoke_layers", style.smoke_name, "vogel", math.max(effect_visual_radius * 1.12, 0.6))
    add_distributed_layers(rings, get_entry_count(smoke_entries, "rim"), weights.smoke, "smoke_layers", style.smoke_name, "rim", math.max(effect_visual_radius * 1.12, 0.8))
    add_distributed_layers(rings, get_entry_count(smoke_entries, "shock"), weights.shock, "smoke_layers", style.smoke_name, "rim", outer_radius * 1.04)
    add_distributed_layers(rings, get_entry_count(smoke_entries, "shock_extra"), weights.shock, "smoke_layers", style.smoke_name, "rim", outer_radius * 1.22)
    add_distributed_layers(rings, get_entry_count(scorch_entries, "core"), weights.scorch, "scorch_layers", "small-scorchmark", "vogel", math.max(effect_visual_radius * math.max(0.8, style.scorch_bias) * 0.82, 0.4))
    add_distributed_layers(rings, get_entry_count(scorch_entries, "rim"), weights.scorch, "scorch_layers", "small-scorchmark", "rim", math.max(effect_visual_radius * math.max(0.8, style.scorch_bias) * 1.05, 0.5))

    if style.cloud_name and spec.severity == "medium" then
        rings[1].center_entities[#rings[1].center_entities + 1] = {name = style.cloud_name}
    end

    return weights
end

local function build_secondary_layers(rings, profile, rupture, primary_family, class_bias, visual_radius, weights, surface_context, spec)
    if spec.allow_secondary == false then
        return
    end

    for _, mix in ipairs(select_secondary_mix(rupture, primary_family, profile)) do
        local secondary_style = EFFECT_STYLES[mix.family]
        local scaled_energy = rupture.total_energy_mj * mix.share
        local scaled_radius = math.max(visual_radius * (0.55 + (mix.share * 0.65)), 0.45)
        local energy_root = math.sqrt(scaled_energy)
        local smoke_total = math.max(1, math.ceil(((scaled_radius * 1.8) + (energy_root * 0.11)) * secondary_style.smoke_bias * class_bias.smoke_scale * secondary_style.secondary_bias))
        local fire_name = get_platform_fire_name(secondary_style, surface_context)

        if surface_context.is_platform then
            scaled_radius = math.max(scaled_radius * PLATFORM_EFFECT_RADIUS_MULT, 0.4)
            smoke_total = math.max(1, math.floor((smoke_total * PLATFORM_SECONDARY_SMOKE_MULT) + 0.5))
        end

        add_distributed_layers(rings, smoke_total, weights.accent, "smoke_layers", secondary_style.smoke_name, "vogel", math.max(scaled_radius, 0.5))
        add_distributed_layers(rings, math.max(1, math.ceil(smoke_total * 0.45)), weights.accent, "smoke_layers", secondary_style.smoke_name, "rim", math.max(scaled_radius * 1.12, 0.6))

        if mix.family == "gas" then
            local accent_count = math.max(1, math.ceil((scaled_radius + (energy_root * 0.04)) * secondary_style.secondary_bias))
            if surface_context.is_platform then
                accent_count = math.max(1, math.floor((accent_count * PLATFORM_SECONDARY_EFFECT_MULT) + 0.5))
            end
            add_distributed_layers(rings, accent_count, weights.accent, "entity_layers", "big-explosion", "rim", math.max(scaled_radius * 0.92, 0.5))
        elseif fire_name and not surface_context.is_platform then
            local fire_scale = secondary_style.fire_bias * 0.45 * class_bias.visual_scale
            local fire_radius = math.max(scaled_radius * 0.72, 0.35)
            local fire_core = math.max(1, math.ceil(((fire_radius * fire_radius) + math.sqrt(scaled_energy * 0.32)) * fire_scale))
            local fire_rim = math.max(1, math.ceil(((fire_radius * 2) + math.sqrt((scaled_energy * 0.32) * 0.5)) * fire_scale * 0.75))
            add_distributed_layers(rings, fire_core, weights.accent, "fire_layers", fire_name, "vogel", fire_radius, "neutral")
            add_distributed_layers(rings, fire_rim, weights.accent, "fire_layers", fire_name, "rim", math.max(fire_radius * 1.08, 0.45), "neutral")
        end
    end
end

local function resolve_effect_flag(value, fallback)
    if value == nil then
        return fallback
    end

    return value
end

local function get_ground_overlay_scale(style, carrier_class)
    local scale = math.max(0.2, tonumber(style and style.ground_overlay_scale) or 1)
    if carrier_class == "vessel" then
        scale = scale * 1.25
    elseif carrier_class == "elevated-line" then
        scale = scale * 0.90
    end
    return ei_lib.clamp(scale, 0.55, 1.35)
end

local function get_ground_overlay_position(entity, carrier_class)
    if not (entity and entity.valid) then
        return nil
    end

    local position = entity.position
    if carrier_class == "line" or carrier_class == "elevated-line" or carrier_class == "signal-line" then
        return {
            x = math.floor(position.x) + 0.5,
            y = math.floor(position.y) + 0.5,
        }
    end

    return {
        x = position.x,
        y = position.y,
    }
end

local function maybe_spawn_ground_overlay(entity, surface_context, style, spec)
    if not (entity and entity.valid and style and style.ground_overlay_sprite and rendering) then
        return
    end
    if not surface_context or surface_context.is_platform then
        return
    end

    local allowed = resolve_effect_flag(spec and spec.allow_ground_overlay, style.ground_overlay_allowed)
    if allowed == false then
        return
    end

    local position = get_ground_overlay_position(entity, spec and spec.carrier_class)
    if not position then
        return
    end

    local render_object = nil
    local scale = get_ground_overlay_scale(style, spec and spec.carrier_class)
    local ok = pcall(function()
        render_object = rendering.draw_sprite{
            sprite = style.ground_overlay_sprite,
            target = position,
            surface = entity.surface,
            render_layer = "radius-visualization",
            time_to_live = math.max(1, tonumber(style.ground_overlay_ttl) or LAVA_GROUND_PATCH_TTL),
            x_scale = scale,
            y_scale = scale,
        }
    end)

    if not (ok and render_object) then
        return
    end

    pcall(function()
        render_object.draw_on_ground = true
        render_object.color = style.ground_overlay_tint or LAVA_GROUND_PATCH_TINT
    end)
end

local function get_effect_settings(spec, style)
    return {
        allow_fire = resolve_effect_flag(spec.allow_fire, style.allow_fire),
        allow_scorch = resolve_effect_flag(spec.allow_scorch, style.allow_scorch),
        allow_secondary = resolve_effect_flag(spec.allow_secondary, style.allow_secondary),
        allow_pipeline_fire = resolve_effect_flag(spec.allow_pipeline_fire, style.default_pipeline_fire),
        allow_platform_tile_damage = resolve_effect_flag(spec.allow_platform_tile_damage, style.default_platform_tile_damage),
        allow_ground_overlay = resolve_effect_flag(spec.allow_ground_overlay, style.ground_overlay_allowed),
        severity = spec.severity or "small",
        pollution_amount = spec.pollution_amount,
        damage_scale = spec.damage_scale,
        carrier_class = spec.carrier_class,
        effect_variant = spec.effect_variant,
        rupture = spec.rupture,
    }
end

local function build_effect_rupture(spec)
    local effect_family = spec.effect_family or "thermal"
    local stored_amount = math.max(0, tonumber(spec.stored_amount) or 0)
    local fluidbox_volume = math.max(1, tonumber(spec.fluidbox_volume) or 100)
    local severity_scale = SEVERITY_SCALE[spec.severity or "small"] or 1
    local base_energy = math.max(ENERGY_THRESHOLD_MJ + 2, (stored_amount * 0.12) + (fluidbox_volume * 0.04))

    if spec.carrier_class == "vessel" then
        base_energy = base_energy * 1.50
    elseif spec.carrier_class == "elevated-line" then
        base_energy = base_energy * 0.85
    elseif spec.carrier_class == "signal-line" then
        base_energy = base_energy * 0.90
    end

    if effect_family == "data" then
        base_energy = base_energy * 0.85
    elseif effect_family == "cryo" then
        base_energy = base_energy * 0.70
    elseif effect_family == "thermal" then
        base_energy = base_energy * 1.10
    elseif effect_family == "chemical" then
        base_energy = base_energy * 0.88
    end

    base_energy = base_energy * severity_scale

    return {
        total_energy_mj = base_energy,
        total_pollution = math.max(0, tonumber(spec.pollution_amount) or 0),
        family_share = {[effect_family] = 1},
        dominant = {
            family = effect_family,
            fluid_name = spec.effect_variant or effect_family,
            energy_mj = base_energy,
        },
    }
end

local function apply_rupture_pollution(surface, position, amount)
    if not (surface and surface.valid and amount and amount > 0) then
        return
    end

    if surface.pollutant_type == nil then
        return
    end

    surface.pollute(position, amount)
end

local function build_effect_job(entity, rupture, style, class_bias, spec)
    local surface_context = get_surface_context(entity.surface)
    local effect_settings = get_effect_settings(spec, style)
    local entity_radius = get_entity_radius(entity)
    local explosion_radius, explosion_damage = get_explosion_metrics(rupture.total_energy_mj)
    local damage_scale = math.max(0, tonumber(spec.damage_scale) or 1)
    explosion_damage = explosion_damage * damage_scale
    local visual_radius = math.max(explosion_radius, entity_radius) * class_bias.visual_scale * math.max(0.2, tonumber(style.visual_radius_scale) or 1)
    local search_radius = explosion_radius + entity_radius + DAMAGE_SEARCH_PADDING
    local profile = rupture_scheduler.get_fidelity_profile(visual_radius)
    local source_force_name = spec.source_force_name or (entity.force and entity.force.name) or "neutral"
    local fire_name = get_platform_fire_name(style, surface_context)
    local platform_source_tile_damage = 0
    local platform_pipe_tile_damage = 0
    if effect_settings.allow_platform_tile_damage ~= false then
        platform_source_tile_damage = surface_context.is_platform and get_platform_tile_damage(style, explosion_damage, false) or 0
        platform_pipe_tile_damage = surface_context.is_platform and get_platform_tile_damage(style, explosion_damage, true) or 0
    end

    local nearby_entities = collect_nearby_entities(entity, search_radius)
    local rings = {}
    for index = 1, profile.ring_count do
        rings[index] = new_ring()
    end

    local weights = build_primary_layers(rings, profile, rupture, style, fire_name, class_bias, visual_radius, surface_context, effect_settings)
    build_secondary_layers(rings, profile, rupture, rupture.dominant.family, class_bias, visual_radius, weights, surface_context, effect_settings)

    local damage_rings = build_damage_rings(entity, nearby_entities, profile.ring_count, explosion_radius, explosion_damage)
    for index = 1, profile.ring_count do
        rings[index].damage_victims = damage_rings[index]
    end

    local seen_platform_tiles = {}
    if surface_context.is_platform and effect_settings.allow_platform_tile_damage ~= false then
        add_entity_platform_tile_damage(rings[1], seen_platform_tiles, entity, platform_source_tile_damage)
        if effect_settings.allow_fire ~= false and not is_pipeline_entity(entity, effect_settings) then
            add_layer(rings[1], "fire_layers", {
                name = fire_name,
                count = math.max(1, math.min(3, math.ceil(entity_radius * 0.75))),
                emitter = "vogel",
                inner_radius = 0,
                outer_radius = math.max(0.35, math.min(entity_radius, 1.1)),
                force_name = "neutral",
            })
        end
    end

    add_pipeline_fire_layers(
        rings,
        entity,
        nearby_entities,
        fire_name,
        profile,
        surface_context,
        explosion_radius,
        search_radius,
        entity_radius,
        seen_platform_tiles,
        platform_pipe_tile_damage,
        effect_settings,
        style
    )

    return {
        mode = profile.mode,
        damage_type = style.damage_type,
        source_force_name = source_force_name,
        surface_index = entity.surface.index,
        surface_kind = surface_context.is_platform and "platform" or "planetary",
        pollution_enabled = surface_context.has_pollutant,
        position = {x = entity.position.x, y = entity.position.y},
        ring_count = profile.ring_count,
        rings = rings,
        child_jobs = build_pair_child_jobs(entity, style, source_force_name, fire_name, platform_pipe_tile_damage, explosion_damage, profile.mode, surface_context, effect_settings),
    }
end

local function build_vent_job(entity, spec)
    local style = get_effect_style(spec) or EFFECT_STYLES.cryo
    local carrier_class = spec.carrier_class or "line"
    local ring_count = carrier_class == "vessel" and 3 or 2
    local smoke_count = carrier_class == "vessel" and 18 or 10
    local outer_radius = carrier_class == "vessel" and 2.4 or 1.35
    local rings = {}

    for index = 1, ring_count do
        rings[index] = new_ring()
    end

    local weights = build_ring_weights(ring_count)
    add_distributed_layers(rings, smoke_count, weights.smoke, "smoke_layers", style.smoke_name, "vogel", outer_radius)
    add_distributed_layers(rings, math.max(2, math.floor(smoke_count * 0.35)), weights.smoke, "smoke_layers", style.smoke_name, "rim", outer_radius * 1.1)

    return {
        mode = rupture_scheduler.get_fidelity_profile(outer_radius).mode,
        damage_type = style.damage_type,
        source_force_name = spec.source_force_name or (entity.force and entity.force.name) or "neutral",
        surface_index = entity.surface.index,
        surface_kind = entity.surface and entity.surface.platform and "platform" or "planetary",
        pollution_enabled = false,
        position = {x = entity.position.x, y = entity.position.y},
        ring_count = ring_count,
        rings = rings,
        child_jobs = {},
    }
end

function model.queue_effect(entity, spec, tick)
    if not (entity and entity.valid and spec and spec.effect_family) then
        return false
    end

    local style = get_effect_style(spec)
    if not style then
        return false
    end

    local rupture = spec.rupture or build_effect_rupture(spec)
    local class_bias = get_entity_class_bias(entity, spec.carrier_class)
    local rupture_job = build_effect_job(entity, rupture, style, class_bias, spec)
    maybe_spawn_ground_overlay(entity, get_surface_context(entity.surface), style, spec)
    local pollution_amount = spec.pollution_amount
    if pollution_amount == nil and rupture.total_pollution then
        pollution_amount = rupture.total_pollution / 10
    end

    apply_rupture_pollution(entity.surface, entity.position, pollution_amount)
    rupture_scheduler.begin_rupture(rupture_job, tick or (game and game.tick) or 0)
    return true
end

function model.queue_vent(entity, spec, tick)
    if not (entity and entity.valid and spec) then
        return false
    end

    spec = shallow_copy(spec)
    spec.effect_family = spec.effect_family or "cryo"
    local rupture_job = build_vent_job(entity, spec)
    rupture_scheduler.begin_rupture(rupture_job, tick or (game and game.tick) or 0)
    return true
end

return model
