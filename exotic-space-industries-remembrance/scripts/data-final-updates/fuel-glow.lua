--==============================================================================
-- ESIR FILE MAP
-- owns: data-final curated fuel glow colors and high-temperature reactor recipe tinting
-- loaded_by: exotic-space-industries-remembrance\data-final-fixes.lua
-- cadence: data-final stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: fuel prototype, reactor visual, or HTR recipe tint changes
--==============================================================================

local ei_lib = require("lib/lib")

local function color(r, g, b, a)
    return {r = r, g = g, b = b, a = a or 1}
end

local function copy_color(source, alpha)
    if type(source) ~= "table" then
        return nil
    end

    return {
        r = source.r,
        g = source.g,
        b = source.b,
        a = alpha or source.a or 1,
    }
end

local function recipe_tint(primary, secondary, tertiary, quaternary)
    return {
        primary = copy_color(primary),
        secondary = copy_color(secondary or primary),
        tertiary = copy_color(tertiary or secondary or primary),
        quaternary = copy_color(quaternary or tertiary or secondary or primary),
    }
end

local fuel_item_types = {
    "item",
    "capsule",
    "tool",
    "ammo",
    "module",
    "rail-planner",
    "item-with-entity-data",
}

local fuel_glows = {
    -- Vanilla and Space Age fuels that ESIR retunes, exposes, or commonly routes into burners.
    ["wood"] = color(1.00, 0.42, 0.14, 0.35),
    ["tree-seed"] = color(0.70, 0.92, 0.28, 0.34),
    ["coal"] = color(0.94, 0.34, 0.12, 0.48),
    ["carbon"] = color(0.70, 0.18, 0.08, 0.44),
    ["solid-fuel"] = color(1.00, 0.66, 0.26, 0.62),
    ["rocket-fuel"] = color(1.00, 0.90, 0.40, 0.82),
    ["nuclear-fuel"] = color(0.70, 1.00, 0.42, 0.95),
    ["uranium-fuel-cell"] = color(0.18, 0.96, 0.20, 0.95),
    ["fusion-power-cell"] = color(0.74, 0.88, 1.00, 0.86),
    ["spoilage"] = color(0.42, 0.60, 0.15, 0.32),
    ["nutrients"] = color(0.46, 0.98, 0.24, 0.50),
    ["bioflux"] = color(0.20, 1.00, 0.72, 0.68),
    ["biter-egg"] = color(0.72, 1.00, 0.24, 0.66),
    ["pentapod-egg"] = color(0.88, 0.95, 0.30, 0.66),
    ["jelly"] = color(0.68, 0.95, 0.24, 0.46),
    ["jellynut"] = color(0.78, 0.92, 0.24, 0.54),
    ["jellynut-seed"] = color(0.50, 0.88, 0.20, 0.40),
    ["yumako"] = color(0.98, 0.68, 0.22, 0.48),
    ["yumako-mash"] = color(0.86, 0.52, 0.18, 0.42),
    ["yumako-seed"] = color(0.82, 0.72, 0.20, 0.40),
    ["nettles"] = color(0.34, 0.88, 0.20, 0.38),
    ["stingfrond-seed"] = color(0.58, 0.80, 0.16, 0.34),

    -- ESIR fuel lineages.
    ["ei-charcoal"] = color(0.92, 0.28, 0.08, 0.38),
    ["ei-coke"] = color(0.95, 0.24, 0.06, 0.48),
    ["ei-crushed-coke"] = color(0.90, 0.20, 0.06, 0.42),
    ["ei-coke-pellets"] = color(1.00, 0.56, 0.18, 0.66),
    ["ei-crushed-coal"] = color(0.78, 0.23, 0.08, 0.38),
    ["ei-diesel-fuel-unit"] = color(1.00, 0.54, 0.12, 0.70),
    ["ei-advanced-rocket-fuel"] = color(1.00, 0.96, 0.55, 0.90),
    ["ei-bio-matter"] = color(0.24, 1.00, 0.44, 0.62),
    ["ei-uranium-235-fuel"] = color(0.22, 1.00, 0.18, 0.95),
    ["ei-uranium-233-fuel"] = color(0.14, 1.00, 0.70, 0.95),
    ["ei-plutonium-239-fuel"] = color(0.82, 0.32, 1.00, 0.95),
    ["ei-pl-mix"] = color(0.78, 1.00, 0.58, 0.82),
    ["ei-dd-mix"] = color(0.46, 0.92, 1.00, 0.86),
    ["ei-dl-mix"] = color(0.34, 1.00, 0.78, 0.88),
    ["ei-dt-mix"] = color(0.78, 0.86, 1.00, 0.92),
    ["ei-tt-mix"] = color(1.00, 0.38, 0.42, 0.92),
    ["ei-dh-mix"] = color(0.66, 0.72, 1.00, 0.88),
    ["ei-hl-mix"] = color(0.76, 0.42, 1.00, 0.88),
    ["ei-th-mix"] = color(1.00, 0.42, 0.76, 0.94),
    ["ei-hh-mix"] = color(1.00, 0.28, 0.95, 0.95),
}

