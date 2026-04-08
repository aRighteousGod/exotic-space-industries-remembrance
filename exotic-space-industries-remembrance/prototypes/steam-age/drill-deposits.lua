-- Forged Nauvis deep mines into a stratified extraction regime: iron and copper now march in fault-bound metal provinces, coal and sulfur congeal through sedimentary basins, lead and gold rise from hydrothermal frontier corridors, while uranium and neodymium are exiled to outer scar-zones and anomaly pockets where the planet’s wounds still glow.
local resource_autoplace = require("__core__/lualib/resource-autoplace")

local nauvis_profile_expressions = {
  {
    type = "noise-expression",
    name = "ei_nauvis_common_inner_bias",
    expression = "clamp(1.18 - distance / 2600, 0.32, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_lead_frontier_bias",
    expression = "clamp((distance - 260) / 420, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_gold_frontier_bias",
    expression = "clamp((distance - 420) / 480, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_outer_scar_bias",
    expression = "clamp((distance - 600) / 700, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_fault_noise",
    expression = "0.5 + 0.5 * multioctave_noise{x = x, y = y, persistence = 0.72, seed0 = map_seed, seed1 = 9101, octaves = 4, input_scale = 1/85}"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_metal_split_noise",
    expression = "0.5 + 0.5 * multioctave_noise{x = x + 250, y = y - 180, persistence = 0.7, seed0 = map_seed, seed1 = 9102, octaves = 3, input_scale = 1/110}"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_basin_noise",
    expression = "0.5 + 0.5 * multioctave_noise{x = x - 400, y = y + 140, persistence = 0.75, seed0 = map_seed, seed1 = 9103, octaves = 4, input_scale = 1/120}"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_scar_noise",
    expression = "0.5 + 0.5 * multioctave_noise{x = x, y = y, persistence = 0.68, seed0 = map_seed, seed1 = 9104, octaves = 3, input_scale = 1/70}"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_anomaly_noise",
    expression = "0.5 + 0.5 * multioctave_noise{x = x + 1200, y = y - 900, persistence = 0.65, seed0 = map_seed, seed1 = 9105, octaves = 2, input_scale = 1/45}"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_metal_belt",
    expression = "clamp(0.25 + 0.45 * ei_nauvis_fault_noise + 0.2 * aux + 0.15 * clamp(elevation, 0, 1), 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_basin_belt",
    expression = "clamp(0.2 + 0.45 * ei_nauvis_basin_noise + 0.25 * moisture + 0.2 * clamp(1 - max(elevation, 0), 0, 1), 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_sulfur_fringe",
    expression = "clamp((0.64 - abs(ei_nauvis_basin_noise - 0.66)) * 2.1, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_hydrothermal_belt",
    expression = "clamp((0.62 - abs(ei_nauvis_fault_noise - 0.55)) * 1.9 + 0.12 * aux + 0.08 * clamp(elevation, 0, 1), 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_scar_belt",
    expression = "clamp((0.58 - abs(ei_nauvis_scar_noise - 0.52)) * 1.9 + 0.18 * clamp(elevation, 0, 1) + 0.16 * (1 - moisture), 0, 1)"
  },
  {
    type = "noise-expression",
    name = "ei_nauvis_anomaly_pockets",
    expression = "clamp((0.35 - abs(ei_nauvis_anomaly_noise - 0.5)) * 3.4, 0, 1)"
  },
}

data:extend(nauvis_profile_expressions)

--====================================================================================================
--DRILL DEPOSITS
--====================================================================================================

