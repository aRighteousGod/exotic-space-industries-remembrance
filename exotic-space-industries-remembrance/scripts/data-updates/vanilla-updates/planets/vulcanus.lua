local ei_lib = require("lib/lib")
local ei_data = require("lib/data")
local util = require("util")

ei_lib.recipe_swap("turbo-transport-belt", "lubricant","electrolyte", 20)
ei_lib.recipe_swap("turbo-underground-belt", "lubricant","electrolyte", 40)
ei_lib.recipe_swap("turbo-splitter", "lubricant","electrolyte", 80)
ei_lib.recipe_add("turbo-transport-belt", "ei-steel-mechanical-parts", 8, false)
ei_lib.recipe_add("turbo-underground-belt", "ei-steel-mechanical-parts", 30, false)
ei_lib.recipe_add("turbo-splitter", "ei-steel-mechanical-parts", 15, false)

-- set next upgrade of turbo belt, splitter and underground to ei_neo-belt
ei_lib.raw["transport-belt"]["turbo-transport-belt"].next_upgrade = "ei-neo-belt"
ei_lib.raw["splitter"]["turbo-splitter"].next_upgrade = "ei-neo-splitter"
ei_lib.raw["underground-belt"]["turbo-underground-belt"].next_upgrade = "ei-neo-underground-belt"

-- set localised descriptions
ei_lib.raw["item"]["burner-inserter"].localised_description = {"item-description.ei_burner-inserter"}
ei_lib.raw["item"]["oil-refinery"].localised_description = {"item-description.ei_oil-refinery"}

-- set localised name of ores to ei ones
data.raw["resource"]["iron-ore"].localised_name = {"item-name.ei-poor-iron-chunk"}
data.raw["resource"]["copper-ore"].localised_name = {"item-name.ei-poor-copper-chunk"}
data.raw["resource"]["uranium-ore"].localised_name = {"item-name.ei-poor-uranium-chunk"}

local p_d_v = ei_lib.raw.technology["planet-discovery-vulcanus"]
if p_d_v then
    p_d_v.age = "computer-age"
end
--cliff explosives
ei_lib.set_prerequisites("cliff-explosives",{"military-2","planet-discovery-vulcanus","explosives"})

-- foundry
local foundry = ei_lib.raw["assembling-machine"].foundry
if foundry then
    foundry.crafting_speed = 1.5
    foundry.energy_usage = "58MW"
    foundry.module_slots = 2
    foundry.energy_source.emissions_per_minute.pollution=18
    table.insert(foundry.crafting_categories,"ei-casting")
end

ei_lib.recipe_swap("casting-low-density-structure","molten-iron","ei-molten-steel",50)

ei_lib.raw.recipe["casting-steel"].ingredients = {
    {type="fluid",name="ei-molten-steel",amount=20}
}
ei_lib.raw.recipe["casting-steel"].results = {
    {type="item",name="steel-plate",amount=2}
}

local casting_iron_gear_wheel = ei_lib.raw.recipe["casting-iron-gear-wheel"]
local iron_mechanical_parts = ei_lib.raw.item["ei-iron-mechanical-parts"]
if casting_iron_gear_wheel and iron_mechanical_parts then
    casting_iron_gear_wheel.results = {
        {type = "item", name = "ei-iron-mechanical-parts", amount = 2}
    }
    casting_iron_gear_wheel.main_product = "ei-iron-mechanical-parts"
    casting_iron_gear_wheel.localised_name = nil
    casting_iron_gear_wheel.icon = iron_mechanical_parts.icon
    casting_iron_gear_wheel.icon_size = iron_mechanical_parts.icon_size
    casting_iron_gear_wheel.icons = iron_mechanical_parts.icons and util.table.deepcopy(iron_mechanical_parts.icons) or nil
end

local casting_iron_stick = ei_lib.raw.recipe["casting-iron-stick"]
local iron_beam = ei_lib.raw.item["ei-iron-beam"]
if casting_iron_stick and iron_beam then
    casting_iron_stick.results = {
        {type = "item", name = "ei-iron-beam", amount = 1}
    }
    casting_iron_stick.main_product = "ei-iron-beam"
    casting_iron_stick.localised_name = nil
    casting_iron_stick.icon = iron_beam.icon
    casting_iron_stick.icon_size = iron_beam.icon_size
    casting_iron_stick.icons = iron_beam.icons and util.table.deepcopy(iron_beam.icons) or nil
