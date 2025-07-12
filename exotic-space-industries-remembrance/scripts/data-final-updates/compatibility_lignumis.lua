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
  
  ei_lib.raw.recipe['ei-dark-age-tech'].enabled = true
  ei_lib.raw.recipe['lignumis-dark-age'].enabled = true
  
  ei_lib.raw.item.wood.fuel_category = "chemical"
  ei_lib.raw.item.lumber.fuel_category = "chemical"
  
  ei_lib.raw.item.lumber.place_as_tile = table.deepcopy(data.raw.item.wood.place_as_tile)
  ei_lib.raw.item.wood.place_as_tile = nil
  
  ei_lib.recipe_swap("burner-mining-drill", "ei-iron-mechanical-parts", "wooden-gear-wheel")
  ei_lib.recipe_swap("burner-mining-drill", "iron-plate", "stone-brick")
  
  ei_lib.recipe_swap("ei-dark-age-lab", "iron-plate", "lumber")
  ei_lib.recipe_swap("ei-dark-age-lab", "ei-copper-mechanical-parts", "wooden-gear-wheel")
  
  ei_lib.recipe_swap("burner-inserter", "ei-copper-mechanical-parts", "wooden-gear-wheel")
  ei_lib.recipe_swap("ei-mechanical-inserter", "ei-iron-mechanical-parts", "wooden-gear-wheel")
  ei_lib.recipe_swap("steam-assembling-machine", "ei-burner-assembler", "burner-assembling-machine")
  ei_lib.recipe_swap("lumber-mill", "ei-burner-assembler", "steam-assembling-machine")

  ei_lib.raw["assembling-machine"]["burner-assembling-machine"]["crafting_speed"] = ei_lib.raw["assembling-machine"]["ei-burner-assembler"]["crafting_speed"]

  ei_lib.raw["assembling-machine"]["steam-assembling-machine"]["crafting_speed"] = ei_lib.raw["assembling-machine"]["ei-steam-assembler"]["crafting_speed"]

  local ei_burner = ei_lib.raw["assembling-machine"]["ei-burner-assembler"]
  local lig_burner = ei_lib.raw["assembling-machine"]["burner-assembling-machine"]
  for _,mergefrom in pairs(lig_burner.crafting_categories) do
      if not ei_lib.table_contains_value(ei_burner.crafting_categories, mergefrom) then
        table.insert(ei_burner.crafting_categories,mergefrom)
      end
    end

  local ei_steamer = ei_lib.raw["assembling-machine"]["ei-steam-assembler"]
  local lig_steamer = ei_lib.raw["assembling-machine"]["steam-assembling-machine"]
  for _,mergefrom in pairs(lig_steamer.crafting_categories) do
      if not ei_lib.table_contains_value(ei_steamer.crafting_categories, mergefrom) then
        table.insert(ei_steamer.crafting_categories,mergefrom)
      end
    end
  ei_lib.raw.recipe["molten-gold"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,allow_productivity=false
}
 local gp = ei_lib.raw.recipe["gold-plate"]
  ei_lib.raw.recipe["gold-plate"].ingredients = {
    {type="item",name="gold-ore",amount=3}
}
  ei_lib.raw.recipe["gold-plate"].results = {
    {type="item",name="gold-plate",amount=1},
    {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
}
  ei_lib.raw.recipe["gold-plate"] = {
    icon = Lignumis.graphics .. "icons/gold-plate.png",
    subgroup = "raw-material",
    color_hint = { text = "C" },
    order = "a[smelting]-0[gold-plate]",
  }
  ei_lib.merge_item("ei-gold-chunk","gold-ore",false)
  --ei_lib.merge_item("gold-plate","ei-gold-ingot",true)
  ei_lib.merge_fluid("ei-molten-gold","molten-gold",false)

  data:extend{
    {
        name = "ei-cast-gold-plate",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-gold", amount = 10},
        },
        results = {
            {type = "item", name = "gold-plate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "gold-plate",
        hide_from_player_crafting = true,
    },
  }
  ei_lib.add_unlock_recipe("ei-arc-furnace", "ei-cast-gold-plate")
  end
  
  -- ei_lib.add_unlock_recipe("ei-dark-age","basic-circuit-board")
  -- ei_lib.remove_unlock_recipe("automation-2","steam-science-pack-steam")