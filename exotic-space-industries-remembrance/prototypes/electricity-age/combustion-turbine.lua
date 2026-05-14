ei_data = require("lib/data")

--====================================================================================================
--COMBUSTION TURBINE
--====================================================================================================

data:extend({
    {
        name = "ei-combustion-turbine",
        type = "item",
        icon = ei_graphics_item_path.."combustion-turbine.png",
        icon_size = 64,
        subgroup = "energy",
        order = "b[steam-power]-c[combustion-turbine]",
        place_result = "ei-combustion-turbine",
        stack_size = 10
    },
    {
        name = "ei-combustion-turbine",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="advanced-circuit", amount=20},
            {type="item", name="electric-engine-unit", amount=18},
            {type="item", name="steel-plate", amount=16},
            {type="item", name="ei-copper-mechanical-parts", amount=12},
            {type="item", name="steam-engine", amount=4},
            {type="item", name="concrete", amount=40}
        },
        results = {{type="item", name="ei-combustion-turbine", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-combustion-turbine",
    },
    {
        name = "ei-combustion-turbine",
        type = "technology",
        icon = ei_graphics_tech_path.."combustion-turbine.png",
        icon_size = 512,
        prerequisites = {"advanced-circuit", "advanced-oil-processing", "concrete"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-combustion-turbine"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-combustion-turbine",
        type = "burner-generator",
        icon = ei_graphics_item_path.."combustion-turbine.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation =  7, main_offset = util.by_pixel(-119.75,  113.375), shadow_offset = util.by_pixel(-119.75,  113.375), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-combustion-turbine"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-4.2, -4.3}, {4.2, 4.3}},
        selection_box = {{-4.3, -4.5}, {4.3, 4.5}},
        map_color = ei_data.colors.assembler,
        energy_source = {
            type = "electric",
            usage_priority = "secondary-output"
        },
        burner = {
            type = "burner",
            fuel_categories = {"chemical"},
            effectivity = 3,
            fuel_inventory_size = 3,
            emissions_per_minute = {pollution = 120 },
            smoke = {
                {
                    name = "smoke",
                    deviation = {0.1, 0.1},
                    frequency = 45,
                    position = {0, -1.75},
                    starting_vertical_speed = 0.08,
                    starting_frame_deviation = 60,
                }
            }
        },
        max_power_output = "12MW",
        heating_energy = "0kW",
        animation = {
            filename = ei_graphics_entity_path.."combustion-turbine_animation.png",
            size = {512,512},
            width = 512,
            height = 512,
            shift = {0,-0.2},
	        scale = 0.65,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.2,
        },
        idle_animation = {
            filename = ei_graphics_entity_path.."combustion-turbine.png",
            size = {512,512},
            width = 512,
            height = 512,
            shift = {0,-0.2},
	        scale = 0.65,
            line_length = 1,
            -- lines_per_file = 2,
            frame_count = 1,
            animation_speed = 0.2,
            repeat_count = 16,
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/steam-turbine.ogg", volume = 0.2},
            apparent_volume = 0.3,
        },
    },
})