end

local casting_ei_copper_beam_template = ei_lib.raw.recipe["casting-iron-stick"]
local copper_beam = ei_lib.raw.item["ei-copper-beam"]
if casting_ei_copper_beam_template and copper_beam then
    local casting_ei_copper_beam = util.table.deepcopy(casting_ei_copper_beam_template)
    casting_ei_copper_beam.name = "casting-ei-copper-beam"
    casting_ei_copper_beam.ingredients = {
        {type = "fluid", name = "ei-molten-copper", amount = 20, fluidbox_multiplier = 10}
    }
    casting_ei_copper_beam.results = {
        {type = "item", name = "ei-copper-beam", amount = 1}
    }
    casting_ei_copper_beam.energy_required = 2
    casting_ei_copper_beam.main_product = "ei-copper-beam"
    casting_ei_copper_beam.localised_name = nil
    casting_ei_copper_beam.icon = copper_beam.icon
    casting_ei_copper_beam.icon_size = copper_beam.icon_size
    casting_ei_copper_beam.icons = copper_beam.icons and util.table.deepcopy(copper_beam.icons) or nil
    data:extend({casting_ei_copper_beam})
    ei_lib.add_unlock_recipe("foundry", "casting-ei-copper-beam")
end

local casting_ei_steel_beam_template = ei_lib.raw.recipe["casting-iron-stick"]
local steel_beam = ei_lib.raw.item["ei-steel-beam"]
if casting_ei_steel_beam_template and steel_beam then
    local casting_ei_steel_beam = util.table.deepcopy(casting_ei_steel_beam_template)
    casting_ei_steel_beam.name = "casting-ei-steel-beam"
    casting_ei_steel_beam.ingredients = {
        {type = "fluid", name = "ei-molten-steel", amount = 20, fluidbox_multiplier = 10}
    }
    casting_ei_steel_beam.results = {
        {type = "item", name = "ei-steel-beam", amount = 1}
    }
    casting_ei_steel_beam.energy_required = 2
    casting_ei_steel_beam.main_product = "ei-steel-beam"
    casting_ei_steel_beam.localised_name = nil
    casting_ei_steel_beam.icon = steel_beam.icon
    casting_ei_steel_beam.icon_size = steel_beam.icon_size
    casting_ei_steel_beam.icons = steel_beam.icons and util.table.deepcopy(steel_beam.icons) or nil
    data:extend({casting_ei_steel_beam})
    ei_lib.add_unlock_recipe("foundry", "casting-ei-steel-beam")
end

local casting_ei_copper_mechanical_parts_template = ei_lib.raw.recipe["casting-iron-gear-wheel"]
local copper_mechanical_parts = ei_lib.raw.item["ei-copper-mechanical-parts"]
if casting_ei_copper_mechanical_parts_template and copper_mechanical_parts then
    local casting_ei_copper_mechanical_parts = util.table.deepcopy(casting_ei_copper_mechanical_parts_template)
    casting_ei_copper_mechanical_parts.name = "casting-ei-copper-mechanical-parts"
    casting_ei_copper_mechanical_parts.ingredients = {
        {type = "fluid", name = "ei-molten-copper", amount = 10, fluidbox_multiplier = 10}
    }
    casting_ei_copper_mechanical_parts.results = {
        {type = "item", name = "ei-copper-mechanical-parts", amount = 2}
    }
    casting_ei_copper_mechanical_parts.energy_required = 0.5
    casting_ei_copper_mechanical_parts.main_product = "ei-copper-mechanical-parts"
    casting_ei_copper_mechanical_parts.localised_name = nil
    casting_ei_copper_mechanical_parts.icon = copper_mechanical_parts.icon
    casting_ei_copper_mechanical_parts.icon_size = copper_mechanical_parts.icon_size
    casting_ei_copper_mechanical_parts.icons = copper_mechanical_parts.icons and util.table.deepcopy(copper_mechanical_parts.icons) or nil
    data:extend({casting_ei_copper_mechanical_parts})
    ei_lib.add_unlock_recipe("foundry", "casting-ei-copper-mechanical-parts")
