local util = require("util")
local explosion_animations = require("__base__.prototypes.entity.explosion-animations")
local particle_animations = require("__base__.prototypes.particle-animations")
local sounds = require("__base__.prototypes.entity.sounds")

local entity_types = {
  "accumulator",
  "agricultural-tower",
  "ammo-turret",
  "arithmetic-combinator",
  "artillery-turret",
  "assembling-machine",
  "beacon",
  "boiler",
  "burner-generator",
  "cargo-wagon",
  "constant-combinator",
  "construction-robot",
  "container",
  "decider-combinator",
  "display-panel",
  "electric-energy-interface",
  "electric-pole",
  "electric-turret",
  "fluid-turret",
  "fluid-wagon",
  "furnace",
  "gate",
  "generator",
  "heat-interface",
  "heat-pipe",
  "inserter",
  "lab",
  "lamp",
  "loader-1x1",
  "locomotive",
  "logistic-container",
  "logistic-robot",
  "mining-drill",
  "offshore-pump",
  "pipe",
  "pipe-to-ground",
  "pump",
  "radar",
  "reactor",
  "roboport",
  "rocket-silo",
  "solar-panel",
  "splitter",
  "storage-tank",
  "transport-belt",
  "underground-belt",
  "wall",
}

local owned_prefixes = {
  "ei-",
  "ei_",
}

local helper_exact = {
  ["ei-gate"] = true,
  ["ei-auric-inoculation-vat"] = true,
}

local exact_effect_assignments = {
  "ei-auric-inoculation-vat",
}

local helper_prefixes = {
  "ei-induction-matrix-core-",
}

local dependency_exact_inclusions = {
  ["accumulator"] = true,
  ["plated-wall"] = true,
  ["solar-panel"] = true,
  ["tough-wall"] = true,
  ["zeus-wrath-zeus-turret"] = true,
}

local dependency_prefix_inclusions = {
  "rp-steam-",
}

