--File to alter data in base/space-age game files

--Adding Fluidboxes to the asteroid crusher
local crusher = data.raw["assembling-machine"]["crusher"]
crusher.fluid_boxes = {
  {
    production_type = "input",
    volume = 1000,
    pipe_connections = {
      { flow_direction="input-output", direction = defines.direction.west, position = {-0.5, -1} },
      { flow_direction="input-output", direction = defines.direction.west, position = {-0.5, 1} },
      { flow_direction="input-output", direction = defines.direction.east, position = {0.5, 0} }}
  },
  {
    production_type = "output",
    volume = 1000,
    pipe_connections = {
      { flow_direction="output", direction = defines.direction.west, position = {-0.5, 0} }}
  },
  {
    production_type = "output",
    volume = 1000,
    pipe_connections = {
      { flow_direction="output", direction = defines.direction.east, position = {0.5, -1} }}
  },
  {
    production_type = "output",
    volume = 1000,
    pipe_connections = {
      { flow_direction="output", direction = defines.direction.east, position = {0.5, 1} }}
  }
}

crusher.fluid_boxes_off_when_no_fluid_recipe = true;

--adding the asteroid spawn definitions to the original data
--had to comment out the code block that added definitions to the connections due to some NIL error
-- theoretically the additional asteroids shouldn't spawn in between the planets because of this but they do anyway. Idk how
local planets = data.raw["planet"]
local locations = data.raw["space-location"]
local connections = data.raw["space-connection"]
local more_asteroid_util = require("scripts/control/more_asteroids_spawners.lua")

local planet_stuffmapping = {
  ["nauvis"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_vulcanus, 0.1),
  ["vulcanus"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_vulcanus, 0.9),
  ["gleba"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_gleba, 0.9),
  ["fulgora"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_fulgora, 0.9),
  ["gaia"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_gaia, 0.9),
  ["aquilo"] = more_asteroid_util.spawn_definitions(more_asteroid_util.fulgora_aquilo, 0.9),
  ["cerys"] = more_asteroid_util.spawn_definitions(more_asteroid_util.fulgora_cerys, 0.9),
  ["muluna"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_muluna, 0.9),
  ["maraxsis"] = more_asteroid_util.spawn_definitions(more_asteroid_util.vulcanus_maraxsis, 0.9)
}
local location_stuffmapping = {
  ["solar-system-edge"] = more_asteroid_util.spawn_definitions(more_asteroid_util.aquilo_solar_system_edge, 0.9),
  ["shattered-planet"] = more_asteroid_util.spawn_definitions(more_asteroid_util.shattered_planet_trip, 0.8)
}

local connection_stuffmapping = {
  ["nauvis-vulcanus"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_vulcanus),
  ["nauvis-gleba"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_gleba),
  ["nauvis-fulgora"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_fulgora),
  ["nauvis-gaia"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_gaia),
  ["vulcanus-gleba"] = more_asteroid_util.spawn_definitions(more_asteroid_util.vulcanus_gleba),
  ["gleba-fulgora"] = more_asteroid_util.spawn_definitions(more_asteroid_util.gleba_fulgora),
  ["gleba-aquilo"] = more_asteroid_util.spawn_definitions(more_asteroid_util.gleba_aquilo),
  ["fulgora-aquilo"] = more_asteroid_util.spawn_definitions(more_asteroid_util.fulgora_aquilo),
  ["aquilo-solar-system-edge"] = more_asteroid_util.spawn_definitions(more_asteroid_util.aquilo_solar_system_edge),
  ["solar-system-edge-shattered-planet"] = more_asteroid_util.spawn_definitions(more_asteroid_util.shattered_planet_trip),
  ["fulgora-cerys"] = more_asteroid_util.spawn_definitions(more_asteroid_util.fulgora_cerys),
  ["nauvis-muluna"] = more_asteroid_util.spawn_definitions(more_asteroid_util.nauvis_muluna),
  ["vulcanus-maraxsis"] = more_asteroid_util.spawn_definitions(more_asteroid_util.vulcanus_maraxsis),
  ["fulgora-maraxsis"] = more_asteroid_util.spawn_definitions(more_asteroid_util.fulgora_maraxsis)
}


