local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

local presets = require("lib/spawner_presets")

local gaia = table.deepcopy(data.raw.planet.fulgora)
gaia.name = "gaia"
gaia.order = "g[gaia]"
gaia.distance = 10
gaia.orientation = 0.75
gaia.icon = ei_graphics_2_path.."graphics/icons/gaia.png"
gaia.icon_size = 64
gaia.starmap_icon = ei_graphics_2_path.."graphics/icons/starmap-planet-gaia.png"
gaia.starmap_icon_size = 2048
gaia.lightning_properties = nil

gaia.map_gen_settings.autoplace_controls["ei-phytogas-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_controls["ei-cryoflux-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_controls["ei-ammonia-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_controls["ei-morphium-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_controls["ei-coal-gas-patch"] = {frequency = 5, size = 1, richness = 1}

gaia.map_gen_settings.autoplace_settings.entity.settings["ei-phytogas-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_settings.entity.settings["ei-cryoflux-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_settings.entity.settings["ei-ammonia-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_settings.entity.settings["ei-morphium-patch"] = {frequency = 5, size = 1, richness = 1}
gaia.map_gen_settings.autoplace_settings.entity.settings["ei-coal-gas-patch"] = {frequency = 5, size = 1, richness = 1}

gaia.map_gen_settings.cliff_settings.cliff_elevation_0 = 0
gaia.map_gen_settings.cliff_settings.cliff_elevation_interval = 0
gaia.map_gen_settings.cliff_settings.richness = 0

gaia.map_gen_settings.terrain_segmentation = 0.75

gaia_water = table.deepcopy(data.raw.tile["water"]);
gaia_water.name = "ei-gaia-water"
gaia_water.fluid = "ei-morphium"; --change this to an extremely diluted version requiring refinement otherwise the patches are useless
data:extend({gaia_water})

local landfill = data.raw.item.landfill

if landfill then
--  table.insert(landfill.place_as_tile.tile_condition, "water-shallow")
--  table.insert(landfill.place_as_tile.tile_condition, "water-mud") 
  table.insert(landfill.place_as_tile.tile_condition, "ei-gaia-water") 
end

gaia.map_gen_settings.autoplace_settings.tile.settings = {
  ["ei-gaia-grass-1"] = {},
  ["ei-gaia-grass-2"] = {},
  ["ei-gaia-grass-1-var"] = {},
  ["ei-gaia-grass-2-var"] = {},
  ["ei-gaia-grass-2-var-2"] = {},
  ["ei-gaia-rock-1"] = {},
  ["ei-gaia-rock-2"] = {},
  ["ei-gaia-rock-3"] = {},
  ["ei-gaia-water"] = {},
}

-- error(serpent.block(gaia.map_gen_settings))

data:extend({gaia})
--Dumps map settings table in log to use with reforge_gaia
--[[
local serpent = require("serpent") --File normally not present in data-stage, locate at https://github.com/pkulchenko/serpent
local gaia = data.raw.planet.gaia
if gaia and gaia.map_gen_settings then
  log(serpent.block(gaia.map_gen_settings, {sortkeys=true, numformat="%0.8f"}))
end
]]
data:extend{
  {
    type = "space-connection",
    name = "nauvis-gaia",
    subgroup = "planet-connections",
    from = "nauvis",
    to = "gaia",
    order = "0",
    length = 100000,
    asteroid_spawn_definitions = {},
    icon = ei_graphics_2_path.."graphics/icons/gaia.png",
  },
  {
    type = "ambient-sound",
    name = "paradise-found",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia001_synthwave_4k.ogg"
  },
  {
    type = "ambient-sound",
    name = "paradise-found2",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia002_synthwave_4k.ogg"
  },
  {
    type = "ambient-sound",
    name = "paradise-found3",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia003_synthwave_4k.ogg"
  },
  {
    type = "ambient-sound",
    name = "choir",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiachoir.ogg"
  },
  {
    type = "ambient-sound",
    name = "ambient1",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiaambient1.ogg"
  },
  {
    type = "ambient-sound",
    name = "arrow",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiaarrow.ogg"
  },
  {
    type = "ambient-sound",
    name = "omni-domina",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiaomnidomina.ogg"
  },
  {
    type = "ambient-sound",
    name = "soliloquy",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiasoliloquy.ogg"
  },
  {
    type = "ambient-sound",
    name = "anti-entity",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia_anti_entity.ogg"
  },
  {
    type = "ambient-sound",
    name = "cathedral",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiacathedral.ogg"
  },
  {
    type = "ambient-sound",
    name = "last-angel",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia_fato_shadow_-_last_angel.ogg"
  },
  {
    type = "ambient-sound",
    name = "desert-of-dreams",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia_caryil_the_desert_of_dreams_chill_jungle_ambient_mix.ogg"
  },
  {
    type = "ambient-sound",
    name = "space",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia_space.ogg"
  },
  {
    type = "ambient-sound",
    name = "underwater-theme",
    track_type = "main-track",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia_underwater_theme_ii.ogg"
  },
  {
    type = "ambient-sound",
    name = "a-bad-feeling",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia1_menu_master.ogg"
  },
  {
    type = "ambient-sound",
    name = "the-swamp",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia2_quiet_1_master.ogg"
  },
  {
    type = "ambient-sound",
    name = "the-tower",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia3_quiet_2_master.ogg"
  },
  {
    type = "ambient-sound",
    name = "dark-room",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia4_tension_1_master.ogg"
  },
  {
    type = "ambient-sound",
    name = "awakening-of-the-monster",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaia5_threat_1_master.ogg"
  },
  {
    type = "ambient-sound",
    name = "eternal-terror",
    track_type = "interlude",
    planet = "gaia",
    sound = ei_soundtrack_path_2.."gaiadova_eternal_terror_master.ogg"
  },
  {
    name = "ei-gaia",
    type = "technology",

    icons = {
      {
        icon = ei_graphics_tech_path.."gaia.png",
        icon_size = 256
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-planet.png",
        icon_size = 128,
        scale = 0.5,
        shift = {
          50,
          50
        }
      }
    },

    essential = true,
    icon_size = 256,
    prerequisites = {"rocket-silo"},
    effects = {
      {
        space_location = "gaia",
        type = "unlock-space-location",
        use_icon_overlay_constant = true
      }
    },
    unit = {
        count = 100,
        ingredients = ei_data.science["computer-age-space"],
        time = 20
    },
    age = "advanced-computer-age"
},
--dummy prototype to account for 1.5.7 prototype name change "gaia" -> "Gaia" and subsequent 1.5.8 reversion
  {
    type = "planet",
    name = "Gaia",
    order = "z-[legacy-gaia]",
    localised_name = {"planet-name.gaia-dummy"},
    distance = 10,
    orientation = 0.75,
    icon = ei_graphics_2_path.."graphics/icons/gaia.png",
    icon_size = 64,
    starmap_icon = ei_graphics_2_path.."graphics/icons/starmap-planet-gaia.png",
    starmap_icon_size = 2048,
    lightning_properties = nil,
    hidden = true
  }
}