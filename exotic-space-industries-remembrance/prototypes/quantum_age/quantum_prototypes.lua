-- this file contains the prototype definition for varios stuff from quantum age

local ei_data = require("lib/data")

--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------
data:extend({
    -- new module tier 4-6
    {
        name = "ei-speed-module-4",
        type = "module",
        icon = ei_graphics_item_path.."speed-module-4.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "a[speed]-c[speed-module-3]-a",
        category = "speed",
        tier = 4,
        effect = { speed = 0.6, consumption = 0.4},
    },
    {
        name = "ei-speed-module-5",
        type = "module",
        icon = ei_graphics_item_path.."speed-module-5.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "a[speed]-c[speed-module-3]-b",
        category = "speed",
        tier = 5,
        effect = { speed = 0.7, consumption = 0.5},
    },
    {
        name = "ei-speed-module-6",
        type = "module",
        icon = ei_graphics_item_path.."speed-module-6.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "a[speed]-c[speed-module-3]-c",
        category = "speed",
        tier = 6,
        effect = { speed = 0.8, consumption = 0.5},
    },
    {
        name = "ei-efficiency-module-4",
        type = "module",
        icon = ei_graphics_item_path.."effectivity-module-4.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[efficiency]-c[efficiency-module-3]-a",
        category = "efficiency",
        tier = 4,
        effect = {consumption = -0.6},
    },
    {
        name = "ei-efficiency-module-5",
        type = "module",
        icon = ei_graphics_item_path.."effectivity-module-5.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[efficiency]-c[efficiency-module-3]-b",
        category = "efficiency",
        tier = 5,
        effect = {consumption = -0.8},
    },
    {
        name = "ei-efficiency-module-6",
        type = "module",
        icon = ei_graphics_item_path.."effectivity-module-6.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[efficiency]-c[efficiency-module-3]-c",
        category = "efficiency",
        tier = 6,
        effect = {consumption = -1},
    },
    {
        name = "ei-productivity-module-4",
        type = "module",
        icon = ei_graphics_item_path.."productivity-module-4.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[productivity]-c[productivity-module]-a",
        category = "productivity",
        tier = 4,
        effect = {
            productivity = 0.1,
            consumption = 0.6,
            pollution = 0.2,
            speed = -0.25
        },
    },
    {
        name = "ei-productivity-module-5",
        type = "module",
        icon = ei_graphics_item_path.."productivity-module-5.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[productivity]-c[productivity-module]-b",
        category = "productivity",
        tier = 5,
        effect = {
            productivity = 0.13,
            consumption = 0.8,
            pollution = 0.4,
            speed = -0.4
        },
    },
    {
        name = "ei-productivity-module-6",
        type = "module",
        icon = ei_graphics_item_path.."productivity-module-6.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "module",
        order = "c[productivity]-c[productivity-module]-c",
        category = "productivity",
        tier = 6,
        effect = {
            productivity = 0.16,
            consumption = 1.0,
            pollution = 0.6,
            speed = -0.8
        },
    },
    {
        name = "ei-gauss-module",
        type = "module",
        icon = ei_graphics_item_path.."gauss-module.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "module",
        order = "c[productivity]-z",
        category = "productivity",
        tier = 7,
        effect = {
            productivity = 0.2,
            consumption = 2,
            pollution = 2,
            speed = -2
        },
    },
    {
        name = "ei-photon-cavity",
        type = "item",
        icon = ei_graphics_item_path.."photon-cavity.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "b8-d",
    },
    {
        name = "ei-gluon-cavity",
        type = "item",
        icon = ei_graphics_item_path.."z-boson-cavity.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "b8-c",
    },
    {
        name = "ei-z-boson-cavity",
        type = "item",
        icon = ei_graphics_item_path.."gluon-cavity.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "b8-b",
    },
    {
        name = "ei-clean-plating",
        type = "item",
        icon = ei_graphics_item_path.."clean-plating.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-alien-intermediates",
        order = "d-x-a",
    },
    {
        name = "ei-circuit-board",
        type = "item",
        icon = ei_graphics_item_path.."circuit-board.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "raw-material",
        order = "x-a",
    },
    {
        name = "ei-pre-circuit-board",
        type = "item",
        icon = ei_graphics_item_path.."pre-circuit-board.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "raw-material",
        order = "x",
    },
    {
        name = "ei-cavity",
        type = "item",
        icon = ei_graphics_item_path.."cavity.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "b8-a",
    },
    {
        name = "ei-crushed-neodym",
        type = "item",
        icon = ei_graphics_item_path.."crushed-neodym.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "d2",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-neodym.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-neodym-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-neodym-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-neodym-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-pure-crushed-neodym",
        type = "item",
        icon = ei_graphics_item_path.."crushed-pure-neodym-3.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-purified",
        order = "c-b",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-pure-neodym.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-neodym-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-neodym-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-neodym-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-crushed-coal",
        type = "item",
        icon = ei_graphics_item_path.."crushed-coal.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "c1",
        fuel_category = "chemical",
        fuel_value = "2MJ",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-coal.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coal-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coal-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-carbon",
        type = "item",
        icon = ei_graphics_item_path.."carbon.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "h[battery]-a[carbon]",
    },
    {
        name = "ei-carbon-nanotube",
        type = "item",
        icon = ei_graphics_item_path.."carbon-nanotube.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "h[battery]-b[carbon]",
        pictures = {
            {
                filename = ei_graphics_item_path.."carbon-nanotube.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."carbon-nanotube-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."carbon-nanotube-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."carbon-nanotube-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-carbon-structure",
        type = "item",
        icon = ei_graphics_item_path.."carbon-structure.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "h[battery]-c[carbon]",
    },
    {
        name = "ei-magnet",
        type = "item",
        icon = ei_graphics_item_path.."magnet.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "b9",
    },
    {
        name = "ei-magnet-data",
        type = "item",
        icon = ei_graphics_item_path.."magnet-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-f",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."magnet-data.png",
                scale = 0.25/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."magnet-data_light.png",
                scale = 0.25/2
              }
            }
          },
    },
    {
        name = "ei-fusion-data",
        type = "item",
        icon = ei_graphics_item_path.."fusion-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-g",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."fusion-data.png",
                scale = 0.25/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.25/2
              }
            }
          },
    },
    {
        name = "ei-fusion-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."fusion-quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a5-1",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."fusion-quantum-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."quantum-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    },
    -- {
    --     name = "ei-space-quantum-age-tech",
    --     type = "tool",
    --     icon = ei_graphics_item_path.."exotic-quantum-age-tech.png",
    --     icon_size = 64,
    --     stack_size = 200,
    --     durability = 1,
    --     subgroup = "science-pack",
    --     order = "a5-2",
    --     pictures = {
    --         layers =
    --         {
    --           {
    --             size = 64,
    --             filename = ei_graphics_item_path.."exotic-quantum-age-tech.png",
    --             scale = 0.25
    --           },
    --           {
    --             draw_as_light = true,
    --             flags = {"light"},
    --             size = 64,
    --             filename = ei_graphics_item_path.."quantum-age-tech_light.png",
    --             scale = 0.25
    --           }
    --         }
    --     },
    -- },
    {
        name = "ei-dt-mix",
        type = "item",
        icon = ei_graphics_item_path.."dt-mix.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-nuclear-fission-fuel",
        order = "c-1",
        fuel_category = "ei-fusion-fuel",
        fuel_value = "1TJ",
        fuel_acceleration_multiplier = 2.0,
        fuel_top_speed_multiplier = 3.0,
    },
    {
        name = "ei-fusion-drive",
        type = "item",
        icon = ei_graphics_item_path.."fusion-drive.png",
        icon_size = 128,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-x-2",
    },
    {
        name = "ei-odd-plating",
        type = "item",
        icon = ei_graphics_item_path.."odd-plating.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-alien-intermediates",
        order = "d-x",
    },
    {
        name = "ei-exotic-ore",
        type = "item",
        icon = ei_graphics_item_path.."exotic-ore.png",
        icon_size = 64,
        stack_size = 20,
        subgroup = "ei-refining-purified",
        order = "x-1",
    },
    {
        name = "ei-plasma-cube",
        type = "item",
        icon = ei_graphics_item_path.."plasma-cube.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "d[barrel]-2",
    },
    {
        name = "ei-eu-circuit",
        type = "item",
        icon = ei_graphics_item_path.."eu-circuit.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "g[processing-unit]-b",
    },
    {
        name = "ei-eu-magnet",
        type = "item",
        icon = ei_graphics_item_path.."eu-magnet.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "b9-a",
    },
    {
        name = "ei-exotic-matter-up",
        type = "item",
        icon = ei_graphics_item_path.."exotic-matter-up.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-alien-items",
        order = "d-a",
    },
    {
        name = "ei-exotic-matter-down",
        type = "item",
        icon = ei_graphics_item_path.."exotic-matter-down.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-alien-items",
        order = "d-b",
    },
    {
        name = "ei-high-tech-parts",
        type = "item",
        icon = ei_graphics_item_path.."high-tech-parts.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "b6-a",
    },
    {
        name = "ei-advanced-rocket-fuel",
        type = "item",
        icon = ei_graphics_item_path.."advanced-rocket-fuel.png",
        icon_size = 64,
        stack_size = 10,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-b",
        fuel_category = "ei-rocket-fuel",
        fuel_value = "180MJ",
        fuel_acceleration_multiplier = 2.1,
        fuel_top_speed_multiplier = 1.3,
    },
    {
        name = "ei-lithium-crystal",
        type = "item",
        icon = ei_graphics_item_path.."lithium-crystal.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-purified",
        order = "b-b",
        pictures = {
            {
                filename = ei_graphics_item_path.."lithium-crystal.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."lithium-crystal-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."lithium-crystal-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."lithium-crystal-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-exotic-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."exotic-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a6",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."exotic-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."exotic-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    },
    {
        name = "ei-bio-armor",
        type = "armor",
        icon = ei_graphics_item_path.."bio-armor.png",
        icon_size = 64,
        stack_size = 1,
        subgroup = "armor",
        order = "f",
        resistances = {
            {type = "physical", decrease = 20, percent = 60},
            {type = "acid", decrease = 5, percent = 85},
            {type = "explosion", decrease = 80, percent = 70},
            {type = "fire", decrease = 20, percent = 70},
            {type = "laser", decrease = 20, percent = 60},
            {type = "electric", decrease = 0, percent = 100},
            {type = "impact", decrease = 5, percent = 90},
            
        },
        equipment_grid = "ei-bio-armor",
        inventory_size_bonus = 60,
        infinite = true,
    },
    {
        name = "ei-personal-solar-3",
        type = "item",
        icon = ei_graphics_item_path.."personal-solar-3.png",
        icon_size = 64,
        subgroup = "equipment",
        order = "a[energy-source]-c[personal-solar-panel]",
        stack_size = 20,
        place_as_equipment_result = "ei-personal-solar-3",
    },
    {
        name = "ei-personal-solar-3",
        type = "solar-panel-equipment",
        power = "150kW",
        categories = {"armor"},
        sprite = {
            filename = ei_graphics_other_path.."personal-solar-3.png",
            width = 64,
            height = 64,
            priority = "medium"
        },
        shape = {
            width = 1,
            height = 1,
            type = "full"
        },
        energy_source = {
            type = "electric",
            usage_priority = "primary-output"
        },
        take_result = "ei-personal-solar-3",
    },
    {
        name = "ei-personal-shield",
        type = "item",
        icon = ei_graphics_item_path.."personal-shield.png",
        icon_size = 64,
        subgroup = "military-equipment",
        order = "a[shield]-c[personal-shield]",
        stack_size = 10,
        place_as_equipment_result = "ei-personal-shield",
    },
    {
        name = "ei-personal-shield",
        type = "energy-shield-equipment",
        sprite = {
            filename = ei_graphics_other_path.."personal-shield.png",
            width = 256,
            height = 256,
            priority = "medium"
        },
        shape = {
            width = 3,
            height = 3,
            type = "full"
        },
        max_shield_value = 500,
        energy_per_shield = "50kJ",
        categories = {"armor"},
        energy_source = {
            type = "electric",
            buffer_capacity = "1000kJ",
            input_flow_limit = "1500kW",
            usage_priority = "primary-input"
        },
        take_result = "ei-personal-shield",
    },
    {
        name = "ei-bug-zapper",
        type = "item",
        icon = ei_graphics_item_path.."bug-zapper.png",
        icon_size = 64,
        subgroup = "military-equipment",
        order = "c[zapper]-a[bug-zapper]",
        stack_size = 1,
        place_as_equipment_result = "ei-bug-zapper",
    },
    {
        name = "ei-bug-zapper",
        type = "active-defense-equipment",
        sprite = {
            filename = ei_graphics_other_path.."bug-zapper.png",
            width = 256,
            height = 256,
            priority = "medium"
        },
        shape = {
            width = 2,
            height = 2,
            type = "full"
        },
        categories = {"armor"},
        energy_source = {
            type = "electric",
            buffer_capacity = "200MJ",
            input_flow_limit = "20MW",
            usage_priority = "primary-input"
        },
        attack_parameters = {
            type = "projectile",
            ammo_category = "electric",
            damage_modifier = 200,
            cooldown = 600,
            projectile_center = {0, 0},
            projectile_creation_distance = 1.2,
            range = 64,
            sound = {
                filename = "__base__/sound/fight/pulse.ogg",
                volume = 0.7
            },
            ammo_type = {
                type = "projectile",
                energy_consumption = "100MJ",
                action = {
                    {
                        type = "area",
                        radius = 64,
                        force = "enemy",
                        action_delivery = {
                            {
                                type = "instant",
                                target_effects = {
                                    {
                                        type = "create-sticker",
                                        sticker = "stun-sticker"
                                    },
                                    {
                                        type = "push-back",
                                        distance = 8
                                    }
                                }
                            },
                            {
                                type = "beam",
                                beam = "electric-beam-no-sound",
                                max_length = 96,
                                duration = 120,
                                source_offset = {0, -0.5},
                                add_to_shooter = false
                            }
                        }
                    }
                }
            }
        },
        automatic = false,
    },
    {
        name = "ei-bug-zapper-remote",
        type = "capsule",
        icon = "__base__/graphics/icons/discharge-defense-equipment-controller.png",
        icon_size = 64, icon_mipmaps = 4,
        capsule_action = {
            type = "equipment-remote",
            equipment = "ei-bug-zapper"
        },
        subgroup = "military-equipment",
        order = "c[zapper]-b[bug-zapper-remote]",
        stack_size = 1
    },
    {
        name = "ei-heavy-minigun",
        type = "gun",
        icon = ei_graphics_item_path.."heavy-minigun.png",
        icon_size = 128,
        stack_size = 1,
        subgroup = "gun",
        order = "a[basic-clips]-d[minigun]",
        attack_parameters = {
            ammo_category = "bullet",
            cooldown = 0.5,
            movement_slow_down_factor = 0.95,
            projectile_creation_distance = 1.125,
            range = 40,
            shell_particle = {
                center = {
                    0,
                    0.1
                },
                creation_distance = -0.5,
                direction_deviation = 0.1,
                name = "shell-particle",
                speed = 0.1,
                speed_deviation = 0.03,
                starting_frame_speed = 0.4,
                starting_frame_speed_deviation = 0.1
            },
            sound = {
                {
                    filename = "__base__/sound/fight/submachine-gunshot-1.ogg",
                    volume = 0.6
                },
                {
                    filename = "__base__/sound/fight/submachine-gunshot-2.ogg",
                    volume = 0.6
                },
                {
                    filename = "__base__/sound/fight/submachine-gunshot-3.ogg",
                    volume = 0.6
                }
            },
            type = "projectile"
        },
    },
    {
        name = "ei-personal-reactor",
        type = "item",
        icon = ei_graphics_item_path.."personal-reactor.png",
        icon_size = 64,
        subgroup = "equipment",
        order = "a[energy-source]-f[personal-reactor]",
        stack_size = 1,
        place_as_equipment_result = "ei-personal-reactor",
    },
})

--RECIPES
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-heavy-minigun",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients =
        {
            {type="item", name="ei-minigun", amount=10},
            {type="item", name="ei-carbon-structure", amount=25},
            {type="item", name="ei-odd-plating", amount=25},
            {type="item", name="ei-advanced-motor", amount=100},
        },
        results = {{type="item", name="ei-heavy-minigun", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-heavy-minigun",
    },
    {
        name = "ei-bug-zapper",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients =
        {
            {type="item", name="discharge-defense-equipment", amount=20},
            {type="item", name="ei-carbon-structure", amount=25},
            {type="item", name="ei-high-tech-parts", amount=25},
        },
        results = {{type="item", name="ei-bug-zapper", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-bug-zapper",
    },
    {
        name = "ei-bug-zapper-remote",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients =
        {
            {type="item", name="discharge-defense-remote", amount=1},
        },
        results = {{type="item", name="ei-bug-zapper-remote", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-bug-zapper-remote",
    },
    {
        name = "ei-personal-shield",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="energy-shield-mk2-equipment", amount=6},
            {type="item", name="ei-carbon-structure", amount=10},
            {type="item", name="ei-superior-data", amount=25},
        },
        results = {{type="item", name="ei-personal-shield", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-personal-shield",
    },
    {
        name = "ei-personal-solar-3",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-solar-panel-3", amount = 4},
            {type = "item", name = "ei-carbon-structure", amount = 6},
            {type = "item", name = "ei-personal-solar-2", amount = 2},
        },
        results = {
            {type = "item", name = "ei-personal-solar-3", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-personal-solar-3",
    },
    {
        name = "ei-crushed-neodym",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-neodym-chunk", amount = 6},
        },
        results = {
            {type = "item", name = "ei-crushed-neodym", amount = 2},
            {type = "item", name = "stone", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-neodym",
    },
    {
        name = "ei-pure-crushed-neodym",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-crushed-neodym", amount = 25},
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 15},
        },
        results = {
            {type = "item", name = "ei-pure-crushed-neodym", amount = 5},
            {type = "fluid", name = "ei-neodym-solution", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-pure-crushed-neodym",
    },
    {
        name = "ei-neodym-solution",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-neodym-solution", amount = 25},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 15},
            {type = "item", name = "ei-crushed-neodym", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-neodym",
        icon = ei_graphics_other_path.."neodym-solution.png",
        icon_size = 64,
        subgroup = "ei-refining-extraction",
        order = "g-b",
    },
    {
        name = "ei-molten-neodym",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-pure-crushed-neodym", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-neodym", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-neodym",
    },
    {
        name = "ei-cast-neodym-ingot",
        type = "recipe",
        category = "ei-casting",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-molten-neodym", amount = 10},
            {type = "item", name = "ei-crushed-coal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-neodym-ingot", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-neodym-ingot",
    },
    {
        name = "ei-magnet",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-neodym-ingot", amount = 3},
            {type = "item", name = "ei-gold-ingot", amount = 2},
            {type = "item", name = "ei-insulated-wire", amount = 25},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-magnet", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-magnet",
    },
    {
        name = "ei-pre-circuit-board",
        type = "recipe",
        category = "centrifuging",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-ceramic", amount = 3},
            {type = "item", name = "ei-gold-ingot", amount = 1},
            {type = "item", name = "ei-clean-plating", amount = 2},
        },
        results = {
            {type = "item", name = "ei-pre-circuit-board", amount = 6},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-pre-circuit-board",
    },
    {
        name = "ei-circuit-board",
        type = "recipe",
        category = "smelting",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-pre-circuit-board", amount = 1},
        },
        results = {
            {type = "item", name = "ei-circuit-board", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-circuit-board",
    },
    {
        name = "ei-processing-unit-circuit-board",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-advanced-semiconductor", amount = 1},
            {type = "item", name = "ei-electronic-parts", amount = 1},
            {type = "item", name = "ei-superior-data", amount = 8},
            {type = "item", name = "ei-circuit-board", amount = 1},
        },
        results = {
            {type = "item", name = "processing-unit", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "processing-unit",
        subgroup = "intermediate-product",
        order = "g[processing-unit]-a",
        icon = ei_graphics_other_path.."processing-unit.png",
        icon_size = 64,
    },
    {
        name = "ei-fission-tech-u235",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "stone", amount = 6},
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
            {type = "item", name = "uranium-235", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
        },
        results = {
            {type = "item", name = "ei-fission-tech", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fission-tech",
    },
    {
        name = "ei-fission-tech-u233",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "stone", amount = 6},
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
            {type = "item", name = "ei-uranium-233", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
        },
        results = {
            {type = "item", name = "ei-fission-tech", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fission-tech",
    },
    {
        name = "ei-fission-tech-pt239",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "stone", amount = 6},
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
            {type = "item", name = "ei-plutonium-239", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
        },
        results = {
            {type = "item", name = "ei-fission-tech", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fission-tech",
    },
    {
        name = "ei-fission-tech-th232",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "stone", amount = 6},
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
            {type = "item", name = "ei-thorium-232", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
        },
        results = {
            {type = "item", name = "ei-fission-tech", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fission-tech",
    },
    {
        name = "ei-magnet-data",
        type = "recipe",
        category = "ei-quantum-computer",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 100},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "item", name = "ei-magnet", amount = 1},
        },
        results = {
            {type = "item", name = "ei-magnet-data", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-magnet-data",
    },
    {
        name = "ei-fusion-data",
        type = "recipe",
        category = "ei-quantum-computer",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 100},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "item", name = "ei-superior-data", amount = 3},
            {type = "item", name = "ei-plasma-data", amount = 3},
            {type = "item", name = "ei-magnet-data", amount = 3},
        },
        results = {
            {type = "item", name = "ei-fusion-data", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fusion-data",
    },
    {
        name = "ei-fusion-quantum-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-charged-neutron-container", amount = 1},
            {type = "item", name = "ei-simulation-data", amount = 20},
            {type = "item", name = "ei-fusion-data", amount = 3},
        },
        results = {
            {type = "item", name = "ei-fusion-quantum-age-tech", amount = 10},
            {type = "item", name = "ei-neutron-container", amount = 1, probability = 0.99},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fusion-quantum-age-tech",
    },
    {
        name = "ei-exotic-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 240,
        ingredients = {
            {type = "item", name = "ei-high-tech-parts", amount = 2},
            {type = "item", name = "ei-superior-data", amount = 10},
            {type = "item", name = "ei-cavity", amount = 1},
        },
        results = {
            {type = "item", name = "ei-exotic-age-tech", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-exotic-age-tech",
    },
    {
        name = "ei-fusion-drive",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-personal-reactor", amount = 1},
            {type = "item", name = "energy-shield-mk2-equipment", amount = 2},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
        },
        results = {
            {type = "item", name = "ei-fusion-drive", amount = 100},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fusion-drive",
    },
    {
        name = "ei-dt-mix",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-empty-cryo-container", amount = 1},
            {type = "fluid", name = "ei-deuterium", amount = 1},
            {type = "fluid", name = "ei-tritium", amount = 1},
        },
        results = {
            {type = "item", name = "ei-dt-mix", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dt-mix",
    },
    {
        name = "ei-plasma-cube",
        type = "recipe",
        category = "ei-advanced-chem-plant",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-empty-cryo-container", amount = 4},
            {type = "item", name = "ei-carbon-structure", amount = 2},
            {type = "fluid", name = "ei-heated-protium", amount = 10},
        },
        results = {
            {type = "item", name = "ei-plasma-cube", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-plasma-cube",
    },
    {
        name = "ei-eu-circuit",
        type = "recipe",
        category = "crafting",
        energy_required = 14,
        ingredients = {
            {type = "item", name = "processing-unit", amount = 2},
            {type = "item", name = "ei-enriched-cryodust", amount = 4},
            {type = "item", name = "ei-circuit-board", amount = 1},
            {type = "item", name = "ei-superior-data", amount = 8},
        },
        results = {
            {type = "item", name = "ei-eu-circuit", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-eu-circuit",
    },
    {
        name = "ei-eu-magnet",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-magnet", amount = 6},
            {type = "item", name = "ei-enriched-cryodust", amount = 1},
            {type = "item", name = "ei-clean-plating", amount = 2},
            {type = "fluid", name = "ei-oxygen-gas", amount = 200},
        },
        results = {
            {type = "item", name = "ei-eu-magnet", amount = 1},
            {type = "item", name = "ei-cryocondensate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-eu-magnet",
    },
    {
        name = "ei-enriched-cryodust",
        type = "recipe",
        category = "ei-growing",
        energy_required = 30,
        ingredients = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "item", name = "ei-condensed-cryodust", amount = 10},
            {type = "fluid", name = "ei-bio-sludge", amount = 50},
        },
        results = {
            {type = "item", name = "ei-enriched-cryodust", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-enriched-cryodust",
    },
    {
        name = "ei-high-tech-parts",
        type = "recipe",
        category = "ei-exotic-assembler",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-eu-magnet", amount = 1},
            {type = "item", name = "ei-eu-circuit", amount = 1},
            {type = "item", name = "ei-plasma-cube", amount = 1},
            {type = "item", name = "ei-exotic-matter-up", amount = 1},
        },
        results = {
            {type = "item", name = "ei-high-tech-parts", amount = 5},
            {type = "item", name = "ei-exotic-matter-down", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-high-tech-parts",
    },
    {
        name = "ei-bio-armor",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-odd-plating", amount = 40},
            {type = "item", name = "power-armor-mk2", amount = 1},
            {type = "item", name = "ei-superior-data", amount = 100},
            {type = "item", name = "ei-magnet", amount = 20},
        },
        results = {
            {type = "item", name = "ei-bio-armor", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-bio-armor",
    },
    {
        name = "ei-advanced-rocket-fuel",
        type = "recipe",
        category = "centrifuging",
        energy_required = 20,
        ingredients = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 15},
            {type = "item", name = "rocket-fuel", amount = 2},
        },
        results = {
            {type = "item", name = "ei-advanced-rocket-fuel", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-rocket-fuel",
    },
    {
        name = "ei-lithium-crystal",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "lithium", amount = 1},
            {type = "fluid", name = "ei-liquid-oxygen", amount = 15},
        },
        results = {
            {type = "item", name = "ei-lithium-crystal", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-lithium-crystal",
    },
    {
        name = "ei-lithium-seperation",
        type = "recipe",
        category = "oil-processing",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-lithium-crystal", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-lithium-6", amount = 10, probability = 0.07},
            {type = "fluid", name = "ei-lithium-7", amount = 10, probability = 0.93},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-lithium-6",
    },
    {
        name = "ei-heated-lithium-6",
        type = "recipe",
        category = "ei-plasma-heater",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-lithium-6", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-heated-lithium-6", amount = ei_data.fusion.plasma_per_unit},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-heated-lithium-6",
    },
    {
        name = "ei-charged-neutron-container-pt239",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-neutron-container", amount = 6},
            {type = "item", name = "ei-plutonium-239", amount = 1},
        },
        results = {
            {type = "item", name = "ei-charged-neutron-container", amount = 6},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charged-neutron-container",
    },
    {
        name = "ei-charged-neutron-container-u235",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-neutron-container", amount = 4},
            {type = "item", name = "uranium-235", amount = 1},
        },
        results = {
            {type = "item", name = "ei-charged-neutron-container", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charged-neutron-container",
    },
    {
        name = "ei-charged-neutron-container-u233",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-neutron-container", amount = 4},
            {type = "item", name = "ei-uranium-233", amount = 1},
        },
        results = {
            {type = "item", name = "ei-charged-neutron-container", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charged-neutron-container",
    },
    {
        name = "ei-charged-neutron-container-th232",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-neutron-container", amount = 2},
            {type = "item", name = "ei-thorium-232", amount = 1},
        },
        results = {
            {type = "item", name = "ei-charged-neutron-container", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charged-neutron-container",
    },
    {
        name = "ei-charged-neutron-container-u238",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-neutron-container", amount = 1},
            {type = "item", name = "uranium-238", amount = 10},
        },
        results = {
            {type = "item", name = "ei-charged-neutron-container", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charged-neutron-container",
    },
    {
        name = "ei-fish-growing",
        type = "recipe",
        category = "ei-growing",
        energy_required = 120,
        ingredients = {
            {type = "fluid", name = "water", amount = 100},
            {type = "item", name = "raw-fish", amount = 1},
            {type = "item", name = "ei-alien-resin", amount = 25},
        },
        results = {
            {type = "item", name = "raw-fish", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "raw-fish",
    },
    {
        name = "ei-odd-plating",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 5},
            {type = "item", name = "ei-sus-plating", amount = 1},
            {type = "item", name = "ei-condensed-cryodust", amount = 1},
            {type = "item", name = "ei-alien-resin", amount = 4},
        },
        results = {
            {type = "item", name = "ei-odd-plating", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-odd-plating",
    },
    {
        name = "ei-bio-carbon-structure",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 120,
        ingredients = {
            {type = "item", name = "ei-carbon-nanotube", amount = 2},
            {type = "item", name = "low-density-structure", amount = 2},
            {type = "item", name = "ei-bio-matter", amount = 3},
            {type = "fluid", name = "ei-nitrogen-gas", amount = 150},
        },
        results = {
            {type = "item", name = "ei-carbon-structure", amount = 8},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_carbon-structure.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-g",
    },
    {
        name = "ei-bio-magnet",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-neodym-ingot", amount = 3},
            {type = "item", name = "ei-gold-ingot", amount = 2},
            {type = "item", name = "ei-insulated-wire", amount = 20},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "item", name = "ei-bio-matter", amount = 3},
        },
        results = {
            {type = "item", name = "ei-magnet", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_magnet.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-h",
    },
    {
        name = "ei-bio-rocket-fuel",
        type = "recipe",
        category = "ei-advanced-refinery",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "solid-fuel", amount = 20},
            {type = "item", name = "ei-cryodust", amount = 5},
            {type = "item", name = "ei-bio-matter", amount = 4},
            {type = "fluid", name = "petroleum-gas", amount = 45},
            {type = "fluid", name = "ei-ammonia-gas", amount = 55},
        },
        results = {
            {type = "item", name = "rocket-fuel", amount = 12},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_rocket-fuel.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-i",
    },
    {
        name = "ei-rocket-parts-odd-plating",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="ei-rocket-control-unit", amount=1},
            {type="item", name="ei-carbon-structure", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8},
            {type="item", name="ei-insulated-wire", amount=6},
            {type="item", name="ei-odd-plating", amount=4},
        },
        results = {{type="item", name="ei-rocket-parts", amount=4}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-rocket-parts",
    },
    {
        name = "ei-neodym-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 3.5,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min=15,amount_max=20},
            {type = "item", name = "ei-crushed-neodym", amount = 1,probability=0.01},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "e",
        icon = ei_graphics_other_path.."neodym-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-neodym-extraction-morphium",
        type = "recipe",
        category = "centrifuging",
        energy_required = 3.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 100},
            {type="item",name="ei-high-energy-crystal",amount=1}
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 20,amount_max=80},
            {type = "item", name = "ei-crushed-neodym", amount = 1},
            {type="item",name="ei-energy-crystal",amount=1,probability=0.05}
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "e2",
        icon = ei_graphics_other_path.."neodym-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-clean-plating",
        type = "recipe",
        category = "ei-bio-reactor",
        energy_required = 40,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 50},
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 10},
            {type = "item", name = "ei-odd-plating", amount = 2},
            {type = "item", name = "plastic-bar", amount = 20},
            {type = "item", name = "ei-neodym-ingot", amount = 1},
        },
        results = {
            {type = "item", name = "ei-clean-plating", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-clean-plating",
    },
    {
        name = "ei-cavity",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 40,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 200},
            {type = "item", name = "ei-clean-plating", amount = 4},
            {type = "item", name = "ei-glass", amount = 15},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 10},
            {type = "item", name = "ei-eu-magnet", amount = 2},
            {type = "item", name = "ei-superior-data", amount = 10},
        },
        results = {
            {type = "item", name = "ei-cavity", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-cavity",
    },
    {
        name = "ei-photon-cavity",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 300,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 25},
            {type = "item", name = "ei-simulation-data", amount = 10},
            {type = "item", name = "ei-cavity", amount = 1},
        },
        results = {
            {type = "item", name = "ei-photon-cavity", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-photon-cavity",
    },
    {
        name = "ei-gluon-cavity",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 300,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 25},
            {type = "item", name = "ei-blooming-evolved-alien-seed", amount = 10},
            {type = "item", name = "ei-cavity", amount = 1},
        },
        results = {
            {type = "item", name = "ei-gluon-cavity", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-gluon-cavity",
    },
    {
        name = "ei-z-boson-cavity",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 300,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 25},
            {type = "item", name = "ei-simulation-data", amount = 10},
            {type = "item", name = "ei-cavity", amount = 1},
        },
        results = {
            {type = "item", name = "ei-z-boson-cavity", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-z-boson-cavity",
    },
    {
        name = "ei-speed-module-4",
        type = "recipe",
        category = "crafting",
        energy_required = 80,
        ingredients = {
            {type = "item", name = "speed-module-3", amount = 2},
            {type = "item", name = "ei-computing-unit", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-speed-module-4", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-speed-module-4",
    },
    {
        name = "ei-efficiency-module-4",
        type = "recipe",
        category = "crafting",
        energy_required = 80,
        ingredients = {
            {type = "item", name = "efficiency-module-3", amount = 2},
            {type = "item", name = "ei-computing-unit", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-efficiency-module-4", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-efficiency-module-4",
    },
    {
        name = "ei-productivity-module-4",
        type = "recipe",
        category = "crafting",
        energy_required = 80,
        ingredients = {
            {type = "item", name = "productivity-module-3", amount = 2},
            {type = "item", name = "ei-computing-unit", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-productivity-module-4", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-productivity-module-4",
    },
    {
        name = "ei-speed-module-5",
        type = "recipe",
        category = "crafting",
        energy_required = 120,
        ingredients = {
            {type = "item", name = "ei-speed-module-4", amount = 2},
            {type = "item", name = "ei-odd-plating", amount = 10},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-speed-module-5", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-speed-module-5",
    },
    {
        name = "ei-efficiency-module-5",
        type = "recipe",
        category = "crafting",
        energy_required = 120,
        ingredients = {
            {type = "item", name = "ei-efficiency-module-4", amount = 2},
            {type = "item", name = "ei-odd-plating", amount = 10},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-efficiency-module-5", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-efficiency-module-5",
    },
    {
        name = "ei-productivity-module-5",
        type = "recipe",
        category = "crafting",
        energy_required = 120,
        ingredients = {
            {type = "item", name = "ei-productivity-module-4", amount = 2},
            {type = "item", name = "ei-odd-plating", amount = 10},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-productivity-module-5", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-productivity-module-5",
    },
    {
        name = "ei-speed-module-6",
        type = "recipe",
        category = "crafting",
        energy_required = 240,
        ingredients = {
            {type = "item", name = "ei-speed-module-5", amount = 2},
            {type = "item", name = "ei-photon-cavity", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-speed-module-6", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-speed-module-6",
    },
    {
        name = "ei-efficiency-module-6",
        type = "recipe",
        category = "crafting",
        energy_required = 240,
        ingredients = {
            {type = "item", name = "ei-efficiency-module-5", amount = 2},
            {type = "item", name = "ei-gluon-cavity", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-efficiency-module-6", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-efficiency-module-6",
    },
    {
        name = "ei-productivity-module-6",
        type = "recipe",
        category = "crafting",
        energy_required = 240,
        ingredients = {
            {type = "item", name = "ei-productivity-module-5", amount = 2},
            {type = "item", name = "ei-z-boson-cavity", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
        },
        results = {
            {type = "item", name = "ei-productivity-module-6", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-productivity-module-6",
    },
    {
        name = "ei-gauss-module",
        type = "recipe",
        category = "crafting",
        energy_required = 600,
        ingredients = {
            {type = "item", name = "ei-productivity-module-6", amount = 4},
            {type = "item", name = "ei-speed-module-6", amount = 4},
            {type = "item", name = "ei-efficiency-module-6", amount = 4},
            {type = "item", name = "ei-high-tech-parts", amount = 25},
        },
        results = {
            {type = "item", name = "ei-gauss-module", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-gauss-module",
    },
    {
        name = "ei-personal-reactor",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="ei-plasma-cube", amount=4},
            {type="item", name="processing-unit", amount=100},
            {type="item", name="ei-fusion-data", amount=40},
        },
        results = {{type="item", name="ei-personal-reactor", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-personal-reactor",
    },
})

--TECHS
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-neodym-dirty-water-usage",
        type = "technology",
        icon = ei_graphics_tech_path.."morphium-usage.png", --used to be called dirty-water-usage.png ...
        icon_size = 128,
        prerequisites = {"ei-neodym-refining"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-neodym-extraction"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-neodym-morphium-usage",
        type = "technology",
        icon = ei_path.."graphics/tech/morphium-usage.png",
        icon_size = 128,
        prerequisites = {"ei-neodym-refining"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-neodym-extraction-morphium"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-bio-carbon-structure",
        type = "technology",
        icon = ei_graphics_other_path.."bio_carbon-structure.png",
        icon_size = 64,
        prerequisites = {"ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-carbon-structure"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-rocket-fuel",
        type = "technology",
        icon = ei_graphics_other_path.."bio_rocket-fuel.png",
        icon_size = 64,
        prerequisites = {"ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-rocket-fuel"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-magnet",
        type = "technology",
        icon = ei_graphics_other_path.."bio_magnet.png",
        icon_size = 64,
        prerequisites = {"ei-odd-plating", "ei-neodym-refining"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-magnet"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-neodym-refining",
        type = "technology",
        icon = ei_graphics_tech_path.."neodym-refining.png",
        icon_size = 128,
        prerequisites = {"ei-quantum-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-neodym"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-pure-crushed-neodym"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-neodym-solution"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-neodym"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-neodym-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-neodym-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-magnet"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-magnet-data",
        type = "technology",
        icon = ei_graphics_tech_path.."magnet-data.png",
        icon_size = 128,
        prerequisites = {"ei-quantum-computer"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-magnet-data"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-fish-growing",
        type = "technology",
        icon = ei_graphics_tech_path.."fish-growing.png",
        icon_size = 256,
        prerequisites = {"ei-quantum-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-fish-growing"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-cavity",
        type = "technology",
        icon = ei_graphics_tech_path.."cavity.png",
        icon_size = 128,
        prerequisites = {"ei-clean-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cavity"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-clean-plating",
        type = "technology",
        icon = ei_graphics_tech_path.."clean-plating.png",
        icon_size = 128,
        prerequisites = {"ei-odd-plating", "ei-quantum-computer", "ei-enriched-cryodust"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-clean-plating"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-eu-magnet"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-odd-plating",
        type = "technology",
        icon = ei_graphics_tech_path.."odd-plating.png",
        icon_size = 128,
        prerequisites = {"ei-oxygen-difluoride", "ei-nano-factory"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-odd-plating"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-parts-odd-plating"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-fusion-data",
        type = "technology",
        icon = ei_graphics_tech_path.."fusion.png",
        icon_size = 256,
        prerequisites = {"ei-magnet-data", "ei-plasma-heater", "ei-nano-factory"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-fusion-data"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-fusion-quantum-age-tech"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-neutron-container"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-charged-neutron-container-pt239"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-charged-neutron-container-u235"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-charged-neutron-container-u238"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-charged-neutron-container-u233"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-charged-neutron-container-th232"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-tritium-breeding",
        type = "technology",
        icon = ei_graphics_tech_path.."tritium-breeding.png",
        icon_size = 256,
        prerequisites = {"ei-fusion-reactor", "laser-weapons-damage-6", "ei-neutron-collector"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-deuterium-activator"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-tritium-activator"
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
        name = "ei-fusion-drive",
        type = "technology",
        icon = ei_graphics_item_path.."fusion-drive.png",
        icon_size = 128,
        prerequisites = {"ei-personal-reactor"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-fusion-drive"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dt-mix"
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
        name = "ei-advanced-fission-tech",
        type = "technology",
        icon = ei_graphics_tech_path.."advanced-fission-tech.png",
        icon_size = 256,
        prerequisites = {"ei-neodym-refining"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-fission-tech-u235"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-fission-tech-u233"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-fission-tech-pt239"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-fission-tech-th232"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-lithium-processing",
        type = "technology",
        icon = ei_graphics_tech_path.."lithium-processing.png",
        icon_size = 128,
        prerequisites = {"ei-fusion-data"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-lithium-crystal"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lithium-seperation"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-heated-lithium-6"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-neutron-activator"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lithium-6-activator"
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
        name = "ei-bio-armor",
        type = "technology",
        icon = ei_graphics_tech_path.."bio-armor.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-armor"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-personal-solar-3",
        type = "technology",
        icon = ei_graphics_tech_path.."personal-solar-3.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-solar-panel-3", "ei-nano-factory"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-solar-3"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-personal-shield",
        type = "technology",
        icon = ei_graphics_other_path.."personal-shield.png",
        icon_size = 256,
        prerequisites = {"ei-quantum-computer", "ei-nano-factory"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-shield"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-bug-zapper",
        type = "technology",
        icon = ei_graphics_other_path.."bug-zapper.png",
        icon_size = 256,
        prerequisites = {"ei-high-tech-parts"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bug-zapper"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-bug-zapper-remote"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["both-quantum-age"],
            time = 20
        },
        age = "both-quantum-age",
    },
    {
        name = "ei-heavy-minigun",
        type = "technology",
        icon = ei_graphics_tech_path.."heavy-minigun.png",
        icon_size = 256,
        prerequisites = {"ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-heavy-minigun"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-speed-module-4",
        type = "technology",
        icon = ei_graphics_tech_path.."speed-module-4.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-neodym-refining", "speed-module-3"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-speed-module-4"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-efficiency-module-4",
        type = "technology",
        icon = ei_graphics_tech_path.."effectivity-module-4.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-neodym-refining", "efficiency-module-3"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-efficiency-module-4"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-productivity-module-4",
        type = "technology",
        icon = ei_graphics_tech_path.."productivity-module-4.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-neodym-refining", "productivity-module-3"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-productivity-module-4"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-speed-module-5",
        type = "technology",
        icon = ei_graphics_tech_path.."speed-module-5.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-speed-module-4", "ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-speed-module-5"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-efficiency-module-5",
        type = "technology",
        icon = ei_graphics_tech_path.."effectivity-module-5.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-efficiency-module-4", "ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-efficiency-module-5"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-productivity-module-5",
        type = "technology",
        icon = ei_graphics_tech_path.."productivity-module-5.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-productivity-module-4", "ei-odd-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-productivity-module-5"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-speed-module-6",
        type = "technology",
        icon = ei_graphics_tech_path.."speed-module-6.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-speed-module-5", "ei-cavity"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-speed-module-6"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-photon-cavity"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["space-quantum-age"],
            time = 20
        },
        age = "space-quantum-age",
    },
    {
        name = "ei-efficiency-module-6",
        type = "technology",
        icon = ei_graphics_tech_path.."effectivity-module-6.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-efficiency-module-5", "ei-cavity"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-efficiency-module-6"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gluon-cavity"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["space-quantum-age"],
            time = 20
        },
        age = "space-quantum-age",
    },
    {
        name = "ei-productivity-module-6",
        type = "technology",
        icon = ei_graphics_tech_path.."productivity-module-6.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-productivity-module-5", "ei-cavity"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-productivity-module-6"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-z-boson-cavity"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["space-quantum-age"],
            time = 20
        },
        age = "space-quantum-age",
    },
    {
        name = "ei-gauss-module",
        type = "technology",
        icon = ei_graphics_tech_path.."gauss-module.png",
        icon_size = 128,
        prerequisites = {"ei-productivity-module-6", "ei-speed-module-6", "ei-efficiency-module-6", "ei-high-tech-parts"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-gauss-module"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["both-quantum-age"],
            time = 20
        },
        age = "both-quantum-age",
    },
    {
        name = "ei-enriched-cryodust",
        type = "technology",
        icon = ei_graphics_tech_2_path.."enriched-cryodust.png",
        icon_size = 256,
        prerequisites = {"ei-fish-growing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-enriched-cryodust"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-plasma-cube",
        type = "technology",
        icon = ei_graphics_tech_path.."plasma-cube.png",
        icon_size = 128,
        prerequisites = {"ei-fusion-data"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-cube"
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
        name = "ei-eu-circuit",
        type = "technology",
        icon = ei_graphics_tech_path.."eu-circuits.png",
        icon_size = 128,
        prerequisites = {"ei-clean-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-pre-circuit-board"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-circuit-board"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-eu-circuit"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-processing-unit-circuit-board"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-personal-reactor",
        type = "technology",
        icon = ei_graphics_other_path.."personal-reactor.png",
        icon_size = 256,
        prerequisites = {"ei-fusion-reactor", "ei-plasma-cube"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-reactor"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
})

--OTHER
------------------------------------------------------------------------------------------------------
data:extend({
    {
        type = "sprite",
        name = "ei-overload-icon",
        filename = ei_graphics_other_path.."overload-icon.png",
        size = 64,
        scale = 1
    },
    {
        type = "animation",
        name = "ei-overload-animation",
        filename = ei_graphics_other_path.."overload-animation.png",
        draw_as_glow = true,
        line_length = 16,
        width = 592/16,
        height = 35,
        frame_count = 16,
        animation_speed = 1,
        scale = 1,
    },
    {
        type = "animation",
        name = "ei-neutron-collector_top",
        filename = ei_graphics_entity_path.."neutron-collector_top.png",
        line_length = 8,
        lines_per_file = 8,
        --width = 36,
        --height = 29,
        width = 512,
        height = 512,
        frame_count = 64,
        animation_speed = 1,
        shift = {0,-0.2},
	    scale = 0.44/2,
        run_mode = "backward",
    },
    {
        name = "ei-bio-armor",
        type = "equipment-grid",
        equipment_categories = {"armor"},
        width = 14,
        height = 14,
    },
    {
        name = "ei-personal-reactor",
        type = "generator-equipment",
        power = "3MW",
        categories = {"armor"},
        sprite = {
            filename = ei_graphics_other_path.."personal-reactor.png",
            width = 256,
            height = 256,
            priority = "medium"
        },
        shape = {
            width = 4,
            height = 4,
            type = "full"
        },
        energy_source = {
            type = "electric",
            usage_priority = "secondary-output"
        },
        take_result = "ei-personal-reactor",
    },
})

table.insert(data.raw["technology"]["ei-exotic-age"].effects, {
    type = "unlock-recipe",
    recipe = "ei-exotic-age-tech"
})

table.insert(data.raw["technology"]["ei-exotic-age"].effects, {
    type = "unlock-recipe",
    recipe = "ei-exotic-matter"
})

table.insert(data.raw["technology"]["ei-exotic-age"].effects, {
    type = "unlock-recipe",
    recipe = "ei-crushed-promethium-asteroid-chunk"
})

data.raw["technology"]["ei-exotic-age"].prerequisites = {
    "ei-high-tech-parts", "ei-cavity"
}