local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--OTHER
------------------------------------------------------------------------------------------------------

--increase assembling machine energy usage and pollution
local a1 = ei_lib.raw["assembling-machine"]["assembling-machine-1"]
local a2 = ei_lib.raw["assembling-machine"]["assembling-machine-2"]
local a3 = ei_lib.raw["assembling-machine"]["assembling-machine-3"]
if a1 then 
    a1.energy_usage = "232.5kW" --def 77.5
    a1.energy_source.emissions_per_minute.pollution = 5 --def 4
end
if a2 then
    a2.energy_usage = "465kW" --def 155
    a2.energy_source.emissions_per_minute.pollution = 4 --def 3
end
if a3 then
    a3.energy_usage = "1164kW" --def 388
    a3.energy_source.emissions_per_minute.pollution = 4 --def 2
end

local offshore_pumps = ei_lib.raw["offshore-pump"]
local offshore_pump = offshore_pumps and offshore_pumps["offshore-pump"]
if offshore_pump then
    offshore_pump.energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
    }
    offshore_pump.energy_usage = "60kW"
    offshore_pump.pumping_speed = 20
    offshore_pump.collision_box = {{-0.32, -1.05}, {0.32, 0.05}}
end

-- set fluid burn values for crude, light, heavy - oil and petrol
ei_lib.raw["fluid"]["crude-oil"] = {
    fuel_value = "100kJ",
    fuel_emissions_multiplier = 1.25
}
ei_lib.raw["fluid"]["heavy-oil"] =  {
    fuel_value = "500kJ",
    fuel_emissions_multiplier = 1.1
}
ei_lib.raw["fluid"]["petroleum-gas"] = {
    fuel_value = "800kJ",
    fuel_emissions_multiplier = 0.7
}
ei_lib.raw["fluid"]["light-oil"] = {
    fuel_value = "1000kJ",
    fuel_emissions_multiplier = 0.8
}
local spider_smoke = table.deepcopy(ei_lib.raw["trivial-smoke"]["train-smoke"])
spider_smoke.name = "ei-spider-smoke"
spider_smoke.start_scale = 0.33
spider_smoke.end_scale = 4.2
spider_smoke.duration = 90
spider_smoke.fade_away_duration = 90
spider_smoke.color = {r = 0.24, g = 0.24, b = 0.24, a = 0.333}
data:extend({spider_smoke})
--Darker, longer duration, longer fadeout, smaller start_Scale, larger end_scale
--similar to actual diesel which makes a lingering plume
ei_lib.raw["trivial-smoke"]["train-smoke"] = {
    color = {r = 0.22, g = 0.22, b = 0.22, a = 0.42},
    duration = 300,
    spread_duration = 450,
    fade_away_duration = 300,
    start_scale = 0.33,
    end_scale = 2.5,
}

-- make locomotive use diesel
-- add burnt fuel slot
local locomotive_energy_source = {
    emissions_per_minute = { pollution = 2.5 },
    fuel_inventory_size = 3,
    burnt_inventory_size = 3,
    smoke = {
        {
            name = "train-smoke",
            deviation = {0.45, 0.45},
            frequency = 175,
            position = {0, 0},
            starting_frame = 0,
            starting_frame_deviation = 60,
            height = 2,
            height_deviation = 0.5,
            starting_vertical_speed = 0.08,
            starting_vertical_speed_deviation = 0.1
        }
  },
}

if not mods["Krastorio2-spaced-out"] then
    locomotive_energy_source.fuel_categories = {"ei-diesel-fuel"}
end

ei_lib.raw.locomotive.locomotive = {
    localised_name = {"entity-name.ei-locomotive"},

    max_power = "800kW", --default 600

    weight = 2500,

    energy_source = locomotive_energy_source
}

if mods["Krastorio2-spaced-out"] then
    ei_lib.modify_data_raw("locomotive", "locomotive", {
        force_insert = true,
        energy_source = {
            fuel_categories = {"ei-diesel-fuel"},
        }
    })
end

