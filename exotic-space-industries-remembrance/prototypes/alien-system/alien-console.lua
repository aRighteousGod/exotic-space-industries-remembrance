ei_data = require("lib/data")

--====================================================================================================
--ALIEN CONSOLE
--restored from ei 0.69, formerly known as knowledge console—not (yet?) in use
--====================================================================================================

data:extend({
    {
        name = "ei-alien-console",
        type = "recipe-category",
    },
    {
        name = "ei-alien-console",
        type = "item",
        icon = ei_graphics_item_path.."alien-console.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-a",
        place_result = "ei-alien-console",
        stack_size = 1
    },
    {
        name = "ei-alien-console",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {"ei-energy-crystal", 10},
            {"lab", 1},
            {"ei-steel-mechanical-parts", 8}
        },
        result = "ei-alien-console",
        result_count = 1,
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-alien-console",
    },
    {
        name = "ei-alien-console-running",
        type = "recipe",
        category = "ei-alien-console",
        energy_required = 1000,
        ingredients = {},
        results = {},
        result_count = 1,
        enabled = false,
        hidden = true,
        icon = ei_graphics_other_path.."64_empty.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "b4",
    },
    {
        name = "ei-alien-console",
        type = "technology",
        icon = ei_graphics_tech_path.."alien-console.png",
        icon_size = 256,
        prerequisites = {"ei-computer-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-alien-console"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-scanner"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-alien-console",
        type = "assembling-machine",
        crafting_categories = {"ei-alien-console"},
        icon = ei_graphics_item_path.."alien-console.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-alien-console"
        },
        max_health = 1000,
        dying_explosion = "medium-explosion",
        collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
        selection_box = {{-1, -1}, {1, 1}},
        fixed_recipe = "ei-alien-console-running",
        map_color = ei_data.colors.assembler,
        crafting_speed = 1,
        energy_source = {
            type = "void",
        },
        energy_usage = "1W",
        animation = {
            filename = ei_graphics_entity_2_path.."alien-console.png",
            size = {256, 256},
            shift = {0, -0.3},
            scale = 0.16*2,
            line_length = 1,
            --lines_per_file = 2,
            frame_count = 1,
            -- animation_speed = 0.2,
        },
        working_visualisations = {
            {
              animation = 
              {
                filename = ei_graphics_entity_2_path.."alien-console_animation.png",
                size = {256, 256},
                shift = {0, -0.3},
                scale = 0.16*2,
                line_length = 8,
                lines_per_file = 8,
                frame_count = 64,
                animation_speed = 0.5,
                run_mode = "backward",
              }
            },
            {
                light = {
                type = "basic",
                intensity = 1,
                size = 15
                }
            }
        }
    },
    {
        name = "ei-scanner",
        type = "selection-tool",
        stack_size = 1,
        icon_size = 64,
        icon = ei_graphics_item_2_path.."scanner.png",
        -- flags = {"mod-openable"},
        selection_color = {r=0.2, g=0.8, b=0, a=0.5 },
        selection_mode = {"any-entity"},
        selection_cursor_box_type = "entity",
        alt_selection_color = {r=0.2, g=0.8, b=0, a=0.5 },
        alt_selection_cursor_box_type = "entity",
        alt_selection_mode = {"any-entity"},
        subgroup = "ei-repairs",
        order = "a",
    },
    {
        name = "ei-scanner",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-energy-crystal", amount = 10},
            {type = "item", name = "small-lamp", amount = 5},
            {type = "item", name = "plastic-bar", amount = 10},
            {type = "item", name = "ei-electronic-parts", amount = 15},
        },
        results = {
            {type = "item", name = "ei-scanner", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-scanner",
    },
})