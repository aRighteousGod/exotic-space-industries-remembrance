-- vanilla patches like changed entities/prototypes are made here

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--GENERIC CHANGES
--====================================================================================================

-- since there is no iron gear used in EI use iron-mechanical parts instead
for i,v in pairs(data.raw["recipe"]) do
    ei_lib.recipe_swap(i, "iron-gear-wheel", "ei-iron-mechanical-parts")
    ei_lib.recipe_swap(i, "iron-stick", "ei-copper-mechanical-parts")
end

--====================================================================================================
--CHANGES
--====================================================================================================

--MINING
------------------------------------------------------------------------------------------------------

-- set furnace result inv to 2, when they have the smelting crafting category
for i,v in pairs(data.raw["furnace"]) do
    if v.crafting_categories[1] == "smelting" then
        ei_lib.raw["furnace"][i].result_inventory_size = 2
    end
end

--RECIPES
------------------------------------------------------------------------------------------------------

ei_lib.raw["recipe"]["burner-mining-drill"].ingredients = {
    {type="item", name="iron-plate", amount=3},
    {type="item", name="ei-iron-mechanical-parts", amount=3},
    {type="item", name="stone-furnace", amount=1}
}

ei_lib.raw["recipe"]["pipe"].ingredients = {
    {type="item", name="iron-plate", amount=1},
}

ei_lib.raw["recipe"]["basic-oil-processing"].ingredients =
{
    {type="fluid", name="crude-oil", amount=50},
    {type="fluid", name="water", amount=20},
}

ei_lib.raw["recipe"]["basic-oil-processing"].results = 
{
    {type="fluid", name="ei-residual-oil", amount=50},
    {type="fluid", name="petroleum-gas", amount=50},
}

ei_lib.raw["recipe"]["sulfuric-acid"].ingredients = {
    {type="fluid", name="water", amount=30},
    {type="item", name="sulfur", amount=3}
}

-- treat cracking
ei_lib.raw["recipe"]["heavy-oil-cracking"].icon = ei_graphics_other_path.."heavy-cracking.png"
ei_lib.raw["recipe"]["heavy-oil-cracking"].icon_size = 64
ei_lib.raw["recipe"]["heavy-oil-cracking"].results = {
    {type="fluid", name="ei-kerosene", amount=40},
}
ei_lib.recipe_new("heavy-oil-cracking",
{
    {type="fluid", name="heavy-oil", amount=50},
    {type="fluid", name="water", amount=50}
})

-- make engine recipe in recipe-category crafting
ei_lib.raw["recipe"]["engine-unit"].category = "crafting"

-- reduce craft time of engines and electric engines
ei_lib.raw["recipe"]["engine-unit"].energy_required = 4
ei_lib.raw["recipe"]["electric-engine-unit"].energy_required = 6

--TECHS
------------------------------------------------------------------------------------------------------
ei_lib.raw["technology"]["flamethrower"].age = "steam-age" --need investigate why the pre-req table doesn't always stick
ei_lib.raw["technology"]["concrete"].age = "steam-age"
ei_lib.set_prerequisites("concrete", {"advanced-material-processing"})
ei_lib.remove_unlock_recipe("concrete","iron-stick")
local new_prerequisites_table = {}

-- first index is tech second is prerequisite
new_prerequisites_table["steam-age"] = {
    {"flammables", "ei-steam-oil-processing"},
    {"automated-rail-transportation", "ei-steam-basic-train"},
    {"rail-signals", "ei-steam-basic-train"},
    {"braking-force-1", "ei-steam-basic-train"},
    {"steel-processing", "ei-steam-crusher"},
    {"engine", "ei-steam-oil-processing"},
    {"electronics", "ei-glass"},
    {"flamethrower","flammables"},
    {"concrete","advanced-material-processing"}
}

new_prerequisites_table["electricity-age"] = {
    {"automation", "ei-electricity-power"},
    {"fast-inserter", "ei-electricity-power"},
    {"circuit-network", "ei-electricity-power"},
    {"lamp", "ei-electricity-power"},
    {"robotics", "ei-grower"},
    {"lubricant", "ei-destill-tower"},
    {"sulfur-processing", "ei-destill-tower"},
    {"coal-liquefaction", "ei-benzol"},
    {"advanced-oil-processing", "ei-destill-tower"},
    {"laser", "ei-grower"},
    {"power-armor", "ei-grower"},
    {"solar-energy", "ei-waver-factory"},
    {"advanced-material-processing-2", "ei-electricity-power"},
    {"uranium-processing", "ei-deep-mining"},
    {"uranium-processing", "advanced-circuit"},
    {"uranium-processing", "ei-grower"},
    {"nuclear-power", "uranium-processing"},    
}