-- let car and tank use alternative fuels
-- this is duplicated in teslas_legacy.lua to cover tesla mod vehicles
local t_extra_fuels = {
    "ei-rocket-fuel",
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-fusion-fuel",
    "ei-diesel-fuel"
}
local t = {
    "tank",
    "car"
}
for _,ent in pairs(t) do
    local target = data.raw.car[ent]
    if target and target.energy_source and target.energy_source.fuel_categories then
        for _,f in pairs(t_extra_fuels) do
            if not ei_lib.table_contains_value(target.energy_source.fuel_categories, f) then
                table.insert(target.energy_source.fuel_categories, f)
            end
        end 
    end
end
-- make oil-refinery heat based
data.raw["assembling-machine"]["oil-refinery"].energy_usage = "1.5MW"
data.raw["assembling-machine"]["oil-refinery"].energy_source = {
    type = 'heat',
    max_temperature = 275,
    min_working_temperature = 185,
    specific_heat = ei_data.specific_heat,
    max_transfer = '10MW',
    emissions_per_minute = {pollution=15},
    connections = {
        {position = {-2.3, 0}, direction = defines.direction.west},
        {position = {-2.3, 1}, direction = defines.direction.west},
        {position = {-2.3, -1}, direction = defines.direction.west},
        -- {position = {0,1.4}, direction = defines.direction.south},
        {position = {2.3, 0}, direction = defines.direction.east},
        {position = {2.3, 1}, direction = defines.direction.east},
        {position = {2.3, -1}, direction = defines.direction.east},
        -- {position = {-1.5,0}, direction = defines.direction.west}
    }
}

-- make burner inserter be able to fuel leech
ei_lib.raw["inserter"]["burner-inserter"].allow_burner_leech = true
-- change upgrade from inserter to steam inserter
ei_lib.raw["inserter"]["burner-inserter"].next_upgrade = "ei-steam-inserter"
-- make electric engine unit craft category be crafting
data.raw["recipe"]["electric-engine-unit"].category = "crafting"

-- make underground pipes longer, read from setting
ei_lib.raw["pipe-to-ground"]["pipe-to-ground"].fluid_box.pipe_connections = {
    {
        direction=defines.direction.north,
        position = {
            0,
            0
        }
    },
    {
        connection_type = "underground",
        max_underground_distance = ei_lib.config("pipe-to-ground-length"),
        direction=defines.direction.south,
        position = {
            0,
            0
        }
    }
}

-- add handcrafting crafting category to player
--table.insert(data.raw["character"]["character"].crafting_categories, "ei-handcrafting")
ei_lib.raw["character"]["character"] = {
    force_insert = true,
    crafting_categories = {"ei-handcrafting"}
}
-- swap vanilla hr and normal reactor sprites with ei ones
-- also swap reactor lights
ei_lib.raw["reactor"]["nuclear-reactor"].picture.layers[1].filename = ei_graphics_entity_path.."hr-reactor.png"
ei_lib.raw["reactor"]["nuclear-reactor"].working_light_picture.filename = ei_graphics_entity_path.."hr-reactor-lights-color.png"

-- add fluidbox to centrifuge
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes_off_when_no_fluid_recipe = true
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes = {
    {
        production_type = "input",
        pipe_picture = ei_pipe_centrifuge,
        pipe_covers = pipecoverspictures(),
        volume = 200,
        pipe_connections = {
            {flow_direction = "input", direction = defines.direction.east, position = {1, 0}}
        },
        secondary_draw_orders = {north = -1}
    },
    {
        production_type = "output",
        pipe_picture = ei_pipe_centrifuge,
        pipe_covers = pipecoverspictures(),
        volume = 200,
        pipe_connections = {
            {flow_direction = "output", direction = defines.direction.west, position = {-1, 0}}
        },
        secondary_draw_orders = {north = -1}
    }
}
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes_off_when_no_fluid_recipe = true

-- remove neighbour bonus from nuclear reactor and set fuel category to ei_nuclear_fuel
-- also set energy output to 100MW (setting)

ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",}
ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.effectivity = 1
if ei_lib.config("nuclear-reactor-remove-bonus") then
    ei_lib.raw["reactor"]["nuclear-reactor"].neighbour_bonus = 0