local micro_types = {
  ["construction-robot"] = true,
  ["electric-pole"] = true,
  ["gate"] = true,
  ["heat-pipe"] = true,
  ["inserter"] = true,
  ["loader-1x1"] = true,
  ["logistic-robot"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["splitter"] = true,
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["wall"] = true,
}

local bucket_data = {
  micro = {
    count_scale = 0.45,
    spread_scale = 0.45,
    animation_scale = 0.58,
    light_size = 18,
    smoke_count = 0,
  },
  small = {
    count_scale = 0.85,
    spread_scale = 0.85,
    animation_scale = 0.78,
    light_size = 30,
    smoke_count = 2,
  },
  medium = {
    count_scale = 1.00,
    spread_scale = 1.00,
    animation_scale = 1.00,
    light_size = 42,
    smoke_count = 3,
  },
  large = {
    count_scale = 1.35,
    spread_scale = 1.25,
    animation_scale = 1.18,
    light_size = 58,
    smoke_count = 4,
  },
  huge = {
    count_scale = 1.75,
    spread_scale = 1.55,
    animation_scale = 1.38,
    light_size = 82,
    smoke_count = 5,
  },
}

local family_order = {
  "tank",
  "mechanical",
  "combustion",
  "steam",
  "electric-industrial",
  "electric-logistics",
  "signal",
  "ballistic",
  "chemical",
  "quantum",
  "alien",
  "cosmic",
  "fortified",
}

local family_assignments = {
  tank = {
    "ei-tank-1",
    "ei-tank-2",
    "ei-tank-3",
    "ei-insulated-tank",
  },
  mechanical = {
    "ei-mechanical-inserter",
    "ei-mechanical-long-inserter",
    "ei-stone-well-pump",
  },
  combustion = {
    "ei-camp-fire",
    "ei-coke-furnace",
    "ei-combustion-turbine",
    "ei-fueler",
    "ei-steampunk-lamp",
  },
  steam = {
    "ei-basic-heat-exchanger",
    "ei-basic-heat-pipe",
    "ei-big-turbine",
    "ei-deep-drill",
    "ei-destill-tower",
    "ei-fluid-boiler",
    "ei-fluid-heater",
    "ei-heat-steel-furnace",
  },
  ["electric-industrial"] = {
    "accumulator",
    "ei-advanced-centrifuge",
    "ei-advanced-chem-plant",
    "ei-advanced-deep-drill",
    "ei-advanced-destill-tower",
    "ei-advanced-electric-mining-drill",
    "ei-advanced-port",
    "ei-advanced-refinery",
    "ei-arc-furnace",
    "ei-bio-chamber",
    "ei-bio-reactor",
    "ei-castor",
    "ei-caster",
    "ei-cooler",
    "ei-electric-quarry",
    "ei-electric-surface-harvester",
    "ei-exchanger",
    "ei-grower",
    "ei-heat-chemical-plant",
    "elevated-pipe",
    "ei-insulated-pipe",
    "ei-insulated-underground-pipe",
    "ei-lufter",
    "ei-purifier",
    "ei-solar-panel-2",
    "ei-thermal-furnace",
    "ei-waver-factory",
    "solar-panel",
  },
  ["electric-logistics"] = {
    "ei-advanced-cargo-wagon",
    "ei-advanced-construction-bot",
    "ei-advanced-logistic-bot",
    "ei-cargo-bot",
    "ei-construction-bot",
    "ei-express-loader",
    "ei-fast-loader",
    "ei-kr-advanced-loader",
    "ei-loader",
    "ei-loader-base",
    "ei-military-loader",
    "ei-turbo-loader",
  },
  signal = {
    "ei-big-lab",
    "ei-computer-core",
    "ei-copper-beacon",
    "ei-data-pipe",
    "ei-energy-extractor-pylon",
    "ei-energy-injector-pylon",
    "ei-fission-facility",
    "ei-high-temperature-reactor",
    "ei-orbital-combinator",
  },
  ballistic = {
    "ei-auto-shotgun-turret",
    "ei-cannon-turret",
    "ei-cannon-turret-mk1",
    "ei-gatling-turret",
    "ei-shotgun-turret",
  },
  chemical = {
    "ei-acidthrower-turret",
  },
  quantum = {
    "ei-accelerator",
    "ei-advanced-crusher",
    "ei-excavator",
    "ei-extreme-express-loader",
    "ei-extreme-fast-loader",
    "ei-fusion-reactor",
    "ei-iron-beacon",
    "ei-kr-superior-loader",
    "ei-matter-stabilizer",
    "ei-nano-factory",
    "ei-nuclear-locomotive",
    "ei-plasma-heater",
    "ei-plasma-turret",
    "ei-quantum-computer",
    "ei-severance-array",
    "ei-solar-panel-3",
    "ei-superior-electric-mining-drill",
    "ei-ultimate-nova-loader",
    "ei-ultra-express-loader",
    "ei-ultra-fast-loader",
    "ei_charger",
    "ei_em-cargo-wagon",
    "ei_em-fluid-wagon",
    "ei_em-locomotive",
    "ei_extreme-loader",
    "ei_high-speed-loader",
    "ei_ultimate-loader",
    "zeus-wrath-zeus-turret",
  },
  alien = {
    "ei-alien-beacon",
    "ei-alien-stabilizer",
    "ei-crystal-accumulator",
    "ei-crystal-accumulator-gaia",
    "ei-farstation",
    "ei-gaia-pump",
    "ei-gate-receiver",
    "ei-rift-stabilizer",
    "ei-warp-beacon",
  },
  cosmic = {
    "ei-black-hole",
    "ei-exotic-assembler",
    "ei-gate-container",
    "ei-small-simulator",
  },
  fortified = {
    "plated-wall",
    "tough-wall",
  },
}

local family_prefixes = {
  combustion = {
    "ei-burner-",
  },
  steam = {
    "ei-steam-",
    "rp-steam-",
  },
  ["electric-industrial"] = {
  },
  signal = {
    "ei-1x1-container",
    "ei-2x2-container",
    "ei-6x6-container",
    "ei-induction-matrix",
  },
  quantum = {
    "ei-5dim-mk",
    "ei-neo-",
  },
  alien = {
    "ei-alien-beacon_off-",
    "ei-crystal-accumulator_off-",
    "ei-farstation_off-",
  },
  cosmic = {
    "ei-holo-",
  },
}

local function remove_entry(list, value)
  if not list then
    return
  end

  for index, entry in pairs(list) do
    if entry == value then
      list[index] = nil
    end
  end
end

if not mods["Accumulator-V2"] then
  remove_entry(family_assignments["electric-industrial"], "accumulator")
end

if not mods["SolarMatrix"] then
  remove_entry(family_assignments["electric-industrial"], "solar-panel")
end

if not mods["enhanced-walls"] then
  family_assignments["fortified"] = {}
end

if not mods["zeus-wrath"] then
  remove_entry(family_assignments["quantum"], "zeus-wrath-zeus-turret")
end

if not mods["castra"] then
  remove_entry(family_assignments["electric-logistics"], "ei-military-loader")
end

if not mods["Krastorio2"] then
  remove_entry(family_assignments["electric-logistics"], "ei-kr-advanced-loader")
end

if not (mods["Krastorio2"] or mods["Krastorio2-spaced-out"]) then
  remove_entry(family_assignments["quantum"], "ei-kr-superior-loader")
end

if not mods["AdvancedBeltsSA"] then
  remove_entry(family_assignments["quantum"], "ei_extreme-loader")
  remove_entry(family_assignments["quantum"], "ei_high-speed-loader")
  remove_entry(family_assignments["quantum"], "ei_ultimate-loader")
end

if not (mods["NovasUltimateBelts"] or mods["UltimateBeltsSpaceAge"] or mods["UltimateBeltsSpaceAgeFork"]) then
  remove_entry(family_assignments["quantum"], "ei-extreme-express-loader")
  remove_entry(family_assignments["quantum"], "ei-extreme-fast-loader")
  remove_entry(family_assignments["quantum"], "ei-ultimate-nova-loader")
  remove_entry(family_assignments["quantum"], "ei-ultra-express-loader")
  remove_entry(family_assignments["quantum"], "ei-ultra-fast-loader")
end

if not mods["5dim_transport"] then
  remove_entry(family_prefixes["quantum"], "ei-5dim-mk")
end

if not mods["rp_steam_roboports"] then
  remove_entry(family_prefixes["steam"], "rp-steam-")
end

local family_colors = {
  tank = { r = 1.00, g = 0.66, b = 0.34 },
  mechanical = { r = 0.78, g = 0.82, b = 0.88 },
  combustion = { r = 1.00, g = 0.56, b = 0.28 },
  steam = { r = 1.00, g = 0.78, b = 0.45 },
  ["electric-industrial"] = { r = 0.48, g = 0.82, b = 1.00 },
  ["electric-logistics"] = { r = 0.40, g = 0.72, b = 1.00 },
  signal = { r = 0.45, g = 0.78, b = 1.00 },
  ballistic = { r = 1.00, g = 0.56, b = 0.30 },
  chemical = { r = 0.62, g = 1.00, b = 0.42 },
  quantum = { r = 0.42, g = 0.92, b = 1.00 },
  alien = { r = 0.48, g = 1.00, b = 0.62 },
  cosmic = { r = 0.94, g = 0.54, b = 1.00 },
  fortified = { r = 0.76, g = 0.76, b = 0.80 },
}

local generic_dying_explosions = {
  ["accumulator-explosion"] = true,
  ["active-provider-chest-explosion"] = true,
  ["arithmetic-combinator-explosion"] = true,
  ["artillery-turret-explosion"] = true,
  ["beacon-explosion"] = true,
  ["big-explosion"] = true,
  ["boiler-explosion"] = true,
  ["buffer-chest-explosion"] = true,
  ["burner-mining-drill-explosion"] = true,
  ["chemical-plant-explosion"] = true,
  ["constant-combinator-explosion"] = true,
  ["construction-robot-explosion"] = true,
  ["decider-combinator-explosion"] = true,
  ["display-panel-explosion"] = true,
  ["electric-furnace-explosion"] = true,
  ["electric-mining-drill-explosion"] = true,
  ["flamethrower-turret-explosion"] = true,
  ["gun-turret-explosion"] = true,
  ["heat-exchanger-explosion"] = true,
  ["heat-pipe-explosion"] = true,
  ["inserter-explosion"] = true,
  ["lamp-explosion"] = true,
  ["laser-turret-explosion"] = true,
  ["logistic-robot-explosion"] = true,
  ["long-handed-inserter-explosion"] = true,
  ["massive-explosion"] = true,
  ["medium-explosion"] = true,
  ["offshore-pump-explosion"] = true,
  ["passive-provider-chest-explosion"] = true,
  ["pipe-explosion"] = true,
  ["pipe-to-ground-explosion"] = true,
  ["pump-explosion"] = true,
  ["pumpjack-explosion"] = true,
  ["radar-explosion"] = true,
  ["requester-chest-explosion"] = true,
  ["roboport-explosion"] = true,
  ["small-explosion"] = true,
  ["solar-panel-explosion"] = true,
  ["steel-furnace-explosion"] = true,
  ["stone-furnace-explosion"] = true,
  ["storage-chest-explosion"] = true,
  ["storage-tank-explosion"] = true,
  ["wall-explosion"] = true,
}

local preserved_core_explosions = {
  ["artillery-wagon-explosion"] = true,
  ["cargo-wagon-explosion"] = true,
  ["fluid-wagon-explosion"] = true,
  ["locomotive-explosion"] = true,
}

local preserve_exact = {
  ["ei-exotic-assembler"] = true,
  ["ei-steampunk-lamp"] = true,
}

local nuclear_locomotive_override_explosion_name = "ei-death-explosion-nuclear-locomotive"
local nuclear_locomotive_delay_anchor_name = "ei-death-explosion-nuclear-locomotive-delay-anchor"
local nuclear_locomotive_delayed_trigger_name = "ei-death-explosion-nuclear-locomotive-delay"

local exact_rolling_stock_overrides = {
  ["ei-nuclear-locomotive"] = nuclear_locomotive_delay_anchor_name,
}

local generated_explosions = {}
local rolling_stock_cores = {
  ["cargo-wagon"] = "cargo-wagon-explosion",
  ["fluid-wagon"] = "fluid-wagon-explosion",
  locomotive = "locomotive-explosion",
}

local function has_flag(proto, flag)
  if not proto or not proto.flags then
    return false
  end

  for _, value in pairs(proto.flags) do
    if value == flag then
      return true
    end
  end

  return false
end

local function startswith(text, prefix)
  return string.sub(text, 1, string.len(prefix)) == prefix
end

local function contains(text, needle)
  return string.find(text, needle, 1, true) ~= nil
end

local function is_owned_name(name)
  for _, prefix in pairs(owned_prefixes) do
    if startswith(name, prefix) then
      return true
    end
  end

  return false
end

local function is_helper_name(name)
  if helper_exact[name] then
    return true
  end

  for _, prefix in pairs(helper_prefixes) do
    if startswith(name, prefix) then
      return true
    end
  end

  return false
end

local function is_hidden(proto)
  return proto.hidden or has_flag(proto, "hidden")
end

local function is_placeable(proto)
  if proto.minable or proto.placeable_by then
    return true
  end

  return
    has_flag(proto, "placeable-player")
    or has_flag(proto, "placeable-neutral")
    or has_flag(proto, "placeable-off-grid")
    or has_flag(proto, "placeable-enemy")
end

local function positive_area(proto)
  local box = proto.selection_box or proto.collision_box

  if not box or not box[1] or not box[2] then
    return false
  end

  return (box[2][1] - box[1][1]) > 0 and (box[2][2] - box[1][2]) > 0
end

local function visible_candidate(name, proto)
  if not proto or is_hidden(proto) or is_helper_name(name) then
    return false
  end

  if proto.selectable_in_game == false then
    return false
  end

  if not is_placeable(proto) or not positive_area(proto) then
    return false
  end

  return true
end

local function footprint_bucket(proto, entity_type)
  if micro_types[entity_type] then
    return "micro"
  end

  local box = proto.selection_box or proto.collision_box

  if not box or not box[1] or not box[2] then
    return "medium"
  end

  local width = box[2][1] - box[1][1]
  local height = box[2][2] - box[1][2]
  local max_dimension = math.max(width, height)

  if max_dimension <= 2.2 then
    return "small"
  end

  if max_dimension <= 3.2 then
    return "medium"
  end

  if max_dimension <= 5.4 then
    return "large"
  end

  return "huge"
end

local function scaled_count(count, bucket)
  return math.max(1, math.floor((count or 1) * bucket.count_scale + 0.5))
end

local function square(area)
  return {
    { -area, -area },
    { area, area },
  }
end

local function scaled_animation(animation, scale)
  local copy = table.deepcopy(animation)

  if copy.filename or copy.stripes then
    copy.scale = (copy.scale or 1) * scale
    return copy
  end

  if copy.layers then
    for _, layer in pairs(copy.layers) do
      layer.scale = (layer.scale or 1) * scale
    end

    copy.scale = (copy.scale or 1) * scale
    return copy
  end

  for _, layer in pairs(copy) do
    if type(layer) == "table" and (layer.filename or layer.stripes or layer.layers) then
      layer.scale = (layer.scale or 1) * scale
    end
  end

  return copy
end

local function tint_animation(animation, tint)
  if type(animation) ~= "table" then
    return
  end

  if animation.filename or animation.filenames or animation.stripes then
    animation.tint = tint
  end

  for _, value in pairs(animation) do
    if type(value) == "table" then
      tint_animation(value, tint)
    end
  end
end

local function make_particle_prototype(params)
  local prototype = {
    type = "optimized-particle",
    name = params.name,
    hidden = true,
    life_time = params.life_time or 28,
    pictures = params.pictures,
    render_layer = params.render_layer or "air-object",
    render_layer_when_on_ground = params.render_layer_when_on_ground or "lower-object-above-shadow",
    movement_modifier_when_on_ground = params.movement_modifier_when_on_ground or 0,
    movement_modifier = params.movement_modifier or 1,
    vertical_acceleration = params.vertical_acceleration or -0.002,
    fade_away_duration = params.fade_away_duration or math.max(4, math.min(60, math.floor((params.life_time or 28) / 4))),
    draw_shadow_when_on_ground = false,
  }

  if params.shadows then
    prototype.shadows = params.shadows
  end

  return prototype
end

local function make_particle_burst(name, count, area, height, vertical_speed, radial_speed, bucket_key, extra)
  local bucket = bucket_data[bucket_key]
  local spread = area * bucket.spread_scale
  local burst = {
    type = "create-particle",
    particle_name = name,
    repeat_count = scaled_count(count, bucket),
    affects_target = false,
    show_in_tooltip = false,
    offset_deviation = square(spread),
    initial_height = height,
    initial_height_deviation = math.max(0.08, height * 0.6),
    initial_vertical_speed = vertical_speed,
    initial_vertical_speed_deviation = math.max(0.03, vertical_speed * 0.65),
    speed_from_center = radial_speed,
    speed_from_center_deviation = math.max(0.02, radial_speed * 0.75),
  }

  if extra then
    for key, value in pairs(extra) do
      burst[key] = value
    end
  end

  return burst
end

local function make_smoke_burst(repeat_count, area, speed, bucket_key, smoke_name)
  local bucket = bucket_data[bucket_key]
  local spread = area * bucket.spread_scale

  return {
    type = "create-trivial-smoke",
    smoke_name = smoke_name or "smoke-fast",
    initial_height = 0,
    speed_from_center = speed,
    speed_from_center_deviation = speed * 0.35,
    offset_deviation = square(spread),
    max_radius = math.max(0.4, spread * 1.25),
    repeat_count = scaled_count(repeat_count, bucket),
  }
end

local function animation_for_family(family, bucket_key)
  local scale = bucket_data[bucket_key].animation_scale

  if family == "tank" then
    if bucket_key == "micro" or bucket_key == "small" then
      return scaled_animation(explosion_animations.small_explosion(), 0.78 * scale)
    end

    if bucket_key == "medium" then
      return scaled_animation(explosion_animations.medium_explosion(), 0.88 * scale)
    end

    if bucket_key == "large" then
      return scaled_animation(explosion_animations.big_explosion(), 0.92 * scale)
    end

    return scaled_animation(explosion_animations.massive_explosion(), 0.90 * scale)
  end

  if family == "combustion" or family == "ballistic" or family == "chemical" then
    if bucket_key == "micro" or bucket_key == "small" then
      return scaled_animation(explosion_animations.small_explosion(), 0.70 * scale)
    end

    if bucket_key == "medium" then
      return scaled_animation(explosion_animations.medium_explosion(), 0.78 * scale)
    end

    if bucket_key == "large" then
      return scaled_animation(explosion_animations.big_explosion(), 0.82 * scale)
    end

    return scaled_animation(explosion_animations.massive_explosion(), 0.80 * scale)
  end

  if family == "steam" or family == "fortified" then
    return scaled_animation(explosion_animations.dust_explosion(), 0.95 * scale)
  end

  if family == "electric-industrial" then
    if bucket_key == "micro" then
      return util.empty_sprite()
    end

    if bucket_key == "small" then
      return scaled_animation(explosion_animations.small_explosion(), 0.60 * scale)
    end

    if bucket_key == "medium" then
      return scaled_animation(explosion_animations.medium_explosion(), 0.66 * scale)
    end

    return scaled_animation(explosion_animations.big_explosion(), 0.62 * scale)
  end

  return util.empty_sprite()
end

local function sound_for_family(family, bucket_key)
  if family == "tank" or family == "ballistic" or family == "chemical" then
    if bucket_key == "large" or bucket_key == "huge" then
      return sounds.large_explosion(0.65, 0.85)
    end

    return sounds.medium_explosion
  end

  if family == "combustion" or family == "fortified" then
    return sounds.medium_explosion
  end

  if family == "cosmic" then
    return sounds.large_explosion(0.55, 0.95)
  end

  return sounds.medium_explosion
end

local function effects_for_family(family, bucket_key)
  if family == "tank" then
    return {
      make_smoke_burst(8, 0.95, 0.028, bucket_key),
      make_particle_burst("storage-tank-metal-particle-big", 10, 0.48, 0.48, 0.105, 0.030, bucket_key),
      make_particle_burst("storage-tank-metal-particle-medium", 17, 0.72, 0.48, 0.118, 0.048, bucket_key),
      make_particle_burst("explosion-remnants-particle", 8, 0.92, 0.18, 0.080, 0.035, bucket_key),
      make_particle_burst("ei-death-vapor-particle", 18, 1.10, 0.08, 0.060, 0.026, bucket_key, {
        frame_speed = 0.85,
        frame_speed_deviation = 0.15,
        tail_length = 5,
        tail_length_deviation = 2,
        tail_width = 2,
        only_when_visible = true,
      }),
    }
  end

  if family == "mechanical" then
    return {
      make_particle_burst("offshore-pump-mechanical-component-particle-medium", 10, 0.48, 0.32, 0.080, 0.032, bucket_key),
      make_particle_burst("steam-engine-metal-particle-small", 12, 0.52, 0.26, 0.078, 0.032, bucket_key),
      make_particle_burst("steam-engine-metal-particle-medium", 5, 0.42, 0.32, 0.070, 0.028, bucket_key),
      make_particle_burst("cable-and-electronics-particle-small-medium", 4, 0.34, 0.28, 0.062, 0.024, bucket_key),
    }
  end

  if family == "combustion" then
    return {
      make_smoke_burst(16, 1.10, 0.032, bucket_key),
      make_particle_burst("steam-engine-metal-particle-big", 7, 0.54, 0.48, 0.090, 0.040, bucket_key),
      make_particle_burst("steam-engine-metal-particle-medium", 16, 0.85, 0.72, 0.095, 0.040, bucket_key),
      make_particle_burst("steam-engine-metal-particle-small", 18, 0.95, 0.90, 0.090, 0.050, bucket_key),
      make_particle_burst("spark-particle", 10, 0.95, 1.00, 0.020, 0.070, bucket_key, {
        frame_speed = 0.60,
        frame_speed_deviation = 0.12,
        tail_length = 8,
        tail_length_deviation = 3,
        tail_width = 3,
        only_when_visible = true,
      }),
      make_particle_burst("explosion-remnants-particle", 8, 0.84, 0.18, 0.080, 0.035, bucket_key),
    }
  end

  if family == "steam" then
    return {
      make_smoke_burst(12, 1.05, 0.030, bucket_key),
      make_particle_burst("steam-engine-metal-particle-big", 7, 0.55, 0.50, 0.085, 0.040, bucket_key),
      make_particle_burst("steam-engine-metal-particle-medium", 16, 0.85, 0.72, 0.095, 0.040, bucket_key),
      make_particle_burst("steam-engine-metal-particle-small", 18, 0.95, 0.95, 0.090, 0.050, bucket_key),
      make_particle_burst("ei-death-vapor-particle", 24, 1.20, 0.10, 0.070, 0.032, bucket_key, {
        frame_speed = 0.90,
        frame_speed_deviation = 0.20,
        tail_length = 6,
        tail_length_deviation = 2,
        tail_width = 2,
        only_when_visible = true,
      }),
      make_particle_burst("spark-particle", 6, 0.88, 0.92, 0.020, 0.060, bucket_key, {
        frame_speed = 0.58,
        frame_speed_deviation = 0.10,
        tail_length = 7,
        tail_length_deviation = 3,
        tail_width = 2,
        only_when_visible = true,
      }),
    }
  end

  if family == "electric-industrial" then
    return {
      make_particle_burst("offshore-pump-metal-particle-big", 7, 0.55, 0.62, 0.072, 0.036, bucket_key),
      make_particle_burst("offshore-pump-metal-particle-medium", 12, 0.74, 0.64, 0.080, 0.038, bucket_key),
      make_particle_burst("offshore-pump-metal-particle-small", 12, 0.84, 0.72, 0.078, 0.040, bucket_key),
      make_particle_burst("offshore-pump-glass-particle-small", 12, 0.70, 0.46, 0.082, 0.040, bucket_key),
      make_particle_burst("offshore-pump-mechanical-component-particle-medium", 8, 0.62, 0.40, 0.070, 0.030, bucket_key),
      make_particle_burst("cable-and-electronics-particle-small-medium", 12, 0.62, 0.42, 0.070, 0.026, bucket_key),
      make_particle_burst("spark-particle", 8, 0.82, 1.00, 0.022, 0.070, bucket_key, {
        frame_speed = 0.60,
        frame_speed_deviation = 0.14,
        tail_length = 8,
        tail_length_deviation = 3,
        tail_width = 3,
        only_when_visible = true,
      }),
    }
  end

  if family == "electric-logistics" then
    return {
      make_particle_burst("cable-and-electronics-particle-small-medium", 12, 0.52, 0.38, 0.068, 0.026, bucket_key),
      make_particle_burst("steam-engine-metal-particle-small", 7, 0.42, 0.24, 0.072, 0.030, bucket_key),
      make_particle_burst("spark-particle", 6, 0.58, 0.82, 0.020, 0.060, bucket_key, {
        frame_speed = 0.58,
        frame_speed_deviation = 0.12,
        tail_length = 7,
        tail_length_deviation = 3,
        tail_width = 2,
        only_when_visible = true,
      }),
    }
  end

  if family == "signal" then
    return {
      make_particle_burst("roboport-metal-particle-big", 7, 0.55, 0.80, 0.070, 0.040, bucket_key),
      make_particle_burst("lab-glass-particle-small", 18, 0.80, 0.45, 0.085, 0.040, bucket_key),
      make_particle_burst("cable-and-electronics-particle-small-medium", 16, 0.70, 0.48, 0.072, 0.028, bucket_key),
      make_particle_burst("spark-particle", 10, 0.95, 1.10, 0.022, 0.075, bucket_key, {
        frame_speed = 0.60,
        frame_speed_deviation = 0.15,
        tail_length = 9,
        tail_length_deviation = 4,
        tail_width = 3,
        only_when_visible = true,
      }),
      make_particle_burst("pole-spark-particle", 7, 0.90, 1.00, 0.022, 0.060, bucket_key, {
        frame_speed = 0.58,
        frame_speed_deviation = 0.10,
        tail_length = 10,
        tail_length_deviation = 4,
        tail_width = 4,
        only_when_visible = true,
      }),
    }
  end

  if family == "ballistic" then
    return {
      make_smoke_burst(10, 0.88, 0.026, bucket_key),
      make_particle_burst("steam-engine-metal-particle-big", 7, 0.52, 0.48, 0.085, 0.040, bucket_key),
      make_particle_burst("steam-engine-metal-particle-medium", 10, 0.70, 0.55, 0.090, 0.040, bucket_key),
      make_particle_burst("explosion-remnants-particle", 10, 0.82, 0.18, 0.082, 0.038, bucket_key),
      make_particle_burst("spark-particle", 5, 0.72, 0.90, 0.020, 0.060, bucket_key, {
        frame_speed = 0.56,
        frame_speed_deviation = 0.10,
        tail_length = 7,
        tail_length_deviation = 3,
        tail_width = 2,
        only_when_visible = true,
      }),
    }
  end

  if family == "chemical" then
    return {
      make_smoke_burst(8, 0.82, 0.022, bucket_key),
      make_particle_burst("storage-tank-metal-particle-medium", 10, 0.64, 0.34, 0.082, 0.034, bucket_key),
      make_particle_burst("ei-corrosive-vapor-particle", 20, 1.00, 0.20, 0.052, 0.028, bucket_key, {
        frame_speed = 0.82,
        frame_speed_deviation = 0.16,
        tail_length = 7,
        tail_length_deviation = 3,
        tail_width = 3,
        only_when_visible = true,
      }),
    }
  end

  if family == "quantum" then
    return {
      make_particle_burst("spark-particle", 16, 0.95, 1.15, 0.022, 0.080, bucket_key, {
        frame_speed = 0.62,
        frame_speed_deviation = 0.14,
        tail_length = 10,
        tail_length_deviation = 4,
        tail_width = 3,
        only_when_visible = true,
      }),
      make_particle_burst("pole-spark-particle", 12, 1.05, 1.10, 0.022, 0.070, bucket_key, {
        frame_speed = 0.58,
        frame_speed_deviation = 0.10,
        tail_length = 12,
        tail_length_deviation = 4,
        tail_width = 4,
        only_when_visible = true,
      }),
      make_particle_burst("ei-quantum-mote-particle", 22, 1.20, 1.00, 0.028, 0.045, bucket_key, {
        frame_speed = 0.65,
        frame_speed_deviation = 0.15,
        tail_length = 12,
        tail_length_deviation = 4,
        tail_width = 3,
        only_when_visible = true,
      }),
      make_particle_burst("cable-and-electronics-particle-small-medium", 8, 0.70, 0.45, 0.070, 0.025, bucket_key),
    }
  end

  if family == "alien" then
    return {
      make_smoke_burst(6, 0.85, 0.018, bucket_key),
      make_particle_burst("ei-alien-shard-particle", 15, 0.82, 0.24, 0.082, 0.040, bucket_key),
      make_particle_burst("ei-alien-spore-particle", 18, 1.12, 0.55, 0.050, 0.030, bucket_key, {
        frame_speed = 0.88,
        frame_speed_deviation = 0.16,
        tail_length = 7,
        tail_length_deviation = 3,
        tail_width = 3,
        only_when_visible = true,
      }),
      make_particle_burst("explosion-remnants-particle", 6, 0.72, 0.16, 0.078, 0.032, bucket_key),
    }
  end

  if family == "fortified" then
    return {
      make_smoke_burst(6, 0.72, 0.018, bucket_key),
      make_particle_burst("ei-fortified-shard-particle", 18, 0.72, 0.26, 0.078, 0.032, bucket_key),
      make_particle_burst("explosion-remnants-particle", 8, 0.70, 0.14, 0.070, 0.030, bucket_key),
    }
  end

  return {
    make_particle_burst("ei-cosmic-mote-particle", 18, 1.20, 1.24, 0.018, 0.022, bucket_key, {
      frame_speed = 0.76,
      frame_speed_deviation = 0.16,
      tail_length = 14,
      tail_length_deviation = 5,
      tail_width = 3,
      only_when_visible = true,
    }),
    make_particle_burst("ei-quantum-mote-particle", 10, 0.92, 1.00, 0.020, 0.030, bucket_key, {
      frame_speed = 0.68,
      frame_speed_deviation = 0.12,
      tail_length = 11,
      tail_length_deviation = 4,
      tail_width = 3,
      only_when_visible = true,
    }),
    make_particle_burst("spark-particle", 5, 0.72, 1.10, 0.020, 0.055, bucket_key, {
      frame_speed = 0.58,
      frame_speed_deviation = 0.10,
      tail_length = 10,
      tail_length_deviation = 3,
      tail_width = 3,
      only_when_visible = true,
    }),
  }
end

local function effects_for_exact(name, bucket_key)
  if name == "ei-auric-inoculation-vat" then
    return {
      make_smoke_burst(10, 1.35, 0.018, bucket_key),
      {
        type = "create-explosion",
        entity_name = "blood-explosion-huge",
      },
      {
        type = "create-explosion",
        entity_name = "blood-explosion-big",
      },
      make_particle_burst("ei-auric-blood-particle", 42, 1.55, 0.38, 0.070, 0.050, bucket_key, {
        frame_speed = 0.78,
        frame_speed_deviation = 0.18,
        tail_length = 8,
        tail_length_deviation = 3,
        tail_width = 4,
        only_when_visible = true,
      }),
      make_particle_burst("ei-auric-gore-particle", 32, 1.25, 0.44, 0.092, 0.056, bucket_key),
      {
        type = "create-entity",
        entity_name = "medium-scorchmark",
        check_buildability = true,
      },
    }
  end

  return nil
end

local function combined_trigger_effects(name, family, bucket_key)
  local effects = effects_for_family(family, bucket_key)
  local exact_effects = effects_for_exact(name, bucket_key)

  if exact_effects then
    effects = table.deepcopy(effects)

    for _, effect in pairs(exact_effects) do
      table.insert(effects, effect)
    end
  end

  return effects
end

local function make_explosion(family, bucket_key)
  local name = "ei-death-explosion-" .. family .. "-" .. bucket_key
  local smoke_count = 0

  if family == "tank" or family == "combustion" or family == "steam" or family == "ballistic" or family == "chemical" or family == "fortified" then
    smoke_count = bucket_data[bucket_key].smoke_count
  end

  local explosion = {
    type = "explosion",
    name = name,
    flags = { "not-on-map" },
    hidden = true,
    subgroup = "explosions",
    order = "z[ei-death]",
    height = 0,
    animations = animation_for_family(family, bucket_key),
    sound = sound_for_family(family, bucket_key),
    light = {
      intensity = family == "cosmic" and 1.15 or 1,
      size = bucket_data[bucket_key].light_size,
      color = family_colors[family],
    },
    created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = effects_for_family(family, bucket_key),
      },
    },
  }

  if smoke_count > 0 then
    explosion.smoke = "smoke-fast"
    explosion.smoke_count = smoke_count
    explosion.smoke_slow_down_factor = 1
  end

  return explosion
