-- Runtime data dump for Gaia map generation settings
-- This mirrors the data stage definitions and provides complete map_gen_settings for applying to surfaces
-- Used for old world migrations and surface reforging

local gaia_mapgen_data = {}

local function copy_value(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, nested in pairs(value) do
        clone[copy_value(key)] = copy_value(nested)
    end
    return clone
end

-- Resource patch autoplace settings (from map-gen.lua)
gaia_mapgen_data.patch_controls = {
    ["ei-morphium-patch"] = {frequency = 4.2, size = 0.72, richness = 1.2},
    ["ei-phytogas-patch"] = {frequency = 2.4, size = 1.15, richness = 0.95},
    ["ei-cryoflux-patch"] = {frequency = 2.8, size = 0.68, richness = 1.4},
    ["ei-ammonia-patch"] = {frequency = 3.4, size = 0.86, richness = 1.05},
    ["ei-coal-gas-patch"] = {frequency = 2.2, size = 1.08, richness = 1.1},
    ["ei-gaia-relic-debris"] = {frequency = 0.14, richness = 0.2, size = 0.12},
}

-- Entity autoplace settings (trees and boulders)
gaia_mapgen_data.entity_settings = {
    -- Resource patches
    ["ei-morphium-patch"] = {frequency = 4.2, size = 0.72, richness = 1.2},
    ["ei-phytogas-patch"] = {frequency = 2.4, size = 1.15, richness = 0.95},
    ["ei-cryoflux-patch"] = {frequency = 2.8, size = 0.68, richness = 1.4},
    ["ei-ammonia-patch"] = {frequency = 3.4, size = 0.86, richness = 1.05},
    ["ei-coal-gas-patch"] = {frequency = 2.2, size = 1.08, richness = 1.1},
    ["ei-gaia-relic-debris"] = {frequency = 0.14, richness = 0.2, size = 0.12},
    -- Trees
    ["ei-gaia-tree-01"] = {frequency = 1.4, richness = 1, size = 0.85},
    ["ei-gaia-tree-02"] = {frequency = 1.15, richness = 1, size = 0.75},
    ["ei-gaia-tree-03"] = {frequency = 1.0, richness = 1, size = 0.65},
    ["ei-gaia-tree-04"] = {frequency = 0.8, richness = 1, size = 0.6},
    ["ei-gaia-tree-05"] = {frequency = 0.55, richness = 1, size = 0.5},
    ["ei-gaia-tree-06"] = {frequency = 0.7, richness = 1, size = 0.55},
    -- Boulders
    ["ei-gaia-boulder-big"] = {frequency = 0.28, richness = 1, size = 0.5},
    ["ei-gaia-crystal-boulder"] = {frequency = 0.08, richness = 1, size = 0.25},
}

-- Decorative autoplace settings (from decoratives.lua)
gaia_mapgen_data.decorative_settings = {
    ["ei-gaia-meadow-carpet-grass"] = {frequency = 1.8, richness = 1, size = 1.45},
    ["ei-gaia-purple-carpet-grass"] = {frequency = 1.45, richness = 1, size = 1.25},
    ["ei-gaia-wet-carpet-grass"] = {frequency = 1.25, richness = 1, size = 1.1},
    ["ei-gaia-bloom-carpet-grass"] = {frequency = 1.25, richness = 1, size = 1.1},
    ["ei-gaia-meadow-hairy-grass"] = {frequency = 1.15, richness = 1, size = 0.9},
    ["ei-gaia-purple-hairy-grass"] = {frequency = 0.95, richness = 1, size = 0.82},
    ["ei-gaia-wet-hairy-grass"] = {frequency = 1.55, richness = 1, size = 1.2},
    ["ei-gaia-bloom-hairy-grass"] = {frequency = 1.55, richness = 1, size = 1.2},
    ["ei-gaia-meadow-bush-mini"] = {frequency = 0.48, richness = 1, size = 0.75},
    ["ei-gaia-purple-bush-mini"] = {frequency = 0.36, richness = 1, size = 0.68},
    ["ei-gaia-fringe-bush-mini"] = {frequency = 0.24, richness = 1, size = 0.5},
    ["ei-gaia-wet-asterisk-mini"] = {frequency = 0.36, richness = 1, size = 0.5},
    ["ei-gaia-bloom-asterisk-mini"] = {frequency = 0.36, richness = 1, size = 0.5},
    ["ei-gaia-shore-asterisk-mini"] = {frequency = 0.28, richness = 1, size = 0.45},
    ["ei-gaia-bloom-shore-asterisk-mini"] = {frequency = 0.28, richness = 1, size = 0.45},
    ["ei-gaia-fringe-lichen-decal"] = {frequency = 0.34, richness = 1, size = 0.55},
    ["ei-gaia-core-lichen-decal"] = {frequency = 0.22, richness = 1, size = 0.45},
    ["ei-gaia-meadow-pink-lichen-decal"] = {frequency = 0.16, richness = 1, size = 0.42},
    ["ei-gaia-purple-pink-lichen-decal"] = {frequency = 0.12, richness = 1, size = 0.38},
    ["ei-gaia-wet-pink-lichen-decal"] = {frequency = 0.08, richness = 1, size = 0.28},
    ["ei-gaia-bloom-pink-lichen-decal"] = {frequency = 0.08, richness = 1, size = 0.28},
    ["ei-gaia-wet-shroom-decal"] = {frequency = 0.18, richness = 1, size = 0.34},
    ["ei-gaia-bloom-shroom-decal"] = {frequency = 0.18, richness = 1, size = 0.34},
    ["ei-gaia-fringe-shroom-decal"] = {frequency = 0.08, richness = 1, size = 0.24},
    ["ei-gaia-tiny-rock"] = {frequency = 0.95, richness = 1, size = 1},
    ["ei-gaia-small-rock"] = {frequency = 0.55, richness = 1, size = 0.85},
    ["ei-gaia-tiny-rock-cluster"] = {frequency = 0.7, richness = 1, size = 0.9},
}

gaia_mapgen_data.tile_settings = {
    ["ei-gaia-grass-1"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-grass-2"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-grass-1-var"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-grass-2-var"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-grass-2-var-2"] = {frequency = 1, richness = 1, size = 1},
    -- Runtime-created/reforged Gaia surfaces need explicit tile candidates or the secondary
    -- rock variants can silently disappear even when the data-stage planet spawns them fine.
    ["ei-gaia-rock-1"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-rock-2"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-rock-3"] = {frequency = 1, richness = 1, size = 1},
    ["ei-gaia-water"] = {frequency = 1, richness = 1, size = 1},
}

-- All autoplace controls (including terrain and resources)
function gaia_mapgen_data.get_autoplace_controls()
    local controls = copy_value(gaia_mapgen_data.patch_controls)
    -- Terrain controls
    controls["gaia_water"] = {frequency = 1, size = 1}
    controls["gaia_trees"] = {frequency = 1, size = 1}
    controls["gaia_meadow"] = {frequency = 1, size = 1}
    controls["gaia_wetlands"] = {frequency = 1, size = 1}
    controls["gaia_rocks"] = {frequency = 1, size = 1}
    controls["gaia_boulders"] = {frequency = 1, size = 1}
    controls["gaia_decoratives"] = {frequency = 1, size = 1}
    controls["gaia_cliff"] = {}
    return controls
end

-- Complete autoplace settings with entity, decorative, and tile sections
function gaia_mapgen_data.get_autoplace_settings()
    return {
        entity = {settings = copy_value(gaia_mapgen_data.entity_settings)},
        decorative = {settings = copy_value(gaia_mapgen_data.decorative_settings)},
        tile = {settings = copy_value(gaia_mapgen_data.tile_settings)},
    }
end

function gaia_mapgen_data.get_map_gen_settings()
    local settings = {
        default_enable_all_autoplace_controls = false,
        terrain_segmentation = 0.75,
        water = "ei-gaia-water",
        autoplace_controls = gaia_mapgen_data.get_autoplace_controls(),
        autoplace_settings = gaia_mapgen_data.get_autoplace_settings(),
        cliff_settings = {
            name = "cliff-gaia",
            control = "gaia_cliff",
            cliff_elevation_0 = 18,
            cliff_elevation_interval = 80,
            richness = 0.35,
            cliff_smoothing = 0.15,
        },
        property_expression_names = {
            aux = "gaia_aux",
            cliff_elevation = "cliff_elevation_from_elevation",
            cliffiness = "gaia_cliffiness",
            elevation = "gaia_elevation",
            moisture = "gaia_moisture",
            temperature = "gaia_temperature",
        },
    }

    if script.active_mods["Electric_flying_enemies"] then
        settings.no_enemies_mode = false
        settings.autoplace_controls["electric_enemies"] = {frequency = 1, richness = 1, size = 5}
        settings.autoplace_settings.entity.settings["flying-electric-unit-spawner"] = {}
        settings.autoplace_settings.entity.settings["walker-electric-unit-spawner"] = {}
    end

    return settings
end

return gaia_mapgen_data
