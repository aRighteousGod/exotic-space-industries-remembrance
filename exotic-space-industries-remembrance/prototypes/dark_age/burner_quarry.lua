data:extend({
    {
        name = modprefix.."burner-quarry",
        type = "item",
        icon = data.raw.item["burner-mining-drill"]["icon"],
        icon_size = 64,
        icon_mipmaps = 4,
        place_result = modprefix.."burner-quarry",
        stack_size = 20,
        subgroup = "extraction-machine",
        order = "a[items]-a[ei-burner-quarry]",
    },
    
    {
        name = modprefix.."burner-quarry",
        type = "recipe",
        enabled = false,
        ingredients = {
          {type = "item", name = "iron-plate", amount = 20},
          {type = "item", name = "iron-gear-wheel", amount = 20},
          {type = "item", name = "burner-mining-drill", amount = 10},
          {type = "item", name = "transport-belt", amount = 10},
        },
        results = {{type = "item", name = modprefix.."burner-quarry", amount = 1}},
        energy_required = 10,
    }
})

data:extend({
    {
        name = modprefix.."electric-quarry",
        type = "item",
        icon = data.raw.item["electric-mining-drill"]["icon"],
        icon_size = 64,
        icon_mipmaps = 4,
        place_result = modprefix.."electric-quarry",
        stack_size = 20,
        subgroup = "extraction-machine",
        order = "a[items]-b[ei-electric-quarry]",
    },
    
    {
        name = modprefix.."electric-quarry",
        type = "recipe",
        enabled = false,
        ingredients = {
          {type = "item", name = "iron-plate", amount = 20},
          {type = "item", name = "iron-gear-wheel", amount = 20},
          {type = "item", name = "electric-mining-drill", amount = 10},
          {type = "item", name = "transport-belt", amount = 20},
        },
        results = {{type = "item", name = modprefix.."electric-quarry", amount = 1}},
        energy_required = 10,
    }
})

local burner_quarry = table.deepcopy(data.raw["mining-drill"]["burner-mining-drill"])
burner_quarry.name = modprefix.."burner-quarry"
burner_quarry.minable = {mining_time = 1, result = modprefix.."burner-quarry"}
burner_quarry.resource_searching_radius = 10
burner_quarry.module_specification = {module_slots = 0}
burner_quarry.mining_speed = 0.5
burner_quarry.base_productivity = 1.0
data:extend({burner_quarry})

local electric_quarry = table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"])
electric_quarry.name = modprefix.."electric-quarry"
electric_quarry.minable = {mining_time = 1, result = modprefix.."electric-quarry"}
electric_quarry.resource_searching_radius = 20
electric_quarry.energy_usage = "1MW"
electric_quarry.energy_source.emissions_per_minute.pollution = electric_quarry.energy_source.emissions_per_minute.pollution * 10
data:extend({electric_quarry})

ei_lib.add_unlock_recipe(modprefix.."burner-assembler",modprefix.."burner-quarry")

