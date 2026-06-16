--==============================================================================
-- ESIR FILE MAP
-- owns: Surveyor handheld ballistic chain
-- loaded_by: exotic-space-industries-remembrance\prototypes\computer-age\computer-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_data = require("lib/data")

local SURVEYOR_CHAIN_HIDDEN = true

local base_gun = data.raw.gun["submachine-gun"]
local base_attack = base_gun and base_gun.attack_parameters or {}
local base_shell_particle = table.deepcopy(base_attack.shell_particle) or {
    name = "shell-particle",
    direction_deviation = 0.1,
    speed = 0.1,
    speed_deviation = 0.03,
    center = {0, 0.9},
    creation_distance = -0.5,
    starting_frame_speed = 0.4,
    starting_frame_speed_deviation = 0.1
}
local base_gun_sound = table.deepcopy(base_attack.sound) or {
    variations = {
        {filename = "__base__/sound/fight/submachine-gunshot-1.ogg", volume = 0.6},
        {filename = "__base__/sound/fight/submachine-gunshot-2.ogg", volume = 0.6},
        {filename = "__base__/sound/fight/submachine-gunshot-3.ogg", volume = 0.6},
    },
    priority = 64
}

local function gun_attack(range, cooldown, damage_modifier, movement_slow_down_factor)
    return {
        type = "projectile",
        ammo_category = "bullet",
        cooldown = cooldown,
        damage_modifier = damage_modifier,
        movement_slow_down_factor = movement_slow_down_factor,
        projectile_creation_distance = 1.125,
        projectile_center = {0, -0.9},
        use_shooter_direction = true,
        range = range,
        shell_particle = table.deepcopy(base_shell_particle),
        sound = table.deepcopy(base_gun_sound)
    }
end

local surveyor_weapons = {
    {
        name = "ei-surveyor-carbine",
        icon = "__base__/graphics/icons/submachine-gun.png",
        icon_size = 64,
        order = "a[basic-clips]-ba[surveyor-carbine]",
        range = 40,
        cooldown = 36,
        damage_modifier = 6.4,
        movement_slow_down_factor = 0.6,
        recipe_time = 8,
        ingredients = {
            {type = "item", name = "submachine-gun", amount = 1},
            {type = "item", name = "ei-glass", amount = 8},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 12},
            {type = "item", name = "ei-ceramic", amount = 4},
            {type = "item", name = "engine-unit", amount = 1},
        },
        tech_icon = "__base__/graphics/technology/military.png",
        tech_icon_size = 256,
        prerequisites = {"military-2"},
        science = "steam-age",
        count = 100,
        time = 20,
        age = "steam-age",
    },
    {
        name = "ei-surveyor-rifle",
        icon = "__base__/graphics/icons/combat-shotgun.png",
        icon_size = 64,
        order = "a[basic-clips]-bb[surveyor-rifle]",
        range = 52,
        cooldown = 45,
        damage_modifier = 9.0,
        movement_slow_down_factor = 0.65,
        recipe_time = 10,
        ingredients = {
            {type = "item", name = "ei-surveyor-carbine", amount = 1},
            {type = "item", name = "ei-glass", amount = 12},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 16},
            {type = "item", name = "ei-ceramic", amount = 6},
            {type = "item", name = "electric-engine-unit", amount = 2},
        },
        tech_icon = "__base__/graphics/technology/military.png",
        tech_icon_size = 256,
        prerequisites = {"ei-surveyor-carbine", "military-3"},
        science = "electricity-age",
        count = 100,
        time = 20,
        age = "electricity-age",
    },
    {
        name = "ei-surveyor-cannon",
        icon = "__space-age__/graphics/icons/railgun.png",
        icon_size = 64,
        order = "a[basic-clips]-bc[surveyor-cannon]",
        range = 70,
        cooldown = 60,
        damage_modifier = 24.0,
        movement_slow_down_factor = 0.8,
        recipe_time = 16,
        ingredients = {
            {type = "item", name = "ei-surveyor-rifle", amount = 1},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 28},
            {type = "item", name = "ei-glass", amount = 16},
            {type = "item", name = "ei-simulation-data", amount = 8},
            {type = "item", name = "ei-carbon", amount = 12},
            {type = "item", name = "ei-electronic-parts", amount = 6},
        },
        tech_icon = "__space-age__/graphics/technology/railgun.png",
        tech_icon_size = 256,
        prerequisites = {"ei-surveyor-rifle", "military-4", "ei-advanced-computer-age-tech", "ei-carbon-manipulation"},
        science = "advanced-computer-age",
        count = 150,
        time = 30,
        age = "advanced-computer-age",
    },
    {
        name = "ei-adaptive-surveyor",
        icon = "__space-age__/graphics/icons/railgun.png",
        icon_size = 64,
        order = "a[basic-clips]-bd[adaptive-surveyor]",
        range = 90,
        cooldown = 72,
        damage_modifier = 34.2,
        movement_slow_down_factor = 0.75,
        recipe_time = 24,
        ingredients = {
            {type = "item", name = "ei-surveyor-cannon", amount = 1},
            {type = "item", name = "ei-glass", amount = 24},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 32},
            {type = "item", name = "ei-computing-unit", amount = 8},
            {type = "item", name = "ei-superior-data", amount = 80},
            {type = "item", name = "ei-odd-plating", amount = 20},
        },
        tech_icon = "__space-age__/graphics/technology/railgun.png",
        tech_icon_size = 256,
        prerequisites = {"ei-surveyor-cannon", "military-5", "ei-quantum-age", "ei-odd-plating"},
        science = "quantum-age",
        count = 200,
        time = 30,
        age = "quantum-age",
    },
}

local items = {}

local recipes = {}

for _, weapon in ipairs(surveyor_weapons) do
    items[#items + 1] = {
        name = weapon.name,
        type = "gun",
        icon = weapon.icon,
        icon_size = weapon.icon_size,
        hidden = SURVEYOR_CHAIN_HIDDEN,
        stack_size = 1,
        subgroup = "gun",
        order = weapon.order,
        attack_parameters = gun_attack(
            weapon.range,
            weapon.cooldown,
            weapon.damage_modifier,
            weapon.movement_slow_down_factor
        ),
    }

    recipes[#recipes + 1] = {
        name = weapon.name,
        type = "recipe",
        category = "crafting",
        energy_required = weapon.recipe_time,
        ingredients = weapon.ingredients,
        results = {{type = "item", name = weapon.name, amount = 1}},
        always_show_made_in = true,
        enabled = false,
        hidden = SURVEYOR_CHAIN_HIDDEN,
        main_product = weapon.name,
    }
end

data:extend(items)
data:extend(recipes)

local techs = {}

for _, weapon in ipairs(surveyor_weapons) do
    techs[#techs + 1] = {
        name = weapon.name,
        type = "technology",
        icon = weapon.tech_icon,
        icon_size = weapon.tech_icon_size,
        hidden = SURVEYOR_CHAIN_HIDDEN,
        prerequisites = weapon.prerequisites,
        effects = {
            {type = "unlock-recipe", recipe = weapon.name},
        },
        unit = {
            count = weapon.count,
            ingredients = ei_data.science[weapon.science],
            time = weapon.time
        },
        age = weapon.age,
    }
end

data:extend(techs)
