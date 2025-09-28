
local planet_map_gen = require("__space-age__/prototypes/planet/planet-map-gen")
data:extend({
    {
    type = "autoplace-control",
    name = "gaia_cliff",
    order = "g-a-i-a",
    category = "cliff",
    richness = true,
  },
})
planet_map_gen.gaia = function ()
    local map_gen_settings = table.deepcopy(data.raw.planet.fulgora.map_gen_settings)

    map_gen_settings.default_enable_all_autoplace_controls = false
    map_gen_settings.terrain_segmentation = 0.75

    map_gen_settings.autoplace_controls["ei-morphium-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_controls["ei-phytogas-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_controls["ei-cryoflux-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_controls["ei-ammonia-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_controls["ei-coal-gas-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_controls["scrap"] = {frequency = 0.05, richness = 0.05, size = 0.05 }
    
    if mods["Electric_flying_enemies"] then
        map_gen_settings.no_enemies_mode=false
        map_gen_settings.autoplace_controls["electric_enemies"] = {frequency = 1, richness =1, size = 1 }
    end

    map_gen_settings.autoplace_settings.entity.settings = {}
    map_gen_settings.autoplace_settings.entity.settings["ei-morphium-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-phytogas-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-cryoflux-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-ammonia-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-coal-gas-patch"] = {frequency = 3, size = 1, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["scrap"] = {frequency = 0.05, richness = 0.05, size = 0.05 }

    --map_gen_settings.autoplace_settings.decorative.settings["fulgoran-ruin-tiny"] = nil
    map_gen_settings.autoplace_settings.decorative.settings = {}
    --[[
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-1"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-2"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-3"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-4"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-5"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-6"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-7"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-8"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-9"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-10"] = {frequency = 1, size = 4, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings["ei-alien-flowers-11"] = {frequency = 1, size = 4, richness = 1}
    ]]
    map_gen_settings.cliff_settings.name = "cliff-gaia"
    map_gen_settings.cliff_settings.control = "gaia_cliff"
    map_gen_settings.cliff_settings.cliff_elevation_0 = 0
    map_gen_settings.cliff_settings.cliff_elevation_interval = 0
    map_gen_settings.cliff_settings.richness = 0
    map_gen_settings.cliff_settings.cliff_smoothing = 0

    map_gen_settings.property_expression_names.aux = "aux_basic"
    map_gen_settings.property_expression_names.cliff_elevation = "cliff_elevation_from_elevation"
    map_gen_settings.property_expression_names.cliffiness = "fulgora_cliffiness"
    map_gen_settings.property_expression_names.elevation = "fulgora_elevation"
    map_gen_settings.property_expression_names.moisture = "moisture_basic"
    map_gen_settings.property_expression_names.temperature = "temperature_basic"

    map_gen_settings.autoplace_settings.tile.settings = {
        ["ei-gaia-grass-1"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-grass-2"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-grass-1-var"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-grass-2-var"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-grass-2-var-2"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-rock-1"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-rock-2"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-rock-3"] = { frequency = 1, richness = 1, size = 1 },
        ["ei-gaia-water"] = { frequency = 1, richness = 1, size = 1 },
    }

    return map_gen_settings
end

return planet_map_gen