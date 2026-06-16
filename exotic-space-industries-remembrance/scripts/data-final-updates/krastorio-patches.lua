--====================================================================================================
-- -- CHECK FOR MOD
--====================================================================================================
if not mods["Krastorio2-spaced-out"] then
    return
end

local ei_lib = require("lib.lib")
local ei_data = require("lib.data")

if not ei_lib.config("enable-preliminary-k2so-patch") then
    return
end

local function k2so_startup_enabled(setting_name)
    return settings
        and settings.startup
        and settings.startup[setting_name]
        and settings.startup[setting_name].value
end

local function remap_prerequisites(prerequisites)
    local mapped = {}
    local seen = {}

    for _, prerequisite in ipairs(prerequisites) do
        local mapped_name = ei_data.tech_swap_dict[prerequisite] or prerequisite

        if data.raw.technology[mapped_name] and not seen[mapped_name] then
            seen[mapped_name] = true
            table.insert(mapped, mapped_name)
        elseif not data.raw.technology[mapped_name] then
            log("K2SO compat: prerequisite '" .. mapped_name .. "' missing while restoring tech shape")
        end
    end

    return mapped
end

local function remap_unit_ingredients(ingredients)
    local mapped = {}
    local seen = {}

    for _, ingredient in ipairs(ingredients) do
        local name = ingredient
        local amount = 1

        if type(ingredient) == "table" then
            name = ingredient.name or ingredient[1]
            amount = ingredient.amount or ingredient[2] or 1
        end

        local mapped_name = ei_data.science_dict[name] or name
        if not seen[mapped_name] then
            seen[mapped_name] = true
            table.insert(mapped, {mapped_name, amount})
        end
    end

    return mapped
end

local function restore_tech_shape(tech_name, shape)
    local tech = data.raw.technology[tech_name]
    if not tech then
        log("K2SO compat: tech '" .. tech_name .. "' missing while restoring tech shape")
        return
    end

    if shape.prerequisites then
        tech.prerequisites = remap_prerequisites(shape.prerequisites)
    end

    if shape.unit then
        tech.research_trigger = nil
        tech.unit = tech.unit or {}
        tech.unit.count = shape.unit.count
        tech.unit.count_formula = nil
        tech.unit.time = shape.unit.time
        tech.unit.ingredients = remap_unit_ingredients(shape.unit.ingredients)
    elseif shape.research_trigger then
        tech.unit = nil
    end

    if shape.research_trigger then
        tech.research_trigger = table.deepcopy(shape.research_trigger)
    end
end

local function k2so_merge_prototype_fields(target, source)
    for key, value in pairs(source) do
        if key ~= "type" and key ~= "name" then
            target[key] = table.deepcopy(value)
        end
    end
end

local function k2so_upsert_prototype(prototype)
    if not prototype or type(prototype) ~= "table" then
        return
    end

    local prototype_type = prototype.type
    local prototype_name = prototype.name
    local prototype_bucket = prototype_type and data.raw[prototype_type]

    if prototype_bucket and prototype_bucket[prototype_name] then
        k2so_merge_prototype_fields(prototype_bucket[prototype_name], prototype)
        return prototype_bucket[prototype_name]
    end

    data:extend({prototype})
    return prototype
end

local function k2so_upsert_prototypes(prototypes)
    local to_extend = {}

    for _, prototype in ipairs(prototypes) do
        local prototype_type = prototype.type
        local prototype_name = prototype.name
        local prototype_bucket = prototype_type and data.raw[prototype_type]

        if prototype_bucket and prototype_bucket[prototype_name] then
            k2so_merge_prototype_fields(prototype_bucket[prototype_name], prototype)
        else
            table.insert(to_extend, prototype)
        end
    end

    if #to_extend > 0 then
        data:extend(to_extend)
    end
end

if k2so_startup_enabled("kr-containers") then
    local container_sizes = {
        ["container"] = {
            ["kr-strongbox"] = 24,
            ["kr-warehouse"] = 48,
        },
        ["logistic-container"] = {
            ["kr-active-provider-strongbox"] = 24,
            ["kr-buffer-strongbox"] = 24,
            ["kr-passive-provider-strongbox"] = 24,
            ["kr-requester-strongbox"] = 24,
            ["kr-storage-strongbox"] = 24,
            ["kr-active-provider-warehouse"] = 48,
            ["kr-buffer-warehouse"] = 48,
            ["kr-passive-provider-warehouse"] = 48,
            ["kr-requester-warehouse"] = 48,
            ["kr-storage-warehouse"] = 48,
        },
    }

    for prototype_type, prototype_sizes in pairs(container_sizes) do
        local prototype_bucket = data.raw[prototype_type]
        if prototype_bucket then
            for prototype_name, size in pairs(prototype_sizes) do
                local prototype = prototype_bucket[prototype_name]
                if prototype then
                    prototype.inventory_size = size
                end
            end
        end
    end
end

local k2so_tech_restores = {
    ["kr-quarry-minerals-extraction"] = {
        prerequisites = {"electric-engine", "kr-advanced-chemistry", "processing-unit", "production-science-pack"},
        unit = {
            count = 350,
            time = 60,
            ingredients = {
                "automation-science-pack",
                "logistic-science-pack",
                "chemical-science-pack",
                "production-science-pack",
            },
        },
    },
    ["kr-imersium-processing"] = {
        prerequisites = {"kr-quarry-minerals-extraction"},
        unit = {
            count = 500,
            time = 60,
            ingredients = {
                "production-science-pack",
                "utility-science-pack",
            },
        },
    },
    ["kr-advanced-tech-card"] = {
        prerequisites = {"kr-imersium-processing", "utility-science-pack", "kr-lithium-sulfur-battery"},
        unit = {
            count = 1000,
            time = 45,
            ingredients = {
                "production-science-pack",
                "utility-science-pack",
            },
        },
    },
    ["kr-energy-control-unit"] = {
        prerequisites = {"kr-advanced-tech-card"},
        unit = {
            count = 350,
            time = 30,
            ingredients = {
                "production-science-pack",
                "utility-science-pack",
                "kr-advanced-tech-card",
            },
        },
    },
    ["kr-ai-core"] = {
        prerequisites = {"kr-quarry-minerals-extraction", "utility-science-pack"},
        unit = {
            count = 500,
            time = 60,
            ingredients = {
                "automation-science-pack",
                "logistic-science-pack",
                "chemical-science-pack",
                "production-science-pack",
                "utility-science-pack",
            },
        },
    },
    ["kr-fusion-energy"] = {
        prerequisites = {"kovarex-enrichment-process", "kr-lithium-processing", "nuclear-power", "utility-science-pack"},
        unit = {
            count = 1500,
            time = 60,
            ingredients = {
                "automation-science-pack",
                "logistic-science-pack",
                "chemical-science-pack",
                "production-science-pack",
                "utility-science-pack",
            },
        },
    },
    ["kr-matter-tech-card"] = {
        prerequisites = {"cryogenic-plant", "kr-lithium-processing"},
        research_trigger = {
            type = "craft-item",
            item = "cryogenic-plant",
        },
    },
    ["planet-discovery-aquilo"] = {
        prerequisites = {"rocket-turret", "advanced-asteroid-processing", "heating-tower", "asteroid-reprocessing", "electromagnetic-science-pack", "kr-advanced-tech-card"},
        unit = {
            count = 3000,
            time = 60,
            ingredients = {
                "automation-science-pack",
                "logistic-science-pack",
                "chemical-science-pack",
                "production-science-pack",
                "utility-science-pack",
                "space-science-pack",
                "metallurgic-science-pack",
                "agricultural-science-pack",
                "electromagnetic-science-pack",
                "kr-advanced-tech-card",
            },
        },
    },
    ["promethium-science-pack"] = {
        prerequisites = {"biter-egg-handling", "fusion-reactor", "kr-singularity-tech-card"},
        unit = {
            count = 10000,
            time = 60,
            ingredients = {
                "automation-science-pack",
                "logistic-science-pack",
                "chemical-science-pack",
                "production-science-pack",
                "utility-science-pack",
                "space-science-pack",
                "metallurgic-science-pack",
                "agricultural-science-pack",
                "electromagnetic-science-pack",
                "cryogenic-science-pack",
                "kr-advanced-tech-card",
                "kr-matter-tech-card",
                "kr-singularity-tech-card",
            },
        },
    },
}

for tech_name, shape in pairs(k2so_tech_restores) do
    restore_tech_shape(tech_name, shape)
end

goto do_not_load
-- changes to K2 mod

local ei_lib = require("lib.lib")
local ei_data = require("lib.data")
local matter = require("__Krastorio2-spaced-out__.prototypes.libraries.matter")
-- local variations_util = require("-Krastorio2-.prototypes.updates.generate-roboport-variations")
local _td = table.deepcopy

--CONSTANTS
------------------------------------------------------------------------------------------------------
local ei_medium_container, ei_big_container = 32, 64
local ei_neo_speed = data.raw["transport-belt"]["transport-belt"].speed * 8

local function convertTypePrototype(name, old_type, new_type)
    if data.raw[old_type][name] then
        local new_prototype = table.deepcopy(data.raw[old_type][name])
        new_prototype.type = new_type
        data.raw[old_type][name] = nil
        k2so_upsert_prototype(new_prototype)
    end
end

--====================================================================================================
-- -- NEW PROTOTYPES
--====================================================================================================

--ROBOPORT
------------------------------------------------------------------------------------------------------

-- if mods["exotic-industries-robots"] then

-- variations_util.createRoboportVariations("ei-advanced-port")

-- end

