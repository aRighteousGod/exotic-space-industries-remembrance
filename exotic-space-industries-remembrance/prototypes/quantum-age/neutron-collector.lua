ei_data = require("lib/data")

--====================================================================================================
--PLASMA HEATER
--====================================================================================================

data:extend({
    {
        name = "ei-neutron-collector",
        type = "recipe-category",
    },
    {
        name = "ei-neutron-collector",
        type = "item",
        icon = ei_graphics_item_path.."neutron-collector.png",
        icon_size = 64,
        subgroup = "ei-nuclear-buildings",
        order = "c-b",
        place_result = "ei-neutron-collector",
        stack_size = 50
    },
    {
        name = "ei-neutron-collector",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-insulated-tank", amount=1},
            {type="item", name="solar-panel", amount=4},
            {type="item", name="ei-magnet", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=8}
        },
        results = {{type="item", name="ei-neutron-collector", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-neutron-collector",
    },
    {
        name = "ei-neutron-container",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-empty-cryo-container", amount=3},
            -- {type="item", name="ei-magnet", amount=2},
            {type="item", name="ei-carbon-structure", amount=1}
        },
        results = {{type="item", name="ei-neutron-container", amount=5}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-neutron-container",
    },
    {
        name = "ei-neutron-collector",
        type = "technology",
        icon = ei_graphics_tech_path.."neutron-collector.png",
        icon_size = 256,
        prerequisites = {"ei-fusion-data"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-neutron-collector"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["fusion-quantum-age"],
            time = 20
        },
        age = "fusion-quantum-age",
    },
    {
        name = "ei-neutron-collector",
        type = "assembling-machine",
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 19, main_offset = util.by_pixel( 21,  13.625), shadow_offset = util.by_pixel( 21,  13.625), show_shadow = true },
            { variation = 19, main_offset = util.by_pixel( 21,  13.625), shadow_offset = util.by_pixel( 21,  13.625), show_shadow = true },
            { variation = 19, main_offset = util.by_pixel( 21,  13.625), shadow_offset = util.by_pixel( 21,  13.625), show_shadow = true },
            { variation = 19, main_offset = util.by_pixel( 21,  13.625), shadow_offset = util.by_pixel( 21,  13.625), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        icon = ei_graphics_item_path.."neutron-collector.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-neutron-collector"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        gui_mode = "all",
        crafting_categories = {"ei-neutron-collector"},
        crafting_speed = 1,
        heating_energy = "100kW",
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "1MW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."neutron-collector.png",
                size = {512,512},
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
                    filename = ei_graphics_entity_path.."neutron-collector_animation.png",
                    size = {512,512},
                    shift = {0,-0.2},
    	            scale = 0.44/2,
                    line_length = 1,
                    lines_per_file = 1,
                    frame_count = 1,
                    animation_speed = 1,
                  }
                },
                {
                    light = {
                    type = "basic",
                    intensity = 1,
                    size = 15
                    }
                }
            },
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-furnace.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-charged-neutron-container",
        type = "item",
        icon = ei_graphics_item_path.."charged-neutron-container.png",
        icon_size = 64,
        subgroup = "ei-nuclear-processing",
        order = "b-b",
        stack_size = 100,
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."charged-neutron-container.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."charged-neutron-container_light.png",
                scale = 0.5
              }
            }
        },
    },
    {
        name = "ei-neutron-container",
        type = "item",
        icon = ei_graphics_item_path.."neutron-container.png",
        icon_size = 64,
        subgroup = "ei-nuclear-processing",
        order = "b-a",
        stack_size = 50
    },
})

local function make_neutron_signal_icons(base_icon, overlay_name, tint)
    return {
        {
            icon = base_icon,
            icon_size = 64,
        },
        {
            icon = ei_graphics_other_path..overlay_name,
            icon_size = 64,
            tint = tint,
        },
    }
end

