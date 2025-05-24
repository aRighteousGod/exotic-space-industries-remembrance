local ei_lib = require("lib/lib")

--====================================================================================================
--ITEM ICON UPDATES
--====================================================================================================

local level_table = {
    ["1"] = {
        "ei-deep-drill",
        "assembling-machine-1",
        "ei-metalworks_1",
        "ei-copper-beacon",
        "solar-panel",
        "electric-mining-drill",
        "ei-crusher",
        "ei-heat-chemical-plant",
        "oil-refinery",
        "ei-destill-tower",
        "centrifuge",
        "pumpjack"
    },
    ["2"] = {
        "ei-advanced-deep-drill",
        "assembling-machine-2",
        "ei-metalworks_2",
        "ei-iron-beacon",
        "ei-solar-panel-2",
        "ei-advanced-electric-mining-drill",
        "ei-advanced-crusher",
        "chemical-plant",
        "ei-advanced-refinery",
        "ei-advanced-destill-tower",
        "ei-advanced-centrifuge",
        "ei-deep-pumpjack"
    },
    ["3"] = {
        "assembling-machine-3",
        "ei-metalworks_3",
        "ei-solar-panel-3",
        "ei-superior-electric-mining-drill",
        "ei-advanced-chem-plant",
    },
    ["4"] = {
        "ei-neo-assembler",
        "ei-metalworks_4",
    },
    -- ["filter"] = {
    --     "ei-small-inserter",
    --     "ei-big-inserter",
    --     "fast-inserter",
    --     "bulk-inserter",
    -- }   
}

for level, items in pairs(level_table) do
    for _, item in ipairs(items) do
        ei_lib.add_item_level(item, level)
    end
end

--====================================================================================================
--TECH ICON UPDATES
--====================================================================================================

-- add an icon to all techs that have the age property and thus count for age progression
-- we need to handle techs with icon or icons property here

local function add_tech_icon(tech)

    local icons = tech.icons or {
        {
            icon = tech.icon,
            icon_size = tech.icon_size,
        }
    }

    -- add overlay
    table.insert(icons, {
        icon = ei_graphics_other_path.."tech_overlay.png",
        icon_size = 64,
        shift = {-100, 100},
    })

    tech.icons = icons

    -- remove old icon if present
    tech.icon = nil

end


local function add_recipe_icon(tech)

    if not data.raw.technology[tech].effects then
        data.raw.technology[tech].effects = {}
    end

    -- check if this tech already has the effect
    for _, effect in ipairs(data.raw.technology[tech].effects) do
        if ((effect.type == "nothing") and effect.icon and (effect.icon == ei_graphics_other_path.."tech_overlay.png")) then
            return
        end
    end

    table.insert(data.raw.technology[tech].effects, {
        type = "nothing",
        effect_description = {"description.tech-counts-for-age-progression"},
        infer_icon = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."tech_overlay.png",
    })

end


for tech_name, tech in pairs(data.raw.technology) do

    if tech.age then
        -- add_tech_icon(tech)

        add_recipe_icon(tech_name)
    end

end
