--====================================================================================================
--PRESERVE THE CUSTOM DEFAULT PRESET WITHOUT GAIA-SPECIFIC AUTOPLACE OVERRIDES
--====================================================================================================

local presets = data.raw["map-gen-presets"] and data.raw["map-gen-presets"].default
if presets and presets.default then
    presets["ei-default"] = table.deepcopy(presets.default)
    presets["ei-default"].order = "a"
end