end

local function make_nuclear_locomotive_override_explosion()
  local explosion = table.deepcopy(data.raw.explosion["small-atomic-explosion"])
  local nuclear_green = { r = 0.42, g = 0.90, b = 0.32, a = 1.00 }
  local nuclear_tint = { r = 0.82, g = 1.00, b = 0.78, a = 0.96 }

  explosion.name = nuclear_locomotive_override_explosion_name
  explosion.flags = { "not-on-map" }
  explosion.hidden = true
  explosion.subgroup = "explosions"
  explosion.order = "z[ei-death]-nuclear-locomotive"
  explosion.animations = scaled_animation(explosion.animations, 0.82)
  tint_animation(explosion.animations, nuclear_tint)
  explosion.light = {
    intensity = 0.90,
    size = 40,
    color = nuclear_green,
  }
  explosion.smoke = nil
  explosion.smoke_count = nil
  explosion.smoke_slow_down_factor = nil
  explosion.created_effect = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 2.6,
            trigger_from_target = true,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "damage",
                  damage = { amount = 220, type = "explosion" },
                  apply_damage_to_trees = true,
                },
              },
            },
          },
        },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 2.6,
            trigger_from_target = true,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "damage",
                  damage = { amount = 20, type = "ei-radiological" },
                  apply_damage_to_trees = false,
                },
              },
            },
          },
        },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 6.5,
            trigger_from_target = true,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "damage",
                  damage = { amount = 95, type = "explosion" },
                  apply_damage_to_trees = true,
                },
              },
            },
          },
        },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 6.5,
            trigger_from_target = true,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "damage",
                  damage = { amount = 12, type = "ei-radiological" },
                  apply_damage_to_trees = false,
                },
              },
            },
          },
        },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 4.5,
            show_in_tooltip = false,
            trigger_from_target = true,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "create-sticker",
                  sticker = "ei-radiological-fallout-sticker-locomotive",
                  show_in_tooltip = false,
                },
              },
            },
          },
        },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = 1.8,
            target_entities = false,
            trigger_from_target = true,
            repeat_count = 4,
            action_delivery = {
              type = "instant",
              target_effects = {
                {
                  type = "create-explosion",
                  entity_name = "uranium-cannon-explosion",
                },
              },
            },
          },
        },
        {
          type = "create-trivial-smoke",
          repeat_count = 6,
          smoke_name = "ei-nuclear-train-smoke",
          offset_deviation = square(1.00),
          speed_from_center = 0.020,
          speed_from_center_deviation = 0.012,
          starting_frame = 0,
          starting_frame_deviation = 60,
        },
        {
          type = "create-entity",
          entity_name = "ei-radiological-fallout-cloud-locomotive",
          trigger_created_entity = true,
        },
        {
          type = "create-entity",
          entity_name = "medium-scorchmark",
          check_buildability = true,
        },
      },
    },
  }

  return explosion
