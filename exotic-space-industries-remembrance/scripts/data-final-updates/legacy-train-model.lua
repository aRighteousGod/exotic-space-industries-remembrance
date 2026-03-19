--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["AspctTrainPatch"] then
    return
end

local ei_lib = require("lib/lib")
--[[defaults
    reversing_power_modifier = 0.6,
    braking_force = 10,
    friction_force = 0.50,
    vertical_selection_shift = -0.5,
    air_resistance = 0.0075, -- this is a percentage of current speed that will be 
]]
local max_health_loco = 1200
local weight_loco = 1600
local weight_cargo = 600
local max_health_cargo = 720
local max_speed = 1.596
local max_speed_wagon = 2
local max_speed_sound_leveloff = 1.5 --pitch stops increasing
local max_speed_sound_levelon = 0.1 --starts
local loco_sound_minimum_speed = 0.09
local loco_sound_maximum_speed = 1.7
local max_power = "1.6MW"
local braking_force = 17.5
local braking_force_wagon = 10
local friction_force = 0.3
local air_resistance = 0.00375
local drive_over_tie_speed = 0.5
local drive_over_tie_distance = 60

function train_front_light()
    local train_front_light =
    {
        {
            type = "oriented",
            minimum_darkness = 0.3,
            picture =
            {
                filename = ei_graphics_3_path.."graphics/entities/nuclear_locomotive/nuclear_locomotive_light_cone_280x400.png",
                priority = "medium",
                scale = 1,
                width = 280,
                height = 400,
                draw_as_light = true,
                blend_mode = "multiplicative-with-alpha"
            },
            shift = {-0.85, -10.5},
            size = 1,
            intensity = 0.95
        },
        {
            type = "oriented",
            minimum_darkness = 0.3,
            picture =
            {
                filename = ei_graphics_3_path.."graphics/entities/nuclear_locomotive/nuclear_locomotive_light_cone_280x400.png",
                priority = "medium",
                scale = 1,
                width = 280,
                height = 400,
                draw_as_light = true,
                blend_mode = "multiplicative-with-alpha"
            },
            shift = {0.85, -10.5},
            size = 1,
            intensity = 0.95
        }
    }
return train_front_light
end

--[[
entity legacy-cargo-wagon, legacy-locomotive
recipes legacy-cargo-wagon, legacy-cargo-wagon-new, legacy-locomotive, legacy-locomotive-new, the -new ones convert legacy back to old
item legacy-cargo-wagon, legacy-locomotive
it loads all these in it's data-final-fixes
]]

--ei-nuclear-locomotive (item)
local enli = table.deepcopy(data.raw.item["legacy-locomotive"])
enli.name = "ei-nuclear-locomotive"
enli.localised_name = {"item-name.ei-nuclear-locomotive"}
enli.place_result = "ei-nuclear-locomotive"

--ei-nuclear-locomotive
local enl = table.deepcopy(data.raw.locomotive["legacy-locomotive"])
enl.name = "ei-nuclear-locomotive"
enl.localised_name = {"entity-name.ei-nuclear-locomotive"}
enl.minable.result = "ei-nuclear-locomotive"

enl.front_light= train_front_light()
enl.stop_trigger =
{
    -- left side
    {
        type = "create-trivial-smoke",
        repeat_count = 75,
        smoke_name = "smoke-train-stop",
        initial_height = 0,
        -- smoke goes to the left
        speed = {-0.03, 0},
        speed_multiplier = 0.75,
        speed_multiplier_deviation = 1.1,
        offset_deviation = {{-0.75, -2.7}, {-0.3, 2.7}}
    },
    -- right side
    {
        type = "create-trivial-smoke",
        repeat_count = 75,
        smoke_name = "smoke-train-stop",
        initial_height = 0,
        -- smoke goes to the right
        speed = {0.03, 0},
        speed_multiplier = 0.75,
        speed_multiplier_deviation = 1.1,
        offset_deviation = {{0.3, -2.7}, {0.75, 2.7}}
    },
    {
        type = "play-sound",
        sound =
        {
            {
                filename = ei_trains_sounds_path.."em_train_brakes.ogg",
                volume = 0.21
            },
        }
    },
}
--enl.drive_over_tie_trigger = drive_over_tie()
enl.drive_over_tie_trigger_minimal_speed = drive_over_tie_speed
enl.tie_distance = 60