new_prerequisites_table["computer-age"] = {
    {"speed-module-2", "ei-computer-core"},
    {"productivity-module-2", "ei-computer-core"},
    {"efficiency-module-2", "ei-computer-core"},
    {"rocket-silo", "ei-computer-age"},
    {"low-density-structure", "ei-advanced-steel"},
    {"ei-rocket-parts", "rocket-fuel"},
    {"rocket-silo", "ei-rocket-parts"},
    {"fission-reactor-equipment", "ei-high-temperature-reactor"},
    
}

new_prerequisites_table["quantum-age"] = {

}

numbered_buffs = {
    "stronger-explosives-7",
    "mining-productivity-4",
    "research-speed-6",
    "worker-robots-speed-6",
    "worker-robots-storage-3",
    "laser-weapons-damage-7",
    "physical-projectile-damage-7",
    "refined-flammables-7",
    "inserter-capacity-bonus-7",
    "braking-force-7",
    "laser-shooting-speed-7",
    "weapon-shooting-speed-6",
    "follower-robot-count-5"
}

local prereqs_to_remove = {}

function make_numbered_buff_prerequisite(tech)

    -- get last char of tech name as number
    local tech_number = tonumber(string.sub(tech, -1))

    if tech_number == 1 then
        return 
    end

    -- get previous tech name by removing last char
    local pre = tonumber(tech_number - 1)
    local previous_tech = string.sub(tech, 1, -2)..tostring(pre)

    if not data.raw["technology"][previous_tech] then
        return
    end

    -- add previous tech to prerequisites, if it not already is there
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].prerequisites then
        if not ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, previous_tech) then
          table.insert(data.raw["technology"][tech].prerequisites, previous_tech)
        end
      end
    end

    -- remove the age tech prerequisite if the previous tech and this tech share the same age
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].age and data.raw["technology"][previous_tech].age then

          if data.raw["technology"][tech].age == data.raw["technology"][previous_tech].age then

              -- check if this tech has the age tech as prerequisite
              local age_tech = ei_data.tech_ages_with_sub_reverse[data.raw["technology"][tech].age]

              if ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, age_tech) then
                  table.insert(prereqs_to_remove, {tech, age_tech})
              end

              -- also check if the main age tech is in the previous techs prerequisites
              if ei_data.sub_age[data.raw["technology"][tech].age] then

                  local main_age_tech = ei_data.tech_ages_with_sub_reverse[ei_data.sub_age[data.raw["technology"][tech].age]]

                  if ei_lib.table_contains_value(data.raw["technology"][previous_tech].prerequisites, main_age_tech) then
                      table.insert(prereqs_to_remove, {previous_tech, main_age_tech})
                  end

              end

          end

      end
    end

    make_numbered_buff_prerequisite(previous_tech)

end
--Nerf the beacon to promote the EI specific varieties
ei_lib.raw.beacon["beacon"] = {
    distribution_effectivity = 0.125,
    distribution_effectivity_bonus_per_quality_level = 0.125,
    module_slots = 1,
    energy_usage = "900kW",
    supply_area_distance = 2
}
ei_lib.raw.technology["steel-processing"].icon = ei_graphics_tech_path.."steel-processing.png"
ei_lib.raw.technology["fluid-handling"] = {
    icon = ei_graphics_tech_path.."barreling.png",
    icon_size = 256,
}

ei_lib.add_unlock_recipe("fluid-wagon","pump")

ei_lib.add_unlock_recipe("automation-2", "ei-ceramic")

ei_lib.add_unlock_recipe("landfill", "ei-landfill-sand")


ei_lib.raw.technology.electronics.effects = {
    {
        type = "unlock-recipe",
        recipe = "electronic-circuit"
    },
    {
        type = "unlock-recipe",
        recipe = "copper-cable"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-ceramic-steam-assembler"
    },
}


-- edit electric enigne tech to use only steam age science for progression
--ei_lib.set_age_packs("electric-engine","steam-age")

-- make inserter-capaity-bonus-1 buff normal inserters
ei_lib.raw.technology["inserter-capacity-bonus-1"].effects = {
    {
        type = "inserter-stack-size-bonus",
        modifier = 1
    }
}

