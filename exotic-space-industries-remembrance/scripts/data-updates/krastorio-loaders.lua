--originally by @Samario for Exotic Industries: Loaders (2.0 Port) 
-- return if krastorio / offshoot is not present
if not (mods["Krastorio2"] or mods["Krastorio2-spaced-out"]) then return end

ei_loaders_lib = require("lib/loaders")
ei_lib = require("lib/lib")

local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"



if mods["Krastorio2"] then -- Krastorio2 Spaced Out does not have the Advanced tier, leaving SA's Turbo tier to take its place
	data:extend({
		{
			name = "ei-kr-advanced-loader",
			type = "item",
			icon = item_path.."kr-advanced-loader.png",
			icon_size = 64,
			icon_mipmaps = 4,
			subgroup = "belt",
			order = "h[ei-loader]-d-k2_1",
			place_result = "ei-kr-advanced-loader",
			stack_size = 50
		},
		{
			name = "ei-kr-advanced-loader",
			type = "recipe",
			category = "crafting",
			energy_required = 2,
			ingredients =
			{
				{type="item", name="ei-fast-loader", amount=2},
				{type="item", name="kr-steel-gear-wheel", amount=15},
				{type="item", name="kr-rare-metals", amount=5},
			},
			results = {{type="item", name="ei-kr-advanced-loader", amount=1}},
			enabled = false,
			always_show_made_in = true,
			main_product = "ei-kr-advanced-loader",
		},
	})

	-- add entities

	local kradvanced_belt = data.raw["transport-belt"]["kr-advanced-transport-belt"]
	ei_loaders_lib.make_loader("kr-advanced", nil, kradvanced_belt.belt_animation_set, kradvanced_belt.speed,item_path,entity_path)
	--data.raw['loader']['ei_kr-advanced-loader'].resistances = data.raw["transport-belt"]["kr-advanced-transport-belt"].resistances
	--data.raw['loader']['ei_kr-advanced-loader'].max_health = data.raw["transport-belt"]["kr-advanced-transport-belt"].max_health

	ei_lib.add_unlock_recipe("kr-logistics-4","ei-kr-advanced-loader")

end

local ingredient = "ei-kr-advanced-loader"
if mods['Krastorio2-spaced-out'] then ingredient = "ei-turbo-loader" end -- K2 Spaced Out uses turbo instead of advanced

data:extend({
    {
        name = "ei-kr-superior-loader",
        type = "item",
        icon = item_path.."kr-superior-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-k2_2",
        place_result = "ei-kr-superior-loader",
        stack_size = 50
    },
    {
        name = "ei-kr-superior-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name=ingredient, amount=1},
            {type="item", name="low-density-structure", amount=10},
            {type="item", name="kr-imersium-gear-wheel", amount=5},
        },
        results = {{type="item", name="ei-kr-superior-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-kr-superior-loader",
    },
})

-- add entities

local krsuperior_belt = data.raw["transport-belt"]["kr-superior-transport-belt"]
ei_loaders_lib.make_loader("kr-superior", nil, krsuperior_belt.belt_animation_set, krsuperior_belt.speed,item_path,entity_path)
--data.raw['loader']['ei_kr-superior-loader'].resistances = data.raw["transport-belt"]["kr-superior-transport-belt"].resistances
--data.raw['loader']['ei_kr-superior-loader'].max_health = data.raw["transport-belt"]["kr-superior-transport-belt"].max_health

ei_lib.add_unlock_recipe("kr-logistic-5","ei-kr-superior-loader")
