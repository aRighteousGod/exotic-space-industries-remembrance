require ("teslas_legacy.lib.technology")

local science = get_science()

local technologies = {}

table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 1,
	prerequisites = { "tl-tesla-tank-technology" },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.050),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.250),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.100),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.050),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.100),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.025),
	},
	science = { science.red, science.green, science.black, science.blue }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 2,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.100),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.350),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.100),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.050),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.100),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.025),
	},
	science = { science.red, science.green, science.black, science.blue }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 3,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.100),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.350),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.150),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.050),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.100),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.025),
	},
	science = { science.red, science.green, science.black, science.blue, science.yellow }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 4,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.100),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.450),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.150),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.025),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.050),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.010),
	},
	science = { science.red, science.green, science.black, science.blue, science.yellow }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 5,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.150),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.450),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.150),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.025),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.050),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.010),
	},
	science = { science.red, science.green, science.black, science.blue, science.purple }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 6,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.150),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.550),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.150),
	  make_shooting_speed_modifier("tl-basic-tesla-coil-turret-category", 0.025),
	  make_shooting_speed_modifier("tl-tesla-coil-ammo-category", 0.050),
	  make_shooting_speed_modifier("tl-advanced-tesla-coil-turret-category", 0.010),
	},
	science = { science.red, science.green, science.black, science.blue, science.yellow, science.purple }
  })
)
table.insert( technologies, create_technology({
    name = "tl-tesla-ammo-upgrade-technology", level = 7,
	prerequisites = { technologies[#technologies].name },
	effects = {
	  make_damage_modifier("tl-basic-tesla-coil-turret-category", 0.150),
	  make_damage_modifier("tl-tesla-coil-ammo-category", 0.600),
	  make_damage_modifier("tl-advanced-tesla-coil-turret-category", 0.200),
	},
	science = { science.red, science.green, science.black, science.blue, science.yellow, science.purple, science.white }
  })
)

data:extend(technologies)

