data:extend({  
  {
    type = "explosion",
    name = "tl-tesla-coil-turret-explosion",
    flags = {"not-on-map"},      
    hidden = true,
    hidden_in_factoriopedia = true,
    animation_speed = 0.1,
    rotate = true,	
    -- The advanced coil and its single-zap helpers create this beam-shaped explosion on the
    -- struck target rather than firing a normal beam entity across the whole path. In modern
    -- Factorio builds, leaving `correct_rotation` disabled here can let that target-side beam
    -- body render in an obviously wrong direction, which looks like an off-screen lance
    -- arriving from nowhere. Keep the target explosion, but force the beam body to align to
    -- the actual shot vector.
    correct_rotation = true,
    fade_out_duration = 200,
    beam = true,
    animations =
    {
      layers = 
	  {
        {
          filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/hr-beam-body.png",
          priority = "extra-high", 
          blend_mode = "additive-soft",
          width = 100,
          height = 240,
          line_length = 2,
          frame_count = 16,
          scale = 1,
        },
        {
          filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/beam/hr-beam-body-light-2.png",
          priority = "extra-high",
          flags = { "light" },          
          draw_as_light = true,
          blend_mode = "additive-soft",
          width = 100,
          height = 240,
          line_length = 1,
          frame_count = 1,
          repeat_count = 16,
          scale = 1,
          tint = { r=26, g=93, b=100, a=0 },
        }
      }
    },
    light = {
      intensity = 1, 
      size = 60,
      color = { r=26, g=93, b=100, a=0 },
    },
    smoke = "smoke-fast",
    smoke_count = 10,
    smoke_slow_down_factor = 1,
  }
})

