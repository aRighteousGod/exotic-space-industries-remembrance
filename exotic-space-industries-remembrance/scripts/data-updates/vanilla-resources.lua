--====================================================================================================
--PRESERVE THE CUSTOM DEFAULT PRESET WITHOUT GAIA-SPECIFIC AUTOPLACE OVERRIDES
--Bound Nauvis surface patches to a cradle-and-scars regime: the landing zone now stands as a protected industrial reserve where iron, copper, coal, stone, and oil remain fit to found first industry, while beyond that cradle the crust fractures into remnant belts and exhausted scar-fields where iron, copper, and uranium persist only as spent surface relics.
--====================================================================================================
data.raw["map-gen-presets"].default["ei-default"] = {
    order = "a",
    basic_settings = {
        starting_area = 1.5
    },
    advanced_settings = {
        enemy_evolution = {
            time_factor = 3.2e-06,
            pollution_factor = 7.65e-07
        },
        enemy_expansion = {
            max_expansion_distance = 6,
            min_expansion_cooldown = 18000,
            max_expansion_cooldown = 270000
        }
    }
}

local nauvis_surface_patch_expressions = {
    {
        type = "noise-expression",
        name = "ei_nauvis_surface_reserve_bias",
        expression = "clamp((420 - distance) / 120, 0, 1)"
    },
    {
        type = "noise-expression",
        name = "ei_nauvis_surface_fracture_ring",
        expression = "clamp((distance - 220) / 180, 0, 1) * clamp((980 - distance) / 240, 0, 1)"
    },
    {
        type = "noise-expression",
        name = "ei_nauvis_surface_ore_scars",
        expression = "clamp((distance - 820) / 260, 0, 1) * clamp((0.66 - abs(ei_nauvis_fault_noise - 0.56)) * 1.85 + 0.2 * ei_nauvis_scar_belt, 0, 1)"
    },
    {
        type = "noise-expression",
        name = "ei_nauvis_surface_pressure_corridors",
        expression = "clamp(0.18 + 0.38 * ei_nauvis_basin_noise + 0.18 * moisture + 0.16 * (1 - abs(ei_nauvis_fault_noise - 0.58)) + 0.1 * clamp(1 - max(elevation, 0), 0, 1), 0, 1)"
    },
    {
        type = "noise-expression",
        name = "ei_nauvis_surface_rocky_floor",
        expression = "clamp(0.42 + 0.28 * aux + 0.2 * clamp(elevation, 0, 1) + 0.15 * ei_nauvis_fault_noise, 0, 1)"
    },
}

data:extend(nauvis_surface_patch_expressions)

local default_crude_oil_patches = data.raw["noise-expression"]["default-crude-oil-patches"]
if default_crude_oil_patches and default_crude_oil_patches.expression then
    default_crude_oil_patches.expression =
        string.gsub(default_crude_oil_patches.expression, "has_starting_area_placement = 0", "has_starting_area_placement = 1", 1)
end

local function apply_surface_patch_mask(resource_name, probability_mask, richness_mask)
    local resource = data.raw.resource[resource_name]

    if not resource or not resource.autoplace then
        return
    end

    resource.autoplace.probability_expression =
        "clamp((" .. resource.autoplace.probability_expression .. ") * (" .. probability_mask .. "), 0, 1)"

    if resource.autoplace.richness_expression and richness_mask then
        resource.autoplace.richness_expression =
            "max(0, (" .. resource.autoplace.richness_expression .. ") * (" .. richness_mask .. "))"
    end
end

local iron_surface_mask =
    "clamp(0.05 + 0.88 * ei_nauvis_surface_reserve_bias + 0.72 * ei_nauvis_surface_reserve_bias * ei_nauvis_metal_belt * (0.84 + 0.26 * (1 - ei_nauvis_metal_split_noise)) + 0.42 * ei_nauvis_surface_fracture_ring * ei_nauvis_metal_belt * (0.32 + 0.68 * (1 - ei_nauvis_metal_split_noise)) + 0.1 * ei_nauvis_surface_ore_scars * ei_nauvis_metal_belt, 0, 2.4)"
local copper_surface_mask =
    "clamp(0.05 + 0.88 * ei_nauvis_surface_reserve_bias + 0.7 * ei_nauvis_surface_reserve_bias * ei_nauvis_metal_belt * (0.84 + 0.26 * ei_nauvis_metal_split_noise) + 0.42 * ei_nauvis_surface_fracture_ring * ei_nauvis_metal_belt * (0.32 + 0.68 * ei_nauvis_metal_split_noise) + 0.1 * ei_nauvis_surface_ore_scars * ei_nauvis_metal_belt, 0, 2.4)"
local uranium_surface_mask =
    "clamp(0.01 + 0.08 * ei_nauvis_surface_reserve_bias * clamp((distance - 190) / 120, 0, 1) * ei_nauvis_scar_belt + 0.16 * ei_nauvis_surface_fracture_ring * ei_nauvis_scar_belt + 0.88 * ei_nauvis_outer_scar_bias * ei_nauvis_surface_ore_scars, 0, 1.5)"
local coal_surface_mask =
    "clamp(0.74 + 0.34 * ei_nauvis_surface_reserve_bias + 0.24 * ei_nauvis_basin_belt + 0.08 * ei_nauvis_surface_fracture_ring - 0.06 * ei_nauvis_outer_scar_bias, 0.5, 1.7)"
local stone_surface_mask =
    "clamp(0.9 + 0.2 * ei_nauvis_surface_reserve_bias + 0.3 * ei_nauvis_surface_rocky_floor + 0.06 * ei_nauvis_surface_fracture_ring, 0.75, 1.7)"
local oil_surface_mask =
    "clamp(0.78 + 0.12 * ei_nauvis_surface_reserve_bias + 0.16 * ei_nauvis_surface_fracture_ring + 0.42 * ei_nauvis_surface_pressure_corridors + 0.08 * ei_nauvis_basin_belt, 0.5, 1.9)"

apply_surface_patch_mask(
    "iron-ore",
    iron_surface_mask,
    "max(0.35, 0.54 + 0.86 * ei_nauvis_surface_reserve_bias + 0.18 * ei_nauvis_surface_fracture_ring + 0.12 * ei_nauvis_metal_belt)"
)
apply_surface_patch_mask(
    "copper-ore",
    copper_surface_mask,
    "max(0.35, 0.54 + 0.84 * ei_nauvis_surface_reserve_bias + 0.18 * ei_nauvis_surface_fracture_ring + 0.1 * ei_nauvis_metal_belt)"
)
apply_surface_patch_mask(
    "uranium-ore",
    uranium_surface_mask,
    "max(0.22, 0.52 + 0.18 * ei_nauvis_surface_fracture_ring + 0.42 * ei_nauvis_outer_scar_bias + 0.25 * ei_nauvis_scar_belt)"
)
apply_surface_patch_mask(
    "coal",
    coal_surface_mask,
    "max(0.55, 0.9 + 0.24 * ei_nauvis_surface_reserve_bias + 0.12 * ei_nauvis_basin_belt - 0.06 * ei_nauvis_outer_scar_bias)"
)
apply_surface_patch_mask(
    "stone",
    stone_surface_mask,
    "max(0.7, 0.95 + 0.18 * ei_nauvis_surface_reserve_bias + 0.15 * ei_nauvis_surface_rocky_floor)"
)
apply_surface_patch_mask(
    "crude-oil",
    oil_surface_mask,
    "max(0.75, 0.95 + 0.2 * ei_nauvis_surface_pressure_corridors + 0.08 * ei_nauvis_surface_fracture_ring)"
)
