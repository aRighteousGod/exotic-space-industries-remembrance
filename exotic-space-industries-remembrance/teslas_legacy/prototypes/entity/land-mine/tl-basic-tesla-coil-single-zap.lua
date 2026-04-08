require("teslas_legacy.lib.log")
require("teslas_legacy.prototypes.entity.beam.tl-tesla-coil-beam")
require("teslas_legacy.prototypes.entity.land-mine.tl-tesla-coil-zap-explosion")
require("teslas_legacy.prototypes.entity.fire.tl-tesla-coil-zap-fire")
require("teslas_legacy.prototypes.animation.empty")
require("teslas_legacy.config.research")
require("teslas_legacy.config.settings")

function get_single_zap_base_name()
  return "tl-basic-tesla-coil-single-zap"
end

function get_single_zap_name(index)
  return get_single_zap_base_name() .. "-"
    .. index.single_zap.damage .. "-"
    .. index.single_zap.count
end

function get_single_zap_range(settings)
  return settings.turret.advanced.range.max / 4
end

local function make_direct_damage_effect(settings, research)
  return
  { -- the shock damage
    type = "damage",
    damage =
    { 
      amount = settings.turret.advanced.damage * research.single_zap.damage, 
      type = "electric"
    }
  }
end

local function make_lightning_beam_effect()
  return 
  { -- this is not an explosion, it is a lightning beam
    type = "create-explosion",
    entity_name = "tl-tesla-coil-turret-explosion"
  }
end


local function get_single_zap_entity(index)
  local research = get_research(index)
  local settings = get_settings()
  return
  {
    type = "land-mine",
    name = get_single_zap_name(index),
    
    -- this should not be interactable
    minable = nil,                                   -- not possible to pick this up
    max_health = 15000,                              -- almost idestructible
    is_military_target = false,                      -- biters wont prioritize this
    alert_when_damaged = false,                      -- no annoying alert when killed
    
    -- this should not be visible
    picture_safe = get_empty_picture(),
    picture_set = get_empty_picture(),
    picture_set_enemy = get_empty_picture(),
                             
    ammo_category = "tl-advanced-tesla-coil-turret-category",   -- belong to tesla ammo group
    force_die_on_attack = false,                     -- does NOT die when shooting
                                                     --    a corresponding 'timer' entity 
                                                     --    will clean it up
    timeout = 0,                                     -- can shoot immediately
    trigger_radius = settings.turret.advanced.range.max,  
    action =
    {
      type = "direct",
      show_in_tooltip = true,
      radius = get_single_zap_range(settings),
      force = "enemy",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
          make_direct_damage_effect(settings, research),
          make_lightning_beam_effect()
        },
      }
    },
        
    icon = "__base__/graphics/icons/land-mine.png",
    icon_size = 64,
    icon_mipmaps = 4,
    hidden = true,
    hidden_in_factoriopedia = true,
  }
end

function tl_basic_tesla_coil_single_zap_data_extend()
  local research_array = get_research_array()
  local entities = {}
  for damage = 1, #research_array.single_zap.damage do
    for count = 1, #research_array.single_zap.count do
      local index = get_default_index()
      index.single_zap.damage = damage
      index.single_zap.count = count
      table.insert( entities, get_single_zap_entity(index))
    end
  end
  
  info("Registering single-zap prototypes: " .. #entities)
  data:extend( entities )
end


