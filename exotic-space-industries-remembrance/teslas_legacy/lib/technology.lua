-- Tesla's Legacy tech helpers are intentionally thin wrappers around EI's
-- age-tech economy. The vendored mod used raw science packs; the internalized
-- version should speak the same language as the rest of Remembrance.
--
-- The important design rule here is that Tesla technologies now own their age
-- placement directly inside the TL module. We no longer rely on a later EI
-- overlay pass to "infer" the right age from a mix of legacy vanilla packs.
local ei_data = require("lib/data")

local LEGACY_SCIENCE = {
  red = {"automation-science-pack", 1},
  green = {"logistic-science-pack", 1},
  black = {"military-science-pack", 1},
  blue = {"chemical-science-pack", 1},
  yellow = {"utility-science-pack", 1},
  purple = {"production-science-pack", 1},
  white = {"space-science-pack", 1},
}

local function starts_with(value, prefix)
  return string.find(value or "", prefix, 1, true) == 1
end

local function copy_science(ingredients)
  if table.deepcopy then
    return table.deepcopy(ingredients)
  end

  local copied = {}
  for index, ingredient in pairs(ingredients or {}) do
    copied[index] = {ingredient[1], ingredient[2]}
  end
  return copied
end

local function resolve_science(age, science_override)
  if science_override then
    return copy_science(science_override)
  end

  if age and ei_data and ei_data.science and ei_data.science[age] then
    return copy_science(ei_data.science[age])
  end

  return copy_science(ei_data and ei_data.science and ei_data.science["electricity-age"] or {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"military-science-pack", 1},
  })
end

-- Compatibility helper for the few vendored files that still build legacy
-- vanilla-pack arrays by name. When `age` is omitted we intentionally return a
-- keyed legacy science table, not EI age science, so those files remain easy to
-- read while the real emitted ingredients still come from the Tesla age map.
function get_science(age)
  if age then
    return resolve_science(age)
  end

  return {
    red = copy_science({LEGACY_SCIENCE.red})[1],
    green = copy_science({LEGACY_SCIENCE.green})[1],
    black = copy_science({LEGACY_SCIENCE.black})[1],
    blue = copy_science({LEGACY_SCIENCE.blue})[1],
    yellow = copy_science({LEGACY_SCIENCE.yellow})[1],
    purple = copy_science({LEGACY_SCIENCE.purple})[1],
    white = copy_science({LEGACY_SCIENCE.white})[1],
  }
end

function get_tesla_technology_level(name, explicit_level)
  if explicit_level ~= nil then
    return explicit_level
  end

  local level = string.match(name or "", "%-(%d+)$")
  return tonumber(level)
end

-- Tesla branch age mapping policy:
-- - "basic coil" families stay in electricity age until their authored late
--   tiers explicitly step into higher science.
-- - anything gated by advanced coils or the Tesla tank is authored directly as
--   advanced-computer-age so it truly inherits EI's higher pack bracket.
-- - infinite or clearly space-tier capstones stay in advanced-computer-age-space.
function get_tesla_technology_age(name, explicit_level)
  local level = get_tesla_technology_level(name, explicit_level) or 0

  if name == "tl-basic-tesla-coils-technology" then
    return "electricity-age"
  end

  if name == "tl-advanced-tesla-coils-technology" or name == "tl-tesla-tank-technology" then
    return "advanced-computer-age"
  end

  if starts_with(name, "ei-waveform-harmonics-") then
    return "advanced-computer-age-space"
  end

  if starts_with(name, "ei-storm-lattice-")
    or starts_with(name, "ei-dielectric-rupture-")
    or starts_with(name, "ei-bridge-coupling-")
  then
    return "quantum-age"
  end

  if starts_with(name, "ei-reactance-overdrive-") then
    return "fusion-quantum-age"
  end

  if name == "ei-exotic-waveform-convergence" then
    return "exotic-age"
  end

  if starts_with(name, "tl-tesla-coil-shooting-speed-") then
    if level >= 7 then
      return "advanced-computer-age-space"
    end
    if level >= 6 then
      return "advanced-computer-age"
    end
    return "electricity-age"
  end

  if starts_with(name, "tl-multi-zap-") then
    if level >= 5 then
      return "advanced-computer-age"
    end
    return "electricity-age"
  end

  if starts_with(name, "tl-slowdown-multiplier-technology-") then
    if level >= 5 then
      return "advanced-computer-age"
    end
    return "electricity-age"
  end

  if starts_with(name, "tl-slowdown-probability-technology-") or starts_with(name, "tl-slowdown-duration-technology-") then
    return "electricity-age"
  end

  if starts_with(name, "tl-tesla-coil-damage-technology-") then
    if level >= 7 then
      return "advanced-computer-age-space"
    end
    return "advanced-computer-age"
  end

  if starts_with(name, "tl-tesla-ammo-upgrade-technology-") then
    if level >= 7 then
      return "advanced-computer-age-space"
    end
    return "advanced-computer-age"
  end

  if starts_with(name, "tl-single-zap-") or starts_with(name, "tl-flames-") or starts_with(name, "tl-volatility-") then
    return "advanced-computer-age"
  end

  if starts_with(name, "tl-") then
    return "electricity-age"
  end

  return nil