--MATTER
------------------------------------------------------------------------------------------------------
local K2_MATTER =  {
    -- TODO: dirty-water / ei_dirty-water
    {
        material = {
            name = "ei-uranium-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-uranium-processing",
    },{
        material = {
            name = "ei-sulfur-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-sulfur-processing",
    },{
        material = {
            name = "ei-iron-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-iron-processing",
    },{
        material = {
            name = "ei-neodym-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-neodym-processing",
    },{
        material = {
            name = "ei-lead-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-lead-processing",
    },{
        material = {
            name = "ei-gold-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-gold-processing",
    },{
        material = {
            name = "ei-copper-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-copper-processing",
    },{
        material = {
            name = "ei-coal-chunk",
            type = "item",
            amount = 10,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-coal-processing",
    },{
        material = {
            name = "ei-coal-gas",
            type = "fluid",
            amount = 100,
        },
        matter_count = 4,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-coal-gas-processing",
    },{
        material = {
            name = "ei-ammonia-gas",
            type = "fluid",
            amount = 100,
        },
        matter_count = 10,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-ammonia-gas-processing",
    },{
        material = {
            name = "ei-phythogas",
            type = "fluid",
            amount = 100,
        },
        matter_count = 20,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-pythogas-processing",
    },{
        material = {
            name = "ei-cryoflux",
            type = "fluid",
            amount = 100,
        },
        matter_count = 20,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-cryoflux-processing",
    },{
        material = {
            name = "ei-poor-iron-chunk",
            type = "item",
            amount = 5,
        },
        matter_count = 5,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-iron-processing",
    },{
        material = {
            name = "ei-poor-copper-chunk",
            type = "item",
            amount = 5,
        },
        matter_count = 5,
        energy_required = 1,
        allow_productivity = true,
        unlocked_by = "kr-matter-copper-processing",
    },{
        material = {
            name = "ei-bio-matter",
            type = "item",
            amount = 1,
        },
        matter_count = 80,
        energy_required = 20,
        allow_productivity = true,
        unlocked_by = "kr-matter-bio-matter-processing",
    },
}

for _, matter_args in pairs(K2_MATTER) do
    if not data.raw.technology[matter_args.unlocked_by] then
        local item = data.raw.item[matter_args.material] or data.raw.fluid[matter_args.material]
        local tech = table.deepcopy(data.raw.technology["kr-matter-iron-processing"])
        tech.name = matter_args.unlocked_by
        tech.effects = {}
        tech.icon = nil
        tech.icons = {
            {
                icon = "-Krastorio2Assets-/technologies/backgrounds/matter.png",
                icon_size = 256,
            },
        }
        -- krastorio.icons.addOverlayIcons(tech, krastorio.icons.getIconsForOverlay(item), 64, 2, {0, 0})
        k2so_upsert_prototype(tech)
    end
    matter.make_recipes(matter_args)
end

--CATEGORIES, GROUPS, SUBGROUPS
------------------------------------------------------------------------------------------------------
k2so_upsert_prototypes({
    {
        name = "ei-science-data",
        type = "item-subgroup",
        group = "intermediate-products",
    },
    {
        name = "ei-science-tech-card",
        type = "item-subgroup",
        group = "intermediate-products",
    },
    --[[
    {
        name = "t4-tech-cards",
        type = "recipe-category",
    },
    ]]
    {
        name = "ei-atmosphere-condensation",
        type = "recipe-category",
    },
    {
        name = "ei-science",
        type = "item-group",
        icon = ei_graphics_other_path.."science.png",
        icon_size = 128,
        inventory_order = "d-a",
        order = "d-a",
    },
    {
        name = "ei-science-other",
        type = "item-subgroup",
        group = "ei-science",
        order = "a",
    },
    {
        name = "ei-science-kr-cards",
        type = "item-subgroup",
        group = "ei-science",
        order = "b",
    },
    {
        name = "ei-science-ei-cards",
        type = "item-subgroup",
        group = "ei-science",
        order = "c",
    },
    {
        name = "ei-science-science",
        type = "item-subgroup",
        group = "ei-science",
        order = "d",
    },
    {
        name = "underground-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-a",
    },
    {
        name = "splitter-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-b",
    },
    {
        name = "loader-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-c",
    },
})

--====================================================================================================
--PROPERTIES CHANGES
--====================================================================================================

convertTypePrototype("ei-arc-furnace", "furnace", "assembling-machine")
convertTypePrototype("kr-crusher", "furnace", "assembling-machine")

--convertTypePrototype("basic-tech-card", "tool", "item")
--[[
convertTypePrototype("automation-science-pack", "tool", "item")
convertTypePrototype("logistic-science-pack", "tool", "item")
convertTypePrototype("military-science-pack", "tool", "item")
convertTypePrototype("chemical-science-pack", "tool", "item")
convertTypePrototype("production-science-pack", "tool", "item")
convertTypePrototype("utility-science-pack", "tool", "item")
convertTypePrototype("space-science-pack", "tool", "item")
convertTypePrototype("matter-tech-card", "tool", "item")
convertTypePrototype("advanced-tech-card", "tool", "item")
convertTypePrototype("singularity-tech-card", "tool", "item")
]]
ei_lib.add_item_level("kr-superior-filter-inserter", "filter")
ei_lib.add_item_level("kr-superior-long-filter-inserter", "filter")
ei_lib.add_item_level("kr-crusher", "3")
ei_lib.add_item_level("kr-advanced-solar-panel", "4")
ei_lib.add_item_level("accumulator", "1")
ei_lib.add_item_level("kr-energy-storage", "2")
ei_lib.add_item_level("stone-furnace", "1")
ei_lib.add_item_level("steel-furnace", "2")
ei_lib.add_item_level("electric-furnace", "3")
ei_lib.add_item_level("kr-advanced-furnace", "4")
ei_lib.add_item_level("kr-advanced-chemical-plant", "4")
ei_lib.add_item_level("ei-dark-age-lab", "1")
ei_lib.add_item_level("lab", "2")
ei_lib.add_item_level("kr-advanced-lab", "3")
ei_lib.add_item_level("kr-singularity-lab", "4")
ei_lib.add_item_level("ei-big-lab", "5")
ei_lib.add_item_level("kr-advanced-assembling-machine", "5")
ei_lib.add_item_level("ei-purifier", "1")
ei_lib.add_item_level("kr-filtration-plant", "2")
ei_lib.add_item_level("kr-research-server", "1")
ei_lib.add_item_level("kr-quantum-computer", "2")
ei_lib.add_item_level("ei-quantum-computer", "3")
ei_lib.add_item_level("ei-lufter", "1")
ei_lib.add_item_level("kr-atmospheric-condenser", "2")

data.raw.lab["lab"].inputs = nil
data.raw.lab["kr-advanced-lab"].inputs = nil
data.raw.lab["kr-singularity-lab"].inputs = nil
data.raw.resource["kr-imersite"].autoplace = nil
data.raw["assembling-machine"]["kr-crusher"].crafting_categories = nil
data.raw["assembling-machine"]["ei-arc-furnace"].source_inventory_size = nil
data.raw["assembling-machine"]["kr-crusher"].source_inventory_size = nil

local K2_CHANGES = {
    ["item-subgroup"] = {
        ["ei-science-data"] = {order = "h1"},
        ["ei-science-tech-card"] = {order = "h2"},
        ["science-pack"] = {order = "h3"},
    },
    ["storage-tank"] = {
        ["ei-tank-1"] = {fluid_box = { base_area = 1200 }},
        ["ei-tank-2"] = {fluid_box = { base_area = 4000 }},
        ["ei-tank-3"] = {fluid_box = { base_area = 1200 }},
    },
    ["container"] = {
        ["kr-medium-container"] = {inventory_size = ei_medium_container},
        ["kr-big-container"] = {inventory_size = ei_big_container},
    },
    ["logistic-container"] = {
        ["kr-big-active-provider-container"] = {inventory_size = ei_big_container},
        ["kr-big-buffer-container"] = {inventory_size = ei_big_container},
        ["kr-big-passive-provider-container"] = {inventory_size = ei_big_container},
        ["kr-big-requester-container"] = {inventory_size = ei_big_container},
        ["kr-big-storage-container"] = {inventory_size = ei_big_container},
        ["kr-medium-active-provider-container"] = {inventory_size = ei_medium_container},
        ["kr-medium-buffer-container"] = {inventory_size = ei_medium_container},
        ["kr-medium-passive-provider-container"] = {inventory_size = ei_medium_container},
        ["kr-medium-requester-container"] = {inventory_size = ei_medium_container},
        ["kr-medium-storage-container"] = {inventory_size = ei_medium_container},
    },
    --[[
    ["loader-1x1"] = {
        ["ei-loader"] = {filter_count = 5},
        ["ei-fast-loader"] = {filter_count = 5},
        ["ei-express-loader"] = {filter_count = 5},
        ["ei-advanced-loader"] = {filter_count = 5},
        ["ei-superior-loader"] = {filter_count = 5},
        ["ei-neo-loader"] = {filter_count = 5, speed = ei_neo_speed},
    },
    ]]
    ["transport-belt"] = {
        ["ei-neo-belt"] = {speed = ei_neo_speed},
    },
    ["underground-belt"] = {
        ["ei-neo-underground-belt"] = {speed = ei_neo_speed, max_distance = 50},
    },
    ["splitter"] = {
        ["ei-neo-splitter"] = {speed = ei_neo_speed},
    },
    ["beacon"] = {
        ["kr-singularity-beacon"] = {module_slots = 1, distribution_effectivity = 0.25},
    },
    ["burner-generator"] = {
        ["kr-antimatter-reactor"] = {max_power_output = "10GW"},
    },
    ["assembling-machine"] = {
        ["kr-advanced-chemical-plant"] = {crafting_categories = {"ei-advanced-chem-plant", "chemistry"}, localised_name = {"item-name.kr-advanced-chemical-plant"}},
        ["kr-crusher"] = {crafting_categories = {"ei-crushing"}, crafting_speed = 12, localised_name = {"item-name.kr-crusher"}},
        ["kr-filtration-plant"] = {crafting_categories = {"ei-purifier", "kr-fluid-filtration"}, crafting_speed = 3, module_slots = 6},
        ["kr-quantum-computer"] = {crafting_speed = 2},
        ["kr-advanced-assembling-machine"] = {crafting_speed = 8, crafting_categories = {"crafting", "basic-crafting", "advanced-crafting", "crafting-with-fluid"}, module_slots = 6, energy_usage = "10MW",},
        ["ei-quantum-computer"] = {crafting_categories = {"ei-quantum-computer", "kr-tech-cards"}, crafting_speed = 10, localised_name = {"item-name.kr-ai-core"}}, -- from 1x
        ["kr-atmospheric-condenser"] = {crafting_categories = {"ei-atmosphere-condensation", "ei-lufter"}, crafting_speed = 4},
    },
    ["lab"] = {
        ["kr-spaceship-research-computer"] = {inputs = {"ei-dark-age-tech"}},
        ["lab"] = {inputs = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech"}},
        ["kr-advanced-lab"] = {inputs = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech", "ei-computer-age-tech"}, researching_speed = 2},
        ["kr-singularity-lab"] = {inputs = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech", "ei-computer-age-tech", "ei-advanced-computer-age-tech", "ei-alien-computer-age-tech", "ei-quantum-age-tech"}, researching_speed = 4},
        ["ei-big-lab"] = {inputs = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech", "ei-computer-age-tech", "ei-advanced-computer-age-tech", "ei-alien-computer-age-tech", "ei-quantum-age-tech",
        --"ei-space-quantum-age-tech", 
        "ei-fusion-quantum-age-tech", "ei-matter-quantum-age-tech", "ei-imersite-quantum-age-tech", "ei-exotic-age-tech", "ei-black-hole-exotic-age-tech"}},
    },
    ["tool"] = {
        ["ei-dark-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-steam-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-electricity-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-computer-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-alien-computer-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-advanced-computer-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-quantum-age-tech"] = {subgroup = "ei-science-science"},
        --["ei-space-quantum-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-fusion-quantum-age-tech"] = {subgroup = "ei-science-science"},
        --["ei-imersite-quantum-age-tech"] = {subgroup = "ei-science-science"},
        --["ei-matter-quantum-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-exotic-age-tech"] = {subgroup = "ei-science-science"},
        ["ei-black-hole-exotic-age-tech"] = {subgroup = "ei-science-science"},
    },
    ["item"] = {
        ["underground-belt"] = {subgroup = "underground-belt"},
        ["fast-underground-belt"] = {subgroup = "underground-belt"},
        ["express-underground-belt"] = {subgroup = "underground-belt"},
        ["kr-advanced-underground-belt"] = {subgroup = "underground-belt"},
        ["kr-superior-underground-belt"] = {subgroup = "underground-belt"},
        --["ei-neo-underground-belt"] = {subgroup = "underground-belt"},

        ["splitter"] = {subgroup = "splitter-belt"},
        ["fast-splitter"] = {subgroup = "splitter-belt"},
        ["express-splitter"] = {subgroup = "splitter-belt"},
        ["kr-advanced-splitter"] = {subgroup = "splitter-belt"},
        ["kr-superior-splitter"] = {subgroup = "splitter-belt"},
        --["ei-neo-splitter"] = {subgroup = "splitter-belt"},

        ["kr-loader"] = {subgroup = "loader-belt"},
        ["kr-fast-loader"] = {subgroup = "loader-belt"},
        ["kr-express-loader"] = {subgroup = "loader-belt"},
        ["kr-advanced-loader"] = {subgroup = "loader-belt"},
        ["kr-superior-loader"] = {subgroup = "loader-belt"},

        ["ei-express-loader"] = {order = "h[ei_loader]-c[ei_express-loader]"},
        ["ei-fast-loader"] = {order = "h[ei_loader]-b[ei_fast-loader]"},
        ["ei-insulated-tank"] = {order = "z-b[fluid]-g[ei_insulated-tank]"},
        ["ei-loader"] = {order = "h[ei_loader]-a[ei_loader]"},
        ["ei-neo-belt"] = {order = "a[transport-belt]-f[ei_neo-belt]"},
        ["ei-neo-loader"] = {order = "h[ei_loader]-f[ei_neo-loader]"},
        ["ei-neo-splitter"] = {order = "c[splitter]-f[ei_neo-splitter]"},
        ["ei-neo-underground-belt"] = {order = "b[underground-belt]-f[ei_neo-underground-belt]"},
        ["ei-tank-1"] = {order = "z-b[fluid]-c[ei_tank-1]"}, -- if not loaded set properties handles this
        ["ei-tank-2"] = {order = "z-b[fluid]-f[ei_tank-2]"},
        ["ei-tank-3"] = {order = "z-b[fluid]-d[ei_tank-3]"},

        ["kr-big-active-provider-container"] = {order = "g"},
        ["kr-big-buffer-container"] = {order = "f"},
        ["kr-big-container"] = {order = "a"},
        ["kr-big-passive-provider-container"] = {order = "c"},
        ["kr-big-requester-container"] = {order = "e"},
        ["kr-big-storage-container"] = {order = "d"},
        ["kr-fluid-storage-1"] = {order = "z-b[fluid]-b[kr-fluid-storage-1]"},
        ["kr-fluid-storage-2"] = {order = "z-b[fluid]-e[kr-fluid-storage-2]"},
        ["kr-medium-active-provider-container"] = {order = "g"},
        ["kr-medium-buffer-container"] = {order = "f"},
        ["kr-medium-container"] = {order = "a"},
        ["kr-medium-passive-provider-container"] = {order = "c"},
        ["kr-medium-requester-container"] = {order = "e"},
        ["kr-medium-storage-container"] = {order = "d"},
        ["storage-tank"] = {order = "z-b[fluid]-a[storage-tank]"},

        ["kr-blank-tech-card"] = {subgroup = "ei-science-other"},
        --["kr-basic-tech-card"] = {subgroup = "ei-science-other"},
        ["automation-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["logistic-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["military-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["chemical-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["production-science-pack"] = {subgroup = "ei-science-kr-cards", order = "b07[utility-tech-card]-a"},
        ["utility-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["space-science-pack"] = {subgroup = "ei-science-kr-cards"},
        ["kr-matter-tech-card"] = {subgroup = "ei-science-kr-cards", order = "b07[utility-tech-card]-b"},
        ["kr-advanced-tech-card"] = {subgroup = "ei-science-kr-cards"},
        ["kr-singularity-tech-card"] = {subgroup = "ei-science-kr-cards"},
        ["ei-simulation-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-space-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-superior-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-plasma-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-magnet-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-fusion-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-sun-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-gas-giant-data"] = {subgroup = "ei-science-ei-cards"},
        ["ei-black-hole-data"] = {subgroup = "ei-science-ei-cards", order = "a-d-a"},
        ["ei-fission-tech"] = {subgroup = "ei-science-ei-cards"},
        ["kr-biter-research-data"] = {subgroup = "ei-science-kr-cards"},
        ["kr-matter-research-data"] = {subgroup = "ei-science-kr-cards"},
        ["kr-space-research-data"] = {subgroup = "ei-science-kr-cards"},

        --energy
        ["kr-wind-turbine"] = {order = "d[solar-panel]-a"},
        ["kr-antimatter-reactor"] = {order = "c-g", subgroup = "ei-nuclear-buildings"},
        ["steam-turbine"] = {order = "b[steam-power]-b[steam-engine]-a"},
        ["heat-exchanger"] = {order = "b[steam-power]-a[fluid-boiler]-a"},
        ["kr-charged-antimatter-fuel-cell"] = {fuel_value = "1TJ"},

        --machinery
        ["kr-quarry-drill"] = {order = "a[items]-a[stone-quarry]-c"},
        ["kr-advanced-assembling-machine"] = {order = "c[assembling-machine-3]-d"},
        ["kr-crusher"] = {order = "d-a-a-3"},
        ["kr-atmospheric-condenser"] = {order = "d-a-c-"},
        ["kr-filtration-plant"] = {order = "d-a-c-2-a"},
        ["kr-greenhouse"] = {order = "d-a-c-7"},
        ["kr-bio-lab"] = {order = "d-a-c-8"},
        ["kr-electrolysis-plant"] = {order = "d-a-c-9"},
        ["kr-fluid-burner"] = {order = "d-a-c-9-1"},

        ["ei-advanced-port"] = {order = "c[signal]-[roboport]-2"},
        ["pipe-to-ground"] = {order = "a[pipe]-a[pipe-to-ground]"},
        ["kr-steel-pipe"] = {order = "a[pipe]-b[pipe]"},
        ["kr-steel-pipe-to-ground"] = {order = "a[pipe]-b[pipe-to-ground]"},
        ["kr-advanced-solar-panel"] = {order = "d[solar-panel]-b[ei_solar-panel-4]"},
        ["ei-quantum-computer"] = {order = "f3[research-servers]-b2", subgroup = "production-machine", localised_name = {"item-name.kr-ai-core"}},
        ["kr-crusher"] = {localised_name = {"item-name.kr-crusher"}},

        ["kr-advanced-lab"] = {order = "a3", subgroup = "ei-labs"},
        ["kr-singularity-lab"] = {order = "a4", subgroup = "ei-labs"},
        ["ei-big-lab"] = {order = "a5", subgroup = "ei-labs"},
        ["kr-advanced-chemical-plant"] = {localised_name = {"item-name.kr-advanced-chemical-plant"}},

        --intermediates
        ["kr-quartz"] = {subgroup = "ei-refining-secondary", order = "c-a"}, --
        ["kr-silicon"] = {subgroup = "ei-refining-secondary", order = "c-b", localised_name = {"item-name.kr-silicon"}}, 
        ["kr-rare-metals"] = {subgroup = "ei-refining-ingot", order = "a7"}, -- 2 recipes
        ["kr-imersium-plate"] = {subgroup = "ei-refining-plate", order = "a7"},
        ["kr-enriched-iron"] = {subgroup = "ei-refining-secondary", order = "c-d"}, --
        ["kr-enriched-copper"] = {subgroup = "ei-refining-secondary", order = "c-e"}, -- 
        ["kr-enriched-rare-metals"] = {subgroup = "ei-refining-secondary", order = "c-d"}, -- 
        ["kr-lithium-chloride"] = {subgroup = "ei-refining-secondary", order = "c-f"}, --
        ["kr-lithium"] = {subgroup = "ei-refining-secondary", order = "c-g", localised_name = {"item-name.kr-lithium"}}, --
        ["kr-imersite-powder"] = {subgroup = "ei-refining-crushed", order = "c2"},
        ["kr-imersium-beam"] = {subgroup = "ei-refining-beam", order = "a4"},
        ["kr-imersium-gear-wheel"] = {subgroup = "ei-refining-parts", order = "a4"},
    },
    ["mining-drill"] = {
        ["electric-mining-drill"] = {next_upgrade = "ei-advanced-electric-mining-drill"},
        ["ei-steam-oil-pumpjack"] = {resource_categories = {"kr-oil"}},
        ["ei-deep-pumpjack"] = {resource_categories = {"ei-pumping", "basic-fluid", "kr-oil"}},
    },
    ["resource"] = {
        ["kr-imersite"] = {autoplace = ei_autoplace("kr-imersite", "gaia")}
    },
    ["recipe"] = {
        ["express-splitter"] = {category = "crafting-with-fluid", ingredients = {
            {type = "item", name = "fast-splitter", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 5},
            {type = "item", name = "kr-rare-metals", amount = 4},
            {type = "item", name = "ei-electronic-parts", amount = 2},
        }},
        --[[ -- why does this not work? manually overwrite below
        ["express-transport-belt"] = {category = "crafting-with-fluid", ingredients = {
            {type = "item", name = "fast-transport-belt", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 5},
            {type = "item", name = "kr-rare-metals", amount = 1},
        }},
        ]]
        ["express-underground-belt"] = {category = "crafting-with-fluid", ingredients = {
            {type = "item", name = "fast-underground-belt", amount = 2},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 5},
            {type = "item", name = "kr-rare-metals", amount = 4},
        }},
        -- intermediates
        ["kr-quartz"] = {subgroup = "ei-refining-secondary", order = "c-a", category = "advanced-crafting"},
        ["kr-rare-metals"] = {subgroup = "ei-refining-ingot", order = "a7"}, -- 2 recipes
        ["kr-rare-metals-2"] = {subgroup = "ei-refining-ingot", order = "a7"}, -- 2 recipes
        ["kr-enriched-iron"] = {subgroup = "ei-refining-secondary", order = "c-d"},
        ["kr-enriched-copper"] = {subgroup = "ei-refining-secondary", order = "c-e"},
        ["kr-enriched-rare-metals"] = {subgroup = "ei-refining-secondary", order = "c-d"},
        ["kr-lithium-chloride"] = {subgroup = "ei-refining-secondary", order = "c-f"},
        ["kr-lithium"] = {subgroup = "ei-refining-secondary", order = "c-g"},

        ["kr-big-active-provider-container"] = {order = "g"},
        ["kr-big-buffer-container"] = {order = "f"},
        ["kr-big-container"] = {order = "a", subgroup = "kr-logistics-3"},
        ["kr-big-passive-provider-container"] = {order = "c"},
        ["kr-big-requester-container"] = {order = "e"},
        ["kr-big-storage-container"] = {order = "d"},
        ["kr-medium-active-provider-container"] = {order = "g"},
        ["kr-medium-buffer-container"] = {order = "f"},
        ["kr-medium-container"] = {order = "a", subgroup = "kr-logistics-2"},
        ["kr-medium-passive-provider-container"] = {order = "c"},
        ["kr-medium-requester-container"] = {order = "e"},
        ["kr-medium-storage-container"] = {order = "d"},
        --transport
        ["kr-advanced-transport-belt"] = {category = "crafting-with-fluid"},
        ["kr-advanced-underground-belt"] = {category = "crafting-with-fluid"},
        ["kr-advanced-splitter"] = {category = "crafting-with-fluid"},
        ["kr-advanced-loader"] = {category = "crafting-with-fluid"},
        -- fuel refining
        ["rocket-fuel"] = {category = "kr-fuel-refinery"},
        ["ei-diesel-fuel-unit"] = {category = "kr-fuel-refinery"},
        ["ei-drill-fluid"] = {category = "kr-fuel-refinery"},
        ["ei-kerosene-heavy-oil"] = {category = "kr-fuel-refinery"},
        -- crushing
        ["sand"] = {category = "ei-crushing"},
        ["kr-imersite-powder"] = {category = "ei-crushing"},
        ["imersite-crystal-to-dust"] = {category = "ei-crushing"},
        -- inserters to parts
        ["inserter-to-parts"] = {category = "ei-crushing"},
        ["fast-inserter-to-parts"] = {category = "ei-crushing"},
        ["long-handed-inserter-to-parts"] = {category = "ei-crushing"},
        ["burner-inserter-to-parts"] = {category = "ei-crushing"},
        ["stack-inserter-to-parts"] = {category = "ei-crushing"},
        ["stack-filter-inserter-to-parts"] = {category = "ei-crushing"},
        ["filter-inserter-to-parts"] = {category = "ei-crushing"},
        ["superior-inserter-to-parts"] = {category = "ei-crushing"},
        ["superior-long-inserter-to-parts"] = {category = "ei-crushing"},
        ["superior-filter-inserter-to-parts"] = {category = "ei-crushing"},
        ["superior-long-filter-inserter-to-parts"] = {category = "ei-crushing"},
        -- k2 science cards + multiplication of ei times
--        ["utility-science-pack"] = {category = "kr-t2-tech-cards"},
--        ["production-science-pack"] = {category = "kr-tech-cards"},
        ["space-science-pack"] = {category = "kr-tech-cards"},
        ["kr-matter-tech-card"] = {category = "kr-tech-cards"},
        ["kr-advanced-tech-card"] = {category = "kr-tech-cards"},
        ["ei-superior-data"] = {energy_required = 50},
        ["ei-plasma-data-deuterium"] = {energy_required = 50},
        ["ei-plasma-data-protium"] = {energy_required = 50},
        ["ei-plasma-data-tritium"] = {energy_required = 50},
        ["ei-magnet-data"] = {energy_required = 50},
        ["ei-fusion-data"] = {energy_required = 50},
    },
    ["armor"] = {
        ["ei-bio-armor"] = {order = "h"},  
    },
    ["equipment-grid"] = {
        ["ei-bio-armor"] = {equipment_categories = {"armor"}}, -- what should the new categories be? removed old universal and robot interactions
    },
    ["solar-panel-equipment"] = {
        ["imersite-solar-panel-equipment"] = {power = "300kW"},
        ["big-imersite-solar-panel-equipment"] = {power = "1400kW"},
    },
    ["energy-shield-equipment"] = {
        ["ei-personal-shield"] = {max_shield_value = 1500, energy_per_shield = "50kJ"},
    },
    ["generator-equipment"] = {
        ["nuclear-reactor-equipment"] = {
            burner = {
                type = "burner", fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",},
                effectivity = 0.25, fuel_inventory_size = 3, burnt_inventory_size = 3
            },
        },
        ["ei-personal-reactor"] = {
            burner = {
                type = "burner", fuel_categories = {"ei-fusion-fuel"},
                effectivity = 1, fuel_inventory_size = 4, burnt_inventory_size = 4
            },
        },
    },
}

for source, group in pairs(K2_CHANGES) do
    for name, object in pairs(group) do
        object.name = name
        object.type = source
        ei_lib.set_properties(object)
    end
end

--table.insert(data.raw["lab"]["ei-big-lab"].inputs, "ei-matter-quantum-age-tech")
--table.insert(data.raw["lab"]["ei-big-lab"].inputs, "ei-imersite-quantum-age-tech")


--====================================================================================================
--TECH FIXES
--====================================================================================================

k2so_upsert_prototypes({
    {
        name = "ei-matter-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."matter-quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "ei-science-science",
        order = "a5-4",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."matter-quantum-age-tech.png",
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
        name = "ei-imersite-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."imersite-quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "ei-science-science",
        order = "a5-3",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."imersite-quantum-age-tech.png",
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
})

local to_remove = {
    "kr-basic-fluid-handling",
    "kr-steam-engine",
    "kr-electric-mining-drill",
    "kr-electric-mining-drill-mk2",
    "kr-electric-mining-drill-mk3",
    "kr-stone-processing",
    "kr-advanced-tech-card",
    "kr-matter-tech-card",
    "kr-fusion-energy",
    "kr-singularity-tech-card",
    "automation-science-pack",
    "kr-laboratory"
}

-- turn K2 fusion into something crystal energy powered

local new_prerequisites = {
    ["steam-age"] = {
        ["kr-automation-core"] = {{"ei-steam-age"},{"ei-steam-assembler"},true},
    },
    ["electricity-age"] = {
        ["kr-gas-power-station"] = {{"ei-fluid-boiler", "advanced-circuit"},{},false},
        ["kr-greenhouse"] = {{"ei-electricity-age"},{},false},
        ["logistics-2"] = {{"plastics", "logistics", "fast-inserter"},{},false},
        ["kr-advanced-lab"] = {{"advanced-circuit"},{"ei-computer-age"},true},
        ["kr-steel-fluid-handling"] = {{"fluid-handling", "electric-engine"},{},true},
        ["kr-steel-fluid-tanks"] = {{"kr-steel-fluid-handling"},{},false},
        ["kr-advanced-radar"] = {{"kr-sentinel", "ei-electronic-parts"},{},false},
        ["advanced-circuit"] = {{"kr-silicon-processing", "sulfur-processing"},{},false},
        ["kr-research-server"] = {{"advanced-circuit", "ei-grower"},{"ei-computer-age"},true},
        ["kr-air-purification"] = {{"advanced-circuit"},{},true},
        ["kr-fuel"] = {{"ei-destill-tower"},{},false},
        ["ei-grower"] = {{"sulfur-processing", "kr-silicon-processing"},{},false},
        ["railway"] = {{"sulfur-processing", "kr-fuel"},{},false},
    },
    ["computer-age"] = {
        ["logistics-3"] = {{"kr-fluids-chemistry", "logistics-2"},{},false},
        ["kr-fluids-chemistry"] = {{"ei-computer-age"},{"kr-atmosphere-condensation", "kr-mineral-water-gathering"},true},
        ["kr-fluid-excess-handling"] = {{"kr-fluids-chemistry"},{},false},
        ["kr-railgun-turret"] = {{"military-4", "kr-fluids-chemistry", "ei-cannon-turret"},{},false},
        ["ei-nitric-acid"] = {{"ei-dinitrogen-tetroxide"},{},false},
        ["bulk-inserter"] = {{"kr-fluids-chemistry"},{},false},
        ["ei-deep-pumpjack"] = {{"kr-fluids-chemistry"},{},false},
        ["ei-cooler"] = {{"kr-fluids-chemistry"},{},false},
        ["kr-nuclear-reactor-equipment"] = {{"fission-reactor-equipment"},{},false},
        ["ei-high-energy-crystal"] = {{"kr-fluids-chemistry"},{},false},
        ["kr-singularity-lab"] = {{"ei-computer-core"},{"ei-advanced-computer-age-tech", "ei-alien-computer-age-tech"},true},
    },
    ["advanced-computer-age"] = {
        ["kr-enriched-ores"] = {{"ei-silicon"},{},false},
        ["kr-improved-pollution-filter"] = {{"processing-unit", "kr-air-purification"},{},true},
        ["kr-advanced-exoskeleton-equipment"] = {{"exoskeleton-equipment"},{},true},
        ["kr-quantum-computer"] = {{"processing-unit"},{"ei-quantum-age"},true},
    },
    ["alien-computer-age"] = {
        ["kr-logistic-4"] = {{"ei-computer-core", "logistics-3"},{},false},
        ["kr-atmosphere-condensation"] = {{"automation-3", "ei-oxygen-gas"},{},false},
        ["kr-advanced-chemistry"] = {{"kr-atmosphere-condensation", "kr-mineral-water-gathering", "ei-advanced-chem-plant"},{},true},
        ["kr-bio-processing"] = {{"ei-sus-plating"},{},true},
        ["kr-bio-fuel"] = {{"kr-advanced-chemistry"},{},false},
        ["kr-nuclear-locomotive"] = {{"automation-3", "nuclear-power"},{},false},
    },
    ["quantum-age"] = {
        ["kr-quarry-minerals-extraction"] = {{"ei-quantum-age", "ei-excavator"},{},false},
        ["kr-logistic-5"] = {{"kr-imersium-processing", "kr-logistic-4"},{},false},
        ["ei-odd-plating"] = {{"ei-nano-factory", "ei-oxygen-difluoride", "kr-quarry-minerals-extraction"},{},false},
        ["ei-big-lab"] = {{"ei-quantum-age"},{"ei-fusion-data", "ei-moon-exploration"},true},
        ["kr-ai-core"] = {{"kr-quarry-minerals-extraction"},{"ei-quantum-computer"},true},
        ["kr-battery-mk3-equipment"] = {{"ei-quantum-computer"},{},false},
        ["kr-imersite-night-vision-equipment"] = {{"ei-quantum-computer"},{},false},
        ["kr-imersium-processing"] = {{"kr-quarry-minerals-extraction", "ei-nano-factory", "ei-oxygen-difluoride", "ei-big-lab", "ei-quantum-computer"},{"kr-energy-control-unit"},true},
        ["kr-lithium-processing"] = {{"ei-oxygen-difluoride"},{"ei-fusion-data"},false},
    },
    ["fusion-quantum-age"] = {
        ["kr-battery-mk3-equipment"] = {{"kr-lithium-sulfur-battery"},{},false},
        ["kr-battery-mk3-equipment"] = {{"kr-lithium-sulfur-battery"},{},false},
        ["kr-lithium-sulfur-battery"] = {{"kr-lithium-processing", "ei-odd-plating"},{},false},
        ["kr-energy-control-unit"] = {{"kr-lithium-sulfur-battery", "ei-clean-plating", "ei-big-lab", "kr-imersium-processing"},{},false},
    },
    ["imersite-quantum-age"] = {
        ["kr-superior-exoskeleton-equipment"] = {{"kr-advanced-exoskeleton-equipment", "kr-imersium-processing"},{},true},
        ["kr-advanced-solar-panel"] = {{"ei-solar-panel-3", "kr-imersium-processing"},{},true},
        ["kr-advanced-chemical-plant"] = {{"ei-fish-growing", "kr-imersium-processing", "ei-advanced-chem-plant"},{},true},
        ["kr-advanced-roboports"] = {{"kr-imersium-processing"},{},true}, --
        ["kr-imersite-solar-panel-equipment"] = {{"ei-personal-solar-3", "kr-imersium-processing"},{},true},
        ["kr-crusher"] = {{"ei-advanced-crusher", "ei-nano-factory", "kr-imersium-processing"},{},true},
        ["kr-advanced-furnace"] = {{"ei-nano-factory", "kr-imersium-processing"},{},true},
        ["kr-power-armor-mk3"] = {{"kr-imersium-processing"},{},false},
        ["kr-automation"] = {{"kr-imersium-processing", "ei-neo-assembler"},{},true},
        ["kr-superior-inserters"] = {{"kr-imersium-processing", "bulk-inserter"},{},true},
        ["kr-logistic-5"] = {{"kr-imersium-processing", "bulk-inserter"},{},true},
        ["kr-energy-storage"] = {{"kr-imersium-processing"},{"ei-superior-induction-matrix"},true},
        ["kr-personal-laser-defense-mk4-equipment"] = {{"kr-personal-laser-defense-mk3-equipment"},{},false},
    },
    ["matter-quantum-age"] = {
        ["kr-advanced-pickaxe"] = {{"kr-energy-control-unit"},{},false},
        ["kr-singularity-beacon"] = {{"kr-energy-control-unit", "ei-iron-beacon"},{},false},
        ["kr-matter-cube"] = {{"kr-energy-control-unit"},{},false},
        ["kr-matter-processing"] = {{"kr-energy-control-unit"},{},false},
        ["kr-laser-artillery-turret"] = {{"kr-energy-control-unit", "kr-military-5"},{},false},
        --["kr-power-armor-mk4"] = {{"kr-power-armor-mk3", "kr-energy-control-unit"},{},false},
        ["kr-biter-virus"] = {{"kr-military-5", "kr-energy-control-unit"},{},false},
        -- ["kr-biter-virus"] = {{"kr-biter-virus"},{},false},
    },
    ["four-quantum-age"] = {
        ["ei-high-tech-parts"] = {{"kr-matter-processing", "ei-asteroid-mining", "ei-eu-circuit", "kr-matter-cube"},{},false},
        ["ei-neo-logistics"] = {{"kr-logistic-5"},{},false},
        ["kr-planetary-teleporter"] = {{"ei-high-tech-parts"},{},false},
        ["ei-bio-armor"] = {{"kr-power-armor-mk3", "ei-high-tech-parts"},{},false},
        ["ei-plasma-turret"] = {{"ei-high-tech-parts", "kr-laser-artillery-turret"},{},false},
        ["kr-antimatter-reactor"] = {{"ei-antimatter-cube"},{},false},
        ["kr-antimatter-ammo"] = {{"kr-antimatter-reactor", "kr-laser-artillery-turret", "kr-rocket-turret"},{},false},
        ["kr-antimatter-reactor-equipment"] = {{"kr-antimatter-reactor", "ei-personal-reactor"},{},false},
        ["ei-personal-shield"] = {{"kr-energy-shield-mk4-equipment", "ei-high-tech-parts"},{},false},
    },
}

for _, tech in ipairs(to_remove) do
    ei_lib.remove_tech(tech)
end

-- potentially overrite thr old prereqs
local overwrite_prereqs = {}
for age, dat in pairs(new_prerequisites) do
    for tech, info in pairs(dat) do
        if info[3] == true then
            -- remove this tech from all other prereqs
            overwrite_prereqs[tech] = true
        end
    end
end

for tech,_ in pairs(data.raw.technology) do
    for _,prereq in ipairs(data.raw.technology[tech].prerequisites or {}) do
        if overwrite_prereqs[prereq] then
            ei_lib.remove_prerequisite(tech, prereq)
        end
    end
end

for age, dat in pairs(new_prerequisites) do
    
    -- first index is new prereq for this tech, second which techs should get this added
    for tech, info in pairs(dat) do
       
        if not data.raw.technology[tech] then
            log("Tech " .. tech .. " does not exist")
            goto continue
        end

        -- set age first
        data.raw.technology[tech].age = age
        ei_lib.set_prerequisites(tech, info[1])

        for _, some_tech in ipairs(info[2]) do
            ei_lib.add_prerequisite(some_tech, tech)
        end

        ::continue::
    end

end

-- fixup age graphs
-- as new techs have set an age property we need to include them aswell

-- prepare list of all altered techs first
local foo = {}
for age, dat in pairs(new_prerequisites) do
    for tech, _ in pairs(dat) do
        foo[tech] = true
    end
end

local function make_dummy_techs(foo, ages_dummy_dict)
    -- loop over all techs in the game
    -- if they have the age attribute
    -- look up the next age in the ages_dummy_dict
    -- and set them as prerequisite for the dummy tech

    for i,_ in pairs(foo) do
        if not data.raw["technology"][i] then
            log("Tech " .. i .. " does not exist")
            goto continue
        end

        if data.raw["technology"][i].age then

            age = data.raw["technology"][i].age

            if ei_data.sub_age[age] then
                age = ei_data.sub_age[age]
            end
            if ages_dummy_dict_age and ages_dummy_dict[age] then
                local next_age = "ei-"..ages_dummy_dict[age].."-dummy"
                if next_age then
                    --set_prerequisites(next_age, i)
                    --table.insert(data.raw["technology"][tech].prerequisites, prerequisite)
                    ei_lib.add_prerequisite(next_age, i)
                end
            end
        end
--[[
            -- find out if the tech already has the age count effect
            for _, effect in pairs(data.raw.technology[i].effects) do
                if ((effect.type == "nothing") and (effect.effect_description == {"description.tech-counts-for-age-progression"})) then
                    goto continue
                end
            end

            table.insert(data.raw.technology[i].effects, {
                type = "nothing",
                effect_description = {"description.tech-counts-for-age-progression"},
                infer_icon = false,
                icon_size = 64,
                icon = ei_graphics_other_path.."tech_overlay.png",
            })
        end
]]
        ::continue::
    end

end
local ages_dummy_dict = ei_data.ages_dummy_dict
make_dummy_techs(foo, ages_dummy_dict)


-- overwrite icons from new sub age techs
data.raw.technology["kr-imersium-processing"].icon = ei_graphics_tech_path.."kr-imersite.png"
data.raw.technology["kr-imersium-processing"].icon_size = 256
data.raw.technology["kr-imersium-processing"].icon_mipmaps = 1

data.raw.technology["kr-energy-control-unit"].icon = ei_graphics_tech_path.."kr-matter.png"
data.raw.technology["kr-energy-control-unit"].icon_size = 256
data.raw.technology["kr-energy-control-unit"].icon_mipmaps = 1

--ITEMS AND RECIPES
------------------------------------------------------------------------------------------------------

--index is target, info is stuff that gets absorbed into it
local items_to_merge = {
    ["ei-iron-beam"] = { item = "iron-beam", use_icon = true },
    ["steel-plate"] = { item = "steel-beam", use_icon = true },
    --["ei-pure-iron"] = { item = "iron-ore", use_icon = false },
    --["ei-pure-copper"] = { item = "copper-ore", use_icon = false },
    ["ei-steel-mechanical-parts"] = { item = "steel-gear-wheel", use_icon = false },
    ["ei-coke"] = { item = "coke", use_icon = false },
    ["ei-sand"] = { item = "sand", use_icon = false },
    ["ei-electronic-parts"] = { item = "electronic-components", use_icon = false },
    ["ei-glass"] = {item = "glass", use_icon = true},
}

local fluids_to_merge = {
    ["ei-nitric-acid"] = { fluid = "nitric-acid", use_icon = true },
    ["ei-dirty-water"] = { fluid = "dirty-water", use_icon = true },
    ["ei-nitrogen-gas"] = { fluid = "nitrogen", use_icon = false },
    ["ei-oxygen-gas"] = { fluid = "oxygen", use_icon = false },
    ["ei-hydrogen-gas"] = { fluid = "kr-hydrogen", use_icon = true },
    ["ei-ammonia-gas"] = { fluid = "ammonia", use_icon = true },
    ["ei-dirty-water"] = { fluid = "dirty-water", use_icon = true },
}

local entites_to_hide = {
    {"generator", "kr-fusion-reactor"},
    {"mining-drill", "kr-electric-mining-drill-mk2"},
    {"mining-drill", "kr-electric-mining-drill-mk3"},
--    {"beacon", "beacon"},
}

-- hide entities
for _, foo in ipairs(entites_to_hide) do
    local entity_type = foo[1]
    local entity_name = foo[2]

    if data.raw[entity_type][entity_name] then
        data.raw[entity_type][entity_name].hidden = true

        -- also remove next upgrade
        data.raw[entity_type][entity_name].next_upgrade = nil
    end
end


local items_to_hide = {
    "kr-fusion-reactor",
    "kr-electric-mining-drill-mk2",
    "kr-electric-mining-drill-mk3",
--    "beacon",
    "kr-coke",
    "kr-tritium",
    "iron-stick",
    "iron-gear-wheel",
    "kr-iron-beam",
    "kr-steel-beam",
    "kr-steel-gear-wheel",
    "kr-empty-dt-fuel-cell",
    "kr-dt-fuel-cell",
    "kr-biter-research-data",
    "kr-matter-research-data",
    "kr-space-research-data",
    "kr-singularity-tech-card",
}

-- hide items
for _, item in ipairs(items_to_hide) do
    if data.raw.item[item] then
        data.raw.item[item].hidden = true

        -- also remove the place result
        data.raw.item[item].place_result = nil
    end
end

local recipe_to_hide = {
    "kr-iron-beam",
    "kr-steel-beam",
    "kr-steel-gear-wheel",
    "dirty-water-filtration-1",
    "kr-filter-iron-ore-from-dirty-water",
    "kr-filter-copper-ore-from-dirty-water",
    "kr-filter-rare-metal-ore-from-dirty-water",
    "dirty-water-filtration-2",
    "dirty-water-filtration-3",
    "kr-basic-tech-card",
    "kr-matter-to-copper-ore",
    "kr-matter-to-iron-ore",
    "kr-copper-ore-to-matter",
    "kr-iron-ore-to-matter",
    "glass",

    -- advanced assembler stuff
    "kr-s-c-iron-beam",
    "kr-s-c-iron-beam-enriched",
    "kr-s-c-steel-beam",
    "kr-s-c-steel-gear-wheel",
    "kr-s-c-imersium-beam",
    "kr-s-c-imersium-gear-wheel",
    "kr-s-c-copper-cable-enriched",
    "kr-s-c-copper-cable",
    "kr-s-c-electronic-components",
    "kr-s-c-iron-stick",
    "kr-s-c-iron-stick-enriched",
    "kr-s-c-iron-gear-wheel",
    "kr-s-c-iron-gear-wheel-enriched",
}

local hard_recipe_overwrite = {
    ["automation-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 2},
        {type = "item", name = "ei-iron-mechanical-parts", amount = 1},
    },
    ["logistic-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 2},
        {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
    },
    ["chemical-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 4},
        {type = "item", name = "electronic-circuit", amount = 3},
        {type = "item", name = "kr-automation-core", amount = 1},
    },
    ["utility-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 6},
        {type = "item", name = "ei-electronic-parts", amount = 3},
        {type = "item", name = "decider-combinator", amount = 2},
    },
    ["production-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 6},
        {type = "item", name = "ei-space-data", amount = 2},
        {type = "item", name = "ei-simulation-data", amount = 20},
    },
    --[[
    ["space-science-pack"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 10},
        {type = "item", name = "ei-space-data", amount = 4},
        {type = "item", name = "ei-moon-fish", amount = 1},
    },
    ]]
    ["kr-matter-tech-card"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 10},
        {type = "item", name = "ei-crushed-iron", amount = 1},
        {type = "item", name = "ei-crushed-copper", amount = 1},
        {type = "item", name = "ei-crushed-gold", amount = 1},
        {type = "item", name = "ei-crushed-sulfur", amount = 1},
        {type = "item", name = "ei-crushed-coal", amount = 1},
        {type = "item", name = "ei-sand", amount = 1},
        {type = "item", name = "ei-crushed-uranium", amount = 1},
        {type = "item", name = "ei-crushed-neodym", amount = 1},
        --{type = "item", name = "ei-fluorite", amount = 1},
        --{type = "item", name = "ei-lithium-crystal", amount = 1},
        {type = "item", name = "kr-imersite-crystal", amount = 1},
        {type = "item", name = "kr-rare-metals", amount = 1},
    },
    ["kr-advanced-tech-card"] = {
        {type = "item", name = "kr-blank-tech-card", amount = 10},
        {type = "item", name = "ei-superior-data", amount = 10},
        {type = "item", name = "ei-cavity", amount = 1},
    },
}

local recipe_overwrite = {
    -- machinery
    ["kr-inserter-parts"] = {
        {type = "item", name = "ei-iron-mechanical-parts", amount = 1},
        {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
    },
    ["kr-atmospheric-condenser"] = {
        {type = "item", name = "ei-lufter", amount = 4},
        {type = "item", name = "ei-advanced-motor", amount = 4},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 10},
    },
    ["kr-electrolysis-plant"] = {
        {type = "item", name = "chemical-plant", amount = 1},
        {type = "item", name = "ei-electronic-parts", amount = 2},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 10},
    },
    ["kr-research-server"] = {
        {type = "item", name = "lab", amount = 1},
        {type = "item", name = "advanced-circuit", amount = 6},
        {type = "item", name = "ei-energy-crystal", amount = 4},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 6},
    },
    ["kr-quantum-computer"] = {
        {type = "item", name = "kr-research-server", amount = 1},
        {type = "item", name = "processing-unit", amount = 10},
        {type = "item", name = "ei-high-energy-crystal", amount = 4},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 6},
    },
    ["kr-advanced-assembling-machine"] = {
        {type = "item", name = "ei-neo-assembler", amount = 2},
        {type = "item", name = "ei-advanced-motor", amount = 12},
        {type = "item", name = "ei-carbon-structure", amount = 10},
        {type = "item", name = "processing-unit", amount = 10},
        {type = "item", name = "kr-imersium-gear-wheel", amount = 6},
        {type = "item", name = "kr-imersium-beam", amount = 14},
    },
    ["kr-advanced-chemical-plant"] = {
        {type = "item", name = "ei-advanced-chem-plant", amount = 2},
        {type = "item", name = "ei-advanced-motor", amount = 12},
        {type = "item", name = "ei-carbon-structure", amount = 10},
        {type = "item", name = "processing-unit", amount = 10},
        {type = "item", name = "kr-imersium-gear-wheel", amount = 6},
        {type = "item", name = "kr-imersium-beam", amount = 14},
    },
    ["kr-advanced-furnace"] = {
        {type = "item", name = "electric-furnace", amount = 4},
        {type = "item", name = "ei-advanced-motor", amount = 12},
        {type = "item", name = "ei-carbon-structure", amount = 24},
        {type = "item", name = "processing-unit", amount = 2},
        {type = "item", name = "kr-imersium-gear-wheel", amount = 6},
        {type = "item", name = "kr-imersium-beam", amount = 14},
    },
    ["kr-crusher"] = {
        {type = "item", name = "ei-advanced-crusher", amount = 2},
        {type = "item", name = "ei-advanced-motor", amount = 12},
        {type = "item", name = "ei-carbon-structure", amount = 10},
        {type = "item", name = "processing-unit", amount = 10},
        {type = "item", name = "kr-imersium-gear-wheel", amount = 6},
        {type = "item", name = "kr-imersium-beam", amount = 14},
    },
    ["kr-filtration-plant"] = {
        {type = "item", name = "ei-advanced-motor", amount = 10},
        {type = "item", name = "storage-tank", amount = 2},
        {type = "item", name = "ei-purifier", amount = 2},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 8},
    },
    ["kr-advanced-solar-panel"] = {
        {type = "item", name = "ei-solar-panel-3", amount = 2},
        {type = "item", name = "ei-carbon-structure", amount = 6},
        {type = "item", name = "processing-unit", amount = 2},
        {type = "item", name = "kr-imersium-plate", amount = 4},
        {type = "item", name = "kr-imersite-crystal", amount = 12},
    },
    ["kr-singularity-lab"] = {
        {type = "item", name = "kr-advanced-lab", amount = 1},
        {type = "item", name = "ei-simulation-data", amount = 100},
        {type = "item", name = "ei-energy-crystal", amount = 24},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 8},
    },
    ["ei-big-lab"] = {
        {type = "item", name = "kr-singularity-lab", amount = 1},
        {type = "item", name = "ei-computing-unit", amount = 10},
        {type = "item", name = "ei-high-energy-crystal", amount = 20},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 80},
    },
    ["kr-gas-power-station"] = {
        {type = "item", name = "ei-fluid-boiler", amount = 1},
        {type = "item", name = "steam-engine", amount = 1},
        {type = "item", name = "advanced-circuit", amount = 6},
        {type = "item", name = "electric-engine-unit", amount = 20},
        {type = "item", name = "ei-copper-mechanical-parts", amount = 12},
    },
    ["kr-energy-storage"] = {
        {type = "item", name = "accumulator", amount = 4},
        {type = "item", name = "processing-unit", amount = 10},
        {type = "item", name = "kr-imersium-beam", amount = 12},
        {type = "item", name = "ei-magnet", amount = 2},
    },
    ["kr-small-roboport"] = {
        {type = "item", name = "roboport", amount = 1},
        {type = "item", name = "processing-unit", amount = 1},
        {type = "item", name = "kr-imersium-beam", amount = 2},
    },
    ["kr-large-roboport"] = {
        {type = "item", name = "kr-small-roboport", amount = 4},
        {type = "item", name = "ei-magnet", amount = 10},
        {type = "item", name = "kr-imersium-beam", amount = 12},
        {type = "item", name = "kr-imersium-gear-wheel", amount = 20},
    },
    ["kr-quarry-drill"] = {
        {type = "item", name = "ei-excavator", amount = 1},
        {type = "item", name = "processing-unit", amount = 4},
        {type = "item", name = "kr-rare-metals", amount = 20},
    },
    ["kr-singularity-beacon"] = {
        {type = "item", name = "ei-iron-beacon", amount = 1},
        {type = "item", name = "kr-energy-control-unit", amount = 4},
        {type = "item", name = "kr-imersium-beam", amount = 6},
    },
    ["kr-antimatter-reactor"] = {
        {type = "item", name = "ei-fusion-reactor", amount = 1},
        {type = "item", name = "ei-neutron-collector", amount = 4},
        {type = "item", name = "kr-energy-control-unit", amount = 50},
        {type = "item", name = "kr-ai-core", amount = 100},
        {type = "item", name = "ei-clean-plating", amount = 250},
        {type = "item", name = "kr-imersium-beam", amount = 500},
        {type = "item", name = "ei-carbon-structure", amount = 100},
    },
    ["kr-intergalactic-transceiver"] = {
        {type = "item", name = "ei-fusion-reactor", amount = 1},
        {type = "item", name = "kr-antimatter-reactor", amount = 1},
        {type = "item", name = "nuclear-reactor", amount = 1},
        {type = "item", name = "ei-high-temperature-reactor", amount = 1},
        {type = "item", name = "ei-high-tech-parts", amount = 100},
        {type = "item", name = "ei-clean-plating", amount = 200},
        {type = "item", name = "kr-imersium-beam", amount = 200},
        {type = "item", name = "ei-carbon-structure", amount = 200},
    },
    ["nuclear-reactor"] = {
        {type = "item", name = "ei-energy-crystal", amount = 100},
        {type = "item", name = "advanced-circuit", amount = 100},
        {type = "item", name = "concrete", amount = 200},
        {type = "item", name = "ei-lead-ingot", amount = 200},
        {type = "item", name = "steel-plate", amount = 200},
        {type = "item", name = "ei-fission-tech", amount = 100},
    },
    --armor and stuff
    ["imersite-solar-panel-equipment"] = {
        {type = "item", name = "ei-personal-solar-3", amount = 2},
        {type = "item", name = "kr-ai-core", amount = 20},
        {type = "item", name = "ei-odd-plating", amount = 4},
        {type = "item", name = "kr-imersite-crystal", amount = 10},
        {type = "item", name = "ei-magnet", amount = 6},
        {type = "fluid", name = "ei-nitric-acid", amount = 25},
    },
    ["nuclear-reactor-equipment"] = {
        {type = "item", name = "fission-reactor-equipment", amount = 1},
        {type = "item", name = "kr-rare-metals", amount = 30},
        {type = "item", name = "ei-simulation-data", amount = 20},
        {type = "item", name = "ei-fission-tech", amount = 20},
    },
    ["ei-personal-shield"] = {
        {type = "item", name = "kr-energy-shield-mk4-equipment", amount = 1},
        {type = "item", name = "ei-superior-data", amount = 20},
        {type = "item", name = "ei-high-tech-parts", amount = 10},
    },
    ["kr-power-armor-mk3"] = {
        {type = "item", name = "power-armor-mk2", amount = 1},
        {type = "item", name = "kr-imersium-plate", amount = 20},
        {type = "item", name = "ei-carbon-structure", amount = 24},
        {type = "item", name = "processing-unit", amount = 10},
    },
    ["kr-power-armor-mk4"] = {
        {type = "item", name = "kr-power-armor-mk3", amount = 1},
        {type = "item", name = "kr-energy-control-unit", amount = 20},
        {type = "item", name = "ei-eu-magnet", amount = 14},
        {type = "item", name = "ei-clean-plating", amount = 10},
    },
    --[[
    ["ei-bio-armor"] = {
        {type = "item", name = "kr-power-armor-mk3", amount = 1},
        {type = "item", name = "ei-high-tech-parts", amount = 20},
        {type = "item", name = "ei-superior-data", amount = 40},
        {type = "item", name = "ei-bio-matter", amount = 100},
    },
    ]]
    ["kr-railgun-turret"] = {
        {type = "item", name = "ei-cannon-turret", amount = 1},
        {type = "item", name = "kr-rare-metals", amount = 20},
        {type = "item", name = "steel-plate", amount = 10},
        {type = "item", name = "ei-electronic-parts", amount = 20},
    },
    ["kr-rocket-turret"] = {
        {type = "item", name = "ei-cannon-turret", amount = 1},
        {type = "item", name = "kr-rare-metals", amount = 20},
        {type = "item", name = "steel-plate", amount = 10},
        {type = "item", name = "kr-heavy-rocket-launcher", amount = 6},
        {type = "item", name = "processing-unit", amount = 20},
    },
    ["kr-nuclear-locomotive"] = {
        {type = "item", name = "locomotive", amount = 1},
        {type = "item", name = "kr-rare-metals", amount = 80},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
        {type = "item", name = "ei-advanced-motor", amount = 20},
        {type = "item", name = "ei-electronic-parts", amount = 20},
    },

    -- intermediates
    ["electric-engine-unit"] = {
        {type = "item", name = "kr-automation-core", amount = 1},
        {type = "item", name = "engine-unit", amount = 1},
        {type = "item", name = "copper-cable", amount = 4},
    },
    ["ei-high-tech-parts"] = {
        {type = "item", name = "ei-eu-magnet", amount = 1},
        {type = "item", name = "ei-eu-circuit", amount = 1},
        {type = "item", name = "ei-plasma-cube", amount = 1},
        {type = "item", name = "ei-exotic-matter-up", amount = 1},
        {type = "item", name = "kr-matter-cube", amount = 1},
        {type = "item", name = "kr-charged-matter-stabilizer", amount = 1},
    },
    ["kr-energy-control-unit"] = {
        {type = "item", name = "kr-lithium-sulfur-battery", amount = 3},
        {type = "item", name = "ei-electronic-parts", amount = 4},
        {type = "item", name = "ei-carbon-structure", amount = 3},
        {type = "item", name = "kr-imersite-crystal", amount = 2},
        {type = "item", name = "ei-superior-data", amount = 1},
    },
    ["rocket-fuel"] = {
        {type = "item", name = "iron-plate", amount = 1},
        {type = "item", name = "solid-fuel", amount = 1},
        {type = "fluid", name = "ei-liquid-oxygen", amount = 25},
        {type = "fluid", name = "ei-kerosene", amount = 15},
    },
    ["kr-charged-antimatter-fuel-cell"] = {
        {type = "item", name = "kr-empty-antimatter-fuel-cell", amount = 1},
        {type = "item", name = "kr-lithium", amount = 10},
        {type = "item", name = "ei-charged-neutron-container", amount = 1},
        {type = "item", name = "ei-antimatter-cube", amount = 1},
    },

    ["kr-inserter-parts"] = {
        {type = "item", name = "ei-iron-mechanical-parts", amount = 1},
        {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
    },
    ["inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 1},
        {type = "item", name = "kr-automation-core", amount = 1},
        {type = "item", name = "electric-engine-unit", amount = 1},
    },
    ["long-handed-inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 1},
        {type = "item", name = "kr-automation-core", amount = 1},
        {type = "item", name = "electric-engine-unit", amount = 1},
        {type = "item", name = "ei-iron-mechanical-parts", amount = 2},
    },
    ["fast-inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 1},
        {type = "item", name = "inserter", amount = 1},
        {type = "item", name = "electronic-circuit", amount = 2},
    },
    ["fast-inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 1},
        {type = "item", name = "inserter", amount = 1},
        {type = "item", name = "electronic-circuit", amount = 6},
    },
    ["bulk-inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 2},
        {type = "item", name = "fast-inserter", amount = 1},
        {type = "item", name = "ei-electronic-parts", amount = 1},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 4},
    },
    ["bulk-inserter"] = {
        {type = "item", name = "kr-inserter-parts", amount = 2},
        {type = "item", name = "fast-inserter", amount = 1},
        {type = "item", name = "ei-electronic-parts", amount = 2},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 4},
    },
    -- belts and stuff
    ["kr-advanced-transport-belt"] = {
        {type="item", name="express-transport-belt", amount=1},
        {type="item", name="ei-steel-mechanical-parts", amount=5},
        {type="item", name="ei-condensed-cryodust", amount=1},
        {type="fluid", name="lubricant", amount=15},
    },
    ["kr-advanced-underground-belt"] = {
        {type="item", name="express-underground-belt", amount=2},
        {type="item", name="ei-steel-mechanical-parts", amount=5},
        {type="item", name="ei-condensed-cryodust", amount=1},
        {type="fluid", name="lubricant", amount=35},
    },
    ["kr-advanced-splitter"] = {
        {type="item", name="express-splitter", amount=1},
        {type="item", name="ei-steel-mechanical-parts", amount=5},
        {type="item", name="ei-condensed-cryodust", amount=1},
        {type="fluid", name="lubricant", amount=55},
    },
    ["kr-advanced-laoder"] = {
        {type="item", name="kr-express-loader", amount=2},
        {type="item", name="ei-steel-mechanical-parts", amount=5},
        {type="item", name="ei-condensed-cryodust", amount=1},
        {type="fluid", name="lubricant", amount=55},
    },

    ["ei-neo-belt"] = {
        {type = "fluid", name = "ei-liquid-nitrogen", amount = 20},
        {type = "item", name = "kr-superior-transport-belt", amount = 2},
        {type = "item", name = "ei-carbon-structure", amount = 2},
        {type = "item", name = "ei-enriched-cryodust", amount = 1},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 10},
    },
    ["ei-neo-splitter"] = {
        {type = "fluid", name = "ei-liquid-nitrogen", amount = 20},
        {type = "item", name = "kr-superior-splitter", amount = 2},
        {type = "item", name = "ei-carbon-structure", amount = 4},
        {type = "item", name = "ei-enriched-cryodust", amount = 2},
        {type = "item", name = "processing-unit", amount = 5},
    },
    ["ei-neo-underground-belt"] = {
        {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
        {type = "item", name = "kr-superior-underground-belt", amount = 4},
        {type = "item", name = "ei-carbon-structure", amount = 10},
        {type = "item", name = "ei-enriched-cryodust", amount = 2},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 30},
    },

    -- science packs and their tech cards
    ["kr-blank-tech-card"] = {
        {type = "item", name = "stone", amount = 1},
        {type = "item", name = "iron-plate", amount = 2},
    },
    ["ei-dark-age-tech"] = {
        {type = "item", name = "kr-inserter-parts", amount = 1},
        {type = "item", name = "automation-science-pack", amount = 1},
    },
    ["ei-steam-age-tech"] = {
        {type = "item", name = "ei-steam-engine", amount = 1},
        {type = "item", name = "logistic-science-pack", amount = 1},
    },
    ["ei-electricity-age-tech"] = {
        {type = "item", name = "engine-unit", amount = 2},
        {type = "item", name = "ei-steel-mechanical-parts", amount = 3},
        {type = "item", name = "chemical-science-pack", amount = 5},
    },
    ["ei-computer-age-tech"] = {
        {type = "fluid", name = "lubricant", amount = 25},
        {type = "item", name = "ei-energy-crystal", amount = 3},
        {type = "item", name = "utility-science-pack", amount = 5},
    },
    ["ei-alien-computer-age-tech"] = {
        {type = "fluid", name = "ei-cryoflux", amount = 100},
        {type = "item", name = "ei-alien-resin", amount = 10},
        {type = "item", name = "ei-alien-seed", amount = 1},
        {type = "item", name = "utility-science-pack", amount = 5},
    },
    ["ei-advanced-computer-age-tech"] = {
        {type = "fluid", name = "ei-ammonia-gas", amount = 100},
        {type = "item", name = "ei-simulation-data", amount = 12},
        {type = "item", name = "kr-rare-metals", amount = 4},
        {type = "item", name = "utility-science-pack", amount = 5},
    },
    ["ei-quantum-age-tech"] = {
        {type = "item", name = "ei-high-energy-crystal", amount = 2},
        {type = "item", name = "ei-computing-unit", amount = 5},
        {type = "item", name = "production-science-pack", amount = 5},
    },
    ["ei-fusion-quantum-age-tech"] = {
        {type = "item", name = "ei-charged-neutron-container", amount = 1},
        {type = "item", name = "ei-fusion-data", amount = 5},
        {type = "item", name = "production-science-pack", amount = 5},
    },
    --[[
    ["ei-space-quantum-age-tech"] = {
        {type = "item", name = "ei-advanced-rocket-fuel", amount = 4},
        {type = "item", name = "space-science-pack", amount = 1},
    },
    ]]
    ["ei-exotic-age-tech"] = {
        {type = "item", name = "ei-high-tech-parts", amount = 2},
        {type = "item", name = "kr-advanced-tech-card", amount = 1},
    },
}

ei_lib.recipe_add("ei-simulation-data", "kr-blank-tech-card", 3)
ei_lib.recipe_add("ei-superior-data", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-plasma-data-deuterium", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-plasma-data-tritium", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-plasma-data-protium", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-magnet-data", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-fusion-data", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-fission-tech", "kr-blank-tech-card", 4)
ei_lib.recipe_add("ei-fission-tech-pt239", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-fission-tech-th232", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-fission-tech-u233", "kr-blank-tech-card", 10)
ei_lib.recipe_add("ei-fission-tech-u235", "kr-blank-tech-card", 10)

-- machinery and other
-------------------------------------------------------------------------------
ei_lib.recipe_add("ei-quantum-computer", "kr-quantum-computer", 1)
ei_lib.add_unlock_recipe("ei-electricity-power", "kr-wind-turbine")

data.raw["solar-panel"]["kr-advanced-solar-panel"].production = "1280kW"


-- ressouces
-------------------------------------------------------------------------------
data.raw.recipe["iron-plate"].icon = nil
data.raw.recipe["iron-plate"].icons = nil
data.raw.recipe["iron-plate"].icon_size = nil

data.raw.recipe["copper-plate"].icon = nil
data.raw.recipe["copper-plate"].icons = nil
data.raw.recipe["copper-plate"].icon_size = nil

data.raw.recipe["kr-rare-metals"].enabled = false
ei_lib.add_unlock_recipe("kr-fluids-chemistry", "kr-rare-metals")


k2so_upsert_prototypes({
    {
        name = "kr-enriched-iron",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-pure-iron", amount = 9},
            {type = "fluid", name = "sulfuric-acid", amount = 3},
        },
        results = {
            {type = "item", name = "kr-enriched-iron", amount = 9},
            {type = "fluid", name = "ei-dirty-water", amount = 3},
        },
        main_product = "kr-enriched-iron",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "kr-enriched-copper",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-pure-copper", amount = 9},
            {type = "fluid", name = "sulfuric-acid", amount = 3},
        },
        results = {
            {type = "item", name = "kr-enriched-copper", amount = 9},
            {type = "fluid", name = "ei-dirty-water", amount = 3},
        },
        main_product = "kr-enriched-copper",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "kr-enriched-rare-metals",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "kr-rare-metal-ore", amount = 9},
            {type = "fluid", name = "kr-hydrogen-chloride", amount = 10},
        },
        results = {
            {type = "item", name = "kr-enriched-rare-metals", amount = 9},
            {type = "fluid", name = "kr-chlorine", amount = 5},
        },
        main_product = "kr-enriched-rare-metals",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "kr-enriched-iron-plate",
        type = "recipe",
        category = "smelting",
        energy_required = 16,
        ingredients = {
            {type = "item", name = "kr-enriched-iron", amount = 10},
        },
        results = {
            {type = "item", name = "iron-plate", amount = 20},
        },
        main_product = "iron-plate",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "kr-enriched-copper-plate",
        type = "recipe",
        category = "smelting",
        energy_required = 16,
        ingredients = {
            {type = "item", name = "kr-enriched-copper", amount = 10},
        },
        results = {
            {type = "item", name = "copper-plate", amount = 20},
        },
        main_product = "copper-plate",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "kr-quartz",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "ei-sand", amount = 10},
            {type = "fluid", name = "water", amount = 10},
        },
        results = {
            {type = "item", name = "kr-quartz", amount = 6},
        },
        main_product = "kr-quartz",
        subgroup = "ei-refining-purified",
        order = "b-a",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-bio-matter-biomass",
        type = "recipe",
        category = "kr-bioprocessing",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-bio-matter", amount = 1},
            {type = "item", name = "kr-fertilizer", amount = 1},
            {type = "item", name = "kr-biomass", amount = 10},
            {type = "item", name = "ei-cryodust", amount = 4},
            {type = "fluid", name = "kr-chlorine", amount = 10},
        },
        results = {
            {type = "item", name = "ei-bio-matter", amount = 2},
            {type = "item", name = "ei-cryodust", amount = 1, probability = 0.5},
        },
        main_product = "ei-bio-matter",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "imersium-beam-metalworks",
        type = "recipe",
        category = "ei-metalworks",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "kr-imersium-plate", amount = 2},
            {type = "item", name = "steel-plate", amount = 1},
        },
        results = {
            {type = "item", name = "kr-imersium-beam", amount = 1},
        },
        main_product = "kr-imersium-beam",
        hide_from_player_crafting = true,
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "imersium-gear-wheel-metalworks",
        type = "recipe",
        category = "ei-metalworks",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "kr-imersium-plate", amount = 4},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 4},
        },
        results = {
            {type = "item", name = "kr-imersium-gear-wheel", amount = 4},
        },
        main_product = "kr-imersium-gear-wheel",
        hide_from_player_crafting = true,
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-water-from-atmosphere",
        type = "recipe",
        category = "ei-atmosphere-condensation",
        energy_required = 120,
        ingredients = {},
        results = {
            {type = "fluid", name = "water", amount = 25},
        },
        main_product = "water",
        subgroup = "fluid-recipes",
        order = "a",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-antimatter-cube",
        type = "item",
        icon = ei_graphics_item_path.."antimatter-cube.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "r",
        stack_size = 1
    },
    {
        name = "ei-antimatter-cube",
        type = "recipe",
        category = "ei-accelerator",
        energy_required = 100, -- 100s at 100MW = 10GJ
        ingredients = {
            {type = "item", name = "kr-matter-cube", amount = 1},
            {type = "item", name = "kr-ai-core", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 10},
            {type = "item", name = "ei-eu-magnet", amount = 1},
        },
        results = {
            {type = "item", name = "ei-antimatter-cube", amount = 1, probability = 0.5},
            {type = "item", name = "kr-matter-cube", amount = 1, probability = 0.5},
            {type = "item", name = "kr-ai-core", amount = 1, probability = 0.5},
            {type = "item", name = "ei-eu-magnet", amount = 1, probability = 0.5},
        },
        main_product = "ei-antimatter-cube",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-antimatter-cube",
        type = "technology",
        icon = ei_graphics_tech_path.."antimatter.png",
        icon_size = 128,
        prerequisites = {"ei-accelerator"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-antimatter-cube"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["four-quantum-age"],
            time = 20
        },
        age = "four-quantum-age",
    },
})

