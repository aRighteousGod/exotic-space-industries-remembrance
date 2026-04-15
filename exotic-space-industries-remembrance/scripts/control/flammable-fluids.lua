--==============================================================================
-- ESIR FILE MAP
-- owns: flammable fluid death analysis and rupture job construction
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: on_entity_died only
-- forwarded_events: on_entity_died
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime prototype changes
--==============================================================================

local rupture_scheduler = require("scripts/control/flammable-rupture-scheduler")

local model = {}

local DAMAGE_TYPE_CHANCES = {
    physical = 0.95,
    impact = 0.95,
    poison = 0.45,
    explosion = 0.75,
    fire = 0.95,
    laser = 0.5,
    acid = 0.5,
    electric = 0.5,
    toxic = 0.45,
    ["sore-acid"] = 0.55,
    cold = 0.35,
    ["ei-plasma"] = 0.95,
    script = 1,
}

local DAMAGE_TYPE_HINT_CHANCES = {
    {hint = "plasma", chance = DAMAGE_TYPE_CHANCES["ei-plasma"]},
    {hint = "tesla", chance = DAMAGE_TYPE_CHANCES.electric},
    {hint = "electric", chance = DAMAGE_TYPE_CHANCES.electric},
    {hint = "sore-acid", chance = DAMAGE_TYPE_CHANCES["sore-acid"]},
    {hint = "acid", chance = DAMAGE_TYPE_CHANCES.acid},
    {hint = "toxic", chance = DAMAGE_TYPE_CHANCES.toxic},
    {hint = "poison", chance = DAMAGE_TYPE_CHANCES.poison},
    {hint = "cold", chance = DAMAGE_TYPE_CHANCES.cold},
    {hint = "fire", chance = DAMAGE_TYPE_CHANCES.fire},
    {hint = "laser", chance = DAMAGE_TYPE_CHANCES.laser},
    {hint = "explosion", chance = DAMAGE_TYPE_CHANCES.explosion},
    {hint = "impact", chance = DAMAGE_TYPE_CHANCES.impact},
    {hint = "physical", chance = DAMAGE_TYPE_CHANCES.physical},
}

local NON_FLAMMABLE_FLUIDS = {
    ["ei-liquid-nitrogen"] = true,
}

local OIL_FAMILY_HINTS = {
    "crude",
    "oil",
    "petroleum",
    "diesel",
    "kerosene",
    "destilate",
    "distill",
    "benzol",
    "fuel",
    "naptha",
    "naphtha",
    "tar",
}

local EXOTIC_FAMILY_HINTS = {
    "morphium",
    "phytho",
    "coolant",
    "fusion",
    "critical-steam",
    "drill-fluid",
    "cryoflux",
    "plasma",
    "antimatter",
    "quantum",
    "singularity",
    "protium",
    "deuterium",
    "tritium",
}

local RUPTURE_FAMILIES = {
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
    },
}

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
local PLATFORM_TILE_DAMAGE_FAMILY_MULT = {
    oil = 1.00,
    gas = 1.18,
    exotic = 1.08,
}

local function get_damage_type_name(event)
    if event and event.damage_type and event.damage_type.name then
        return event.damage_type.name
    end
    return "script"
end

local function get_damage_gate_chance(damage_type_name)
    local chance = DAMAGE_TYPE_CHANCES[damage_type_name]
    if chance then
        return chance
    end

    local lowered = damage_type_name and string.lower(damage_type_name) or nil
    if not lowered then
        return nil
    end

    for _, hint in ipairs(DAMAGE_TYPE_HINT_CHANCES) do
        if string.find(lowered, hint.hint, 1, true) then
            return hint.chance
        end
    end

    return nil
end

local function passes_damage_gate(event)
    local chance = get_damage_gate_chance(get_damage_type_name(event))
    return chance and chance > 0 and math.random() <= chance
end

local function name_has_hint(name, hints)
    for _, hint in ipairs(hints) do
        if string.find(name, hint, 1, true) then
            return true
        end
    end
    return false
end

