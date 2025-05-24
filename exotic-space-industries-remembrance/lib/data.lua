-- store data like switch tables and other constants/parameters here
-- excluding global table stuff
-- can be used in data stage AND in control

local ei_data = {}

ei_data.prerequisites_to_set = {}
ei_data.tech_scaling = {}
ei_data.science = {}
ei_data.sub_age = {}
ei_data.add_to_sub_age = {}
ei_data.tech_structure = {}
ei_data.colors = {}
ei_data.lab_inputs = {}
ei_data.pipe_pictures = {}
ei_data.fusion = {}
ei_data.matter_stabilizer = {}

--====================================================================================================
--COLORS
--====================================================================================================

ei_data.colors.miner = {r = 1, g = 0.67, b = 0.3}
ei_data.colors.assembler = {r = 1, g = 0.67, b = 0.3}
ei_data.colors.neo = {r = 0.66, g = 0.14, b = 0.7, a = 0}
ei_data.colors.exotic = {r = 0.1, g = 0.5, b = 0.77, a = 0}
ei_data.colors.alien = {r = 0.16, g = 0.5, b = 0.2, a = 1}
ei_data.colors.solenoid = {r = 0.2, g = 0.2, b = 0.2, a = 0}
ei_data.colors.converter = {r = 0.2, g = 0.5, b = 0.9, a = 0}
ei_data.colors.coil = {r = 0.8, g = 0.45, b = 0.1, a = 0}

--ei_data.colors.neo = {r = 0.31, g = 0.22, b = 0.38, a = 0}
-- ei_data.colors.neo = {r = 0.55, g = 0.29, b = 0.56, a = 0}

--====================================================================================================
--TECH SCALING
--====================================================================================================

ei_data.tech_scaling.switch_table = {
    ["Very Cheap"]      =    500,
    ["More Cheap"]      =   1000,
    ["Cheap"]           =   1500,
    ["Default"]         =   2000,
    ["Less Expensive"]  =   3500,
    ["Expensive"]       =   5000,
    ["Very Expensive"]  = 100000
}

--====================================================================================================
--SCIENCE PACKS
--====================================================================================================

-- science packs that are needed to research techs from their respective ages

ei_data.science["dark-age"] = {
    {"ei-dark-age-tech",1},
}

ei_data.science["steam-age"] = {
    {"ei-dark-age-tech",1},
    {"ei-steam-age-tech",1},
}

ei_data.science["electricity-age"] = {
    {"ei-dark-age-tech",1},
    {"ei-steam-age-tech",1},
    {"ei-electricity-age-tech",1},
}

ei_data.science["computer-age"] = {
    {"ei-dark-age-tech",1},
    {"ei-steam-age-tech",1},
    {"ei-electricity-age-tech",1},
    {"ei-computer-age-tech",1},
}

ei_data.science["computer-age-space"] = {
    {"ei-dark-age-tech",1},
    {"ei-steam-age-tech",1},
    {"ei-electricity-age-tech",1},
    {"ei-computer-age-tech",1},
    {"space-science-pack",1},
}

ei_data.science["advanced-computer-age"] = {
    {"ei-electricity-age-tech",1},
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
}

