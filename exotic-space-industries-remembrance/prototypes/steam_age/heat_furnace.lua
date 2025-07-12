local heat_furnace_entity = table.deepcopy(data.raw["furnace"]["steel-furnace"])
heat_furnace_entity.name = "ei-heat-steel-furnace"
heat_furnace_entity.minable.result = "ei-heat-steel-furnace"
heat_furnace_entity.energy_usage = "135kW"
heat_furnace_entity.energy_source = {
  type = 'heat',
  max_temperature = 275,
  min_working_temperature = 185,
  specific_heat = ei_data.specific_heat,
  max_transfer = '10MW',
  emissions_per_minute = { pollution = 1.25 },
  connections = {
      {position = { -1.0,  0.0 }, direction = defines.direction.west},
      {position = {  0.0,  1.0 }, direction = defines.direction.south},
      {position = {  1.0,  0.0 }, direction = defines.direction.east},
      {position = {  0.0, -1.0 }, direction = defines.direction.north}
  }
}


local heat_furnace_item = table.deepcopy(data.raw["item"]["steel-furnace"])
heat_furnace_item.name = "ei-heat-steel-furnace"
heat_furnace_item.place_result = "ei-heat-steel-furnace"

local heat_furnace_recipe = table.deepcopy(data.raw["recipe"]["steel-furnace"])
heat_furnace_recipe.name = "ei-heat-steel-furnace"
heat_furnace_recipe.results = {{type="item", name="ei-heat-steel-furnace", amount=1}}
heat_furnace_recipe.main_product = "ei-heat-steel-furnace"

data:extend({heat_furnace_item,heat_furnace_entity,heat_furnace_recipe})
ei_lib.add_unlock_recipe("advanced-material-processing", "ei-heat-steel-furnace")
