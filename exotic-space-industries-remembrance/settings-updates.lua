local function set_bool(mod,name,value)
  if mods[mod] then
    data.raw["bool-setting"][name].hidden = true
    data.raw["bool-setting"][name]["default_value"] = value
    data.raw["bool-setting"][name]["forced_value"] = value
    data.raw["bool-setting"][name]["allowed_values"] = {value}
  end
end


local function set_string(mod,name,value)
  if mods[mod] then
    data.raw["string-setting"][name].hidden = true
    data.raw["string-setting"][name]["default_value"] = value
    data.raw["string-setting"][name]["forced_value"] = value
    data.raw["string-setting"][name]["allowed_values"] = {value}
  end
end


local function set_int(mod,name,value)
  if mods[mod] then
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

set_string("Explosive_Biters","eb-spawn-planet","both")
set_bool("Cold_Biters","cb-enable-dying-explosion",true)
set_string("Cold_Biters","cb-spawn-planet","both")
set_bool("Toxic_Biters","tb-allow-infection",true)