enl.color = {
	r = 0.1411764705882353, g = 0.3725490196078431, b = 0.1764705882352941, a = 1 -- industrial nuclear green
}

enl.max_power = max_power --default 600
enl.max_speed = max_speed
enl.braking_force = braking_force
enl.friction_force = friction_force
enl.air_resistance = air_resistance
enl.health = max_health_loco
enl.weight = weight_loco
enl.resistances =
{
    {type = "fire", decrease = 30, percent = 75 },
    {type = "cold", decrease = 30, percent = 75 },
    {type = "physical", decrease = 30, percent = 60 },
    {type = "impact",decrease = 100,percent = 80},
    {type = "explosion",decrease = 30,percent = 60},
    {type = "acid",decrease = 12,percent = 50}
}
enl.front_light[1].color = {r = 0.17647, g = 0.6274509, b = 0.274509, a=1}
enl.front_light[1].intensity = 0.88
enl.front_light[2].color = {r = 0.17647, g = 0.6274509, b = 0.274509, a=1}
enl.front_light[2].intensity = 0.88
enl.energy_source.effectivity = 0.5
enl.energy_source.emissions_per_minute = { pollution = 1.25 }
enl.energy_source.fuel_categories = {"ei-nuclear-fuel-cell","ei-nuclear-fuel","ei-fusion-fuel"}
enl.energy_source.fuel_inventory_size = 1
enl.energy_source.burnt_inventory_size = 1

local nuclear_smoke = table.deepcopy(data.raw["trivial-smoke"]["train-smoke"])
nuclear_smoke.name = "ei-nuclear-train-smoke"
nuclear_smoke.start_scale = 1
nuclear_smoke.end_scale = 1.2
nuclear_smoke.duration = 1200
nuclear_smoke.fade_away_duration = 900
nuclear_smoke.color = {r = 0.17647, g = 0.6274509, b = 0.274509, a = 0.333} -- gamma core

enl.energy_source.smoke = {
	{
		name = "ei-nuclear-train-smoke",
		deviation = {0.08, 0.08},
		frequency = 15,
		position = {0, 1.4},
		starting_frame = 0,
		starting_frame_deviation = 60,
		height = 1.1,
		height_deviation = 0.08,
		starting_vertical_speed = 0.055,
		starting_vertical_speed_deviation = 0.05
	}
}

--ei-advanced-cargo-wagon (item)
local enacwi = table.deepcopy(data.raw.item["legacy-cargo-wagon"])
enacwi.name = "ei-advanced-cargo-wagon"
enacwi.localised_name = {"item-name.ei-advanced-cargo-wagon"}
enacwi.place_result = "ei-advanced-cargo-wagon"

--ei-advanced-cargo-wagon
local enacw = table.deepcopy(data.raw["cargo-wagon"]["legacy-cargo-wagon"])
enacw.name = "ei-advanced-cargo-wagon"
enacw.weight = weight_cargo

enacw.resistances =
{
    {type = "fire", decrease = 30, percent = 75 },
    {type = "cold", decrease = 30, percent = 75 },
    {type = "physical", decrease = 20, percent = 60 },
    {type = "impact",decrease = 50,percent = 80},
    {type = "explosion",decrease = 20,percent = 60},
    {type = "acid",decrease = 12,percent = 50}
}
enacw.health = max_health_cargo
enacw.max_speed = max_speed_wagon
enacw.braking_force = braking_force_wagon
enacw.minable.result = "ei-advanced-cargo-wagon"
enacw.localised_name = {"entity-name.ei-advanced-cargo-wagon"}

