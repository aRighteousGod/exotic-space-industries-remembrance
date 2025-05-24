ei_data = require("lib/data")

--====================================================================================================
--CASTER
--====================================================================================================
local caster_glow = {
    type = "sprite",
    name = "caster_glow",
    filename = ei_graphics_glow_path.."small_pngs/frame_count_3/glow_3.png",
    width = 205,
    height = 207,
    scale = 1,
    frame_count = 3,
    animation_speed = 8,
}

data:extend({
        caster_glow,
    {
        name = "ei-casting",
        type = "recipe-category",
    },
    {
        name = "ei-caster",
        type = "item",
        icon = ei_graphics_item_path.."caster.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c",
        place_result = "ei-caster",
        stack_size = 50
    },
    {
        name = "ei-caster",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="electronic-circuit", amount=2},
            {type="item", name="electric-engine-unit", amount=2},
            {type="item", name="steel-plate", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=6}
        },
        results = {{type="item", name="ei-caster", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-caster",
    },
    {
        name = "ei-caster",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."caster.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-caster"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-casting"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            emissions_per_minute = { pollution = 1 },
        },
        energy_usage = "1.2MW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."caster.png",
                size = {512,512},
                width = 512,
                height = 512,
                shift = {0,-0.2},
    	        scale = 0.44/2,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."caster_animation.png",
                    size = {512,512},
                    width = 512,
                    height = 512,
                    shift = {0,-0.2},
    	            scale = 0.44/2,
                    line_length = 4,
                    lines_per_file = 4,
                    frame_count = 16,
                    animation_speed = 0.6,
                    run_mode = "backward",
                  }
                },
                {

                    light = {
                    type = "basic",
                    sprite = "caster_glow",
                    flicker_interval = 9,
                    flicker_min_modifier = 0.6,
                    flicker_max_modifier = 0.9,
                    offset_flicker = true,
                    intensity = 0.9,
                    size = 14,
                    color = {r = 0.6, g = 0.4, b = 0.0}, -- darker orange
                    blend_mode = "multiplicative",
                    apply_runtime_tint = true,
                    draw_as_glow = true,
                    }
                },
                {

                    light = {
                    type = "basic",
                    sprite = "caster_glow",
                    flicker_interval = 7,
                    flicker_min_modifier = 0.8,
                    flicker_max_modifier = 1,
                    offset_flicker = true,
                    intensity = 1,
                    size = 5,
                    color = {r = 1.0, g = 0.5, b = 1.0}, -- White ish
                    apply_runtime_tint = true,
                    }
                }
            },
        },
        allowed_effects = {"speed", "consumption", "pollution","quality"},
        module_slots = 2,
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_electricity,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
                },
                production_type = "input",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-cast-iron-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-iron", amount = 10},
        },
        results = {
            {type = "item", name = "iron-plate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "iron-plate",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-cast-copper-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-copper", amount = 10},
        },
        results = {
            {type = "item", name = "copper-plate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "copper-plate",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-cast-lead-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-lead", amount = 10},
        },
        results = {
            {type = "item", name = "ei-lead-ingot", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-lead-ingot",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-cast-gold-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-gold", amount = 10},
        },
        results = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-gold-ingot",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-cast-steel-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-steel", amount = 10},
        },
        results = {
            {type = "item", name = "steel-plate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "steel-plate",
        hide_from_player_crafting = true,
    },
})