ei_data.science["alien-computer-age"] = {
    {"ei-electricity-age-tech",1},
    {"ei-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
}

ei_data.science["both-computer-age"] = {
    {"ei-electricity-age-tech",1},
    {"ei-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
}

ei_data.science["quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
}

ei_data.science["fusion-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
}

ei_data.science["space-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
}

ei_data.science["imersite-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-imersite-quantum-age-tech",1},
}

ei_data.science["matter-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
    {"ei-imersite-quantum-age-tech",1},
    {"ei-matter-quantum-age-tech",1},
}

ei_data.science["both-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
}

ei_data.science["four-quantum-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
    {"ei-imersite-quantum-age-tech",1},
    {"ei-matter-quantum-age-tech",1},
}

ei_data.science["exotic-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
    {"ei-exotic-age-tech",1},
}

ei_data.science["black-hole-exotic-age"] = {
    {"ei-computer-age-tech",1},
    {"ei-advanced-computer-age-tech",1},
    {"ei-alien-computer-age-tech",1},
    {"ei-quantum-age-tech",1},
    {"ei-fusion-quantum-age-tech",1},
    {"ei-exotic-age-tech",1},
    {"ei-black-hole-exotic-age-tech",1},
}

ei_data.science["interstellar"] = {
    {"electromagnetic-science-pack",1},
    {"metallurgic-science-pack",1},
    {"agricultural-science-pack",1},
}

-- inputs for labs

ei_data.lab_inputs["dark-age-lab"] = {
  "ei-dark-age-tech",
  "ei-steam-age-tech",
  "ei-electricity-age-tech"
}

ei_data.lab_inputs["lab"] = {
  "ei-dark-age-tech",
  "ei-steam-age-tech",
  "ei-electricity-age-tech",
  "ei-computer-age-tech",
}

-- EI equivalent of vanilla science packs
ei_data.science_dict = {
    ["automation-science-pack"] = "ei-dark-age-tech",
    ["logistic-science-pack"] = "ei-steam-age-tech",
    ["chemical-science-pack"] = "ei-electricity-age-tech",
    ["military-science-pack"] = "ei-electricity-age-tech",
    ["production-science-pack"] = "ei-computer-age-tech",
    ["utility-science-pack"] = "ei-computer-age-tech",

    ["wood-science-pack"] = "ei-dark-age-tech",
    ["steam-science-pack"] = "ei-steam-age-tech",

    -- ["space-science-pack"] = "ei-quantum-age-tech",
    -- K2 stuff
    -- ["basic-tech-card"] = "ei-dark-age-tech",
    -- ["matter-tech-card"] = "ei-matter-quantum-age-tech",
    -- ["advanced-tech-card"] = "ei-imersite-quantum-age-tech",
    -- ["singularity-tech-card"] = "ei-exotic-age-tech",
}

ei_data.science_dict_obsolete = {
    ["ei-dark-age-tech"] = true,
    ["ei-steam-age-tech"] = true,
    ["ei-electricity-age-tech"] = true,
    ["wood-science-pack"] = true,
    ["steam-science-pack"] = true,
}

--====================================================================================================
--SUB AGES
--====================================================================================================

ei_data.sub_age["advanced-computer-age"] = "computer-age"
ei_data.sub_age["alien-computer-age"] = "computer-age"
ei_data.sub_age["both-computer-age"] = "computer-age"

ei_data.add_to_sub_age["alien-computer-age"] = {
    "logistics-3",
    "braking-force-6",
    "braking-force-7",
    "bulk-inserter",
    "inserter-capacity-bonus-3",
    "inserter-capacity-bonus-4",
    "spidertron",
    "automation-3",
}

ei_data.add_to_sub_age["advanced-computer-age"] = {
    "mining-productivity-2",
    "research-speed-3",
    "research-speed-4",
    -- "spidertron",
    "processing-unit",
    "ei-quantum-age",
    "speed-module-3",
    "efficiency-module-3",
    "productivity-module-3",
    "worker-robots-speed-3",
    "worker-robots-storage-1",
    "worker-robots-speed-4",
    "worker-robots-storage-2",
    "personal-roboport-mk2-equipment",
    "follower-robot-count-3",
    "follower-robot-count-4",
    "power-armor-mk2",
    "laser-shooting-speed-4",
    "laser-shooting-speed-5",
    "laser-shooting-speed-6",
    "laser-shooting-speed-7",
    "laser-weapons-damage-3",
    "laser-weapons-damage-4",
    "energy-shield-mk2-equipment",
    "battery-mk2-equipment",
    "artillery",
    "artillery-shell-range-1",
    "artillery-shell-speed-1",
}

ei_data.add_to_sub_age["both-computer-age"] = {
  
}

ei_data.sub_age["fusion-quantum-age"] = "quantum-age"
ei_data.sub_age["space-quantum-age"] = "quantum-age"
ei_data.sub_age["both-quantum-age"] = "quantum-age"
ei_data.sub_age["imersite-quantum-age"] = "quantum-age"
ei_data.sub_age["matter-quantum-age"] = "quantum-age"
ei_data.sub_age["four-quantum-age"] = "quantum-age"


ei_data.add_to_sub_age["fusion-quantum-age"] = {
    "ei-personal-reactor",
    "worker-robots-speed-5",
    "worker-robots-storage-3",
    "laser-weapons-damage-6",
}

ei_data.add_to_sub_age["both-quantum-age"] = {
    "mining-productivity-4",
    "worker-robots-speed-6",
    "research-speed-6",
    "inserter-capacity-bonus-7",
    "laser-weapons-damage-7",
    "stronger-explosives-7",
}

ei_data.sub_age["black-hole-exotic-age"] = "exotic-age"

--====================================================================================================
--AGE STRUCTURE
--====================================================================================================

ei_data.ages = {
    "dark-age",
    "steam-age",
    "electricity-age",
    "computer-age",
    "quantum-age",
    "exotic-age"
}

-- used in final fixes to fix third party mods
ei_data.ages_with_sub = {
    ["dark-age"] = 1,
    ["steam-age"] = 2,
    ["electricity-age"] = 3,
    ["computer-age"] = 4,
    ["advanced-computer-age"] = 5,
    ["alien-computer-age"] = 5,
    ["quantum-age"] = 6,
    ["fusion-quantum-age"] = 7,
    ["space-quantum-age"] = 7,
    ["both-quantum-age"] = 10,
    ["imersite-quantum-age"] = 8,
    ["matter-quantum-age"] = 9,
    ["exotic-age"] = 11,
    ["black-hole-exotic-age"] = 12,
}

-- used in final fixes to account for age techs
ei_data.tech_ages_with_sub = {
    ["ei-dark-age"] = "dark-age",
    ["ei-steam-age"] = "steam-age",
    ["ei-electricity-age"] = "electricity-age",
    ["ei-computer-age"] = "computer-age",
    ["ei-advanced-computer-age-tech"] = "advanced-computer-age",
    ["ei-alien-computer-age-tech"] = "alien-computer-age",
    ["rocket-silo"] = "computer-age",
    ["ei-gaia"] = "computer-age",
    ["ei-quantum-age"] = "quantum-age",
    ["ei-fusion-data"] = "fusion-quantum-age",
    ["kr-imersium-processing"] = "imersite-quantum-age",
    ["kr-energy-control-unit"] = "matter-quantum-age",
    ["ei-exotic-age"] = "exotic-age",
    ["ei-high-tech-parts"] = "four-quantum-age",
}
ei_data.tech_ages_with_sub_reverse = {
    ["dark-age"] = "ei-dark-age",
    ["steam-age"] = "ei-steam-age",
    ["electricity-age"] = "ei-electricity-age",
    ["computer-age"] = "ei-computer-age",
    ["advanced-computer-age"] = "ei-advanced-computer-age-tech",
    ["alien-computer-age"] = "ei-alien-computer-age-tech",
    ["quantum-age"] = "ei-quantum-age",
    ["fusion-quantum-age"] = "ei-fusion-data",
    ["exotic-age"] = "ei-exotic-age",
    ["imersite-quantum-age"] = "kr-imersium-processing",
    ["matter-quantum-age"] = "kr-energy-control-unit",
    ["four-quantum-age"] = "ei-high-tech-parts",
}

-- store which age comes after which
-- used to make dummy techs

ei_data.ages_dummy_dict = {
    ["dark-age"] = "steam-age",
    ["steam-age"] = "electricity-age",
    ["electricity-age"] = "computer-age",
    ["computer-age"] = "quantum-age",
    ["quantum-age"] = "exotic-age",
}

--====================================================================================================
--ROUGH TECH STRUCTURE
--====================================================================================================

-- list tech names for their respective ages here

ei_data.tech_structure["dark-age"] = {
    "gun-turret",
    "heavy-armor",
    "military",
    "weapon-shooting-speed-1",
    "physical-projectile-damage-1",
    "toolbelt",
    "stone-wall",
    "logistics",
}
-- KEY = TECH, VALUE = PREREQUISITE
ei_data.prerequisites_to_set["dark-age"] = {
    ["heavy-armor"] = "military",
    ["weapon-shooting-speed-1"] = "military",
    ["physical-projectile-damage-1"] = "military",

    -- set mandatory for next age
    -- ["ei-steam-age"] = "military",
    -- ["ei-steam-age"] = "gun-turret",
}

ei_data.tech_structure["steam-age"] = {
    "electronics",
    -- steel furnace
    "advanced-material-processing",
    -- train
    "automated-rail-transportation",
    "braking-force-1",
    "braking-force-2",
    "weapon-shooting-speed-2",
    "physical-projectile-damage-2",
    "automobilism",
    "engine",
    "flamethrower",
    "flammables",
    "refined-flammables-1",
    "refined-flammables-2",
    "stronger-explosives-1",
    "gate",
    "inserter-capacity-bonus-1",
    "research-speed-1",
    "landfill",
    "steel-axe",
    "steel-processing",
    "military-2",

}

ei_data.tech_structure["electricity-age"] = {
    "oil-processing",
    "railway",
    "fluid-wagon",
    "fluid-handling",
    "automation",
    -- red circ
    "advanced-circuit",
    -- electric furnace
    "advanced-material-processing-2",
    "automation-2",
    "battery",
    "battery-equipment",
    "belt-immunity-equipment",
    "energy-shield-equipment",
    "exoskeleton-equipment",
    "night-vision-equipment",
    "personal-roboport-equipment",
    "modular-armor",
    "power-armor",
    "tank",
    "braking-force-3",
    "braking-force-4",
    "braking-force-5",
    "circuit-network",
    "explosives",
    "stronger-explosives-2",
    "refined-flammables-3",
    "refined-flammables-4",
    "physical-projectile-damage-3",
    "physical-projectile-damage-4",
    "land-mine",
    "cliff-explosives",
    "concrete",
    "logistic-system",
    "worker-robots-speed-1",
    "worker-robots-speed-2",
    "electric-energy-accumulators",
    "electric-energy-distribution-1",
    "electric-energy-distribution-2",
    "electric-engine",
    "lubricant",
    "fast-inserter",
    "inserter-capacity-bonus-2",
    "research-speed-2",
    "lamp",
    "laser",
    "laser-turret",
    "personal-laser-defense-equipment",
    "laser-shooting-speed-1",
    "laser-shooting-speed-2",
    "laser-shooting-speed-3",
    "logistics-2",
    "mining-productivity-1",
    "nuclear-power",
    "uranium-ammo",
    "uranium-processing",
    -- "nuclear-fuel-reprocessing",
    "plastics",
    "sulfur-processing",
    "solar-energy",
    "solar-panel-equipment",
    "military-3",
    "advanced-oil-processing",
    "coal-liquefaction",
    "defender",
    "destroyer",
    "discharge-defense-equipment",
    "distractor",
    "laser-weapons-damage-1",
    "laser-weapons-damage-2",
    "follower-robot-count-1",
    "follower-robot-count-2",
    "robotics",
    "logistic-robotics",
    "construction-robotics",

}

ei_data.tech_structure["computer-age"] = {
    -- green circ
    "weapon-shooting-speed-3",
    "weapon-shooting-speed-4",
    "stronger-explosives-3",
    "explosive-rocketry",
    "processing-unit",
    "automation-3",
    "battery-mk2-equipment",
    "energy-shield-mk2-equipment",
    "power-armor-mk2",
    "personal-roboport-mk2-equipment",
    "braking-force-6",
    "braking-force-7",
    "modules",
    -- "effect-transmission",
    "efficiency-module",
    "efficiency-module-2",
    "efficiency-module-3",
    "productivity-module",
    "productivity-module-2",
    "productivity-module-3",
    "speed-module",
    "speed-module-2",
    "speed-module-3",
    "inserter-capacity-bonus-3",
    "inserter-capacity-bonus-4",
    "stronger-explosives-4",
    "stronger-explosives-5",
    --"research-speed-3",
    --"research-speed-4",
    "refined-flammables-5",
    "refined-flammables-6",
    "weapon-shooting-speed-5",
    "weapon-shooting-speed-6",
    "physical-projectile-damage-5",
    "physical-projectile-damage-6",
    "laser-shooting-speed-4",
    "laser-shooting-speed-5",
    "laser-shooting-speed-6",
    "laser-shooting-speed-7",
    "worker-robots-speed-3",
    "worker-robots-speed-4",
    "worker-robots-storage-1",
    "worker-robots-storage-2",
    "laser-weapons-damage-3",
    "laser-weapons-damage-4",
    "logistics-3",
    "low-density-structure",
    "mining-productivity-2",
    "rocket-fuel",
    "rocket-silo",
    "rocketry",
    "spidertron",
    "bulk-inserter",
    "military-4",
    "artillery",
    "follower-robot-count-3",
    "follower-robot-count-4",
    "fission-reactor-equipment"

}

ei_data.tech_structure["quantum-age"] = {
    "atomic-bomb",
    "inserter-capacity-bonus-5",
    "inserter-capacity-bonus-6",
    "inserter-capacity-bonus-7",
    "worker-robots-speed-5",
    "worker-robots-speed-6",
    "worker-robots-storage-3",
    "refined-flammables-7",
    "physical-projectile-damage-7",
    "research-speed-5",
    "research-speed-6",
    "stronger-explosives-6",
    "stronger-explosives-7",
    "mining-productivity-3",
    "mining-productivity-4",
    "laser-weapons-damage-5",
    "laser-weapons-damage-6",
    "laser-weapons-damage-7",
    "follower-robot-count-5",
    "artillery-shell-range-1",
    "artillery-shell-speed-1",
}

ei_data.tech_structure["exotic-age"] = {

}

ei_data.tech_exclude_list = {
    "logistic-science-pack",
    "chemical-science-pack",
    "military-science-pack",
    "production-science-pack",
    "utility-science-pack"
}

ei_data.tech_swap_dict = {
    ["automation-science-pack"] = "ei-dark-age",
    ["logistic-science-pack"] = "ei-steam-age",
    ["chemical-science-pack"] = "ei-electricity-age",
    ["military-science-pack"] = "ei-electricity-age",
    ["production-science-pack"] = "ei-computer-age",
    ["utility-science-pack"] = "ei-computer-age",

    ["wood-science-pack"] = "ei-dark-age",
    ["steam-science-pack"] = "ei-steam-age",
}




--====================================================================================================
--OTHER
--====================================================================================================

ei_data.specific_heat = "100kJ"
ei_data.high_specific_heat = "1000kJ"

ei_data.matter_stabilizer.matter_range = 10
ei_data.matter_stabilizer.alien_range = 12

ei_data.beacon_range = 6

--====================================================================================================
--FUEL COMBINATIONS FOR FUSION REACTOR
--====================================================================================================

--> refer to the fusion reator prototype definition for more info

-- entries in MJ
-- time 10 since at least 5 of each fuel is required
ei_data.fusion.fuel_combinations = {
    ["ei-heated-protium"] = {
        ["ei-heated-protium"] = nil,
        ["ei-heated-deuterium"] = nil,
        ["ei-heated-tritium"] = nil,
        ["ei-heated-helium-3"] = nil,
        ["ei-heated-lithium-6"] = 2*60*10,
    },
    ["ei-heated-deuterium"] = {
        ["ei-heated-protium"] = nil,
        ["ei-heated-deuterium"] = 2*100*10,
        ["ei-heated-tritium"] = 2*200*10,
        ["ei-heated-helium-3"] = 2*220*10,
        ["ei-heated-lithium-6"] = 2*120*10,
    },
    ["ei-heated-tritium"] = {
        ["ei-heated-protium"] = nil,
        ["ei-heated-deuterium"] = 2*200*10,
        ["ei-heated-tritium"] = 2*300*10,
        ["ei-heated-helium-3"] = 2*380*10,
        ["ei-heated-lithium-6"] = nil,
    },
    ["ei-heated-helium-3"] = {
        ["ei-heated-protium"] = nil,
        ["ei-heated-deuterium"] = 2*220*10,
        ["ei-heated-tritium"] = 2*380*10,
        ["ei-heated-helium-3"] = 2*420*10,
        ["ei-heated-lithium-6"] = 2*220*10,
    },
    ["ei-heated-lithium-6"] = {
        ["ei-heated-protium"] = 2*60*10,
        ["ei-heated-deuterium"] = 2*120*10,
        ["ei-heated-tritium"] = nil,
        ["ei-heated-helium-3"] = 2*220*10,
        ["ei-heated-lithium-6"] = nil,
    },
}

ei_data.fusion.max_power = 2*420*2*1.2*10 -- 2*420MW * 2 * 1.2 * 10 = 2*10.080MW
-- for reference efficient, non breeder, DT = 200MW * 0.75 * 1.2 * 10 = 1.800MW

-- value is multiplied with power output
ei_data.fusion.temp_modes = {
    ["low"] = 0.2,
    ["medium"] = 1,
    ["high"] = 1.2,
}

-- first value is multiplied with power output
-- second value is fuel usage per second
ei_data.fusion.fuel_injection_modes = {
    ["low"] = {0.75, 5},
    ["medium"] = {1, 10},
    ["high"] = {2, 25},
}

-- multiplactors for the neutron flux calculation
ei_data.fusion.fuel_neutron_flux = {
    ["ei-heated-protium"] = 0.75,
    ["ei-heated-deuterium"] = 0.9,
    ["ei-heated-tritium"] = 1,
    ["ei-heated-helium-3"] = 1,
    ["ei-heated-lithium-6"] = 0.75,
}

ei_data.fusion.temp_neutron_flux = {
    ["low"] = 1,
    ["medium"] = 0.3,
    ["high"] = 0,
}

ei_data.fusion.injection_neutron_flux = {
    ["low"] = 1,
    ["medium"] = 1.5,
    ["high"] = 2,
}

-- fuel value of 1 hot coolant in MJ
ei_data.fusion.coolant_fuel_value = 40
-- power output in MW
ei_data.fusion.turbine_power = 400

-- amount of plasma per 1 fluid unit
ei_data.fusion.plasma_per_unit = 10

--====================================================================================================
--GAIA STUFF
--====================================================================================================

ei_data.repair_tools = {
    ["ei-crystal-accumulator-repair"] = {
        targets = {
            ["ei-crystal-accumulator_off-1"] = true,
            ["ei-crystal-accumulator_off-2"] = true,
            ["ei-crystal-accumulator_off-3"] = true,
            ["ei-crystal-accumulator_off-4"] = true
        },
        result = "ei-crystal-accumulator"
    },
    ["ei-farstation-repair"] = {
        targets = {
            ["ei-farstation_off-1"] = true,
            ["ei-farstation_off-2"] = true,
            ["ei-farstation_off-3"] = true,
        },
        result = "ei-farstation"
    },
    ["ei-alien-beacon-repair"] = {
        targets = {
            ["ei-alien-beacon_off-1"] = true,
            ["ei-alien-beacon_off-2"] = true,
            ["ei-alien-beacon_off-3"] = true,
        },
        result = "ei-alien-beacon"
    }
}

-- only used during data phase
function ei_data.repair_tool_entity_filter(name)
  local entity_filter = {}
  for ent, _ in pairs(ei_data.repair_tools[name].targets) do
    table.insert(entity_filter, ent)
  end
  return entity_filter
end

return ei_data
