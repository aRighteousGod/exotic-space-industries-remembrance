--====================================================================================================
--GAIA PUMP
--====================================================================================================

data:extend({
    {
        name = "ei-gaia-pump",
        type = "item",
        icon = ei_graphics_item_path.."gaia-pump.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-d",
        place_result = "ei-gaia-pump",
        stack_size = 20
    },
    {
        name = "ei-gaia-pump",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="offshore-pump", amount=1},
            {type="item", name="ei-alien-resin", amount=2},
        },
        results = {{type="item", name="ei-gaia-pump", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-gaia-pump",
    },
})

local pump = util.table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

pump.name = "ei-gaia-pump"
pump.fluid = "ei-morphium"
pump.minable.result = "ei-gaia-pump"

data:extend({pump})
