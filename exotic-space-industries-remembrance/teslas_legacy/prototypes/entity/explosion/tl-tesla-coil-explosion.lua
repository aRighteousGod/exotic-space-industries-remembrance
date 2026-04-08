

function get_animation_A_layers()
  local sequence = { 1, 1, 1, 1, 2, 2, 2,3, 3, 3,4, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 13 }
  return
  {
    {     
      animation_speed = 1,
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-a.png",
      priority = "extra-high",
      width = 200,
      height = 1280,
      line_length = 13,
      frame_count = 13,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop"},
      draw_as_glow = true,
      frame_sequence = sequence,
    },
    {
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-a.png",
      priority = "extra-high",
      width = 200,
      height = 1280,
      line_length = 13,
      frame_count = 13,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop", "light"},
      draw_as_light = true,
      frame_sequence = sequence,
    },
  }
end


function get_animation_B_layers()
  return
  {
    {     
      animation_speed = 0.5,
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-b.png",
      priority = "extra-high",
      width = 300,
      height = 720,
      line_length = 13,
      frame_count = 13,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop"},
      draw_as_glow = true,
    },
    {
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-b.png",
      priority = "extra-high",
      width = 300,
      height = 720,
      line_length = 13,
      frame_count = 13,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop", "light"},
      draw_as_light = true,
    },
    { -- TODO the pop-in is a bit annoying
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/light.png",
      priority = "extra-high",
      width = 300,
      height = 720,
      line_length = 1,
      frame_count = 1,
      repeat_count = 13,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop", "light"}, 
      draw_as_light = true,
      blend_mode = "additive-soft",
      tint = { r=26, g=93, b=100, a=255 },
    },
  }
end


function get_animation_C_layers()
  return
  {
    {     
      animation_speed = 0.75,
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-c.png",
      priority = "extra-high",
      width = 350,
      height = 565,
      line_length = 9,
      frame_count = 18,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop"},
	  shift = { 0, 1 },
    },
    {     
      animation_speed = 0.5,
      filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/sheet-c-light.png",
      priority = "extra-high",
      width = 350,
      height = 565,
      line_length = 9,
      frame_count = 18,
      max_advance = 1,
      scale = 1,
      flags = {"no-crop", "light"},
	  shift = { 0, 1 },
      blend_mode = "additive-soft",
      draw_as_light = true,
    },
  }
end

data:extend({  
  {
    type = "explosion",
    name = "tl-tesla-coil-explosion",
    flags = {"not-on-map"},
    hidden = true,
    hidden_in_factoriopedia = true,
    rotate = true,
    beam = true,
    correct_rotation = true,
    animations =
    {
      layers = get_animation_C_layers(),
    },
	
    light = {
	  intensity = 1, 
	  size = 75
	},
	
    sound = 
    {
	  {
        filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/tl-tesla-tank-zap-1.wav",
        volume = 6,
        speed = 1,
	  },
	  {
        filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/tl-tesla-tank-zap-2.wav",
        volume = 6,
        speed = 1,
	  },
	  {
        filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/tl-tesla-tank-zap-3.wav",
        volume = 4,
        speed = 1,
	  },
	  {
        filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/tl-tesla-tank-zap-4.wav",
        volume = 4,
        speed = 1,
	  },
    }
  }
})