-- inserters and belts
-------------------------------------------------------------------------------
ei_lib.recipe_add("ei-steam-inserter", "kr-inserter-parts", 1)
ei_lib.recipe_add("ei-steam-long-inserter", "kr-inserter-parts", 1)
ei_lib.recipe_add("ei-small-inserter-normal", "kr-inserter-parts", 4)
ei_lib.recipe_add("ei-big-inserter-normal", "kr-inserter-parts", 4)
ei_lib.remove_unlock_recipe("logistics", "inserter")
ei_lib.remove_unlock_recipe("logistics", "long-handed-inserter")
ei_lib.remove_unlock_recipe("logistics", "kr-loader")
ei_lib.add_unlock_recipe("fast-inserter", "kr-loader")

-- does not work above, why?
data.raw["item"]["ei-neo-underground-belt"].subgroup = "underground-belt"
data.raw["item"]["ei-neo-splitter"].subgroup = "splitter-belt"

-- science
-------------------------------------------------------------------------------
--data.raw.item["automation-science-pack"].flags = nil
--data.raw.item["space-science-pack"].flags = nil
--data.raw.recipe["automation-science-pack"].enabled = true
data.raw.recipe["kr-blank-tech-card"].enabled = true

k2so_upsert_prototypes({
    {
        name = "ei-blank-tech-card",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type="item", name="ei-ceramic", amount=3},
            {type="item", name="iron-plate", amount=4},
            {type="item", name="ei-glass", amount=2},
        },
        results = {{type="item", name="kr-blank-tech-card", amount=14}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-blank-tech-card-electronic-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        ingredients = {
            {type="item", name="ei-ceramic", amount=6},
            {type="item", name="iron-plate", amount=6},
            {type="item", name="ei-electronic-parts", amount=2},
        },
        results = {{type="item", name="kr-blank-tech-card", amount=32}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-matter-quantum-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type="item", name="ei-clean-plating", amount=2},
            {type="item", name="kr-energy-control-unit", amount=1},
            {type="item", name="kr-matter-tech-card", amount=1},
        },
        results = {{type="item", name="ei-matter-quantum-age-tech", amount=12}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-imersite-quantum-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type="item", name="kr-imersium-plate", amount=2},
            {type="item", name="ei-carbon-structure", amount=1},
            {type="item", name="production-science-pack", amount=5},
        },
        results = {{type="item", name="ei-imersite-quantum-age-tech", amount=10}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        type = "recipe",
        name = "express-transport-belt",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type = "item", name = "fast-transport-belt", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 5},
            {type = "item", name = "kr-rare-metals", amount = 1},
        },
        results = {{type="item", name="express-transport-belt", amount=1}},
        enabled = false,
    },
    {
        type = "recipe",
        name = "kr-wind-turbine",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "electric-engine-unit", amount = 1},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 3},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 3},
        },
        results = {{type="item", name="kr-wind-turbine", amount=1}},
        enabled = false,
    },
    {
        type = "recipe",
        name = "kr-imersite-powder",
        category = "ei-crushing",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "kr-imersite", amount = 6},
        },
        results = {
            {type = "item", name = "ei-sand", amount = 2},
            {type = "item", name = "kr-imersite-powder", amount = 4},
        },
        main_product = "kr-imersite-powder",
        enabled = false,
    },
    
})

