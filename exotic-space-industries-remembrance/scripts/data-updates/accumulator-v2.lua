--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["Accumulator-V2"] then
    return
end

local ei_lib = require("lib/lib")
local path = "__Accumulator-V2__"

--tech accumulator-v2
--item accumulator-v2
--recipe accumulator-v2
--accumulator accumulator-v2
--corpse accumulatorv2-remnants

--vanilla_accumulator
data.raw.accumulator.accumulator = table.deepcopy(data.raw.accumulator["accumulator-v2"])
data.raw.accumulator.accumulator.name = "accumulator"
data.raw.accumulator.accumulator.minable.result = "accumulator"

-- same from vanilla patches
ei_lib.raw.accumulator.accumulator = {
  energy_source = {
      buffer_capacity = "6MJ",
      input_flow_limit = "425kW",
      output_flow_limit = "425kW",
  }
}

--for whatever reason this doesn't work
--[[
local v_a = ei_lib.raw["accumulator"]["accumulator"]
local a_2 = ei_lib.raw["accumulator"]["accumulator-v2"]
if v_a and a_2 then
  log("setting accumulator to accumulator-v2 icon")
  v_a.icon = table.deepcopy(a_2.icon)
  v_a.corpse = table.deepcopy(a_2.corpse)
  v_a.chargeable_graphics = table.deepcopy(a_2.chargeable_graphics)
end
]]

local v_a_tech = ei_lib.raw.technology["electric-energy-accumulators"]
local a_2_tech = ei_lib.raw.technology["accumulator-v2"]
if a_2_tech and not mods["Paracelsin"] then
  a_2_tech.hidden = true
  a_2_tech.enabled = false
  v_a_tech.icon = table.deepcopy(a_2_tech.icon)
  v_a_tech.icon_size = table.deepcopy(a_2_tech.icon_size)
elseif v_a_tech then
  v_a_tech.icon = path.."/graphics/icons/accumulatortech_icon.png"
  v_a_tech.icon_size = 256
end
local v_a_item = ei_lib.raw.item.accumulator
local a_2_item = ei_lib.raw.item["accumulator-v2"]
if a_2_item and v_a_item then
  v_a_item.icon = table.deepcopy(a_2_item.icon)
  v_a_item.icon_size = table.deepcopy(a_2_item.icon_size)
  a_2_item.hidden = true
end

local a_2_recipe = ei_lib.raw.recipe["accumulator-v2"]
if a_2_recipe and not mods["Paracelsin"] then
  a_2_recipe.hidden = true
  a_2_recipe.enabled = false
end