end

local function make_nuclear_locomotive_delay_anchor()
  return {
    type = "explosion",
    name = nuclear_locomotive_delay_anchor_name,
    flags = { "not-on-map" },
    hidden = true,
    subgroup = "explosions",
    order = "z[ei-death]-nuclear-locomotive-delay",
    height = 0,
    animations = util.empty_sprite(),
    created_effect = {
      type = "direct",
      action_delivery = {
        type = "delayed",
        delayed_trigger = nuclear_locomotive_delayed_trigger_name,
      },
    },
  }
end

local function make_nuclear_locomotive_delayed_trigger()
  return {
    type = "delayed-active-trigger",
    name = nuclear_locomotive_delayed_trigger_name,
    delay = 60,
    action = {
      {
        type = "direct",
        action_delivery = {
          type = "instant",
          source_effects = {
            {
              type = "create-explosion",
              entity_name = nuclear_locomotive_override_explosion_name,
            },
          },
        },
      },
    },
  }
end

local function generate_explosions()
  local prototypes = {
    make_particle_prototype {
      name = "ei-death-vapor-particle",
      life_time = 28,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.92, 0.96, 1.00, 0.42 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0025,
    },
    make_particle_prototype {
      name = "ei-corrosive-vapor-particle",
      life_time = 30,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.62, 1.00, 0.42, 0.52 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0018,
    },
    make_particle_prototype {
      name = "ei-quantum-mote-particle",
      life_time = 24,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.48, 0.90, 1.00, 0.78 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0014,
    },
    make_particle_prototype {
      name = "ei-alien-spore-particle",
      life_time = 30,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.44, 1.00, 0.63, 0.76 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0010,
    },
    make_particle_prototype {
      name = "ei-cosmic-mote-particle",
      life_time = 34,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.92, 0.58, 1.00, 0.58 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0018,
    },
    make_particle_prototype {
      name = "ei-alien-shard-particle",
      life_time = 34,
      pictures = particle_animations.get_stone_particle_small_pictures({ tint = { 0.60, 0.94, 0.72, 1.00 } }),
      render_layer = "object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0030,
    },
    make_particle_prototype {
      name = "ei-auric-blood-particle",
      life_time = 38,
      pictures = particle_animations.get_water_particle_pictures({ tint = { 0.56, 0.02, 0.01, 0.88 } }),
      render_layer = "air-object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0012,
    },
    make_particle_prototype {
      name = "ei-auric-gore-particle",
      life_time = 42,
      pictures = particle_animations.get_stone_particle_small_pictures({ tint = { 0.36, 0.02, 0.02, 1.00 } }),
      render_layer = "object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0034,
    },
    make_particle_prototype {
      name = "ei-fortified-shard-particle",
      life_time = 34,
      pictures = particle_animations.get_stone_particle_small_pictures({ tint = { 0.76, 0.76, 0.82, 1.00 } }),
      render_layer = "object",
      render_layer_when_on_ground = "lower-object-above-shadow",
      vertical_acceleration = -0.0030,
    },
  }

  for _, family in pairs(family_order) do
    generated_explosions[family] = {}

    for bucket_key, _ in pairs(bucket_data) do
      local explosion = make_explosion(family, bucket_key)
      generated_explosions[family][bucket_key] = explosion.name
      table.insert(prototypes, explosion)
    end
  end

  table.insert(prototypes, make_nuclear_locomotive_override_explosion())
  table.insert(prototypes, make_nuclear_locomotive_delay_anchor())
  table.insert(prototypes, make_nuclear_locomotive_delayed_trigger())

  data:extend(prototypes)
