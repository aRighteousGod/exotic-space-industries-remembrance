if mods["lignumis"] then 
  -- data.raw.recipe["ei-dark-age-tech"].ingredients = data.raw.recipe["wood-science-pack"].ingredients
  -- data.raw.recipe["ei-steam-age-tech"].ingredients = data.raw.recipe["steam-science-pack"].ingredients

  local lignumis_dark_age = table.deepcopy(data.raw.recipe["ei-dark-age-tech"])
  lignumis_dark_age.ingredients = data.raw.recipe["wood-science-pack"].ingredients
  lignumis_dark_age.surface_conditions =
      {
          {
            property = "gravity",
            min = 4,
            max = 4
          }
      }
  lignumis_dark_age.name = "lignumis-dark-age"

  local lignumis_steam_age = table.deepcopy(data.raw.recipe["ei-steam-age-tech"])
  lignumis_steam_age.ingredients = data.raw.recipe["steam-science-pack"].ingredients
  lignumis_steam_age.surface_conditions =
        {
           {
              property = "gravity",
              min = 4,
              max = 4
            }
        }
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

  --alt recipes for burner lab, drill, mechanical and burner inserters
  data:extend({
      {
        name = "ei-dark-age-lab-lignumis",
        type = "recipe",
        category = "crafting",
        energy_required = ei_lib.raw.recipe["ei-dark-age-lab"].energy_required*1.25,
        ingredients =
        {
            {type="item", name="wooden-gear-wheel", amount=4},
            {type="item", name="gold-plate", amount=6},
            {type="item", name="stone-brick", amount=4},
        },
        results = {{type="item", name="ei-dark-age-lab", amount=1}},
        enabled = true,
        always_show_made_in = false,
        main_product = "ei-dark-age-lab",
    },
    {
        name = "ei-burner-mining-drill-lignumis",
        type = "recipe",
        category = "crafting",
        energy_required = ei_lib.raw.recipe["burner-mining-drill"].energy_required*1.25,
        ingredients =
        {
            {type="item", name="stone-furnace", amount=1},
            {type="item", name="gold-plate", amount=3},
            {type="item", name="wooden-gear-wheel", amount=3},

        },
        results = {{type="item", name="burner-mining-drill", amount=1}},
        enabled = true,
        always_show_made_in = false,
        main_product = "burner-mining-drill",
    },
    {
        name = "ei-mechanical-inserter-lignumis",
        type = "recipe",
        category = "crafting",
        energy_required = ei_lib.raw.recipe["ei-mechanical-inserter"].energy_required*1.25, --lefty loosey
        ingredients =
        {
            {type="item", name="burner-inserter", amount=1},
            {type="item", name="wooden-gear-wheel", amount=10},
        },
        results = {{type="item", name="ei-mechanical-inserter", amount=1}},
        enabled = false,
        always_show_made_in = false,
        main_product = "ei-mechanical-inserter",
    },
    {
        name = "ei-burner-inserter-lignumis",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="gold-plate", amount=1},
            {type="item", name="wooden-gear-wheel", amount=2},
        },
        results = {{type="item", name="burner-inserter", amount=1}},
        enabled = true,
        always_show_made_in = false,
        main_product = "burner-inserter",
    },
  })

  ei_lib.raw.recipe["burner-assembling-machine"].surface_conditions =
  {
      {
        property = "gravity",
        min = 4,
        max = 4
      }
  }
  ei_lib.raw.recipe["steam-assembling-machine"].surface_conditions =
  {
      {
        property = "gravity",
        min = 4,
        max = 4
      }
  }
  ei_lib.add_unlock_recipe("ei-mechanical-inserter","ei-mechanical-inserter-lignumis")

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
  ei_lib.raw.item["gold-bacteria"].spoil_result = "ei-gold-chunk"

  ei_lib.merge_item("ei-gold-chunk","gold-ore",false,true)
  --ei_lib.merge_item("gold-plate","ei-gold-ingot",true)
  ei_lib.merge_fluid("ei-molten-gold","molten-gold",false,true)

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