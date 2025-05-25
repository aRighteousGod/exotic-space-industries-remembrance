
data:extend({
  {
    type = "sound",
    name = "kr-intergalactic-transceiver-discharging-warning",
    category = "alert",
    filename = ei_graphics_3_path.."K2_ASSETS/sounds/others/alert-discharging.ogg",
    volume = 1.0,
    audible_distance_modifier = 1000,
    aggregation = {
      max_count = 1,
      remove = false,
      count_already_playing = true,
    },
  },

  {
    type = "sound",
    name = "kr-planetary-teleporter-effect-sound",
    category = "alert",
    filename = ei_graphics_3_path.."K2_ASSETS/sounds/others/planetary-teleporter-effect-sound.ogg",
    volume = 2.0,
    audible_distance_modifier = 2.0,
    aggregation = {
      max_count = 2,
      remove = true,
      count_already_playing = true,
    },
  },

})
