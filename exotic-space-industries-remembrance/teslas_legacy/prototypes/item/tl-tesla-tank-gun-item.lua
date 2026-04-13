require("teslas_legacy.config.settings")

local settings = get_settings()

data:extend(
{
  {
    type = "gun",
    name = "tl-tesla-tank-gun-item",
    icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/tank/icons/Teslatankcannon.png",
    icon_size = 64, icon_mipmaps = 4,
    hidden = true,
    hidden_in_factoriopedia = true,
    subgroup = "gun",
    order = "z[tank]-a[cannon]",
    attack_parameters =
    {
      type = "projectile",
      ammo_category = "tl-tesla-coil-ammo-category",
      cooldown = 60 / settings.vehicle.tank.fire_rate,
      movement_slow_down_factor = 0,
      projectile_creation_distance = 1,
      projectile_center = {0, 0},
      range = settings.vehicle.tank.range,
      --sound =
	  --{
      --  {
      --    filename = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/sound/earcing.ogg",
      --    volume = 0.5
      --  }
      --}
    },
    stack_size = 1
  }
})


