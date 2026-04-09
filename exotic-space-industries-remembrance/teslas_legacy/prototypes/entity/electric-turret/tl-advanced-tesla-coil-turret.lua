local sounds = require("__base__/prototypes/entity/sounds.lua")
require("teslas_legacy.config.settings")
local settings = get_settings()

local anim_spd = 0.5
local anim_offset = {x=0,y=-1}

function pillar_animation_core(args)
  return
  {
    priority = "high",
    flags = args.flags or nil,
    frame_count = 1,
    line_length = 1,
    animation_speed = anim_spd, 
    repeat_count = args.repeat_count or 22,
    run_mode = args.run_mode or "forward",
    axially_symmetrical = false,
    apply_runtime_tint = args.apply_runtime_tint or false,
    direction_count = 1,
    shift = anim_offset,
  }
end

function pillar_animation(args)

  local high_res_anim = pillar_animation_core(args)
  high_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-soviet-tesla-mask-1x1.png"
  high_res_anim.width = 222
  high_res_anim.height = 362
  high_res_anim.scale = 0.5
  
  local low_res_anim = pillar_animation_core(args)
  low_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-soviet-tesla-mask-1x1.png"
  low_res_anim.width = 111
  low_res_anim.height = 181
  low_res_anim.hr_version = high_res_anim
  
  return low_res_anim
end

function get_color_mask_animation(args)
    local adjusted_args = args
    adjusted_args.flags = {"mask"}
    adjusted_args.apply_runtime_tint = true
    return pillar_animation(adjusted_args)
end

function get_shadow_animation_core(args)
  local shadow_offset = util.by_pixel(78, 40) -- Note.: shadow looks good with these numbers 
  return 
  {
    frame_count = 1,
    line_length = 1,
    repeat_count = args.repeat_count,       
    axially_symmetrical = false,
    direction_count = 1,
    draw_as_shadow = true,
    shift = { x=shadow_offset[1] + anim_offset.x, y=shadow_offset[2] + anim_offset.y }
  }
end

function get_shadow_animation(args)
  local high_res_anim = get_shadow_animation_core(args)
  high_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-tesla-shadow-1x1.png"
  high_res_anim.width = 444
  high_res_anim.height = 300
  high_res_anim.scale = 0.5
  
  local low_res_anim = get_shadow_animation_core(args)
  low_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-tesla-shadow-1x1.png"
  low_res_anim.width = 222
  low_res_anim.height= 150
  low_res_anim.hr_version = high_res_anim
  
  return low_res_anim
end

function get_idle_animation_core(args)
  return
  {
    priority = "high",
    axially_symmetrical = false,
    direction_count = 1,
    frame_count = 1,
    line_length = 1,
    repeat_count = args.repeat_count or 32,
    continuous_animation = true,            
    shift = anim_offset,
  }
end

function get_idle_animation(args)
  local high_res_anim = get_idle_animation_core(args)
  high_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-soviet-tesla-with-dirt-1x1.png"
  high_res_anim.width = 222
  high_res_anim.height= 362
  high_res_anim.scale = 0.5
    
  local low_res_anim = get_idle_animation_core(args)
  low_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-soviet-tesla-with-dirt-1x1.png"
  low_res_anim.width = 111
  low_res_anim.height= 181
  low_res_anim.hr_version = high_res_anim
    
  return low_res_anim
end

function get_charging_animation_core(args)
  return
  {    
      priority = "high",
      frame_count = args.frame_count or 22,
      line_length = args.line_length or 11,
      direction_count = 1,
      shift = anim_offset,
  }
end

function get_charging_animation(args)
  local high_res_anim = get_charging_animation_core(args)
  high_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-tesla-charge-with-dirt-11x2.png"
  high_res_anim.width = 222
  high_res_anim.height= 362
  high_res_anim.scale = 0.5
  
  local low_res_anim = get_charging_animation_core(args)
  low_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-tesla-charge-with-dirt-11x2.png"
  low_res_anim.width = 111
  low_res_anim.height= 181
  low_res_anim.hr_version = high_res_anim
    
  return low_res_anim
end

function get_charging_glow_animation(args)
  local anim = get_charging_animation(args)
  anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-tesla-charge-glow2-11x2.png"
  anim.draw_as_glow = true    
  anim.hr_version.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-tesla-charge-glow2-11x2.png"
  anim.hr_version.draw_as_glow = true    
  return anim
end

function get_charging_light_animation(args)
  local anim = get_charging_animation(args)
  anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-tesla-charge-light-11x2.png"
  anim.draw_as_light = true    
  anim.hr_version.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-tesla-charge-light-11x2.png"
  anim.hr_version.draw_as_light = true
  return anim
end

function get_sparking_animation_core(args)
  return
  {
    priority = "high",
    frame_count = args.frame_count or 32,
    line_length = args.line_length or 8,
    repeat_count = args.repeat_count or 1,
    direction_count = 1,
    shift = anim_offset, 
  }
end

