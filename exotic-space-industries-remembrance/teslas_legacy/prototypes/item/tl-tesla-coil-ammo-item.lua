require("teslas_legacy.config.settings")

local settings = get_settings()

local function make_crit_damage_effect( critical, amount )
  if not critical.probability then
    return nil
  end
  
  -- note.: since a beam attacks every tick, a critical hit will happen more ofthen
  --        so to banace it out somewhat, the probability is decreased
  
  return
  {
    type = "nested-result",
    probability = critical.probability,
    action =
    {
      type = "direct",
      action_delivery = 
      {
        type = "instant",
        target_effects =
        {
          {
            type = "script",
            effect_id = "tl-critical-hit-effect-id"
          },
          {
            type = "damage",
            damage = { 
              amount = amount * critical.multiplier,
              type = "electric"
            } 
          },
          {
            type = "create-fire",
            entity_name = "fire-flame",
            initial_ground_flame_count = 10
          },
        }
      }
    }
  }
end


local function make_damage_effect( amount )
  return
  {
    type = "damage",
    damage = { 
      amount = settings.vehicle.tank.damage, 
      type = "electric"
    }
  }
end

data:extend({
  {
    type = "ammo",
    name = "tl-tesla-coil-ammo",
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/icons/Teslacharge.png",
    icon_size = 64,
    icon_mipmaps = 1,
    ammo_category = "tl-tesla-coil-ammo-category",
    ammo_type =
    {
      action =
      {
        type = "line",
        range = settings.vehicle.tank.range,
        width = 4,
        range_effects = 
        {
          {
            type = "create-explosion",
            entity_name = "tl-tesla-coil-explosion"
          }
        },
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            make_damage_effect( settings.vehicle.tank.damage ),
			make_crit_damage_effect( settings.critical, settings.vehicle.tank.damage ),
          }
        }
      }
    },
    magazine_size = 1,
    subgroup = "ammo",
    order = "q[laser-cannon]-g[laser]",
    stack_size = 200
  }
})