ei_lib.add_unlock_recipe("electronics", "ei-blank-tech-card")
ei_lib.add_unlock_recipe("ei-electronic-parts", "ei-blank-tech-card-electronic-parts")
ei_lib.add_unlock_recipe("ei-steam-age", "logistic-science-pack")
ei_lib.add_unlock_recipe("ei-electricity-age", "chemical-science-pack")
ei_lib.add_unlock_recipe("kr-research-server", "utility-science-pack")
ei_lib.add_unlock_recipe("kr-quantum-computer", "production-science-pack")
ei_lib.add_unlock_recipe("ei-moon-exploration", "space-science-pack")
ei_lib.add_unlock_recipe("kr-imersium-processing", "ei-imersite-quantum-age-tech")
ei_lib.add_unlock_recipe("kr-energy-control-unit", "ei-matter-quantum-age-tech")
ei_lib.add_unlock_recipe("kr-energy-control-unit", "kr-matter-tech-card")
ei_lib.add_unlock_recipe("ei-exotic-age", "kr-advanced-tech-card")

ei_lib.add_prerequisite("ei-moon-exploration", "ei-quantum-computer")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-exotic-age")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-fusion-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "kr-antimatter-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-high-temperature-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "nuclear-power")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-superior-induction-matrix")

ei_lib.set_prerequisites("ei-black-hole", {"ei-black-hole-exploration", "kr-intergalactic-transceiver"}) 

