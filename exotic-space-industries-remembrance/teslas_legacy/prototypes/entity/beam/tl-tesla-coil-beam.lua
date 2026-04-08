require("teslas_legacy.prototypes.entity.sticker.tl-shock-sticker")
require("teslas_legacy.config.research")
require("teslas_legacy.config.settings")

local settings = get_settings()

-- Note, I dont want to change turrets or turret beams during Runtime
--       For this reason, there will be only one turret with one turret beam
--       Since this beam will be available from the initial turret research
--       I will make this relatively reasonable level.
function get_basic_turret_index()
  local index = get_default_index()
  index.slowdown.duration = 2
  index.slowdown.multiplier = 4
  index.slowdown.probability = 4
  return index
end

function get_beam_name_turret(index)
  local index = get_basic_turret_index()
  return "tl-tesla-coil-beam-turret-"
    .. index.slowdown.probability .. "-"
    .. index.slowdown.multiplier .. "-"
    .. index.slowdown.duration 
end

function get_beam_name_multi_zap(index)
  return "tl-tesla-coil-beam-multi-zap-"
    .. index.multi_zap.damage .. "-"
    .. index.slowdown.probability .. "-"
    .. index.slowdown.multiplier .. "-"
    .. index.slowdown.duration
end

local function make_tesla_beam_action(effects)

  filterred_effects = {}
  for i = 1, #effects do
    if effects[i] then
      table.insert(filterred_effects, effects[i])
    end
  end

  return
  {
    type = "direct",
    action_delivery =
    {
      type = "instant",
      target_effects = filterred_effects
    }
  }
end

local function make_damage_effect( amount )
  return
  {
    type = "damage",
    damage = { 
      amount = amount,
      type = "electric"
    } 
  }
end

local function make_crit_damage_effect( critical, amount )
  if not critical.probability then
    return nil
  end
  
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
            initial_ground_flame_count = 3
          },
        }
      }
    }
  }
end

local function make_shock_effect( shock, index )
  if not shock.probability then
    return nil
  end
  
  return
  {
    type = "create-sticker",
    probability = shock.probability,
    sticker = get_shock_sticker_name(index)
  }
end


local function make_tesla_beam( args )
  local result =
  {
    type = "beam",
    name = args.name,
    flags = {"not-on-map"},
    width = 0.5,
    damage_interval = 60 * 999,
    target_offset = {0, 0},
    action_triggered_automatically = false,
    action = make_tesla_beam_action({
      make_crit_damage_effect(settings.critical, args.damage_base * args.damage_mult),
      make_damage_effect(args.damage_base * args.damage_mult ),
      make_shock_effect(args.shock, args.index),
    }),
    hidden = true,
    hidden_in_factoriopedia = true
  }
  
  result.working_sound =
  {
    sound =
    {
      filename = "__base__/sound/fight/electric-beam.ogg",
      volume = 0.7
    },
    max_sounds_per_type = 4
  }
  result.name = args.name
  
  return append_base_electric_beam_graphics(result, beam_blend_mode, beam_non_light_flags, nil, nil)
end

local function make_multi_zap_beam(index)
  return make_tesla_beam({
    name = get_beam_name_multi_zap(index),
    damage_base = settings.turret.basic.damage,
    damage_mult = get_research(index).multi_zap.damage,
    shock = get_research(index).slowdown,
	index = index,
  })
end

local function make_turret_beam()
  local index = get_basic_turret_index()
  return make_tesla_beam({
    name = get_beam_name_turret(index),
    damage_base = settings.turret.basic.damage,
    damage_mult = 1,
    shock = get_research(index).slowdown,
	index = index,
  })
end

function tl_basic_tesla_coil_beam_data_extend()
  local research_array = get_research_array()
  local entities = {}
  
  -- Note.: multi_zap.range and multi_zap.probability has no effect on the beam entity itself
  
  for slowdown_duration = 1, #research_array.slowdown.duration do
    for slowdown_multiplier = 1, #research_array.slowdown.multiplier do
      for slowdown_probability = 1, #research_array.slowdown.probability do
      
        local index = get_default_index()        
        index.slowdown.duration = slowdown_duration
        index.slowdown.multiplier = slowdown_multiplier
        index.slowdown.probability = slowdown_probability 
        
        for damage = 1, #research_array.multi_zap.damage do
          index.multi_zap.damage = damage
          table.insert( entities, make_multi_zap_beam(index))
        end
      end
    end
  end
      
  table.insert( entities, make_turret_beam(index))
  
  data:extend( entities )
end



