if mods["lignumis"] then 
  -- data.raw.recipe["ei-dark-age-tech"].ingredients = data.raw.recipe["wood-science-pack"].ingredients
  -- data.raw.recipe["ei-steam-age-tech"].ingredients = data.raw.recipe["steam-science-pack"].ingredients

  local lignumis_dark_age = table.deepcopy(data.raw.recipe["ei-dark-age-tech"])
  lignumis_dark_age.ingredients = data.raw.recipe["wood-science-pack"].ingredients
  lignumis_dark_age.name = "lignumis-dark-age"

  local lignumis_steam_age = table.deepcopy(data.raw.recipe["ei-steam-age-tech"])
  lignumis_steam_age.ingredients = data.raw.recipe["steam-science-pack"].ingredients
  lignumis_steam_age.name = "lignumis-steam-age"

  data:extend({lignumis_dark_age,lignumis_steam_age})

  ei_lib.disable("wood-science-pack")
  ei_lib.disable("steam-science-pack")
  ei_lib.disable("steam-science-pack-steam")

  ei_lib.add_unlock_recipe("ei-steam-age","ei-steam-age-tech")
  ei_lib.add_unlock_recipe("ei-steam-age","lignumis-steam-age")
  
  data.raw.recipe['ei-dark-age-tech'].enabled = true
  data.raw.recipe['lignumis-dark-age'].enabled = true
  
  data.raw.item.wood.fuel_category = "chemical"
  data.raw.item.lumber.fuel_category = "chemical"
  
  data.raw.item.lumber.place_as_tile = table.deepcopy(data.raw.item.wood.place_as_tile)
  data.raw.item.wood.place_as_tile = nil
  
  ei_lib.recipe_swap("burner-mining-drill", "ei-iron-mechanical-parts", "wooden-gear-wheel")
  ei_lib.recipe_swap("burner-mining-drill", "iron-plate", "stone-brick")
  
  ei_lib.recipe_swap("ei-dark-age-lab", "iron-plate", "lumber")
  ei_lib.recipe_swap("ei-dark-age-lab", "ei-copper-mechanical-parts", "wooden-gear-wheel")
  
  ei_lib.recipe_swap("basic-construction-robot-copper", "basic-circuit-board", "wooden-gear-wheel")
  ei_lib.recipe_swap("ei-burner-assembler", "ei-copper-mechanical-parts", "wooden-gear-wheel")
  ei_lib.recipe_swap("steam-assembling-machine", "ei-steam-assembler", "ei-burner-assembler")
  ei_lib.recipe_swap("lumber-mill", "ei-steam-assembler", "ei-burner-assembler")

  ei_lib.recipe_swap("ei-burner-quarry", "transport-belt", "wood-transport-belt")
  ei_lib.recipe_swap("ei-burner-quarry", "iron-plate", "stone-brick")
  ei_lib.recipe_swap("ei-burner-quarry", "ei-iron-mechanical-parts", "wooden-gear-wheel")

  data.raw["assembling-machine"]["ei-steam-assembler"]["crafting_speed"] = 1.0

  if data.raw["assembling-machine"]["burner-assembling-machine"] then 
    data.raw["assembling-machine"]["ei-burner-assembler"].crafting_categories = table.deepcopy(data.raw["assembling-machine"]["burner-assembling-machine"].crafting_categories)
  end

  if data.raw["assembling-machine"]["steam-assembling-machine"] then
    data.raw["assembling-machine"]["ei-steam-assembler"].crafting_categories = table.deepcopy(data.raw["assembling-machine"]["steam-assembling-machine"].crafting_categories)
  end

  -- ei_lib.add_unlock_recipe("ei-dark-age","basic-circuit-board")
  -- ei_lib.remove_unlock_recipe("automation-2","steam-science-pack-steam")
end
