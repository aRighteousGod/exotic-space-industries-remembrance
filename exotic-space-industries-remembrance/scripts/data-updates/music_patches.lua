-- =======================================================================================
-- Override nauvis tracks
data.raw["ambient-sound"]["after-the-crash"].sound = ei_soundtrack_path_1.."dear_diary.ogg"
data.raw["ambient-sound"]["automation"].sound = ei_soundtrack_path_1.."beyond_the_stars_ambient.ogg"
data.raw["ambient-sound"]["resource-deficiency"].sound = ei_soundtrack_path_1.."drifting_beyond_the_stars.ogg"
data.raw["ambient-sound"]["are-we-alone"].sound = ei_soundtrack_path_1.."futuristic_ambient_1.ogg"
data.raw["ambient-sound"]["beyond-factory-outskirts"].sound = ei_soundtrack_path_1.."futuristic_ambient_2.ogg"
data.raw["ambient-sound"]["censeqs-discrepancy"].sound = ei_soundtrack_path_1.."futuristic_ambient_3.ogg"
data.raw["ambient-sound"]["efficiency-program"].sound = ei_soundtrack_path_1.."futuristic_ambient_4.ogg"
data.raw["ambient-sound"]["expansion"].sound = ei_soundtrack_path_1.."path_to_lake_land.ogg"
data.raw["ambient-sound"]["the-search-for-iron"].sound = ei_soundtrack_path_1.."cyberpunk_moonlight_sonata_v2.ogg"
data.raw["ambient-sound"]["gathering-horizon"].sound = ei_soundtrack_path_1.."hitctrl_searching_within_ambient.ogg"
data.raw["ambient-sound"]["research-and-minerals"].sound = ei_soundtrack_path_1.."dust.ogg"
data.raw["ambient-sound"]["solar-intervention"].sound = ei_soundtrack_path_1.."the_eternal_sandsmix.ogg"
data.raw["ambient-sound"]["the-oil-industry"].sound = ei_soundtrack_path_1.."alexander_ehlers_waking_the_devil.ogg"
data.raw["ambient-sound"]["the-right-tools"].sound = ei_soundtrack_path_1.."thefallofarcana.ogg"
data.raw["ambient-sound"]["pollution"].sound = ei_soundtrack_path_1.."arclight.ogg"
data.raw["ambient-sound"]["turbine-dynamics"].sound = ei_soundtrack_path_1.."tropicstrike_youweremybrother.ogg"
data.raw["ambient-sound"]["sentient"].sound = ei_soundtrack_path_1.."welcome_to_com_mecha.ogg"


-- =======================================================================================
-- Override nauvis interludes
data.raw["ambient-sound"]["anomaly"].sound = ei_soundtrack_path_1.."main_menu.ogg"
data.raw["ambient-sound"]["first-light"].sound = ei_soundtrack_path_1.."scary_ambient_wind.ogg"
data.raw["ambient-sound"]["transmit"].sound = ei_soundtrack_path_1.."space_graveyard.ogg"
data.raw["ambient-sound"]["swell-pad"].sound = ei_soundtrack_path_1.."cave_themeb4.ogg"
data.raw["ambient-sound"]["world-ambience-3"].sound = ei_soundtrack_path_1.."dark_amb.ogg"
data.raw["ambient-sound"]["world-ambience-4"].sound = ei_soundtrack_path_1.."forest.ogg"
data.raw["ambient-sound"]["world-ambience-5"].sound = ei_soundtrack_path_1.."giii_8inst_1.ogg"
data.raw["ambient-sound"]["world-ambience-6"].sound = ei_soundtrack_path_1.."ambient_menu.ogg"
if data.raw["ambient-sound"]["main-menu"] and not mods["krastorio2-spaced-out"] or not settings.startup["kr-main-menu-song"].value then
  data.raw["ambient-sound"]["main-menu"].sound = ei_soundtrack_path_1.."main_menu.ogg"
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