local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

local exotic_magazine_effects = require("exotic-magazine-effects")

local base_mag_icon = "__base__/graphics/icons/uranium-rounds-magazine.png"
local base_mag_light_icon = "__base__/graphics/icons/uranium-rounds-magazine-light.png"
local exotic_mag_picture_path = ei_graphics_item_4_path.."exotic-magazines/"
local advanced_circuit_icon = "__base__/graphics/icons/advanced-circuit.png"
local battery_icon = "__base__/graphics/icons/battery.png"
local explosives_icon = "__base__/graphics/icons/explosives.png"
local sulfur_icon = "__base__/graphics/icons/sulfur.png"

local high_energy_crystal_icon = ei_graphics_item_path .. "high-energy-crystal.png"
local copper_mech_icon = ei_graphics_item_path .. "copper-mechanical-parts.png"
local steel_mech_icon = ei_graphics_item_path .. "steel-mechanical-parts.png"
local ceramic_icon = ei_graphics_3_path .. "graphics/items/ceramic.png"
local energy_crystal_icon = ei_graphics_3_path .. "graphics/items/energy-crystal.png"
local insulated_wire_icon = ei_graphics_3_path .. "graphics/items/insulated-wire-1.png"
local fluorite_icon = ei_graphics_item_path .. "fluorite.png"
local lead_ingot_icon = ei_graphics_item_path .. "lead-ingot.png"
local lithium_crystal_icon = ei_graphics_item_path .. "lithium-crystal.png"
local cryodust_icon = ei_graphics_item_2_path .. "cryodust.png"
local condensed_cryodust_icon = ei_graphics_item_2_path .. "condensed-cryodust.png"
local charged_neutron_container_icon = ei_graphics_item_path .. "charged-neutron-container.png"

local nitric_acid_icon = ei_graphics_fluid_path .. "nitric-acid.png"
local oxygen_difluoride_icon = ei_graphics_fluid_path .. "oxygen-difluoride.png"
local concentrated_morphium_icon = ei_graphics_fluid_path .. "concentrated-morphium.png"
local uranium_hexafluorite_icon = ei_graphics_fluid_path .. "uranium-hexafluorite.png"