end
ei_lib.raw["reactor"]["nuclear-reactor"].consumption = ei_lib.config("nuclear-reactor-energy-output")


-- buff solar panel power output and set fast_replaceable_group/next_upgrade
--update solar_matrix.lua default prod value at bottom if changing this
--1.778 is area difference multiplier between vanilla 3x3 solar and matrix 4x4
ei_lib.raw["solar-panel"]["solar-panel"].production = (80*1.778).."kW"
ei_lib.raw["solar-panel"]["solar-panel"].fast_replaceable_group = "solar-panel"
ei_lib.raw["solar-panel"]["solar-panel"].next_upgrade = "ei-solar-panel-2"

-- buff accumulator capacity, max in and output
ei_lib.raw.accumulator.accumulator = {
    energy_source = {
        buffer_capacity = "6MJ",
        input_flow_limit = "425kW",
        output_flow_limit = "425kW",
    }
}

-- sort fission reactor into nuclear tab
ei_lib.raw["item"]["nuclear-reactor"].subgroup = "ei-nuclear-buildings"
ei_lib.raw["item"]["nuclear-reactor"].order = "b-a"

ei_lib.raw["mining-drill"]["big-mining-drill"].energy_usage = "2MW"
--adjust furnaces energy usage
local stf = ei_lib.raw["furnace"]["stone-furnace"] or ei_lib.raw["assembling-machine"]["stone-furnace"]
if stf then
    stf.energy_usage = "135kW"
end
local sf = ei_lib.raw["furnace"]["steel-furnace"] or ei_lib.raw["assembling-machine"]["steel-furnace"]
if sf then
    sf.energy_usage = "260kW"
end
local ef = ei_lib.raw["furnace"]["electric-furnace"] or ei_lib.raw["assembling-machine"]["electric-furnace"]
if ef then
    ef.energy_usage = "558kW"
    ef.energy_source.emissions_per_minute.pollution = 2
end
ei_lib.raw["storage-tank"]["storage-tank"].fluid_box.volume = 5000

local vcp = ei_lib.raw["assembling-machine"]["chemical-plant"]
if vcp then
    --electric chem plant uses same energy but is slower than heat chem plant 1 vs 1.5
    vcp.energy_usage = "1MW"
    -- set fast replaceable group for chem plant
    vcp.fast_replaceable_group = "chemical-plant"
    -- allow burning fuels for ash
    if vcp.crafting_categories then
        table.insert(vcp.crafting_categories,"ei-burning")
    end
end

--set heat exchanger icon size so add_item_level can add the tier icon
local hea_exc = ei_lib.raw.item["heat-exchanger"]
if hea_exc then
    hea_exc.icon_size = 64
end

-- make mining radius of burner mining drill 
ei_lib.raw["mining-drill"]["burner-mining-drill"].radius_visualisation_picture = ei_lib.raw["mining-drill"]["electric-mining-drill"].radius_visualisation_picture
ei_lib.raw["mining-drill"]["burner-mining-drill"].resource_searching_radius = 2
ei_lib.raw["mining-drill"]["electric-mining-drill"] = {
    resource_searching_radius = 4,
    fast_replaceable_group = "electric-mining-drill",
    next_upgrade = "ei-advanced-electric-mining-drill",
    energy_usage = "150kW"
}

-- turn spidertron into a burner vehicle
local spider_energy_source_exceptions = {
    ["ei-gaian-saucer"] = true,
}

for _, spider in pairs(data.raw["spider-vehicle"]) do
    if spider and not spider_energy_source_exceptions[spider.name] and spider.energy_source and spider.energy_source.type ~= "burner" then
        spider.energy_source =
    {
            type = "burner",
            fuel_categories = {"chemical", "ei-rocket-fuel","ei-nuclear-fuel","ei-nuclear-fuel-cell", "ei-fusion-fuel","ei-diesel-fuel"},
            effectivity = 1,
            fuel_inventory_size = 3,
            burnt_inventory_size = 3,
            emissions_per_minute = {
            pollution = 10
        },
        smoke = {
            {
            name = "ei-spider-smoke",
            deviation = {1.8, 1.8},
            frequency = 245,
            position = {0, 0},
            --position = {0, 0},
            starting_frame = 0,
            starting_frame_deviation = 60,
            height = 0.5,
            height_deviation = 1,
            starting_vertical_speed = 0.1,
            starting_vertical_speed_deviation = 0.5,
            }
        }
    }
        spider.movement_energy_consumption = "1.0MW"
    end