local function is_flammable_fluid(fluid)
    return fluid and not NON_FLAMMABLE_FLUIDS[fluid.name] and (fluid.fuel_value or 0) > 0
end

local function is_gas_fluid(fluid)
    if not fluid then
        return false
    end

    if fluid.default_temperature and fluid.gas_temperature and fluid.default_temperature >= fluid.gas_temperature then
        return true
    end

    local name = fluid.name or ""
    return (not string.find(name, "gasoline", 1, true))
        and (
            string.find(name, "-gas", 1, true) ~= nil
            or string.find(name, "gas-", 1, true) ~= nil
            or string.find(name, " steam", 1, true) ~= nil
            or string.find(name, "-steam", 1, true) ~= nil
            or name == "steam"
        )
end

local function classify_fluid_family(fluid)
    if not fluid then
        return "oil"
    end

    local name = fluid.name or ""
    if name_has_hint(name, EXOTIC_FAMILY_HINTS) then
        return "exotic"
    end
    if is_gas_fluid(fluid) then
        return "gas"
    end
    if name_has_hint(name, OIL_FAMILY_HINTS) then
        return "oil"
    end
    if string.sub(name, 1, 3) == "ei-" then
        return "exotic"
    end
    return "oil"
end

local function get_entity_radius(entity)
    local box = entity.bounding_box
    if not box then
        return 0.5
    end

    local pos = entity.position
    return 0.5 * ((box.right_bottom.x - pos.x) + (box.right_bottom.y - pos.y))
end

local function get_entity_class_bias(entity)
    if not entity or not entity.valid then
        return {visual_scale = 1, smoke_scale = 1, scorch_scale = 1, stage_scale = 1, shockwave_scale = 1}
    end

    local entity_type = entity.type
    if entity_type == "storage-tank" or entity_type == "fluid-wagon" then
        return {visual_scale = 1.70, smoke_scale = 1.60, scorch_scale = 1.45, stage_scale = 1.60, shockwave_scale = 1.45}
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

    return {visual_scale = 1, smoke_scale = 1, scorch_scale = 1, stage_scale = 1, shockwave_scale = 1}
end

local function analyze_fluidboxes(entity)
    local fluidbox = entity.fluidbox
    if not fluidbox or #fluidbox <= 0 then
        return nil
    end

    local total_energy_mj = 0
    local total_pollution = 0
    local family_energy_mj = {oil = 0, gas = 0, exotic = 0}
    local per_fluid_energy = {}

    for index = 1, #fluidbox do
        local contents = fluidbox[index]
        if contents and contents.name and contents.amount and contents.amount > 0 then
            local fluid = prototypes.fluid[contents.name]
            if is_flammable_fluid(fluid) then
                local fuel_value = fluid.fuel_value or 0
                local energy_mj = (fuel_value * contents.amount) / 1000000
                if energy_mj > 0 then
                    local family = classify_fluid_family(fluid)
                    total_energy_mj = total_energy_mj + energy_mj
                    family_energy_mj[family] = family_energy_mj[family] + energy_mj
                    total_pollution = total_pollution + (((fuel_value / 1800000) * 0.5 * (fluid.emissions_multiplier or 1) * contents.amount) / 1.5)

                    local fluid_total = per_fluid_energy[fluid.name] or {
                        fluid_name = fluid.name,
                        family = family,
                        is_gas = is_gas_fluid(fluid),
                        energy_mj = 0,
                    }
                    fluid_total.energy_mj = fluid_total.energy_mj + energy_mj
                    per_fluid_energy[fluid.name] = fluid_total
                end
            end
        end
    end

    local dominant = nil
    for _, fluid_total in pairs(per_fluid_energy) do
        if not dominant or fluid_total.energy_mj > dominant.energy_mj then
            dominant = fluid_total
        end
    end

    if total_energy_mj <= ENERGY_THRESHOLD_MJ or not dominant then
        return nil
    end

    local family_share = {}
    for family, energy_mj in pairs(family_energy_mj) do
        family_share[family] = energy_mj / total_energy_mj
    end

    return {
        total_energy_mj = total_energy_mj,
        total_pollution = total_pollution,
        family_share = family_share,
        dominant = dominant,
    }