local function set_fuel_glow(name, glow)
    for _, item_type in pairs(fuel_item_types) do
        local prototypes = data.raw[item_type]
        local prototype = prototypes and prototypes[name]
        if prototype and prototype.fuel_value then
            prototype.fuel_glow_color = copy_color(glow)
            return
        end
    end
end

local function apply_fuel_glows()
    for name, glow in pairs(fuel_glows) do
        set_fuel_glow(name, glow)
    end

    local item_prototypes = data.raw.item or {}
    local em_train_glow = color(0.18, 0.78, 1.00, 0.76)
    for name, prototype in pairs(item_prototypes) do
        if ei_lib.startswith(name, "ei_emt-fuel_")
            and prototype.fuel_value
            and prototype.fuel_category == "ei_emt-fuel" then
            prototype.fuel_glow_color = copy_color(em_train_glow)
        end
    end
end

local function light_flicker(glow, minimum_intensity, maximum_intensity)
    return {
        color = copy_color(glow, 1),
        minimum_intensity = minimum_intensity or 0.6,
        maximum_intensity = maximum_intensity or 0.9,
    }
end

local function set_energy_source_light(prototype_type, prototype_name, glow, minimum_intensity, maximum_intensity)
    local prototype = data.raw[prototype_type] and data.raw[prototype_type][prototype_name]
    local energy_source = prototype and prototype.energy_source
    if not energy_source then
        return
    end

    energy_source.light_flicker = light_flicker(glow, minimum_intensity, maximum_intensity)
end

local function set_burner_light(prototype_type, prototype_name, glow, minimum_intensity, maximum_intensity)
    local prototype = data.raw[prototype_type] and data.raw[prototype_type][prototype_name]
    local burner = prototype and prototype.burner
    if not burner then
        return
    end

    burner.light_flicker = light_flicker(glow, minimum_intensity, maximum_intensity)
end

local function add_animation_light_layer(animation, glow, alpha)
    if type(animation) ~= "table" then
        return
    end

    local layers = animation.layers
    if type(layers) ~= "table" or type(layers[1]) ~= "table" then
        return
    end

    local layer = table.deepcopy(layers[1])
    layer.draw_as_light = true
    layer.blend_mode = "additive"
    layer.tint = copy_color(glow, alpha or glow.a or 0.45)
    table.insert(layers, layer)
end

