ei_lib = require("lib/lib")

--====================================================================================================
--MECHANICAL INSERTER
--====================================================================================================

data:extend({
    {
        name = "ei-mechanical-inserter",
        type = "item",
        icon = ei_graphics_item_path.."mechanical-inserter.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "inserter",
        order = "0a-a[burner-inserter]",
        place_result = "ei-mechanical-inserter",
        stack_size = 50
    },
    {
        name = "ei-mechanical-inserter",
        type = "recipe",
        category = "crafting",
        energy_required = 8, --winding the springs
        ingredients =
        {
            {type="item", name="burner-inserter", amount=1},
            {type="item", name="ei-iron-mechanical-parts", amount=10},
        },
        results = {{type="item", name="ei-mechanical-inserter", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-mechanical-inserter",
    },
    {
        name = "ei-mechanical-long-inserter",
        type = "item",
        icon = ei_graphics_item_path.."mechanical-long-inserter.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "inserter",
        order = "0b-a[burner-inserter]",
        place_result = "ei-mechanical-long-inserter",
        stack_size = 50
    },
    {
        name = "ei-mechanical-long-inserter",
        type = "recipe",
        category = "crafting",
        energy_required = 16, --winding the steel springs
        ingredients =
        {
            {type="item", name="ei-mechanical-inserter", amount=1},
            {type="item", name="ei-steel-mechanical-parts", amount=10},
        },
        results = {{type="item", name="ei-mechanical-long-inserter", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-mechanical-long-inserter",
    },
    {
        name = "ei-mechanical-inserter",
        type = "technology",
        icon = ei_graphics_tech_path.."mechanical-inserter-tech-256x256.png",
        icon_size = 256,
        prerequisites = {"ei-dark-age-tech"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-mechanical-inserter"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-mechanical-long-inserter"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["dark-age"],
            time = 20
        },
        age = "dark-age",
    }, 
})

-- deep copy inserter
local inserter = table.deepcopy(data.raw["inserter"]["inserter"])

-- set name and icon
inserter.name = "ei-mechanical-inserter"
inserter.icon = ei_graphics_item_path.."mechanical-inserter.png"

inserter.minable.result = "ei-mechanical-inserter"
inserter.fast_replaceable_group = "inserter"
inserter.next_upgrade = nil
inserter.filter_count = 1
inserter.rotation_speed = 0.0014
inserter.extension_speed = 0.0035

-- set new platform picture
inserter.platform_picture = {
    sheet = {
        filename = ei_graphics_entity_path.."mechanical-inserter-platform.png",
        priority = "extra-high",
        width = 105,
        height = 79,
        shift = util.by_pixel(1.5, 7.5-1),
        scale = 0.5
    }
}
inserter.hand_base_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-base.png",
    priority = "extra-high",
    width = 32,
    height = 136,
    scale = 0.25
}
inserter.hand_closed_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-closed.png",
    priority = "extra-high",
    width = 72,
    height = 164,
    scale = 0.25
}
inserter.hand_open_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-open.png",
    priority = "extra-high",
    width = 72,
    height = 164,
    scale = 0.25
}
-- set energy source to void
inserter.energy_source = {
    type = "void",
    emissions_per_minute = {},
    render_no_power_icon = false,
    render_no_network_icon = false
}

-- mechanical long handed inserter
local long_inserter = table.deepcopy(data.raw["inserter"]["long-handed-inserter"])

-- set name and icon
long_inserter.name = "ei-mechanical-long-inserter"
long_inserter.icon = ei_graphics_item_path.."mechanical-long-inserter.png"

long_inserter.minable.result = "ei-mechanical-long-inserter"
long_inserter.fast_replaceable_group = "inserter"
long_inserter.next_upgrade = nil
long_inserter.filter_count = 1
long_inserter.rotation_speed = 0.0013
long_inserter.extension_speed = 0.0035

-- set new platform picture
long_inserter.platform_picture = {
    sheet = {
        filename = ei_graphics_entity_path.."mechanical-inserter-platform.png",
        priority = "extra-high",
        width = 105,
        height = 79,
        shift = util.by_pixel(1.5, 7.5-1),
        scale = 0.5
    }
}
long_inserter.hand_base_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-base.png",
    priority = "extra-high",
    width = 32,
    height = 136,
    scale = 0.25
}
long_inserter.hand_closed_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-closed.png",
    priority = "extra-high",
    width = 72,
    height = 164,
    scale = 0.25
}
long_inserter.hand_open_picture = {
    filename = ei_graphics_entity_path.."mechanical-inserter-hand-open.png",
    priority = "extra-high",
    width = 72,
    height = 164,
    scale = 0.25
}
-- set energy source to void
long_inserter.energy_source = {
    type = "void",
    emissions_per_minute = {},
    render_no_power_icon = false,
    render_no_network_icon = false
}

-- add to data
data:extend({inserter, long_inserter})