function get_sparking_animation(args)
  local high_res_anim = get_sparking_animation_core(args)
  high_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-soviet-teslabase-8x4.png"
  high_res_anim.width = 222
  high_res_anim.height= 362          
  high_res_anim.scale = 0.5
      
  local low_res_anim = get_sparking_animation_core(args) 
  low_res_anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-soviet-teslabase-8x4.png"
  low_res_anim.width = 111
  low_res_anim.height= 181
  low_res_anim.hr_version = high_res_anim
  
  return low_res_anim
end

function get_sparking_glow_animation(args)
  local anim = get_sparking_animation(args)
  anim.hr_version.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-soviet-spark-only-8x4.png"
  anim.hr_version.draw_as_glow = true
  anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-soviet-spark-only-8x4.png" 
  anim.draw_as_glow = true
  return anim
end

function get_sparking_light_animation(args)
  local anim = get_sparking_animation(args)
  anim.hr_version.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/hr-soviet-spark-only-light-8x4.png" -- TODO MISSING
  anim.hr_version.draw_as_light = true
  anim.filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/entity/soviet-tesla/lr-soviet-spark-only-light-8x4.png" 
  anim.draw_as_light = true
  return anim
end
 
 
function init_animations(electric_turret_object)
  local anim_setting = settings.turret.advanced.anim
  if anim_setting == "charge-up" then
    return init_glowing_animations(electric_turret_object)
  elseif anim_setting == "simple" then
    return init_subtle_animations(electric_turret_object)
  end
end

function init_subtle_animations(electric_turret_object)
  
  electric_turret_object.folded_animation =
  {
    layers =
    {
      get_idle_animation({repeat_count = 32}),
      get_shadow_animation({repeat_count = 32}),
      get_color_mask_animation({repeat_count = 32}), 
    }      
  }
  
  local sparking_anim = get_sparking_animation({repeat_count = 5})
  local frame_count = sparking_anim.frame_count * sparking_anim.repeat_count
  local slowdown_factor = 4;
  
  electric_turret_object.prepared_speed = 1 / (frame_count * slowdown_factor)
  electric_turret_object.prepared_speed_secondary = electric_turret_object.prepared_speed
  electric_turret_object.prepared_animation =
  {
    layers =
    {
      sparking_anim,
      get_sparking_glow_animation({repeat_count = 5}),
      get_sparking_light_animation({repeat_count = 5}),
      get_shadow_animation({repeat_count = frame_count}),
      get_color_mask_animation({repeat_count = frame_count}),        
    }
  }
  
  electric_turret_object.starting_attack_sound = 
  {
    filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/tl-advanced-tesla-coil-zap-subtle.wav",
    volume = 0.7,
    speed = 1,
  }
  
  return electric_turret_object
end

function init_glowing_animations(electric_turret_object)
  -- animation when idle: no sparks or creeping energy
  electric_turret_object.folded_speed = 1 / 60 
  electric_turret_object.folded_speed_secondary = 1 / 60 
  electric_turret_object.folded_animation =
  {
    layers =
    {
      get_idle_animation({repeat_count = 1}),
      get_shadow_animation({repeat_count = 1}),
      get_color_mask_animation({repeat_count = 1}), 
    }      
  }
  
  ---- animation done when target is first noticed: sparking for a quick bit
  --local short_sparking_anim = get_sparking_animation({frame_count = 16})
  --local short_sparking_slowdown_factor = 2
  --electric_turret_object.preparing_speed = 1 / (short_sparking_anim.frame_count * short_sparking_slowdown_factor)
  --electric_turret_object.preparing_animation =
  --{
  --  layers =
  --  {
  --    short_sparking_anim,
  --    get_sparking_glow_animation({frame_count = 16}),
  --    get_sparking_light_animation({frame_count = 16}),
  --    get_shadow_animation({repeat_count = short_sparking_anim.frame_count}),
  --    get_color_mask_animation({repeat_count = short_sparking_anim.frame_count}),        
  --  }
  --}
  --
  -- animation when the coil is ready to shoot: continuous sparking
  --local sparking_anim = get_sparking_animation({repreat_count = 7})
  --local sparking_frame_count = sparking_anim.frame_count * sparking_anim.repeat_count
  --local sparking_slowdown_factor = 4; 
  --electric_turret_object.prepared_speed = 1 / (sparking_frame_count * sparking_slowdown_factor)
  --electric_turret_object.prepared_speed_secondary = electric_turret_object.prepared_speed
  --electric_turret_object.prepared_animation =
  --{
  --  layers =
  --  {
  --    sparking_anim,
  --    get_sparking_glow_animation({repreat_count = 7}),
  --    get_sparking_light_animation({repreat_count = 7}),
  --    get_shadow_animation({repeat_count = sparking_frame_count}),
  --    get_color_mask_animation({repeat_count = sparking_frame_count}),        
  --  }
  --}
  
  -- animation played before attacking: energy creeping upwards on the middle pole
  local charging_slowdown_factor = 1; 
  local charging_anim = get_charging_animation({})
  electric_turret_object.starting_attack_speed = 1 / (charging_anim.frame_count * charging_slowdown_factor)
  electric_turret_object.starting_attack_animation =
  {
    layers =
    {
      charging_anim,
      get_charging_glow_animation({}),
      get_charging_light_animation({}),
      get_shadow_animation({repeat_count = charging_anim.frame_count}),
      get_color_mask_animation({repeat_count = charging_anim.frame_count}),        
    }
  }
  electric_turret_object.starting_attack_sound = 
  {
    filename = "__exotic-space-industries-remembrance__/teslas_legacy/sound/chargeup-with-zap.wav",
    volume = 0.7,
    speed = 1,
  }
  return electric_turret_object