end

-- apply quality scaling bonuses to EI fuels
local buff_fuels = {
    "ei-rocket-fuel",
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-fusion-fuel"
}
for _,item in pairs(data.raw["item"]) do
    if item.fuel_category and ei_lib.table_contains_value(buff_fuels,item.fuel_category) then
        if not item.fuel_acceleration_multiplier_quality_bonus then
            item.fuel_acceleration_multiplier_quality_bonus = 0.495
        else
            item.fuel_acceleration_multiplier_quality_bonus = math.max(49.5,item.fuel_acceleration_multiplier_quality_bonus*1.1)
        end
        if not item.fuel_top_speed_multiplier_quality_bonus then 
            item.fuel_top_speed_multiplier_quality_bonus = 0.1
        else
            item.fuel_top_speed_multiplier_quality_bonus = math.max(0.1,item.fuel_top_speed_multiplier_quality_bonus*1.1)
        end
    end
end

-- improve movement speed bonus on stone-bricks, concrete and refined-concrete

data.raw["tile"]["stone-path"].walking_speed_modifier = 1.6
data.raw["tile"]["concrete"].walking_speed_modifier = 1.8
data.raw["tile"]["hazard-concrete-left"].walking_speed_modifier = 1.8
data.raw["tile"]["refined-concrete"].walking_speed_modifier = 2.2
data.raw["tile"]["refined-hazard-concrete-left"].walking_speed_modifier = 2.2

--prevent projectiles from colliding with friendly structures and allow collision with asteroids
local modify_collision_projectiles = {
    "cannon-projectile",
    "explosive-cannon-projectile",
    "explosive-uranium-cannon-projectile",
    "uranium-cannon-projectile",
    "shotgun-pellet",
    "piercing-shotgun-pellet",
    "ei-uranium-shotgun-pellet",
    "ei-dragons-breath-shotgun-pellet",
}
local collision_mask = {
    layers = {
        object = true,
        player = true,
        trigger_target = true,
        train = true
    },
    not_colliding_with_itself = true
}
for _,projectile in ipairs(modify_collision_projectiles) do
    data.raw["projectile"][projectile].force_condition = "not-same"
    data.raw["projectile"][projectile].hit_collision_mask = collision_mask

    -- add the force condition to the action delivery
    if data.raw["projectile"][projectile].action then
        if data.raw["projectile"][projectile].action.action_delivery then
            
            -- loop over all trigger items and if contains damage set force
            for _,triggeritem in ipairs(data.raw["projectile"][projectile].action.action_delivery.target_effects) do
                if triggeritem.type == "damage" then
                    triggeritem.force = "not-same"
                end
            end

        end
    end

    -- do the same for final_action
    if data.raw["projectile"][projectile].final_action then
        if data.raw["projectile"][projectile].final_action.action_delivery then
            
            -- loop over all trigger items and if contains damage set force
            for _,triggeritem in ipairs(data.raw["projectile"][projectile].final_action.action_delivery.target_effects) do
                if triggeritem.type == "damage" then
                    triggeritem.force = "not-same"
                end

                if triggeritem.type == "nested-result" then
                    for _,nestedtriggeritem in ipairs(triggeritem.action.action_delivery.target_effects) do
                        if nestedtriggeritem.type == "damage" then
                            nestedtriggeritem.force = "not-same"
                        end
                    end
                end

            end

        end
    end