-- intermediates
-------------------------------------------------------------------------------
data.raw["recipe"]["iron-plate"].results = {
    {type = "item", name = "iron-plate", amount = 1}
}
data.raw["recipe"]["copper-plate"].results = {
    {type = "item", name = "copper-plate", amount = 1}
}

ei_lib.remove_unlock_recipe("advanced-circuit", "electronic-components")
ei_lib.recipe_add("ei-crystal-solution", "kr-chlorine", 20, true)
ei_lib.recipe_add("ei-advanced-semiconductor", "kr-chlorine", 5, true)
ei_lib.recipe_add("ei-advanced-semiconductor-monosilicon", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-monosilicon", "kr-chlorine", 2, true)
ei_lib.recipe_add("ei-nitric-acid-uranium-235", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-uranium-233", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-plutonium-239", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-thorium-232", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-bio-matter", "kr-chlorine", 2, true)

ei_lib.recipe_add("kr-empty-antimatter-fuel-cell", "ei-empty-cryo-container", 1, false)
ei_lib.recipe_add("kr-empty-antimatter-fuel-cell", "ei-clean-plating", 10, false)

ei_lib.recipe_add("heat-pipe", "kr-quartz", 4, false)
ei_lib.recipe_add("processing-unit", "kr-rare-metals", 6, false)

ei_lib.recipe_add("advanced-circuit", "kr-silicon", 1)
data.raw["recipe"]["kr-quartz"].ingredients = {
    {type = "item", name = "ei-sand", amount = 2},
    {type = "fluid", name = "water", amount = 20},
}
ei_lib.recipe_add("ei-semiconductor", "kr-silicon", 2)
ei_lib.recipe_add("ei-advanced-base-semiconductor", "kr-silicon", 4)
ei_lib.recipe_add("ei-silicon", "kr-silicon", 1)
ei_lib.recipe_add("ei-lithium-crystal", "kr-lithium", 1)
ei_lib.recipe_add("ei-neutron-collector", "kr-lithium", 15)
ei_lib.recipe_add("ei-fusion-reactor", "kr-lithium", 100)
ei_lib.recipe_add("kr-lithium-sulfur-battery", "battery", 1)
ei_lib.recipe_add("ei-fusion-data", "kr-lithium", 2)

data.raw["recipe"]["kr-ai-core"].ingredients = {
    {type="item", name="processing-unit", amount=1}, {type="item", name="kr-imersite-crystal", amount=3}, {type="item", name="ei-computing-unit", amount=1}, 
}
data.raw["recipe"]["kr-ai-core"].results = {{type="item", name="kr-ai-core", amount=10}}
ei_lib.recipe_add("ei-superior-data", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-tritium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-deuterium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-protium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-magnet-data", "kr-ai-core", 1)
ei_lib.recipe_add("ei-fusion-data", "kr-ai-core", 1)

ei_lib.recipe_add("ei-odd-plating", "kr-imersite-crystal", 1)
ei_lib.recipe_add("kr-imersium-plate", "ei-neodym-ingot", 2)

ei_lib.recipe_add("ei-energy-crystal-growing", "kr-quartz", 1)

ei_lib.add_unlock_recipe("kr-bio-processing", "ei-bio-matter-biomass")
ei_lib.add_unlock_recipe("kr-imersium-processing", "imersium-beam-metalworks")
ei_lib.add_unlock_recipe("kr-imersium-processing", "imersium-gear-wheel-metalworks")

ei_lib.recipe_add("kr-imersium-beam", "steel-plate", 1)
ei_lib.recipe_add("kr-imersium-gear-wheel", "ei-steel-mechanical-parts", 4)

data.raw.technology["kr-automation"].effects = {
    { type = "unlock-recipe", recipe = "kr-advanced-assembling-machine" },
}

-- chemistry changes
-------------------------------------------------------------------------------
ei_lib.add_unlock_recipe("kr-fluids-chemistry", "kr-water-separation")
ei_lib.remove_unlock_recipe("kr-advanced-chemistry", "kr-water-separation")
ei_lib.remove_unlock_recipe("kr-advanced-chemistry", "ammonia")
ei_lib.add_prerequisite("kr-advanced-chemistry", "ei-nitric-acid")

data.raw.technology["kr-atmosphere-condensation"].effects = {
    { type = "unlock-recipe", recipe = "kr-atmospheric-condenser" },
    { type = "unlock-recipe", recipe = "ei-water-from-atmosphere" },
}

ei_lib.add_unlock_recipe("ei-dirty-water-production", "kr-filtration-plant")
ei_lib.add_unlock_recipe("oil-processing", "chemical-plant")
ei_lib.remove_unlock_recipe("kr-fluids-chemistry", "kr-filtration-plant")
ei_lib.remove_unlock_recipe("kr-fluids-chemistry", "chemical-plant")

-- fuel and vehicles
-------------------------------------------------------------------------------
ei_lib.modify_data_raw("locomotive", "ei-steam-advanced-locomotive", {
    force_insert = true,
    energy_source = {
        fuel_categories = {
            "chemical",
            "kr-vehicle-fuel"
        }
    }
})

ei_lib.modify_data_raw("locomotive", "locomotive", {
    force_insert = true,
    energy_source = {
        fuel_categories = {
            "ei-diesel-fuel",
            "ei-rocket-fuel"
        }
    }
})

ei_lib.modify_data_raw("locomotive", "kr-nuclear-locomotive", {
    force_insert = true,
    energy_source = {
        fuel_categories = {
            "ei-nuclear-fuel",
            "ei-fusion-fuel"
        }
    }
})

--[[
for _, spider in pairs(data.raw["spider-vehicle"]) do
    spider.energy_source = {
        type = "burner",
        fuel_categories = {"chemical", "ei-nuclear-fuel","ei-nuclear-fuel-cell", "ei-fusion-fuel"},
        effectivity = 1,
        fuel_inventory_size = 3,
        burnt_inventory_size = 3,
    }
    spider.movement_energy_consumption = "1.0MW"
end
]]

--[[
-- nuclear and steam reset
-------------------------------------------------------------------------------
data.raw["reactor"]["nuclear-reactor"].energy_source.fuel_categories = {"ei-nuclear-fuel"}
data.raw["reactor"]["nuclear-reactor"].energy_source.effectivity = 2
if ei_lib.config("nuclear-reactor-remove-bonus") then
    data.raw["reactor"]["nuclear-reactor"].neighbour_bonus = 0
end
data.raw["reactor"]["nuclear-reactor"].consumption = ei_lib.config("nuclear-reactor-energy-output")

-- heat exchanger
-- 10 MW in, 103w/s in, 15dec min, 500dec steam out so 500dec min heat, out 103steam at 500dec / s

-- steam
-- min temp 15 - max 1000, 200 J/K

-- steam turbine
-- 900kw at 165dec steam with 30/s

-- boiler: 165dec steam out, with 60/s at 1.8MW
-- fluid boiler: same with fluid

data.raw["boiler"]["ei-fluid-boiler"].energy_consumption = "1.5MW"

-- nuclear stuff
-- steam = 200J/K
-- > 500dec steam = 200J * 500 = 100.000J = 0,1MJ
-- 10k steam at 500dec = 1GJ

-- 1000dec steam = 0,2MJ
-- 500dec steam = 0,1MJ
-- U235 = 25GJ -> 250k steam
-- U233 = 15GJ -> 150k steam
-- Pu239 = 30GJ -> 300k steam
-- Th232 = 10GJ -> 100k steam

-- + 50k each as HTR is more efficient
-- * 2 since effeciency is 200% for nuclear
local blank_htr = {
    name = "ei-htr-uranium-235",
    type = "recipe",
    category = "ei-high-temperature-reactor",
    energy_required = 120,
    ingredients = {
        {type = "item", name = "ei-uranium-235-fuel", amount = 1},
        {type = "fluid", name = "water", amount = 2*300000},
    },
    results = {
        {type = "item", name = "ei-used-uranium-235-fuel", amount = 1},
        {type = "fluid", name = "steam", amount = 2*300000, temperature = 500},
    },
    always_show_made_in = true,
    enabled = false,
    main_product = "steam",
    subgroup = "ei-htr-recipes",
    order = "a",
}

local function add_htr(fuel, fuel_value, steam_heat_capacity, steam_temp)

    local recipe = util.table.deepcopy(blank_htr)
    recipe.name = "ei-htr-" .. fuel
    -- time is 120s

    -- energy of 1 unit steam
    local steam_energy = steam_heat_capacity * (steam_temp - 15)
    local total_gained_energy = fuel_value * 2

    -- + 5GJ as htr is more efficient
    local total_steam = (total_gained_energy + 5000000000) / steam_energy

    recipe.ingredients[1].name = "ei-"..fuel.."-fuel"
    recipe.ingredients[2].amount = total_steam

    recipe.results[1].name = "ei-used-" .. fuel.."-fuel"
    recipe.results[2].amount = total_steam
    recipe.results[2].temperature = steam_temp

    k2so_upsert_prototype(recipe)

end

local htr_fuels = {
    ["uranium-235"] = 25*1000*1000*1000,
    ["uranium-233"] = 15*1000*1000*1000,
    ["plutonium-239"] = 30*1000*1000*1000,
    ["thorium-232"] = 10*1000*1000*1000,
}

for fuel, value in pairs(htr_fuels) do
    add_htr(fuel, value, 200, 415)
end

-- also increase energy usage of injector pylons to 10GW each
data.raw["assembling-machine"]["ei-energy-injector-pylon"].energy_usage = "10GW"

-- make pump not use energy
data.raw["pump"]["pump"].energy_source = {
    type = 'void'
}
-- data.raw["offshore-pump"]["offshore-pump"].energy_source = {
--     type = "void"
-- }
data.raw["item"]["satellite"].rocket_launch_product = nil
data.raw["capsule"]["raw-fish"].rocket_launch_product = nil
data.raw["capsule"]["raw-fish"].rocket_launch_products = nil
]]
-- starting machinery
-------------------------------------------------------------------------------
k2so_upsert_prototypes({
    {
        type = "recipe",
        name = "ei-basic-power-pole",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "wood", amount = 2},
            {type = "item", name = "copper-plate", amount = 3},
        },
        results = {{type="item", name="small-electric-pole", amount=1}},
        enabled = false,
    },
})

