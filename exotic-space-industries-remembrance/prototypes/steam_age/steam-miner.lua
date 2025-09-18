ei_data = require("lib/data")

--====================================================================================================
--STEAM MINER
--====================================================================================================

data:extend({
    {
        name = "ei-steam-miner",
        type = "item",
        icon = ei_graphics_item_path.."steam-miner.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "extraction-machine",
        order = "a[items]-a[burner-mining-drill]-a",
        place_result = "ei-steam-miner",
        stack_size = 50
    },
    {
        name = "ei-steam-miner",
        type = "recipe",
        category = "crafting",
        energy_required = 3,
        ingredients =
        {
            {type="item", name="burner-mining-drill", amount=1},
            {type="item", name="ei-steam-engine", amount=2},
            {type="item", name="ei-copper-mechanical-parts", amount=4},
            {type="item", name="ei-copper-beam", amount=4}
        },
        results = {{type="item", name="ei-steam-miner", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-miner",
    },

    {
        name = modprefix.."steam-quarry",
        type = "item",
        icon = ei_graphics_item_path.."steam-miner.png", --add overlay or something
        icon_size = 64,
        icon_mipmaps = 4,
        place_result = modprefix.."steam-quarry",
        stack_size = 20,
        subgroup = "extraction-machine",
        order = "a[items]-a[ei-steam-quarry]",
    },
    
    {
        name = modprefix.."steam-quarry",
        type = "recipe",
        enabled = false,
        ingredients = {
          {type = "item", name = "iron-plate", amount = 20},
          {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
          {type="item",name="ei-copper-beam",amount=10},
          {type = "item", name = "ei-steam-miner", amount = 10},
          {type = "item", name = "transport-belt", amount = 10},
        },
        results = {{type = "item", name = modprefix.."steam-quarry", amount = 1}},
        energy_required = 10,
    },
})

table.insert(data.raw["technology"]["ei-steam-power"].effects, {type = "unlock-recipe", recipe = "ei-steam-miner"})

local miner = util.table.deepcopy(data.raw["mining-drill"]["burner-mining-drill"])

miner.name = "ei-steam-miner"
miner.icon = ei_graphics_item_path.."steam-miner.png"
miner.icon_size = 64
miner.icon_mipmaps = 1
miner.minable.result = "ei-steam-miner"
miner.heating_energy = "50kW"
miner.mining_speed = 0.35
miner.module_slots = 2
miner.allowed_effects = {"consumption", "speed", "productivity", "pollution","quality"}
-- set energy source
miner.energy_source = {
    type = "fluid",
    emissions_per_minute={pollution=10},
    fluid_box = {   
        filter = "steam",
        volume = 200,
        pipe_covers = pipecoverspictures(),
        pipe_picture = ei_pipe_miner,
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {0.5, -0.5}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {-0.5, -0.5}},
        },
        production_type = "input-output",
    },
    effectivity = 0.7,
    scale_fluid_usage = true,
}
miner.fast_replaceable_group = "burner-mining-drill"
miner.radius_visualisation_picture = data.raw["mining-drill"]["electric-mining-drill"].radius_visualisation_picture
miner.resource_searching_radius = 2

data:extend({miner})

data.raw["mining-drill"]["burner-mining-drill"].next_upgrade = "ei-steam-miner"
data.raw["mining-drill"]["burner-mining-drill"].fast_replaceable_group = "burner-mining-drill"


local steam_quarry = table.deepcopy(data.raw["mining-drill"]["burner-mining-drill"])
steam_quarry.icon = ei_graphics_kirazy_path.."icon/electric-mining-drill.png"
steam_quarry.name = modprefix.."steam-quarry"
steam_quarry.minable = {mining_time = 1, result = modprefix.."steam-quarry"}
steam_quarry.resource_searching_radius = 15
steam_quarry.energy_usage = "1.05MW"
steam_quarry.heating_energy = "50kW"
steam_quarry.energy_source = {
    type = "fluid",
    emissions_per_minute={pollution=32},
    fluid_box = {   
        filter = "steam",
        volume = 200,
        pipe_covers = pipecoverspictures(),
        pipe_picture = ei_pipe_miner,
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {0.5, -0.5}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {-0.5, -0.5}},
        },
        production_type = "input-output",
    },
    effectivity = 1.0,
    scale_fluid_usage = true,
}
miner.module_slots = 2
miner.allowed_effects = {"consumption", "speed", "productivity", "pollution","quality"}
steam_quarry.mining_speed = 1.5
steam_quarry.resource_drain_rate_percent = 65
steam_quarry.performance_to_activity_rate = 2.0

data:extend({steam_quarry})
table.insert(data.raw["technology"]["ei-steam-power"].effects, {type = "unlock-recipe", recipe = "ei-steam-quarry"})