end

local function make_script_effect(id)
  return
  {
    type = "script",
    effect_id = id,
  }
end

local function make_crit_damage_effect( critical, amount )  
  if not critical.probability then
    return nil
  end
  return make_composite_effect({
    make_script_effect("tl-critical-hit-effect-id"),
    make_vaporize_effect(amount * critical.multiplier),
    make_blood_explosion_effect()
  }, critical.probability )
end

function get_trigger_delivery_discharge()
  local settings = get_settings()
  return
  {
    type = "instant",
    target_effects = make_effect_list({
      -- NOTE.: control.lua will also add fire and AOE damage (explosion) 
      make_crit_damage_effect(settings.critical, settings.turret.advanced.damage),
      make_damage_effect(settings.turret.advanced.damage),
      make_lightning_beam_effect(),
	  -- TODO source_effect = light_explosion effect
    }),
  }
end

function make_lightning_beam_effect()
  return
  { -- visual only, this is the lightning bolt, not an actual explosion
    type = "create-explosion",
    entity_name = "tl-tesla-coil-turret-explosion",
    offset_deviation  = {{0,0},{0,0}}
  }
end

function make_blood_explosion_effect()
  return
  { -- visual only
    type = "create-explosion",
    entity_name = "blood-explosion-huge"
  }
end


function make_vaporize_effect(amount)
  local damage_effect = make_damage_effect(amount)
  damage_effect.vaporize = true
  return damage_effect
end

function make_damage_effect(amount)
  return
  {
    type = "damage",
    damage = { 
      amount = amount,
      type = "electric"
    } 
  }
end

function make_composite_effect(effects, probability)
  return
  {
    type = "nested-result",
    probability = probability,
    action =
    {
      type = "direct",
      action_delivery = 
      {
        type = "instant",
        target_effects = make_effect_list(effects),
      }
    }
  }
end

function make_effect_list(effects)
  filtered_effects = {}
  for i = 1, #effects do
    if effects[i] then
      table.insert(filtered_effects, effects[i])
    end
  end

  return filtered_effects
end

function get_trigger_delivery()
  return get_trigger_delivery_discharge()
end
 
function create_advanced_tesla_coil_turret()
  local electric_turret_object =
  {
    type = "electric-turret",
    name = "tl-advanced-tesla-coil",
    
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/icons/soviet-tesla.png",
    icon_size = 64, icon_mipmaps = 4,
    minable = 
    {
      mining_time = 0.6, 
      result = "tl-advanced-tesla-coil"
    },
    
    flags = 
    {
      "placeable-player", 
      "player-creation",
    },
    
    map_color = {r = 0, g = 0.365, b = 0.58, a = 1},
    max_health = settings.turret.advanced.health,
    preparing_sound = sounds.laser_turret_activate,
    folding_sound = sounds.laser_turret_deactivate,
    corpse = "medium-remnants",
    dying_explosion = "artillery-turret-explosion",
    attacking_speed = 1, 
    folding_speed = 1,
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    allow_copy_paste = true,
    start_attacking_only_when_can_shoot = true,
  
    attack_parameters =  
    {
      type = "beam",
      cooldown = 60 / settings.turret.advanced.fire_rate,
      range = settings.turret.advanced.range.max,
      prepare_range = settings.turret.advanced.range.max + 5,
      source_direction_count = 64,
      source_offset = {0,-100},
      damage_modifier = 1,  
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      ammo_type =
      {
        energy_consumption = "2000kJ",
        action = 
        {
          type = "direct",
          action_delivery = get_trigger_delivery(),
        }
      },
    }, 
    
    energy_source =
    {
      type = "electric",
      buffer_capacity = "4001kJ",
      input_flow_limit = "9600kW",
      drain = "35kW",
      usage_priority = "primary-input"
    },  
    
    hide_resistances = false,
    resistances = {
      -- resist its own attacks
      { type = "fire",      decrease = 20, percent = 80 },
      { type = "explosion", decrease = 20, percent = 80 },
      -- other resistance
      { type = "physical",  decrease = 10, percent = 30 },
      { type = "acid",      decrease = 5,  percent = 25 },
      { type = "electric",  decrease = 0,  percent = 95 },
    },
    
    light = {
      intensity = 30.0, 
      size = 100, 
      color = {r = 0.0, g = 1.0, b = 1.0}, 
      shift = {0,0}
    },
    graphics_set = {},
    call_for_help_radius = 48,
    vehicle_impact_sound = sounds.generic_impact,
  } 
  return init_animations(electric_turret_object)
end

data:extend({
  create_advanced_tesla_coil_turret()
})