end

local casting_ei_steel_mechanical_parts_template = ei_lib.raw.recipe["casting-iron-gear-wheel"]
local steel_mechanical_parts = ei_lib.raw.item["ei-steel-mechanical-parts"]
if casting_ei_steel_mechanical_parts_template and steel_mechanical_parts then
    local casting_ei_steel_mechanical_parts = util.table.deepcopy(casting_ei_steel_mechanical_parts_template)
    casting_ei_steel_mechanical_parts.name = "casting-ei-steel-mechanical-parts"
    casting_ei_steel_mechanical_parts.ingredients = {
        {type = "fluid", name = "ei-molten-steel", amount = 10, fluidbox_multiplier = 10}
    }
    casting_ei_steel_mechanical_parts.results = {
        {type = "item", name = "ei-steel-mechanical-parts", amount = 2}
    }
    casting_ei_steel_mechanical_parts.energy_required = 1
    casting_ei_steel_mechanical_parts.main_product = "ei-steel-mechanical-parts"
    casting_ei_steel_mechanical_parts.localised_name = nil
    casting_ei_steel_mechanical_parts.icon = steel_mechanical_parts.icon
    casting_ei_steel_mechanical_parts.icon_size = steel_mechanical_parts.icon_size
    casting_ei_steel_mechanical_parts.icons = steel_mechanical_parts.icons and util.table.deepcopy(steel_mechanical_parts.icons) or nil
    data:extend({casting_ei_steel_mechanical_parts})
    ei_lib.add_unlock_recipe("foundry", "casting-ei-steel-mechanical-parts")
end

ei_lib.raw.recipe["molten-copper"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,ignored_by_stats=12
}
ei_lib.raw.recipe["molten-iron"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,ignored_by_stats=12
}
ei_lib.raw.recipe["molten-copper-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,ignored_by_stats=12
}
ei_lib.raw.recipe["molten-iron-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,ignored_by_stats=12
}
local t_plate_recipe = ei_lib.raw.recipe["tungsten-plate"]
if t_plate_recipe then
    t_plate_recipe.results[2] = {
        type="item",name="ei-slag",amount_min=1,amount_max=2,probability=0.44,ignored_by_stats=2
    }
    t_plate_recipe.icon = ei_lib.raw.item["tungsten-plate"].icon
    t_plate_recipe.icon_size = ei_lib.raw.item["tungsten-plate"].icon_size
    t_plate_recipe.localised_name = {"item-name.tungsten-plate"}
end
--[[
local t_carbide_recipe = ei_lib.raw.recipe["tungsten-carbide"]
if t_carbide_recipe then
    t_carbide_recipe.results[2] = {
        type="item",name="ei-slag",amount_min=1,amount_max=2,probability=0.22,ignored_by_stats=2
    }
    t_carbide_recipe.results[3] = {
        type="item",name="atan-ash",amount_min=1,amount_max=2,probability=0.11,ignored_by_stats=2
    }
    t_carbide_recipe.icon = ei_lib.raw.item["tungsten-carbide"].icon
    t_carbide_recipe.icon_size = ei_lib.raw.item["tungsten-carbide"].icon_size
    t_carbide_recipe.localised_name = {"item-name.tungsten-carbide"}
end
]]
ei_lib.merge_fluid("ei-molten-iron", "molten-iron", false)
ei_lib.merge_fluid("ei-molten-copper", "molten-copper", false)
--allow caster to produce space-age plates
local addToCaster = {
    "holmium-plate",
    "tungsten-plate"
}
for _,toCast in pairs(addToCaster) do
    local recipe = ei_lib.raw.recipe[toCast]
    if recipe then
        if recipe.additional_categories then
            table.insert(recipe.additional_categories,"ei-casting")
        else
            recipe.additional_categories = {"ei-casting"}
        end
    end
end

