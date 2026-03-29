local planet_map_gen = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/map-gen")
local ei_lib = require("lib/lib")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")
local gaia_procession_catalogue = require("__exotic-space-industries-remembrance__/prototypes/planet-gaia/procession-catalogue")

local function gaia_world_ambient_sound(filename_stem, variation_count, volume, tuning, advanced_volume_control)
  return
  {
    sound =
    {
      variations = sound_variations(filename_stem, variation_count, volume),
      advanced_volume_control = advanced_volume_control or default_tile_sounds_advanced_volume_control(),
    },
    radius = tuning.radius,
    min_entity_count = tuning.min_entity_count,
    max_entity_count = tuning.max_entity_count,
    entity_to_sound_ratio = tuning.entity_to_sound_ratio,
    average_pause_seconds = tuning.average_pause_seconds,
  }
end

local gaia_asteroid_ratio = {2, 6, 1, 0}
local gaia_asteroid_chunks = 0.001
local gaia_asteroid_medium = 0.0015
local gaia_platform_procession_set = {
  arrival = {"planet-to-platform-b"},
  departure = {"platform-to-planet-a"},
}
local gaia_planet_procession_set = {
  arrival = {"platform-to-planet-b"},
  departure = {"planet-to-platform-a"},
}
local gaia_vanilla_asteroid_route = {
  probability_on_range_chunk = {
    {position = 0.1, probability = asteroid_util.nauvis_chunks, angle_when_stopped = asteroid_util.chunk_angle},
    {position = 0.3, probability = asteroid_util.weighted_average(asteroid_util.nauvis_chunks, gaia_asteroid_chunks, 0.7) * 2, angle_when_stopped = asteroid_util.chunk_angle},
    {position = 0.6, probability = gaia_asteroid_chunks, angle_when_stopped = asteroid_util.chunk_angle},
    {position = 0.9, probability = gaia_asteroid_chunks, angle_when_stopped = asteroid_util.chunk_angle},
  },
  probability_on_range_medium = {
    {position = 0.1, probability = asteroid_util.nauvis_chunks * 0.5, angle_when_stopped = asteroid_util.medium_angle},
    {position = 0.3, probability = asteroid_util.nauvis_chunks, angle_when_stopped = asteroid_util.medium_angle},
    {position = 0.6, probability = gaia_asteroid_medium, angle_when_stopped = asteroid_util.medium_angle},
    {position = 0.9, probability = gaia_asteroid_medium, angle_when_stopped = asteroid_util.medium_angle},
  },
  type_ratios = {
    {position = 0.1, ratios = asteroid_util.nauvis_ratio},
    {position = 0.3, ratios = asteroid_util.nauvis_ratio},
    -- Gaia's vanilla layer leans carbonic-heavy to read as a greener, wetter route
    -- without duplicating the later EI-specific asteroid additions.
    {position = 0.6, ratios = gaia_asteroid_ratio},
    {position = 0.9, ratios = gaia_asteroid_ratio},
  }
}

local gaia_cliff = table.deepcopy(data.raw.cliff["cliff-gleba"])
gaia_cliff.name = "cliff-gaia"
gaia_cliff.localised_name = {"entity-name.cliff-gaia"}
gaia_cliff.map_color = {132, 118, 97}

local gaia_water_control = "slider_rescale(control:gaia_water:size, 2) * slider_rescale(control:gaia_water:frequency, 2)"
local gaia_water = table.deepcopy(data.raw.tile["water"]);
gaia_water.name = "ei-gaia-water"
gaia_water.fluid = "ei-diluted-morphium";
gaia_water.autoplace = {
  control = "gaia_water",
  probability_expression = "clamp(1.1 * gaia_water_mask * (" .. gaia_water_control .. "), 0, 1)",
}
gaia_water.ambient_sounds = {
  gaia_world_ambient_sound(
    "__base__/sound/world/water/waterlap",
    10,
    0.18,
    {
      radius = 7.5,
      min_entity_count = 4,
      max_entity_count = 12,
      entity_to_sound_ratio = 0.10,
      average_pause_seconds = 0,
    }
  ),
  gaia_world_ambient_sound(
    "__space-age__/sound/world/tiles/oil-gloop",
    10,
    0.05,
    {
      radius = 7.5,
      min_entity_count = 4,
      max_entity_count = 12,
      entity_to_sound_ratio = 0.10,
      average_pause_seconds = 0,
    }
  ),
}
data:extend({gaia_cliff, gaia_water})
local landfill = ei_lib.raw.item.landfill

