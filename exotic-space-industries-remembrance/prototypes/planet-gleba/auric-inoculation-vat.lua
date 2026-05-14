--==============================================================================
-- ESIR FILE MAP
-- owns: auric inoculation vat entity, tech, hidden phase recipes, and telemetry prototypes
-- loaded_by: exotic-space-industries-remembrance\prototypes\planet-gleba\gleba.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
local ei_data = require("lib/data")
local util = require("util")

local VAT_CATEGORY_NAME = "ei-auric-inoculation-vat"
local VAT_NAME = "ei-auric-inoculation-vat"
local VAT_TECH_NAME = "ei-auric-marsh-inoculation"
local VAT_IDLE_RECIPE_NAME = "ei-auric-vat-idle"
local MARKER_FLUID_NAME = "ei-auric-inoculation-vat-marker"
local TELEMETRY_PROXY_NAME = "ei-auric-inoculation-vat-circuit-interface"
local MAIN_GRAPHICS_PATH = ei_path .. "graphics/"

local VAT_ICON_PATH = MAIN_GRAPHICS_PATH .. "items/auric-inoculation-vat.png"
local VAT_TECH_ICON_PATH = MAIN_GRAPHICS_PATH .. "techs/auric-marsh-inoculation.png"
local CYST_ICON_PATH = MAIN_GRAPHICS_PATH .. "entities/auric-cyst-node/auric-cyst-1.png"
local CYST_ICON_SIZE = 512
local CYST_ICON_MIPMAPS = 5
local VAT_ENTITY_PATH = MAIN_GRAPHICS_PATH .. "entities/auric-inoculation-vat/"
local VAT_FRAME_SIZE = 500
local VAT_FRAME_SCALE = 0.36

local MARKER_ICON = ei_graphics_other_path .. "64_empty.png"
local DIRTY_WATER_INPUT_FLUIDBOX = 1
local BIO_OIL_INPUT_FLUIDBOX = 2
local DIRTY_WATER_OUTPUT_FLUIDBOX = 1
local ACIDIC_WATER_OUTPUT_FLUIDBOX = 2
local MARKER_OUTPUT_FLUIDBOX = 3

local BAND_DEFS = {
    {key = "b1", min = 24, max = 39, seed_spoilage = 8,  seed_bio_oil = 16, flood_dirty_water = 40,  ferment_jelly = 18, ferment_yumako = 18, enrich_bioflux = 1, drain_dirty_water = 25, drain_acidic_water = 5},
    {key = "b2", min = 40, max = 55, seed_spoilage = 9,  seed_bio_oil = 18, flood_dirty_water = 50,  ferment_jelly = 22, ferment_yumako = 22, enrich_bioflux = 1, drain_dirty_water = 35, drain_acidic_water = 5},
    {key = "b3", min = 56, max = 71, seed_spoilage = 10, seed_bio_oil = 20, flood_dirty_water = 60,  ferment_jelly = 25, ferment_yumako = 25, enrich_bioflux = 2, drain_dirty_water = 45, drain_acidic_water = 10},
    {key = "b4", min = 72, max = 87, seed_spoilage = 12, seed_bio_oil = 24, flood_dirty_water = 72,  ferment_jelly = 30, ferment_yumako = 30, enrich_bioflux = 2, drain_dirty_water = 55, drain_acidic_water = 10},
    {key = "b5", min = 88, max = 103, seed_spoilage = 14, seed_bio_oil = 28, flood_dirty_water = 84,  ferment_jelly = 35, ferment_yumako = 35, enrich_bioflux = 3, drain_dirty_water = 65, drain_acidic_water = 15},
    {key = "b6", min = 104, max = 127, seed_spoilage = 16, seed_bio_oil = 32, flood_dirty_water = 96, ferment_jelly = 40, ferment_yumako = 40, enrich_bioflux = 3, drain_dirty_water = 80, drain_acidic_water = 15},
    {key = "b7", min = 128, max = 160, seed_spoilage = 18, seed_bio_oil = 36, flood_dirty_water = 108, ferment_jelly = 45, ferment_yumako = 45, enrich_bioflux = 4, drain_dirty_water = 95, drain_acidic_water = 20},
}

local function make_signal_icons(base_icon, base_size, overlay_icon, tint, base_mipmaps)
    return {
        {
            icon = base_icon,
            icon_size = base_size,
            icon_mipmaps = base_mipmaps,
        },
        {
            icon = overlay_icon,
            icon_size = 64,
            tint = tint,
        },
    }
end

local function make_marker_result()
    return {type = "fluid", name = MARKER_FLUID_NAME, amount = 1, fluidbox_index = MARKER_OUTPUT_FLUIDBOX, ignored_by_stats = 1, ignored_by_productivity = 1}
