--====================================================================================================
--COLORFUL BIOCHAMBER
--====================================================================================================

if not mods["colorful_biochamber"] then
	return
end

local ei_lib = require("lib/lib")

local function rgba(r, g, b, a)
	return { r = r, g = g, b = b, a = a or 1 }
end

local function normalize_color(color, fallback)
	local source = color or fallback or rgba(1, 1, 1, 1)
	local r = source.r or source[1]
	local g = source.g or source[2]
	local b = source.b or source[3]
	local a = source.a or source[4] or 1

	if not (r and g and b) then
		return table.deepcopy(fallback or rgba(1, 1, 1, 1))
	end

	if r > 1 or g > 1 or b > 1 or a > 1 then
		r = math.min(1, r / 255)
		g = math.min(1, g / 255)
		b = math.min(1, b / 255)
		a = a > 1 and math.min(1, a / 255) or a
	end

	return { r = r, g = g, b = b, a = a }
end

local function fluid_color(fluid_name, field, fallback)
	local fluid = data.raw.fluid[fluid_name]
	return normalize_color(fluid and fluid[field], fallback)
end

local function tint(primary, secondary, tertiary, quaternary)
	return {
		primary = normalize_color(primary),
		secondary = normalize_color(secondary),
		tertiary = normalize_color(tertiary),
		quaternary = normalize_color(quaternary),
	}
end

local sludge_dark = rgba(0.18, 0.08, 0.12)
local sludge_maroon = rgba(0.42, 0.16, 0.14)
local growth_green = rgba(0.10, 0.74, 0.16)
local growth_lime = rgba(0.36, 0.92, 0.28)
local plastic_violet = rgba(0.72, 0.28, 0.78)
local copper_amber = rgba(0.95, 0.58, 0.12)
local sulfur_yellow = rgba(0.98, 0.91, 0.10)
local gold_bright = rgba(0.98, 0.80, 0.22)
local carbon_black = rgba(0.08, 0.08, 0.08)
local steam_white = rgba(0.95, 0.98, 1.00)
local steam_cyan = rgba(0.78, 0.96, 1.00)
local petroleum_purple = rgba(0.66, 0.25, 0.75)
local egg_purple = rgba(0.78, 0.33, 0.89)
local orange_glow = rgba(1.00, 0.58, 0.14)
local oxygen_red = rgba(0.96, 0.19, 0.08)
local acid_yellow = rgba(0.96, 1.00, 0.12)
local crystal_cyan = rgba(0.18, 0.87, 1.00)
local crystal_magenta = rgba(0.86, 0.26, 0.81)
local metal_tarnish = rgba(0.16, 0.12, 0.08)

local bio_oil_base = fluid_color("ei-bio-oil", "base_color", rgba(60 / 255, 130 / 255, 50 / 255))
local acidic_water_flow = fluid_color("ei-acidic-water", "flow_color", rgba(0.81, 0.85, 0.63))
local hydrofluoric_flow = fluid_color("ei-hydrofluoric-acid", "flow_color", rgba(0.57, 0.68, 0.39))
local nitric_base = fluid_color("ei-nitric-acid", "base_color", rgba(0.76, 0.45, 0.30))
local dinitro_base = fluid_color("ei-dinitrogen-tetroxide-water-solution", "base_color", rgba(0.53, 0.58, 0.75))

local colorful_recipe_tints = {
	["ei-bio-insulated-wire"] = tint(sludge_dark, copper_amber, growth_green, plastic_violet),
	["ei-bio-electronic-parts"] = tint(sludge_dark, oxygen_red, growth_green, rgba(0.20, 0.84, 0.82)),
	["ei-bio-magnet"] = tint(sludge_dark, gold_bright, growth_green, crystal_cyan),
	["ei-bio-energy-crystal"] = tint(sludge_dark, acidic_water_flow, growth_green, growth_lime),
	["ei-bio-high-energy-crystal"] = tint(sludge_dark, crystal_magenta, growth_green, crystal_cyan),
	["ei-bio-hydrofluoric-acid"] = tint(metal_tarnish, acid_yellow, growth_green, hydrofluoric_flow),
	["ei-bio-nitric-acid"] = tint(sludge_maroon, oxygen_red, growth_green, dinitro_base),
	["ei-bio-oil-synthesis"] = tint(sludge_dark, egg_purple, bio_oil_base, rgba(0.16, 0.86, 0.75)),
	["ei-carbon-fiber-from-bio-oil"] = tint(carbon_black, nitric_base, bio_oil_base, crystal_cyan),
	["ei-pentapod-egg-from-bio-oil"] = tint(sludge_dark, egg_purple, bio_oil_base, orange_glow),
	["ei-plastic-from-bio-oil"] = tint(sludge_dark, steam_white, bio_oil_base, petroleum_purple),
	["ei-space-steam-1"] = tint(metal_tarnish, steam_white, growth_green, sulfur_yellow),
	["ei-space-steam-2"] = tint(sludge_dark, steam_cyan, growth_lime, orange_glow),
	["ei-sulfur-from-bio-oil"] = tint(sludge_maroon, sulfur_yellow, bio_oil_base, petroleum_purple),
	["ei-sus-plating"] = tint(metal_tarnish, gold_bright, growth_green, acidic_water_flow),
}

for recipe_name, recipe_tint in pairs(colorful_recipe_tints) do
	local recipe = ei_lib.raw.recipe[recipe_name]
	if recipe then
		recipe.crafting_machine_tint = table.deepcopy(recipe_tint)
	end
end