if landfill then
  table.insert(landfill.place_as_tile.tile_condition, "ei-gaia-water")
end

data:extend({
  {
    type = "planet",
    name = "gaia",
    icon = ei_graphics_2_path .. "graphics/icons/gaia.png",
    icon_size = 64,
    starmap_icon = ei_graphics_2_path .. "graphics/icons/starmap-planet-gaia.png",
    starmap_icon_size = 2048,
    gravity_pull = 10,
    distance = 23,
    orientation = 0.75,
    magnitude = 0.9,
    label_orientation = 0.35,
    order = "g[gaia]",
    subgroup = "planets",
    map_gen_settings = planet_map_gen.gaia(),
    solar_power_in_space = 160,
    platform_procession_set = gaia_platform_procession_set,
    planet_procession_set = gaia_planet_procession_set,
    procession_graphic_catalogue = gaia_procession_catalogue,
    surface_properties = {
      ["day-night-cycle"] = 8 * minute,
      ["magnetic-field"] = 45,
      ["solar-power"] = 45,
      pressure = 1600,
      gravity = 15.5,
    },
    asteroid_spawn_influence = 1,
    -- Gaia owns its vanilla metallic-carbonic-oxide route.
    -- The later more_asteroids data-update appends the EI-specific Gaia asteroid layer.
    asteroid_spawn_definitions = asteroid_util.spawn_definitions(gaia_vanilla_asteroid_route, 0.9),
    surface_render_parameters = {
        fog = {
            color1 = {
                0.18, -- dark emerald base
                0.65, -- vivid mid-green
                0.45, -- aqua undertone
                1
            },
            color2 = {
                0.42, -- brighter jade
                0.95, -- glowing neon green
                0.72, -- ethereal highlight
                1
            },
            detail_noise_texture = {
                filename = "__core__/graphics/clouds-detail-noise.png",
                size = 2048
            },
            shape_noise_texture = {
                filename = "__core__/graphics/clouds-noise.png",
                size = 2048
            }
        }
    },
    persistent_ambient_sounds = {
      base_ambience = {
        {sound = {filename = "__base__/sound/world/world_base_wind.ogg", volume = 0.12}},
      },
      wind = {
        {filename = "__base__/sound/wind/wind.ogg", volume = 0.22},
        {
          sound = {
            filename = "__space-age__/sound/wind/base-wind-gleba-day.ogg",
            volume = 0.10,
            advanced_volume_control = {darkness_threshold = -0.7},
          }
        },
        {
          sound = {
            filename = "__space-age__/sound/wind/base-wind-gleba-night.ogg",
            volume = 0.08,
            advanced_volume_control = {darkness_threshold = 0.85},
          }
        },
      },
      semi_persistent = {
        {
          sound = {variations = sound_variations("__space-age__/sound/world/semi-persistent/distant-rumble", 3, 0.05)},
          delay_mean_seconds = 28,
          delay_variance_seconds = 10,
        }
      },
    },
    water = "ei-gaia-water",
},
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
    prerequisites = {"ei-high-energy-crystal","ei-deep-pumpjack","rocket-silo"},
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
    age = "computer-age"
  },
  -- Dummy prototype kept for 1.5.7 save compatibility after the internal-name reversion.
  {
    type = "planet",
    name = "Gaia",
    order = "z-[legacy-gaia]",
    localised_name = {"planet-name.gaia-dummy"},
    distance = 23,
    orientation = 0.75,
    icon = ei_graphics_2_path.."graphics/icons/gaia.png",
    icon_size = 64,
    starmap_icon = ei_graphics_2_path.."graphics/icons/starmap-planet-gaia.png",
    starmap_icon_size = 2048,
    hidden = true
  }
})

local pdgaia = ei_lib.raw.technology["ei-gaia"]
if pdgaia and pdgaia.effects then
    table.insert(pdgaia.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-gaia"
    })
    table.insert(pdgaia.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-surface-harvester-running-gaia"
    })
end

-- error(serpent.block(data.raw.planet.gaia.map_gen_settings))
