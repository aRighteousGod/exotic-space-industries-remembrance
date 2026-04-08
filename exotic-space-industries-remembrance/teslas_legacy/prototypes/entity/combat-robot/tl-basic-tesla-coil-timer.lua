require("teslas_legacy.prototypes.animation.empty")

function get_basic_beam_timer_entity(timeout)
  return
  {
    type = "combat-robot",
    name = "tl-basic-tesla-coil-timer",

    -- important bits
	
    time_to_live = timeout,
    speed = 0,
    is_military_target = false,
    alert_when_damaged = false,
    idle = get_empty_animation(),
    in_motion = get_empty_animation(),
    shadow_idle = get_empty_animation(),
    shadow_in_motion = get_empty_animation(),
    destroy_action = 
    {
      type = "direct",
      action_delivery = 
      {
        type = 'instant',
        source_effects = 
        {
          type = "script",
          effect_id = "tl-basic-tesla-coil-timer-effect-id"
        }
      }
    },
	
	-- irrelevant part
	
    icon = "__base__/graphics/icons/distractor.png",
    icon_size = 64, 
    icon_mipmaps = 4,
    flags = {
      "placeable-player", 
      "player-creation", 
      "placeable-off-grid", 
      "not-on-map", 
      "not-repairable"
    },
    
    hidden = true,
    hidden_in_factoriopedia = true,
    
    subgroup="capsule",
    order="e-a-b",
    max_health = 10000,
    collision_box = {{0, 0}, {0, 0}},
    selection_box = {{-0.5, -1.5}, {0.5, -0.5}},
    hit_visualization_box = {{-0.1, -1.1}, {0.1, -1.0}},
	
    -- note.: we dont really want to shoot, since this entity is a simple timer
    attack_parameters =
    {
      type = "beam",
      cooldown = 999 * timeout, -- cooldown should not expire before the robot itself expires
      range = 0,
      ammo_category = "tl-tesla-coil-ammo-category",
      ammo_type =
      {
        action =
        {
          type = "direct",
          action_delivery =
          {
            type = "beam",
            beam = get_beam_name_turret()
          }
        }
      }
    },
  }
end

data:extend({
  get_basic_beam_timer_entity(10),
})