end

local function get_ranked_family_mix(rupture)
    local ranked = {}
    for family, share in pairs(rupture.family_share) do
        if share and share > 0 then
            ranked[#ranked + 1] = {family = family, share = share}
        end
    end
    table.sort(ranked, function(left, right) return left.share > right.share end)
    return ranked
end

local function get_explosion_metrics(total_energy_mj)
    local scaled_energy = math.max(0, total_energy_mj * 10)
    return RADIUS_MULT * math.pow(scaled_energy, RADIUS_POWER), DAMAGE_MULT * math.pow(scaled_energy, DAMAGE_POWER)
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
        for index = 1, #(weights or {}) do distribution[index] = 0 end
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

local function is_pipeline_entity(entity)
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

local function get_connection_step_distance(source, target)
    local dx = target.position.x - source.position.x
    local dy = target.position.y - source.position.y
    return math.sqrt((dx * dx) + (dy * dy))
end

local function get_connected_fluid_owners(entity)
    local owners = {}
    local seen = {}
    local fluidbox = entity and entity.valid and entity.fluidbox or nil
    if not fluidbox or #fluidbox <= 0 then
        return owners
    end

    for index = 1, #fluidbox do
        local ok, connections = pcall(function()
            return entity.fluidbox.get_connections(index)
        end)

        if ok and connections then
            for _, connection in pairs(connections) do
                local owner = connection and connection.owner
                local key = get_entity_visit_key(owner)
                if owner and owner.valid and owner ~= entity and key and not seen[key] then
                    seen[key] = true
                    owners[#owners + 1] = owner
                end
            end
        end
    end

    return owners
end

local function get_pipeline_traversal_visit_cap(profile, fire_cap)
    if fire_cap then
        return math.max(PIPELINE_TRAVERSAL_MIN_VISITS, fire_cap * PIPELINE_TRAVERSAL_VISIT_MULT)
    end

    if profile.mode == "unbounded" then
        return PIPELINE_TRAVERSAL_UNBOUNDED_VISITS
    end

    return PIPELINE_TRAVERSAL_MIN_VISITS
end

local function collect_local_pipeline_fire_targets(entity, fire_radius, profile)
    local targets = {}
    local seen = {}
    local fire_cap = get_pipeline_fire_cap(profile.mode)

    local function add_target(target, distance)
        local key = get_entity_visit_key(target)
        if not key or seen[key] then
            return
        end

        seen[key] = true
        targets[#targets + 1] = {
            distance = distance,
            position = copy_position(target.position),
        }
    end

    if is_pipeline_entity(entity) then
        add_target(entity, 0)
    end

    for _, target in ipairs(entity.surface.find_entities_filtered{position = entity.position, radius = fire_radius}) do
        if target ~= entity and is_pipeline_entity(target) then
            local distance = get_connection_step_distance(entity, target)
            if distance <= fire_radius then
                add_target(target, distance)
            end
        end
    end

    table.sort(targets, function(left, right) return left.distance < right.distance end)

    while fire_cap and #targets > fire_cap do
        targets[#targets] = nil
    end

    return targets
end

local function collect_pipeline_fire_targets(entity, fire_radius, profile)
    local targets = {}
    local fire_cap = get_pipeline_fire_cap(profile.mode)
    local visit_cap = get_pipeline_traversal_visit_cap(profile, fire_cap)
    local visited = {}
    local queue = {}
    local queue_index = 1
    local visited_count = 0

    local function enqueue(target, path_distance)
        local key = get_entity_visit_key(target)
        if not key or visited[key] then
            return false
        end

        visited[key] = true
        visited_count = visited_count + 1
        queue[#queue + 1] = {entity = target, path_distance = path_distance}

        if is_pipeline_entity(target) then
            targets[#targets + 1] = {
                distance = path_distance,
                position = copy_position(target.position),
            }
        end

        return true
    end

    enqueue(entity, 0)

    while queue_index <= #queue and visited_count < visit_cap do
        local current = queue[queue_index]
        queue_index = queue_index + 1

        for _, owner in ipairs(get_connected_fluid_owners(current.entity)) do
            if owner.valid then
                local next_distance = current.path_distance + get_connection_step_distance(current.entity, owner)
                local owner_budget = fire_radius + get_entity_radius(owner)
                if next_distance <= owner_budget then
                    enqueue(owner, next_distance)
                end
            end
        end
    end

    table.sort(targets, function(left, right) return left.distance < right.distance end)

    while fire_cap and #targets > fire_cap do
        targets[#targets] = nil
    end

    if #targets == 0 then
        return collect_local_pipeline_fire_targets(entity, fire_radius, profile)
    end

    return targets
end

local function add_pipeline_fire_layers(rings, entity, style, profile, surface_context, explosion_radius, search_radius, entity_radius, seen_platform_tiles, platform_pipe_tile_damage)
    local fire_name = get_platform_fire_name(style, surface_context)
    if not fire_name or #rings == 0 then
        return
    end

    local fire_radius = get_pipeline_fire_radius(search_radius, explosion_radius, entity_radius)
    if fire_radius <= 0 then
        return
    end

    local targets = collect_pipeline_fire_targets(entity, fire_radius, profile)
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

        if surface_context.is_platform then
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
    for _, mix in ipairs(get_ranked_family_mix(rupture)) do
        if mix.family ~= primary_family and mix.share >= threshold then
            selected[#selected + 1] = mix
            if #selected >= limit then
                break
            end
        end
    end
    return selected
end

local function build_damage_rings(entity, ring_count, search_radius, explosion_radius, explosion_damage)
    local damage_rings = {}
    for index = 1, ring_count do damage_rings[index] = {} end
    if explosion_radius <= 0 or explosion_damage <= 0 then return damage_rings end

    for _, victim in ipairs(entity.surface.find_entities_filtered{position = entity.position, radius = search_radius}) do
        if victim ~= entity and victim.valid and ei_lib.entity_can_take_health_damage(victim) then
            local dx = victim.position.x - entity.position.x
            local dy = victim.position.y - entity.position.y
            local distance_sq = (dx * dx) + (dy * dy)
            local distance = math.sqrt(distance_sq)
            local victim_radius = get_entity_radius(victim)
            local effective_distance = math.max(0, distance - victim_radius)
            if effective_distance <= explosion_radius then
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

local function build_pair_child_jobs(entity, style, explosion_damage, mode, surface_context)
    if entity.type ~= "pipe-to-ground" or not entity.neighbours then
        return {}
    end

    for _, neighbour_group in pairs(entity.neighbours) do
        if neighbour_group and neighbour_group.object_name == "LuaEntity" then
            neighbour_group = {neighbour_group}
        end

        if type(neighbour_group) == "table" then
            for _, neighbour in pairs(neighbour_group) do
                if neighbour and neighbour.valid and neighbour.type == "pipe-to-ground" then
                    local ring = {
                        center_entities = {{name = style.pair_explosion_name}},
                        entity_layers = {},
                        smoke_layers = {{name = style.smoke_name, count = 1, emitter = "center", inner_radius = 0, outer_radius = 0}},
                        fire_layers = {{
                            name = get_platform_fire_name(style, surface_context),
                            count = 1,
                            emitter = "center",
                            inner_radius = 0,
                            outer_radius = 0,
                            force_name = "neutral",
                        }},
                        scorch_layers = {},
                        damage_victims = {{entity = neighbour, damage = explosion_damage}},
                        platform_tile_damage = {},
                    }

                    if surface_context.is_platform then
                        local seen_tiles = {}
                        add_platform_tile_damage(ring, seen_tiles, neighbour.position, get_platform_tile_damage(style, explosion_damage, true))
                    end

                    return {{
                        mode = mode,
                        damage_type = style.damage_type,
                        source_force_name = entity.force and entity.force.name or "neutral",
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

local function build_primary_layers(rings, profile, rupture, style, class_bias, visual_radius, surface_context)
    local total_energy_mj = rupture.total_energy_mj
    local gas_share = rupture.family_share.gas or 0
    local energy_root = math.sqrt(total_energy_mj)
    local weights = build_ring_weights(#rings)
    local effect_visual_radius = surface_context.is_platform and math.max(visual_radius * PLATFORM_VISUAL_RADIUS_MULT, 0.45) or visual_radius
    local outer_radius = math.max(effect_visual_radius * (1.05 + (0.08 * class_bias.shockwave_scale)), 0.8)
    local shock_base = math.max(1, math.ceil((visual_radius + (energy_root * 0.055)) * style.ring_bias * class_bias.stage_scale))
    local shock_extra = total_energy_mj >= 220 or class_bias.stage_scale >= 1.35
    local fire_name = get_platform_fire_name(style, surface_context)

    local explosion_entries = {
        {key = "cluster_medium", count = math.max(1, math.ceil((visual_radius + (energy_root * 0.045)) * style.explosion_bias * class_bias.stage_scale))},
        {key = "cluster_big", count = math.max(0, math.floor(energy_root * (0.12 + (gas_share * 0.35)) * style.explosion_bias * class_bias.visual_scale))},
        {key = "shock_big", count = shock_base},
        {key = "shock_medium", count = shock_extra and math.max(1, math.ceil(shock_base * 0.8)) or 0},
    }
    local fire_entries = {
        {key = "core", count = math.max(1, math.ceil(((visual_radius * visual_radius) + energy_root) * style.fire_bias * class_bias.visual_scale))},
        {key = "rim", count = math.max(1, math.ceil(((visual_radius * 2) + math.sqrt(total_energy_mj * 0.5)) * style.fire_bias * class_bias.visual_scale * 0.75))},
    }
    local smoke_base = math.max(2, math.ceil(((visual_radius * 1.8) + (energy_root * 0.11)) * style.smoke_bias * class_bias.smoke_scale))
    local smoke_entries = {
        {key = "core", count = smoke_base},
        {key = "rim", count = math.max(1, math.ceil(smoke_base * 0.45))},
        {key = "shock", count = math.max(2, math.ceil(shock_base * (0.85 + (style.shockwave_bias * 0.2))))},
        {key = "shock_extra", count = shock_extra and math.max(2, math.ceil(math.max(2, math.ceil(shock_base * (0.85 + (style.shockwave_bias * 0.2)))) * 0.6)) or 0},
    }
    local scorch_entries = total_energy_mj >= SCORCH_THRESHOLD_MJ and {
        {key = "core", count = math.max(1, math.ceil(((visual_radius * 1.2) + (energy_root * 0.05)) * style.scorch_bias * class_bias.scorch_scale))},
        {key = "rim", count = visual_radius >= 1.2 and math.max(1, math.floor(math.max(1, math.ceil(((visual_radius * 1.2) + (energy_root * 0.05)) * style.scorch_bias * class_bias.scorch_scale)) * 0.5)) or 0},
    } or {}

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
    if surface_context.is_platform then
        massive_count = math.min(massive_count, PLATFORM_MASSIVE_CAP)
    end
    if profile.massive_cap ~= nil then
        massive_count = math.min(massive_count, profile.massive_cap)
    end

    rings[1].center_entities[#rings[1].center_entities + 1] = {name = effect_visual_radius <= 1 and "explosion" or "medium-explosion"}
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

    return weights
end

local function build_secondary_layers(rings, profile, rupture, primary_family, class_bias, visual_radius, weights, surface_context)
    for _, mix in ipairs(select_secondary_mix(rupture, primary_family, profile)) do
        local secondary_style = RUPTURE_FAMILIES[mix.family]
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
        elseif not surface_context.is_platform then
            local fire_scale = secondary_style.fire_bias * 0.45 * class_bias.visual_scale
            local fire_radius = math.max(scaled_radius * 0.72, 0.35)
            local fire_core = math.max(1, math.ceil(((fire_radius * fire_radius) + math.sqrt(scaled_energy * 0.32)) * fire_scale))
            local fire_rim = math.max(1, math.ceil(((fire_radius * 2) + math.sqrt((scaled_energy * 0.32) * 0.5)) * fire_scale * 0.75))
            add_distributed_layers(rings, fire_core, weights.accent, "fire_layers", fire_name, "vogel", fire_radius, "neutral")
            add_distributed_layers(rings, fire_rim, weights.accent, "fire_layers", fire_name, "rim", math.max(fire_radius * 1.08, 0.45), "neutral")
        end
    end
end

local function build_rupture_job(entity, rupture, style, class_bias, surface_context, explosion_radius, explosion_damage, visual_radius, search_radius)
    local profile = rupture_scheduler.get_fidelity_profile(visual_radius)
    local rings = {}
    for index = 1, profile.ring_count do rings[index] = new_ring() end

    local weights = build_primary_layers(rings, profile, rupture, style, class_bias, visual_radius, surface_context)
    build_secondary_layers(rings, profile, rupture, rupture.dominant.family, class_bias, visual_radius, weights, surface_context)

    local damage_rings = build_damage_rings(entity, profile.ring_count, search_radius, explosion_radius, explosion_damage)
    for index = 1, profile.ring_count do
        rings[index].damage_victims = damage_rings[index]
    end

    local seen_platform_tiles = {}
    if surface_context.is_platform then
        add_entity_platform_tile_damage(rings[1], seen_platform_tiles, entity, get_platform_tile_damage(style, explosion_damage, false))
        if not is_pipeline_entity(entity) then
            add_layer(rings[1], "fire_layers", {
                name = get_platform_fire_name(style, surface_context),
                count = math.max(1, math.min(3, math.ceil(get_entity_radius(entity) * 0.75))),
                emitter = "vogel",
                inner_radius = 0,
                outer_radius = math.max(0.35, math.min(get_entity_radius(entity), 1.1)),
                force_name = "neutral",
            })
        end
    end

    add_pipeline_fire_layers(
        rings,
        entity,
        style,
        profile,
        surface_context,
        explosion_radius,
        search_radius,
        get_entity_radius(entity),
        seen_platform_tiles,
        get_platform_tile_damage(style, explosion_damage, true)
    )

    return {
        mode = profile.mode,
        damage_type = style.damage_type,
        source_force_name = entity.force and entity.force.name or "neutral",
        surface_index = entity.surface.index,
        surface_kind = surface_context.is_platform and "platform" or "planetary",
        pollution_enabled = surface_context.has_pollutant,
        position = {x = entity.position.x, y = entity.position.y},
        ring_count = profile.ring_count,
        rings = rings,
        child_jobs = build_pair_child_jobs(entity, style, explosion_damage, profile.mode, surface_context),
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

function model.on_entity_died(event)
    local entity = event and event.entity
    if not entity or not entity.valid or entity.type == "pump" then
        return
    end
    if not passes_damage_gate(event) then
        return
    end

    local rupture = analyze_fluidboxes(entity)
    if not rupture then
        return
    end

    local style = RUPTURE_FAMILIES[rupture.dominant.family] or RUPTURE_FAMILIES.oil
    local class_bias = get_entity_class_bias(entity)
    local surface_context = get_surface_context(entity.surface)
    local explosion_radius, explosion_damage = get_explosion_metrics(rupture.total_energy_mj)
    local entity_radius = get_entity_radius(entity)
    local visual_radius = math.max(explosion_radius, entity_radius) * class_bias.visual_scale
    local search_radius = explosion_radius + entity_radius + DAMAGE_SEARCH_PADDING
    local rupture_job = build_rupture_job(entity, rupture, style, class_bias, surface_context, explosion_radius, explosion_damage, visual_radius, search_radius)

    apply_rupture_pollution(entity.surface, entity.position, rupture.total_pollution / 10)
    rupture_scheduler.begin_rupture(rupture_job, event.tick or (game and game.tick) or 0)
end

return model
