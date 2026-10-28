-- originally from Bio oil by Kil_Jaeden
-- adds Gleban bio oil fluid, recipes to produce and refine it, and a tech to unlock them
local bio_oil_fluid = {
	type = "fluid",
	subgroup = "fluid",
	name = "ei-bio-oil",
	icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png",
	icon_mipmaps = 4,
	icon_size = 64,
	base_color = { 60, 130, 50 },
	flow_color = { 60, 100, 50 },
	default_temperature = 30,
    fuel_value = "80kJ", --crude 100kj
    fuel_emissions_multiplier = 0.8 --crude 1.25
}
local synthesis_recipe = {
	type = "recipe",
	name = "ei-bio-oil-synthesis",
	subgroup = "fluid-recipes",
	categories = {"organic"},
	ingredients = {
		{ type = "item", name = "pentapod-egg", amount = 1 },
		{ type = "item", name = "jelly", amount = 60 },
	},
	results = {
        { type = "fluid", name = "ei-bio-oil", amount_min = 40, amount_max = 160 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
	},
	energy_required = 15,
	enabled = false,
	
	unlock_results = true,
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local refining_recipe = {
	type = "recipe",
	name = "ei-bio-oil-refining",
	subgroup = "fluid-recipes",
	categories = {"oil-processing"},
	icons = {
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.2, shift = { -0, -3 } },
		{ icon = data.raw.fluid["ei-medium-destilate"].icon, scale = 0.2, shift = { -3, 3 } },
		{ icon = data.raw.fluid["ei-heavy-destilate"].icon, scale = 0.2, shift = { 3, 3 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 130 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
	},
	results = {
        { type = "fluid", name = "ei-medium-destilate", amount_min = 14, amount_max = 46, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
        { type = "fluid", name = "ei-heavy-destilate", amount_min = 19, amount_max = 62, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
		{ type = "item", name = "spoilage", amount_min = 1, amount_max = 3, independent_probability = 0.99, ignored_by_stats = 3 },
	},
	energy_required = 10,
	enabled = false,
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local water_refining_recipe = {
	type = "recipe",
	name = "ei-water-bio-oil-refining",
	subgroup = "fluid-recipes",
	categories = {"oil-processing"},
	icons = {
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.2, shift = { -3, -3 } },
        { icon = "__base__/graphics/icons/fluid/water.png", scale = 0.2, shift = { 3, -3 } },
		{ icon = data.raw.fluid["ei-medium-destilate"].icon, scale = 0.2, shift = { -3, 3 } },
		{ icon = data.raw.fluid["ei-heavy-destilate"].icon, scale = 0.2, shift = { 3, 3 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 100 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "water", amount = 100 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
	},
	results = {
        { type = "fluid", name = "ei-medium-destilate", amount_min = 24, amount_max = 76, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
        { type = "fluid", name = "ei-heavy-destilate", amount_min = 24, amount_max = 76, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
		{ type = "item", name = "spoilage", amount_min = 1, amount_max = 3, independent_probability = 0.66, ignored_by_stats = 3 },
	},
	energy_required = 10,
	enabled = false,
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}

local steam_refining_recipe = {
	type = "recipe",
	name = "ei-steam-bio-oil-refining",
	subgroup = "fluid-recipes",
	categories = {"oil-processing"},
	icons = {
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.2, shift = { -0, -3 } },
        { icon = "__base__/graphics/icons/fluid/steam.png", scale = 0.2, shift = { 3, -3 } },
		{ icon = data.raw.fluid["ei-medium-destilate"].icon, scale = 0.2, shift = { -3, 3 } },
		{ icon = data.raw.fluid["ei-heavy-destilate"].icon, scale = 0.2, shift = { 3, 3 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 75 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "steam", amount = 750, minimum_temperature = 500 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
	},
	results = {
        { type = "fluid", name = "ei-medium-destilate", amount_min = 34, amount_max = 106, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
        { type = "fluid", name = "ei-heavy-destilate", amount_min = 10, amount_max = 40, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
        { type = "fluid", name = "ei-lube-destilate", amount_min = 2, amount_max = 18, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
		{ type = "item", name = "spoilage", amount_min = 1, amount_max = 3, independent_probability = 0.33, ignored_by_stats = 3 },
	},
	energy_required = 10,
	enabled = false,
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local plastic_from_bio_oil_recipe = {
	type = "recipe",
	name = "ei-plastic-from-bio-oil",
	categories = {"organic"},
	icons = {
		{ icon = "__base__/graphics/icons/plastic-bar.png", scale = 0.8, shift = { 6, 0 } },
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.6, shift = { -6, 0 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 10 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "petroleum-gas", amount = 80 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
		{ type = "item", name = "bioflux", amount = 2 },
	},
	results = {
		{ type = "item", name = "plastic-bar", amount = 10 },
	},
	energy_required = 5,
	enabled = false,
	
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local sulfur_from_bio_oil_recipe = {
	type = "recipe",
	name = "ei-sulfur-from-bio-oil",
	categories = {"organic"},
	icons = {
		{ icon = "__base__/graphics/icons/sulfur.png", scale = 0.8, shift = { 6, 0 } },
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.6, shift = { -6, 0 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 10 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "petroleum-gas", amount = 90 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
		{ type = "item", name = "bioflux", amount = 1 },
	},
	results = {
		{ type = "item", name = "sulfur", amount = 10 },
	},
	energy_required = 5,
	enabled = false,
	
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local pentapod_egg_from_bio_oil_recipe = {
    type = "recipe",
    name = "ei-pentapod-egg-from-bio-oil",
    icon = "__space-age__/graphics/icons/pentapod-egg-3.png",
    categories = {"organic"},
    surface_conditions =
    {
      {
        property = "pressure",
        min = 2000,
        max = 2000
      }
    },
    subgroup = "agriculture-processes",
    order = "d[organic-processing]-a[pentapod-egg2]",
    auto_recycle = false,
    enabled = false,
    allow_productivity = true,
    
    hide_from_signal_gui = true,
    energy_required = 37,
    ingredients =
    {
		{type = "item", name = "pentapod-egg", amount = 1, ignored_by_stats = 1},
		{type = "item", name = "nutrients", amount = 60},
        {type = "fluid", name = "ei-bio-oil", amount = 90, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
    },
    results =
    {
		{type = "item", name = "pentapod-egg", amount = 1, ignored_by_stats = 1, ignored_by_productivity = 1, reset_freshness_on_craft = true},
		{type = "item", name = "pentapod-egg", amount_min = 2, amount_max = 4, independent_probability = 0.95, reset_freshness_on_craft = true},
    },
    crafting_machine_tint =
    {
		primary = {r = 45, g = 129, b = 86, a = 1.000},
		secondary = {r = 122, g = 75, b = 156, a = 1.000},
    }
}

local carbon_fiber_from_bio_oil_recipe = {
	type = "recipe",
	name = "ei-carbon-fiber-from-bio-oil",
	categories = {"organic"},
	subgroup = "agriculture-products",
	order = "a[organic-products]-h[carbon-fiber]-a[broodslime-oil]",
	icons = {
		{ icon = "__space-age__/graphics/icons/carbon-fiber.png", scale = 0.8, shift = { 6, 0 } },
		{ icon = ei_graphics_3_path .. "graphics/fluids/bio-oil.png", scale = 0.6, shift = { -6, 0 } },
	},
	ingredients = {
        { type = "fluid", name = "ei-bio-oil", amount = 150 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "ei-nitric-acid", amount = 150 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
		{ type = "item", name = "yumako-mash", amount = 150 },
		{ type = "item", name = "carbon", amount = 15 },
		{ type = "item", name = "bioflux", amount = 15 },
	},
	results = {
	{ type = "item",  name = "carbon-fiber",    amount_min = 10, amount_max = 20 },
    { type = "fluid", name = "ei-acidic-water", amount_min = 15, amount_max = 35, independent_probability = 0.70, ignored_by_stats = 35 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
    { type = "fluid", name = "ei-dirty-water",  amount_min = 5, amount_max = 25, independent_probability = 0.50, ignored_by_stats = 25 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
	{ type = "item",  name = "atan-ash",        amount_min = 2,  amount_max = 8,  independent_probability = 0.35, ignored_by_stats = 8 },
	},
	energy_required = 45,
	enabled = false,
	
	surface_conditions = {
		{ property = "pressure", min = 2000, max = 2000 },
	},
}
local tech = {
	type = "technology",
	name = "ei-bio-oil",
	icons = refining_recipe.icons,
	research_trigger = {
		type = "craft-item",
		item = "pentapod-egg",
		count = 1,
	},
	prerequisites = {
		"agricultural-science-pack",
	},
	effects = {
		{
			type = "unlock-recipe",
			recipe = synthesis_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = refining_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = water_refining_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = steam_refining_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = plastic_from_bio_oil_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = sulfur_from_bio_oil_recipe.name,
		},
		{
			type = "unlock-recipe",
			recipe = pentapod_egg_from_bio_oil_recipe.name,
		},
	},
	unit = {
		count = 100,
		ingredients = ei_data.science["computer-age"],
		time = 20,
	},
	age = "computer-age",
}

local carbon_tech = {
	type = "technology",
	name = "ei-bio-oil-carbon-fiber",
	icons = carbon_fiber_from_bio_oil_recipe.icons,
	prerequisites = {
		"ei-bio-oil","carbon-fiber"
	},
	effects = {
		{
			type = "unlock-recipe",
			recipe = carbon_fiber_from_bio_oil_recipe.name,
		},
	},
	unit = {
		count = 100,
		ingredients = ei_data.science["computer-age"],
		time = 20,
	},
	age = "computer-age",
}

--[[
data.raw["recipe"]["stack-inserter"].ingredients = {
    { type = "item",  name = "bulk-inserter",   amount = 1 },
    { type = "item",  name = "processing-unit", amount = 1 },
    { type = "item",  name = "carbon-fiber",    amount = 2 },
    { type = "fluid", name = "ei-bio-oil",         amount = 10 },
}

data.raw["technology"]["bioflux-processing"] = nil
data.raw["technology"]["carbon-fiber"] = nil

local prerequisities = data.raw["technology"]["agricultural-science-pack"].prerequisites
for i, v in ipairs(prerequisities) do
    if v == "bioflux-processing" then
        prerequisities[i] = "bioflux"
    end
end
local technologies = { "rocket-turret", "toolbelt-equipment", "stack-inserter" }
for i, technology in ipairs(technologies) do
    for j, v in ipairs(data.raw["technology"][technology].prerequisites) do
        if v == "carbon-fiber" then
            data.raw["technology"][technology].prerequisites[j] = "ei-bio-oil"
        end
    end
end
]]
if mods["colorful_biochamber"] then
	synthesis_recipe.crafting_machine_tint = {
		primary = { r = 1, g = 1, b = 1, a = 1 },
		secondary = bio_oil_fluid.base_color,
		tertiary = bio_oil_fluid.base_color,
		quaternary = bio_oil_fluid.flow_color,
	}
	plastic_from_bio_oil_recipe.crafting_machine_tint = {
		primary = bio_oil_fluid.flow_color,
		secondary = data.raw["fluid"]["petroleum-gas"].base_color,
		tertiary = bio_oil_fluid.base_color,
		quaternary = data.raw["fluid"]["petroleum-gas"].flow_color,
	}
	sulfur_from_bio_oil_recipe.crafting_machine_tint = {
		primary = data.raw["fluid"]["sulfuric-acid"].base_color,
		secondary = data.raw["fluid"]["petroleum-gas"].base_color,
		tertiary = data.raw["fluid"]["petroleum-gas"].flow_color,
		quaternary = bio_oil_fluid.base_color,
	}
	
	carbon_fiber_from_bio_oil_recipe.crafting_machine_tint = {
		primary = { r = 50, g = 50, b = 50, a = 1 },
		secondary = bio_oil_fluid.base_color,
		tertiary = bio_oil_fluid.flow_color,
		quaternary = { r = 50, g = 50, b = 50, a = 1 },
	}
end

data:extend({
	bio_oil_fluid,
	synthesis_recipe,
	refining_recipe,
    water_refining_recipe,
    steam_refining_recipe,
	plastic_from_bio_oil_recipe,
	sulfur_from_bio_oil_recipe,
	carbon_fiber_from_bio_oil_recipe,
	pentapod_egg_from_bio_oil_recipe,
	tech,
	carbon_tech,
})
