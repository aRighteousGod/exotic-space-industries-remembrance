

--====================================================================================================
--STEAM INSERTER
--====================================================================================================

data:extend({
    {
        name = "ei-steam-inserter",
        type = "item",
        icon = ei_graphics_item_path.."steam-inserter.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "inserter",
        order = "a[burner-inserter]-a",
        place_result = "ei-steam-inserter",
        stack_size = 50
    },
    {
        name = "ei-steam-inserter",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="burner-inserter", amount=1},
            {type="item", name="ei-steam-engine", amount=1},
        },
        results = {{type="item", name="ei-steam-inserter", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-inserter",
    },
    {
        name = "ei-steam-long-inserter",
        type = "item",
        icon = ei_graphics_item_path.."steam-long-inserter.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "inserter",
        order = "a[burner-inserter]-b",
        place_result = "ei-steam-long-inserter",
        stack_size = 50
    },
    {
        name = "ei-steam-long-inserter",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="ei-steam-inserter", amount=1},
            {type="item", name="ei-steel-mechanical-parts", amount=1},
        },
        results = {{type="item", name="ei-steam-long-inserter", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-long-inserter",
    },
    {
        name = "ei-steam-inserter",
        type = "technology",
        icon = ei_graphics_tech_path.."steam-inserter.png",
        icon_size = 128,
        prerequisites = {"ei-steam-power"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-steam-inserter"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-long-inserter"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    }, 
})

-- deep copy burner inserter
local inserter = table.deepcopy(data.raw["inserter"]["inserter"])

-- set name and icon
inserter.name = "ei-steam-inserter"
inserter.icon = ei_graphics_item_path.."steam-inserter.png"

inserter.minable.result = "ei-steam-inserter"
inserter.fast_replaceable_group = "pipe"
inserter.next_upgrade = nil

-- set new platform picture
inserter.platform_picture = {
    sheet = {
        filename = ei_graphics_entity_path.."steam-inserter_platform.png",
        priority = "extra-high",
        width = 105,
        height = 79,
        scale = 0.5
    }
}

-- shift all hand pictures by some pixels
local hand_shift = util.by_pixel(0, -7)

local pictures_to_shift = {
    "hand_base_shadow",
    "hand_closed_shadow",
    "hand_open_shadow",
    "hand_base_picture",
    "hand_closed_picture",
    "hand_open_picture",
}


for _, picture in ipairs(pictures_to_shift) do
    inserter[picture].shift = hand_shift
end
inserter.icon_draw_specification = {shift = {0, 0}, scale = 1, scale_for_many = 0.75, render_layer = "air-entity-info-icon"}
-- set energy source to steam fluid box
inserter.energy_source = {
    type = "fluid",
    fluid_box = {   
        filter = "steam",
        volume = 200,
        secondary_draw_order = -1,
        pipe_covers = pipecoverspictures(),
        --pipe_picture = ei_pipe_steam,
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {0, 0}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {0, 0}}
        },
        production_type = "input-output",
    },
    effectivity = 0.7,
    scale_fluid_usage = true,
}

-- steam long handed inserter
local long_inserter = table.deepcopy(data.raw["inserter"]["long-handed-inserter"])

-- set name and icon
long_inserter.name = "ei-steam-long-inserter"
long_inserter.icon = ei_graphics_item_path.."steam-long-inserter.png"

long_inserter.minable.result = "ei-steam-long-inserter"
long_inserter.fast_replaceable_group = "pipe"
long_inserter.next_upgrade = nil

-- set new platform picture
long_inserter.platform_picture = {
    sheet = {
        filename = ei_graphics_entity_path.."steam-inserter_platform.png",
        priority = "extra-high",
        width = 105,
        height = 79,
        scale = 0.5
    }
}

for _, picture in ipairs(pictures_to_shift) do
    long_inserter[picture].shift = hand_shift
end
long_inserter.icon_draw_specification = {shift = {0, 0}, scale = 1, scale_for_many = 0.75, render_layer = "air-entity-info-icon"}
-- set energy source to steam fluid box
long_inserter.energy_source = {
    type = "fluid",
    fluid_box = {   
        filter = "steam",
        volume = 200,
        pipe_covers = pipecoverspictures(),
        secondary_draw_order = -1,
        --pipe_picture = ei_pipe_steam,
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {0, 0}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {0, 0}}
        },
        production_type = "input-output",
    },
    effectivity = 0.7,
    scale_fluid_usage = true,
}

-- add to data
data:extend({inserter, long_inserter})