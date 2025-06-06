--====================================================================================================
--EMPTY SPRITE
--====================================================================================================

local empty_sprite = {
    filename = ei_tanks_entity_path.."64_empty.png",
    priority = "high",
    width = 64,
    height = 64
}

--====================================================================================================
--PIPE PICTURES
--====================================================================================================

ei_tank_1 = {
    north = empty_sprite,
    south = {
        layers = {
            {
              filename = ei_tanks_pipe_path.."data_south_covers.png",
              width = 512,
              height = 512,
              -- shift = {0,-2.15},
              scale = 0.35,
              shift = util.by_pixel(0, -96), 
            },
            {
              filename = ei_tanks_pipe_path.."south_basic_covers.png",
              priority = "high",
              width = 55,
              height = 50,
              shift = {0.01, -0.58},
              scale = 0.5
            }
        }
        
    },
    west = {
      filename = ei_tanks_pipe_path.."big_west_covers.png",
      priority = "high",
      width = 512,
      height = 512,
      scale = 0.35,
      shift = util.by_pixel(96, 0),        
    },
    east = {
      filename = ei_tanks_pipe_path.."big_east_covers.png",
      priority = "high",
      width = 512,
      height = 512,
      scale = 0.35,
      shift = util.by_pixel(-96, 0),
    }
}

ei_tank_2 = {
    north = empty_sprite,
    south = {
        layers = {
            {
                filename = ei_tanks_pipe_path.."data_south_covers.png",
                width = 512,
                height = 512,
                -- shift = {0,-2.15},
                scale = 0.35,
                shift = util.by_pixel(0, -96), 
            },
            {
                filename = ei_tanks_pipe_path.."south_basic_covers.png",
                priority = "high",
                width = 55,
                height = 50,
                shift = {0.01, -0.58},
                scale = 0.5
            }
        }
        
    },
    west = empty_sprite,
    east = empty_sprite
}

--====================================================================================================
--TANKS
--====================================================================================================