end
local fa_mag = ei_lib.raw["ammo"]["firearm-magazine"]
--fa_mag.magazine_size = 12
-- improve damage per bullet of firearm-magazine and piercing-rounds-magazine
fa_mag.ammo_type =     {
    action =
    {
    {
        type = "direct",
        action_delivery =
        {
        {
            type = "instant",
            source_effects =
            {
            {
                type = "create-explosion",
                entity_name = "explosion-gunshot",
                only_when_visible = true
            }
            },
            target_effects =
            {
            {
                type = "create-entity",
                entity_name = "explosion-hit",
                offsets = {{0, 1}},
                offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
                only_when_visible = true
            },
            {
                type = "damage",
                damage = {amount = 8, type = "physical"}
            },
            {
                type = "activate-impact",
                deliver_category = "bullet"
            }
            }
        }
        }
    }
    }
}

local pr_mag = ei_lib.raw["ammo"]["piercing-rounds-magazine"]
--pr_mag.magazine_size = 12
pr_mag.ammo_type =     {
    action =
    {
    type = "direct",
    action_delivery =
    {
        type = "instant",
        source_effects =
        {
        type = "create-explosion",
        entity_name = "explosion-gunshot",
        only_when_visible = true
        },
        target_effects =
        {
        {
            type = "create-entity",
            entity_name = "explosion-hit",
            offsets = {{0, 1}},
            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
            only_when_visible = true
        },
        {
            type = "damage",
            damage = {amount = 13, type = "physical"}
        },
        {
            type = "activate-impact",
            deliver_category = "bullet"
        }
        }
    }
    }
}
--[[
local ur_mag = ei_lib.raw["ammo"]["uranium-rounds-magazine"]
ur_mag.magazine_size = 12

local shot_shells = ei_lib.raw["ammo"]["shotgun-shell"]
shot_shells.magazine_size = 12

local pr_shot_shells = ei_lib.raw["ammo"]["piercing-shotgun-shell"]
pr_shot_shells.magazine_size = 12
]]
-- increase radar energy usage
ei_lib.raw.radar.radar.energy_usage = "1.2MW" --default 300kW

-- increase power output of fission reactor equipment

local fission_reactor_burner = {
    type = "burner",
    effectivity = 1.0,
    fuel_inventory_size = 9,
    burnt_inventory_size = 9,
}

if not mods["Krastorio2-spaced-out"] then
    fission_reactor_burner.fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",}
end

ei_lib.raw["generator-equipment"]["fission-reactor-equipment"] = {
    power = "1MW",
    burner = fission_reactor_burner
}

if mods["Krastorio2-spaced-out"] then
    ei_lib.modify_data_raw("generator-equipment", "fission-reactor-equipment", {
        force_insert = true,
        burner = {
            fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",},
        }
    })
end

ei_lib.raw["generator-equipment"]["fission-reactor-equipment"].energy_source.usage_priority = "secondary-output"
ei_lib.raw["item"]["fission-reactor-equipment"].order = "a[energy-source]-g[fission-reactor-equipment]"
ei_lib.recipe_remove("fusion-reactor-equipment", "fusion-power-cell")
local fusion_reactor_equipment = data.raw["generator-equipment"]["fusion-reactor-equipment"]
if fusion_reactor_equipment then
    fusion_reactor_equipment.power = "12MW"
    fusion_reactor_equipment.burner = {
        type = "burner",
        effectivity = 1.0,
        fuel_categories = {"fusion"},
        fuel_inventory_size = 3,
        burnt_inventory_size = 1,
    }
    fusion_reactor_equipment.energy_source.usage_priority = "secondary-output"
end

-- sort uranium 235/238 in the nuclear tab
ei_lib.raw["item"]["uranium-235"].subgroup = "ei-nuclear-processing"
ei_lib.raw["item"]["uranium-235"].order = "a-a-a"

ei_lib.raw["item"]["uranium-238"].subgroup = "ei-nuclear-processing"
ei_lib.raw["item"]["uranium-238"].order = "a-a-b"

-- let vanilla modules use new textures (prod, speed and effectivity modules)
ei_lib.raw.module["productivity-module"].icon = ei_graphics_item_path .. "productivity-module.png"
ei_lib.raw.module["productivity-module-2"].icon = ei_graphics_item_path .. "productivity-module-2.png"
ei_lib.raw.module["productivity-module-3"].icon = ei_graphics_item_path .. "productivity-module-3.png"