ei_lib.add_unlock_recipe("ei-dark-age", "ei-basic-power-pole")

-- remove non ei drops from crash site things
local swap_crash_items = {
    ["iron-plate"] = "iron-plate",
    ["copper-plate"] = "copper-plate",
    ["iron-gear-wheel"] = "ei-iron-mechanical-parts",
    ["copper-cable"] = "ei-copper-mechanical-parts",
} 

local crash_entites = {
    ["container"] = {
        "crash-site-spaceship",
        "crash-site-spaceship-wreck-big-1",
        "crash-site-spaceship-wreck-big-2",
        "crash-site-spaceship-wreck-medium-1",
        "crash-site-spaceship-wreck-medium-2",
        "crash-site-chest-1",
        "crash-site-chest-2",
        "kr-crash-site-chest-1",
        "kr-crash-site-chest-2",
    },
    ["simple-entity-with-owner"] = {
        "crash-site-spaceship-wreck-small-1",
        "crash-site-spaceship-wreck-small-2",
        "crash-site-spaceship-wreck-small-3",
        "crash-site-spaceship-wreck-small-4",
        "crash-site-spaceship-wreck-small-5",
        "crash-site-spaceship-wreck-small-6",
        "kr-mineable-wreckage",
    },
    ["assembling-machine"] = {
        "kr-crash-site-assembling-machine-1-repaired",
        "kr-crash-site-assembling-machine-2-repaired",
    },
    ["lab"] = {
        "kr-crash-site-lab-repaired",
    },
    ["electric-energy-interface"] = {
        "kr-crash-site-generator",
    },
}

