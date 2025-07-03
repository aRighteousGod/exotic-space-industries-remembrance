ei_data = require("lib/data")

--====================================================================================================
--EXOTIC ASSEMBLER
--====================================================================================================

data:extend({
    {
        name = "ei-exotic-assembler",
        type = "recipe-category",
    },
    {
        name = "ei-exotic-assembler",
        type = "item",
        icon = ei_graphics_item_path.."exotic-assembler.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "c[assembling-machine-3]-x",
        place_result = "ei-exotic-assembler",
        stack_size = 50
    },
    {
        name = "ei-exotic-assembler",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="assembling-machine-3", amount=2},
            {type="item", name="ei-carbon-structure", amount=5},
            {type="item", name="ei-superior-data", amount=5},
            {type="item", name="ei-eu-magnet", amount=5},
            {type = "fluid", name = "ei-liquid-oxygen", amount = 25},
        },
        results = {{type="item", name="ei-exotic-assembler", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-exotic-assembler",
    },
    {
        name = "ei-high-tech-parts",
        type = "technology",
        icon = ei_graphics_tech_path.."high-tech-parts.png",
        icon_size = 128,
        prerequisites = {"ei-eu-circuit"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-exotic-assembler"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-high-tech-parts"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["both-quantum-age"],
            time = 20
        },
        age = "both-quantum-age",
    },
    {
        name = "ei-matter-explosion",
        type = "explosion",
        flags = {"not-on-map"},
        animations = {
            {
                filename = ei_graphics_other_path.."plasma-explosion.png",
                size = {1944/6, 1248/3},
                shift = {0, -6},
                scale = 3,
                line_length = 6,
                lines_per_file = 6,
                frame_count = 36,
                animation_speed = 0.3,
                draw_as_glow = true,
                priority = "high",
            },
        },
        light_intensity_peak_end_progress = 0.6,
        light_size_peak_start_progress = 0.0675,
        light_size_peak_end_progress = 0.9,
        scale_out_duration = 45,
        scale_end = 0.85,
        scale_animation_speed = true,
        light = {
            intensity = 0.85,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 0.45, g = 0.1, b = 0.6},
            size = 125
        },
        sound = {
            aggregation = {
                max_count = 40,
                remove = true
            },
            variations = {
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_1.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_2.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_3.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_4.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_5.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_6.ogg",
                    volume = 0.95
                }
            }
        },
        smoke = "smoke-fast",
        smoke_count = 2,
        smoke_slow_down_factor = 1,

        created_effect = {
            action_delivery = {
                target_effects = {
                    {
                        type = "damage",
                        damage = {amount = 2500, type = "electric"},
                        force = "enemy",
                    },
                    {
                        action = {
                            action_delivery = {
                                target_effects = {
                                    {
                                        damage = {amount = 1250,type = "explosion"},
                                        force = "enemy",
                                        type = "damage"
                                    },
                                },
                                type = "instant"
                            },
                            radius = ei_data.matter_stabilizer.matter_range,
                            type = "area"
                        },
                        type = "nested-result"
                    },
                    {
                        check_buildability = true,
                        entity_name = "huge-scorchmark-tintable",
                        type = "create-entity"
                    },
                    {
                        repeat_count = 1,
                        type = "invoke-tile-trigger"
                    },
                    {
                        decoratives_with_trigger_only = false,
                        from_render_layer = "decorative",
                        include_decals = false,
                        include_soft_decoratives = true,
                        invoke_decorative_trigger = true,
                        radius = ei_data.matter_stabilizer.matter_range,
                        to_render_layer = "object",
                        type = "destroy-decoratives"
                    }
                },
                type = "instant",
            },
            type = "direct",
        },
        
        subgroup = "explosions",
        order = "c-a-a2"
    }
})


local neo_assembler = {
    name = "ei-exotic-assembler",
    type = "assembling-machine",
    icon = ei_graphics_item_path.."exotic-assembler.png",
    icon_size = 64,
    circuit_connector =  circuit_connector_definitions.create_vector(
    universal_connector_template,
    {
        { variation = 31, main_offset = util.by_pixel( 35.125,  10.125), shadow_offset = util.by_pixel( 35.125,  10.125), show_shadow = true },
        { variation = 31, main_offset = util.by_pixel( 35.125,  10.125), shadow_offset = util.by_pixel( 35.125,  10.125), show_shadow = true },
        { variation = 31, main_offset = util.by_pixel( 35.125,  10.125), shadow_offset = util.by_pixel( 35.125,  10.125), show_shadow = true },
        { variation = 31, main_offset = util.by_pixel( 35.125,  10.125), shadow_offset = util.by_pixel( 35.125,  10.125), show_shadow = true }
    }
    ),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {
        mining_time = 0.5,
        result = "ei-exotic-assembler"
    },
    max_health = 300,
    corpse = "big-remnants",
    dying_explosion = "ei-matter-explosion",
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    map_color = ei_data.colors.assembler,
    crafting_categories = {"ei-exotic-assembler"},
    crafting_speed = 1,
    energy_source = {
        type = 'electric',
        usage_priority = 'secondary-input',
        emissions_per_minute = {pollution = 4 },
    },
    energy_usage = "5MW",
    result_inventory_size = 1,
    source_inventory_size = 1,
    allowed_effects = {"speed", "consumption", "pollution", "productivity","quality"},
    module_slots = 4,
    fluid_boxes = util.table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"].fluid_boxes),
    graphics_set = util.table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"].graphics_set),
    working_sound =
    {
        sound = {filename = "__base__/sound/electric-furnace.ogg", volume = 0.6},
        apparent_volume = 0.3,
    },
    -- fast_replaceable_group = "assembling-machine",
}

-- data.raw["assembling-machine"]["assembling-machine-3"].next_upgrade = "ei-exotic-assembler"

neo_assembler.fluid_boxes[1].secondary_draw_order = 2
neo_assembler.fluid_boxes[2].secondary_draw_order = 2

table.insert(neo_assembler.graphics_set.animation.layers,
{
    filename = ei_graphics_V453000_path.."hr-beaconed-assembling-machine-3-overlay.png",
    priority = "high",
    width = 214,
    height = 218,
    frame_count = 1,
    repeat_count = 32,
    shift = util.by_pixel(0, 4),
    animation_speed = 1,
    scale = 0.5
})

table.insert(neo_assembler.graphics_set.animation.layers,
{
    filename = ei_graphics_V453000_path.."hr-assembling-machine-3-mask.png",
    priority = "high",
    width = 156,
    height = 192,
    frame_count = 32,
    line_length = 8,
    shift = util.by_pixel(-0.5, -11),
    tint = ei_data.colors.exotic,
    blend_mode = "additive",
    animation_speed = 1,
    scale = 0.5
})

data:extend({neo_assembler})