local nauvis_autoplace_profiles = {
  ["ei-iron-structural"] = {
    base_density = 6.2,
    base_spots_per_km2 = 1.15,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.5,
    random_spot_size_maximum = 1.25,
    random_probability = 1 / 48,
    additional_richness = 500000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.4,
    probability_mask = "clamp(0.24 + 0.92 * ei_nauvis_common_inner_bias * ei_nauvis_metal_belt * (0.85 + 0.3 * (1 - ei_nauvis_metal_split_noise)), 0, 1)",
    richness_mask = "1.05 + 0.1 * tier_from_start + 0.24 * ei_nauvis_metal_belt",
    candidate_spot_count = 22,
  },
  ["ei-copper-structural"] = {
    base_density = 6.15,
    base_spots_per_km2 = 1.18,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.5,
    random_spot_size_maximum = 1.25,
    random_probability = 1 / 48,
    additional_richness = 500000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.35,
    probability_mask = "clamp(0.24 + 0.9 * ei_nauvis_common_inner_bias * ei_nauvis_metal_belt * (0.85 + 0.3 * ei_nauvis_metal_split_noise), 0, 1)",
    richness_mask = "1.02 + 0.1 * tier_from_start + 0.22 * ei_nauvis_metal_belt",
    candidate_spot_count = 22,
  },
  ["ei-coal-basin"] = {
    base_density = 5.2,
    base_spots_per_km2 = 1.0,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.45,
    random_spot_size_maximum = 1.2,
    random_probability = 1 / 48,
    additional_richness = 500000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.3,
    probability_mask = "clamp(0.24 + 0.9 * ei_nauvis_common_inner_bias * ei_nauvis_basin_belt, 0, 1)",
    richness_mask = "1 + 0.08 * tier_from_start + 0.18 * ei_nauvis_basin_belt",
    candidate_spot_count = 22,
  },
  ["ei-sulfur-basin"] = {
    base_density = 4.6,
    base_spots_per_km2 = 0.95,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.45,
    random_spot_size_maximum = 1.15,
    random_probability = 1 / 48,
    additional_richness = 550000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.35,
    probability_mask = "clamp(0.18 + 0.88 * ei_nauvis_common_inner_bias * ei_nauvis_basin_belt * (0.65 + 0.35 * ei_nauvis_sulfur_fringe), 0, 1)",
    richness_mask = "1.03 + 0.1 * tier_from_start + 0.16 * ei_nauvis_basin_belt + 0.12 * ei_nauvis_sulfur_fringe",
    candidate_spot_count = 20,
  },
  ["ei-lead-frontier"] = {
    base_density = 0.7,
    base_spots_per_km2 = 0.35,
    has_starting_area_placement = false,
    random_spot_size_minimum = 0.45,
    random_spot_size_maximum = 1.15,
    random_probability = 1 / 48,
    additional_richness = 700000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.45,
    probability_mask = "clamp(0.04 + 1.05 * ei_nauvis_lead_frontier_bias * ei_nauvis_hydrothermal_belt, 0, 1)",
    richness_mask = "1.15 + 0.18 * tier_from_start + 0.28 * ei_nauvis_hydrothermal_belt",
    candidate_spot_count = 20,
  },
  ["ei-gold-frontier"] = {
    base_density = 0.45,
    base_spots_per_km2 = 0.22,
    has_starting_area_placement = false,
    random_spot_size_minimum = 0.4,
    random_spot_size_maximum = 1.1,
    random_probability = 1 / 48,
    additional_richness = 850000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.5,
    probability_mask = "clamp(0.02 + 1.15 * ei_nauvis_gold_frontier_bias * ei_nauvis_hydrothermal_belt, 0, 1)",
    richness_mask = "1.28 + 0.24 * tier_from_start + 0.34 * ei_nauvis_hydrothermal_belt",
    candidate_spot_count = 18,
  },
  ["ei-uranium-scar"] = {
    base_density = 0.35,
    base_spots_per_km2 = 0.16,
    has_starting_area_placement = false,
    random_spot_size_minimum = 0.45,
    random_spot_size_maximum = 1.1,
    random_probability = 1 / 48,
    additional_richness = 900000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.55,
    probability_mask = "clamp(0.01 + 1.18 * ei_nauvis_outer_scar_bias * ei_nauvis_scar_belt, 0, 1)",
    richness_mask = "1.35 + 0.3 * tier_from_start + 0.32 * ei_nauvis_scar_belt",
    candidate_spot_count = 18,
  },
  ["ei-neodym-anomaly"] = {
    base_density = 0.18,
    base_spots_per_km2 = 0.09,
    has_starting_area_placement = false,
    random_spot_size_minimum = 0.2,
    random_spot_size_maximum = 0.9,
    random_probability = 1 / 48,
    additional_richness = 1250000,
    richness_multiplier = 2,
    richness_multiplier_distance_bonus = 2.8,
    probability_mask = "clamp(1.25 * ei_nauvis_outer_scar_bias * ei_nauvis_scar_belt * ei_nauvis_anomaly_pockets, 0, 1)",
    richness_mask = "1.6 + 0.4 * tier_from_start + 0.36 * ei_nauvis_scar_belt + 0.42 * ei_nauvis_anomaly_pockets",
    candidate_spot_count = 16,
  },
}

