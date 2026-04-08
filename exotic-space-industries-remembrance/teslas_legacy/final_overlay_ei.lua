-- Final Tesla technology reassertion.
--
-- EI's global final-tech passes legitimately rewrite packs for a wide range of
-- technologies. Tesla's Legacy is unusual because we want the original TL ladders,
-- the harmonics spine, and the later doctrine families to finish in a very specific
-- EI layout that does not always match the generic "highest visible prerequisite"
-- outcome. This file is intentionally small and explicit: it reapplies the Tesla
-- family map one last time, without any ingredient inference.

local ei_data = require("lib/data")

local function ingredient_list_has_name(ingredients, ingredient_name)
  for _, ingredient in pairs(ingredients or {}) do
    local name = ingredient.name or ingredient[1]
    if name == ingredient_name then
      return true
    end
  end

  return false
end

local function set_tesla_technology_layout(name, age, extra_ingredients)
  local technology = data.raw.technology[name]
  if not technology then
    return
  end

  technology.age = age

  if technology.unit then
    technology.unit.ingredients = table.deepcopy(ei_data.science[age] or technology.unit.ingredients)
    for _, ingredient in pairs(extra_ingredients or {}) do
      if not ingredient_list_has_name(technology.unit.ingredients, ingredient[1]) then
        technology.unit.ingredients[#technology.unit.ingredients + 1] = {ingredient[1], ingredient[2]}
      end
    end
  end

  technology.icon_size = technology.icon_size or 128
  if technology.icon_mipmaps == nil or technology.icon_mipmaps == 0 then
    technology.icon_mipmaps = 4
  end
end

local function set_tesla_technology_range(prefix, first_level, last_level, age)
  for level = first_level, last_level do
    set_tesla_technology_layout(prefix .. level, age)
  end
end

-- The ordering below is deliberate rather than data-driven: first anchor the three public
-- entry technologies, then walk each TL upgrade family by age band so later global EI passes
-- cannot leave a few late levels stranded on the wrong science tier.
set_tesla_technology_layout("tl-basic-tesla-coils-technology", "electricity-age")
set_tesla_technology_layout("tl-advanced-tesla-coils-technology", "advanced-computer-age")
set_tesla_technology_layout("tl-tesla-tank-technology", "advanced-computer-age")

set_tesla_technology_range("tl-tesla-coil-shooting-speed-", 1, 5, "electricity-age")
set_tesla_technology_layout("tl-tesla-coil-shooting-speed-6", "advanced-computer-age")
set_tesla_technology_layout("tl-tesla-coil-shooting-speed-7", "advanced-computer-age-space")

set_tesla_technology_range("tl-multi-zap-probability-technology-", 1, 4, "electricity-age")
set_tesla_technology_range("tl-multi-zap-damage-technology-", 1, 4, "electricity-age")
set_tesla_technology_range("tl-multi-zap-range-technology-", 1, 4, "electricity-age")
set_tesla_technology_layout("tl-multi-zap-probability-technology-5", "advanced-computer-age")
set_tesla_technology_layout("tl-multi-zap-damage-technology-5", "advanced-computer-age")
set_tesla_technology_layout("tl-multi-zap-range-technology-5", "advanced-computer-age")

set_tesla_technology_range("tl-slowdown-probability-technology-", 1, 5, "electricity-age")
set_tesla_technology_range("tl-slowdown-duration-technology-", 1, 5, "electricity-age")
set_tesla_technology_range("tl-slowdown-multiplier-technology-", 1, 4, "electricity-age")
set_tesla_technology_layout("tl-slowdown-multiplier-technology-5", "advanced-computer-age")

set_tesla_technology_range("tl-tesla-coil-damage-technology-", 1, 6, "advanced-computer-age")
set_tesla_technology_layout("tl-tesla-coil-damage-technology-7", "advanced-computer-age-space")

set_tesla_technology_range("tl-single-zap-probability-technology-", 1, 5, "advanced-computer-age")
set_tesla_technology_range("tl-single-zap-damage-technology-", 1, 5, "advanced-computer-age")
set_tesla_technology_range("tl-single-zap-count-technology-", 1, 5, "advanced-computer-age")

set_tesla_technology_range("tl-flames-probability-technology-", 1, 5, "advanced-computer-age")
set_tesla_technology_range("tl-flames-count-technology-", 1, 5, "advanced-computer-age")
set_tesla_technology_range("tl-flames-explosion-technology-", 1, 5, "advanced-computer-age")

set_tesla_technology_range("tl-tesla-ammo-upgrade-technology-", 1, 6, "advanced-computer-age")
set_tesla_technology_layout("tl-tesla-ammo-upgrade-technology-7", "advanced-computer-age-space")
set_tesla_technology_range("tl-volatility-modulation-technology-", 1, 5, "advanced-computer-age")
set_tesla_technology_range("tl-volatility-probability-technology-", 1, 5, "advanced-computer-age")

for level = 1, 3 do
  -- These EI-exclusive follow-up technologies sit above the classical TL line, so they get
  -- pinned after the legacy families instead of being folded into the same generic range pass.
  set_tesla_technology_layout(
    "ei-waveform-harmonics-" .. level,
    "advanced-computer-age-space",
    {{"electromagnetic-science-pack", 1}}
  )
end

for level = 1, 3 do
  set_tesla_technology_layout("ei-storm-lattice-" .. level, "quantum-age")
  set_tesla_technology_layout("ei-dielectric-rupture-" .. level, "quantum-age")
  set_tesla_technology_layout("ei-reactance-overdrive-" .. level, "fusion-quantum-age")
end

for level = 1, 2 do
  set_tesla_technology_layout("ei-bridge-coupling-" .. level, "quantum-age")
end

set_tesla_technology_layout("ei-exotic-waveform-convergence", "exotic-age")
