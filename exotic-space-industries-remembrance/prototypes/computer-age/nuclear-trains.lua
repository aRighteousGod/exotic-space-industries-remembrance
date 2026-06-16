--==============================================================================
-- ESIR FILE MAP
-- owns: data-stage static prototypes for Goliath, Black Ark, and Black Grail rolling stock
-- loaded_by: exotic-space-industries-remembrance\prototypes\computer-age\computer-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild, rolling-stock render refresh
--==============================================================================

local ei_data = require("lib/data")

local entity_path = ei_graphics_entity_4_path
local item_path = ei_graphics_item_4_path
local tech_path = ei_graphics_tech_4_path

local nuclear_locomotive_path = entity_path .. "nuclear-locomotive/"
local advanced_cargo_wagon_path = entity_path .. "advanced-cargo-wagon/"
local advanced_fluid_wagon_path = entity_path .. "advanced-fluid-wagon/"

local max_health_loco = 1200
local weight_loco = 1600
local weight_cargo = 600
local max_health_cargo = 720
local max_speed = 1.596
local max_speed_wagon = 2
local max_power = "1.6MW"
local braking_force = 17.5
local braking_force_wagon = 10
local friction_force = 0.3
local air_resistance = 0.00375
local drive_over_tie_speed = 0.5
local drive_over_tie_distance = 60

local nuclear_green = {r = 0.17647, g = 0.6274509, b = 0.274509, a = 1}
local goliath_hid_white = {r = 1, g = 1, b = 1, a = 1}
local cargo_gold = {r = 0.86, g = 0.64, b = 0.22, a = 1}
local locomotive_body_sprite_scale = 0.9975
local advanced_cargo_wagon_body_sprite_scale = 0.9
local advanced_fluid_wagon_body_sprite_scale = 0.9
local locomotive_body_shift = util.by_pixel(0, 7)
local advanced_cargo_wagon_body_shift = util.by_pixel(0, 4)
local advanced_fluid_wagon_body_shift = util.by_pixel(0, 4)

local function merge(target, source)
    if not source then return target end
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

local function shift_add(a, b)
    return {
        (a.x or a[1] or 0) + (b.x or b[1] or 0),
        (a.y or a[2] or 0) + (b.y or b[2] or 0),
    }
end

local function spritter_metadata(path)
    local metadata = require(path)
    if not metadata or not metadata.spritter then
        error("Invalid Spritter metadata file: " .. path)
    end
    return metadata
end

local function spritter_filenames(path, file_count)
    local filenames = {}
    for index = 0, file_count - 1 do
        filenames[index + 1] = path .. "-" .. index .. ".png"
    end
    return filenames
end

local function spritter_train_sheet(path, offset, extra, scale_multiplier)
    local metadata = spritter_metadata(path)
    return merge({
        priority = "very-low",
        filenames = spritter_filenames(path, metadata.file_count or 1),
        width = metadata.width,
        height = metadata.height,
        direction_count = metadata.sprite_count,
        line_length = metadata.line_length,
        lines_per_file = metadata.lines_per_file,
        scale = metadata.scale * (scale_multiplier or 1),
        shift = shift_add(metadata.shift, offset or {0, 0}),
        dice = 4,
        usage = "train",
    }, extra)
end

local nuclear_train_glow_layers = {
    {suffix = "glow", extra = {draw_as_glow = true}},
}

local advanced_cargo_wagon_layers = {
    {suffix = "mask", extra = {flags = {"mask"}, apply_runtime_tint = true}},
    {suffix = "glow", extra = {draw_as_glow = true}},
}
local advanced_fluid_wagon_layers = advanced_cargo_wagon_layers

