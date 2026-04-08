require("teslas_legacy.lib.log")
require("teslas_legacy.config.settings")
require("teslas_legacy.config.research")
local fireutil = require("__base__.prototypes.fire-util")

function get_tesla_coil_zap_fire_base_name()
  return "tl-tesla-coil-zap-fire"
end

function get_tesla_coil_zap_fire_name(index)
  return get_tesla_coil_zap_fire_base_name() .. "-"
    .. index.flames.count 
end

function get_tesla_coil_zap_fire_entity(index)
  local research = get_research(index)
  local settings = get_settings()
  return fireutil.add_basic_fire_graphics_and_effects_definitions({
    type = "fire",
    hidden = true,
    hidden_in_factoriopedia = true,
    name = get_tesla_coil_zap_fire_name(index),
    flags = {"placeable-off-grid", "not-on-map"},
    damage_per_tick = 
    {
      amount = (settings.flames.damage * research.flames.count) / 60, 
      type = "fire"
    },
    maximum_damage_multiplier = 6,
    damage_multiplier_increase_per_added_fuel = 1,
    damage_multiplier_decrease_per_tick = 0.005,
  
    spawn_entity = "fire-flame-on-tree",
  
    spread_delay = 300, 
    spread_delay_deviation = 180,
    maximum_spread_count = 100,
  
    emissions_per_second = { pollution = 0.005 },
    burnt_patch_lifetime = 3600,
    initial_lifetime = 60,
    lifetime_increase_by = 150,
    lifetime_increase_cooldown = 4,
    maximum_lifetime = 1800,
    delay_between_initial_flames = 1, 
    initial_flame_count = research.flames.count,
    fade_out_duration = 60,
  })
end

function get_tesla_coil_zap_fire_data_extend()
  local research_array = get_research_array()
  local entities = {}
  for count = 1, #research_array.flames.count do
    local index = get_default_index()
    index.flames.count = count
    table.insert( entities, get_tesla_coil_zap_fire_entity(index))
  end
  info("Registering zap-fire prototypes: " .. #entities)
  data:extend( entities )
end


