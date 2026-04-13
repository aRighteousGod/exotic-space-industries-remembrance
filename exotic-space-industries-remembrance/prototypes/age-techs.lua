--==============================================================================
-- ESIR FILE MAP
-- owns: data-stage prototype aggregation for age-techs
-- loaded_by: exotic-space-industries-remembrance\data.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
-- store prototypes for age techs here to use them in control scripting

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--AGE TECHS
--====================================================================================================

local science = ei_data.science

data:extend({
    {
        name = "ei-temp",
        type = "technology",
        icon = ei_graphics_path.."graphics/128_placeholder.png",
        icon_size = 128,
        prerequisites = {

        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        enabled = false,
        visible_when_disabled = true,
    },
    {
        name = "ei-dark-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/dark-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {

        },
        effects = {
        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 10
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-steam-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/steam-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {
        "ei-burner-assembler","military","stone-wall","gun-turret","ei-mechanical-inserter"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "pipe"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-engine"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-age-tech"
            },
        },
        unit = {
            count = 200,
            ingredients = science["dark-age"],
            time = 20
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-electricity-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/electricity-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {
            "ei-steam-inserter","logistics","ei-steam-assembler","ei-tank-silo","ei-steam-advanced-train","rp-steam-logistics-chests","ei-fluid-boiler","ei-lube-destilation","electric-engine"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-electricity-age-tech"
            },
        },
        unit = {
            count = 300,
            ingredients = science["steam-age"],
            time = 30
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-computer-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/computer-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {
            "construction-robotics","logistic-robotics","ei-circuit-waver","oil-gathering","ei-grower","logistics-2","fluid-wagon","ei-castor","ei-benzol","ei-small-inserter","ei-combustion-turbine","ei-arc-furnace"
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-computer-age-tech"
            }
        },
        unit = {
            count = 400,
            ingredients = science["electricity-age"],
            time = 40
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-quantum-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/quantum-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-quantum-computer"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-quantum-age-tech"
            },
        },
        unit = {
            count = 600,
            ingredients = science["both-computer-age"],
            time = 50
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-exotic-age",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/exotic-age.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-cavity","ei-efficiency-module-6","ei-productivity-module-6","ei-speed-module-6","ei-plasma-turret","zeus-wrath-zeus-wrath","ei-induction-matrix-superior-converter","ei-induction-matrix-superior-coil"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-exotic-age-tech"
            }
        },
        unit = {
            count = 700,
            ingredients = science["both-quantum-age"],
            time = 60
        },
        enabled = true,
        visible_when_disabled = true,
    },
    -- dummy techs to have all of their age as prerequisites for storage of "age-marks"
    {
        name = "ei-steam-age-dummy",
        type = "technology",
        icon = ei_lib.empty_sprite(256),
        icon_size = 256,
        prerequisites = {},
        effects = {},
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        hidden = true,
    },
    {
        name = "ei-electricity-age-dummy",
        type = "technology",
        icon = ei_lib.empty_sprite(256),
        icon_size = 256,
        prerequisites = {},
        effects = {},
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        hidden = true,
    },
    {
        name = "ei-computer-age-dummy",
        type = "technology",
        icon = ei_lib.empty_sprite(256),
        icon_size = 256,
        prerequisites = {},
        effects = {},
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        hidden = true,
    },
    {
        name = "ei-quantum-age-dummy",
        type = "technology",
        icon = ei_lib.empty_sprite(256),
        icon_size = 256,
        prerequisites = {},
        effects = {},
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        hidden = true,
    },
    {
        name = "ei-exotic-age-dummy",
        type = "technology",
        icon = ei_lib.empty_sprite(256),
        icon_size = 256,
        prerequisites = {},
        effects = {},
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        hidden = true,
    },
})

-- if in dev mode unhidde dummy techs
if ei_mod.dev_mode == true then

    for _, tech in pairs(data.raw.technology) do
        if string.find(tech.name, "-dummy") then
            tech.hidden = false
        end

        if tech.name == "ei-dark-age" then
            tech.enabled = true
        end
        if tech.name == "ei-steam-age" then
            tech.enabled = true
        end
        if tech.name == "ei-electricity-age" then
            tech.enabled = true
        end
        if tech.name == "ei-computer-age" then
            tech.enabled = true
        end
        if tech.name == "ei-quantum-age" then
            tech.enabled = true
        end
        if tech.name == "ei-exotic-age" then
            tech.enabled = true
        end
    end
   
    if not ei_mod.show_dummy then
        for _, tech in pairs(data.raw.technology) do
            if string.find(tech.name, "-dummy") then
                tech.hidden = true
            end
        end
    end

end