end

local function find_entity(name)
  for _, entity_type in pairs(entity_types) do
    local group = data.raw[entity_type]
    if group and group[name] then
      return group[name], entity_type
    end
  end

  return nil, nil
end

local function build_exact_family_map()
  local map = {}

  for family, names in pairs(family_assignments) do
    for _, name in pairs(names) do
      map[name] = family
    end
  end

  return map
end

local function dependency_prefix_for_name(name)
  for _, prefix in pairs(dependency_prefix_inclusions) do
    if startswith(name, prefix) then
      return prefix
    end
  end

  return nil
end

local function find_prefix_family(name)
  for family, prefixes in pairs(family_prefixes) do
    for _, prefix in pairs(prefixes) do
      if startswith(name, prefix) then
        return family, prefix
      end
    end
  end

  return nil, nil
end

local function is_generic_dying_explosion(name)
  return name ~= nil and generic_dying_explosions[name] == true
end

local function is_scoped_dependency(name, exact_family_map)
  if is_owned_name(name) then
    return false
  end

  if dependency_exact_inclusions[name] then
    return true
  end

  if exact_family_map[name] then
    return true
  end

  return dependency_prefix_for_name(name) ~= nil
end

local function family_from_heuristics(name, prototype, entity_type)
  if entity_type == "wall" or entity_type == "gate" then
    return "fortified"
  end

  if entity_type == "ammo-turret" or entity_type == "artillery-turret" then
    return "ballistic"
  end

  if entity_type == "fluid-turret" then
    return "chemical"
  end

  if entity_type == "storage-tank" then
    return "tank"
  end

  if startswith(name, "ei-holo-") or contains(name, "black-hole") or contains(name, "simulator") then
    return "cosmic"
  end

  if startswith(name, "ei-neo-") or startswith(name, "ei_em-") or startswith(name, "ei-5dim-mk") or name == "ei_charger" then
    return "quantum"
  end

  if contains(name, "alien") or contains(name, "crystal") or contains(name, "gaia") or contains(name, "farstation") then
    return "alien"
  end

  if name == "ei-gate-receiver" or name == "ei-rift-stabilizer" or name == "ei-warp-beacon" then
    return "alien"
  end

  if entity_type == "locomotive" or entity_type == "cargo-wagon" or entity_type == "fluid-wagon" then
    if startswith(name, "rp-steam-") or startswith(name, "ei-steam-") then
      return "steam"
    end

    if startswith(name, "ei_em-") or name == "ei-nuclear-locomotive" then
      return "quantum"
    end

    return "electric-logistics"
  end

  if entity_type == "construction-robot" or entity_type == "logistic-robot" then
    if startswith(name, "rp-steam-") then
      return "steam"
    end

    return "electric-logistics"
  end

  if entity_type == "loader-1x1" or entity_type == "transport-belt" or entity_type == "underground-belt" or entity_type == "splitter" then
    if startswith(name, "ei-neo-") or startswith(name, "ei_em-") or startswith(name, "ei-5dim-mk") then
      return "quantum"
    end

    return "electric-logistics"
  end

  if entity_type == "inserter" then
    if name == "ei-mechanical-inserter" or name == "ei-mechanical-long-inserter" then
      return "mechanical"
    end

    if startswith(name, "ei-burner-") then
      return "combustion"
    end

    if startswith(name, "ei-steam-") then
      return "steam"
    end

    return "electric-logistics"
  end

  if entity_type == "electric-pole" then
    if contains(name, "farstation") then
      return "alien"
    end

    return "signal"
  end

  if entity_type == "offshore-pump" then
    if name == "ei-gaia-pump" then
      return "alien"
    end

    if name == "ei-stone-well-pump" then
      return "mechanical"
    end

    return "steam"
  end

  if entity_type == "pipe" or entity_type == "pipe-to-ground" then
    if name == "ei-data-pipe" then
      return "signal"
    end

    return "electric-industrial"
  end

  if entity_type == "heat-pipe" or entity_type == "boiler" or entity_type == "heat-interface" then
    return "steam"
  end

  if entity_type == "pump" then
    if startswith(name, "rp-steam-") then
      return "steam"
    end

    return "electric-industrial"
  end

  if entity_type == "solar-panel" or entity_type == "accumulator" then
    if name == "ei-solar-panel-3" or contains(name, "neo") then
      return "quantum"
    end

    return "electric-industrial"
  end

  if entity_type == "display-panel" or entity_type == "electric-energy-interface" then
    return "cosmic"
  end

  if entity_type == "constant-combinator" or entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" then
    return "signal"
  end

  if entity_type == "container" or entity_type == "logistic-container" then
    return "signal"
  end

  if entity_type == "lamp" then
    if name == "ei-steampunk-lamp" then
      return "combustion"
    end

    return "signal"
  end

  if entity_type == "generator" then
    if contains(name, "combustion") then
      return "combustion"
    end

    if contains(name, "turbine") then
      return "steam"
    end
  end

  if name == "ei-fueler" then
    return "combustion"
  end

  if name == "accumulator" or name == "solar-panel" then
    return "electric-industrial"
  end

  if contains(name, "reactor") or contains(name, "fusion") or contains(name, "plasma") or contains(name, "quantum") then
    return "quantum"
  end

  local energy_source = prototype.energy_source
  if energy_source and energy_source.type then
    if energy_source.type == "burner" then
      return "combustion"
    end

    if energy_source.type == "fluid" or energy_source.type == "heat" then
      return "steam"
    end

    if energy_source.type == "void" then
      return "mechanical"
    end

    if energy_source.type == "electric" then
      if entity_type == "beacon" or entity_type == "constant-combinator" or entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" or entity_type == "display-panel" or entity_type == "electric-pole" or entity_type == "electric-energy-interface" or entity_type == "lab" then
        return "signal"
      end

      return "electric-industrial"
    end
  end

  if entity_type == "beacon" or entity_type == "lab" then
    return "signal"
  end

  return nil