local neutron_wire_proxy = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
neutron_wire_proxy.name = "ei-neutron-collector-circuit-interface"
neutron_wire_proxy.icon = ei_graphics_other_path.."64_empty.png"
neutron_wire_proxy.flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-flammable", "not-repairable", "not-upgradable", "hide-alt-info"}
neutron_wire_proxy.hidden = true
neutron_wire_proxy.gui_mode = "none"
neutron_wire_proxy.selectable_in_game = false
neutron_wire_proxy.minable = nil
neutron_wire_proxy.max_health = 300
neutron_wire_proxy.collision_box = {{0, 0}, {0, 0}}
neutron_wire_proxy.selection_box = {{0, 0}, {0, 0}}
neutron_wire_proxy.item_slot_count = 5
neutron_wire_proxy.activity_led_light = {intensity = 0, size = 0, color = {r = 1, g = 1, b = 1}}
neutron_wire_proxy.activity_led_sprites = {
    north = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    east = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    south = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    west = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
}
neutron_wire_proxy.sprites = {
    north = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    east = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    south = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
    west = {filename = ei_graphics_other_path.."64_empty.png", size = 64},
}
neutron_wire_proxy.circuit_wire_max_distance = default_circuit_wire_max_distance

data:extend({
    neutron_wire_proxy,
    {
        type = "virtual-signal",
        name = "ei-neutron-efficiency",
        icons = make_neutron_signal_icons(
            ei_graphics_item_path.."charged-neutron-container.png",
            "overlay_1.png",
            {r = 0.25, g = 0.92, b = 1, a = 0.95}
        ),
        order = "ei-neutron-a",
    },
    {
        type = "virtual-signal",
        name = "ei-neutron-distance",
        icons = make_neutron_signal_icons(
            ei_graphics_item_path.."neutron-collector.png",
            "overlay_2.png",
            {r = 1, g = 0.75, b = 0.2, a = 0.95}
        ),
        order = "ei-neutron-b",
    },
    {
        type = "virtual-signal",
        name = "ei-neutron-collector-agent",
        icons = make_neutron_signal_icons(
            ei_graphics_item_path.."neutron-collector.png",
            "overlay_3.png",
            {r = 0.2, g = 0.95, b = 0.4, a = 0.95}
        ),
        order = "ei-neutron-c",
    },
    {
        type = "virtual-signal",
        name = "ei-neutron-source-agent",
        icons = make_neutron_signal_icons(
            ei_graphics_item_path.."fusion-reactor.png",
            "overlay_1.png",
            {r = 0.35, g = 0.62, b = 1, a = 0.95}
        ),
        order = "ei-neutron-d",
    },
    {
        type = "virtual-signal",
        name = "ei-neutron-scan-agent",
        icons = make_neutron_signal_icons(
            ei_graphics_item_path.."neutron-container.png",
            "overlay_3.png",
            {r = 0.9, g = 0.35, b = 1, a = 0.95}
        ),
        order = "ei-neutron-e",
    },
})

--RECIPES FOR CHARGED NEUTRON CONTAINER
------------------------------------------------------------------------------------------------------

local base_recipe = {
    name = "ei-charged-neutron-container",
    type = "recipe",
    category = "ei-neutron-collector",
    energy_required = 100,
    ingredients = {
        {type = "item", name = "ei-neutron-container", amount = 1},
    },
    results = {
        {type = "item", name = "ei-charged-neutron-container", amount = 1},
    },
    enabled = true,
    hidden = true,
    main_product = "ei-charged-neutron-container",
}

local idle_recipe = util.table.deepcopy(base_recipe)
idle_recipe.name = "ei-neutron-collector-idle"
idle_recipe.ingredients = {
    {type = "item", name = "ei-neutron-container", amount = 1},
}
idle_recipe.results = {
    {type = "item", name = "ei-neutron-container", amount = 1},
}
idle_recipe.energy_required = 1
idle_recipe.main_product = "ei-neutron-container"
data:extend({idle_recipe})

-- make recipes for 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 .. 200 percent efficiency
for i = 10, 300, 10 do
    local recipe = util.table.deepcopy(base_recipe)
    -- ei_charged-neutron-container:percentage
    recipe.name = recipe.name.."-"..i

    -- set time usage -> 100 percent <=> 10s/2, 10 percent <=> 100s
    recipe.energy_required = 1000/(i+i-10)
    data:extend({recipe})
end
