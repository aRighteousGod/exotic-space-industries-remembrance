
-- info

ei_mod.stage = "data-final-updates"
local ei_lib = require("lib.lib")

function endswith(str,suf) return str:sub(-string.len(suf)) == suf end
function startswith(text, prefix) return text:find(prefix, 1, true) == 1 end
function contains(s, word) return tostring(s):find(word, 1, true) ~= nil end

--===========
--FINAL FIXES
--===========


-- =======================================================================================
-- Override main menu
require("scripts/data-final-updates/set-menu-background")

-- =======================================================================================
require("scripts/data-final-updates/assembler-reskin")
require("scripts/data-final-updates/distant-misfires")
require("scripts/data-final-updates/camp-fire")
require("scripts/data-final-updates/flare-stack")
require("scripts/data-final-updates/final-tech-fixes")
require("scripts/data-final-updates/hide-surveyor-weapons")
require("scripts/data-final-updates/final-recipe-fixes")
require("scripts/data-final-updates/final-tint-pass")
require("scripts/data-final-updates/colorful-biochamber")
require("scripts/data-final-updates/set-age-packs")
require("scripts/data-final-updates/set-prerequisites")
require("scripts/data-final-updates/tiles")
require("scripts/data-final-updates/labs")
require("scripts/data-final-updates/recycling")
require("scripts/data-final-updates/items")
require("scripts/data-final-updates/krastorio-patches")
require("teslas_legacy/final_overlay_ei")


--=======================================================================================

require("scripts/data-final-updates/compatibility")
require("scripts/data-final-updates/compatibility-lignumis")
require("scripts/data-final-updates/compatibility-muluna")
require("scripts/data-final-updates/death-explosions")

-- =======================================================================================

--data.raw.reactor["ei-burner-heater"].energy_source.fuel_categories = {"chemical"}
ei_lib.raw.item.wood.fuel_category = "chemical"
ei_lib.raw.item.coal.fuel_category = "chemical"

-- =======================================================================================

for _,thruster in pairs(data.raw.thruster) do
  thruster.tile_buildability_rules[2].area[2][2] = 25.0
end

-- =======================================================================================

for _, ammo_turret in pairs(data.raw["ammo-turret"]) do
  if ammo_turret.inventory_size >= 5 then
    -- do nothing
  else
    ammo_turret.inventory_size = 5
  end
end

-- =======================================================================================

data.raw["space-platform-starter-pack"]["space-platform-starter-pack"].initial_items = {
  {type = "item", name = "space-platform-foundation", amount = 60}
}

-- =======================================================================================

--data.raw["assembling-machine"]["foundry"].fluid_boxes[3].volume = 5000
--data.raw["assembling-machine"]["foundry"].fluid_boxes[4].volume = 5000

-- =======================================================================================

local esa = ei_lib.raw["assembling-machine"]["ei-steam-assembler"]
local am2 = ei_lib.raw["assembling-machine"]["assembling-machine-2"]
if esa and am2 then
  for _,mergefrom in pairs(am2.crafting_categories) do
    if not ei_lib.table_contains_value(esa.crafting_categories, mergefrom) then
      table.insert(esa.crafting_categories,mergefrom)
    end
  end
end

-- =======================================================================================

for _, inserter in pairs(data.raw.inserter) do
  if inserter.energy_source and inserter.energy_source.type == "burner" then
    inserter.allow_burner_leech = true
  end
end

-- =======================================================================================

-- List of base machine types to modify
--[[
local base_machine_types = {
  "assembling-machine",
  "furnace",
  "mining-drill"
}


-- Loop through each base machine type and set match_animation_speed_to_activity to false
for _, machine_type in pairs(base_machine_types) do
  if data.raw[machine_type] then
    for _, prototype in pairs(data.raw[machine_type]) do
      if prototype then
        if contains(prototype.name,"recycler") then prototype.surface_conditions = nil end
        if contains(prototype.name,"crusher") then prototype.surface_conditions = nil end
        prototype.match_animation_speed_to_activity = false
      end
    end
  end
end
]]
-- error(serpent.block(data.raw["furnace"]["recycler"]))

-- =======================================================================================

for _,tech in pairs(data.raw.technology) do
  if tech.prerequisites then
    for i,t in ipairs(tech.prerequisites) do 
      if data.raw.technology[t] and data.raw.technology[t].hidden then
        table.remove(data.raw.technology[tech.name].prerequisites, i)
      end
    end
  end
end

-- Fuel glow needs to run after final fuel-category compatibility passes so ESIR's
-- curated colors win over optional generic fuel glow mods.
require("scripts/data-final-updates/fuel-glow")

-- Gate attunement stays near the end so the startup setting remains the final word on gate
-- tech placement and both gate recipes after the repo's generic age/prereq passes.
require("scripts/data-final-updates/exotic-damage-resistances")
require("scripts/data-final-updates/enemy-difficulty")
require("scripts/data-final-updates/gate-difficulty")
require("scripts/data-final-updates/singularity-lance-damage-category")
require("scripts/data-final-updates/emerald-apocalypse-hover-tank")
require("scripts/data-final-updates/item-glow-overlays")
require("scripts/data-final-updates/arc-furnace-light")
require("scripts/data-final-updates/entity-presentation")

-- Spider-vehicle lights are normalized between data-updates and final fixes; keep
-- the saucer's forward crystal headlight as the final word so Spidertron defaults do not leak in.
do
  local saucer = data.raw["spider-vehicle"] and data.raw["spider-vehicle"]["ei-gaian-saucer"]
  if saucer and saucer.graphics_set then
    local crystal_headlight_color = {r = 0.12, g = 0.95, b = 0.88}
    local front_crystal_offset = {x = 0, y = -50}
    local function crystal_beam_origin(offset)
      local distance = math.sqrt(offset.x * offset.x + offset.y * offset.y)
      if distance == 0 then
        return offset
      end

      return {
        x = offset.x + (offset.x / distance * 12),
        y = offset.y + (offset.y / distance * 12),
      }
    end
    local function crystal_beam_shift(offset)
      offset = crystal_beam_origin(offset)
      return util.by_pixel(offset.x * 0.69, offset.y * 0.69)
    end
    local function crystal_beam(source_orientation_offset, source_offset)
      return {
        type = "oriented",
        minimum_darkness = 0.25,
        picture = {
          filename = "__core__/graphics/light-cone.png",
          priority = "extra-high",
          flags = {"light"},
          scale = 0.85,
          width = 200,
          height = 200,
        },
        source_orientation_offset = source_orientation_offset,
        shift = crystal_beam_shift(source_offset),
        size = 0.95,
        intensity = 0.26,
        color = table.deepcopy(crystal_headlight_color),
      }
    end

    saucer.graphics_set.light = {
      crystal_beam(0.00, front_crystal_offset),
      {
        type = "basic",
        minimum_darkness = 0.25,
        intensity = 0.5,
        size = 18,
        color = {r = 0.25, g = 0.95, b = 0.55},
      },
    }
  end
end

-- Weighted-tech badges are a pure icon pass, so they can run truly last after every other
-- final tech rewrite has settled on its finished icon and science layout.
require("scripts/data-final-updates/tech-weight-badges")
