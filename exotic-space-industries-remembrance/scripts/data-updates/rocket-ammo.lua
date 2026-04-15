local ei_lib = require("lib/lib")

ei_lib.recipe_new("rocket", {
    {type = "item", name = "ei-rocket-airframe", amount = 1},
    {type = "item", name = "ei-rocket-motor-basic", amount = 1},
    {type = "item", name = "ei-rocket-warhead-impact", amount = 1},
}, {
    clear_difficulty_variants = true,
    enabled = false,
})

ei_lib.recipe_new("explosive-rocket", {
    {type = "item", name = "ei-rocket-airframe", amount = 1},
    {type = "item", name = "ei-rocket-motor-basic", amount = 1},
    {type = "item", name = "ei-rocket-warhead-explosive", amount = 1},
}, {
    clear_difficulty_variants = true,
    enabled = false,
})

ei_lib.recipe_swap("rocket-turret", "processing-unit", "ei-electronic-parts", 20)

local rocket_turret = data.raw["ammo-turret"] and data.raw["ammo-turret"]["rocket-turret"]
if rocket_turret and rocket_turret.attack_parameters then
    if rocket_turret.attack_parameters.range and rocket_turret.attack_parameters.range < 40 then
        rocket_turret.attack_parameters.range = 40
    end

    rocket_turret.attack_parameters.health_penalty = -1
end

local rocket_launcher = data.raw.gun and data.raw.gun["rocket-launcher"]
if rocket_launcher and rocket_launcher.attack_parameters and rocket_launcher.attack_parameters.range
    and rocket_launcher.attack_parameters.range < 40 then
    rocket_launcher.attack_parameters.range = 40
end

ei_lib.add_unlock_recipe("rocketry", "ei-rocket-airframe")
ei_lib.add_unlock_recipe("rocketry", "ei-rocket-motor-basic")
ei_lib.add_unlock_recipe("rocketry", "ei-rocket-warhead-impact")

ei_lib.add_unlock_recipe("explosive-rocketry", "ei-rocket-warhead-explosive")
ei_lib.add_unlock_recipe("ei-advanced-rocket-fuel", "ei-rocket-motor-high-energy")

if data.raw.technology["atomic-bomb"] then
    ei_lib.set_prerequisites("atomic-bomb", {
        "ei-advanced-rocket-fuel",
        "ei-uranium-235-recycling",
    })
    ei_lib.set_age_packs("atomic-bomb", "computer-age")
    data.raw.technology["atomic-bomb"].age = "computer-age"
    ei_lib.remove_unlock_recipe("atomic-bomb", "atomic-bomb")
    ei_lib.add_unlock_recipe("atomic-bomb", "ei-rocket-warhead-atomic-u235")
    ei_lib.add_unlock_recipe("atomic-bomb", "atomic-bomb-u235")
end

if data.raw.technology["ei-plutonium-warheads"] then
    ei_lib.set_age_packs("ei-plutonium-warheads", "advanced-computer-age")
    data.raw.technology["ei-plutonium-warheads"].age = "advanced-computer-age"
end

if data.raw.recipe["atomic-bomb"] then
    data.raw.recipe["atomic-bomb"].enabled = false
    data.raw.recipe["atomic-bomb"].hidden = true
    data.raw.recipe["atomic-bomb"].allow_productivity = false
end
