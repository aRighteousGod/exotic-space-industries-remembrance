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

set_float("rp_steam_roboports","rp_steam_roboports_roboport_drain_kj",100)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_charge_kw",1000)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_electric_buffer_kj",5000)
set_float("rp_steam_roboports","rp_steam_roboports_roboport_steam_buffer_kj",12000)
set_int("rp_steam_roboports","rp_steam_roboports_roboport_charge_slots",4)
set_float("rp_steam_roboports","rp_steam_roboports_vanilla_bot_speed",0.06)
set_float("rp_steam_roboports","rp_steam_roboports_bot_speed",0.055)
set_float("rp_steam_roboports","rp_steam_roboports_bot_max_energy_kj",1500)
set_float("rp_steam_roboports","rp_steam_roboports_bot_energy_per_tick_kj",0.055)
set_float("rp_steam_roboports","rp_steam_roboports_bot_energy_per_move_kj",6)
set_bool("rp_steam_roboports","rp_steam_roboports_bot_die_when_out_of_energy",true)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_low_kw",100)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_medium_kw",200)
set_float("rp_steam_roboports","rp_steam_roboports_chests_power_high_kw",400)
set_bool("atan-ash","atan-ash-entities-burn",true)