for entity_type, entity_names in pairs(crash_entites) do

    for _, entity_name in pairs(entity_names) do

        if (not data.raw[entity_type]) or (not data.raw[entity_type][entity_name]) then
            log("Entity " .. entity_name .. " does not exist")
            goto continue
        end

        if (not data.raw[entity_type][entity_name].minable) or (not data.raw[entity_type][entity_name].minable.results) then
            goto continue
        end

        for i, minables in pairs(data.raw[entity_type][entity_name].minable.results) do

            --log(serpent.block(minables))
            if swap_crash_items[minables.name] then
                data.raw[entity_type][entity_name].minable.results[i].name = swap_crash_items[minables.name]
            end

        end

        ::continue::

    end

end

--log(serpent.block(data.raw["container"]["kr-crash-site-chest-2"]))

-- tech cost fixup
-------------------------------------------------------------------------------

-- loop over all techs and set their cost to 10 if they dont ignore tech multiplier
for tech_name, tech in pairs(data.raw.technology) do

    if tech.ignore_tech_cost_multiplier == true then
        goto continue
    end

    if not tech.unit then
        goto continue
    end

    if not tech.unit.count then
        goto continue
    end

    tech.unit.count = base_start_price

    ::continue::
end

-- fix ammos
-------------------------------------------------------------------------------