end

local function make_hidden_recipe(name, energy_required, ingredients, extra_results, localised_name)
    local results = {make_marker_result()}
    for _, result in ipairs(extra_results or {}) do
        results[#results + 1] = result
    end

    local recipe = {
        type = "recipe",
        name = name,
        category = VAT_CATEGORY_NAME,
        enabled = true,
        hidden = true,
        hide_from_player_crafting = true,
        hide_from_stats = false,
        hide_from_signal_gui = true,
        allow_as_intermediate = false,
        allow_decomposition = false,
        allow_productivity = false,
        allow_quality = false,
        unlock_results = false,
        auto_recycle = false,
        energy_required = energy_required,
        ingredients = ingredients or {},
        results = results,
        main_product = MARKER_FLUID_NAME,
        localised_name = localised_name,
        always_show_made_in = true,
    }

    return recipe
end

local recipes = {
    make_hidden_recipe(VAT_IDLE_RECIPE_NAME, 60, {}),
    make_hidden_recipe("ei-auric-vat-drain", 15, {}),
    make_hidden_recipe("ei-auric-vat-bloom", 45, {}),
    make_hidden_recipe("ei-auric-vat-rest", 60, {}),
}

for _, band in ipairs(BAND_DEFS) do
    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-seed-" .. band.key,
        10,
        {
            {type = "item", name = "spoilage", amount = band.seed_spoilage},
            {type = "fluid", name = "ei-bio-oil", amount = band.seed_bio_oil, fluidbox_index = BIO_OIL_INPUT_FLUIDBOX},
        }
    )

    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-flood-" .. band.key,
        15,
        {
            {type = "fluid", name = "ei-dirty-water", amount = band.flood_dirty_water, fluidbox_index = DIRTY_WATER_INPUT_FLUIDBOX},
        }
    )

    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-ferment-" .. band.key,
        30,
        {
            {type = "item", name = "jelly", amount = band.ferment_jelly},
            {type = "item", name = "yumako-mash", amount = band.ferment_yumako},
        }
    )

    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-ferment-enriched-" .. band.key,
        30,
        {
            {type = "item", name = "jelly", amount = band.ferment_jelly},
            {type = "item", name = "yumako-mash", amount = band.ferment_yumako},
            {type = "item", name = "bioflux", amount = band.enrich_bioflux},
        }
    )

    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-drain-" .. band.key,
        15,
        {},
        {
            {type = "fluid", name = "ei-dirty-water", amount = band.drain_dirty_water, fluidbox_index = DIRTY_WATER_OUTPUT_FLUIDBOX},
        }
    )

    recipes[#recipes + 1] = make_hidden_recipe(
        "ei-auric-vat-drain-acidic-" .. band.key,
        15,
        {},
        {
            {type = "fluid", name = "ei-dirty-water", amount = band.drain_dirty_water, fluidbox_index = DIRTY_WATER_OUTPUT_FLUIDBOX},
            {type = "fluid", name = "ei-acidic-water", amount = band.drain_acidic_water, fluidbox_index = ACIDIC_WATER_OUTPUT_FLUIDBOX},
        }
    )
end

local telemetry_proxy = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
telemetry_proxy.name = TELEMETRY_PROXY_NAME
telemetry_proxy.icon = MARKER_ICON
telemetry_proxy.flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-flammable", "not-repairable", "not-upgradable", "hide-alt-info"}
telemetry_proxy.hidden = true
telemetry_proxy.selectable_in_game = false
telemetry_proxy.minable = nil
telemetry_proxy.max_health = 1
telemetry_proxy.collision_box = {{0, 0}, {0, 0}}
telemetry_proxy.selection_box = {{0, 0}, {0, 0}}
telemetry_proxy.activity_led_light = {intensity = 0, size = 0, color = {r = 1, g = 1, b = 1}}
telemetry_proxy.activity_led_sprites = {
    north = util.empty_sprite(),
    east = util.empty_sprite(),
    south = util.empty_sprite(),
    west = util.empty_sprite(),
}
telemetry_proxy.sprites = {
    north = util.empty_sprite(),
    east = util.empty_sprite(),
    south = util.empty_sprite(),
    west = util.empty_sprite(),
}
telemetry_proxy.circuit_wire_max_distance = default_circuit_wire_max_distance

