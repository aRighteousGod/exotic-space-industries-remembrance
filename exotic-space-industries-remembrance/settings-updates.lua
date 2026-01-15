local function set_bool(mod,name,value)
  if mods[mod] then
    if not data.raw["bool-setting"][name] then
      log("EI set_bool: Setting "..name.." not found in data.raw.bool-setting")
      return
    end
    data.raw["bool-setting"][name].hidden = true
    data.raw["bool-setting"][name]["default_value"] = value
    data.raw["bool-setting"][name]["forced_value"] = value
    data.raw["bool-setting"][name]["allowed_values"] = {value}
  end
end


local function set_string(mod,name,value)
  if mods[mod] then
    if not data.raw["string-setting"][name] then
      log("EI set_string: Setting "..name.." not found in data.raw.string-setting")
      return
    end
    data.raw["string-setting"][name].hidden = true
    data.raw["string-setting"][name]["default_value"] = value
    data.raw["string-setting"][name]["forced_value"] = value
    data.raw["string-setting"][name]["allowed_values"] = {value}
  end
end


local function set_int(mod,name,value)
  if mods[mod] then
    if not data.raw["int-setting"][name] then
      log("EI set_int: Setting "..name.." not found in data.raw.int-setting")
      return
    end
    data.raw["int-setting"][name].hidden = true
    data.raw["int-setting"][name]["default_value"] = value
    data.raw["int-setting"][name]["forced_value"] = value
    data.raw["int-setting"][name]["allowed_values"] = {value}
    data.raw["int-setting"][name]["minimum_value"] = value-1
    data.raw["int-setting"][name]["maximum_value"] = value+1
  end
end


local function set_float(mod,name,value)
  if mods[mod] then
    if not data.raw["double-setting"][name] then
      log("EI set_float: Setting "..name.." not found in data.raw.double-setting")
      return
    end
    data.raw["double-setting"][name].hidden = true
    data.raw["double-setting"][name]["default_value"] = value
    data.raw["double-setting"][name]["forced_value"] = value
    data.raw["double-setting"][name]["allowed_values"] = {value}
    data.raw["double-setting"][name]["minimum_value"] = value-0.01
    data.raw["double-setting"][name]["maximum_value"] = value+0.01
  end
end

local function set_color(mod,name,value)
  if mods[mod] then
    if not data.raw["color-setting"][name] then
      log("EI set_color: Setting "..name.." not found in data.raw.color-setting")
      return
    end
    data.raw["color-setting"][name].hidden = true
    data.raw["color-setting"][name]["default_value"] = value
    data.raw["color-setting"][name]["forced_value"] = value
    data.raw["color-setting"][name]["allowed_values"] = {value}
  end
end

-- set_bool("passive-radar","mining-returns-pradar",true)
-- set_bool("","",true)

-- ==========================================================

set_bool("SpidertronPatrols","sp-enable-spiderling",true)
set_bool("SpidertronPatrols","sp-remove-military-requirement",true)

-- ==========================================================

set_bool("lignumis","lignumis-belt-progression",false)
set_bool("lignumis","lignumis-inserter-progression",false)
set_bool("lignumis","lignumis-ammo-progression",false)

set_string("Explosive_biters","eb-spawn-planet","both")
set_bool("Cold_biters","fb-enable-dying-explosion",true)
set_string("Cold_biters","fb-spawn-planet","both")
set_bool("Toxic_biters","tb-allow-infection",true)
set_bool("zeus-wrath","zeus-wrath-friendly-fire",true)
set_bool("zeus-wrath","zeus-wrath-friendly-fire-gun",true)