-- only if "kr-more-realistic-weapon" setting is enabled
-- if settings.startup["kr-more-realistic-weapon"].value then
--     data.raw["ammo"]["firearm-magazine"].ammo_type.category = "pistol-ammo"
--     data.raw["ammo"]["piercing-rounds-magazine"].ammo_type.category = "pistol-ammo"
-- end

-- productivity modules
-------------------------------------------------------------------------------
local recipes = {
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "utility-science-pack",
    "production-science-pack",
--    "space-science-pack",
    "kr-matter-tech-card",
    "kr-advanced-tech-card",
    "kr-blank-tech-card",
    "ei-blank-tech-card",
    "ei-blank-tech-card-electronic-parts",
    "utility-science-pack_alt",
    "production-science-pack_alt",
    "utility-science-pack_alt",
    "automation-science-pack_alt",
    "logistic-science-pack_alt",
    "chemical-science-pack_alt",
}

-- for i,v in pairs(recipes) do
--     table.insert(data.raw["module"]["productivity-module"].limitation, v)
--     table.insert(data.raw["module"]["productivity-module-2"].limitation, v)
--     table.insert(data.raw["module"]["productivity-module-3"].limitation, v)
-- end

for target, info in pairs(items_to_merge) do
    ei_lib.merge_item(target, info.item, info.use_icon)
end

for _, recipe in pairs(recipe_to_hide) do
    -- if not data raw log
    if not data.raw.recipe[recipe] then
        log("Recipe " .. recipe .. " does not exist")
        goto continue
    end

    data.raw.recipe[recipe].hidden = true
    -- also remove it from tech unlocks
    for tech, _ in pairs(data.raw.technology) do
        ei_lib.remove_unlock_recipe(tech, recipe)
    end

    ::continue::

end

for target, info in pairs(fluids_to_merge) do
    ei_lib.merge_fluid(target, info.fluid, info.use_icon)
end

for recipe, info in pairs(recipe_overwrite) do
    if not data.raw.recipe[recipe] then
        log("Recipe " .. recipe .. " does not exist")
        goto continue
    end

    data.raw.recipe[recipe].ingredients = info
    ::continue::
end

for recipe, info in pairs(hard_recipe_overwrite) do
    if not data.raw.recipe[recipe] then
        log("Recipe " .. recipe .. " does not exist")
        goto continue
    end

    ei_lib.recipe_hard_overwrite(recipe, info)
    ::continue::
end
ei_lib.remove_prerequisite("automation","advanced-circuit")
ei_lib.remove_prerequisite("advanced-circuit","automation")
ei_lib.remove_prerequisite("ei-computer-age-tech","automation-2")

::do_not_load::