local function spritter_layered_train_sheet(path, layer_specs, options)
    options = options or {}
    local offset = options.offset
    local scale_multiplier = options.scale_multiplier
    local layers = {spritter_train_sheet(path, offset, nil, scale_multiplier)}
    for _, layer_spec in ipairs(layer_specs) do
        layers[#layers + 1] = spritter_train_sheet(path .. "-" .. layer_spec.suffix, offset, layer_spec.extra, scale_multiplier)
    end
    return {layers = layers}
end

local standard_train_wheels = {
    rotated = util.sprite_load("__base__/graphics/entity/train-wheel/train-wheel", {
        priority = "very-low",
        direction_count = 256,
        scale = 0.5,
        shift = util.by_pixel(0, 8),
        usage = "train",
    }),
    sloped = util.sprite_load("__elevated-rails__/graphics/entity/train-wheel/train-wheel-sloped", {
        priority = "very-low",
        direction_count = 160,
        scale = 0.5,
        shift = util.by_pixel(0, 8),
        usage = "train",
    }),
    slope_angle_between_frames = 1.25,
}

local function goliath_hid_light(shift, source_orientation_offset)
    return {
        type = "oriented",
        minimum_darkness = 0.3,
        picture = {
            filename = nuclear_locomotive_path .. "hid-light-cone.png",
            priority = "medium",
            flags = {"light"},
            width = 400,
            height = 1013,
            scale = 1,
            draw_as_light = true,
            blend_mode = "multiplicative-with-alpha",
        },
        shift = shift,
        size = 0.95,
        intensity = 0.86,
        color = table.deepcopy(goliath_hid_white),
        source_orientation_offset = source_orientation_offset,
    }
end

local function goliath_hid_front_light()
    return {
        goliath_hid_light({-0.75, -13.4}, -0.018),
        goliath_hid_light({0.75, -13.4}, 0.018),
    }
end

local function nuclear_train_smoke()
    local smoke = table.deepcopy(data.raw["trivial-smoke"]["train-smoke"])
    smoke.name = "ei-nuclear-train-smoke"
    smoke.start_scale = 1
    smoke.end_scale = 1.2
    smoke.duration = 1200
    smoke.fade_away_duration = 900
    smoke.color = {r = 0.82, g = 0.94, b = 1.0, a = 0.24}
    return smoke
end

local nuclear_locomotive_item = table.deepcopy(data.raw["item-with-entity-data"].locomotive)
nuclear_locomotive_item.name = "ei-nuclear-locomotive"
nuclear_locomotive_item.localised_name = {"item-name.ei-nuclear-locomotive"}
nuclear_locomotive_item.icon = item_path .. "nuclear-locomotive.png"
nuclear_locomotive_item.icon_size = 128
nuclear_locomotive_item.icon_mipmaps = 3
nuclear_locomotive_item.subgroup = "ei-trains"
nuclear_locomotive_item.order = "c1"
nuclear_locomotive_item.place_result = "ei-nuclear-locomotive"
nuclear_locomotive_item.stack_size = 5

local advanced_cargo_wagon_item = table.deepcopy(data.raw["item-with-entity-data"]["cargo-wagon"])
advanced_cargo_wagon_item.name = "ei-advanced-cargo-wagon"
advanced_cargo_wagon_item.localised_name = {"item-name.ei-advanced-cargo-wagon"}
advanced_cargo_wagon_item.icon = item_path .. "advanced-cargo-wagon.png"
advanced_cargo_wagon_item.icon_size = 128
advanced_cargo_wagon_item.icon_mipmaps = 3
advanced_cargo_wagon_item.subgroup = "ei-trains"
advanced_cargo_wagon_item.order = "c2"
advanced_cargo_wagon_item.place_result = "ei-advanced-cargo-wagon"
advanced_cargo_wagon_item.stack_size = 5

local advanced_fluid_wagon_item = table.deepcopy(data.raw["item-with-entity-data"]["fluid-wagon"])
advanced_fluid_wagon_item.name = "ei-advanced-fluid-wagon"
advanced_fluid_wagon_item.localised_name = {"item-name.ei-advanced-fluid-wagon"}
advanced_fluid_wagon_item.icon = item_path .. "advanced-fluid-wagon.png"
advanced_fluid_wagon_item.icon_size = 128
advanced_fluid_wagon_item.icon_mipmaps = 3
advanced_fluid_wagon_item.subgroup = "ei-trains"
advanced_fluid_wagon_item.order = "c3"
advanced_fluid_wagon_item.place_result = "ei-advanced-fluid-wagon"
advanced_fluid_wagon_item.stack_size = 5

local nuclear_locomotive = table.deepcopy(data.raw.locomotive.locomotive)
nuclear_locomotive.name = "ei-nuclear-locomotive"
nuclear_locomotive.localised_name = {"entity-name.ei-nuclear-locomotive"}
nuclear_locomotive.icon = item_path .. "nuclear-locomotive.png"
nuclear_locomotive.icon_size = 128
nuclear_locomotive.icon_mipmaps = 3
nuclear_locomotive.minable.result = "ei-nuclear-locomotive"
nuclear_locomotive.max_health = max_health_loco
nuclear_locomotive.weight = weight_loco
nuclear_locomotive.max_power = max_power
nuclear_locomotive.max_speed = max_speed
nuclear_locomotive.braking_force = braking_force
nuclear_locomotive.friction_force = friction_force
nuclear_locomotive.air_resistance = air_resistance
nuclear_locomotive.drive_over_tie_trigger_minimal_speed = drive_over_tie_speed
nuclear_locomotive.tie_distance = drive_over_tie_distance
nuclear_locomotive.color = table.deepcopy(nuclear_green)
nuclear_locomotive.default_copy_color_from_train_stop = false
nuclear_locomotive.resistances = {
    {type = "fire", decrease = 30, percent = 75},
    {type = "cold", decrease = 30, percent = 75},
    {type = "physical", decrease = 30, percent = 60},
    {type = "impact", decrease = 100, percent = 80},
    {type = "explosion", decrease = 30, percent = 60},
    {type = "acid", decrease = 12, percent = 50},
}
nuclear_locomotive.energy_source.effectivity = 0.5
nuclear_locomotive.energy_source.emissions_per_minute = {pollution = 1.25}
nuclear_locomotive.energy_source.fuel_categories = {"ei-nuclear-fuel-cell", "ei-nuclear-fuel", "ei-fusion-fuel"}
nuclear_locomotive.energy_source.fuel_inventory_size = 1
nuclear_locomotive.energy_source.burnt_inventory_size = 1
nuclear_locomotive.energy_source.smoke = {
    {
        name = "ei-nuclear-train-smoke",
        deviation = {0.08, 0.08},
        frequency = 15,
        position = {0, 1.4},
        starting_frame = 0,
        starting_frame_deviation = 60,
        height = 1.1,
        height_deviation = 0.08,
        starting_vertical_speed = 0.055,
        starting_vertical_speed_deviation = 0.05,
    },
}
nuclear_locomotive.front_light = goliath_hid_front_light()
nuclear_locomotive.front_light_pictures = nil
nuclear_locomotive.pictures = {
    rotated = spritter_layered_train_sheet(nuclear_locomotive_path .. "body", nuclear_train_glow_layers, {
        offset = locomotive_body_shift,
        scale_multiplier = locomotive_body_sprite_scale,
    }),
    sloped = spritter_layered_train_sheet(nuclear_locomotive_path .. "sloped", nuclear_train_glow_layers, {
        offset = locomotive_body_shift,
        scale_multiplier = locomotive_body_sprite_scale,
    }),
    slope_angle_between_frames = 1.25,
}
nuclear_locomotive.wheels = table.deepcopy(standard_train_wheels)
nuclear_locomotive.working_sound = {
    main_sounds = {
        {
            sound = {
                filename = ei_sounds_4_path .. "nuclear-locomotive-engine.ogg",
                volume = 1.0,
                speed = 1.0,
                audible_distance_modifier = 1.15,
                modifiers = {
                    volume_multiplier("main-menu", 2.0),
                    volume_multiplier("driving", 0.9),
                    volume_multiplier("tips-and-tricks", 0.8),
                    volume_multiplier("elevation", 0.75),
                },
            },
            match_volume_to_activity = true,
            activity_to_volume_modifiers = {
                multiplier = 2.0,
                maximum = 1.0,
                offset = 1.0,
            },
            match_speed_to_activity = true,
            activity_to_speed_modifiers = {
                multiplier = 0.35,
                minimum = 0.98,
                maximum = 1.15,
                offset = 0.98,
            },
        },
        {
            sound = {
                filename = ei_sounds_4_path .. "nuclear-locomotive-engine.ogg",
                volume = 0.60,
                speed = 0.86,
                audible_distance_modifier = 1.1,
                modifiers = {
                    volume_multiplier("main-menu", 2.0),
                    volume_multiplier("driving", 0.85),
                    volume_multiplier("tips-and-tricks", 0.8),
                },
            },
            match_volume_to_activity = true,
            activity_to_volume_modifiers = {
                multiplier = 1.75,
                offset = 1.7,
                minimum = 0.12,
                inverted = true,
            },
        },
    },
    max_sounds_per_prototype = 2,
    activate_sound = {filename = "__base__/sound/train-engine-start.ogg", volume = 0.35},
    deactivate_sound = {filename = "__base__/sound/train-engine-stop.ogg", volume = 0.35},
}

local advanced_cargo_wagon = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
advanced_cargo_wagon.name = "ei-advanced-cargo-wagon"
advanced_cargo_wagon.localised_name = {"entity-name.ei-advanced-cargo-wagon"}
advanced_cargo_wagon.icon = item_path .. "advanced-cargo-wagon.png"
advanced_cargo_wagon.icon_size = 128
advanced_cargo_wagon.icon_mipmaps = 3
advanced_cargo_wagon.minable.result = "ei-advanced-cargo-wagon"
advanced_cargo_wagon.max_health = max_health_cargo
advanced_cargo_wagon.weight = weight_cargo
advanced_cargo_wagon.max_speed = max_speed_wagon
advanced_cargo_wagon.braking_force = braking_force_wagon
advanced_cargo_wagon.inventory_size = 50
advanced_cargo_wagon.color = table.deepcopy(cargo_gold)
advanced_cargo_wagon.allow_manual_color = true
advanced_cargo_wagon.default_copy_color_from_train_stop = true
advanced_cargo_wagon.resistances = {
    {type = "fire", decrease = 30, percent = 75},
    {type = "cold", decrease = 30, percent = 75},
    {type = "physical", decrease = 20, percent = 60},
    {type = "impact", decrease = 50, percent = 80},
    {type = "explosion", decrease = 20, percent = 60},
    {type = "acid", decrease = 12, percent = 50},
}
advanced_cargo_wagon.pictures = {
    rotated = spritter_layered_train_sheet(advanced_cargo_wagon_path .. "body", advanced_cargo_wagon_layers, {
        offset = advanced_cargo_wagon_body_shift,
        scale_multiplier = advanced_cargo_wagon_body_sprite_scale,
    }),
    sloped = spritter_layered_train_sheet(advanced_cargo_wagon_path .. "sloped", advanced_cargo_wagon_layers, {
        offset = advanced_cargo_wagon_body_shift,
        scale_multiplier = advanced_cargo_wagon_body_sprite_scale,
    }),
    slope_back_equals_front = false,
    slope_angle_between_frames = 1.25,
}
advanced_cargo_wagon.horizontal_doors = nil
advanced_cargo_wagon.vertical_doors = nil
advanced_cargo_wagon.wheels = table.deepcopy(standard_train_wheels)

local advanced_fluid_wagon = table.deepcopy(data.raw["fluid-wagon"]["fluid-wagon"])
advanced_fluid_wagon.name = "ei-advanced-fluid-wagon"
advanced_fluid_wagon.localised_name = {"entity-name.ei-advanced-fluid-wagon"}
advanced_fluid_wagon.icon = item_path .. "advanced-fluid-wagon.png"
advanced_fluid_wagon.icon_size = 128
advanced_fluid_wagon.icon_mipmaps = 3
advanced_fluid_wagon.minable.result = "ei-advanced-fluid-wagon"
advanced_fluid_wagon.max_health = max_health_cargo
advanced_fluid_wagon.weight = weight_cargo
advanced_fluid_wagon.max_speed = max_speed_wagon
advanced_fluid_wagon.braking_force = braking_force_wagon
advanced_fluid_wagon.capacity = 75000
advanced_fluid_wagon.color = table.deepcopy(cargo_gold)
advanced_fluid_wagon.allow_manual_color = true
advanced_fluid_wagon.default_copy_color_from_train_stop = true
advanced_fluid_wagon.resistances = {
    {type = "fire", decrease = 30, percent = 75},
    {type = "cold", decrease = 30, percent = 75},
    {type = "physical", decrease = 20, percent = 60},
    {type = "impact", decrease = 50, percent = 80},
    {type = "explosion", decrease = 20, percent = 60},
    {type = "acid", decrease = 12, percent = 50},
}
advanced_fluid_wagon.pictures = {
    rotated = spritter_layered_train_sheet(advanced_fluid_wagon_path .. "body", advanced_fluid_wagon_layers, {
        offset = advanced_fluid_wagon_body_shift,
        scale_multiplier = advanced_fluid_wagon_body_sprite_scale,
    }),
    sloped = spritter_layered_train_sheet(advanced_fluid_wagon_path .. "sloped", advanced_fluid_wagon_layers, {
        offset = advanced_fluid_wagon_body_shift,
        scale_multiplier = advanced_fluid_wagon_body_sprite_scale,
    }),
    slope_back_equals_front = false,
    slope_angle_between_frames = 1.25,
}
advanced_fluid_wagon.wheels = table.deepcopy(standard_train_wheels)

data:extend({
    nuclear_train_smoke(),
    nuclear_locomotive_item,
    advanced_cargo_wagon_item,
    advanced_fluid_wagon_item,
    nuclear_locomotive,
    advanced_cargo_wagon,
    advanced_fluid_wagon,
    {
        name = "ei-nuclear-locomotive",
        type = "recipe",
        category = "crafting",
        energy_required = 7,
        ingredients = {
            {type = "item", name = "locomotive", amount = 1},
            {type = "item", name = "processing-unit", amount = 7},
            {type = "item", name = "ei-energy-crystal", amount = 16},
            {type = "item", name = "ei-carbon", amount = 40},
            {type = "item", name = "ei-fission-tech", amount = 100},
            {type = "item", name = "ei-advanced-motor", amount = 8},
            {type = "item", name = "ei-lead-ingot", amount = 30},
        },
        results = {{type = "item", name = "ei-nuclear-locomotive", amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-nuclear-locomotive",
    },
    {
        name = "ei-advanced-cargo-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 7,
        ingredients = {
            {type = "item", name = "ei-carbon", amount = 30},
            {type = "item", name = "ei-ceramic", amount = 15},
            {type = "item", name = "plastic-bar", amount = 12},
            {type = "item", name = "low-density-structure", amount = 15},
            {type = "item", name = "cargo-wagon", amount = 1},
        },
        results = {{type = "item", name = "ei-advanced-cargo-wagon", amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-cargo-wagon",
    },
    {
        name = "ei-advanced-fluid-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 7,
        ingredients = {
            {type = "item", name = "ei-carbon", amount = 30},
            {type = "item", name = "ei-ceramic", amount = 15},
            {type = "item", name = "plastic-bar", amount = 12},
            {type = "item", name = "low-density-structure", amount = 15},
            {type = "item", name = "storage-tank", amount = 1},
            {type = "item", name = "fluid-wagon", amount = 1},
        },
        results = {{type = "item", name = "ei-advanced-fluid-wagon", amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-fluid-wagon",
    },
    {
        name = "ei-advanced-cargo-wagon",
        type = "technology",
        icon = tech_path .. "advanced-cargo-wagon.png",
        icon_size = 512,
        prerequisites = {"ei-advanced-computer-age-tech", "railway", "ei-carbon-manipulation"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-advanced-cargo-wagon"},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20,
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-advanced-fluid-wagon",
        type = "technology",
        icon = tech_path .. "advanced-fluid-wagon.png",
        icon_size = 512,
        prerequisites = {"ei-advanced-computer-age-tech", "railway", "ei-carbon-manipulation"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-advanced-fluid-wagon"},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20,
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-nuclear-locomotive",
        type = "technology",
        icon = tech_path .. "nuclear-locomotive.png",
        icon_size = 512,
        prerequisites = {"ei-advanced-computer-age-tech", "railway", "ei-carbon-manipulation", "nuclear-power"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-nuclear-locomotive"},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20,
        },
        age = "advanced-computer-age",
    },
})
