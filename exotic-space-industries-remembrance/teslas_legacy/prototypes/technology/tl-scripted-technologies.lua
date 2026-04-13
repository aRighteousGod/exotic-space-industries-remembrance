require ("teslas_legacy.config.research")
require ("teslas_legacy.config.settings")
require ("teslas_legacy.lib.technology")

-- These aliases document the original upstream science progression. The
-- internalized EI version no longer emits them directly; `make_technology()`
-- resolves each scripted Tesla tech to an EI age and therefore to EI packs.

local red = {"automation-science-pack", 1}
local green = {"logistic-science-pack", 1}
local black = {"military-science-pack", 1}
local blue = {"chemical-science-pack", 1}
local yellow = {"utility-science-pack", 1}
local purple= {"production-science-pack", 1}
local white={"space-science-pack", 1}

function get_name(name, index)
  if index then
    return name .. "-" .. index
  end
  return name
end

function get_icon(name) 
  return "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/" .. name .. ".png" 
end
function get_modifier_icon(name) 
  return "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/modifiers/" .. name .. "-modifier.png" 
end

local function create_nothing_effect( name, formatted_modifier, current_bonus )
  return
  { 
    {
      type = "nothing",
      icon = get_modifier_icon(name),
      icon_size = 64,
      effect_description = {name .. "-modifier", formatted_modifier, current_bonus},
    }
  }
end

local function percent_modifier(name, modifier, current_bonus)
  local function format(value)
    return value*100 .. '%'
  end  
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function inverse_percent_modifier(name, modifier, current_bonus)
  local function format(value)
    return (1-value)*100 .. '%'
  end  
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function duration_modifier(name, modifier, current_bonus)
  local function format(value)
    return value .. ' second(s)'
  end  
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function length_modifier(name, modifier, current_bonus)
  local function format(value)
    return value .. ' tile(s)'
  end  
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function counter_modifier(name, modifier, current_bonus)  
  return create_nothing_effect(name, tostring(modifier), tostring(current_bonus))
end

local function flames_counter_modifier(name, modifier, current_bonus)
  local settings = get_settings()
  local function format(value)
    return value .. ' damage: ' .. (settings.flames.damage * value) .. "/flame"
  end   
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function min_max_modifier(name, modifier, current_bonus)  
  local function format(value)
    return "min: " .. (value.minimal*100) .. '%, max: ' .. (value.maximal*100) .. "%" 
  end  
  return create_nothing_effect(name, format(modifier), format(current_bonus))
end

local function make_min_max_percent_technology(args)
  args.modifier_fn = min_max_modifier
  return make_technology(args)
end

local function make_length_technology(args)
  args.modifier_fn = length_modifier
  return make_technology(args)
end

local function make_duration_technology(args)
  args.modifier_fn = duration_modifier
  return make_technology(args)
end

local function make_inverse_percent_technology(args)
  args.modifier_fn = inverse_percent_modifier
  return make_technology(args)
end

local function make_percent_technology(args)
  args.modifier_fn = percent_modifier
  return make_technology(args)
end

local function make_counter_technology(args)
  args.modifier_fn = counter_modifier
  return make_technology(args)
end

local function make_flames_counter_technology(args)
  args.modifier_fn = flames_counter_modifier
  return make_technology(args)
end

function make_technology(args)
  local upgrade = false
  if args.level > 0 then
    upgrade = true
  end
  
  local technology_name = get_name(args.name, args.level)
  local age = get_tesla_technology_age(technology_name, args.level) or "electricity-age"
  
  local prerequisites = {}  
  if args.prerequisites then
    prerequisites = args.prerequisites
  else
    if args.level > 1 then 
      table.insert( prerequisites, get_name(args.name, args.level-1) )
    end
  end
  
  local mod = args.modifier or {0,1,2,3,4,5}
  local fn = args.modifier_fn or function(name, mod, x)
    return
    { 
      {
        type = "nothing", 
        effect_description = "tl-nothing",
      }
    }
  end
  
  local full_bonus = mod[args.level+1] 
  local delta_bonus = nil
  if type(full_bonus) == "table" then
    if full_bonus.minimal and full_bonus.maximal then
	  delta_bonus = {
	    minimal = full_bonus.minimal - mod[args.level].minimal,
	    maximal = full_bonus.maximal - mod[args.level].maximal,
	  }
	end
  else
    delta_bonus = full_bonus - (mod[args.level] or 0)
  end
  
  return
  {
    type = "technology",
    name = technology_name,
    icon_size = 128,
    icon_mipmaps = 4,
    icon = get_icon(args.name),
    effects = fn(args.name, delta_bonus, full_bonus),
    prerequisites = prerequisites,
    unit =
    {
      count = args.cost,
      -- Keep the per-call raw science tables as human-readable notes about the
      -- legacy pacing, but emit the final ingredients from the centralized TL
      -- age map so every scripted tech matches EI's pack system.
      ingredients = get_tesla_technology_science(technology_name, args.level),
      time = args.time
    },
    age = age,
    upgrade = upgrade,
    order = "e-l-b"
  }
