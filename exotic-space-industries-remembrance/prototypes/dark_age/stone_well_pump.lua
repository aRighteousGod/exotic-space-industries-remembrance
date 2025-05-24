local name = modprefix.."stone_well_pump"

local stone_well_pump = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

stone_well_pump.name = name
stone_well_pump.icon = ei_graphics_icon_2_path.."stone-waterwell.png"
stone_well_pump.icon_size = 32
stone_well_pump.icon_mipmaps = 1
stone_well_pump.pumping_speed = 20

stone_well_pump.graphics_set = nil
stone_well_pump.water_reflection = nil
stone_well_pump.animation = nil

-- error(serpent.block(stone_well_pump))

for i,d in ipairs({"north", "east", "south", "west"}) do
	stone_well_pump.picture[d] = 
	{
		filename = ei_graphics_entity_2_path.."stone-waterwell.png",
		priority = "extra-high",
		shift = {0.3, 0.8},
		width = 256,
		height = 256,
		x = (i - 1) * 256
	}
end

stone_well_pump.minable = {mining_time = 1, result = name}

stone_well_pump.collision_box = {{-2.2, -2.2}, {2.2, 2.2}}
stone_well_pump.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
stone_well_pump.fluid_box.pipe_connections[1].position = {0, 3}

stone_well_pump.circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points
stone_well_pump.circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites

data:extend(
{
	stone_well_pump, 
	{
		type = "recipe",
		name = name,
		energy_required = 10,
		ingredients =
		{
			{type="item", name="iron-gear-wheel", amount=10},
			{type="item", name="stone-brick", amount=10},
			{type="item", name="pipe", amount=10},
			{type="item", name="pipe-to-ground", amount=1},
		},
		result_count = 1,
		result = name
	},
	{
		type = "item",
		name = name,
		icon = ei_graphics_icon_2_path.."stone-waterwell.png",
		icon_size = 32,
		subgroup = "extraction-machine",
		order = "b[fluids]-a[stone-waterwell]",
		place_result = name,
		stack_size = 5
	}
})

add_unlock_recipe(modprefix.."steam-power",name)