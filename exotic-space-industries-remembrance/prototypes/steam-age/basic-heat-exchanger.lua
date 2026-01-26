-- add basic heat exchanger
-- with max temp of 275 dec

ei_data = require("lib/data")

--====================================================================================================
--BASIC HEAT EXCHANGER
--====================================================================================================
local exchanger_tint = {1,1,0.45}
data:extend({
    {
        name = "ei-basic-heat-exchanger",
        type = "item",
        icon = data.raw.item["heat-exchanger"].icon,
        icon_size = 64,
        icons = {{icon=data.raw.item["heat-exchanger"].icon, tint=exchanger_tint, icon_size = 64}},
        subgroup = "energy",
        order = "f[nuclear-energy]-c[1heat-exchanger]",
        place_result = "ei-basic-heat-exchanger",
        stack_size = 50,
        weight = 40*kg,
        random_tint_color = item_tints.iron_rust
    },
    {
        name = "ei-basic-heat-exchanger",
        type = "recipe",
        category = "crafting",
        energy_required = 3,
        ingredients =
        {
            {type="item", name="ei-iron-beam", amount=2},
            {type="item", name="iron-plate", amount=6},
            {type="item", name="copper-plate", amount=50},
            {type="item", name="pipe", amount=10},
        },
        results = {{type="item", name="ei-basic-heat-exchanger", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-basic-heat-exchanger",
    },
})

local exchanger = table.deepcopy(data.raw["boiler"]["heat-exchanger"])
exchanger.minable.result = "ei-basic-heat-exchanger"
exchanger.target_temperature = 240
exchanger.energy_consumption = "2MW"
exchanger.energy_source.max_temperature = 275
exchanger.energy_source.specific_heat = ei_data.specific_heat
exchanger.energy_source.minimum_glow_temperature = 180
exchanger.energy_source.max_transfer = "100MW"
exchanger.energy_source.min_working_temperature = 240
exchanger.pictures.north.structure.layers[1].tint = exchanger_tint
exchanger.pictures.east.structure.layers[1].tint = exchanger_tint
exchanger.pictures.south.structure.layers[1].tint = exchanger_tint
exchanger.pictures.west.structure.layers[1].tint = exchanger_tint
exchanger.name = "ei-basic-heat-exchanger"

data:extend({exchanger})