end

function get_tesla_technology_science(name, explicit_level)
  local age = get_tesla_technology_age(name, explicit_level)
  if not age then
    return nil
  end

  return resolve_science(age)
end

local function apply_icon_defaults(technology)
  if technology.name == "tl-basic-tesla-coils-technology" then
    technology.icon_size = 256
  else
    technology.icon_size = technology.icon_size or 128
  end

  if technology.icon_mipmaps == nil or technology.icon_mipmaps == 0 then
    technology.icon_mipmaps = 4
  end
end

function apply_tesla_technology_layout(technology, explicit_level)
  if not technology or not technology.name or not technology.unit then
    return
  end

  if not starts_with(technology.name, "tl-")
    and not starts_with(technology.name, "ei-waveform-harmonics-")
    and not starts_with(technology.name, "ei-storm-lattice-")
    and not starts_with(technology.name, "ei-dielectric-rupture-")
    and not starts_with(technology.name, "ei-bridge-coupling-")
    and not starts_with(technology.name, "ei-reactance-overdrive-")
    and technology.name ~= "ei-exotic-waveform-convergence"
  then
    return
  end

  local age = get_tesla_technology_age(technology.name, explicit_level)
  if not age then
    return
  end

  technology.age = age
  technology.unit.ingredients = resolve_science(age)
  apply_icon_defaults(technology)
end

function apply_tesla_technology_layouts()
  for _, technology in pairs(data.raw.technology or {}) do
    apply_tesla_technology_layout(technology)
  end
end

function get_count(level)
  return 10
end

function get_time(level)
  return 30
end

function make_damage_modifier(category, modifier)
  return {
    type = "ammo-damage",
    ammo_category = category,
    modifier = modifier,
  }
end

function make_shooting_speed_modifier(category, modifier)
  return {
    type = "gun-speed",
    ammo_category = category,
    modifier = modifier,
  }
end

function create_technology(args)
  local technology_name = args.name .. "-" .. args.level
  local age = args.age or get_tesla_technology_age(technology_name, args.level) or "electricity-age"
  local upgrade = args.upgrade
  if upgrade == nil then
    upgrade = args.level ~= nil and args.level > 0
  end

  return {
    type = "technology",
    name = technology_name,
    icon_size = args.icon_size or 128,
    icon_mipmaps = args.icon_mipmaps or 4,
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/technology/icons/" .. args.name .. ".png",
    effects = args.effects or {},
    prerequisites = args.prerequisites or {},
    unit = {
      count = args.count or get_count(args.level),
      ingredients = resolve_science(age, args.use_custom_science and args.science or nil),
      time = args.time or get_time(args.level),
    },
    age = age,
    upgrade = upgrade,
    order = args.order or "e-j-a",
  }
end
