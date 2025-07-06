ei_lib = require ("lib/lib")

--type string, track table, planet string
local function track_override(track_type, track_table, targetplanet)
  for track,_ in pairs(track_table) do
    modified = ei_lib.raw["ambient-sound"][track]
    if modified then
      log("ei track_override: "..track.." successfully overwritten by "..track_table[track])
      modified.sound = ei_soundtrack_path_1..track_table[track]..".ogg"
    else
      log("ei track_override: "..track.." missing from data.raw, creating new entry for "..track_table[track])
      data:extend{
        {
          type = "ambient-sound",
          name = track_table[track],
          track_type = track_type,
          sound = ei_soundtrack_path_1..track_table[track]..".ogg",
          planet = targetplanet
        }
      }
    end
  end
end
-- =======================================================================================
-- Override nauvis tracks
local ei_nauvis_track_override = {
  ["after-the-crash"] = "dear_diary",
  ["automation"] = "beyond_the_stars_ambient",
  ["resource-deficiency"] = "drifting_beyond_the_stars",
  ["are-we-alone"] = "futuristic_ambient_1",
  ["beyond-factory-outskirts"] = "futuristic_ambient_2",
  ["censeqs-discrepancy"] = "futuristic_ambient_3",
  ["efficiency-program"] = "futuristic_ambient_4",
  ["expansion"] = "path_to_lake_land",
  ["the-search-for-iron"] = "cyberpunk_moonlight_sonata_v2",
  ["gathering-horizon"] = "hitctrl_searching_within_ambient",
  ["research-and-minerals"] = "dust",
  ["solar-intervention"] = "the_eternal_sandsmix",
  ["the-oil-industry"] = "alexander_ehlers_waking_the_devil",
  ["the-right-tools"] = "thefallofarcana",
  ["pollution"] = "arclight",
  ["turbine-dynamics"] = "tropicstrike_youweremybrother",
  ["sentient"] = "welcome_to_com_mecha"
}
track_override("main-track",ei_nauvis_track_override, "nauvis")
-- =======================================================================================
-- Override nauvis interludes
local ei_nauvis_interlude_override = {
  ["anomaly"] = "main_menu",
  ["first-light"] = "scary_ambient_wind",
  ["transmit"] = "space_graveyard",
  ["swell-pad"] = "cave_themeb4",
  ["world-ambience-3"] = "dark_amb",
  ["world-ambience-4"] = "forest",
  ["world-ambience-5"] = "giii_8inst_1",
  ["world-ambience-6"] = "ambient_menu"
}
track_override("interlude",ei_nauvis_interlude_override, "nauvis")


if ei_lib.raw["ambient-sound"]["main-menu"] and not mods["krastorio2-spaced-out"] or not settings.startup["kr-main-menu-song"].value then
  ei_lib.raw["ambient-sound"]["main-menu"].sound = ei_soundtrack_path_1.."main_menu.ogg"
elseif mods["krastorio2-spaced-out"] and settings.startup["kr-main-menu-song"].value then --meow -.-
    data:extend{
      {
        type = "ambient-sound",
        name = "ei-main-menu-1",
        track_type = "menu-track",
        sound = ei_soundtrack_path_1.."main_menu.ogg"
      },
      {
        type = "ambient-sound",
        name = "ei-main-menu-2", --two because kr2 adds 2, 50:50 play ratio
        track_type = "menu-track",
        sound = ei_soundtrack_path_1.."main_menu.ogg"
      },
    }
end
data:extend{
  {
    type = "ambient-sound",
    name = "my-very-own-dead-ship",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."blackmoor_ninjas.ogg"
  },
  {
    type = "ambient-sound",
    name = "leave-the-world-behind",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."kimlightyear_leave_the_world_tonight.ogg"
  },
  {
    type = "ambient-sound",
    name = "inevitability",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."inevitability.ogg"
  },
  {
    type = "ambient-sound",
    name = "villified",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."villified.ogg"
  },
  {
    type = "ambient-sound",
    name = "a-new-page",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."a_new_page.ogg"
  },
  {
    type = "ambient-sound",
    name = "death-is-just-another-path",
    track_type = "main-track",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."death_is_just_another_path.ogg"
  },
  {
    type = "ambient-sound",
    name = "my-very-own-dead-ship",
    track_type = "interlude",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."myveryowndeadship.ogg"
  },
  {
    type = "ambient-sound",
    name = "catacomb",
    track_type = "interlude",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."catacomb.ogg"
  },
  {
    type = "ambient-sound",
    name = "brightwood",
    track_type = "interlude",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."brightwood.ogg"
  },
  {
    type = "ambient-sound",
    name = "bleakwood",
    track_type = "interlude",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."bleakwood.ogg"
  },
  {
    type = "ambient-sound",
    name = "underground",
    track_type = "interlude",
    planet = "nauvis",
    sound = ei_soundtrack_path_1.."underground.ogg"
  },
}