require ("teslas_legacy.config.research")

function get_shock_sticker_name(index)
  return "tl-shock-sticker-" 
	  .. index.slowdown.multiplier .. "-"
	  .. index.slowdown.duration 
end

function make_shock_sticker(index)
  local research = get_research(index)
  return
  {
    type = "sticker",
    name = get_shock_sticker_name(index),
    duration_in_ticks = research.slowdown.duration * 60,
    target_movement_modifier_from = research.slowdown.multiplier,
    target_movement_modifier_to = 1,
  }
end

function tl_shock_sticker_data_extend()
  local research_array = get_research_array()
  local entities = {}
  for duration = 1, #research_array.slowdown.duration do
    for multiplier = 1, #research_array.slowdown.multiplier do
      local index = get_default_index()
      index.slowdown.duration = duration
      index.slowdown.multiplier = multiplier
      table.insert( entities, make_shock_sticker(index))
    end
  end
  data:extend( entities )
end 


