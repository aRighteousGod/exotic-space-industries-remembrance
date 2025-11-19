--originally by @Samario for Exotic Industries: Loaders (2.0 Port) 
-- return if 5dim belts is not present
if not mods["5dim_transport"] then return end

ei_loaders_lib = require("lib/loaders")
ei_lib = require("lib/lib")

local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"

for i = 4, 10 do
	local previous_loader = 'ei-5dim-mk' .. i-1 .. '-loader'
	if i == 4 then previous_loader = 'ei-express-loader' end
	data:extend({
		{
			name = "ei-5dim-mk".. i .. "-loader",
			type = "item",
			icon = item_path.."5dim-mk".. i .. "-loader.png",
			icon_size = 64,
			icon_mipmaps = 4,
			subgroup = "belt",
			order = "h[ei-loader]_d-5d_" .. i,
			place_result = "ei-5dim-mk".. i .. "-loader",
			stack_size = 50
		},
		{
			name = "ei-5dim-mk".. i .. "-loader",
			type = "recipe",
			category = "crafting-with-fluid",
			energy_required = 2,
			ingredients =
			{
				{type="item", name=previous_loader, amount=1},
				{type="item", name="processing-unit", amount=10 + (5*i)},
				{type="item", name="low-density-structure", amount=10 + (3*i)},
				{type="fluid", name="lubricant", amount=50 + (1*i)}
			},
			results = {{type="item", name="ei-5dim-mk".. i .. "-loader", amount=1}},
			enabled = false,
			always_show_made_in = true,
			main_product = "ei-5dim-mk".. i .. "-loader",
		},
	})

	-- add entities

	local base_belt = data.raw["transport-belt"]["5d-transport-belt-0" .. i]
	if i == 10 then base_belt = data.raw["transport-belt"]["5d-transport-belt-10"] end
	ei_loaders_lib.make_loader("5dim-mk".. i, nil, base_belt.belt_animation_set, base_belt.speed,item_path,entity_path)

	if i > 4 then
		data.raw["loader-1x1"]["ei-5dim-mk" .. i-1 .. "-loader"].next_upgrade = "ei-5dim-mk".. i .. "-loader"
	end
	local target = "logistics-"..i
	local unlock = "ei-5dim-mk" .. i .. "-loader"
	ei_lib.add_unlock_recipe(target,unlock)
end