--acid neutralisation
local a_n = ei_lib.raw.recipe["acid-neutralisation"]
if a_n then
    --acid neutralisation t2
    local a_n_t2 = table.deepcopy(a_n)
    a_n_t2.name = "ei-acid-neutralisation-t2"
    a_n_t2.icon = ei_graphics_3_path.."graphics/fluid/acid-neutralisation-t2.png"
    a_n_t2.icon_size = 64
    a_n_t2.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=750},
        {type= "fluid", name= "ei-nitric-acid", amount=250},
    }
    a_n_t2.results = {
        {type= "fluid", name= "steam", amount_min= 9000, amount_max=12500, temperature=500},
        {type = "fluid", name= "ei-acidic-water", amount_min=25,amount_max=125}
    }
    data:extend({
        a_n_t2,
    {
        name = "ei-acid-neutralisation-t2",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/fluid/acid-neutralisation-t2.png",
        icon_size = 64,
        prerequisites = {"ei-nitric-acid","metallurgic-science-pack"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-acid-neutralisation-t2"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-calcite-bed",
        type = "item",
        icon = ei_path.."graphics/items/calcite-bed.png",
        icon_size = 128,
        icon_mipmaps = 3,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "h[fluorite]-a[calcite-bed]",
    },
    {
        name = "ei-calcite-bed",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "calcite", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 1},
        },
        results = {
            {type = "item", name = "ei-calcite-bed", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-calcite-bed",
    },
    {
        name = "ei-acidic-water-fluorite-bed",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-acidic-water", amount = 100},
            {type = "fluid", name = "steam", amount = 100, minimum_temperature = 500},
            {type = "item", name = "ei-calcite-bed", amount = 1},
        },
        results = {
            {type = "item", name = "ei-fluorite", amount = 1},
            {type = "fluid", name = "water", amount_min = 1, amount_max = 20, ignored_by_stats = 20, ignored_by_productivity = 20},
            {type = "fluid", name = "ei-carbon-dioxide", amount = 10, ignored_by_stats = 10, ignored_by_productivity = 10},
            {type = "item", name = "ei-calcite-bed", amount = 1, probability = 0.25, ignored_by_stats = 1, ignored_by_productivity = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fluorite",
        icons = ei_lib.make_icons(
            ei_graphics_item_path.."fluorite.png",
            64,
            ei_path.."graphics/items/calcite-bed.png",
            128,
            0.28,
            {10, 10},
            nil,
            {overlay_mipmaps = 3, base_scale = 1.05}
        ),
        icon_size = 64,
    },
    {
        name = "ei-carbon-dioxide-acidic-water",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-carbon-dioxide", amount = 20},
            {type = "fluid", name = "water", amount = 20},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-acidic-water",
        icons = ei_lib.make_icons(
            ei_graphics_fluid_path.."acidic-water.png",
            64,
            ei_path.."graphics/fluids/carbon-dioxide.png",
            64,
            0.36,
            {9, 9}
        ),
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "a[fluid-chemistry]-a[ei_carbon-dioxide-acidic-water]",
    },
        })
    local a_n_t2_tech = ei_lib.raw.technology["ei-acid-neutralisation-t2"]
    table.insert(a_n_t2_tech.unit.ingredients,{"metallurgic-science-pack",1})
    ei_lib.add_unlock_recipe("ei-acid-neutralisation-t2", "ei-calcite-bed")
    ei_lib.add_unlock_recipe("ei-acid-neutralisation-t2", "ei-acidic-water-fluorite-bed")
    ei_lib.add_unlock_recipe("ei-acid-neutralisation-t2", "ei-carbon-dioxide-acidic-water")
    ei_lib.add_unlock_recipe("ei-acid-neutralisation-t2", "ei-carbon-dioxide-vent")
    a_n.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=1000},
    }
    --modify acid neutralization
    a_n.results = {
        {type= "fluid", name= "steam", amount_min= 7500, amount_max=9500, temperature= 280},
        {type = "fluid", name= "ei-acidic-water", amount_min=50,amount_max=250}
    }
end
--tungsten requires lubricant
ei_lib.raw["resource"]["tungsten-ore"].minable.required_fluid = "lubricant"
ei_lib.raw["resource"]["tungsten-ore"].minable.fluid_amount = 25