end

local function family_for_prototype(name, prototype, entity_type, exact_family_map)
  local owned = is_owned_name(name)
  local scoped_dependency = is_scoped_dependency(name, exact_family_map)

  if not owned and not scoped_dependency then
    return nil, nil, nil
  end

  local exact_family = exact_family_map[name]
  if exact_family then
    return exact_family, "exact", name
  end

  local prefix_family, prefix = find_prefix_family(name)
  if prefix_family then
    if owned or dependency_prefix_for_name(name) == prefix then
      return prefix_family, "prefix", prefix
    end
  end

  local heuristic_family = family_from_heuristics(name, prototype, entity_type)
  if heuristic_family then
    return heuristic_family, "heuristic", nil
  end

  return nil, nil, nil
end

local function append_trigger_effects(prototype, effects)
  local existing = prototype.dying_trigger_effect
  local merged = {}

  if existing then
    if existing.type then
      table.insert(merged, table.deepcopy(existing))
    else
      for _, effect in pairs(existing) do
        table.insert(merged, table.deepcopy(effect))
      end
    end
  end

  for _, effect in pairs(effects) do
    table.insert(merged, table.deepcopy(effect))
  end

  prototype.dying_trigger_effect = merged
end

local function should_supplement(name, current_core)
  if not current_core then
    return false
  end

  if preserve_exact[name] then
    return true
  end

  if preserved_core_explosions[current_core] then
    return true
  end

  if startswith(current_core, "ei-death-explosion-") then
    return false
  end

  return not is_generic_dying_explosion(current_core)
