for _, spec in ipairs{{"slow", 1 / 1800, 120}, {"fast", 1 / 30, 1}} do
  local rocket = table.deepcopy(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"])
  rocket.name = "ei-rocket-qc-" .. spec[1]
  rocket.engine_starting_speed = spec[2]
  local silo = table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])
  silo.name = "ei-rocket-qc-silo-" .. spec[1]
  silo.rocket_entity = rocket.name
  silo.launch_wait_time = spec[3]
  data:extend{rocket, silo}
end
local source = data.raw["simple-entity"]["ei-rocket-launch-pollution"]
assert(source.hidden and source.hidden_in_factoriopedia and not source.selectable_in_game)
assert(source.icon == "__base__/graphics/icons/rocket-part.png" and source.icon_size == 64)
assert(source.localised_name[1] == "exotic-industries-informatron.rocket-launch-pollution")
assert(not source.minable and not source.dying_explosion and not source.factoriopedia_simulation)