local function apply_fluid_consumer_lights()
    local oil_flame = color(1.00, 0.46, 0.12, 1)
    local drill_flame = color(0.92, 0.72, 0.42, 1)
    local cryo_glow = color(0.30, 0.88, 1.00, 1)
    local critical_steam = color(0.84, 0.96, 1.00, 1)

    set_energy_source_light("boiler", "ei-fluid-boiler", oil_flame, 0.72, 0.92)
    set_energy_source_light("reactor", "ei-fluid-heater", oil_flame, 0.70, 0.90)

    set_energy_source_light("mining-drill", "ei-deep-drill", drill_flame, 0.46, 0.70)
    set_energy_source_light("mining-drill", "ei-advanced-deep-drill", drill_flame, 0.46, 0.76)
    set_energy_source_light("mining-drill", "ei-deep-pumpjack", drill_flame, 0.42, 0.68)

    set_energy_source_light("assembling-machine", "ei-copper-beacon-source", cryo_glow, 0.34, 0.62)
    set_energy_source_light("assembling-machine", "ei-iron-beacon-source", cryo_glow, 0.34, 0.62)

    local turbine = data.raw.generator and data.raw.generator["ei-big-turbine"]
    if turbine then
        add_animation_light_layer(turbine.horizontal_animation, critical_steam, 0.38)
        add_animation_light_layer(turbine.vertical_animation, critical_steam, 0.38)
    end
end

local reactor_glow_defaults = {
    ["ei-burner-heater"] = color(1.00, 0.56, 0.18, 1),
    ["heating-tower"] = color(1.00, 0.56, 0.18, 1),
    ["nuclear-reactor"] = color(0.22, 1.00, 0.20, 1),
}

local function apply_reactor_fuel_glows()
    for name, glow in pairs(reactor_glow_defaults) do
        local reactor = data.raw.reactor and data.raw.reactor[name]
        if reactor and reactor.working_light_picture then
            reactor.use_fuel_glow_color = true
            reactor.default_fuel_glow_color = copy_color(glow)
        end
    end
end

local htr_recipe_tints = {
    ["ei-htr-uranium-235"] = recipe_tint(
        color(0.22, 1.00, 0.18, 0.78),
        color(0.56, 1.00, 0.42, 0.48),
        color(0.12, 0.56, 0.10, 0.40),
        color(0.80, 1.00, 0.62, 0.34)
    ),
    ["ei-htr-uranium-233"] = recipe_tint(
        color(0.14, 1.00, 0.70, 0.78),
        color(0.42, 1.00, 0.92, 0.48),
        color(0.06, 0.54, 0.42, 0.40),
        color(0.72, 1.00, 0.92, 0.34)
    ),
    ["ei-htr-plutonium-239"] = recipe_tint(
        color(0.82, 0.32, 1.00, 0.78),
        color(1.00, 0.52, 0.92, 0.48),
        color(0.36, 0.10, 0.52, 0.40),
        color(0.92, 0.74, 1.00, 0.34)
    ),
    ["ei-htr-thorium-232"] = recipe_tint(
        color(0.78, 0.90, 1.00, 0.72),
        color(1.00, 0.78, 0.42, 0.46),
        color(0.36, 0.44, 0.52, 0.38),
        color(0.96, 0.88, 0.66, 0.34)
    ),
}

local function apply_htr_recipe_tints()
    for name, tint in pairs(htr_recipe_tints) do
        local recipe = data.raw.recipe and data.raw.recipe[name]
        if recipe then
            recipe.crafting_machine_tint = tint
        end
    end
end

local function add_htr_recipe_glow()
    local htr = data.raw["assembling-machine"] and data.raw["assembling-machine"]["ei-high-temperature-reactor"]
    if not htr then
        return
    end

    htr.graphics_set = htr.graphics_set or {}
    htr.graphics_set.working_visualisations = htr.graphics_set.working_visualisations or {}
    local working_visualisations = htr.graphics_set.working_visualisations

    table.insert(working_visualisations, {
        apply_recipe_tint = "primary",
        animation = {
            filename = ei_graphics_entity_path.."high-temperature-reactor_animation.png",
            size = {512, 512},
            shift = {0, 0},
            scale = 0.35,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.4,
            run_mode = "backward",
            draw_as_light = true,
            blend_mode = "additive",
        },
    })

    table.insert(working_visualisations, {
        apply_recipe_tint = "secondary",
        light = {
            type = "basic",
            intensity = 0.82,
            size = 18,
        },
    })
end

apply_fuel_glows()
apply_fluid_consumer_lights()
apply_reactor_fuel_glows()
apply_htr_recipe_tints()
add_htr_recipe_glow()