end

function get_multi_zap_probability_technology_name(index)
  return get_name("tl-multi-zap-probability-technology", index)
end

function add_multi_zap_probability_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_multi_zap_probability_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =50, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.probability,
    prerequisites = { "tl-basic-tesla-coils-technology" }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =75, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.probability,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =120, time=40, science = {red, green, black, blue}, 
	modifier = modifiers.multi_zap.probability,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =200, time=40, science = {red, green, black, blue},
	modifier = modifiers.multi_zap.probability,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =400, time=50, science = {red, green, black, blue, yellow},
	modifier = modifiers.multi_zap.probability, 
  }))
end

function get_multi_zap_damage_technology_name(index)
  return get_name("tl-multi-zap-damage-technology", index)
end

function add_multi_zap_damage_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_multi_zap_damage_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =30, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.damage,
    prerequisites = { get_multi_zap_probability_technology_name(2) }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =50, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.damage,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =75, time=40, science = {red, green, black, blue},
	modifier = modifiers.multi_zap.damage,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =120, time=40, science = {red, green, black, blue},
	modifier = modifiers.multi_zap.damage, 
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =250, time=50, science = {red, green, black, blue, yellow},
	modifier = modifiers.multi_zap.damage, 
  }))
end

function get_multi_zap_range_technology_name(index)
  return get_name("tl-multi-zap-range-technology", index)
end

function add_multi_zap_range_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_multi_zap_range_technology_name()
  
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=1, cost=100, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.range,
    prerequisites = { get_multi_zap_probability_technology_name(2) }
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=2, cost=150, time=30, science = {red, green, black},
	modifier = modifiers.multi_zap.range, 
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=3, cost=200, time=40, science = {red, green, black, blue},
	modifier = modifiers.multi_zap.range, 
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=4, cost=300, time=40, science = {red, green, black, blue},
	modifier = modifiers.multi_zap.range, 
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=5, cost=550, time=50, science = {red, green, black, blue, yellow},
	modifier = modifiers.multi_zap.range, 
  }))
end



function get_slowdown_probability_technology_name(index)
  return get_name("tl-slowdown-probability-technology", index)
end

function add_slowdown_probability_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_slowdown_probability_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost=20, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.probability,
    prerequisites = { "tl-basic-tesla-coils-technology" }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost=45, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.probability, 
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost=90, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.probability,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost=140, time=40, science = {red, green, black, blue},
	modifier = modifiers.slowdown.probability, 
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost=200, time=40, science = {red, green, black, blue},
	modifier = modifiers.slowdown.probability, 
  }))
end

function get_slowdown_duration_technology_name(index)
  return get_name("tl-slowdown-duration-technology", index)
end

function add_slowdown_duration_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_slowdown_duration_technology_name()
  
  table.insert(technologies, make_duration_technology({ 
    name = technology_name, level=1, cost=20, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.duration,
    prerequisites = { get_slowdown_probability_technology_name(2) }
  }))
  table.insert(technologies, make_duration_technology({ 
    name = technology_name, level=2, cost=45, time=30, science = {red, green, black}, 
	modifier = modifiers.slowdown.duration,
  }))
  table.insert(technologies, make_duration_technology({ 
    name = technology_name, level=3, cost=90, time=30, science = {red, green, black}, 
	modifier = modifiers.slowdown.duration,
  }))
  table.insert(technologies, make_duration_technology({ 
    name = technology_name, level=4, cost=140, time=40, science = {red, green, black, blue} ,
	modifier = modifiers.slowdown.duration,
  }))
  table.insert(technologies, make_duration_technology({ 
    name = technology_name, level=5, cost=200, time=40, science = {red, green, black, blue}, 
	modifier = modifiers.slowdown.duration, 
  }))
end

function get_slowdown_multiplier_technology_name(index)
  return get_name("tl-slowdown-multiplier-technology", index)
end