local gaia_autoplace_profiles = {
  ["gaia-cryoflux"] = {
    base_density = 1.5,
    base_spots_per_km2 = 1.9,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.44,
    random_spot_size_maximum = 1.02,
    random_probability = 1 / 48,
    additional_richness = 780000,
    richness_multiplier = 2.45,
    richness_multiplier_distance_bonus = 2.3,
    probability_mask = "gaia_cryoflux_habitat",
    richness_mask = "gaia_cryoflux_richness",
    candidate_spot_count = 36,
  },
  ["gaia-phytogas"] = {
    base_density = 1.14,
    base_spots_per_km2 = 1.08,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.82,
    random_spot_size_maximum = 1.56,
    random_probability = 1 / 48,
    additional_richness = 520000,
    richness_multiplier = 1.95,
    richness_multiplier_distance_bonus = 2.0,
    probability_mask = "gaia_phytogas_habitat",
    richness_mask = "gaia_phytogas_richness",
    candidate_spot_count = 24,
  },
  ["gaia-morphium"] = {
    base_density = 1.8,
    base_spots_per_km2 = 2.3,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.5,
    random_spot_size_maximum = 1.2,
    random_probability = 1 / 48,
    additional_richness = 640000,
    richness_multiplier = 2.1,
    richness_multiplier_distance_bonus = 2.15,
    probability_mask = "gaia_morphium_habitat",
    richness_mask = "gaia_morphium_richness",
    candidate_spot_count = 36,
  },
  ["gaia-ammonia"] = {
    base_density = 1.34,
    base_spots_per_km2 = 1.52,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.54,
    random_spot_size_maximum = 1.12,
    random_probability = 1 / 48,
    additional_richness = 560000,
    richness_multiplier = 2.0,
    richness_multiplier_distance_bonus = 2.1,
    probability_mask = "gaia_ammonia_habitat",
    richness_mask = "gaia_ammonia_richness",
    candidate_spot_count = 30,
  },
  ["gaia-coal-gas"] = {
    base_density = 0.94,
    base_spots_per_km2 = 0.86,
    has_starting_area_placement = true,
    random_spot_size_minimum = 0.68,
    random_spot_size_maximum = 1.36,
    random_probability = 1 / 48,
    additional_richness = 620000,
    richness_multiplier = 2.1,
    richness_multiplier_distance_bonus = 2.15,
    probability_mask = "gaia_coal_gas_habitat",
    richness_mask = "gaia_coal_gas_richness",
    candidate_spot_count = 20,
  },
}

local function apply_profile_masks(autoplace, profile)
  if not profile.probability_mask then
    return autoplace
  end

  local mask = profile.probability_mask
  local richness_multiplier = profile.richness_mask or ("max(0.25, 0.65 + 0.85 * (" .. mask .. "))")

  autoplace.probability_expression = "clamp((" .. autoplace.probability_expression .. ") * (" .. mask .. "), 0, 1)"
  autoplace.richness_expression = "max(0, (" .. autoplace.richness_expression .. ") * (" .. richness_multiplier .. "))"

  return autoplace
end

function ei_autoplace(name, profile_name)
  local profile = gaia_autoplace_profiles[profile_name] or nauvis_autoplace_profiles[profile_name]

  if not profile then
    error("Unknown EI autoplace profile: " .. tostring(profile_name))
  end

  local autoplace = resource_autoplace.resource_autoplace_settings
	{
		name = name,
		order = "x1",
		base_density = profile.base_density,
		richness_multiplier = profile.richness_multiplier,
		richness_multiplier_distance_bonus = profile.richness_multiplier_distance_bonus,
		base_spots_per_km2 = profile.base_spots_per_km2,
		has_starting_area_placement = profile.has_starting_area_placement,
		random_spot_size_minimum = profile.random_spot_size_minimum,
		random_spot_size_maximum = profile.random_spot_size_maximum,
    random_probability = profile.random_probability,
		regular_blob_amplitude_multiplier = 1,
		richness_post_multiplier = 1.0,
		additional_richness = profile.additional_richness,
		regular_rq_factor_multiplier = 1,
		candidate_spot_count = profile.candidate_spot_count or 22
	}

  return apply_profile_masks(autoplace, profile)
end

