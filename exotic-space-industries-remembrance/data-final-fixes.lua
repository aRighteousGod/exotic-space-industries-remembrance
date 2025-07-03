
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
require("scripts/data-final-updates/set_menu_background")

-- =======================================================================================

require("scripts/data-final-updates/final-tech-fixes")
require("scripts/data-final-updates/final-recipe-fixes")
require("scripts/data-final-updates/set_age_packs")
require("scripts/data-final-updates/set_prerequisites")
require("scripts/data-final-updates/tiles")
require("scripts/data-final-updates/labs")
require("scripts/data-final-updates/items")
require("scripts/data-final-updates/krastorio_patches")
-- =======================================================================================

require("scripts/data-final-updates/compatibility")

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
-- Biolab uses nutrients, @StephenB
local originalEnergySource = ei_lib.raw.lab.biolab.energy_source
ei_lib.raw.lab.biolab.energy_source = table.deepcopy(data.raw["assembling-machine"].biochamber.energy_source)
-- Leaving power at 300kW. Biochambers use 500kW.
-- Biochambers have -1/m pollution emission (ie they reduce pollution). Biolabs had 8/m pollution emission, but this changes it to -1/m. Captive biter spawners are also -1/m. Looking at a simple Nauvis base importing most sciences, biolabs are actually the majority of the pollution, so I'm changing it back to 8/m.
ei_lib.raw.lab.biolab.energy_source.emissions_per_minute = originalEnergySource.emissions_per_minute

-- =======================================================================================

--data.raw["assembling-machine"]["foundry"].fluid_boxes[3].volume = 5000
--data.raw["assembling-machine"]["foundry"].fluid_boxes[4].volume = 5000

-- =======================================================================================

ei_lib.raw["assembling-machine"]["ei-steam-assembler"].crafting_categories = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"].crafting_categories)

for _, crafting_category in pairs({"ei-steam-assembler", "crafting", "crafting-with-fluid", "electronics"}) do 
  if not ei_lib.table_contains_value(data.raw["assembling-machine"]["ei-steam-assembler"].crafting_categories,crafting_category) then 
    table.insert(data.raw["assembling-machine"]["ei-steam-assembler"].crafting_categories,crafting_category)
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
local base_machine_types = {
  "assembling-machine",
  "furnace",
  "mining-drill"
}

--[[
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