function add_slowdown_multiplier_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_slowdown_multiplier_technology_name()
  
  table.insert(technologies, make_inverse_percent_technology({ 
    name = technology_name, level=1, cost =50, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.multiplier,
    prerequisites = { get_slowdown_probability_technology_name(2) }
  }))
  table.insert(technologies, make_inverse_percent_technology({ 
    name = technology_name, level=2, cost =75, time=30, science = {red, green, black},
	modifier = modifiers.slowdown.multiplier,
  }))
  table.insert(technologies, make_inverse_percent_technology({ 
    name = technology_name, level=3, cost =120, time=40, science = {red, green, black, blue},
	modifier = modifiers.slowdown.multiplier,
  }))
  table.insert(technologies, make_inverse_percent_technology({ 
    name = technology_name, level=4, cost =180, time=40, science = {red, green, black, blue},
	modifier = modifiers.slowdown.multiplier,
  }))
  table.insert(technologies, make_inverse_percent_technology({ 
    name = technology_name, level=5, cost =250, time=50, science = {red, green, black, blue, yellow},
	modifier = modifiers.slowdown.multiplier, 
  }))
end


function get_single_zap_probability_technology_name(index)
  return get_name("tl-single-zap-probability-technology", index)
end

function add_single_zap_probability_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_single_zap_probability_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =50, time=30, science = {red, green, black},
	modifier = modifiers.single_zap.probability,
    prerequisites = { "tl-advanced-tesla-coils-technology" }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =75, time=30, science = {red, green, black} ,
	modifier = modifiers.single_zap.probability,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =120, time=40, science = {red, green, black, blue},
	modifier = modifiers.single_zap.probability, 
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =200, time=40, science = {red, green, black, blue},
	modifier = modifiers.single_zap.probability, 
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =300, time=50, science = {red, green, black, blue, yellow},
	modifier = modifiers.single_zap.probability, 
  }))
end

function get_single_zap_damage_technology_name(index)
  return get_name("tl-single-zap-damage-technology", index)
end

function add_single_zap_damage_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_single_zap_damage_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =100, time=40, science = {red, green, black, blue},
	modifier = modifiers.single_zap.damage,
    prerequisites = { get_single_zap_probability_technology_name(2) }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =200, time=40, science = {red, green, black, blue},
	modifier = modifiers.single_zap.damage,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =300, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.single_zap.damage,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =500, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.single_zap.damage,
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =750, time=90, science = {red, green, black, blue, yellow, purple},
	modifier = modifiers.single_zap.damage, 
  }))
end

function get_single_zap_count_technology_name(index)
  return get_name("tl-single-zap-count-technology", index)
end

function add_single_zap_count_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_single_zap_count_technology_name()
  
  table.insert(technologies, make_counter_technology({ 
    name = technology_name, level=1, cost =50, time=40, science = {red, green, black, blue},
    modifier = modifiers.single_zap.count, 
    prerequisites = { get_single_zap_probability_technology_name(2) }
  }))
  table.insert(technologies, make_counter_technology({ 
    name = technology_name, level=2, cost =75, time=40, science = {red, green, black, blue},
    modifier = modifiers.single_zap.count,  
  }))
  table.insert(technologies, make_counter_technology({ 
    name = technology_name, level=3, cost =120, time=40, science = {red, green, black, blue} ,
    modifier = modifiers.single_zap.count,  
  }))
  table.insert(technologies, make_counter_technology({ 
    name = technology_name, level=4, cost =200, time=60, science = {red, green, black, blue} ,
    modifier = modifiers.single_zap.count,  
  }))
  table.insert(technologies, make_counter_technology({ 
    name = technology_name, level=5, cost =400, time=60, science = {red, green, black, blue, yellow},
    modifier = modifiers.single_zap.count,   
  }))
end


function get_flames_probability_technology_name(index)
  return get_name("tl-flames-probability-technology", index)
end

function add_flames_probability_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_flames_probability_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =50, time=30, science = {red, green, black},
    modifier = modifiers.flames.probability,  
    prerequisites = { "tl-advanced-tesla-coils-technology" }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =75, time=30, science = {red, green, black} ,
    modifier = modifiers.flames.probability,  
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =100, time=30, science = {red, green, black, blue} ,
    modifier = modifiers.flames.probability,  
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =180, time=30, science = {red, green, black, blue} ,
    modifier = modifiers.flames.probability,  
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =250, time=30, science = {red, green, black, blue, yellow} ,
    modifier = modifiers.flames.probability,  
  }))
end

function get_flames_count_technology_name(index)
  return get_name("tl-flames-count-technology", index)
end