set_float("rp_steam_roboports","rp_steam_roboports_roboport_drain_kj",500)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_charge_kw",1000)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_electric_buffer_kj",9000)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_steam_buffer_kj",18000)
set_int("rp_steam_roboports","rp_steam_roboports_roboport_charge_slots",4)
set_float("rp_steam_roboports","rp_steam_roboports_vanilla_bot_speed",0.06)
set_float("rp_steam_roboports","rp_steam_roboports_bot_speed",0.055)
set_float("rp_steam_roboports","rp_steam_roboports_bot_max_energy_kj",1500)
set_float("rp_steam_roboports","rp_steam_roboports_bot_energy_per_tick_kj",0.05)
set_float("rp_steam_roboports","rp_steam_roboports_bot_energy_per_move_kj",5.5)
set_bool("rp_steam_roboports","rp_steam_roboports_bot_die_when_out_of_energy",true)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_low_kw",100)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_medium_kw",200)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_high_kw",400)
set_bool("atan-ash","atan-ash-entities-burn",false)
set_int("Flare Stack", "flare-stack-fluid-rate",5)
set_int("Flare Stack","flare-stack-item-rate",1)
set_float("Flammable_Oils_QUICKFIX","flo-radius-mult",0.5)
set_float("Flammable_Oils_QUICKFIX","flo-damage-mult",5)
set_float("Flammable_Oils_QUICKFIX","flo-radius-power",3)
set_float("Flammable_Oils_QUICKFIX","flo-damage-power",3)
set_int("ch-concentrated-solar","ch-solar-max-production-mw",120)
set_bool("elevated-pipes","elevated-pipes--freezes",true)
set_int("elevated-pipes","max-underground-distance",12)
set_color("SolarMatrix","solar-matrix-color", {r=1, g=1, b=1, a=1})
set_float("SolarMatrix","solar-matrix-power",128)
set_bool("SolarMatrix","link-multiplier-to-cost",false)
set_float("Accumulator-V2","accumulator-power-capacity", 10)
set_bool("Accumulator-V2","multiply-costs",false)
set_bool("Assembler-Reskin","toggle-reskin",true)
set_color("Assembler-Reskin","assembler-1-color",{r = 0.47, g = 0.5, b = 0.43, a = 1.0})
set_color("Assembler-Reskin","assembler-2-color",{r = 0.13, g = 0.25, b = 0.66, a = 1.0})
set_color("Assembler-Reskin","assembler-3-color",{r = 0.7, g = 0.8, b = 0.32, a = 1.0})
set_int("enhanced-walls","plated-wall-tech-cost",10)
set_int("enhanced-walls","plated-wall-health",1000)
set_float("enhanced-walls","plated-wall-mining-time", 0.2)
set_int("enhanced-walls","plated-wall-res-phys-flat",10)
set_int("enhanced-walls","plated-wall-res-phys-percent",40)
set_int("enhanced-walls","plated-wall-res-impact-flat",80)
set_int("enhanced-walls","plated-wall-res-impact-percent",80)
set_int("enhanced-walls","plated-wall-res-exp-flat",15)
set_int("enhanced-walls","plated-wall-res-exp-percent",50)
set_int("enhanced-walls","plated-wall-res-acid-flat",10)
set_int("enhanced-walls","plated-wall-res-acid-percent",80)
set_int("enhanced-walls","tough-wall-tech-cost",10)
set_int("enhanced-walls","tough-wall-health",700)
set_float("enhanced-walls","tough-wall-mining-time", 0.2)
set_int("enhanced-walls","tough-wall-res-phys-flat",3)
set_int("enhanced-walls","tough-wall-res-phys-percent",20)
set_int("enhanced-walls","tough-wall-res-impact-flat",45)
set_int("enhanced-walls","tough-wall-res-impact-percent",60)
set_int("enhanced-walls","tough-wall-res-exp-flat",10)
set_int("enhanced-walls","tough-wall-res-exp-percent",30)
set_int("enhanced-walls","tough-wall-res-acid-flat",0)
set_int("enhanced-walls","tough-wall-res-acid-percent",50)
set_string("tesla_legacy_sa","tl-advanced-attack-anim","charge-up")
set_int("tesla_legacy_sa","tl-advanced-health",1600)
set_int("tesla_legacy_sa","tl-advanced-damage",100)
set_float("tesla_legacy_sa","tl-advanced-fire-rate",0.25)
set_int("tesla_legacy_sa","tl-advanced-range",18)
set_int("tesla_legacy_sa","tl-basic-health",750)
set_int("tesla_legacy_sa","tl-basic-damage",10)
set_float("tesla_legacy_sa","tl-basic-fire-rate",0.5)
set_int("tesla_legacy_sa","tl-basic-range",12)
set_int("tesla_legacy_sa","tl-tank-health",2500)
set_int("tesla_legacy_sa","tl-tank-damage",150)
set_float("tesla_legacy_sa","tl-tank-fire-rate",0.75)
set_int("tesla_legacy_sa","tl-tank-range",24)
set_float("tesla_legacy_sa","tl-critical-multiplier",2)
set_float("tesla_legacy_sa","tl-critical-chance",0.5)