local function push_if_value(target, value)
    if value then
        target[#target + 1] = value
    end
end

local function make_icons(base_icon, primary_icon, primary_shift, primary_tint, secondary_icon, secondary_shift, secondary_tint, light_tint)
    local icons = {
        {
            icon = base_icon,
            icon_size = 64,
        },
        {
            icon = base_mag_light_icon,
            icon_size = 64,
            tint = light_tint,
        },
    }

    push_if_value(icons, primary_icon and {
        icon = primary_icon,
        icon_size = 64,
        scale = 0.34,
        shift = primary_shift,
        tint = primary_tint,
    })
    push_if_value(icons, secondary_icon and {
        icon = secondary_icon,
        icon_size = 64,
        scale = 0.24,
        shift = secondary_shift,
        tint = secondary_tint,
    })

    return icons
end

local function make_mag_pictures(ammo_name)
    local picture_name = ammo_name:gsub("^ei%-", "")

    return {
        layers = {
        {
            filename = exotic_mag_picture_path .. picture_name .. ".png",
            size = 64,
            mipmap_count = 4,
            scale = 0.5,
        },
        },
    }
end

local function make_item(name, icons, pictures, order)
    local item = {
        type = "item",
        name = name,
        icons = icons,
        icon_size = 64,
        subgroup = "intermediate-product",
        order = order,
        stack_size = 100,
    }

    if pictures then
        item.pictures = pictures
    end

    return item
end

local function make_recipe(name, category, energy_required, ingredients, results)
    return {
        type = "recipe",
        name = name,
        category = category,
        energy_required = energy_required,
        ingredients = ingredients,
        results = results,
        enabled = false,
        always_show_made_in = true,
        main_product = results[1].name,
    }
end

local function make_bullet_ammo(def)
    local target_effects = {
        {
            type = "create-entity",
            entity_name = def.hit_effect_name,
            offsets = {{0, 1}},
            offset_deviation = {{-0.22, -0.22}, {0.22, 0.22}},
            only_when_visible = true,
            trigger_created_entity = true,
        },
    }

    for _, damage in ipairs(def.direct_damages) do
        target_effects[#target_effects + 1] = {
            type = "damage",
            damage = {
                amount = damage.amount,
                type = damage.type,
            },
        }
    end

    target_effects[#target_effects + 1] = {
        type = "create-sticker",
        sticker = def.sticker_name,
    }
    if def.accent_sticker_name then
        target_effects[#target_effects + 1] = {
            type = "create-sticker",
            sticker = def.accent_sticker_name,
        }
    end
    target_effects[#target_effects + 1] = {
        type = "activate-impact",
        deliver_category = "bullet",
    }

    local action_delivery = {
        type = "instant",
        target_effects = target_effects,
    }
    local source_effects = exotic_magazine_effects.source_effects_by_ammo_name[def.name]
    if source_effects and #source_effects > 0 then
        action_delivery.source_effects = table.deepcopy(source_effects)
    end

    return {
        type = "ammo",
        name = def.name,
        icons = make_icons(
            base_mag_icon,
            def.primary_icon,
            def.primary_icon_shift,
            def.primary_icon_tint,
            def.secondary_icon,
            def.secondary_icon_shift,
            def.secondary_icon_tint,
            def.light_tint
        ),
        icon_size = 64,
        subgroup = "ammo",
        order = def.order,
        magazine_size = 10,
        pictures = make_mag_pictures(def.name),
        stack_size = 100,
        ammo_category = "bullet",
        ammo_type = {
            action = {
                type = "direct",
                action_delivery = action_delivery,
            },
        },
    }
end

local function make_tech(name, icons, prerequisites, science_key, effects, age, order)
    return {
        type = "technology",
        name = name,
        icons = icons,
        icon_size = 64,
        prerequisites = prerequisites,
        effects = effects,
        unit = {
            count = 100,
            ingredients = ei_data.science[science_key],
            time = 20,
        },
        age = age,
        order = order,
    }
end

local body_icons = {
    {icon = steel_mech_icon, icon_size = 64},
    {icon = copper_mech_icon, icon_size = 64, scale = 0.28, shift = {8, -8}},
    {icon = ceramic_icon, icon_size = 64, scale = 0.24, shift = {-8, 8}},
}

local driver_icons = {
    {icon = advanced_circuit_icon, icon_size = 64},
    {icon = battery_icon, icon_size = 64, scale = 0.28, shift = {8, -8}},
    {icon = energy_crystal_icon, icon_size = 64, scale = 0.22, shift = {-8, 8}},
}

local core_icons = {
    {icon = base_mag_icon, icon_size = 64},
    {icon = explosives_icon, icon_size = 64, scale = 0.3, shift = {8, -8}},
    {icon = high_energy_crystal_icon, icon_size = 64, scale = 0.22, shift = {-8, 8}},
}

local body_item = make_item("ei-exotic-magazine-body", body_icons, nil, "q[exotic-magazine]-a")
local driver_item = make_item("ei-exotic-magazine-driver", driver_icons, nil, "q[exotic-magazine]-b")
local core_item = make_item("ei-exotic-magazine-core", core_icons, nil, "q[exotic-magazine]-c")

local ammo_defs = {
    {
        key = "compound",
        name = "ei-compound-ammo",
        payload_name = "ei-magazine-payload-compound",
        tech_name = "ei-exotic-magazines",
        order = "a[basic-clips]-d[compound-ammo]",
        primary_icon = high_energy_crystal_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = explosives_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.78, g = 0.98, b = 1.0, a = 0.95},
        direct_damages = {
            {amount = 44, type = "physical"},
            {amount = 28, type = "electric"},
        },
        hit_effect_name = "ei-compound-ammo-impact-burst",
        sticker_name = "ei-compound-ammo-sticker",
        payload_category = "crafting",
        payload_ingredients = {
            {type = "item", name = "ei-energy-crystal", amount = 4},
            {type = "item", name = "explosives", amount = 4},
        },
        payload_icons = {
            {icon = high_energy_crystal_icon, icon_size = 64},
            {icon = explosives_icon, icon_size = 64, scale = 0.28, shift = {8, -8}},
        },
    },
    {
        key = "corrosive",
        name = "ei-corrosive-ammo",
        payload_name = "ei-magazine-payload-corrosive",
        tech_name = "ei-corrosive-magazines",
        order = "a[basic-clips]-e[corrosive-ammo]",
        primary_icon = nitric_acid_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = sulfur_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.48, g = 1.0, b = 0.42, a = 0.95},
        direct_damages = {
            {amount = 40, type = "physical"},
            {amount = 18, type = "acid"},
        },
        hit_effect_name = "ei-corrosive-ammo-impact-burst",
        sticker_name = "ei-corrosive-ammo-sticker",
        payload_category = "chemistry",
        payload_ingredients = {
            {type = "item", name = "sulfur", amount = 4},
            {type = "fluid", name = "ei-nitric-acid", amount = 20},
            {type = "fluid", name = "ei-bio-oil", amount = 20},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        payload_icons = {
            {icon = nitric_acid_icon, icon_size = 64},
            {icon = sulfur_icon, icon_size = 64, scale = 0.26, shift = {-8, 8}},
        },
    },
    {
        key = "cryo",
        name = "ei-cryo-ammo",
        payload_name = "ei-magazine-payload-cryo",
        tech_name = "ei-cryo-magazines",
        order = "a[basic-clips]-f[cryo-ammo]",
        primary_icon = cryodust_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = condensed_cryodust_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.72, g = 0.95, b = 1.0, a = 0.95},
        direct_damages = {
            {amount = 36, type = "physical"},
            {amount = 14, type = "cold"},
        },
        hit_effect_name = "ei-cryo-ammo-impact-burst",
        sticker_name = "ei-cryo-ammo-sticker",
        payload_category = "crafting",
        payload_ingredients = {
            {type = "item", name = "ei-cryodust", amount = 4},
            {type = "item", name = "ei-condensed-cryodust", amount = 1},
        },
        payload_icons = {
            {icon = cryodust_icon, icon_size = 64},
            {icon = condensed_cryodust_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
    {
        key = "oxyfluoride",
        name = "ei-oxyfluoride-ammo",
        payload_name = "ei-magazine-payload-oxyfluoride",
        tech_name = "ei-oxyfluoride-magazines",
        order = "a[basic-clips]-g[oxyfluoride-ammo]",
        primary_icon = oxygen_difluoride_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = fluorite_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 1.0, g = 0.92, b = 0.62, a = 0.95},
        direct_damages = {
            {amount = 42, type = "physical"},
            {amount = 24, type = "fire"},
        },
        hit_effect_name = "ei-oxyfluoride-ammo-impact-burst",
        sticker_name = "ei-oxyfluoride-ammo-sticker",
        payload_category = "chemistry",
        payload_ingredients = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 15},
            {type = "item", name = "ei-fluorite", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        payload_icons = {
            {icon = oxygen_difluoride_icon, icon_size = 64},
            {icon = fluorite_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
    {
        key = "morphium",
        name = "ei-morphium-ammo",
        payload_name = "ei-magazine-payload-morphium",
        tech_name = "ei-morphium-magazines",
        order = "a[basic-clips]-h[morphium-ammo]",
        primary_icon = concentrated_morphium_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = fluorite_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.52, g = 0.12, b = 0.7, a = 0.92},
        direct_damages = {
            {amount = 34, type = "physical"},
            {amount = 14, type = "ei-morphium"},
        },
        hit_effect_name = "ei-morphium-ammo-impact-burst",
        sticker_name = "ei-morphium-ammo-sticker",
        payload_category = "chemistry",
        payload_ingredients = {
            {type = "fluid", name = "ei-concentrated-morphium", amount = 40},
            {type = "item", name = "ei-fluorite", amount = 1},
            {type = "item", name = "ei-high-energy-crystal", amount = 1},
        },
        payload_icons = {
            {icon = concentrated_morphium_icon, icon_size = 64},
            {icon = fluorite_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
    {
        key = "hexafluoride",
        name = "ei-hexafluoride-ammo",
        payload_name = "ei-magazine-payload-hexafluoride",
        tech_name = "ei-hexafluoride-magazines",
        order = "a[basic-clips]-i[hexafluoride-ammo]",
        primary_icon = uranium_hexafluorite_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = lead_ingot_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.42, g = 0.92, b = 0.72, a = 0.92},
        direct_damages = {
            {amount = 48, type = "physical"},
            {amount = 10, type = "acid"},
            {amount = 6, type = "ei-radiological"},
        },
        hit_effect_name = "ei-hexafluoride-ammo-impact-burst",
        sticker_name = "ei-hexafluoride-ammo-sticker",
        payload_category = "chemistry",
        payload_ingredients = {
            {type = "fluid", name = "ei-uranium-hexafluorite", amount = 20},
            {type = "item", name = "ei-lead-ingot", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        payload_icons = {
            {icon = uranium_hexafluorite_icon, icon_size = 64},
            {icon = lead_ingot_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
    {
        key = "arc",
        name = "ei-arc-ammo",
        payload_name = "ei-magazine-payload-arc",
        tech_name = "ei-arc-magazines",
        order = "a[basic-clips]-j[arc-ammo]",
        primary_icon = lithium_crystal_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = battery_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.42, g = 0.56, b = 1.0, a = 0.95},
        direct_damages = {
            {amount = 32, type = "physical"},
            {amount = 44, type = "electric"},
        },
        hit_effect_name = "ei-arc-ammo-impact-burst",
        sticker_name = "ei-arc-ammo-sticker",
        payload_category = "crafting",
        payload_ingredients = {
            {type = "item", name = "ei-lithium-crystal", amount = 1},
            {type = "item", name = "ei-fluorite", amount = 2},
            {type = "item", name = "battery", amount = 1},
        },
        payload_icons = {
            {icon = lithium_crystal_icon, icon_size = 64},
            {icon = battery_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
    {
        key = "neutron",
        name = "ei-neutron-ammo",
        payload_name = "ei-magazine-payload-neutron",
        tech_name = "ei-neutron-magazines",
        order = "a[basic-clips]-k[neutron-ammo]",
        primary_icon = charged_neutron_container_icon,
        primary_icon_shift = {8, -8},
        secondary_icon = lead_ingot_icon,
        secondary_icon_shift = {-8, 8},
        light_tint = {r = 0.76, g = 0.9, b = 1.0, a = 0.95},
        direct_damages = {
            {amount = 60, type = "physical"},
            {amount = 16, type = "ei-radiological"},
        },
        hit_effect_name = "ei-neutron-ammo-impact-burst",
        sticker_name = "ei-neutron-ammo-sticker",
        payload_category = "crafting",
        payload_ingredients = {
            {type = "item", name = "ei-charged-neutron-container", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        payload_icons = {
            {icon = charged_neutron_container_icon, icon_size = 64},
            {icon = lead_ingot_icon, icon_size = 64, scale = 0.28, shift = {-8, 8}},
        },
    },
}

local items = {
    body_item,
    driver_item,
    core_item,
}

local recipes = {
    make_recipe(
        "ei-exotic-magazine-body",
        "crafting",
        4,
        {
            {type = "item", name = "ei-steel-mechanical-parts", amount = 2},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        {{type = "item", name = "ei-exotic-magazine-body", amount = 1}}
    ),
    make_recipe(
        "ei-exotic-magazine-driver",
        "crafting",
        5,
        {
            {type = "item", name = "advanced-circuit", amount = 1},
            {type = "item", name = "battery", amount = 1},
            {type = "item", name = "ei-insulated-wire", amount = 2},
            {type = "item", name = "ei-energy-crystal", amount = 1},
        },
        {{type = "item", name = "ei-exotic-magazine-driver", amount = 1}}
    ),
    make_recipe(
        "ei-exotic-magazine-core",
        "crafting",
        6,
        {
            {type = "item", name = "ei-exotic-magazine-body", amount = 1},
            {type = "item", name = "ei-exotic-magazine-driver", amount = 1},
            {type = "item", name = "explosives", amount = 2},
        },
        {{type = "item", name = "ei-exotic-magazine-core", amount = 1}}
    ),
}

local techs = {}
local new_ammos = {}
local compound_ammo
local compound_recipe

for _, def in ipairs(ammo_defs) do
    items[#items + 1] = make_item(def.payload_name, def.payload_icons, nil, "q[exotic-magazine]-p-" .. def.key)
    recipes[#recipes + 1] = make_recipe(
        def.payload_name,
        def.payload_category,
        6,
        def.payload_ingredients,
        {{type = "item", name = def.payload_name, amount = 1}}
    )

    local final_recipe = make_recipe(
        def.name,
        "crafting",
        4,
        {
            {type = "item", name = "ei-exotic-magazine-core", amount = 1},
            {type = "item", name = def.payload_name, amount = 1},
        },
        {{type = "item", name = def.name, amount = 1}}
    )

    def.accent_sticker_name = "ei-" .. def.key .. "-ammo-accent-sticker"
    local ammo = make_bullet_ammo(def)
    if def.name == "ei-compound-ammo" then
        compound_ammo = ammo
        compound_recipe = final_recipe
    else
        new_ammos[#new_ammos + 1] = ammo
        recipes[#recipes + 1] = final_recipe
    end
end

ei_lib.remove_unlock_recipe("military-4", "ei-compound-ammo")

techs[#techs + 1] = make_tech(
    "ei-exotic-magazines",
    compound_ammo.icons,
    {"military-4", "uranium-ammo", "ei-computer-age", "ei-high-energy-crystal-growing"},
    "computer-age",
    {
        {type = "unlock-recipe", recipe = "ei-exotic-magazine-body"},
        {type = "unlock-recipe", recipe = "ei-exotic-magazine-driver"},
        {type = "unlock-recipe", recipe = "ei-exotic-magazine-core"},
        {type = "unlock-recipe", recipe = "ei-magazine-payload-compound"},
        {type = "unlock-recipe", recipe = "ei-compound-ammo"},
    },
    "computer-age",
    "a-j-a"
)

techs[#techs + 1] = make_tech(
    "ei-corrosive-magazines",
    make_icons(base_mag_icon, nitric_acid_icon, {8, -8}, nil, sulfur_icon, {-8, 8}, nil, {r = 0.48, g = 1.0, b = 0.42, a = 0.95}),
    {"ei-exotic-magazines", "ei-nitric-acid", "ei-bio-oil"},
    "computer-age-space-gleba",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-corrosive"},
        {type = "unlock-recipe", recipe = "ei-corrosive-ammo"},
    },
    "computer-age-space-gleba",
    "a-j-b"
)

techs[#techs + 1] = make_tech(
    "ei-cryo-magazines",
    make_icons(base_mag_icon, cryodust_icon, {8, -8}, nil, condensed_cryodust_icon, {-8, 8}, nil, {r = 0.72, g = 0.95, b = 1.0, a = 0.95}),
    {"ei-exotic-magazines", "ei-cryodust"},
    "alien-computer-age",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-cryo"},
        {type = "unlock-recipe", recipe = "ei-cryo-ammo"},
    },
    "alien-computer-age",
    "a-j-c"
)

techs[#techs + 1] = make_tech(
    "ei-oxyfluoride-magazines",
    make_icons(base_mag_icon, oxygen_difluoride_icon, {8, -8}, nil, fluorite_icon, {-8, 8}, nil, {r = 1.0, g = 0.92, b = 0.62, a = 0.95}),
    {"ei-exotic-magazines", "ei-oxygen-difluoride"},
    "computer-age",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-oxyfluoride"},
        {type = "unlock-recipe", recipe = "ei-oxyfluoride-ammo"},
    },
    "computer-age",
    "a-j-d"
)

techs[#techs + 1] = make_tech(
    "ei-morphium-magazines",
    make_icons(base_mag_icon, concentrated_morphium_icon, {8, -8}, nil, fluorite_icon, {-8, 8}, nil, {r = 0.52, g = 0.12, b = 0.7, a = 0.92}),
    {"ei-exotic-magazines", "ei-morphium-usage"},
    "computer-age-space",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-morphium"},
        {type = "unlock-recipe", recipe = "ei-morphium-ammo"},
    },
    "computer-age-space",
    "a-j-e"
)

techs[#techs + 1] = make_tech(
    "ei-hexafluoride-magazines",
    make_icons(base_mag_icon, uranium_hexafluorite_icon, {8, -8}, nil, lead_ingot_icon, {-8, 8}, nil, {r = 0.42, g = 0.92, b = 0.72, a = 0.92}),
    {"ei-exotic-magazines", "uranium-processing", "ei-fluoride-uranium-reprocessing"},
    "advanced-computer-age",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-hexafluoride"},
        {type = "unlock-recipe", recipe = "ei-hexafluoride-ammo"},
    },
    "advanced-computer-age",
    "a-j-f"
)

techs[#techs + 1] = make_tech(
    "ei-arc-magazines",
    make_icons(base_mag_icon, lithium_crystal_icon, {8, -8}, nil, battery_icon, {-8, 8}, nil, {r = 0.42, g = 0.56, b = 1.0, a = 0.95}),
    {"ei-exotic-magazines", "ei-lithium-processing"},
    "quantum-age",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-arc"},
        {type = "unlock-recipe", recipe = "ei-arc-ammo"},
    },
    "quantum-age",
    "a-j-g"
)

techs[#techs + 1] = make_tech(
    "ei-neutron-magazines",
    make_icons(base_mag_icon, charged_neutron_container_icon, {8, -8}, nil, lead_ingot_icon, {-8, 8}, nil, {r = 0.76, g = 0.9, b = 1.0, a = 0.95}),
    {"ei-exotic-magazines", "ei-neutron-collector"},
    "fusion-quantum-age",
    {
        {type = "unlock-recipe", recipe = "ei-magazine-payload-neutron"},
        {type = "unlock-recipe", recipe = "ei-neutron-ammo"},
    },
    "fusion-quantum-age",
    "a-j-h"
)

data:extend(items)
data:extend(recipes)
data:extend(new_ammos)
data:extend(techs)

if compound_ammo then
    data.raw.ammo["ei-compound-ammo"] = compound_ammo
end
if compound_recipe then
    data.raw.recipe["ei-compound-ammo"] = compound_recipe
end
