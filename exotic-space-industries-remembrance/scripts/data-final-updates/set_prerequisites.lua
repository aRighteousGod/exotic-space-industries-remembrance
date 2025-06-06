

-- ==========================================================================================================

local science_pack_unlock = {["ei-dark-age-tech"]="ei-dark-age"}
local tiered_tech = {}
local name = ""
local untiered = ""
local tier = 0

for _,tech in pairs(data.raw.technology) do

  if ei_lib.config("tech-tree-flatten") then
    for i = 1,4 do
      if tonumber(string.sub(tech.name, -i)) then 
        tiered_tech[tech.name] = true
      end      
    end

    if tech.effects and tech.unit and tech.unit.ingredients then
      data.raw.technology[tech.name].prerequisites = {}
      for i,v in ipairs(tech.effects) do
        if v.type == "unlock-recipe" then
          if data.raw.tool[v.recipe] then 
            if not science_pack_unlock[v.recipe] then 
              science_pack_unlock[v.recipe] = tech.name
            end
          end
        end
      end
    end
  end

end

-- error(serpent.block(science_pack_unlock))
-- error(serpent.block(tiered_tech))


if ei_lib.config("tech-tree-flatten") then
  for _,tech in pairs(data.raw.technology) do
    if tiered_tech[tech.name] then 
      tier = tonumber(string.sub(tech.name, -1))
      untiered = string.sub(tech.name, 0, -3)
      
      if not tier then 
        tier = tonumber(string.sub(tech.name, -2)) 
        untiered = string.sub(tech.name, 0, -4)
      end 

      if not tier then error("Can not get tier for tech "..tech.name) end 
      
      -- error(tech.name.." | "..tier.." | "..untiered)
      
      for i = tier-1,0,-1 do 
        name = untiered.."-"..i
        if data.raw.technology[name] then ei_lib.add_prerequisite(tech.name,name) end
      end

      if data.raw.technology[untiered] then ei_lib.add_prerequisite(tech.name,untiered) end

    end

    name = string.gsub(tech.name, "basic", "advanced")
    if data.raw.technology[name] and name ~= tech.name then ei_lib.add_prerequisite(tech.name,name) end

    name = string.gsub(tech.name, "steel", "material")
    if data.raw.technology[name] and name ~= tech.name then ei_lib.add_prerequisite(tech.name,name) end

    name = string.gsub(tech.name, "mk1", "mk2")
    if data.raw.technology[name] and name ~= tech.name then ei_lib.add_prerequisite(tech.name,name) end

    name = string.gsub(tech.name, "mk2", "mk3")
    if data.raw.technology[name] and name ~= tech.name then ei_lib.add_prerequisite(tech.name,name) end

    name = "advanced-"..tech.name
    if data.raw.technology[name] then ei_lib.add_prerequisite(tech.name,name) end

    mod_prefix,name = tech.name:match("^(.+)-(.+)")
    if name then 
      name = mod_prefix.."-".."advanced".."-"..name
      if data.raw.technology[name] and name ~= tech.name then ei_lib.add_prerequisite(tech.name,name) end
    end

    if tech.effects and tech.unit and tech.unit.ingredients then
      for x,y in ipairs(tech.unit.ingredients) do
        -- error(y[1])
        if science_pack_unlock[y[1]] and tech.name ~= science_pack_unlock[y[1]] then 
          ei_lib.add_prerequisite(tech.name,science_pack_unlock[y[1]])
        end
      end
    end

  end
end


-- error(serpent.block(data.raw.technology[i].unit.ingredients))
-- error(serpent.block(data.raw.technology["physical-projectile-damage-4"].prerequisites))
-- error(serpent.block(data.raw.technology["repair-pack"].prerequisites))

-- ======================================================================================

ei_lib.set_prerequisites("kovarex-enrichment-process",{"uranium-processing"})
ei_lib.set_prerequisites("processing-unit",{"advanced-circuit"})
ei_lib.set_prerequisites("ei-electronic-parts",{"processing-unit"})
ei_lib.set_prerequisites("ei-lithium-battery",{"lithium-processing"})
ei_lib.set_prerequisites("ei-lithium-processing",{"lithium-processing"})
ei_lib.set_prerequisites("space-platform-thruster",{"rocket-silo"})
ei_lib.set_prerequisites("ei-iron-beacon",{"ei-copper-beacon"})
ei_lib.set_prerequisites("ei-superior-electric-mining-drill",{"ei-quantum-computer"})
ei_lib.set_prerequisites("recycling",{"rocket-silo"})
ei_lib.set_prerequisites("holmium-processing",{"recycling","planet-discovery-fulgora"})

ei_lib.set_prerequisites("planet-discovery-castra",{"rocket-silo"})
ei_lib.set_prerequisites("rocket-fuel",{"ei-computer-age"})

ei_lib.set_prerequisites("agriculture",{"planet-discovery-gleba"})
ei_lib.set_prerequisites("heating-tower",{"planet-discovery-gleba"})
ei_lib.set_prerequisites("lithium-processing",{"planet-discovery-aquilo"})
ei_lib.set_prerequisites("tungsten-carbide",{"planet-discovery-vulcanus"})

