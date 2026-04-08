
local planet_map_gen = require("__space-age__/prototypes/planet/planet-map-gen")
local gaia_biomes = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/biomes")
local gaia_decorative_settings = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/decoratives")

local gaia_patch_controls = {
    ["ei-morphium-patch"] = {frequency = 4.2, size = 0.72, richness = 1.2},
    ["ei-phytogas-patch"] = {frequency = 2.4, size = 1.15, richness = 0.95},
    ["ei-cryoflux-patch"] = {frequency = 2.8, size = 0.68, richness = 1.4},
    ["ei-ammonia-patch"] = {frequency = 3.4, size = 0.86, richness = 1.05},
    ["ei-coal-gas-patch"] = {frequency = 2.2, size = 1.08, richness = 1.1},
    ["ei-gaia-relic-debris"] = {frequency = 0.14, richness = 0.2, size = 0.12},
}

local gaia_entity_settings = table.deepcopy(gaia_patch_controls)
gaia_entity_settings["ei-gaia-tree-01"] = {frequency = 1.4, richness = 1, size = 0.85}
gaia_entity_settings["ei-gaia-tree-02"] = {frequency = 1.15, richness = 1, size = 0.75}
gaia_entity_settings["ei-gaia-tree-03"] = {frequency = 1.0, richness = 1, size = 0.65}
gaia_entity_settings["ei-gaia-tree-04"] = {frequency = 0.8, richness = 1, size = 0.6}
gaia_entity_settings["ei-gaia-tree-05"] = {frequency = 0.55, richness = 1, size = 0.5}
gaia_entity_settings["ei-gaia-tree-06"] = {frequency = 0.7, richness = 1, size = 0.55}
gaia_entity_settings["ei-gaia-boulder-big"] = {frequency = 0.28, richness = 1, size = 0.5}
gaia_entity_settings["ei-gaia-crystal-boulder"] = {frequency = 0.08, richness = 1, size = 0.25}

local gaia_tile_groups = gaia_biomes.tile_groups

local gaia_tile_settings = {}

for _, tile_group in pairs(gaia_biomes.primary_tile_groups) do
    for _, tile_name in ipairs(tile_group) do
        gaia_tile_settings[tile_name] = {frequency = 1, richness = 1, size = 1}
    end
end

data:extend({
    {
        type = "autoplace-control",
        name = "gaia_water",
        order = "g-a-i-a",
        category = "terrain",
        localised_name = {"autoplace-control-names.gaia_water"},
    },
    {
        type = "autoplace-control",
        name = "gaia_trees",
        localised_name = {"autoplace-control-names.gaia_trees"},
        order = "g-a-i-b",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_meadow",
        localised_name = {"autoplace-control-names.gaia_meadow"},
        order = "g-a-i-c",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_wetlands",
        localised_name = {"autoplace-control-names.gaia_wetlands"},
        order = "g-a-i-d",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_rocks",
        localised_name = {"autoplace-control-names.gaia_rocks"},
        order = "g-a-i-e",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_boulders",
        localised_name = {"autoplace-control-names.gaia_boulders"},
        order = "g-a-i-f",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_decoratives",
        localised_name = {"autoplace-control-names.gaia_decoratives"},
        order = "g-a-i-g",
        category = "terrain",
    },
    {
        type = "autoplace-control",
        name = "gaia_cliff",
        order = "g-a-i-h",
        category = "cliff",
        richness = true,
    },
})

local function build_gaia_autoplace_controls()
    local autoplace_controls = table.deepcopy(gaia_patch_controls)
    autoplace_controls["gaia_water"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_trees"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_meadow"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_wetlands"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_rocks"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_boulders"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_decoratives"] = {frequency = 1, size = 1}
    autoplace_controls["gaia_cliff"] = {}
    return autoplace_controls
end

local function build_gaia_autoplace_settings()
    return {
        entity = {settings = table.deepcopy(gaia_entity_settings)},
        decorative = {settings = table.deepcopy(gaia_decorative_settings)},
        tile = {settings = table.deepcopy(gaia_tile_settings)},
    }
end

planet_map_gen.gaia = function ()
    local map_gen_settings = {
        default_enable_all_autoplace_controls = false,
        terrain_segmentation = 0.75,
        water = "ei-gaia-water",
        autoplace_controls = build_gaia_autoplace_controls(),
        autoplace_settings = build_gaia_autoplace_settings(),
        cliff_settings = {
            name = "cliff-gaia",
            control = "gaia_cliff",
            cliff_elevation_0 = 18,
            cliff_elevation_interval = 80,
            richness = 0.35,
            cliff_smoothing = 0.15,
        },
        property_expression_names = {
            -- Gaia keeps climate, biome, and water placement on the same expression family
            -- so tile bands and tree stages describe the same terrain instead of drifting apart.
            aux = "gaia_aux",
            cliff_elevation = "cliff_elevation_from_elevation",
            cliffiness = "gaia_cliffiness",
            elevation = "gaia_elevation",
            moisture = "gaia_moisture",
            temperature = "gaia_temperature",
        }
    }

    if mods["Electric_flying_enemies"] then
        map_gen_settings.no_enemies_mode = false
        map_gen_settings.autoplace_controls["electric_enemies"] = {frequency = 1, richness = 1, size = 5}
        map_gen_settings.autoplace_settings.entity.settings["flying-electric-unit-spawner"] = {}
        map_gen_settings.autoplace_settings.entity.settings["walker-electric-unit-spawner"] = {}
    end

    return map_gen_settings
end

planet_map_gen.gaia_tile_groups = table.deepcopy(gaia_tile_groups)

return planet_map_gen