data:extend({
    nuclear_smoke,
    enl,
    enli,
    enacw,
    enacwi,
    {
        name = "ei-nuclear-locomotive",
        type = "recipe",
        category = "crafting",
        energy_required = 7,
        ingredients =
        {
            {type="item",name="locomotive",amount=1},
            {type="item",name="processing-unit", amount=7},
            {type="item",name="ei-energy-crystal", amount=16},
            {type="item",name="ei-carbon", amount=40},
            {type="item",name="ei-fission-tech", amount=100},
            {type="item",name="ei-advanced-motor", amount=8},
            {type="item",name="ei-lead-ingot", amount=30},
        },
        results = {{type="item", name="ei-nuclear-locomotive", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-nuclear-locomotive",
    },
    {
        name = "ei-advanced-cargo-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 7,
        ingredients =
        {
            {type="item",name="ei-carbon",amount=30},
            {type="item",name="ei-ceramic", amount=15},
            {type="item",name="plastic-bar", amount=12},
            {type="item",name="low-density-structure", amount=15},
            {type="item",name="cargo-wagon", amount=1},
        },
        results = {{type="item", name="ei-advanced-cargo-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-cargo-wagon",
    },
    {
        name = "ei-advanced-cargo-wagon",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/advanced-cargo-wagon.png",
        icon_size = 512,
        icon_mipmaps = 4,
        prerequisites = {"ei-advanced-computer-age-tech","railway","ei-carbon-manipulation"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-cargo-wagon"
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
        name = "ei-nuclear-locomotive",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/tech/nuclear-locomotive.png",
        icon_size = 512,
        icon_mipmaps = 4,
        prerequisites = {"ei-advanced-computer-age-tech","railway","ei-carbon-manipulation","nuclear-power"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-nuclear-locomotive"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    }, 
})

local techs_to_remove = {
    "legacy-locomotive",
    "legacy-locomotive-new",
    "legacy-cargo-wagon",
    "legacy-cargo-wagon-new"
}

for _,tech in pairs(techs_to_remove) do
    ei_lib.remove_unlock_recipe("railway",tech)
end
--ei_lib.add_unlock_recipe("railway","ei-advanced-cargo-wagon")
--ei_lib.add_unlock_recipe("railway","ei-nuclear-locomotive")

--remove the mod's items, recipes, entities
--[[
data.raw.item["legacy-locomotive"] = nil
data.raw.locomotive["legacy-locomotive"] = nil
data.raw.recipe["legacy-locomotive"] = nil
data.raw.recipe["legacy-locomotive-new"] = nil
data.raw.recipe["legacy-locomotive-recycling"] = nil
data.raw.item["legacy-cargo-wagon"] = nil
data.raw["cargo-wagon"]["legacy-cargo-wagon"] = nil
data.raw.recipe["legacy-cargo-wagon"] = nil
data.raw.recipe["legacy-cargo-wagon-recycling"] = nil
data.raw.recipe["legacy-cargo-wagon-new"] = nil

]]
--remove the mod's items, recipes, entities
data.raw.item["legacy-locomotive"].hidden = true
data.raw.locomotive["legacy-locomotive"].hidden = true
data.raw.recipe["legacy-locomotive"].hidden = true
data.raw.recipe["legacy-locomotive-new"].hidden = true
data.raw.item["legacy-cargo-wagon"].hidden = true
data.raw["cargo-wagon"]["legacy-cargo-wagon"].hidden = true
data.raw.recipe["legacy-cargo-wagon"].hidden = true
data.raw.recipe["legacy-cargo-wagon-new"].hidden = true
--data.raw.recipe["legacy-locomotive-recycling"].hidden = true
--data.raw.recipe["legacy-cargo-wagon-recycling"].hidden = true