--FUEL CATEGORIES
------------------------------------------------------------------------------------------------------

ei_lib.raw.item["rocket-fuel"] = {
    fuel_categories = {"ei-rocket-fuel"},
    force_insert = true
}
ei_lib.raw.item["nuclear-fuel"] = {
    fuel_categories = {"ei-rocket-fuel"},
    force_insert = true
}

--ITEM SUBGROUPS
------------------------------------------------------------------------------------------------------

-- move iron and copper plates to plates subgroup
ei_lib.raw["item"]["iron-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["iron-plate"].order = "a1"
ei_lib.raw["item"]["copper-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["copper-plate"].order = "a2"

-- set train, cargo wagon, fluid wagon and artillery wagon to new ei_trains subgroup
ei_lib.raw["item-with-entity-data"]["locomotive"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["locomotive"].order = "c1"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].order = "c2"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].order = "c3"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].order = "c4"

ei_lib.raw["item"]["steel-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["steel-plate"].order = "a3"

ei_lib.raw["item"]["lab"].subgroup = "ei-labs"
ei_lib.raw["item"]["lab"].order = "a2"

ei_lib.raw["fluid"]["lubricant"].order = "a[fluid]-d[lubricant]"

--OTHER
------------------------------------------------------------------------------------------------------

-- set fluid burn values for crude, light, heavy - oil and petrol
ei_lib.raw["fluid"]["crude-oil"].fuel_value = "50kJ"
ei_lib.raw["fluid"]["heavy-oil"].fuel_value = "250kJ"
ei_lib.raw["fluid"]["petroleum-gas"].fuel_value = "400kJ"
ei_lib.raw["fluid"]["light-oil"].fuel_value = "500kJ"

-- make locomotive use diesel and rocket fuel
-- add burnt fuel slot
ei_lib.raw.locomotive.locomotive = {
    localised_name = {"entity-name.ei-locomotive"},
    energy_source = {
        emissions_per_minute = { pollution = 1.75 },
        fuel_categories = {"ei-diesel-fuel", "ei-rocket-fuel"},
        burnt_inventory_size = 1,
    }
}

-- make oil-refinery heat based
data.raw["assembling-machine"]["oil-refinery"].energy_source = {
    type = 'heat',
    max_temperature = 275,
    min_working_temperature = 185,
    specific_heat = ei_data.specific_heat,
    max_transfer = '10MW',
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

-- make electric engine unit craft category be crafting
-- data.raw["recipe"]["electric-engine-unit"].category = "crafting"

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

ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.fuel_categories = {"ei-nuclear-fuel"}
ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.effectivity = 2
if ei_lib.config("nuclear-reactor-remove-bonus") then
    ei_lib.raw["reactor"]["nuclear-reactor"].neighbour_bonus = 0
end
ei_lib.raw["reactor"]["nuclear-reactor"].consumption = ei_lib.config("nuclear-reactor-energy-output")

-- buff solar panel power output and set fast_replaceable_group/next_upgrade
ei_lib.raw["solar-panel"]["solar-panel"].production = "100kW"
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

-- set fast replaceable group for chem plant
data.raw["assembling-machine"]["chemical-plant"].fast_replaceable_group = "chemical-plant"

-- make mining radius of burner mining drill 
ei_lib.raw["mining-drill"]["burner-mining-drill"].radius_visualisation_picture = ei_lib.raw["mining-drill"]["electric-mining-drill"].radius_visualisation_picture
ei_lib.raw["mining-drill"]["burner-mining-drill"].resource_searching_radius = 2
ei_lib.raw["mining-drill"]["electric-mining-drill"] = {
    resource_searching_radius = 4,
    fast_replaceable_group = "electric-mining-drill",
    next_upgrade = "ei-advanced-electric-mining-drill",
    energy_usage = "150kW"
}

-- increase power output of fusion reactor equipment

ei_lib.raw["generator-equipment"]["fission-reactor-equipment"] = {
    power = "1MW",
    burner = {
        type = "burner",
        fuel_categories = {"ei-nuclear-fuel"},
        effectivity = 1.0,
        fuel_inventory_size = 9,
        burnt_inventory_size = 9,
    }
}
ei_lib.raw["generator-equipment"]["fission-reactor-equipment"].energy_source.usage_priority = "secondary-output"
ei_lib.raw["item"]["fission-reactor-equipment"].order = "a[energy-source]-g[fission-reactor-equipment]"

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
    consumption = 0.1,
    speed = 0.3
}

ei_lib.raw.module["speed-module-2"].effect = {
    consumption = 0.2,
    speed = 0.4
}

ei_lib.raw.module["speed-module-3"].effect = {
    consumption = 0.3,
    speed = 0.5
}


-- add 2 more module slots to rocket silo
ei_lib.raw["rocket-silo"]["rocket-silo"].module_slots = 4

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

--bring in line with ei-containers
ei_lib.raw["container"]["wooden-chest"].inventory_size = 8
ei_lib.raw["container"]["iron-chest"].inventory_size = 12
ei_lib.raw["container"]["steel-chest"].inventory_size = 16

--Modify laser turrets for extended range and lowered damage
ei_lib.raw["electric-turret"]["laser-turret"] = {
    attack_parameters = {
        range = 30,
        damage_modifier = -1.2,
    }
}

ei_lib.patch_nested_value(
  data.raw["electric-turret"]["laser-turret"],
  "attack_parameters.ammo_type.action.action_delivery[1].max_length",
  30
)


--Note: Add individual stream types to provide visual differentiation for different fluids
ei_lib.raw["fluid-turret"]["flamethrower-turret"] = {
    attack_parameters = {
        fluid_consumption = 1, --default 0.2
        lead_target_for_projectile_speed = 0.45,
        range = 36, --default 0.225
        min_range = 9, --default 6
        turn_range = ei_lib.raw["fluid-turret"]["flamethrower-turret"].attack_parameters.turn_range * 0.8,
        fluids = {
            {type = "ei-heavy-destilate", damage_modifier = 0.4, damage_override_animation_modifier = 0.4},
            {type = "ei-medium-destilate", damage_modifier = 0.5, damage_override_animation_modifier = 0.5},
            {type = "ei-residual-oil", damage_modifier = 0.65, damage_override_animation_modifier = 0.65},
            {type = "crude-oil"},
            {type = "heavy-oil", damage_modifier = 1.15, damage_override_animation_modifier = 1.15},
            {type = "light-oil", damage_modifier = 1.25, damage_override_animation_modifier = 1.25},
            {type = "petroleum-gas", damage_modifier = 1.35, damage_override_animation_modifier = 1.35},
            {type = "ei-kerosene", damage_modifier = 1.45, damage_override_animation_modifier = 1.45}
        },
    }
    
}
ei_lib.raw.stream["flamethrower-fire-stream"] = {
    particle_verticle_acceleration = ei_lib.raw.stream["flamethrower-fire-stream"].particle_vertical_acceleration * 1.5,
    particle_horizontal_speed = ei_lib.raw.stream["flamethrower-fire-stream"].particle_horizontal_speed * 1.5,
    particle_horizontal_speed_deviation = ei_lib.raw.stream["flamethrower-fire-stream"].particle_horizontal_speed_deviation * 1.5
}
local flame_stream = ei_lib.raw["stream"]["flamethrower-fire-stream"]

-- set next upgrade of turbo belt, splitter and underground to ei_neo-belt
ei_lib.raw["transport-belt"]["turbo-transport-belt"].next_upgrade = "ei-neo-belt"
ei_lib.raw["splitter"]["turbo-splitter"].next_upgrade = "ei-neo-splitter"
ei_lib.raw["underground-belt"]["turbo-underground-belt"].next_upgrade = "ei-neo-underground-belt"

-- set localised descriptions
ei_lib.raw["item"]["burner-inserter"].localised_description = {"item-description.ei_burner-inserter"}
ei_lib.raw["item"]["oil-refinery"].localised_description = {"item-description.ei_oil-refinery"}

--====================================================================================================
--FUNCTION STUFF
--====================================================================================================

-- loop over new_prerequisites_table and add new prerequisites for indexed technologies
-- if so remove the age tech as prerequisiter
for age,table_in in pairs(new_prerequisites_table) do
    for i,v in pairs(table_in) do
        ei_lib.add_prerequisite(v[1], v[2])
        ei_lib.remove_prerequisite(v[1], "ei-"..age)
    end
end

for _, tech in ipairs(numbered_buffs) do
    make_numbered_buff_prerequisite(tech)
end

for i,v in ipairs(prereqs_to_remove) do
    ei_lib.remove_prerequisite(v[1], v[2])
end
