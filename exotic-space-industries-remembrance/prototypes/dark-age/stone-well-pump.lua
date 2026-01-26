local name = modprefix.."stone-well-pump"

local ei_lib = require("lib/lib")
local stone_well_pump = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

stone_well_pump.name = name
stone_well_pump.icon = ei_graphics_icon_2_path.."stone-waterwell.png"
stone_well_pump.icon_size = 32
stone_well_pump.icon_mipmaps = 1
stone_well_pump.pumping_speed = 2

stone_well_pump.graphics_set = {
	base_pictures = {
	sheets = {
{
	filename = ei_graphics_entity_2_path.."stone-waterwell.png",
	priority = "extra-high",
	shift = {0.3, 0.8},
	width = 256,
	height = 256,
}
	}
}
}
stone_well_pump.water_reflection = nil
stone_well_pump.animation = nil

stone_well_pump.minable = {mining_time = 1, result = name}

stone_well_pump.collision_box = {{-2.2, -2.2}, {2.2, 2.2}}
stone_well_pump.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
stone_well_pump.fluid_box.pipe_connections = {
	{
		position = {0, 2},
		direction = defines.direction.south,
		flow_direction = "output"
	}
}

stone_well_pump.circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points
stone_well_pump.circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites

data:extend(
{
	stone_well_pump, 
	{
		type = "recipe",
		name = name,
		energy_required = 3,
		ingredients =
		{
			{type="item", name="ei-iron-mechanical-parts", amount=10},
			{type="item", name="stone-brick", amount=10},
			{type="item", name="pipe", amount=10},
			{type="item", name="pipe-to-ground", amount=1},
		},
		results = {
			{type="item", name="ei-stone-well-pump", amount=1},
		},
		enabled = true,
	},
	{
		type = "item",
		name = "ei-stone-well-pump",
		icon = ei_graphics_icon_2_path.."stone-waterwell.png",
		icon_size = 32,
		subgroup = "extraction-machine",
		order = "b[fluids]-a[stone-waterwell]",
		place_result = "ei-stone-well-pump",
		stack_size = 5
	}
})