ei_lib.raw.module["speed-module"].icon = ei_graphics_item_path .. "speed-module.png"
ei_lib.raw.module["speed-module-2"].icon = ei_graphics_item_path .. "speed-module-2.png"
ei_lib.raw.module["speed-module-3"].icon = ei_graphics_item_path .. "speed-module-3.png"

ei_lib.raw.module["efficiency-module"].icon = ei_graphics_item_path .. "effectivity-module.png"
ei_lib.raw.module["efficiency-module-2"].icon = ei_graphics_item_path .. "effectivity-module-2.png"
ei_lib.raw.module["efficiency-module-3"].icon = ei_graphics_item_path .. "effectivity-module-3.png"

-- modify quality modules
ei_lib.raw.module["quality-module"].effect = {
    productivity = -0.25,
    consumption = 1,
    speed = -0.3,
    quality=0.3
}
ei_lib.raw.module["quality-module-2"].effect = {
    productivity = -0.50,
    consumption = 2,
    speed = -0.6,
    quality=0.45
}
ei_lib.raw.module["quality-module-3"].effect = {
    productivity = -0.75,
    consumption = 3,
    speed = -0.9,
    quality=0.6
}

-- nerf vanilla modules a bit
ei_lib.raw.module["productivity-module"].effect = {
    productivity = 0.03,
    --consumption = 0.3,
    pollution = 0.05,
    speed = -0.05
}
ei_lib.raw.module["productivity-module-2"].effect = {
    productivity = 0.05,
    consumption = 0.2,
    pollution = 0.07,
    speed = -0.1
}
ei_lib.raw.module["productivity-module-3"].effect = {
    productivity = 0.07,
    consumption = 0.4,
    pollution = 0.15,
    speed = -0.2
}

ei_lib.raw.module["speed-module"].effect = {
    consumption = 0.40,
    speed = 0.3
}

ei_lib.raw.module["speed-module-2"].effect = {
    consumption = 0.60,
    speed = 0.4
}

ei_lib.raw.module["speed-module-3"].effect = {
    consumption = 0.80,
    speed = 0.5
}

-- clone vanilla prod module limitation to ei prod modules
data.raw.module["ei-productivity-module-4"].limitation = data.raw.module["productivity-module"].limitation
data.raw.module["ei-productivity-module-5"].limitation = data.raw.module["productivity-module"].limitation
data.raw.module["ei-productivity-module-6"].limitation = data.raw.module["productivity-module"].limitation
-- properly set logistics 3 age and prere 
ei_lib.raw.technology["logistics-3"].age = "advanced-computer-age"
ei_lib.set_prerequisites("logistics-3",{"ei-advanced-computer-age-tech","logistics-2","ei-carbon-manipulation"})
--plastic bar productivity
local pbp = ei_lib.raw.technology["plastic-bar-productivity"]
if pbp and pbp.effects then
    table.insert(pbp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-plastic-benzol",
        change = 0.1
    })
    table.insert(pbp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-plastic-crushed-coke",
        change = 0.1
    })
end

--processing unit productivity
local pup = ei_lib.raw.technology["processing-unit-productivity"]
if pup and pup.effects then
    table.insert(pup.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-processing-unit-circuit-board",
        change = 0.1
    })
end

--add t1 steel ingot casting to steel productivity

local spp = ei_lib.raw.technology["steel-plate-productivity"]
if spp and spp.effects then
    table.insert(spp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-cast-steel-ingot",
        change = 0.1
    })
end
--increase silo energy draw, enforce modules
ei_lib.raw["rocket-silo"]["rocket-silo"] = {
    module_slots = 6,
    rocket_parts_required = 100,
    energy_usage = "1MW",
    active_energy_usage = "7980kW",
    allowed_effects = {"speed", "consumption", "pollution"}
}

--adjust vanilla rocket part recipe
local rocket_part_recipe = ei_lib.raw["recipe"]["rocket-part"]
rocket_part_recipe.ingredients = {
	{type = "item", name = "ei-rocket-parts", amount = 1}
}
rocket_part_recipe.localised_name = {"recipe-name.ei-rocket-assembly"}
--adjust Rocket part name display
local rocket_part = ei_lib.raw["item"]["rocket-part"]
rocket_part.localised_name = {"item-name.ei-rocket-assembled"}

