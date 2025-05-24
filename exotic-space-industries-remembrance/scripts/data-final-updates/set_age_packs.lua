ei_lib.set_age_packs("ei-gaia","computer-age-space")
ei_lib.set_age_packs("space-platform-thruster","computer-age")
ei_lib.set_age_packs("aai-signal-transmission","computer-age")
ei_lib.set_age_packs("ei-computer-core","computer-age")
ei_lib.set_age_packs("recycling","computer-age")
ei_lib.set_age_packs("ei-morphium-usage","computer-age")
ei_lib.set_age_packs("kovarex-enrichment-process","computer-age")
ei_lib.set_age_packs("ei-black-hole","black-hole-exotic-age")
ei_lib.set_age_packs("ei-accelerator","exotic-age")
ei_lib.set_age_packs("electronics","steam-age")
ei_lib.set_age_packs("steel-axe","steam-age")
ei_lib.set_age_packs("oil-processing","steam-age")
ei_lib.set_age_packs("logistic-system","electricity-age")
ei_lib.set_age_packs("cliff-explosives","computer-age")
ei_lib.set_age_packs("refined-flammables-6","computer-age")
ei_lib.set_age_packs("rocket-fuel","computer-age")
ei_lib.set_age_packs("rocket-silo","computer-age")
ei_lib.set_age_packs("crusher","computer-age")
ei_lib.set_age_packs("anorthite-processing","computer-age")
ei_lib.set_age_packs("advanced-boiler","computer-age")
ei_lib.set_age_packs("greenhouses","computer-age")
ei_lib.set_age_packs("asteroid-collector","computer-age")
ei_lib.set_age_packs("wood-gas-processing","computer-age")
ei_lib.set_age_packs("space-science-pack","computer-age")
ei_lib.set_age_packs("space-hub-chest","computer-age")
ei_lib.set_age_packs("space-chest","computer-age")
ei_lib.set_age_packs("planet-discovery-muluna","computer-age")
ei_lib.set_age_packs("advanced-wood-gas-processing","computer-age-space")
ei_lib.set_age_packs("wood-gas-processing-to-crude-oil","computer-age-space")

ei_lib.set_science_packs("interstellar-science-pack",ei_data.science["interstellar"])

ei_lib.copy_science_packs("uranium-processing","ei-computer-core")
ei_lib.copy_science_packs("processing-unit","advanced-circuit")
ei_lib.copy_science_packs("ei-advanced-computer-age-tech","ei-big-lab")
ei_lib.copy_science_packs("ei-alien-computer-age-tech","ei-big-lab")
ei_lib.copy_science_packs("science-pack-productivity","promethium-science-pack") 

ei_lib.set_age_packs("ei-electricity-power","electricity-age")
ei_lib.set_age_packs("electric-engine","electricity-age")
ei_lib.set_age_packs("electric-mining-drill","electricity-age")
ei_lib.set_age_packs("ei_fueler","electricity-age")

if ei_lib.config("no-triggers") then
  for _,tech in pairs(data.raw.technology) do
    if data.raw.technology[tech.name]["research_trigger"] then 
      if tech.age then ei_lib.set_age_packs(tech.name,tech.age)
      else ei_lib.set_age_packs(tech.name,"computer-age") end
    end 
  end 
end

ei_lib.set_age_packs("copper-processing","steam-age")
ei_lib.set_age_packs("iron-processing","steam-age")
ei_lib.set_age_packs("burner-mechanics","dark-age")
ei_lib.set_age_packs("basic-logistics","dark-age")

ei_lib.set_age_packs("oil-processing","electricity-age")
ei_lib.set_age_packs("kr-gas-power-station","electricity-age")
