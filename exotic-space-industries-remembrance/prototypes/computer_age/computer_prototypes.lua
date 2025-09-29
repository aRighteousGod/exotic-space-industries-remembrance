-- this file contains the prototype definition for varios stuff from computer age

local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-module-part",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/module-part.png",
        icon_size = 512,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = ei_graphics_3_path.."graphics/item/module-part.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/module-part-2.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/module-part-3.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            }
        },
        subgroup = "intermediate-product",
        order = "b7",
        stack_size = 50
    },
    {
        name = "ei-module-base",
        type = "item",
        icon = ei_graphics_item_path.."module-base.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "b8",
        stack_size = 50
    },
    {
        name = "ei-empty-cryo-container",
        type = "item",
        icon = ei_graphics_item_path.."empty-cryo-container.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "d[barrel]-1",
        stack_size = 50
    },
    {
        name = "ei-cryo-container-nitrogen",
        type = "item",
        icon = ei_graphics_item_path.."cryo-container-nitrogen.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "d[barrel]-1",
        stack_size = 50
    },
    {
        name = "ei-cryo-container-oxygen",
        type = "item",
        icon = ei_graphics_item_path.."cryo-container-oxygen.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "d[barrel]-2",
        stack_size = 50
    },
    --[[
    {
        name = "ei-charged-energy-crystal",
        type = "item",
        icon = ei_graphics_item_path.."charged-energy-crystal.png",
        icon_size = 64,
        subgroup = "raw-material",
        order = "g1",
        stack_size = 100
    },
    ]]
    {
        name = "ei-high-energy-crystal",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/high-energy-crystal.png",
        icon_size = 512,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = ei_graphics_3_path.."graphics/item/high-energy-crystal.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/high-energy-crystal-2.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/high-energy-crystal-3.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            }
        },
        spoil_ticks = 15 * minute,
        spoil_result = "ei-energy-crystal",
        subgroup = "raw-material",
        order = "g1",
        stack_size = 100
    },
    {
        name = "ei-advanced-motor",
        type = "item",
        icon = ei_graphics_item_path.."advanced-motor.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "i[electric-engine-unit]-1",
        stack_size = 50
    },
    {
        name = "ei-rocket-parts",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/rocket-parts.png",
        icon_size = 512,
        icon_mipmaps = 5,
        scale = 0.0625,
        subgroup = "intermediate-product",
        order = "p[rocket-fuel]-x-1",
        stack_size = 100
    },
    {
        name = "ei-advanced-computer-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."advanced-computer-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a4-1",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."advanced-computer-age-tech.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."computer-age-tech_light.png",
                scale = 0.5
              }
            }
        },
    },
    {
        name = "ei-alien-computer-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."alien-computer-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a4-2",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."alien-computer-age-tech.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."computer-age-tech_light.png",
                scale = 0.5
              }
            }
        },
    },
    {
        name = "ei-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a5",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."quantum-age-tech.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."quantum-age-tech_light.png",
                scale = 0.5
              }
            }
        },
    },
    
    {
        name = "ei-faulty-advanced-semiconductor",
        type = "item",
        icon = ei_graphics_item_path.."advanced-faulty-waver.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b4",
        stack_size = 50
    },
    
    {
        name = "ei-advanced-semiconductor",
        type = "item",
        icon = ei_graphics_item_path.."advanced-waver.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b3-2",
        stack_size = 50
    },
    {
        name = "ei-advanced-base-semiconductor",
        type = "item",
        icon = ei_graphics_item_path.."advanced-base-waver.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b3-1",
        stack_size = 50
    },
    {
        name = "ei-computing-unit",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/computing-unit.png",
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "b8-1",
        stack_size = 50
    },
    {
        name = "ei-personal-laser",
        type = "item",
        icon = ei_graphics_item_path.."personal-laser.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "military-equipment",
        order = "b[active-defense]-a[personal-laser-defense-equipment]-a",
        place_as_equipment_result = "ei-personal-laser",
        stack_size = 20
    },
    {
        name = "ei-personal-laser",
        type = "active-defense-equipment",
        sprite = {
            filename = ei_graphics_other_path.."personal-laser.png",
            width = 128,
            height = 128,
            priority = "medium"
        },
        shape = {
            width = 2,
            height = 2,
            type = "full"
        },
        energy_source = {
            type = "electric",
            buffer_capacity = "10MJ",
            input_flow_limit = "500kW",
            usage_priority = "primary-input"
        },
        automatic = true,
        attack_parameters = {
            ammo_category = "laser",
            ammo_type = {
                action = {
                    action_delivery = {
                        beam = "laser-beam",
                        duration = 20,
                        max_length = 20,
                        source_offset = {
                            0,
                            -1.3143899999999999
                        },
                        type = "beam"
                    },
                    type = "direct"
                },
                energy_consumption = "100kJ"
            },
            cooldown = 20,
            damage_modifier = 4,
            range = 20,
            type = "beam"
        },
        -- energy_consumption = "100kW",
        take_result = "ei-personal-laser",
        categories = {"armor"}
    },
    {
        name = "ei-personal-leg",
        type = "item",
        icon = ei_graphics_item_path.."personal-leg.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "equipment",
        order = "d[exoskeleton]-b[personal-leg]",
        place_as_equipment_result = "ei-personal-leg",
        stack_size = 20
    },
    {
        name = "ei-personal-leg",
        type = "movement-bonus-equipment",
        sprite = {
            filename = ei_graphics_other_path.."personal-leg.png",
            width = 128,
            height = 256,
            priority = "medium"
        },
        shape = {
            width = 2,
            height = 4,
            type = "full"
        },
        energy_source = {
            type = "electric",
            buffer_capacity = "10MJ",
            input_flow_limit = "550kW",
            usage_priority = "primary-input"
        },
        energy_consumption = "500kW",
        movement_bonus = 0.7,
        take_result = "ei-personal-leg",
        categories = {"armor"}
    },
    {
        name = "ei-compound-ammo",
        type = "ammo",
        icon = ei_graphics_item_path.."compound-ammo.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "ammo",
        order = "a[basic-clips]-d[compound-ammo]",
        magazine_size = 100,
        pictures = {
            layers = {
              {
                filename = ei_graphics_item_path.."compound-ammo.png",
                mipmap_count = 4,
                scale = 0.5,
                size = 64
              },
              {
                draw_as_light = true,
                filename = "__base__/graphics/icons/uranium-rounds-magazine-light.png",
                flags = {
                  "light"
                },
                mipmap_count = 4,
                scale = 0.5,
                size = 64
              }
            }
        },
        stack_size = 200,
        ammo_category = "bullet",
        ammo_type = {
            action = {
                action_delivery = {
                    source_effects = {
                        entity_name = "explosion-gunshot",
                        type = "create-explosion"
                    },
                    target_effects = {
                        {
                            entity_name = "explosion-hit",
                            offset_deviation = {
                                { -0.5, -0.5 },
                                { 0.5, 0.5 }
                            },
                            offsets = {
                                { 0, 1 }
                            },
                            type = "create-entity"
                        },
                        {
                            damage = {
                                amount = 44,
                                type = "physical"
                            },
                            type = "damage"
                        },
                        {
                            damage = {
                                amount = 32,
                                type = "electric"
                            },
                            type = "damage"
                        },
                        {
                            type = "create-sticker",
                            sticker = "stun-sticker"
                        }
                    },
                    type = "instant"
                },
                type = "direct"
            },
        },
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
        name = "ei-cryodust",
        type = "item",
        icon = ei_graphics_item_2_path.."cryodust.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-alien-items-2",
        order = "a",
        pictures = {
            {
                filename = ei_graphics_item_2_path.."cryodust-1.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_2_path.."cryodust-2.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_2_path.."cryodust-3.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_2_path.."cryodust-4.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_2_path.."cryodust-5.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_2_path.."cryodust-6.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-condensed-cryodust",
        type = "item",
        icon = ei_graphics_item_2_path.."condensed-cryodust.png",
        icon_size = 128,
        stack_size = 100,
        subgroup = "ei-alien-items-2",
        order = "c",
        pictures = {
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-1.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-1.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-2.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-2.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-3.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-3.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-4.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-4.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-5.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-5.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."condensed-cryodust-6.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."condensed-cryodust-6.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
        },
    },
    {
        name = "ei-enriched-cryodust",
        type = "item",
        icon = ei_graphics_item_2_path.."enriched-cryodust.png",
        icon_size = 128,
        stack_size = 100,
        subgroup = "ei-alien-items-2",
        order = "d",
        pictures = {
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."enriched-cryodust.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."enriched-cryodust.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."enriched-cryodust-2.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."enriched-cryodust-2.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."enriched-cryodust-3.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."enriched-cryodust-3.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
            {
            layers = {
                {
                    filename = ei_graphics_item_2_path.."enriched-cryodust-4.png",
                    scale = 0.125,
                    size = 128
                },
                {
                    draw_as_light = true,
                    filename = ei_graphics_item_2_path.."enriched-cryodust-4.png",
                    scale = 0.125,
                    size = 128
                }
            },
            },
        },
    },
    {
        name = "ei-cryocondensate",
        type = "item",
        icon = ei_graphics_item_2_path.."cryocondensate.png",
        icon_size = 64,
        subgroup = "ei-alien-items-2",
        order = "b",
        stack_size = 20
    },
    {
        name = "ei-sus-plating",
        type = "item",
        icon = ei_graphics_item_path.."sus-plating.png",
        icon_size = 64,
        subgroup = "ei-alien-intermediates",
        order = "d-a",
        stack_size = 100
    },
    {
        name = "ei-bio-matter",
        type = "item",
        fuel_category = "ei-bio-matter",
        fuel_value = "1MJ",
        icon = ei_graphics_item_path.."bio-matter.png",
        icon_size = 64,
        subgroup = "ei-alien-intermediates",
        order = "c-b",
        stack_size = 10
    },
    {
        name = "ei-evolved-alien-seed",
        type = "item",
        icon = ei_graphics_item_path.."evolved-alien-seed.png",
        icon_size = 64,
        subgroup = "ei-alien-items",
        order = "c-a",
        stack_size = 100
    },
    {
        name = "ei-blooming-evolved-alien-seed",
        type = "item",
        icon = ei_graphics_item_path.."blooming-evolved-alien-seed.png",
        icon_size = 64,
        subgroup = "ei-alien-items",
        order = "c-b",
        spoil_ticks = 0.25 * hour,
        spoil_result = "ei-evolved-alien-seed",
        stack_size = 100
    },
    {
        name = "ei-silicon",
        type = "item",
        icon = ei_graphics_item_path.."silicon.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-secondary",
        order = "b1",
        pictures = {
            {
                filename = ei_graphics_item_path.."silicon.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."silicon-2.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."silicon-3.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."silicon-4.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."silicon-5.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-monosilicon",
        type = "item",
        icon = ei_graphics_item_path.."monosilicon.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-secondary",
        order = "b2",
        pictures = {
            {
                filename = ei_graphics_item_path.."monosilicon.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."monosilicon-2.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."monosilicon-3.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        type = "item",
        name = "ei-rocket-control-unit",
        icon = ei_graphics_3_path.."graphics/item/rocket-processing-unit.png",
        icon_size = 512,
        icon_mipmaps = 5,
        subgroup = "intermediate-product",
        order = "n[ei_rocket-control-unit]",
        stack_size = 100
      },
})

--RECIPES
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-sus-plating",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 2,
        ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "ei-bio-matter", amount = 1},
            {type = "item", name = "ei-alien-resin", amount = 1},
            {type = "fluid", name = "lubricant", amount = 5},
        },
        results = {
            {type = "item", name = "ei-sus-plating", amount = 1},
            {type = "item", name = "ei-bio-matter", amount = 1, probability = 0.8},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-sus-plating",
    },
    {
        name = "ei-bio-insulated-wire",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 2,
        ingredients = {
            {type = "item", name = "plastic-bar", amount = 2},
            {type = "item", name = "copper-cable", amount = 4},
            {type = "item", name = "ei-bio-matter", amount = 1},
        },
        results = {
            {type = "item", name = "ei-insulated-wire", amount = 4},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_insulated-wire.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-a",
    },
    {
        name = "ei-bio-energy-crystal",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-energy-crystal", amount = 1},
            {type = "fluid", name = "ei-acidic-water", amount = 10},
            {type = "item", name = "ei-bio-matter", amount = 1},
        },
        results = {
            {type = "item", name = "ei-energy-crystal", amount_min = 2,amount_max=3},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_3_path.."graphics/other/bio-energy-crystal.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-c",
    },
    {
        name = "ei-bio-high-energy-crystal",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "ei-crystal-solution", amount = 3},
            {type = "item", name = "ei-bio-matter", amount = 3},
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount_min = 2,amount_max=3},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        result_is_always_fresh = true,
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_3_path.."graphics/other/bio-high-energy-crystal.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-d",
    },
    {
        name = "ei-bio-hydrofluoric-acid",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-fluorite", amount = 1},
            {type = "fluid", name = "water", amount = 100},
            {type = "item", name = "sulfur", amount = 3},
            {type = "item", name = "ei-bio-matter", amount = 2},
        },
        results = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 250},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_hydrofluoric-acid.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-e",
    },
    {
        name = "ei-bio-nitric-acid",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 3,
        ingredients = {
            {type = "item", name = "ei-crushed-gold", amount = 1},
            {type = "fluid", name = "ei-dinitrogen-tetroxide-water-solution", amount = 10},
            {type = "fluid", name = "ei-oxygen-gas", amount = 5},
            {type = "item", name = "ei-bio-matter", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-nitric-acid", amount = 100},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."bio_nitric-acid.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-f",
    },
    {
        name = "ei-bio-electronic-parts",
        type = "recipe",
        category = "ei-bio-reactor",
        additional_categories = {"ei-bio-chamber","organic"},
        energy_required = 6,
        ingredients = {
            {type = "item", name = "battery", amount = 2},
            {type = "item", name = "ei-insulated-wire", amount = 2},
            {type = "item", name = "ei-cpu", amount = 1},
            {type = "item", name = "advanced-circuit", amount = 3},
            {type = "item", name = "ei-bio-matter", amount = 4},
        },
        results = {
            {type = "item", name = "ei-electronic-parts", amount = 5},
            {type="fluid",name="ei-bio-sludge",amount_min=1,amount_max=2,probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_3_path.."graphics/other/bio-electronic-parts.png",
        icon_size = 64,
        subgroup = "ei-alien-bio",
        order = "a-b",
    },
    {
        name = "ei-oxygen-difluoride",
        type = "recipe",
        category = "chemistry",
        energy_required = 9,
        ingredients = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 100},
            {type = "fluid", name = "ei-liquid-oxygen", amount = 50},
        },
        results = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount_min = 25,amount_max=45},
            {type = "fluid", name = "ei-hydrogen-gas", amount_min=5,amount_max=25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-oxygen-difluoride",
    },
    {
        name = "ei-oxygen-difluoride-alien",
        type = "recipe",
        category = "chemistry",
        energy_required = 12,
        ingredients = {
            {type = "fluid", name = "ei-liquid-oxygen", amount = 100},
            {type = "fluid", name = "sulfuric-acid", amount = 50},
            {type = "item", name = "ei-alien-resin", amount = 2},
            {type = "item", name = "ei-fluorite", amount = 2},
        },
        results = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount_min = 70, amount_max = 110},
            {type = "fluid", name = "ei-bio-sludge", amount_min=1,amount_max=6,probability=0.1,allow_productivity=false},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-oxygen-difluoride",
    },
    {
        name = "ei-undilute-morphium",
        type = "recipe",
        category = "chemistry",
        energy_required = 32,
        ingredients = {
            {type = "fluid", name = "ei-diluted-morphium", amount = 1000},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-morphium", amount = 10},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=15,probability=0.9,allow_productivity=false},
        },
        always_show_made_in = true,
        icon = ei_graphics_fluid_path.."diluted-morphium.png",
        icon_size = 256,
        enabled = false,
        main_product = "ei-morphium",
        subgroup = "ei-alien-intermediates",
        order = "a-a1",
    },
    {
        name = "ei-concentrated-morphium",
        type = "recipe",
        category = "chemistry",
        energy_required = 4,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 25},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 15},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-concentrated-morphium",
        subgroup = "ei-alien-intermediates",
        order = "a-a2",
    },
    {
        name = "ei-concentrated-morphium-light-oil",
        type = "recipe",
        category = "chemistry",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 8},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "steam", amount = 8},
        },
        results = {
            {type = "fluid", name = "light-oil", amount = 24},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "light-oil",
        subgroup = "ei-alien-intermediates",
        order = "a-a3",
    },
    
    {
        name = "ei-concentrated-morphium-kerosene",
        type = "recipe",
        category = "chemistry",
        energy_required = 16,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 16},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "steam", amount = 16},
        },
        results = {
            {type = "fluid", name = "ei-kerosene", amount = 48},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-kerosene",
        subgroup = "ei-alien-intermediates",
        order = "a-a4",
    },
    
    {
        name = "ei-concentrated-morphium-heavy-oil",
        type = "recipe",
        category = "chemistry",
        energy_required = 32,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 32},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "steam", amount = 32},
        },
        results = {
            {type = "fluid", name = "heavy-oil", amount = 96},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "heavy-oil",
        subgroup = "ei-alien-intermediates",
        order = "a-a5",
    },
    
    {
        name = "ei-concentrated-morphium-lubricant",
        type = "recipe",
        category = "chemistry",
        energy_required = 64,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 64},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "fluid", name = "steam", amount = 64},
        },
        results = {
            {type = "fluid", name = "lubricant", amount = 192},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "lubricant",
        subgroup = "ei-alien-intermediates",
        order = "a-a6",
    },


    {
        name = "ei-water",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 6,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 100},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
        },
        results = {
            {type = "item", name = modprefix.."sand", amount = 1},
            {type = "item", name = "ei-crushed-coal", amount = 1},
            {type = "item", name = "ei-crushed-sulfur", amount = 1},
            {type = "fluid", name = "water", amount = 100},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min=1,amount_max=2, probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-alien-intermediates",
        order = "a-b",
        main_product = "water",
    },
    {
        name = "ei-evolved-alien-seed",
        type = "recipe",
        category = "ei-bio-chamber",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "ei-ammonia-gas", amount = 25},
            {type = "item", name = "ei-alien-seed", amount = 1},
            {type = "fluid", name = "ei-phythogas", amount = 50},
        },
        results = {
            {type = "item", name = "ei-evolved-alien-seed", amount = 1},
            {type = "item", name = "ei-alien-seed", amount = 1, probability = 0.5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-evolved-alien-seed",
    },
    {
        name = "ei-blooming-evolved-alien-seed",
        type = "recipe",
        category = "ei-bio-chamber",
        energy_required = 20,
        ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 5},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
            {type = "item", name = "ei-evolved-alien-seed", amount = 1},
            {type = "fluid", name = "ei-phythogas", amount = 100},
        },
        results = {
            {type = "item", name = "ei-blooming-evolved-alien-seed", amount = 1},
           {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},

        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-blooming-evolved-alien-seed",
    },
    {
        name = "ei-bio-sludge",
        type = "recipe",
        category = "ei-bio-reactor",
        energy_required = 16,
        ingredients = {
            {type = "item", name = "ei-blooming-evolved-alien-seed", amount = 1},
            {type = "fluid", name = "ei-nitrogen-gas", amount = 25},
            {type = "fluid", name = "ei-oxygen-gas", amount = 25},
        },
        results = {
            {type = "item", name = "ei-evolved-alien-seed", amount = 1, probability = 0.5},
            {type = "item", name = "ei-blooming-evolved-alien-seed", amount = 1, probability = 0.25},
            {type = "item", name = "ei-bio-matter", amount = 1, probability = 0.5},
            {type = "fluid", name = "ei-bio-sludge", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-bio-sludge",
    },
    {
        name = "ei-bio-matter",
        type = "recipe",
        category = "ei-bio-reactor",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-bio-matter", amount = 1},
            {type = "item", name = "ei-crushed-coal", amount = 1},
            {type = "fluid", name = "ei-bio-sludge", amount = 10},
        },
        results = {
            {type = "item", name = "ei-bio-matter", amount = 2},
            {type = "fluid", name = "ei-bio-sludge", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-bio-matter",
    },
    {
        name = "ei-cryodust",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 5},
            {type = "item", name = modprefix.."sand", amount = 1},
            {type = "fluid", name = "ei-cryoflux", amount = 10},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-cryodust", amount = 1},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-cryodust",
    },
    {
        name = "ei-cryocondensate",
        type = "recipe",
        category = "centrifuging",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "ei-cryodust", amount = 10},
            {type = "item", name = "sulfur", amount = 4},
            {type = "fluid", name = "ei-cryoflux", amount = 25},
        },
        results = {
            {type = "item", name = "ei-cryodust", amount = 3},
            {type = "item", name = "ei-cryocondensate", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-cryocondensate",
    },
    {
        name = "ei-condensed-cryodust",
        type = "recipe",
        category = "ei-destill-tower",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-cryocondensate", amount = 10},
            {type = "item", name = "ei-crushed-coal", amount = 4},
            {type = "fluid", name = "ei-nitrogen-gas", amount = 25},
        },
        results = {
            {type = "item", name = "ei-cryocondensate", amount = 9},
            {type = "item", name = "ei-condensed-cryodust", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-condensed-cryodust",
    },
    {
        name = "ei-compound-ammo",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="uranium-rounds-magazine", amount=1},
            {type="item", name="ei-energy-crystal", amount=10},
            {type="item", name="explosives", amount=10},
        },
        results = {{type="item", name="ei-compound-ammo", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-compound-ammo",
    },
    {
        name = "ei-personal-laser",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="personal-laser-defense-equipment", amount=4},
            {type="item", name="ei-simulation-data", amount=30},
            {type="item", name="ei-high-energy-crystal", amount=20},
        },
        results = {{type="item", name="ei-personal-laser", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-personal-laser",
    },
    {
        name = "ei-personal-leg",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="exoskeleton-equipment", amount=4},
            {type="item", name="ei-simulation-data", amount=30},
            {type="item", name="ei-advanced-motor", amount=20},
        },
        results = {{type="item", name="ei-personal-leg", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-personal-leg",
    },
    {
        name = "ei-advanced-base-semiconductor",
        type = "recipe",
        category = "ei-waver-factory",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-nitric-acid", amount = 5},
            {type = "item", name = "ei-sand", amount = 8},
            {type = "item", name = "ei-semiconductor", amount = 1},
        },
        results = {
            {type = "item", name = "ei-advanced-base-semiconductor", amount = 1, probability = 0.75},
            {type = "item", name = "ei-faulty-semiconductor", amount = 1, probability = 0.25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-base-semiconductor",
    },
    {
        name = "ei-advanced-semiconductor",
        type = "recipe",
        category = "ei-waver-factory",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-crushed-gold", amount = 6},
            {type = "item", name = "ei-energy-crystal", amount = 2},
            {type = "item", name = "ei-advanced-base-semiconductor", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 10},
            {type = "item", name = "ei-advanced-semiconductor", amount = 1, probability = 0.75},
            {type = "item", name = "ei-faulty-advanced-semiconductor", amount = 1, probability = 0.25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-semiconductor",
    },
    {
        name = "ei-computing-unit",
        type = "recipe",
        category = "crafting",
        additional_categories = {"electronics"},
        energy_required = 15,
        ingredients = {
            {type = "item", name = "ei-rocket-control-unit", amount = 1},
            {type = "item", name = "ei-module-base", amount = 1},
            {type = "item", name = "ei-condensed-cryodust", amount = 1},
            {type = "item", name = "ei-sus-plating", amount = 3},
        },
        results = {
            {type = "item", name = "ei-computing-unit", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-computing-unit",
    },
    {
        name = "ei-molten-steel-mix",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-molten-iron", amount = 10},
            {type = "item", name = "ei-crushed-coke", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-steel", amount = 10, temperature = 900},
            {type = "item", name = "atan-ash", amount_min = 1, amount_max = 2, probability = 0.25,allow_productivity=false},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-steel",
        icon_size = 64,
        icon = ei_graphics_other_path.."molten-steel_coke.png"
    },
    {
        name = "ei-molten-steel-oxygen",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-molten-iron", amount = 20},
            {type = "fluid", name = "ei-oxygen-gas", amount = 20},
            {type = "item", name = "ei-crushed-coke", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-steel", amount = 20, temperature = 900},
            {type = "item", name = "atan-ash", amount_min = 1, amount_max = 2, probability = 0.05,allow_productivity=false},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-steel",
        icon_size = 64,
        icon = ei_graphics_other_path.."molten-steel_coal.png"
    },
    {
        name = "ei-module-part",
        type = "recipe",
        category = "crafting",
        additional_categories = {"electronics"},
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-electronic-parts", amount=1},
            {type="item", name="ei-ceramic", amount=4},
            {type="item", name="ei-crushed-gold", amount=2},
        },
        results = {{type="item", name="ei-module-part", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-module-part",
    },
    {
        name = "ei-rocket-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="ei-rocket-control-unit", amount=1},
            {type="item", name="low-density-structure", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=5},
            {type="item", name="ei-insulated-wire", amount=2},
            {type="item",name="ei-copper-beam",amount=1},
            {type = "item", name = "rocket-fuel", amount = 20}
        },
        results = {{type="item", name="ei-rocket-parts", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-rocket-parts",
    },
    {
        name = "ei-rocket-parts-advanced",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="ei-rocket-control-unit", amount=1},
            {type="item", name="low-density-structure", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=5},
            {type="item", name="ei-insulated-wire", amount=2},
            {type="item",name="ei-copper-beam",amount=1},
            {type = "item", name = "ei-advanced-rocket-fuel", amount = 5}
        },
        results = {{type="item", name="ei-rocket-parts", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-rocket-parts",
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
		type = "recipe",
		name = "ei-space-steam-1",
		category = "organic-or-chemistry",
		subgroup = "fluid-recipes",
		order = "d[other-chemistry]-b[space-steam]",
		enabled = false,
		energy_required = 1,
		ingredients =
		{
		  {type = "item", name = "coal", amount = 1},
		  {type = "item", name = "ice", amount = 1},
          {type = "fluid", name = "thruster-oxidizer", amount = 5}
		},
		results =
		{
		  {type = "fluid", name = "steam", amount = 100, temperature = 165}
		},
		allow_productivity = false,
		show_amount_in_title = false,
		allow_decomposition = false,
		icon = "__base__/graphics/icons/fluid/steam.png",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
        crafting_machine_tint =
		{
			primary = {r = 1.000, g = 0.912, b = 0.036, a = 1.000}, -- #ffe809ff
			secondary = {r = 0.707, g = 0.797, b = 0.335, a = 1.000}, -- #b4cb55ff
			tertiary = {r = 0.681, g = 0.635, b = 0.486, a = 1.000}, -- #ada17bff
			quaternary = {r = 1.000, g = 0.804, b = 0.000, a = 1.000}, -- #ffcd00ff
		}
    },
    {
        type = "recipe",
		name = "ei-space-steam-2",
		category = "organic-or-chemistry",
		subgroup = "fluid-recipes",
		order = "d[other-chemistry]-b[space-steam]",
		enabled = false,
		energy_required = 10,
		ingredients =
		{
		  {type = "item", name = "rocket-fuel", amount = 10},
		  {type = "fluid", name = "water", amount = 90},
		},
		results =
		{
		  {type = "fluid", name = "steam", amount = 1000, temperature = 165},
		},
		allow_productivity = false,
		show_amount_in_title = false,
		allow_decomposition = false,
		icon = "__base__/graphics/icons/fluid/steam.png",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
        crafting_machine_tint =
		{
			primary = {r = 1.000, g = 0.912, b = 0.036, a = 1.000}, -- #ffe809ff
			secondary = {r = 0.707, g = 0.797, b = 0.335, a = 1.000}, -- #b4cb55ff
			tertiary = {r = 0.681, g = 0.635, b = 0.486, a = 1.000}, -- #ada17bff
			quaternary = {r = 1.000, g = 0.804, b = 0.000, a = 1.000}, -- #ffcd00ff
		}
	  },
    {
        name = "ei-module-base",
        type = "recipe",
        category = "crafting",
        additional_categories = {"electronics"},
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-module-part", amount=1},
            {type="item", name="ei-energy-crystal", amount=1},
            {type="item", name="ei-glass", amount=2},
        },
        results = {{type="item", name="ei-module-base", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-module-base",
    },
    {
        name = "ei-emtpy-cryo-container",
        type = "recipe",
        category = "crafting",
        energy_required = 6,
        ingredients =
        {
            {type="item", name="plastic-bar", amount=8},
            {type="item", name="barrel", amount=1},
            {type="item", name="ei-ceramic", amount=10},
            {type="item", name="ei-glass", amount=8},
        },
        results = {{type="item", name="ei-empty-cryo-container", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-empty-cryo-container",
    },
    {
        name = "ei-fill-cryo-container-nitrogen",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-liquid-nitrogen", amount = ei_lib.config("barrel-capacity")},
            {type = "item", name = "ei-empty-cryo-container", amount = 1},
        },
        results = {
            {type = "item", name = "ei-cryo-container-nitrogen", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."fill-cryo-container-nitrogen.png",
        icon_size = 64,
        subgroup = "fill-barrel",
        order = "c-1",
    },
    {
        name = "ei-empty-cryo-container-nitrogen",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-cryo-container-nitrogen", amount = 1},
        },
        results = {
            {type = "item", name = "ei-empty-cryo-container", amount = 1},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = ei_lib.config("barrel-capacity")},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."empty-cryo-container-nitrogen.png",
        icon_size = 64,
        subgroup = "barrel",
        order = "c-1",
    },
    {
        name = "ei-fill-cryo-container-oxygen",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-liquid-oxygen", amount = ei_lib.config("barrel-capacity")},
            {type = "item", name = "ei-empty-cryo-container", amount = 1},
        },
        results = {
            {type = "item", name = "ei-cryo-container-oxygen", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."fill-cryo-container-oxygen.png",
        icon_size = 64,
        subgroup = "fill-barrel",
        order = "c-2",
    },
    {
        name = "ei-empty-cryo-container-oxygen",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-cryo-container-oxygen", amount = 1},
        },
        results = {
            {type = "item", name = "ei-empty-cryo-container", amount = 1},
            {type = "fluid", name = "ei-liquid-oxygen", amount = ei_lib.config("barrel-capacity")},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."empty-cryo-container-oxygen.png",
        icon_size = 64,
        subgroup = "barrel",
        order = "c-2",
    },
    {
        name = "ei-crystal-solution",
        type = "recipe",
        category = "chemistry",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 25},
            {type = "item", name = "ei-energy-crystal", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-crystal-solution", amount = 25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crystal-solution",
    },
    {
        name = "ei-high-energy-crystal",
        type = "recipe",
        category = "centrifuging",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-crystal-solution", amount = 100},
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability = 0.001},
            {type = "fluid", name = "ei-crystal-solution", amount_min = 1,amount_max=99},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-high-energy-crystal",
    },
    {
        name = "ei-high-energy-crystal-growing",
        type = "recipe",
        category = "ei-growing",
        energy_required = 60,
        ingredients = {
            {type = "fluid", name = "ei-crystal-solution", amount = 5},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount=1},
            {type = "item", name = "ei-high-energy-crystal", amount_min=1,amount_max=2,probability=0.05}
        },
        always_show_made_in = true,
        result_is_always_fresh = true,
        enabled = false,
        main_product = "ei-high-energy-crystal",
    },
    {
        name = "ei-quantum-age-tech",
        type = "recipe",
        category = "crafting",
        energy_required = 90,
        ingredients =
        {
            {type="item", name="ei-superior-data", amount=20},
            {type="item", name="ei-copper-beacon", amount=1},
            {type="item", name="ei-crystal-accumulator", amount=1},
            {type="item", name="ei-magnet", amount=2},
            {type="item", name="ei-computing-unit", amount=2},
        },
        results = {{type="item", name="ei-quantum-age-tech", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-quantum-age-tech",
    },
    {
        name = "ei-hydrogen",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "water", amount = 20},
        },
        results = {
            {type = "fluid", name = "ei-oxygen-gas", amount = 10},
            {type = "fluid", name = "ei-hydrogen-gas", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-hydrogen-gas",
    },
    {
        name = "ei-ammonia",
        type = "recipe",
        category = "chemistry",
        energy_required = 3,
        ingredients = {
            {type = "fluid", name = "ei-hydrogen-gas", amount = 30},
            {type = "fluid", name = "ei-nitrogen-gas", amount = 20},
        },
        results = {
            {type = "fluid", name = "ei-ammonia-gas", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-ammonia-gas",
    },
    {
        name = "ei-dinitrogen-tetroxide",
        type = "recipe",
        category = "chemistry",
        energy_required = 3,
        ingredients = {
            {type = "fluid", name = "ei-ammonia-gas", amount = 40},
            {type = "fluid", name = "ei-oxygen-gas", amount = 70},
            {type = "item", name = "ei-crushed-iron", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-dinitrogen-tetroxide-gas", amount = 40},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dinitrogen-tetroxide-gas",
    },
    {
        name = "ei-dinitrogen-tetroxide-water-solution",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-dinitrogen-tetroxide-gas", amount = 10},
            {type = "fluid", name = "water", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-dinitrogen-tetroxide-water-solution", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dinitrogen-tetroxide-water-solution",
    },
    {
        name = "ei-nitric-acid",
        type = "recipe",
        category = "chemistry",
        energy_required = 3,
        ingredients = {
            {type = "fluid", name = "ei-dinitrogen-tetroxide-water-solution", amount = 20},
            {type = "fluid", name = "ei-oxygen-gas", amount = 10},
            {type = "item", name = "ei-crushed-gold", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-nitric-acid", amount = 40},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-nitric-acid",
    },
    {
        name = "ei-advanced-computer-age-tech",
        type = "recipe",
        category = "advanced-crafting",
        energy_required = 56,
        ingredients = {
            {type = "item", name = "ei-advanced-motor", amount = 1},
            {type = "item", name = "processing-unit", amount = 12},
            {type = "item", name = "ei-data-pipe", amount = 12},
            {type = "fluid", name = "ei-nitric-acid", amount = 100},
        },
        results = {
            {type = "item", name = "ei-advanced-computer-age-tech", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-computer-age-tech",
    },
    {
        name = "ei-alien-computer-age-tech",
        type = "recipe",
        category = "advanced-crafting",
        energy_required = 70,
        ingredients = {
            {type = "item", name = "ei-blooming-alien-seed", amount = 5},
            {type = "item", name = "ei-high-energy-crystal", amount = 2},
            {type = "item", name = "ei-bio-matter", amount = 50},
            {type = "fluid", name = "ei-concentrated-morphium", amount = 100},
        },
        results = {
            {type = "item", name = "ei-alien-computer-age-tech", amount = 2},
           {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-alien-computer-age-tech",
    },
    {
        name = "ei-advanced-motor",
        type = "recipe",
        category = "crafting-with-fluid",
        icon = ei_graphics_3_path.."graphics/tech/advanced-motor.png",
        icon_size = 256,
        icon_mipmaps = 4,
        energy_required = 10,
        ingredients = {
            {type = "item", name = "electric-engine-unit", amount = 1},
            {type = "item", name = "ei-electronic-parts", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 2},
            {type = "fluid", name = "lubricant", amount = 150},
        },
        results = {
            {type = "item", name = "ei-advanced-motor", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-motor",
    },
    {
        name = "ei-advanced-motor-cryo",
        type = "recipe",
        category = "crafting-with-fluid",
        icon = ei_graphics_3_path.."graphics/tech/advanced-motor-cryo.png",
        icon_size = 256,
        icon_mipmaps = 4,
        energy_required = 8,
        ingredients = {
            {type = "item", name = "electric-engine-unit", amount = 1},
            {type = "item", name = "ei-electronic-parts", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 2},
            {type = "item", name = "ei-condensed-cryodust", amount = 2},
            {type = "fluid", name = "lubricant", amount = 15},
        },
        results = {
            {type = "item", name = "ei-advanced-motor", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-motor",
    },
    {
        name = "ei-battery-lithium",
        type = "recipe",
        category = "chemistry",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "lithium", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 1},
            {type = "fluid", name = "sulfuric-acid", amount = 15},
        },
        results = {
            {type = "item", name = "battery", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "battery",
        icon = ei_graphics_other_path.."lithium-battery.png",
        icon_size = 64,
    },
    {
        name = "ei-morphium-fluorite",
        type = "recipe",
        category = "centrifuging",
        energy_required = 4,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 50},
            {type = "item", name ="ei-high-energy-crystal", amount = 1}
        },
        results = {
            {type = "item", name = "ei-fluorite", amount = 1},
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability=0.10,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-alien-intermediates",
        order = "a-a2b",
        main_product = "ei-fluorite",
    },
    {
        name = "ei-copper-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 40},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "ei-pure-copper", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "b",
        main_product = "ei-pure-copper",
        icon_size = 64,
    },
    {
        name = "ei-iron-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 40},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "ei-pure-iron", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "a",
        main_product = "ei-pure-iron",
        icon_size = 64,
    },
    {
        name = "ei-gold-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 60},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "ei-pure-gold", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "c",
        main_product = "ei-pure-gold",
        icon_size = 64,
    },
    {
        name = "ei-lead-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 60},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "ei-pure-lead", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "d",
        main_product = "ei-pure-lead",
        icon_size = 64,
    },
    {
        name = "ei-uranium-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 2.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 100},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.9,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.10,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "uranium-ore", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "uranium-ore",
        order = "f",
        icon_size = 64,
    },

    {
        name = "ei-stone-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 2.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 10},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "stone", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        order = "f",
        icon_size = 64,
    },
    {
        name = "ei-sulfur-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 2.5,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 80},
            {type = "item", name = "ei-high-energy-crystal", amount=1}
        },
        results = {
            {type = "item", name = "ei-high-energy-crystal", amount = 1, probability=0.98,allow_productivity=false},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.02,allow_productivity=false},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=2, probability = 0.10,allow_productivity=false},
            {type = "item", name = "sulfur", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        order = "f",
        main_product = "sulfur",
        icon_size = 64,
    },


    {
        name = "ei-dirty-water-copper-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 40},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 10,amount_max=15,allow_productivity=false},
            {type = "item", name = "ei-pure-copper", amount = 1,probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "b",
        icon = ei_graphics_other_path.."copper-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-dirty-water-iron-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 40},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 10,amount_max=15,allow_productivity=false},
            {type = "item", name = "ei-pure-iron", amount = 1,probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "a",
        icon = ei_graphics_other_path.."iron-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-dirty-water-gold-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1.5,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 60},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 15,amount_max=25,allow_productivity=false},
            {type = "item", name = "ei-pure-gold", amount = 1,probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "c",
        icon = ei_graphics_other_path.."gold-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-dirty-water-lead-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 1.5,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 60},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 7,amount_max=8,allow_productivity=false},
            {type = "item", name = "ei-pure-lead", amount = 1,probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "d",
        icon = ei_graphics_other_path.."lead-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-dirty-water-uranium-extraction",
        type = "recipe",
        category = "centrifuging",
        energy_required = 2.5,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 80},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 15,amount_max=20,allow_productivity=false},
            {type = "item", name = "ei-crushed-uranium", amount = 1,probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-refining-extraction",
        order = "f",
        icon = ei_graphics_other_path.."uranium-extraction.png",
        icon_size = 64,
    },
    {
        name = "ei-dirty-water-stone",
        type = "recipe",
        category = "ei-advanced-chem-plant",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "water", amount = 10},
            {type = "item", name = "stone", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dirty-water",
    },

    {
        name = "ei-petroleum-reforming",
        type = "recipe",
        category = "ei-advanced-chem-plant",
        energy_required = 4,
        ingredients = {
            {type = "fluid", name = "petroleum-gas", amount = 40},
            {type = "fluid", name = "ei-hydrogen-gas", amount = 10},
        },
        results = {
            {type = "fluid", name = "water", amount_min = 3,amount_max=7},
            {type = "fluid", name = "heavy-oil", amount_min = 3,amount_max=7},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "heavy-oil",
        icon = ei_graphics_tech_path.."petroleum-reforming.png",
        icon_size = 128,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-g[petroleum-reforming]",
    },
    {
        name = "ei-silicon",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-hydrogen-gas", amount = 5},
            {type = "fluid", name = "ei-molten-glass", amount = 10},
        },
        results = {
            {type = "item", name = "ei-silicon", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-silicon",
    },
    {
        name = "ei-monosilicon",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-silicon", amount = 5},
            {type = "fluid", name = "ei-oxygen-gas", amount = 5},
        },
        results = {
            {type = "item", name = "ei-silicon", amount = 5, probability = 0.75},
            {type = "item", name = "ei-monosilicon", amount = 1, probability = 0.25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-monosilicon",
    },
    {
        name = "ei-semiconductor-monosilicon",
        type = "recipe",
        category = "ei-waver-factory",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 10},
            {type = "item", name = "ei-crushed-gold", amount = 5},
            {type = "item", name = "ei-monosilicon", amount = 1},
        },
        results = {
            {type = "item", name = "ei-semiconductor", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-semiconductor",
        icon = ei_graphics_other_path.."monosilicon_waver.png",
        icon_size = 128,
    },
    {
        name = "ei-advanced-semiconductor-monosilicon",
        type = "recipe",
        category = "ei-waver-factory",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-monosilicon", amount = 2},
            {type = "item", name = "ei-crushed-gold", amount = 6},
            {type = "item", name = "ei-energy-crystal", amount = 2},
            {type = "item", name = "ei-advanced-base-semiconductor", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 10},
            {type = "item", name = "ei-advanced-semiconductor", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-advanced-semiconductor",
        icon = ei_graphics_other_path.."monosilicon_advanced-waver.png",
        icon_size = 128,
    },

    {
        type = "recipe",
        name = "ei-rocket-control-unit",
        energy_required = 30,
        enabled = false,
        category = "crafting",
        icons = {{icon=ei_graphics_3_path.."graphics/item/rocket-processing-unit.png", tint={r=1.0, g=1.0, b=0.0}, icon_size = 512,icon_mipmaps = 5}},
        ingredients =
        {
            {type="item", name="advanced-circuit", amount=10},
            {type="item", name="low-density-structure", amount=2},
            {type="item", name="ei-insulated-wire", amount=6},
        },
        results={{type = "item", name= "ei-rocket-control-unit", amount=1}}
      },

    {
        type = "recipe",
        name = "ei-rocket-processing-unit",
        energy_required = 30,
        enabled = false,
        category = "crafting",
        ingredients =
        {
            {type="item", name="processing-unit", amount=1},
            {type="item", name="low-density-structure", amount=2},
            {type="item", name="ei-insulated-wire", amount=2},
        },
        results={{type = "item", name= "ei-rocket-control-unit", amount=1}}
      },
    {
        type = "recipe",
        name = "ei-oxygen-sulfuric-acid",
        category = "chemistry",
        subgroup = "fluid-recipes",
        order = "c[oil-products]-b[sulfuric-acid]2",
        energy_required = 1.8,
        icons = {
            { icon = data.raw.fluid["ei-oxygen-gas"].icon,            scale = 0.2, shift = { 3, 3 } },
            { icon = "__base__/graphics/icons/fluid/sulfuric-acid.png", scale = 0.2, shift = { -3, -3 } },
        },
        enabled = false,
        ingredients =
        {
            {type="fluid", name="ei-oxygen-gas", amount=30},
            {type="fluid", name="water", amount=50},
            {type="item", name="ei-crushed-iron", amount=2},
            {type="item", name="ei-crushed-sulfur", amount=14}
        },
        results =
        {
        {type = "fluid", name = "sulfuric-acid", amount_min=95,amount_max=125}
        },
    },
    --basic cryogenic fractionation
{
        name = "ei-liquid-nitrogen-oil-processing",
        type = "recipe",
        category = "oil-processing",
        energy_required = 10,
        ingredients =
        {
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "fluid", name = "crude-oil", amount = 50}
        },
        results =
        {
            {type="fluid", name="ei-kerosene", amount_min=48,amount_max=52},
            {type="fluid", name="ei-heavy-destilate", amount_min=33,amount_max=37},
            {type="fluid", name="ei-residual-oil", amount_min=18,amount_max=22},
        },
        --icon = ei_graphics_3_path.."graphics/other/basic-steam-oil-processing.png",
        --icon_size = 64,
        subgroup = "fluid-recipes",
        order = "a[oil-processing]-b[advanced-oil-processing]1",
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-kerosene",
    },
    --basic oxidative cracking
{
        name = "ei-liquid-oxygen-heavy-oil-cracking",
        type = "recipe",
        category = "oil-processing",
        energy_required = 10,
        ingredients =
        {
            {type = "fluid", name = "ei-liquid-oxygen", amount = 100},
            {type = "fluid", name = "heavy-oil", amount = 50}
        },
        results =
        {
            {type="fluid", name="petroleum-gas", amount_min=68,amount_max=72},
            {type="fluid", name="ei-benzol", amount_min=33,amount_max=37},
            {type="fluid", name="ei-coal-gas", amount_min=18,amount_max=22},
        },
        --icon = ei_graphics_3_path.."graphics/other/basic-steam-oil-processing.png",
        --icon_size = 64,
        subgroup = "fluid-recipes",
        order = "a[oil-processing]-b[advanced-oil-processing]2",
        always_show_made_in = true,
        enabled = false,
        main_product = "petroleum-gas",
    },
    --basic Acid Hydrolysis / Nitration
{
        name = "ei-nitric-acid-medium-destilate-cracking",
        type = "recipe",
        category = "oil-processing",
        energy_required = 10,
        ingredients =
        {
            {type = "fluid", name = "ei-nitric-acid", amount = 100},
            {type = "fluid", name = "ei-medium-destilate", amount = 50}
        },
        results =
        {
            {type="fluid", name="ei-diesel", amount_min=68,amount_max=72},
            {type="fluid", name="ei-ammonia-gas", amount_min=33,amount_max=37},
            {type="fluid", name="ei-dinitrogen-tetroxide-gas", amount_min=18,amount_max=22},
        },
        --icon = ei_graphics_3_path.."graphics/other/basic-steam-oil-processing.png",
        --icon_size = 64,
        subgroup = "fluid-recipes",
        order = "a[oil-processing]-b[advanced-oil-processing]3",
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-diesel",
    },
})

--TECHS
------------------------------------------------------------------------------------------------------
data:extend({
        {
        name = "ei-advanced-motor",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/advanced-motor.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-computer-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-motor"
            },
            --[[
            {
                type = "unlock-recipe",
                recipe = "ei-liquid-nitrogen-oil-processing"
            },            {
                type = "unlock-recipe",
                recipe = "ei-liquid-oxygen-heavy-oil-cracking"
            },            {
                type = "unlock-recipe",
                recipe = "ei-nitric-acid-medium-destilate-cracking"
            },
            ]]
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
        {
        name = "ei-oxygen-difluoride",
        type = "technology",
        icon = ei_graphics_tech_path.."oxygen-difluoride.png",
        icon_size = 128,
        prerequisites = {"ei-bio-chamber","ei-oxygen-gas"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-oxygen-difluoride"
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
        name = "ei-sus-plating",
        type = "technology",
        icon = ei_graphics_tech_path.."sus-plating.png",
        icon_size = 128,
        prerequisites = {"ei-bio-reactor"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-sus-plating"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-oxygen-difluoride-alien",
        type = "technology",
        icon = ei_graphics_tech_path.."oxygen-difluoride.png",
        icon_size = 128,
        prerequisites = {"ei-oxygen-difluoride", "ei-alien-computer-age-tech"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-oxygen-difluoride-alien"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    -- bio variantes for insulted-wire, energy-crystal, high-energy-crystal, nitric acid and hydrofluoric-acid
    {
        name = "ei-bio-insulated-wire",
        type = "technology",
        icon = ei_graphics_other_path.."bio_insulated-wire.png",
        icon_size = 64,
        prerequisites = {"ei-bio-reactor"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-insulated-wire"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-energy-crystal",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/other/bio-energy-crystal.png",
        icon_size = 64,
        prerequisites = {"ei-bio-reactor", "ei-grower"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-energy-crystal"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-high-energy-crystal",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/other/bio-high-energy-crystal.png",
        icon_size = 64,
        prerequisites = {"ei-bio-energy-crystal"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-high-energy-crystal"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-nitric-acid",
        type = "technology",
        icon = ei_graphics_other_path.."bio_nitric-acid.png",
        icon_size = 64,
        prerequisites = {"ei-bio-hydrofluoric-acid", "ei-nitric-acid"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-nitric-acid"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-hydrofluoric-acid",
        type = "technology",
        icon = ei_graphics_other_path.."bio_hydrofluoric-acid.png",
        icon_size = 64,
        prerequisites = {"ei-bio-reactor"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-hydrofluoric-acid"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-bio-electronic-parts",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/other/bio-electronic-parts.png",
        icon_size = 64,
        prerequisites = {"ei-bio-insulated-wire"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-electronic-parts"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-logistic-containers",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/logistic-containers.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-computer-core","ei-containers","logistic-robotics"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-red"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-red"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-red"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-yellow"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-yellow"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-yellow"
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
        name = "ei-advanced-logistic-containers",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/advanced-logistic-containers.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-logistic-containers","logistic-system"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-green"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-green"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-green"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-blue"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-blue"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-blue"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-pink"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-pink"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-pink"
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
        name = "ei-personal-leg",
        type = "technology",
        icon = ei_graphics_tech_path.."personal-leg.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"military-4", "automation-3", "ei-computer-core"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-leg"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-personal-laser",
        type = "technology",
        icon = ei_graphics_tech_path.."personal-laser.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"military-4", "ei-computer-core","personal-laser-defense-equipment"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-laser"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "computer-age",
    },
   {
        name = "ei-dirty-water-usage",
        type = "technology",
        icon = ei_graphics_tech_path.."morphium-usage.png", --used to be called dirty-water-usage.png ...
        icon_size = 128,
        prerequisites = {"ei-computer-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-iron-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-copper-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-lead-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-uranium-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-gold-extraction"
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
        name = "ei-morphium-usage",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/morphium-usage.png",
        icon_size = 128,
        icon_mipmaps = 3,
        prerequisites = {"ei-computer-age","ei-gaia"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-iron-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-copper-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lead-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-uranium-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-stone-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gold-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-sulfur-extraction"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-morphium-fluorite"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-slag-extraction-morphium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-undilute-morphium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-concentrated-morphium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-water"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age-space"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-morphium-usage-petro",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/morphium-usage.png",
        icon_size = 128,
        icon_mipmaps = 3,
        prerequisites = {"ei-alien-computer-age-tech","ei-morphium-usage"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-concentrated-morphium-light-oil"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-concentrated-morphium-kerosene"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-concentrated-morphium-heavy-oil"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-concentrated-morphium-lubricant"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-cryodust",
        type = "technology",
        icon = ei_graphics_tech_2_path.."cryodust.png",
        icon_size = 128,
        prerequisites = {"ei-alien-computer-age-tech"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cryodust"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cryocondensate"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-condensed-cryodust"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-coal"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-advanced-motor-cryodust",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/advanced-motor-cryo.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-cryodust","ei-advanced-motor"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-motor-cryo"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-advanced-steel",
        type = "technology",
        icon = ei_graphics_tech_path.."steel-processing.png",
        icon_size = 256,
        prerequisites = {"ei-computer-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-molten-steel-mix"
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
        name = "ei-oxygen-steel",
        type = "technology",
        icon = ei_graphics_tech_path.."oxygen-steel.png",
        icon_size = 256,
        
        prerequisites = {"ei-advanced-steel", "ei-oxygen-gas"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-molten-steel-oxygen"
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
        name = "ei-oxygen-sulfuric-acid",
        type = "technology",
        icon = data.raw.fluid["ei-oxygen-gas"].icon,
        icon_size = data.raw.fluid["ei-oxygen-gas"].icon_size,
        icons = {
            { icon = data.raw.fluid["ei-oxygen-gas"].icon,            scale = 0.2, shift = { 3, 4 } },
            { icon = "__base__/graphics/icons/fluid/sulfuric-acid.png", scale = 0.2, shift = { -3, -4 } },
        },
        prerequisites = {"sulfur-processing", "ei-oxygen-gas"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-oxygen-sulfuric-acid"
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
        name = "ei-lithium-battery",
        type = "technology",
        icon = ei_graphics_tech_path.."lithium-battery.png",
        icon_size = 256,
        prerequisites = {"processing-unit"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-battery-lithium"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-advanced-rocket-fuel",
        type = "technology",
        icon = ei_graphics_item_path.."advanced-rocket-fuel.png",
        icon_size = 64,
        prerequisites = {"ei-rocket-parts","ei-advanced-chem-plant","ei-oxygen-difluoride"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-rocket-fuel"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-parts-advanced"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-silicon",
        type = "technology",
        icon = ei_graphics_tech_path.."silicon.png",
        icon_size = 128,
        prerequisites = {"processing-unit"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-silicon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-monosilicon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-semiconductor-monosilicon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-semiconductor-monosilicon"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-dirty-water-production",
        type = "technology",
        icon = ei_graphics_tech_path.."dirty-water-production.png",
        icon_size = 128,
        prerequisites = {"ei-advanced-chem-plant", "ei-dirty-water-usage"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-stone"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-petroleum-reforming",
        type = "technology",
        icon = ei_graphics_tech_path.."petroleum-reforming.png",
        icon_size = 128,
        prerequisites = {"ei-advanced-chem-plant", "ei-ammonia"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-petroleum-reforming"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-oxygen-gas",
        type = "technology",
        icon = ei_graphics_tech_path.."oxygen-lufter.png",
        icon_size = 128,
        prerequisites = {"ei-cooler"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-oxygen-gas"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-liquid-oxygen"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-vaporize-liquid-ammonia"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-oxygen-gas-vent"
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
        name = "ei-rocket-parts",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/item/rocket-parts.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-rocket-control-unit", "low-density-structure", "rocketry"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-parts"
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
        name = "ei-high-energy-crystal",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/high-energy-crystal.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-computer-core"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-crystal-solution"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-high-energy-crystal"
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
        name = "ei-high-energy-crystal-growing",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/high-energy-crystal-growing.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-high-energy-crystal"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-high-energy-crystal-growing"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-cryo-container",
        type = "technology",
        icon = ei_graphics_tech_path.."cryo-container.png",
        icon_size = 128,
        prerequisites = {"ei-cooler"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-emtpy-cryo-container"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-fill-cryo-container-nitrogen"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-empty-cryo-container-nitrogen"
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
        name = "ei-oxygen-cryo-container",
        type = "technology",
        icon = ei_graphics_tech_path.."oxygen-cryo-container.png",
        icon_size = 128,
        prerequisites = {"ei-cryo-container", "ei-oxygen-gas"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-fill-cryo-container-oxygen"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-empty-cryo-container-oxygen"
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
        name = "ei-ammonia",
        type = "technology",
        icon = ei_graphics_tech_path.."ammonia.png",
        icon_size = 128,
        prerequisites = {"ei-cooler"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-ammonia"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-hydrogen"
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
        name = "ei-dinitrogen-tetroxide",
        type = "technology",
        icon = ei_graphics_tech_path.."dinitrogen-tetroxide.png",
        icon_size = 128,
        prerequisites = {"ei-ammonia", "ei-oxygen-gas"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-dinitrogen-tetroxide"
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
        name = "ei-advanced-computer-age-tech",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/simulation-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-big-lab", "ei-nitric-acid","processing-unit"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-computer-age-tech"
            },
        },
        unit = {
            count = 500,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-alien-computer-age-tech",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/alien-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-big-lab", "ei-oxygen-difluoride","ei-gaia"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-alien-computer-age-tech"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gaia-pump"
            },
        },
        unit = {
            count = 500,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-nitric-acid",
        type = "technology",
        icon = ei_graphics_tech_path.."nitric-acid.png",
        icon_size = 128,
        prerequisites = {"ei-dinitrogen-tetroxide"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-dinitrogen-tetroxide-water-solution"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-nitric-acid"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-slag-extraction-nitric"
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
        type = "technology",
        name = "ei-rocket-control-unit",
        icons = {{icon=ei_graphics_3_path.."graphics/item/rocket-processing-unit.png", tint={r=1.0, g=1.0, b=0.0}, icon_size = 512,icon_mipmaps = 5}},
        effects =
        {
          {
            type = "unlock-recipe",
            recipe = "ei-rocket-control-unit"
          },
        },
        prerequisites = {"ei-computer-age","low-density-structure"},
        unit =
        {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
        order = "k-a"
    },
    {
        type = "technology",
        name = "ei-rocket-processing-unit",
        icon = ei_graphics_3_path.."graphics/item/rocket-processing-unit.png",
        icon_size = 512,
        icon_mipmaps = 5,
        effects =
        {
            {
                type = "unlock-recipe",
                recipe = "ei-rocket-processing-unit"
            }
        },
        prerequisites = {"ei-rocket-control-unit","processing-unit","ei-advanced-computer-age-tech"},
        unit =
        {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
        order = "k-a"
    },
--carbon fiber plate casting pre-quantum age
    {
        name = "ei-carbon-manipulation",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/carbon-manipulation.png",
        icon_size = 256,
        prerequisites = {"space-platform","ei-high-energy-crystal-growing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-coke"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-fusion"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-fusion-high-energy"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-symbiote-casting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-carbon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-reheat"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-carbon-symbiote-reheat"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age"
    },
    {
        name = "ei-advanced-semiconductor",
        type = "technology",
        icon = ei_graphics_item_path.."advanced-waver.png",
        icon_size = 128,
        prerequisites = {"ei-computer-core","ei-waver-factory","ei-nitric-acid"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-base-semiconductor"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-semiconductor"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crush-faulty-advanced-semiconductor"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age"
    },
    {
        name = "ei-computing-unit",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/item/computing-unit.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-copper-beacon","ei-advanced-deep-drill","ei-advanced-centrifuge","ei-advanced-refinery","ei-sus-plating","ei-cryodust"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-computing-unit"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["both-computer-age"],
            time = 20
        },
        age = "both-computer-age"
    },
  {
    type = "recipe",
    name = "ei-thruster-oxidizer",
    category = "chemistry",
    subgroup="space-processing",
    order = "c[thruster-oxidizer]2",
    auto_recycle = false,
    enabled = false,
    ingredients =
    {
      {type = "item", name = "ei-poor-iron-chunk", amount = 6},
      {type = "fluid", name = "water", amount = 10}
    },
    surface_conditions =
    {
      {
        property = "gravity",
        min = 0,
        max = 0
      }
    },
    energy_required = 2.5,
    results = {{type = "fluid", name = "thruster-oxidizer", amount = 75}},
    allow_productivity = true,
    show_amount_in_title = false,
    always_show_products = true,
    crafting_machine_tint =
    {
      primary = {r = 0.082, g = 0.396, b = 0.792, a = 0.502}, -- #1565ca80
      secondary = {r = 0.161, g = 0.553, b = 0.796, a = 0.502}, -- #298dcb80
      tertiary = {r = 0.059, g = 0.376, b = 0.545, a = 0.502}, -- #0f5f8a80
      quaternary = {r = 0.683, g = 0.915, b = 1.000, a = 0.502}, -- #aee9ff80
    }
  },
  {
    type = "recipe",
    name = "ei-advanced-thruster-oxidizer",
    icon = "__space-age__/graphics/icons/advanced-thruster-oxidizer.png",
    category = "chemistry",
    subgroup = "space-processing",
    order = "d[advanced-thruster-oxydizer]2",
    auto_recycle = false,
    enabled = false,
    ingredients =
    {
      {type = "item", name = "ei-poor-iron-chunk", amount = 6},
      {type = "item", name = "calcite", amount = 1},
      {type = "fluid", name = "water", amount = 100}
    },
    surface_conditions =
    {
      {
        property = "gravity",
        min = 0,
        max = 0
      }
    },
    energy_required = 12.5,
    results =
    {
      {type = "fluid", name = "thruster-oxidizer", amount = 1500},
    },
    allow_productivity = true,
    always_show_products = true,
    show_amount_in_title = false,
    allow_decomposition = false,
    crafting_machine_tint =
    {
      primary = {r = 0.082, g = 0.396, b = 0.792, a = 0.502}, -- #1565ca80
      secondary = {r = 0.161, g = 0.553, b = 0.796, a = 0.502}, -- #298dcb80
      tertiary = {r = 0.059, g = 0.376, b = 0.545, a = 0.502}, -- #0f5f8a80
      quaternary = {r = 0.683, g = 0.915, b = 1.000, a = 0.502}, -- #aee9ff80
    }
  },
})

ei_lib.raw.technology.modules.effects = {
    {
        type = "unlock-recipe",
        recipe = "ei-module-base"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-module-part"
    }
}

table.insert(data.raw["technology"]["military-4"].effects, {
    type = "unlock-recipe",
    recipe = "ei-compound-ammo"
})
--steam all the way in space :v Sassxolotl
table.insert(data.raw["technology"]["space-platform"].effects, {type = "unlock-recipe", recipe = "ei-space-steam-1"})
table.insert(data.raw["technology"]["space-platform-thruster"].effects, {type = "unlock-recipe", recipe = "ei-space-steam-2"})
table.insert(data.raw["technology"]["space-platform-thruster"].effects, {type = "unlock-recipe", recipe = "ei-thruster-oxidizer"})
table.insert(data.raw["technology"]["advanced-asteroid-processing"].effects, {type = "unlock-recipe", recipe = "ei-advanced-thruster-oxidizer"})