local vat_entity = {
    type = "assembling-machine",
    name = VAT_NAME,
    icon = VAT_ICON_PATH,
    icon_size = 64,
    circuit_connector = circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 23, main_offset = util.by_pixel( 70.125,  55.125), shadow_offset = util.by_pixel( 70.125,  55.125), show_shadow = true },
            { variation = 23, main_offset = util.by_pixel( 70.125,  55.125), shadow_offset = util.by_pixel( 70.125,  55.125), show_shadow = true },
            { variation = 23, main_offset = util.by_pixel( 70.125,  55.125), shadow_offset = util.by_pixel( 70.125,  55.125), show_shadow = true },
            { variation = 23, main_offset = util.by_pixel( 70.125,  55.125), shadow_offset = util.by_pixel( 70.125,  55.125), show_shadow = true },
        }
    ),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {
        mining_time = 0.75,
        result = VAT_NAME,
    },
    max_health = 500,
    corpse = "big-remnants",
    dying_explosion = "biolab-explosion",
    impact_category = "organic",
    damaged_trigger_effect = hit_effects.entity(),
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    radius_visualisation_specification = {
        sprite = {
            filename = ei_graphics_other_path .. "radius.png",
            width = 256,
            height = 256,
        },
        distance = 20,
        draw_in_cursor = true,
        draw_on_selection = true,
    },
    map_color = ei_data.colors.assembler,
    crafting_categories = {VAT_CATEGORY_NAME},
    crafting_speed = 1,
    ingredient_count = 4,
    heating_energy = "200kW",
    energy_source = {
        type = "burner",
        fuel_categories = {"nutrients"},
        effectivity = 1,
        burner_usage = "nutrients",
        fuel_inventory_size = 1,
        usage_priority = "secondary-input",
        emissions_per_minute = {pollution = 6, spores = 8},
    },
    energy_usage = "1.25MW",
    allowed_effects = {"speed", "consumption", "pollution", "quality"},
    module_slots = 2,
    surface_conditions = {
        {property = "pressure", min = 2000, max = 2000},
    },
    fluid_boxes = {
        {
            volume = 300,
            filter = "ei-dirty-water",
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_pipe_big,
            pipe_connections = {
                {flow_direction = "input", direction = defines.direction.east, position = {2, -1}},
            },
            production_type = "input",
        },
        {
            volume = 300,
            filter = "ei-bio-oil",
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_pipe_big,
            pipe_connections = {
                {flow_direction = "input", direction = defines.direction.east, position = {2, 1}},
            },
            production_type = "input",
        },
        {
            volume = 300,
            filter = "ei-dirty-water",
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_pipe_big,
            pipe_connections = {
                {flow_direction = "output", direction = defines.direction.west, position = {-2, 1}},
            },
            production_type = "output",
        },
        {
            volume = 300,
            filter = "ei-acidic-water",
            pipe_covers = pipecoverspictures(),
            pipe_picture = ei_pipe_big,
            pipe_connections = {
                {flow_direction = "output", direction = defines.direction.west, position = {-2, -1}},
            },
            production_type = "output",
        },
        {
            volume = 10,
            filter = MARKER_FLUID_NAME,
            pipe_picture = util.empty_sprite(),
            pipe_covers = util.empty_sprite(),
            -- Keep this box in the machine but disconnected from player-built
            -- pipes so marker fluid stays internal.
            pipe_connections = {},
            production_type = "output",
        },
    },
    fluid_boxes_off_when_no_fluid_recipe = false,
    graphics_set = {
        animation = {
            layers = {
                {
                    filename = VAT_ENTITY_PATH .. "pathogen-lab-hr-animation-1.png",
                    size = {VAT_FRAME_SIZE, VAT_FRAME_SIZE},
                    shift = {0.0, -0.08},
                    scale = VAT_FRAME_SCALE,
                    line_length = 8,
                    frame_count = 1,
                },
                {
                    filename = VAT_ENTITY_PATH .. "pathogen-lab-hr-shadow.png",
                    size = {900, 700},
                    shift = {0.78, 0.42},
                    scale = 0.18,
                    line_length = 1,
                    frame_count = 1,
                    draw_as_shadow = true,
                },
            },
        },
        working_visualisations = {
            {
                animation = {
                    filename = VAT_ENTITY_PATH .. "pathogen-lab-hr-animation-1.png",
                    size = {VAT_FRAME_SIZE, VAT_FRAME_SIZE},
                    shift = {0.0, -0.08},
                    scale = VAT_FRAME_SCALE,
                    line_length = 8,
                    lines_per_file = 8,
                    frame_count = 60,
                    animation_speed = 0.35,
                },
            },
            {
                animation = {
                    filename = VAT_ENTITY_PATH .. "pathogen-lab-hr-emission-1.png",
                    size = {VAT_FRAME_SIZE, VAT_FRAME_SIZE},
                    shift = {0.0, -0.08},
                    scale = VAT_FRAME_SCALE,
                    line_length = 8,
                    lines_per_file = 8,
                    frame_count = 60,
                    animation_speed = 0.35,
                    draw_as_glow = true,
                    blend_mode = "additive",
                },
            },
            {
                light = {
                    type = "basic",
                    intensity = 1,
                    size = 18,
                    color = {r = 1.0, g = 0.50, b = 0.18},
                },
            },
        },
    },
    open_sound = {filename = "__base__/sound/open-close/fluid-open.ogg", volume = 0.55},
    close_sound = {filename = "__base__/sound/open-close/fluid-close.ogg", volume = 0.54},
    working_sound =
    {
      sound = {filename = "__space-age__/sound/entity/biochamber/biochamber-loop.ogg", volume = 0.4},
      max_sounds_per_prototype = 3,
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    water_reflection =
    {
      pictures =
      {
        filename = "__base__/graphics/entity/chemical-plant/chemical-plant-reflection.png",
        priority = "extra-high",
        width = 28,
        height = 36,
        shift = util.by_pixel(5, 60),
        variation_count = 4,
        scale = 5
      },
      rotate = false,
      orientation_to_variation = true
    },
}