for _,planet in pairs(planets) do
  if planet_stuffmapping[planet.name] ~= nil then
    if planet.asteroid_spawn_definitions ~= nil then
      for _,def in pairs(planet_stuffmapping[planet.name]) do
        if not mods["any-planet-start"] then
          table.insert(planet.asteroid_spawn_definitions, def)
        else 
          if (settings.startup["aps-planet"].value ~= planet.name) then
            table.insert(planet.asteroid_spawn_definitions, def)
          elseif (string.find(def.asteroid, "medium") == nil) and (planet.asteroid_spawn_definitions ~= nil) then
            --local name = planet.name
            --table.insert(planet.asteroid_spawn_definitions, def)
          end
        end
      end
    else 
      planet.asteroid_spawn_definitions = planet_stuffmapping[planet.name]
    end
  end
end

for _,location in pairs(locations) do
  if location_stuffmapping[location.name] ~= nil then
    if location.asteroid_spawn_definitions ~= nil then
      for _,def in pairs(location_stuffmapping[location.name]) do
        table.insert(location.asteroid_spawn_definitions, def)
      end
    else
      location.asteroid_spawn_definitions = location_stuffmapping[location.name]
    end
  end
end

for _,connection in pairs(connections) do
  if connection_stuffmapping[connection.name] ~= nil then
    if connection.asteroid_spawn_definitions ~= nil then
      for _,def in pairs(connection_stuffmapping[connection.name]) do
        table.insert(connection.asteroid_spawn_definitions, def)
      end
    else
      connection.asteroid_spawn_definitions = connection_stuffmapping[connection.name]
    end
  end
end



--add recipes to tech research
table.insert(data.raw["technology"]["space-platform"].effects, {type = "unlock-recipe", recipe = "ei-uranium-asteroid-crushing"})
table.insert(data.raw["technology"]["space-platform"].effects, {type = "unlock-recipe", recipe = "ei-petrified-asteroid-crushing"})

table.insert(data.raw["technology"]["planet-discovery-vulcanus"].effects, {type = "unlock-recipe", recipe = "ei-rock-asteroid-crushing"})
table.insert(data.raw["technology"]["planet-discovery-fulgora"].effects, {type = "unlock-recipe", recipe = "ei-scrap-asteroid-crushing"})
table.insert(data.raw["technology"]["planet-discovery-gleba"].effects, {type = "unlock-recipe", recipe = "ei-organic-asteroid-crushing"})

table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-uranium-asteroid-crushing"})
table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-petrified-asteroid-crushing"})
table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-rock-asteroid-crushing"})
table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-scrap-asteroid-crushing"})
table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-organic-asteroid-crushing"})

table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-chemical-asteroid-crushing"})
table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-advanced-chemical-asteroid-crushing"})

local recipes = {"ei-uranium-asteroid-crushing", 
"ei-rock-asteroid-crushing", 
"ei-scrap-asteroid-crushing",
"ei-organic-asteroid-crushing",
"ei-petrified-asteroid-crushing",
"ei-chemical-asteroid-crushing",
"ei-advanced-uranium-asteroid-crushing",
"ei-advanced-petrified-asteroid-crushing",
"ei-advanced-rock-asteroid-crushing",
"ei-advanced-scrap-asteroid-crushing",
"ei-advanced-organic-asteroid-crushing",
"ei-advanced-chemical-asteroid-crushing"}


for i=1, 12 do
  table.insert(data.raw["technology"]["asteroid-productivity"].effects, {type = "change-recipe-productivity", recipe = recipes[i], change = 0.1})
end