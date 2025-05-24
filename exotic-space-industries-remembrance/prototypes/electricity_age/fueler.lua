--====================================================================================================
--fueler
--====================================================================================================

data:extend({
    {
        name = "ei_fueler",
        type = "item",
        icon = ei_fueler_graphics_path.."fueler_icon.png",
        icon_size = 64,
        subgroup = "train-transport",
        order = "0",
        place_result = "ei_fueler",
        stack_size = 10,
    },
    {
        name = "ei_fueler",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type="item", name="iron-plate", amount=10},
            {type="item", name="iron-gear-wheel", amount=5},
            {type="item", name="gun-turret", amount=1},
            {type="item", name="inserter", amount=10},
        },
        results = {{type="item", name="ei_fueler", amount=1}},
        enabled = false,
    },
    {
        name = "ei_fueler",
        type = "technology",
        icon = ei_fueler_graphics_path.."fueler_tech.png",
        icon_size = 256,
        prerequisites = {"steel-processing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei_fueler"
            }
        },
        unit = {
            count = 50,
            ingredients = {
                {"automation-science-pack", 1},
            },
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei_fueler",
        type = "container",
        icon = ei_fueler_graphics_path.."fueler_icon.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation"},
        minable = {mining_time = 0.2, result = "ei_fueler"},
        max_health = 100,
        corpse = "small-remnants",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        inventory_size = 50,
        inventory_type = "with_filters_and_bar",
        circuit_connector_sprites = data.raw["container"]["steel-chest"].circuit_connector_sprites,
        circuit_wire_connection_point = data.raw["container"]["steel-chest"].circuit_wire_connection_point,
        circuit_wire_max_distance = data.raw["container"]["steel-chest"].circuit_wire_max_distance,
        enable_inventory_bar = false,
        picture = {
            filename = ei_fueler_graphics_path.."fueler_picture.png",
            width = 512,
            height = 512,
            shift = {0,-0.2},
	        scale = 0.5/2,
        },
        radius_visualisation_specification = {
            sprite = {
                filename = ei_fueler_graphics_path.."radius.png",
                width = 256,
                height = 256
            },
            distance = settings.startup["ei_fueler_range"].value
        },
        
    },
    {
        name = "ei_fueler-sprite",
        type = "sprite",
        filename = ei_fueler_graphics_path.."fueler_picture.png",
        width = 512,
        height = 512
    },
    {
        name = "ei_vehicle",
        type = "sprite",
        filename = ei_fueler_graphics_path.."vehicle.png",
        width = 40,
        height = 40,
    },
    {
        name = "ei_equipment",
        type = "sprite",
        filename = ei_fueler_graphics_path.."equipment.png",
        width = 40,
        height = 40,
    },
})

local fuel_beam = table.deepcopy(data.raw["beam"]["electric-beam"])
fuel_beam.name = "ei_fuel-beam"
fuel_beam.action = nil

data:extend({fuel_beam})