local solid_turbine = data.raw["burner-generator"]["ei-combustion-turbine"]
local fluid_open_proxy_name = "ei-combustion-turbine-fluid-open-proxy"
if solid_turbine then
    solid_turbine.fast_replaceable_group = "ei-combustion-turbine"
    solid_turbine.placeable_by = {item = "ei-combustion-turbine", count = 1}
    solid_turbine.additional_pastable_entities = {
        "ei-combustion-turbine-fluid",
        fluid_open_proxy_name,
    }

    local fluid_turbine = table.deepcopy(solid_turbine)
    fluid_turbine.name = "ei-combustion-turbine-fluid"
    fluid_turbine.type = "generator"
    fluid_turbine.localised_name = {"entity-name.ei-combustion-turbine"}
    fluid_turbine.localised_description = {"entity-description.ei-combustion-turbine"}
    fluid_turbine.hidden = true
    fluid_turbine.hidden_in_factoriopedia = true
    fluid_turbine.allow_copy_paste = true
    fluid_turbine.additional_pastable_entities = {
        "ei-combustion-turbine",
        fluid_open_proxy_name,
    }
    fluid_turbine.placeable_by = {item = "ei-combustion-turbine", count = 1}
    fluid_turbine.minable = {
        mining_time = 1,
        result = "ei-combustion-turbine"
    }

    fluid_turbine.effectivity = solid_turbine.burner and solid_turbine.burner.effectivity or 1
    fluid_turbine.burns_fluid = true
    fluid_turbine.scale_fluid_usage = true
    fluid_turbine.fluid_usage_per_tick = 1
    fluid_turbine.maximum_temperature = 1000
    fluid_turbine.fluid_box = {
        volume = 400,
        pipe_covers = pipecoverspictures(),
        pipe_picture = ei_pipe_big,
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {4, 0}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {-4, 0}},
        },
        production_type = "input-output",
    }
    fluid_turbine.smoke = table.deepcopy(solid_turbine.burner and solid_turbine.burner.smoke or {})
    fluid_turbine.horizontal_animation = table.deepcopy(solid_turbine.animation)
    fluid_turbine.vertical_animation = table.deepcopy(solid_turbine.animation)
    fluid_turbine.horizontal_animation.filename = ei_path.."graphics/entities/combustion-turbine-fluid_animation.png"
    fluid_turbine.vertical_animation.filename = ei_path.."graphics/entities/combustion-turbine-fluid_animation.png"
    fluid_turbine.burner = nil
    fluid_turbine.animation = nil
    fluid_turbine.idle_animation = nil
    fluid_turbine.always_draw_idle_animation = nil

    local fluid_open_proxy = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
    fluid_open_proxy.name = fluid_open_proxy_name
    fluid_open_proxy.icon = ei_graphics_item_path.."combustion-turbine.png"
    fluid_open_proxy.icon_size = 64
    fluid_open_proxy.localised_name = {"entity-name.ei-combustion-turbine"}
    fluid_open_proxy.localised_description = {"entity-description.ei-combustion-turbine"}
    fluid_open_proxy.flags = {
        "not-blueprintable",
        "not-deconstructable",
        "not-on-map",
        "not-flammable",
        "not-repairable",
        "not-upgradable",
        "hide-alt-info",
    }
    fluid_open_proxy.hidden = true
    fluid_open_proxy.hidden_in_factoriopedia = true
    fluid_open_proxy.gui_mode = "all"
    fluid_open_proxy.minable = nil
    fluid_open_proxy.max_health = 1
    fluid_open_proxy.collision_box = {{0, 0}, {0, 0}}
    fluid_open_proxy.collision_mask = {layers = {}}
    fluid_open_proxy.selection_box = {{-2.9, -3.0}, {2.9, 3.0}}
    fluid_open_proxy.selection_priority = 255
    fluid_open_proxy.allow_copy_paste = true
    fluid_open_proxy.additional_pastable_entities = {
        "ei-combustion-turbine",
        "ei-combustion-turbine-fluid",
    }
    fluid_open_proxy.item_slot_count = 1
    fluid_open_proxy.activity_led_light = {intensity = 0, size = 0, color = {r = 1, g = 1, b = 1}}
    fluid_open_proxy.activity_led_sprites = {
        north = util.empty_sprite(),
        east = util.empty_sprite(),
        south = util.empty_sprite(),
        west = util.empty_sprite(),
    }
    fluid_open_proxy.sprites = {
        north = util.empty_sprite(),
        east = util.empty_sprite(),
        south = util.empty_sprite(),
        west = util.empty_sprite(),
    }
    fluid_open_proxy.circuit_wire_max_distance = 0

    data:extend({fluid_turbine, fluid_open_proxy})
end