local prototypes = {
    {
        type = "recipe-category",
        name = VAT_CATEGORY_NAME,
    },
    {
        type = "fluid",
        name = MARKER_FLUID_NAME,
        icon = MARKER_ICON,
        icon_size = 64,
        default_temperature = 25,
        max_temperature = 25,
        heat_capacity = "1kJ",
        base_color = {r = 0.78, g = 0.60, b = 0.20},
        flow_color = {r = 1.00, g = 0.78, b = 0.24},
        hidden = true,
        auto_barrel = false,
    },
    {
        type = "item",
        name = VAT_NAME,
        icon = VAT_ICON_PATH,
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-3",
        place_result = VAT_NAME,
        stack_size = 20,
        default_import_location = "gleba",
    },
    {
        type = "recipe",
        name = VAT_NAME,
        category = "crafting",
        energy_required = 12,
        ingredients = {
            {type = "item", name = "biochamber", amount = 1},
            {type = "item", name = "ei-purifier", amount = 1},
            {type = "item", name = "electric-engine-unit", amount = 8},
            {type = "item", name = "ei-tank-1", amount = 2},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 50},
            {type = "item", name = "bioflux", amount = 10},
        },
        results = {{type = "item", name = VAT_NAME, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = VAT_NAME,
    },
    {
        type = "technology",
        name = VAT_TECH_NAME,
        icon = VAT_TECH_ICON_PATH,
        icon_size = 256,
        prerequisites = {
            "ei-bio-oil",
            "bioflux",
            "ei-purifier",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = VAT_NAME,
            },
            {
                type = "unlock-recipe",
                recipe = "ei-auric-cyst-washing",
            },
        },
        unit = {
            count = 150,
            ingredients = ei_data.science["computer-age-space-gleba"],
            time = 30,
        },
        age = "computer-age-space-gleba",
    },
    vat_entity,
    telemetry_proxy,
    {
        type = "virtual-signal",
        name = "ei-auric-vat-vigor",
        icons = make_signal_icons(CYST_ICON_PATH, CYST_ICON_SIZE, ei_graphics_other_path .. "overlay_2.png", {r = 0.42, g = 0.96, b = 0.46, a = 0.95}, CYST_ICON_MIPMAPS),
        order = "ei-auric-a",
    },
    {
        type = "virtual-signal",
        name = "ei-auric-vat-contamination",
        icons = make_signal_icons(VAT_ICON_PATH, 64, ei_graphics_other_path .. "overlay_3.png", {r = 1.0, g = 0.34, b = 0.24, a = 0.95}),
        order = "ei-auric-b",
    },
    {
        type = "virtual-signal",
        name = "ei-auric-vat-band",
        icons = make_signal_icons(VAT_ICON_PATH, 64, ei_graphics_other_path .. "overlay_1.png", {r = 0.35, g = 0.72, b = 1.0, a = 0.95}),
        order = "ei-auric-c",
    },
    {
        type = "virtual-signal",
        name = "ei-auric-vat-claims",
        icons = make_signal_icons(VAT_ICON_PATH, 64, ei_graphics_other_path .. "overlay_4.png", {r = 0.86, g = 0.68, b = 0.20, a = 0.95}),
        order = "ei-auric-d",
    },
    {
        type = "virtual-signal",
        name = "ei-auric-vat-bloom",
        icons = make_signal_icons(CYST_ICON_PATH, CYST_ICON_SIZE, ei_graphics_other_path .. "overlay_4.png", {r = 1.0, g = 0.82, b = 0.22, a = 0.95}, CYST_ICON_MIPMAPS),
        order = "ei-auric-e",
    },
}

for _, recipe in ipairs(recipes) do
    prototypes[#prototypes + 1] = recipe
end

data:extend(prototypes)
