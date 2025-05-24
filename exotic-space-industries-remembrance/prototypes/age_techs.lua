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
        icon = ei_graphics_tech_path.."dark-age.png",
        icon_size = 128,
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
        icon = ei_graphics_tech_path.."steam-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-dark-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 20
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-electricity-age",
        type = "technology",
        icon = ei_graphics_tech_path.."electricity-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-steam-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["steam-age"],
            time = 30
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-computer-age",
        type = "technology",
        icon = ei_graphics_tech_path.."computer-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-electricity-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["electricity-age"],
            time = 40
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-quantum-age",
        type = "technology",
        icon = ei_graphics_tech_path.."quantum-age.png",
        icon_size = 128,
        prerequisites = {},
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["both-computer-age"],
            time = 50
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-exotic-age",
        type = "technology",
        icon = ei_graphics_tech_path.."exotic-age.png",
        icon_size = 128,
        prerequisites = {},
        effects = {
            
        },
        unit = {
            count = 100,
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