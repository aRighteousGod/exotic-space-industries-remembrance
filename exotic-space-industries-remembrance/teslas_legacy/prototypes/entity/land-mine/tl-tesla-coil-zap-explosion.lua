require("teslas_legacy.lib.log")
require("teslas_legacy.prototypes.animation.empty")
require("teslas_legacy.config.research")
require("teslas_legacy.config.settings")

-- Description
--------------
-- this entity is representing a jumping lightning bolt, usually fired by script
-- when an enemy dies because of an advanced tesla coil.
--

function get_tesla_coli_zap_explosion_base_name()
  return "tl-tesla-coil-zap-explosion"
end

function get_tesla_coli_zap_explosion_name(index)
  return get_tesla_coli_zap_explosion_base_name() .. "-"
    .. index.flames.explosion .. "-"
    .. index.flames.probability
end

function get_tesla_coil_zap_explosion_entity(index)
  local research = get_research(index)
  local settings = get_settings()
  return{
    type = "land-mine",
    name = get_tesla_coli_zap_explosion_name(index),
    icon = "__base__/graphics/icons/land-mine.png",
    icon_size = 64, icon_mipmaps = 4,
    hidden = true,
    hidden_in_factoriopedia = true,
    
    -- this should not be interactable
    minable = nil,                                   -- not possible to pick this up
    max_health = 15000,                              -- almost idestructible
    is_military_target = false,                      -- biters wont prioritize this
    alert_when_damaged = false,                      -- no annoying alert when killed
    
    -- this should not be visible
    picture_safe = get_empty_picture(),
    picture_set = get_empty_picture(),
    picture_set_enemy = get_empty_picture(),
    
    ammo_category = "tl-advanced-tesla-coil-turret-category",        -- belong to tesla ammo group
    timeout = 0,                                          -- armed immediately
    trigger_force = 'all',                                -- we want it to explode immediately so anything can trigger it
    trigger_radius = settings.turret.advanced.range.max,  -- we know that an advanced tesla coil must be in range 
    action =
    {
      type = "direct",
      probability = research.flames.probability,
      action_delivery =
      {
        type = "instant",
        source_effects =
        {
          --{ -- visual only
          --  type = "create-entity",
          --  entity_name = "blood-explosion-huge" -- TODO critical hit effect
          --},
          make_explosion_effect(index),
          make_aoe_damage_effect(settings, research, 0.6),
        }
      }
    }
  }
end

function make_explosion_effect(index)
  if index.flames.explosion > 4 then
    return make_big_explosion_effect()
  else
    return make_small_explosion_effect()
  end
end

function make_small_explosion_effect()
  return
  { -- visual only
    type = "create-entity",
    entity_name = "land-mine-explosion"
  }
end

function make_big_explosion_effect()
  return
  { -- visual only
    type = "create-entity",
    entity_name = "medium-explosion"
  }
end

function make_aoe_damage_effect(settings, research, scale)
  return 
  { -- AOE damage
    type = "nested-result",
    affects_target = true,
    action =
    {
      type = "area",
      radius = research.flames.explosion,
      force = "all",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
          {
            type = "damage",
            damage = 
            {
              amount = settings.turret.advanced.damage * scale, 
              type = "explosion"
            }
          },
        }
      }
    }
  }
end


function tl_tesla_coil_zap_explosion_data_extend()
  local research_array = get_research_array()
  local entities = {}
  for explosion = 1, #research_array.flames.explosion do
    for probability = 1, #research_array.flames.probability do
      local index = get_default_index()
      index.flames.explosion = explosion
      index.flames.probability = probability
      table.insert( entities, get_tesla_coil_zap_explosion_entity(index))
    end
  end
  info("Registering zap-explosion prototypes: " .. #entities)
  data:extend( entities )
end 