data:extend({
    {
        type = "resource",
        name = "ei-gold-patch",
        icon = ei_graphics_item_path.."gold-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-gold-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-gold-patch", "ei-gold-frontier"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."gold-patch.png",
            priority = "extra-high",
            width = 975,
            height = 664,
            scale = 0.2,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=1, g=0.82, b=0.28},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-gold-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-lead-patch",
        icon = ei_graphics_item_path.."lead-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-lead-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-lead-patch", "ei-lead-frontier"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."lead-patch.png",
            priority = "extra-high",
            width = 594,
            height = 634,
            scale = 0.2,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.36, g=0.2, b=0.84},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-lead-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-neodym-patch",
        icon = ei_graphics_item_path.."neodym-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-neodym-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-neodym-patch", "ei-neodym-anomaly"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."neodym-patch.png",
            priority = "extra-high",
            width = 519,
            height = 331,
            scale = 0.3,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.76, g=0.25, b=0.79},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-neodym-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-iron-patch",
        icon = ei_graphics_item_path.."iron-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-iron-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-iron-patch", "ei-iron-structural"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."iron-patch.png",
            priority = "extra-high",
            width = 285,
            height = 243,
            scale = 0.55,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.25, g=0.48, b=0.79},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-iron-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-copper-patch",
        icon = ei_graphics_item_path.."copper-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-copper-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-copper-patch", "ei-copper-structural"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."copper-patch.png",
            priority = "extra-high",
            width = 233,
            height = 197,
            scale = 0.6,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.86, g=0.50, b=0.16},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-copper-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-coal-patch",
        icon = ei_graphics_item_path.."coal-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-coal-chunk",
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-coal-patch", "ei-coal-basin"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."coal-patch.png",
            priority = "extra-high",
            width = 1016,
            height = 720,
            scale = 0.2,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.20, g=0.20, b=0.20},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-coal-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
    {
        type = "resource",
        name = "ei-uranium-patch",
        icon = ei_graphics_item_path.."uranium-patch.png",
        icon_size = 64,
        flags = {"placeable-neutral"},
        category = "ei-drilling",
        order = "a-b-a",
        infinite = false,
        highlight = true,
        minimum = 600000,
        normal = 1200000,
        --infinite_depletion_amount = 10,
        resource_patch_search_radius = 12,
        tree_removal_probability = 1,
        tree_removal_max_distance = 32 * 32,
        minable =
        {
            mining_time = 1,
            result = "ei-uranium-chunk",
            fluid_amount = 25,
            required_fluid = "sulfuric-acid"
        },
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        --collision_mask = {"item-layer", "water-tile"},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        autoplace = ei_autoplace("ei-uranium-patch", "ei-uranium-scar"),
        stage_counts = {0},
        stages =
        {
          sheet =
          {
            filename = ei_graphics_entity_path.."uranium-patch.png",
            priority = "extra-high",
            width = 567,
            height = 565,
            scale = 0.3,
            frame_count = 1,
            variation_count = 1
          }
        },
        map_color = {r=0.12, g=0.77, b=0.10},
        map_grid = false
    },
    {
		type = "autoplace-control",
		name = "ei-uranium-patch",
		richness = true,
		order = "x1",
		category = "resource"
	},
  {
    type = "resource",
    name = "ei-sulfur-patch",
    icon = ei_graphics_item_path.."sulfur-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-drilling",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
        mining_time = 1,
        result = "ei-sulfur-chunk",
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-sulfur-patch", "ei-sulfur-basin"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_path.."sulfur-patch.png",
        priority = "extra-high",
        width = 870,
        height = 781,
        scale = 0.2,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.69, g=0.81, b=0.45},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-sulfur-patch",
  richness = true,
  order = "x1",
  category = "resource"
  },
  --[[
  {
    type = "resource",
    name = "ei-core-patch",
    icon = ei_graphics_item_path.."core-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-drilling",
    order = "a-b-a",
    infinite = true,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    infinite_depletion_amount = 100,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
        mining_time = 1,
        result = "ei-neodym-chunk",
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-core-patch", "gaia-core"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_path.."ground-source.png",
        priority = "extra-high",
        width = 332,
        height = 240,
        scale = 0.5,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.69, g=0.81, b=0.45},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-core-patch",
  richness = true,
  order = "y3",
  category = "resource"
  },
  {
  type = "noise-layer",
  name = "ei-core-patch"
  },
  ]]
  {
    type = "resource",
    name = "ei-cryoflux-patch",
    icon = ei_graphics_item_path.."cryoflux-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-pumping",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
      mining_time = 1,
			results =
			{
				{
					type = "fluid",
					name = "ei-cryoflux",
					amount_min = 20,
					amount_max = 20,
					probability = 1,
				}
			},
      fluid_amount = 1,
      required_fluid = "steam"
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-cryoflux-patch", "gaia-cryoflux"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_path.."alien-hole-1.png",
        priority = "extra-high",
        width = 512,
        height = 512,
        scale = 0.3,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0, g=0.615, b=0.901},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-cryoflux-patch",
  richness = true,
  order = "y2",
  category = "resource"
  },
  {
    type = "resource",
    name = "ei-phytogas-patch",
    icon = ei_graphics_item_path.."phytogas-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-pumping",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
      mining_time = 1,
			results =
			{
				{
					type = "fluid",
					name = "ei-phythogas",
					amount_min = 20,
					amount_max = 20,
					probability = 1,
				}
			},
      fluid_amount = 1,
      required_fluid = "ei-acidic-water"
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-phytogas-patch", "gaia-phytogas"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_path.."alien-hole-2.png",
        priority = "extra-high",
        width = 512,
        height = 512,
        scale = 0.3,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.235, g=0.78, b=0},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-phytogas-patch",
  richness = true,
  order = "y1",
  category = "resource"
  },
  {
    type = "resource",
    name = "ei-morphium-patch",
    icon = ei_graphics_item_2_path.."morphium-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "basic-fluid",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
      mining_time = 1,
			results =
			{
				{
					type = "fluid",
					name = "ei-morphium",
					amount_min = 20,
					amount_max = 20,
					probability = 1,
				}
			},
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-morphium-patch", "gaia-morphium"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_2_path.."morphium-patch.png",
        priority = "extra-high",
        width = 473,
        height = 267,
        scale = 0.4,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.58, g=0.168, b=1.0},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-morphium-patch",
  richness = true,
  order = "z1",
  category = "resource"
  },
  {
    type = "resource",
    name = "ei-ammonia-patch",
    icon = ei_graphics_item_2_path.."ammonia-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-pumping",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
      mining_time = 1,
			results =
			{
				{
					type = "fluid",
					name = "ei-ammonia-gas",
					amount_min = 20,
					amount_max = 20,
					probability = 1,
				}
			},
      fluid_amount = 1,
      required_fluid = "steam"
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-ammonia-patch", "gaia-ammonia"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_2_path.."ammonia-patch.png",
        priority = "extra-high",
        width = 473,
        height = 267,
        scale = 0.4,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.921, g=0.921, b=0.921},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-ammonia-patch",
  richness = true,
  order = "z2",
  category = "resource"
  },
  {
    type = "resource",
    name = "ei-coal-gas-patch",
    icon = ei_graphics_item_2_path.."coal-gas-patch.png",
    icon_size = 64,
    flags = {"placeable-neutral"},
    category = "ei-pumping",
    order = "a-b-a",
    infinite = false,
    highlight = true,
    minimum = 600000,
    normal = 1200000,
    --infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    minable =
    {
      mining_time = 1,
			results =
			{
				{
					type = "fluid",
					name = "ei-coal-gas",
					amount_min = 20,
					amount_max = 20,
					probability = 1,
				}
			},
      fluid_amount = 1,
      required_fluid = "steam"
    },
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    --collision_mask = {"item-layer", "water-tile"},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    autoplace = ei_autoplace("ei-coal-gas-patch", "gaia-coal-gas"),
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = ei_graphics_entity_2_path.."coal-gas-patch.png",
        priority = "extra-high",
        width = 504,
        height = 358,
        scale = 0.35,
        frame_count = 1,
        variation_count = 1
      }
    },
    map_color = {r=0.788, g=0.2, b=0},
    map_grid = false
  },
  {
  type = "autoplace-control",
  name = "ei-coal-gas-patch",
  richness = true,
  order = "z3",
  category = "resource"
  },
})

for _, resource_name in pairs({
  "ei-gold-patch",
  "ei-lead-patch",
  "ei-neodym-patch",
  "ei-iron-patch",
  "ei-copper-patch",
  "ei-coal-patch",
  "ei-uranium-patch",
  "ei-sulfur-patch",
}) do
  -- Register the existing control names on Nauvis so previews, UI controls, and saves keep working.
  data.raw["planet"]["nauvis"].map_gen_settings.autoplace_settings["entity"]["settings"][resource_name] = {}
  data.raw["planet"]["nauvis"].map_gen_settings.autoplace_controls[resource_name] = {}
end