ei_lib.set_prerequisites("logistic-robotics",{"robotics"})
ei_lib.set_prerequisites("construction-robotics",{"robotics"})

ei_lib.set_prerequisites("worker-robots-storage-1",{"logistic-robotics","construction-robotics"})
ei_lib.set_prerequisites("worker-robots-speed-1",{"logistic-robotics","construction-robotics"})

ei_lib.set_prerequisites("worker-robots-storage-2",{"worker-robots-storage-1"})
ei_lib.set_prerequisites("worker-robots-storage-3",{"worker-robots-storage-2"})
ei_lib.set_prerequisites("worker-robots-storage-4",{"worker-robots-storage-3"})

ei_lib.set_prerequisites("nuclear-power",{"uranium-mining"})
ei_lib.set_prerequisites("uranium-ammo",{"uranium-mining"})

ei_lib.set_prerequisites("uranium-ammo",{"uranium-mining"})

ei_lib.set_prerequisites("asteroid-collector",{"space-platform"})
ei_lib.set_prerequisites("space-hub-chest",{"space-platform"})
ei_lib.set_prerequisites("space-chest",{"space-platform"})
ei_lib.set_prerequisites("planet-discovery-muluna",{"space-platform"})
ei_lib.set_prerequisites("space-platform-thruster",{"space-platform"})

--ei_lib.set_prerequisites("ei-steam-age",{"ei-burner-assembler","logistics"})
ei_lib.set_prerequisites("interstellar-science-pack",{"space-science-pack"})
ei_lib.set_prerequisites("interstellar-science-pack",{"space-science-pack"})
ei_lib.set_prerequisites("electric-mining-drill",{"ei-electricity-power"})
ei_lib.set_prerequisites("military-2",{"military"})
ei_lib.set_prerequisites("flamethrower",{"flammables"})

ei_lib.set_prerequisites("wdm_home_planet",{})

ei_lib.set_prerequisites("ei-quantum-age",{"ei-advanced-computer-age-tech","ei-alien-computer-age-tech"})

ei_lib.set_prerequisites("automation-2",{"automation","ei-electricity-age"})
ei_lib.set_prerequisites("ei_fueler",{"ei-electricity-age"})

ei_lib.add_prerequisite("laser-shooting-speed-1","laser")
ei_lib.add_prerequisite("laser-turret","laser")
ei_lib.add_prerequisite("laser-weapons-damage-1","laser")
ei_lib.add_prerequisite("personal-laser-defense-equipment","laser")
ei_lib.add_prerequisite("ei-personal-laser","laser")
ei_lib.add_prerequisite("ei-black-hole-exploration","ei-fusion-drive")

ei_lib.set_prerequisites("burner-mechanics",{"ei-dark-age"})
ei_lib.set_prerequisites("kr-automation-core",{"ei-dark-age"})
ei_lib.set_prerequisites("kr-iron-pickaxe",{"ei-dark-age"})

ei_lib.set_prerequisites("radar",{"ei-electricity-power"})
ei_lib.set_prerequisites("electric-energy-accumulators",{"ei-electricity-power"})
ei_lib.set_prerequisites("electric-energy-distribution-1",{"ei-electricity-power"})

ei_lib.set_prerequisites("electric-energy-distribution-2",{"electric-energy-distribution-1"})

ei_lib.set_prerequisites("battery",{"electric-energy-accumulators"})
ei_lib.set_prerequisites("battery-equipment",{"battery"})

ei_lib.set_prerequisites("kr-ai-core",{"ei-advanced-computer-age-tech"})

ei_lib.set_prerequisites("artillery-shell-range-1",{"artillery"})
ei_lib.set_prerequisites("artillery-shell-speed-1",{"artillery"})
ei_lib.set_prerequisites("artillery-shell-damage-1",{"artillery"})

ei_lib.set_prerequisites("nuclear-power",{"uranium-mining"})

ei_lib.set_prerequisites("kr-fusion-energy",{"lithium-processing","nuclear-power"})
ei_lib.set_prerequisites("captive-biter-spawner",{"cryogenic-science-pack","biter-egg-handling"})

-- ======================================================================================

if mods["planet-muluna"] then ei_lib.set_prerequisites("space-science-pack",{"planet-discovery-muluna"})
else ei_lib.set_prerequisites("space-science-pack",{"space-platform"}) end

-- ======================================================================================

if mods["lignumis"] then 
  ei_lib.set_prerequisites("ei-steam-age",{"steam-automation"})
  ei_lib.set_prerequisites("ei-burner-assembler",{"burner-automation"})
  ei_lib.set_prerequisites("repair-pack",{"basic-repair-pack"})
  ei_lib.set_prerequisites("gun-turret",{"basic-gun-turret"})
  ei_lib.set_prerequisites("logistics",{"wood-logistics"})

  ei_lib.add_prerequisite("radar", "ei-steam-age")
  ei_lib.add_prerequisite("military", "ei-steam-age")
  ei_lib.add_prerequisite("repair-pack", "ei-steam-age")
  ei_lib.add_prerequisite("gun-turret", "ei-steam-age")
  ei_lib.add_prerequisite("logistics", "ei-steam-age")
end


