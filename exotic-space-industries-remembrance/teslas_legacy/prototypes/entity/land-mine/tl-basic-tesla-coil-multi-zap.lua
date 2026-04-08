require("teslas_legacy.lib.log")
require("teslas_legacy.config.research")
require("teslas_legacy.prototypes.animation.empty")
require("teslas_legacy.prototypes.entity.beam.tl-tesla-coil-beam")

function get_multi_zap_base_name()
  return "tl-basic-tesla-coil-multi-zap"
end

function get_multi_zap_name(index)
  return get_multi_zap_base_name() .. "-"
    .. index.multi_zap.range .. "-"
    .. index.multi_zap.damage .. "-"
    .. index.slowdown.duration .. "-"
    .. index.slowdown.multiplier .. "-"
    .. index.slowdown.probability 
end

function get_multi_zap_entity(index)
  local research = get_research(index)
  return
  {
    type = "land-mine",
    name = get_multi_zap_name(index),
    
    -- this should not be interactable
    minable = nil,                                   -- not possible to pick this up
    max_health = 15000,                              -- almost idestructible
    is_military_target = false,                      -- biters wont prioritize this
    alert_when_damaged = false,                      -- no annoying alert when killed
    
    -- this should not be visible
    picture_safe = get_empty_picture(),
    picture_set = get_empty_picture(),
    picture_set_enemy = get_empty_picture(),
                             
    ammo_category = "tl-basic-tesla-coil-turret-category",   -- belong to tesla ammo group
    force_die_on_attack = false,                     -- does NOT die when shooting
                                                     --    a corresponding 'timer' entity 
                                                     --    will clean it up
    timeout = 0,                                     -- can shoot immediately
    trigger_radius = research.multi_zap.range,  
    action =
    {
      type = "area",
      show_in_tooltip = false,
      radius = research.multi_zap.range,
      force = "enemy",
      action_delivery =
      {
        type = "beam",
        beam = get_beam_name_multi_zap(index),
        max_length = research.multi_zap.range,
      }
    },
    
    icon = "__base__/graphics/icons/land-mine.png",
    icon_size = 64,
    icon_mipmaps = 4,
    hidden = true,
    hidden_in_factoriopedia = true,
  }
end

function tl_basic_tesla_coil_multi_zap_data_extend()
  local research_array = get_research_array()
  local entities = {}
  for mz_range = 1, #research_array.multi_zap.range do
      for mz_damage = 1, #research_array.multi_zap.damage do
        for slowdown_duration = 1, #research_array.slowdown.duration do
          for slowdown_multiplier = 1, #research_array.slowdown.multiplier do
            for slowdown_probability = 1, #research_array.slowdown.probability do
              local index = get_default_index()
              index.multi_zap.damage = mz_damage
              index.multi_zap.range = mz_range
              index.slowdown.duration = slowdown_duration
              index.slowdown.multiplier = slowdown_multiplier
              index.slowdown.probability = slowdown_probability
              table.insert( entities, get_multi_zap_entity(index))
            end
          end
        end
      end
  end
  info("Registering multi-zap prototypes: " .. #entities)
  data:extend( entities )
end 