data:extend({
    {
        name = "ei-tank-1",
        type = "item",
        icon = ei_tanks_item_path.."tank-1.png",
        icon_size = 64,
        subgroup = "storage",
        order = "b[fluid]-b",
        place_result = "ei-tank-1",
        stack_size = 50
    },
    {
        name = "ei-tank-2",
        type = "item",
        icon = ei_tanks_item_path.."tank-2.png",
        icon_size = 64,
        subgroup = "storage",
        order = "b[fluid]-d",
        place_result = "ei-tank-2",
        stack_size = 50
    },
    {
        name = "ei-tank-3",
        type = "item",
        icon = ei_tanks_item_path.."tank-3.png",
        icon_size = 64,
        subgroup = "storage",
        order = "b[fluid]-c",
        place_result = "ei-tank-3",
        stack_size = 50
    },
    {
        name = "ei-tank-1",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="concrete", amount=25},
            {type="item", name="steel-plate", amount=16}, --storage:iron ratio 600:1
            {type="item", name="storage-tank", amount=1}, --45iron, storage:iron ratio 555:1
        },
        results = {{type="item", name="ei-tank-1", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-tank-1",
    },
    {
        name = "ei-tank-2",
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        ingredients =
        {
            {type="item", name="concrete", amount=100},
            {type="item", name="steel-plate", amount=35},--storage:iron ratio 666:1
            {type="item", name="ei-tank-3", amount=1},
        },
        results = {{type="item", name="ei-tank-2", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-tank-2",
    },
    {
        name = "ei-tank-3",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="concrete", amount=50},
            {type="item", name="steel-plate", amount=20}, --storage:iron ratio 750:1
            {type="item", name="ei-tank-1", amount=1},
        },
        results = {{type="item", name="ei-tank-3", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-tank-3",
    },
    {
        name = "ei-tank-column",
        type = "technology",
        icon = ei_tanks_tech_path.."tank-1.png",
        icon_size = 256,
        prerequisites = {"ei-tank","concrete"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-tank-1"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 30
        },
        age = "steam-age",
    },
    {
        name = "ei-tank-silo",
        type = "technology",
        icon = ei_tanks_tech_path.."tank-2.png",
        icon_size = 256,
        prerequisites = {"ei-tank-sphere"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-tank-2"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 30
        },
        age = "steam-age",
    },
    {
        name = "ei-tank-sphere",
        type = "technology",
        icon = ei_tanks_tech_path.."tank-3.png",
        icon_size = 256,
        prerequisites = {"ei-tank-column"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-tank-3"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 30
        },
        age = "steam-age",
    },
    {
        name = "ei-tank-1",
        type = "storage-tank",
        icon = ei_tanks_item_path.."tank-1.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation"},
        minable = {mining_time = 0.5, result = "ei-tank-1"},
        max_health = 1000,
        resistances = {
          { type = "physical", percent = 30 },
          { type = "fire",     percent = 60 },
          { type = "impact",   percent = 60 },
        },
        corpse = "big-remnants",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points,
		circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites,
		circuit_wire_max_distance = 20,
        flow_length_in_ticks = 1,
        map_color = data.raw["storage-tank"]["storage-tank"].map_color,
        window_bounding_box = {{0,0},{1,1}},
        fluid_box = {
            volume = 75000,
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_tank_1,
            base_level = 0,
            pipe_connections =
            {
                { flow_direction = "input-output", direction = defines.direction.north, position = {0, -2} },
                { flow_direction = "input-output", direction = defines.direction.south, position = {0, 2} },
                { flow_direction = "input-output", direction = defines.direction.west, position = {-2, 0} },
                { flow_direction = "input-output", direction = defines.direction.east, position = {2, 0} },
            },
            production_type = "input-output",
        },
        pictures = {
            picture = {
                filename = ei_tanks_entity_path.."tank-1.png",
                size = {512,512},
                shift = {0, 0},
	            scale = 0.35*2,
            },
            window_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            fluid_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            flow_sprite = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            gas_flow = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
                line_length = 1,
                frame_count = 1,
                animation_speed = 1,
            },
        }
    },
    {
        name = "ei-tank-2",
        type = "storage-tank",
        icon = ei_tanks_item_path.."tank-2.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation"},
        minable = {mining_time = 0.5, result = "ei-tank-2"},
        max_health = 1500,
        resistances = {
          { type = "physical", percent = 40 },
          { type = "fire",     percent = 70 },
          { type = "impact",   percent = 70 },
        },
        corpse = "big-remnants",
        collision_box = {{-3.4, -3.4}, {3.4, 3.4}},
        selection_box = {{-3.5, -3.5}, {3.5, 3.5}},
        circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points,
		circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites,
		circuit_wire_max_distance = 20,
        flow_length_in_ticks = 1,
        map_color = data.raw["storage-tank"]["storage-tank"].map_color,
        window_bounding_box = {{0,0},{1,1}},
        fluid_box = {
            volume = 300000,
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_tank_2,
            base_level = 0,
            pipe_connections =
            {
                { flow_direction = "input-output", direction = defines.direction.north, position = {1, -3} },  
                { flow_direction = "input-output", direction = defines.direction.north, position = {-1, -3} },

                { flow_direction = "input-output", direction = defines.direction.south, position = {1, 3} },
                { flow_direction = "input-output", direction = defines.direction.south, position = {-1, 3} },

                { flow_direction = "input-output", direction = defines.direction.west, position = {-3, 1} },
                { flow_direction = "input-output", direction = defines.direction.west, position = {-3, -1} },

                { flow_direction = "input-output", direction = defines.direction.east, position = {3, 1} },
                { flow_direction = "input-output", direction = defines.direction.east, position = {3, -1} },
            },
            production_type = "input-output",
        },
        pictures = {
            picture = {
                filename = ei_tanks_entity_path.."tank-2.png",
                size = {512*2,512*2},
                shift = {0, 0},
	            scale = 0.52,
            },
            window_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            fluid_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            flow_sprite = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            gas_flow = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
                line_length = 1,
                frame_count = 1,
                animation_speed = 1,
            },
        }
    },
    {
        name = "ei-tank-3",
        type = "storage-tank",
        icon = ei_tanks_item_path.."tank-3.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation"},
        minable = {mining_time = 0.5, result = "ei-tank-3"},
        max_health = 2000,
        resistances = {
          { type = "physical", percent = 60 },
          { type = "fire",     percent = 80 },
          { type = "impact",   percent = 80 },
        },
        corpse = "big-remnants",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points,
		circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites,
		circuit_wire_max_distance = 20,
        flow_length_in_ticks = 1,
        map_color = data.raw["storage-tank"]["storage-tank"].map_color,
        window_bounding_box = {{0,0},{1,1}},
        fluid_box = {
            volume = 150000,
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_tank_1,
            base_level = 0,
            pipe_connections =
            {
                { flow_direction = "input-output", direction = defines.direction.north, position = {0, -2} },
                { flow_direction = "input-output", direction = defines.direction.south, position = {0, 2} },
                { flow_direction = "input-output", direction = defines.direction.east, position = {-2, 0} },
                { flow_direction = "input-output", direction = defines.direction.west, position = {2, 0} },
            },
            production_type = "input-output",
        },
        pictures = {
            picture = {
                filename = ei_tanks_entity_path.."tank-3.png",
                size = {512,512},
                shift = {0, 0},
	            scale = 0.35*2,
            },
            window_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            fluid_background = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            flow_sprite = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
            },
            gas_flow = {
                filename = ei_tanks_entity_path.."64_empty.png",
                size = {64,64},
                shift = {0, 0},
                scale = 0.5,
                line_length = 1,
                frame_count = 1,
                animation_speed = 1,
            },
        }
    }
})