end

local function apply_exact_rolling_stock_override(name, prototype, entity_type, family, bucket_key, current_core, rolling_stock_core, assignment_log)
  local override_explosion = exact_rolling_stock_overrides[name]
  if not override_explosion or not rolling_stock_core then
    return false
  end

  prototype.dying_explosion = rolling_stock_core
  append_trigger_effects(prototype, {
    {
      type = "create-explosion",
      entity_name = override_explosion,
    },
  })
  assignment_log[name] = {
    mode = "rail-exact",
    family = family,
    bucket = bucket_key,
    core = current_core,
    final_core = rolling_stock_core,
    override = override_explosion,
  }

  return true
end

local function apply_family(name, prototype, entity_type, family, assignment_log)
  local bucket_key = footprint_bucket(prototype, entity_type)
  local target_explosion = generated_explosions[family][bucket_key]
  local current_core = prototype.dying_explosion
  local rolling_stock_core = rolling_stock_cores[entity_type]

  if apply_exact_rolling_stock_override(name, prototype, entity_type, family, bucket_key, current_core, rolling_stock_core, assignment_log) then
    return
  end

  if rolling_stock_core then
    prototype.dying_explosion = rolling_stock_core
    append_trigger_effects(prototype, combined_trigger_effects(name, family, bucket_key))
    assignment_log[name] = {
      mode = "rail-core",
      family = family,
      bucket = bucket_key,
      core = current_core,
      final_core = rolling_stock_core,
    }
    return
  end

  if should_supplement(name, current_core) then
    append_trigger_effects(prototype, combined_trigger_effects(name, family, bucket_key))
    assignment_log[name] = {
      mode = "supplement",
      family = family,
      bucket = bucket_key,
      core = current_core,
    }
    return
  end

  prototype.dying_explosion = target_explosion
  local exact_effects = effects_for_exact(name, bucket_key)
  if exact_effects then
    append_trigger_effects(prototype, exact_effects)
  end
  assignment_log[name] = {
    mode = "replace",
    family = family,
    bucket = bucket_key,
    core = current_core,
  }