function add_flames_count_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_flames_count_technology_name()
  
  table.insert(technologies, make_flames_counter_technology({ 
    name = technology_name, level=1, cost=50, time=30, science = {red, green, black},
    modifier = modifiers.flames.count,  
    prerequisites = { get_flames_probability_technology_name(2) }
  }))
  table.insert(technologies, make_flames_counter_technology({ 
    name = technology_name, level=2, cost=75, time=30, science = {red, green, black} ,
    modifier = modifiers.flames.count,  
  }))
  table.insert(technologies, make_flames_counter_technology({ 
    name = technology_name, level=3, cost=120, time=30, science = {red, green, black, blue},
    modifier = modifiers.flames.count,  
  }))
  table.insert(technologies, make_flames_counter_technology({ 
    name = technology_name, level=4, cost=200, time=30, science = {red, green, black, blue},
    modifier = modifiers.flames.count,  
  }))
  table.insert(technologies, make_flames_counter_technology({ 
    name = technology_name, level=5, cost=300, time=30, science = {red, green, black, blue, yellow},
    modifier = modifiers.flames.count,   
  }))
end


function get_flames_explosion_technology_name(index)
  return get_name("tl-flames-explosion-technology", index)
end

function add_flames_explosion_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_flames_explosion_technology_name()
  
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=1, cost=100, time=40, science = {red, green, black, blue},
	modifier = modifiers.flames.explosion,  
    prerequisites = { get_flames_probability_technology_name(2) }
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=2, cost =175, time=40, science = {red, green, black, blue},
	modifier = modifiers.flames.explosion,   
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=3, cost =240, time=40, science = {red, green, black, blue},
	modifier = modifiers.flames.explosion,   
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=4, cost =320, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.flames.explosion,   
  }))
  table.insert(technologies, make_length_technology({ 
    name = technology_name, level=5, cost =570, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.flames.explosion,   
  }))
end


function get_volatility_modulation_technology_name(index)
  return get_name("tl-volatility-modulation-technology", index)
end

function add_volatility_modulation_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_volatility_modulation_technology_name()
  
  table.insert(technologies, make_min_max_percent_technology({ 
    name = technology_name, level=1, cost=100, time=40, science = {red, green, black, blue},
	modifier = modifiers.volatility.modulation,  
    prerequisites = { "tl-tesla-tank-technology" }
  }))
  table.insert(technologies, make_min_max_percent_technology({ 
    name = technology_name, level=2, cost=200, time=60, science = {red, green, black, blue},
	modifier = modifiers.volatility.modulation,   
  }))
  table.insert(technologies, make_min_max_percent_technology({ 
    name = technology_name, level=3, cost=300, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.volatility.modulation,   
  }))
  table.insert(technologies, make_min_max_percent_technology({ 
    name = technology_name, level=4, cost=450, time=90, science = {red, green, black, blue, yellow},
	modifier = modifiers.volatility.modulation,  
  }))
  table.insert(technologies, make_min_max_percent_technology({ 
    name = technology_name, level=5, cost=800, time=90, science = {red, green, black, blue, yellow, purple},
	modifier = modifiers.volatility.modulation,   
  }))
end

function get_volatility_probability_technology_name(index)
  return get_name("tl-volatility-probability-technology", index)
end

function add_volatility_probability_technologies(technologies)
  local modifiers = get_research_array()
  local technology_name = get_volatility_probability_technology_name()
  
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=1, cost =150, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.volatility.probability,  
    prerequisites = { "tl-tesla-tank-technology" }
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=2, cost =250, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.volatility.probability,  
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=3, cost =400, time=60, science = {red, green, black, blue, yellow},
	modifier = modifiers.volatility.probability,   
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=4, cost =750, time=90, science = {red, green, black, blue, yellow, purple},
	modifier = modifiers.volatility.probability,   
  }))
  table.insert(technologies, make_percent_technology({ 
    name = technology_name, level=5, cost =1000, time=90, science = {red, green, black, blue, yellow, purple},
	modifier = modifiers.volatility.probability,   
  }))
end

function all_scripted_technology_data_extend()
  technologies = {}
  -------
  add_multi_zap_probability_technologies(technologies)
  add_multi_zap_damage_technologies(technologies)
  add_multi_zap_range_technologies(technologies)
  -------
  add_slowdown_probability_technologies(technologies)
  add_slowdown_duration_technologies(technologies)
  add_slowdown_multiplier_technologies(technologies)
  -------
  add_single_zap_probability_technologies(technologies)
  add_single_zap_damage_technologies(technologies)
  add_single_zap_count_technologies(technologies)
  -------
  add_flames_probability_technologies(technologies)
  add_flames_explosion_technologies(technologies)
  add_flames_count_technologies(technologies)
  -------
  add_volatility_probability_technologies(technologies)
  add_volatility_modulation_technologies(technologies)
  -------
  data:extend(technologies)
end