local rfp = ei_lib.raw.technology["rocket-fuel-productivity"]
if rfp and rfp.effects then
    table.insert(rfp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-bio-rocket-fuel",
        change = 0.1
    })
end

data.raw.technology["rocket-part-productivity"].effects = {
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-advanced",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-odd-plating",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-odd-plating-advanced",
        change = 0.1
    },
}

ei_lib.raw["recipe"]["heavy-oil-cracking"].localised_name = {"recipe-name.ei-heavy-oil-cracking"}


-- use mk2 armor sprite for bio armor
for _, animation in ipairs(data.raw["character"]["character"]["animations"]) do
    if animation.armors then
        for _, armor in ipairs(animation.armors) do
            if armor == "power-armor-mk2" then
                animation.armors[#animation.armors + 1] = "ei-bio-armor"
                break
            end
        end
    end
end
--Double roboport charge energy
ei_lib.raw.roboport.roboport.charging_energy = "1MW"
--x10 the constant roboport drain
ei_lib.raw.roboport.roboport.energy_usage = "500kW"

--bring in line with ei-containers
ei_lib.raw["container"]["wooden-chest"].inventory_size = 8
ei_lib.raw["container"]["iron-chest"].inventory_size = 12
ei_lib.raw["container"]["steel-chest"].inventory_size = 16

ei_lib.patch_nested_value(
  data.raw["electric-turret"]["laser-turret"],
  "attack_parameters.ammo_type.action.action_delivery[1].max_length",
  30
)

--Modify laser turrets for extended range and lowered damage
ei_lib.raw["electric-turret"]["laser-turret"] = {
    attack_parameters = {
        range = 30,
        damage_modifier = 1.2,
    }
}

--adjusting speed of sound changes pitch
ei_lib.patch_nested_value(
  data.raw["beam"]["laser-beam"],
  "working_sound.sound.speed",
  0.9
)

--Note: Add individual stream types to provide visual differentiation for different fluids
ei_lib.raw["fluid-turret"]["flamethrower-turret"] = {
    attack_parameters = {
        prepare_range = 40,
        fluid_consumption = 1, --default 0.2
        lead_target_for_projectile_speed = 0.45,
        range = 38, --default 0.225
        min_range = 9, --default 6
        turn_range = ei_lib.raw["fluid-turret"]["flamethrower-turret"].attack_parameters.turn_range * 0.8,
        fluids = {
            {type = "ei-heavy-destilate", damage_modifier = 0.4, damage_override_animation_modifier = 0.4},
            {type = "ei-medium-destilate", damage_modifier = 0.5, damage_override_animation_modifier = 0.5},
            {type = "ei-residual-oil", damage_modifier = 0.65, damage_override_animation_modifier = 0.65},
            {type = "ei-bio-oil", damage_modifier = 0.8, damage_override_animation_modifier = 0.8},
            {type = "crude-oil"},
            {type = "heavy-oil", damage_modifier = 1.15, damage_override_animation_modifier = 1.15},
            {type = "light-oil", damage_modifier = 1.25, damage_override_animation_modifier = 1.25},
            {type = "petroleum-gas", damage_modifier = 1.35, damage_override_animation_modifier = 1.35},
            {type = "ei-kerosene", damage_modifier = 1.45, damage_override_animation_modifier = 1.45}
        },
    }
    
}
local flame_stream = ei_lib.raw["stream"]["flamethrower-fire-stream"]
ei_lib.raw.stream["flamethrower-fire-stream"] = {
    particle_verticle_acceleration = flame_stream.particle_vertical_acceleration * 1.5,
    particle_horizontal_speed = flame_stream.particle_horizontal_speed * 1.5,
    particle_horizontal_speed_deviation = flame_stream.particle_horizontal_speed_deviation * 1.5
}
--allow space crusher to do ground based crusher recipes
local space_crusher = ei_lib.raw["assembling-machine"]["crusher"]
if space_crusher and space_crusher.crafting_categories then
    table.insert(space_crusher.crafting_categories,"ei-crushing")
end
