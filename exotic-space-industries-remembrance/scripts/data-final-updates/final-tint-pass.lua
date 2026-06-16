-- Curated late generic recipe tint owner.
-- Keep colorful-biochamber as its own later override pass.

local function has_rgba_channels(color)
	return type(color) == "table"
		and color.r ~= nil
		and color.g ~= nil
		and color.b ~= nil
		and color.a ~= nil
end

local function has_recipe_tint(recipe_tint)
	return type(recipe_tint) == "table"
		and has_rgba_channels(recipe_tint.primary)
		and has_rgba_channels(recipe_tint.secondary)
		and has_rgba_channels(recipe_tint.tertiary)
		and has_rgba_channels(recipe_tint.quaternary)
end

local function apply_recipe_tint(recipe_name, recipe_tint)
	if not has_recipe_tint(recipe_tint) then
		return
	end

	local recipe = data.raw.recipe[recipe_name]
	if not recipe then
		return
	end

	recipe.crafting_machine_tint = table.deepcopy(recipe_tint)
end

local function apply_recipe_tints(recipe_tints)
	for recipe_name, recipe_tint in pairs(recipe_tints) do
		apply_recipe_tint(recipe_name, recipe_tint)
	end
end

local curated_recipe_tints = {
	["rocket-fuel"] = {
		primary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
		secondary = { r = 0.49, g = 0.48, b = 0.46, a = 1.000 },
		tertiary = { r = 0.57, g = 0.7, b = 0.47, a = 1.000 },
		quaternary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
	},

	["heavy-oil-cracking"] = {
		primary = { r = 0.57, g = 0.7, b = 0.47, a = 1.000 },
		secondary = { r = 0.75, g = 0.88, b = 0.75, a = 1.000 },
		tertiary = { r = 0.854, g = 0.659, b = 0.576, a = 1.000 },
		quaternary = { r = 1.000, g = 0.494, b = 0.271, a = 1.000 },
	},

	["ei-solid-fuel-residual-oil"] = {
		primary = { r = 0.49, g = 0.36, b = 0.13, a = 1.000 },
		secondary = { r = 0.4, g = 0.24, b = 0.06, a = 1.000 },
		tertiary = { r = 0.49, g = 0.36, b = 0.13, a = 1.000 },
		quaternary = { r = 0.4, g = 0.24, b = 0.06, a = 1.000 },
	},

	["ei-diesel-fuel-unit-empty"] = {
		primary = { r = 0.64, g = 0.59, b = 0.49, a = 1.000 },
		secondary = { r = 0.90, g = 0.83, b = 0.67, a = 1.000 },
		tertiary = { r = 0.64, g = 0.59, b = 0.49, a = 1.000 },
		quaternary = { r = 0.90, g = 0.83, b = 0.67, a = 1.000 },
	},

	["ei-diesel-fuel-unit"] = {
		primary = { r = 0.64, g = 0.59, b = 0.49, a = 1.000 },
		secondary = { r = 0.90, g = 0.83, b = 0.67, a = 1.000 },
		tertiary = { r = 0.64, g = 0.59, b = 0.49, a = 1.000 },
		quaternary = { r = 0.90, g = 0.83, b = 0.67, a = 1.000 },
	},

	["ei-plastic-benzol"] = {
		primary = { r = 1.000, g = 1.000, b = 1.000, a = 1.000 },
		secondary = { r = 0.771, g = 0.771, b = 0.771, a = 1.000 },
		tertiary = { r = 0.768, g = 0.665, b = 0.762, a = 1.000 },
		quaternary = { r = 0.55, g = 0.3, b = 0.21, a = 1.000 },
	},

	["ei-desulfurize-kerosene"] = {
		primary = { r = 0.64, g = 0.59, b = 0.49, a = 1.000 },
		secondary = { r = 0.90, g = 0.83, b = 0.67, a = 1.000 },
		tertiary = { r = 0.75, g = 0.88, b = 0.75, a = 1.000 },
		quaternary = { r = 0.57, g = 0.7, b = 0.47, a = 1.000 },
	},

	["ei-acidic-water-sulfur"] = {
		primary = { r = 0.876, g = 0.869, b = 0.597, a = 1.000 },
		secondary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
		tertiary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		quaternary = { r = 0.81, g = 0.85, b = 0.63, a = 1.000 },
	},

	["ei-sulfur-acidic-water"] = {
		primary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		secondary = { r = 0.81, g = 0.85, b = 0.63, a = 1.000 },
		tertiary = { r = 0.876, g = 0.869, b = 0.597, a = 1.000 },
		quaternary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
	},

	["ei-kerosene-heavy-oil"] = {
		primary = { r = 0.57, g = 0.7, b = 0.47, a = 1.000 },
		secondary = { r = 0.75, g = 0.88, b = 0.75, a = 1.000 },
		tertiary = { r = 0.854, g = 0.659, b = 0.576, a = 1.000 },
		quaternary = { r = 1.000, g = 0.395, b = 0.127, a = 1.000 },
	},

	["ei-benzol-petroleum"] = {
		primary = { r = 0.764, g = 0.596, b = 0.780, a = 1.000 },
		secondary = { r = 0.762, g = 0.551, b = 0.844, a = 1.000 },
		tertiary = { r = 0.33, g = 0.16, b = 0.13, a = 1.000 },
		quaternary = { r = 0.55, g = 0.3, b = 0.21, a = 1.000 },
	},

	["ei-kerosene-cracking"] = {
		primary = { r = 1.000, g = 0.642, b = 0.261, a = 1.000 },
		secondary = { r = 1.000, g = 0.722, b = 0.376, a = 1.000 },
		tertiary = { r = 0.75, g = 0.88, b = 0.75, a = 1.000 },
		quaternary = { r = 0.57, g = 0.7, b = 0.47, a = 1.000 },
	},

	["ei-acidic-water-crushed-sulfur"] = {
		primary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		secondary = { r = 0.81, g = 0.85, b = 0.63, a = 1.000 },
		tertiary = { r = 0.876, g = 0.869, b = 0.597, a = 1.000 },
		quaternary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
	},
	["ei-carbon-dioxide-acidic-water"] = {
		primary = { r = 0.72, g = 0.72, b = 0.72, a = 1.000 },
		secondary = { r = 0.55, g = 0.64, b = 0.68, a = 1.000 },
		tertiary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		quaternary = { r = 0.86, g = 0.84, b = 0.77, a = 1.000 },
	},
	["ei-dirty-water-fluorite-nitric"] = {
		primary = { r = 0.29, g = 0.41, b = 0.45, a = 1.000 },
		secondary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		tertiary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		quaternary = { r = 1.000, g = 0.978, b = 0.513, a = 1.000 },
	},
	["ei-acidic-water-fluorite-bed"] = {
		primary = { r = 0.51, g = 0.69, b = 0.62, a = 1.000 },
		secondary = { r = 0.94, g = 0.94, b = 0.94, a = 1.000 },
		tertiary = { r = 0.86, g = 0.84, b = 0.77, a = 1.000 },
		quaternary = { r = 1.000, g = 0.978, b = 0.513, a = 1.000 },
	},
	["ei-oxygen-sulfuric-acid"] = {
		primary = { r = 0.313, g = 0.705, b = 0.352, a = 1.000 },
		secondary = { r = 0.215, g = 0.607, b = 0.803, a = 1.000 },
		tertiary = { r = 0.647, g = 0.721, b = 0.309, a = 1.000 },
		quaternary = { r = 0.431, g = 0.866, b = 0.784, a = 1.000 },
	},
	["ei-drill-fluid"] = {
		primary = { r = 0.49, g = 0.48, b = 0.44, a = 1.000 },
		secondary = { r = 0.69, g = 0.63, b = 0.771, a = 1.000 },
		tertiary = { r = 0.268, g = 0.723, b = 0.223, a = 1.000 },
		quaternary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
	},

	["ei-lube-destilation"] = {
		primary = { r = 0.647, g = 0.471, b = 0.396, a = 1.000 },
		secondary = { r = 1.000, g = 0.395, b = 0.127, a = 1.000 },
		tertiary = { r = 0.268, g = 0.723, b = 0.223, a = 1.000 },
		quaternary = { r = 0.432, g = 0.793, b = 0.386, a = 1.000 },
	},
	["ei-lube-destilate-steam-finishing"] = {
		primary = { r = 0.647, g = 0.471, b = 0.396, a = 1.000 },
		secondary = { r = 0.920, g = 0.960, b = 0.980, a = 1.000 },
		tertiary = { r = 0.268, g = 0.723, b = 0.223, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},

	["ei-sus-plating"] = {
		primary = { r = 0.728, g = 0.818, b = 0.443, a = 1.000 },
		secondary = { r = 0.939, g = 0.763, b = 0.191, a = 1.000 },
		tertiary = { r = 0.268, g = 0.723, b = 0.223, a = 1.000 },
		quaternary = { r = 0.432, g = 0.793, b = 0.386, a = 1.000 },
	},

	["ei-bio-hydrofluoric-acid"] = {
		primary = { r = 0.36, g = 0.56, b = 0.37, a = 1.000 },
		secondary = { r = 0.57, g = 0.68, b = 0.39, a = 1.000 },
		tertiary = { r = 0.728, g = 0.818, b = 0.443, a = 1.000 },
		quaternary = { r = 0.939, g = 0.763, b = 0.191, a = 1.000 },
	},

	["ei-bio-nitric-acid"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.24, g = 0.42, b = 0.55, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.53, g = 0.58, b = 0.75, a = 1.000 },
	},

	["ei-undilute-morphium"] = {
		primary = { r = 0.38, g = 0.52, b = 0.56, a = 1.000 },
		secondary = { r = 0.48, g = 0.46, b = 0.32, a = 1.000 },
		tertiary = { r = 0.22, g = 0.60, b = 0.66, a = 1.000 },
		quaternary = { r = 0.64, g = 0.54, b = 0.58, a = 1.000 },
	},

	["ei-concentrated-morphium"] = {
		primary = { r = 0.56, g = 0.36, b = 0.38, a = 1.000 },
		secondary = { r = 0.66, g = 0.63, b = 0.45, a = 1.000 },
		tertiary = { r = 0, g = 0.57, b = 0.63, a = 1.000 },
		quaternary = { r = 0.78, g = 0.55, b = 0.68, a = 1.000 },
	},
	["ei-concentrated-morphium-light-oil"] = {
		primary = { r = 0.56, g = 0.36, b = 0.38, a = 1.000 },
		secondary = { r = 0.920, g = 0.960, b = 1.000, a = 1.000 },
		tertiary = { r = 1.000, g = 0.722, b = 0.376, a = 1.000 },
		quaternary = { r = 0.360, g = 0.600, b = 0.600, a = 1.000 },
	},
	["ei-concentrated-morphium-kerosene"] = {
		primary = { r = 0.56, g = 0.36, b = 0.38, a = 1.000 },
		secondary = { r = 0.920, g = 0.960, b = 1.000, a = 1.000 },
		tertiary = { r = 1.000, g = 0.494, b = 0.271, a = 1.000 },
		quaternary = { r = 0.360, g = 0.600, b = 0.600, a = 1.000 },
	},
	["ei-concentrated-morphium-heavy-oil"] = {
		primary = { r = 0.56, g = 0.36, b = 0.38, a = 1.000 },
		secondary = { r = 0.920, g = 0.960, b = 1.000, a = 1.000 },
		tertiary = { r = 0.570, g = 0.700, b = 0.470, a = 1.000 },
		quaternary = { r = 0.360, g = 0.600, b = 0.600, a = 1.000 },
	},
	["ei-concentrated-morphium-lubricant"] = {
		primary = { r = 0.56, g = 0.36, b = 0.38, a = 1.000 },
		secondary = { r = 0.920, g = 0.960, b = 1.000, a = 1.000 },
		tertiary = { r = 0.432, g = 0.793, b = 0.386, a = 1.000 },
		quaternary = { r = 0.360, g = 0.600, b = 0.600, a = 1.000 },
	},

	["ei-evolved-alien-seed"] = {
		primary = { r = 0.728, g = 0.818, b = 0.443, a = 1.000 },
		secondary = { r = 0.939, g = 0.763, b = 0.191, a = 1.000 },
		tertiary = { r = 0.1, g = 0.78, b = 0.03, a = 1.000 },
		quaternary = { r = 0.36, g = 0.6, b = 0.6, a = 1.000 },
	},

	["ei-bio-matter"] = {
		primary = { r = 0.728, g = 0.818, b = 0.443, a = 1.000 },
		secondary = { r = 0.939, g = 0.763, b = 0.191, a = 1.000 },
		tertiary = { r = 0.22, g = 0.36, b = 0.25, a = 1.000 },
		quaternary = { r = 0.6, g = 0.31, b = 0.32, a = 1.000 },
	},

	["ei-cryodust"] = {
		primary = { r = 0.1, g = 0.78, b = 0.83, a = 1.000 },
		secondary = { r = 0.78, g = 0.55, b = 0.68, a = 1.000 },
		tertiary = { r = 0, g = 0.57, b = 0.63, a = 1.000 },
		quaternary = { r = 0.1, g = 0.78, b = 0.83, a = 1.000 },
	},

	["ei-molten-steel-mix"] = {
		primary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
		secondary = { r = 0.50, g = 0.61, b = 0.67, a = 1.000 },
		tertiary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
		quaternary = { r = 0.49, g = 0.48, b = 0.46, a = 1.000 },
	},

	["ei-molten-steel-oxygen"] = {
		primary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
		secondary = { r = 0.50, g = 0.61, b = 0.67, a = 1.000 },
		tertiary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
		quaternary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
	},

	["ei-crystal-solution"] = {
		primary = { r = 0.55, g = 0.75, b = 0.57, a = 1.000 },
		secondary = { r = 0.48, g = 0.3, b = 0.36, a = 1.000 },
		tertiary = { r = 0.36, g = 0.56, b = 0.37, a = 1.000 },
		quaternary = { r = 0.57, g = 0.68, b = 0.39, a = 1.000 },
	},

	["ei-hydrogen"] = {
		primary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
		secondary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		tertiary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
		quaternary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
	},

	["ei-ammonia"] = {
		primary = { r = 0.36, g = 0.6, b = 0.6, a = 1.000 },
		secondary = { r = 0.36, g = 0.6, b = 0.6, a = 1.000 },
		tertiary = { r = 0.0, g = 0.82, b = 1, a = 1.000 },
		quaternary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
	},

	["ei-dinitrogen-tetroxide"] = {
		primary = { r = 0.53, g = 0.58, b = 0.75, a = 1.000 },
		secondary = { r = 0.67, g = 0.36, b = 0.45, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.36, g = 0.6, b = 0.6, a = 1.000 },
	},

	["ei-dinitrogen-tetroxide-water-solution"] = {
		primary = { r = 0.53, g = 0.58, b = 0.75, a = 1.000 },
		secondary = { r = 0.67, g = 0.36, b = 0.45, a = 1.000 },
		tertiary = { r = 0.53, g = 0.58, b = 0.75, a = 1.000 },
		quaternary = { r = 0.67, g = 0.36, b = 0.45, a = 1.000 },
	},

	["ei-nitric-acid"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.24, g = 0.42, b = 0.55, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.53, g = 0.58, b = 0.75, a = 1.000 },
	},

	["ei-battery-lithium"] = {
		primary = { r = 0.65, g = 0.81, b = 0.87, a = 1.000 },
		secondary = { r = 0.80, g = 0.84, b = 0.73, a = 1.000 },
		tertiary = { r = 0.728, g = 0.818, b = 0.443, a = 1.000 },
		quaternary = { r = 0.939, g = 0.763, b = 0.191, a = 1.000 },
	},

	["ei-silicon"] = {
		primary = { r = 0.24, g = 0.28, b = 0.40, a = 1.000 },
		secondary = { r = 0.55, g = 0.48, b = 0.67, a = 1.000 },
		tertiary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
		quaternary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
	},

	["ei-monosilicon"] = {
		primary = { r = 0.44, g = 0.31, b = 0.62, a = 1.000 },
		secondary = { r = 1.0, g = 1.0, b = 1.0, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.55, g = 0.48, b = 0.67, a = 1.000 },
	},

	["ei-neodym-ingot"] = {
		primary = { r = 0.1, g = 0.78, b = 0.83, a = 1.000 },
		secondary = { r = 0.64, g = 0.56, b = 0.63, a = 1.000 },
		tertiary = { r = 0.0, g = 0.82, b = 1, a = 1.000 },
		quaternary = { r = 0.54, g = 0.53, b = 0.85, a = 1.000 },
	},

	["ei-pl-mix"] = {
		primary = { r = 0.72, g = 0.46, b = 0.1, a = 1.000 },
		secondary = { r = 0.0, g = 0.49, b = 0.47, a = 1.000 },
		tertiary = { r = 0.95, g = 0.88, b = 0.35, a = 1.000 },
		quaternary = { r = 0.0, g = 0.72, b = 0.68, a = 1.000 },
	},

	["ei-dd-mix"] = {
		primary = { r = 0.0, g = 0.51, b = 0.58, a = 1.000 },
		secondary = { r = 0.0, g = 0.51, b = 0.58, a = 1.000 },
		tertiary = { r = 0.0, g = 0.72, b = 0.8, a = 1.000 },
		quaternary = { r = 0.4, g = 0.96, b = 1.0, a = 1.000 },
	},

	["ei-dl-mix"] = {
		primary = { r = 0.0, g = 0.51, b = 0.58, a = 1.000 },
		secondary = { r = 0.0, g = 0.49, b = 0.47, a = 1.000 },
		tertiary = { r = 0.0, g = 0.72, b = 0.8, a = 1.000 },
		quaternary = { r = 0.0, g = 0.72, b = 0.68, a = 1.000 },
	},

	["ei-dt-mix"] = {
		primary = { r = 0.0, g = 0.51, b = 0.58, a = 1.000 },
		secondary = { r = 0.59, g = 0.22, b = 0.21, a = 1.000 },
		tertiary = { r = 0.0, g = 0.72, b = 0.8, a = 1.000 },
		quaternary = { r = 0.96, g = 0.35, b = 0.34, a = 1.000 },
	},

	["ei-tt-mix"] = {
		primary = { r = 0.59, g = 0.22, b = 0.21, a = 1.000 },
		secondary = { r = 0.59, g = 0.22, b = 0.21, a = 1.000 },
		tertiary = { r = 0.96, g = 0.35, b = 0.34, a = 1.000 },
		quaternary = { r = 1.0, g = 0.5, b = 0.62, a = 1.000 },
	},

	["ei-dh-mix"] = {
		primary = { r = 0.0, g = 0.51, b = 0.58, a = 1.000 },
		secondary = { r = 0.68, g = 0.12, b = 0.70, a = 1.000 },
		tertiary = { r = 0.0, g = 0.72, b = 0.8, a = 1.000 },
		quaternary = { r = 1.0, g = 0.36, b = 0.92, a = 1.000 },
	},

	["ei-hl-mix"] = {
		primary = { r = 0.68, g = 0.12, b = 0.70, a = 1.000 },
		secondary = { r = 0.0, g = 0.49, b = 0.47, a = 1.000 },
		tertiary = { r = 1.0, g = 0.36, b = 0.92, a = 1.000 },
		quaternary = { r = 0.0, g = 0.72, b = 0.68, a = 1.000 },
	},

	["ei-th-mix"] = {
		primary = { r = 0.59, g = 0.22, b = 0.21, a = 1.000 },
		secondary = { r = 0.68, g = 0.12, b = 0.70, a = 1.000 },
		tertiary = { r = 0.96, g = 0.35, b = 0.34, a = 1.000 },
		quaternary = { r = 1.0, g = 0.36, b = 0.92, a = 1.000 },
	},

	["ei-hh-mix"] = {
		primary = { r = 0.68, g = 0.12, b = 0.70, a = 1.000 },
		secondary = { r = 0.68, g = 0.12, b = 0.70, a = 1.000 },
		tertiary = { r = 1.0, g = 0.36, b = 0.92, a = 1.000 },
		quaternary = { r = 0.88, g = 0.22, b = 1.0, a = 1.000 },
	},

	["ei-oxygen-difluoride"] = {
		primary = { r = 0.56, g = 0.82, b = 0.1, a = 1.000 },
		secondary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.44, g = 0.31, b = 0.62, a = 1.000 },
	},
	["ei-oxygen-difluoride-alien"] = {
		primary = { r = 0.560, g = 0.820, b = 0.100, a = 1.000 },
		secondary = { r = 0.950, g = 0.100, b = 0.100, a = 1.000 },
		tertiary = { r = 0.647, g = 0.721, b = 0.309, a = 1.000 },
		quaternary = { r = 0.780, g = 0.550, b = 0.680, a = 1.000 },
	},

	["ei-lithium-crystal"] = {
		primary = { r = 0.65, g = 0.81, b = 0.87, a = 1.000 },
		secondary = { r = 0.80, g = 0.84, b = 0.73, a = 1.000 },
		tertiary = { r = 0.83, g = 0.11, b = 0.05, a = 1.000 },
		quaternary = { r = 0.29, g = 0.41, b = 0.45, a = 1.000 },
	},

	["ei-uranium-hexafluorite"] = {
		primary = { r = 0.28, g = 1, b = 0.6, a = 1.000 },
		secondary = { r = 0.210, g = 0.170, b = 0.013, a = 1.000 },
		tertiary = { r = 0.36, g = 0.56, b = 0.37, a = 1.000 },
		quaternary = { r = 0.57, g = 0.68, b = 0.39, a = 1.000 },
	},

	["ei-energy-crystal-washing"] = {
		primary = { r = 0.51, g = 0.84, b = 0.61, a = 1.000 },
		secondary = { r = 0.210, g = 0.170, b = 0.013, a = 1.000 },
		tertiary = { r = 1.000, g = 0.978, b = 0.513, a = 1.000 },
		quaternary = { r = 0.210, g = 0.170, b = 0.013, a = 1.000 },
	},

	["ei-hydrofluoric-acid"] = {
		primary = { r = 0.36, g = 0.56, b = 0.37, a = 1.000 },
		secondary = { r = 0.57, g = 0.68, b = 0.39, a = 1.000 },
		tertiary = { r = 0.4, g = 0.3, b = 0.54, a = 1.000 },
		quaternary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
	},

	["ei-hydrofluoric-acid-steam-ash"] = {
		primary = { r = 0.53, g = 0.56, b = 0.37, a = 1.000 },
		secondary = { r = 0.68, g = 0.68, b = 0.39, a = 1.000 },
		tertiary = { r = 0.54, g = 0.3, b = 0.54, a = 1.000 },
		quaternary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
	},

	["ei-hydrofluoric-acid-steam"] = {
		primary = { r = 0.66, g = 0.56, b = 0.37, a = 1.000 },
		secondary = { r = 0.87, g = 0.68, b = 0.39, a = 1.000 },
		tertiary = { r = 0.7, g = 0.3, b = 0.54, a = 1.000 },
		quaternary = { r = 0.969, g = 1.000, b = 0.019, a = 1.000 },
	},

	["ei-alien-seed-harvesting"] = {
		primary = { r = 0.0, g = 0.82, b = 1, a = 1.000 },
		secondary = { r = 0.54, g = 0.53, b = 0.85, a = 1.000 },
		tertiary = { r = 0.0, g = 0.82, b = 1, a = 1.000 },
		quaternary = { r = 0.54, g = 0.53, b = 0.85, a = 1.000 },
	},

	["ei-nitric-acid-uranium-235"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.37, g = 0.84, b = 0.16, a = 1.000 },
		tertiary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		quaternary = { r = 0.24, g = 0.42, b = 0.55, a = 1.000 },
	},

	["ei-nitric-acid-plutonium-239"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.23, g = 0.69, b = 0.67, a = 1.000 },
		tertiary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		quaternary = { r = 0.24, g = 0.42, b = 0.55, a = 1.000 },
	},

	["ei-nitric-acid-thorium-232"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.24, g = 0.37, b = 0.38, a = 1.000 },
		tertiary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		quaternary = { r = 0.24, g = 0.42, b = 0.55, a = 1.000 },
	},

	["ei-nitric-acid-uranium-233"] = {
		primary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		secondary = { r = 0.24, g = 0.37, b = 0.38, a = 1.000 },
		tertiary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		quaternary = { r = 0.35, g = 0.65, b = 0.36, a = 1.000 },
	},
	["nuclear-fuel-reprocessing"] = {
		primary = { r = 0.760, g = 0.450, b = 0.300, a = 1.000 },
		secondary = { r = 0.370, g = 0.840, b = 0.160, a = 1.000 },
		tertiary = { r = 0.760, g = 0.450, b = 0.300, a = 1.000 },
		quaternary = { r = 0.240, g = 0.420, b = 0.550, a = 1.000 },
	},

	["ei-cold-coolant"] = {
		primary = { r = 0.88, g = 0.65, b = 0.42, a = 1.000 },
		secondary = { r = 0.32, g = 0.84, b = 0.95, a = 1.000 },
		tertiary = { r = 0.76, g = 0.45, b = 0.3, a = 1.000 },
		quaternary = { r = 0.3, g = 0.3, b = 0.3, a = 1.000 },
	},

	["ei-carbon"] = {
		primary = { r = 0.3, g = 0.3, b = 0.3, a = 1.000 },
		secondary = { r = 0.1, g = 0.1, b = 0.1, a = 1.000 },
		tertiary = { r = 1.000, g = 0.978, b = 0.513, a = 1.000 },
		quaternary = { r = 0.210, g = 0.170, b = 0.013, a = 1.000 },
	},
	["ei-coal-gas-carbon-dioxide"] = {
		primary = { r = 0.72, g = 0.72, b = 0.72, a = 1.000 },
		secondary = { r = 0.25, g = 0.16, b = 0.15, a = 1.000 },
		tertiary = { r = 0.1, g = 0.1, b = 0.1, a = 1.000 },
		quaternary = { r = 0.88, g = 0.53, b = 0.16, a = 1.000 },
	},
	["ei-fluorite-fluorine-calcite"] = {
		primary = { r = 0.560, g = 0.820, b = 0.100, a = 1.000 },
		secondary = { r = 0.940, g = 0.940, b = 0.940, a = 1.000 },
		tertiary = { r = 1.000, g = 0.978, b = 0.513, a = 1.000 },
		quaternary = { r = 0.720, g = 0.720, b = 0.720, a = 1.000 },
	},

	["ei-liquid-nitrogen"] = {
		primary = { r = 0.100, g = 0.850, b = 0.900, a = 1.000 },
		secondary = { r = 0.050, g = 0.350, b = 1.000, a = 1.000 },
		tertiary = { r = 0.100, g = 0.100, b = 0.120, a = 1.000 },
		quaternary = { r = 0.700, g = 1.000, b = 1.000, a = 1.000 },
	},
	["ei-liquid-oxygen"] = {
		primary = { r = 0.950, g = 0.100, b = 0.100, a = 1.000 },
		secondary = { r = 1.000, g = 0.450, b = 0.100, a = 1.000 },
		tertiary = { r = 0.120, g = 0.080, b = 0.080, a = 1.000 },
		quaternary = { r = 1.000, g = 0.700, b = 0.700, a = 1.000 },
	},
	["ei-vaporize-liquid-nitrogen"] = {
		primary = { r = 0.180, g = 0.750, b = 0.780, a = 1.000 },
		secondary = { r = 0.100, g = 0.350, b = 0.800, a = 1.000 },
		tertiary = { r = 0.110, g = 0.110, b = 0.130, a = 1.000 },
		quaternary = { r = 0.780, g = 0.950, b = 0.950, a = 1.000 },
	},
	["ei-vaporize-liquid-oxygen"] = {
		primary = { r = 0.850, g = 0.180, b = 0.180, a = 1.000 },
		secondary = { r = 0.950, g = 0.500, b = 0.200, a = 1.000 },
		tertiary = { r = 0.130, g = 0.090, b = 0.090, a = 1.000 },
		quaternary = { r = 0.980, g = 0.780, b = 0.780, a = 1.000 },
	},
	["ei-liquid-ammonia"] = {
		primary = { r = 0.920, g = 0.980, b = 0.970, a = 1.000 },
		secondary = { r = 0.700, g = 0.900, b = 0.850, a = 1.000 },
		tertiary = { r = 0.120, g = 0.130, b = 0.130, a = 1.000 },
		quaternary = { r = 0.980, g = 1.000, b = 1.000, a = 1.000 },
	},
	["ei-vaporize-liquid-ammonia"] = {
		primary = { r = 0.900, g = 0.950, b = 0.940, a = 1.000 },
		secondary = { r = 0.720, g = 0.860, b = 0.820, a = 1.000 },
		tertiary = { r = 0.130, g = 0.140, b = 0.140, a = 1.000 },
		quaternary = { r = 0.960, g = 0.990, b = 0.990, a = 1.000 },
	},

	["ei-insulated-pipe"] = {
		primary = { r = 0.900, g = 0.890, b = 0.850, a = 1.000 },
		secondary = { r = 0.650, g = 0.810, b = 0.870, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.550, g = 0.480, b = 0.670, a = 1.000 },
	},
	["ei-insulated-underground-pipe"] = {
		primary = { r = 0.900, g = 0.890, b = 0.850, a = 1.000 },
		secondary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		tertiary = { r = 0.650, g = 0.810, b = 0.870, a = 1.000 },
		quaternary = { r = 0.240, g = 0.280, b = 0.400, a = 1.000 },
	},
	["ei-insulated-tank"] = {
		primary = { r = 0.900, g = 0.890, b = 0.850, a = 1.000 },
		secondary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		tertiary = { r = 0.500, g = 0.610, b = 0.670, a = 1.000 },
		quaternary = { r = 0.550, g = 0.480, b = 0.670, a = 1.000 },
	},
	["ei-gaia-relic-debris-recycling"] = {
		primary = { r = 0.620, g = 0.840, b = 0.750, a = 1.000 },
		secondary = { r = 0.720, g = 0.920, b = 0.820, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.650, g = 0.810, b = 0.870, a = 1.000 },
	},

	["ei-warm-fire-from-wood"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-coal"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-wooden-chest"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-solid-fuel"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-carbon"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-yumako-seed"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-jellynut-seed"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-biter-egg"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-pentapod-egg"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-spoilage"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-tree-seed"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ee-super-fuel"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-stingfrond-seed"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-nettles"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ei-coke"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ei-coke-pellets"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ei-crushed-coke"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ei-charcoal"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},
	["ei-warm-fire-from-ei-crushed-coal"] = {
		primary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
		secondary = { r = 1.000, g = 0.852, b = 0.172, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.250, g = 0.160, b = 0.150, a = 1.000 },
	},

	["extinguisher-ammo"] = {
		primary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		secondary = { r = 0.550, g = 0.640, b = 0.680, a = 1.000 },
		tertiary = { r = 0.647, g = 0.721, b = 0.309, a = 1.000 },
		quaternary = { r = 0.880, g = 0.530, b = 0.160, a = 1.000 },
	},
	["captive-biter-spawner"] = {
		primary = { r = 0.780, g = 0.330, b = 0.890, a = 1.000 },
		secondary = { r = 0.650, g = 0.810, b = 0.870, a = 1.000 },
		tertiary = { r = 0.370, g = 0.840, b = 0.160, a = 1.000 },
		quaternary = { r = 0.600, g = 0.310, b = 0.320, a = 1.000 },
	},
	["scrap-recycling"] = {
		primary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		secondary = { r = 0.640, g = 0.590, b = 0.490, a = 1.000 },
		tertiary = { r = 0.650, g = 0.810, b = 0.870, a = 1.000 },
		quaternary = { r = 0.900, g = 0.830, b = 0.670, a = 1.000 },
	},
	["atan-pollution-filter"] = {
		primary = { r = 0.100, g = 0.100, b = 0.100, a = 1.000 },
		secondary = { r = 0.647, g = 0.471, b = 0.396, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.550, g = 0.480, b = 0.670, a = 1.000 },
	},
	["atan-pollution-filter-cleaning"] = {
		primary = { r = 0.920, g = 0.960, b = 0.980, a = 1.000 },
		secondary = { r = 1.000, g = 0.494, b = 0.271, a = 1.000 },
		tertiary = { r = 0.290, g = 0.410, b = 0.450, a = 1.000 },
		quaternary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
	},
	["atan-spore-filter"] = {
		primary = { r = 0.080, g = 0.080, b = 0.080, a = 1.000 },
		secondary = { r = 0.570, g = 0.700, b = 0.470, a = 1.000 },
		tertiary = { r = 0.490, g = 0.480, b = 0.460, a = 1.000 },
		quaternary = { r = 0.290, g = 0.640, b = 0.320, a = 1.000 },
	},
	["atan-spore-filter-cleaning"] = {
		primary = { r = 0.920, g = 0.960, b = 0.980, a = 1.000 },
		secondary = { r = 1.000, g = 0.494, b = 0.271, a = 1.000 },
		tertiary = { r = 0.290, g = 0.410, b = 0.450, a = 1.000 },
		quaternary = { r = 0.220, g = 0.360, b = 0.250, a = 1.000 },
	},
}

apply_recipe_tints(curated_recipe_tints)