end

local function apply_exact_effect(name, prototype, entity_type, assignment_log)
  if assignment_log[name] then
    return
  end

  local bucket_key = footprint_bucket(prototype, entity_type)
  local exact_effects = effects_for_exact(name, bucket_key)
  if not exact_effects then
    return
  end

  append_trigger_effects(prototype, exact_effects)
  assignment_log[name] = {
    mode = "exact-effect",
    bucket = bucket_key,
    core = prototype.dying_explosion,
  }
end

local function collect_unresolved_exacts()
  local unresolved = {}

  for family, names in pairs(family_assignments) do
    for _, name in pairs(names) do
      local prototype = find_entity(name)
      if not prototype then
        table.insert(unresolved, family .. ":" .. name)
      end
    end
  end

  table.sort(unresolved)
  return unresolved
end

local function audit_logs(exact_family_map, assignment_log, prefix_hits)
  local unresolved_exacts = collect_unresolved_exacts()
  if #unresolved_exacts > 0 then
    log("EI death explosion audit: unresolved exact assignments -> " .. table.concat(unresolved_exacts, ", "))
  end

  local unresolved_prefixes = {}
  for family, prefixes in pairs(family_prefixes) do
    for _, prefix in pairs(prefixes) do
      if not prefix_hits[family .. ":" .. prefix] then
        table.insert(unresolved_prefixes, family .. ":" .. prefix)
      end
    end
  end

  table.sort(unresolved_prefixes)
  if #unresolved_prefixes > 0 then
    log("EI death explosion audit: unresolved prefix assignments -> " .. table.concat(unresolved_prefixes, ", "))
  end

  local leftovers = {}
  for _, entity_type in pairs(entity_types) do
    for name, prototype in pairs(data.raw[entity_type] or {}) do
      if visible_candidate(name, prototype) and (is_owned_name(name) or is_scoped_dependency(name, exact_family_map)) then
        local generic_or_missing = prototype.dying_explosion == nil or is_generic_dying_explosion(prototype.dying_explosion)
        local supplemented = assignment_log[name] and assignment_log[name].mode == "supplement"

        if generic_or_missing and not supplemented then
          table.insert(leftovers, name .. ":" .. entity_type .. ":" .. tostring(prototype.dying_explosion))
        end
      end
    end
  end

  table.sort(leftovers)
  if #leftovers > 0 then
    log("EI death explosion audit: scoped visible prototypes still generic or missing after pass -> " .. table.concat(leftovers, ", "))
  end
end

generate_explosions()

local exact_family_map = build_exact_family_map()
local assignment_log = {}
local prefix_hits = {}

for _, entity_type in pairs(entity_types) do
  for name, prototype in pairs(data.raw[entity_type] or {}) do
    if visible_candidate(name, prototype) then
      local family, source, source_key = family_for_prototype(name, prototype, entity_type, exact_family_map)
      if family then
        if source == "prefix" and source_key then
          prefix_hits[family .. ":" .. source_key] = true
        end

        apply_family(name, prototype, entity_type, family, assignment_log)
      end
    end
  end
end

for _, name in pairs(exact_effect_assignments) do
  local prototype, entity_type = find_entity(name)
  if prototype then
    apply_exact_effect(name, prototype, entity_type, assignment_log)
  else
    log("EI death explosion audit: unresolved exact effect assignment -> " .. name)
  end
end

audit_logs(exact_family_map, assignment_log, prefix_hits)
