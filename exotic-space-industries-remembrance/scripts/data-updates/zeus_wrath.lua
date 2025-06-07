if not mods["zeus-wrath"] then return end
local ei_lib = require("lib/lib")
--tech zeus-wrath-zeus-wrath
--gun zeus-wrath-zeus-gun
--turret zeus-wrath-zeus-turret
--ammo zeus-wrath-lightning-ammo
--remnants zeus-wrath-zeus-turret-remnants

--this looks for target_name_alt in the .cfg
ei_lib.overwrite_entity_and_description("zeus-wrath-zeus-turret","electric-turret")
ei_lib.overwrite_entity_and_description("zeus-wrath-zeus-turret","item")
ei_lib.overwrite_entity_and_description("zeus-wrath-zeus-gun","gun")
ei_lib.overwrite_entity_and_description("zeus-wrath-lightning-ammo","ammo")
ei_lib.overwrite_entity_and_description("zeus-wrath-zeus-wrath","technology")

ei_lib.add_prerequisite("zeus-wrath-zeus-wrath","ei-high-tech-parts")
ei_lib.add_prerequisite("zeus-wrath-zeus-wrath","ei-quantum-computer")
data.raw.technology["zeus-wrath-zeus-wrath"].age = "quantum-age"

data.raw["electric-turret"]["zeus-wrath-zeus-turret"].max_health = 3000
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].prepare_range = 355
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].rotation_speed = 0.01
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].attack_parameters.cooldown = 720
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].attack_parameters.range = 350
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].attack_parameters.min_range = 70
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].call_for_help_radius = 70
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].energy_source.drain = "75MW"
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].energy_source.input_flow_limit = "400MW"
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].energy_source.buffer_capacity = "1.1GJ"
data.raw["electric-turret"]["zeus-wrath-zeus-turret"].attack_parameters.ammo_type.energy_consumption = "1GJ"

--Inner radius damage
ei_lib.patch_nested_value(
  data.raw["electric-turret"]["zeus-wrath-zeus-turret"],
  "attack_parameters.ammo_type.action.action_delivery[2].target_effects[2].action[1].action_delivery.target_effects[1].damage.amount",
  900
)
--Outer radius damage
ei_lib.patch_nested_value(
  data.raw["electric-turret"]["zeus-wrath-zeus-turret"],
  "attack_parameters.ammo_type.action.action_delivery[2].target_effects[2].action[2].action_delivery.target_effects[1].damage.amount",
  300
)

--Inner radius damage
ei_lib.patch_nested_value(
  data.raw["ammo"]["zeus-wrath-lightning-ammo"],
  "ammo_type.action.action_delivery[2].target_effects[2].action[1].action_delivery.target_effects[1].damage.amount",
  900
)
--Outer radius damage
ei_lib.patch_nested_value(
  data.raw["ammo"]["zeus-wrath-lightning-ammo"],
  "ammo_type.action.action_delivery[2].target_effects[2].action[2].action_delivery.target_effects[1].damage.amount",
  300
)

local newTurretIngredients = {
        {type = "fluid", name = "electrolyte", amount = 2000},
        {type = "item", name = "ei-high-energy-crystal", amount = 100},
        {type = "item", name = "superconductor", amount = 200},
        {type = "item", name = "holmium-plate", amount = 200},
        {type = "item", name = "ei-induction-matrix-core", amount = 1},
        {type = "item", name = "ei-induction-matrix-advanced-solenoid", amount = 10},
        {type = "item", name = "ei-induction-matrix-superior-coil", amount = 10},
        {type = "item", name = "ei-induction-matrix-superior-converter", amount = 10},
        {type = "item", name = "ei-high-tech-parts", amount = 200},
        {type = "item", name = "ei-superior-data", amount = 200},
        {type = "item", name = "lightning-collector", amount = 1},
        {type = "item", name = "ei-copper-beacon", amount = 10},
        {type = "item", name = "zeus-wrath-zeus-gun", amount = 1}
    }

ei_lib.recipe_hard_overwrite("zeus-wrath-zeus-turret",newTurretIngredients)

local newGunIngredients = {
        {type = "fluid", name = "electrolyte", amount = 1000},
        {type = "item", name = "ei-high-energy-crystal", amount = 20},
        {type = "item", name = "superconductor", amount = 50},
        {type = "item", name = "holmium-plate", amount = 50},
        {type = "item", name = "ei-induction-matrix-core", amount = 1},
        {type = "item", name = "ei-induction-matrix-advanced-solenoid", amount = 3},
        {type = "item", name = "ei-induction-matrix-superior-coil", amount = 3},
        {type = "item", name = "ei-induction-matrix-superior-converter", amount = 3},
        {type = "item", name = "ei-superior-data", amount = 50},
        {type = "item", name = "ei-high-tech-parts", amount = 50},
        {type = "item", name = "lightning-collector", amount = 1},
        {type = "item", name = "teslagun", amount = 1}
}

ei_lib.recipe_hard_overwrite("zeus-wrath-zeus-gun",newGunIngredients)

local newAmmoIngredients = {
        {type = "fluid", name = "electrolyte", amount = 50},
        {type = "item", name = "ei-high-energy-crystal", amount = 5},
        {type = "item", name = "ei-induction-matrix-advanced-solenoid", amount = 1},
        {type = "item", name = "ei-induction-matrix-superior-coil", amount = 1},
        {type = "item", name = "ei-induction-matrix-superior-converter", amount = 1},
        {type = "item", name = "ei-high-tech-parts", amount = 5},
        {type = "item", name = "ei-superior-data", amount = 10},
        {type = "item", name = "lightning-rod", amount = 1}
}

ei_lib.recipe_hard_overwrite("zeus-wrath-lightning-ammo",newAmmoIngredients)