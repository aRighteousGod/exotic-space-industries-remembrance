local asteroid_functions = {}

asteroid_functions.standard_speed = 1 * meter/second

asteroid_functions.weighted_average = function(A, B, weight)
  local result = A + ((B-A)*weight)
  return result
end

asteroid_functions.nauvis_ratio      = {9, 0, 0, 0, 9, 0}
asteroid_functions.vulcanus_ratio    = {0, 9, 0, 0, 0, 0}
asteroid_functions.gleba_ratio       = {0, 0, 0, 9, 0, 0}
asteroid_functions.fulgora_ratio     = {0, 0, 0, 0, 0, 9}
asteroid_functions.aquilo_ratio      = {0, 0, 9, 0, 0, 0}
asteroid_functions.system_edge_ratio = {0, 0, 3, 0, 0, 0}

asteroid_functions.cerys_ratio       = {3, 0, 3, 0, 0, 3}
asteroid_functions.muluna_ratio      = {2, 5, 0, 0, 0, 0}
asteroid_functions.maraxsis_ratio    = {0, 2, 0, 4, 4, 0}
asteroid_functions.gaia_ratio      = {2, 0, 1, 6, 0, 0}


asteroid_functions.nauvis_chunks      = 0.0125
asteroid_functions.vulcanus_chunks    = 0.0020
asteroid_functions.vulcanus_medium    = 0.0025
asteroid_functions.gleba_chunks       = 0.0030
asteroid_functions.gleba_medium       = 0.0025
asteroid_functions.fulgora_chunks     = 0.0025
asteroid_functions.fulgora_medium     = 0.0025
asteroid_functions.aquilo_chunks      = 0.0010
asteroid_functions.aquilo_big         = 0.0025
asteroid_functions.system_edge_chunks = 0.0005
asteroid_functions.system_edge_huge   = 0.00125

asteroid_functions.cerys_chunks       = 0.005
asteroid_functions.cerys_medium       = 0.0005
asteroid_functions.muluna_chunks      = 0.01
asteroid_functions.maraxsis_chunks    = 0.001
asteroid_functions.maraxsis_medium    = 0.0025
asteroid_functions.gaia_chunks      = 0.001
asteroid_functions.gaia_medium      = 0.0015

asteroid_functions.chunk_angle = 1
asteroid_functions.small_angle = 0.7
asteroid_functions.medium_angle = 0.6
asteroid_functions.big_angle = 0.5
asteroid_functions.huge_angle = 0.4

asteroid_functions.nauvis_vulcanus =
{
  types = {"uranium", "rock", "petrified"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.vulcanus_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.5, probability = asteroid_functions.vulcanus_medium * 3, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.vulcanus_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.9, ratios = asteroid_functions.vulcanus_ratio},
  }
}

asteroid_functions.nauvis_gleba =
{
  types = {"uranium", "organic", "petrified"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.gleba_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.5, probability = asteroid_functions.gleba_medium * 3, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.gleba_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.9, ratios = asteroid_functions.gleba_ratio},
  }
}

asteroid_functions.nauvis_fulgora =
{
  types = {"uranium", "petrified", "scrap"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.fulgora_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.5, probability = asteroid_functions.fulgora_medium * 3, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.fulgora_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.9, ratios = asteroid_functions.fulgora_ratio},
  }
}

asteroid_functions.vulcanus_gleba =
{
  types = {"rock", "organic"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.vulcanus_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.gleba_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.vulcanus_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.5, probability = asteroid_functions.weighted_average(asteroid_functions.vulcanus_medium, asteroid_functions.gleba_medium, 0.5) * 3, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.gleba_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.vulcanus_ratio},
    {position = 0.9, ratios = asteroid_functions.gleba_ratio},
  }
}

asteroid_functions.gleba_fulgora =
{
  types = {"organic", "scrap"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.gleba_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.fulgora_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.gleba_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.5, probability = asteroid_functions.weighted_average(asteroid_functions.gleba_medium, asteroid_functions.fulgora_medium, 0.5) * 3, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.fulgora_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.gleba_ratio},
    {position = 0.9, ratios = asteroid_functions.fulgora_ratio},
  }
}

asteroid_functions.gleba_aquilo =
{
  types = {"chemical", "organic"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.gleba_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.aquilo_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.gleba_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.medium_angle}
  },
  probability_on_range_big =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.big_angle},
    {position = 0.9, probability = asteroid_functions.aquilo_big, angle_when_stopped = asteroid_functions.big_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.gleba_ratio},
    {position = 0.4, ratios = asteroid_functions.aquilo_ratio},
    {position = 0.9, ratios = asteroid_functions.aquilo_ratio}
  }
}

asteroid_functions.fulgora_aquilo =
{
  types = {"chemical", "scrap"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.aquilo_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.medium_angle}
  },
  probability_on_range_big =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.big_angle},
    {position = 0.9, probability = asteroid_functions.aquilo_big, angle_when_stopped = asteroid_functions.big_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.fulgora_ratio},
    {position = 0.4, ratios = asteroid_functions.aquilo_ratio},
    {position = 0.9, ratios = asteroid_functions.aquilo_ratio}
  }
}

asteroid_functions.aquilo_solar_system_edge =
{
  types = {"uranium", "rock", "chemical"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.aquilo_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.system_edge_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_big =
  {
    {position = 0.1, probability = asteroid_functions.aquilo_big, angle_when_stopped = asteroid_functions.big_angle},
    {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.big_angle}
  },
  probability_on_range_huge =
  {
    {position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.huge_angle},
    {position = 0.9, probability = asteroid_functions.system_edge_huge, angle_when_stopped = asteroid_functions.huge_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.aquilo_ratio},
    {position = 0.2, ratios = {0, 0, 5, 0, 0, 0}},
    {position = 0.3, ratios = {0, 1, 6, 0, 0, 0}},
    {position = 0.4, ratios = {0, 2, 7, 0, 0, 0}},
    {position = 0.5, ratios = {1, 1, 4, 0, 0, 0}},
    {position = 0.6, ratios = {2, 0, 1, 0, 0, 0}},
    {position = 0.7, ratios = {4, 2, 0, 0, 0, 0}},
    {position = 0.8, ratios = {7, 0, 0, 0, 0, 0}},
    {position = 0.9, ratios = asteroid_functions.system_edge_ratio},
  }
}

asteroid_functions.shattered_planet_trip =
{
  types = {"uranium", "rock", "chemical", "organic", "petrified", "scrap"},
  probability_on_range_huge   =
  {
    {position = 0.001, probability = asteroid_functions.system_edge_huge, angle_when_stopped = asteroid_functions.huge_angle},
    {position = 0.999, probability = 0.111, angle_when_stopped = asteroid_functions.huge_angle}
  },
  type_ratios =
  {
    {position = 0.001, ratios = asteroid_functions.system_edge_ratio},
    {position = 0.002, ratios = {0, 0, 3, 1, 1, 0}},-- 3 5 2
    {position = 0.2,   ratios = {0.5, 1, 4, 1, 2, 0}},
    {position = 0.3,   ratios = {1, 2, 5, 1, 3, 1}},
    {position = 0.4,   ratios = {2, 3, 5, 1, 4, 5}},
    {position = 0.5,   ratios = {4, 4, 5, 1, 5, 2}},
    {position = 0.6,   ratios = {8, 5, 5, 1, 6, 4}},
    {position = 0.7,   ratios = {9, 6, 5, 1, 8, 8}},
    {position = 0.8,   ratios = {10, 7, 5, 1, 10, 11}},
    {position = 0.999, ratios = {10, 8, 5, 1, 12, 12}}
  }
}

asteroid_functions.fulgora_cerys =
{
  types = {"uranium", "chemical", "scrap"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.5, probability = asteroid_functions.weighted_average(asteroid_functions.fulgora_chunks, asteroid_functions.cerys_chunks, 0.5), angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.cerys_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.4, probability = asteroid_functions.fulgora_medium * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.cerys_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.fulgora_ratio},
    {position = 0.9, ratios = asteroid_functions.cerys_ratio},
  }
}

asteroid_functions.nauvis_muluna =
{
  types = {"uranium", "rock", "petrified"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    --{position = 0.5, probability = asteroid_functions.weighted_average(asteroid_functions.nauvis_chunks, asteroid_functions.muluna_chunks, 0.7) * 2, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.muluna_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.9, ratios = asteroid_functions.muluna_ratio},
  }
}

asteroid_functions.nauvis_gaia =
{
  types = {"uranium", "scrap","chemical"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.3, probability = asteroid_functions.weighted_average(asteroid_functions.nauvis_chunks, asteroid_functions.muluna_chunks, 0.7) * 2, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.6, probability = asteroid_functions.gaia_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.gaia_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.nauvis_chunks * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.3, probability = asteroid_functions.nauvis_chunks, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.6, probability = asteroid_functions.gaia_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.gaia_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.3, ratios = asteroid_functions.nauvis_ratio},
    {position = 0.6, ratios = asteroid_functions.gaia_ratio},
    {position = 0.9, ratios = asteroid_functions.gaia_ratio}
  }
}

asteroid_functions.vulcanus_maraxsis =
{
  types = {"rock", "organic", "petrified"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.vulcanus_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.maraxsis_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.vulcanus_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.3, probability = asteroid_functions.vulcanus_medium * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.6, probability = asteroid_functions.maraxsis_medium * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.maraxsis_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.vulcanus_ratio},
    {position = 0.9, ratios = asteroid_functions.maraxsis_ratio},
  }
}

asteroid_functions.fulgora_maraxsis =
{
  types = {"rock", "organic", "petrified", "scrap"},
  probability_on_range_chunk =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_chunks, angle_when_stopped = asteroid_functions.chunk_angle},
    {position = 0.9, probability = asteroid_functions.maraxsis_chunks, angle_when_stopped = asteroid_functions.chunk_angle}
  },
  probability_on_range_medium =
  {
    {position = 0.1, probability = asteroid_functions.fulgora_medium, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.3, probability = asteroid_functions.fulgora_medium * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.6, probability = asteroid_functions.maraxsis_medium * 0.5, angle_when_stopped = asteroid_functions.medium_angle},
    {position = 0.9, probability = asteroid_functions.maraxsis_medium, angle_when_stopped = asteroid_functions.medium_angle}
  },
  type_ratios =
  {
    {position = 0.1, ratios = asteroid_functions.fulgora_ratio},
    {position = 0.9, ratios = asteroid_functions.maraxsis_ratio},
  }
}

asteroid_functions.search_in_table = function(table, key)
  local found = false
  for k, entry in pairs(table) do
    if entry == key then
      found = true
      return found
    end
  end
  return found
end

asteroid_functions.find_lower_point = function(position, data)
  local position_data = {position = 0}
  for k, data_point in pairs(data) do
    if data_point.position <= position and data_point.position > position_data.position then
      position_data = data_point
    end
  end
  return position_data
end

asteroid_functions.find_higher_point = function(position, data)
  local position_data = {position = 1}
  for k, data_point in pairs(data) do
    if data_point.position >= position then
      if data_point.position < position_data.position then
        position_data = data_point
      end
    end
  end
  return position_data
end

asteroid_functions.interpolate_points = function(pointA, pointB, position)
  if pointA.position == pointB.position then
    return pointA.probability, pointA.angle_when_stopped or 1
  end
  local range = pointB.position - pointA.position
  local position_in_range = (position - pointA.position) / range
  local probability_difference = pointB.probability - pointA.probability
  local interpolated_probability = pointA.probability + position_in_range * probability_difference
  local angle_a = (pointA.angle_when_stopped or 1)
  local angle_b = (pointB.angle_when_stopped or 1)
  local angle_difference = angle_b - angle_a
  local interpolated_angle = angle_a + position_in_range * angle_difference
  return interpolated_probability, interpolated_angle
end

asteroid_functions.normalize_ratio = function(ratio)
  local r = {}
  local max = 0
  for k, v in pairs(ratio) do
    if v > max then
      max = v
    end
  end
  for k, v in pairs(ratio) do
    table.insert(r, v/max)
  end
  return r
end

asteroid_functions.interpolate_point_ratio = function(pointA, pointB, position)
  local interpolated_data = {position = position, ratios = {1,1,1,1}}
  for k, r in pairs(pointA.ratios) do
    local interpolated_probability, interpolated_angle = asteroid_functions.interpolate_points(
      {position = pointA.position, probability = asteroid_functions.normalize_ratio(pointA.ratios)[k]},
      {position = pointB.position, probability = asteroid_functions.normalize_ratio(pointB.ratios)[k]},
      position
    )
    interpolated_data.ratios[k] = interpolated_probability
  end
  return interpolated_data.ratios
end

asteroid_functions.asteroid_spawn_point = function(asteroid_type, ratio_data, probability_data, planet)
  -- get significant positions
  local significant_positions = {}
  for k, point in pairs(ratio_data) do
    table.insert(significant_positions, point.position)
  end

  for k, point in pairs(probability_data) do
    local point_is_already_in_table = asteroid_functions.search_in_table(significant_positions, point.position)
    if point_is_already_in_table == false then
      table.insert(significant_positions, point.position)
    end
  end

  table.sort(significant_positions)

  local spawn_points = {}
  -- fill every significant position with data and add it to spawn points
  for k, significant_position in pairs(significant_positions) do
    if planet == nil or planet == significant_position then
      local ratio_lower_point  = asteroid_functions.find_lower_point(significant_position, ratio_data)
      local ratio_higher_point = asteroid_functions.find_higher_point(significant_position, ratio_data)
      local interpolated_ratio = asteroid_functions.interpolate_point_ratio(ratio_lower_point, ratio_higher_point, significant_position)

      local probability_lower_point  = asteroid_functions.find_lower_point(significant_position, probability_data)
      local probability_higher_point = asteroid_functions.find_higher_point(significant_position, probability_data)
      local interpolated_probability, interpolated_angle = asteroid_functions.interpolate_points(probability_lower_point, probability_higher_point, significant_position)

      local spawn_point = {}
      if planet == nil then
        spawn_point = {distance = significant_position, probability = interpolated_probability * interpolated_ratio[asteroid_type], speed = asteroid_functions.standard_speed, angle_when_stopped = interpolated_angle}
      else
        spawn_point = {probability = interpolated_probability * interpolated_ratio[asteroid_type], speed = asteroid_functions.standard_speed, angle_when_stopped = interpolated_angle}
      end

      table.insert(spawn_points, spawn_point)
    end
  end

  return spawn_points
end

asteroid_functions.are_all_zero = function(table)
  local are_all_zero = true
  if table ~= nil then
    for k, v in pairs(table) do
      if v.probability ~= 0 then
        are_all_zero = false
      end
    end
  end
  return are_all_zero
end

asteroid_functions.spawn_definitions = function(data, planet)
  local asteroid_spawn_definitions = {}
  local asteroid_sizes = {"chunk", "small", "medium", "big", "huge"}
  local asteroid_types = data.types
  for k, asteroid_size in pairs(asteroid_sizes) do
    for k, asteroid_type in pairs(asteroid_types) do
      local asteroid_name = "ei-"
      if asteroid_size == "chunk" then
        asteroid_name = asteroid_name..asteroid_type .. "-asteroid-chunk"
      else
        asteroid_name = asteroid_name..asteroid_size .. "-" .. asteroid_type .. "-asteroid"
      end

      local asteroid_id = 0
      if asteroid_type == "uranium" then
        asteroid_id = 1
      elseif asteroid_type == "rock" then
        asteroid_id = 2
      elseif asteroid_type == "chemical" then
        asteroid_id = 3
      elseif asteroid_type == "organic" then
        asteroid_id = 4
      elseif asteroid_type == "petrified" then
        asteroid_id = 5
      elseif asteroid_type == "scrap" then
        asteroid_id = 6
      end

      local probability_data = {}
      if asteroid_size == "chunk" then
        probability_data = data.probability_on_range_chunk or {{position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.chunk_angle}, {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.chunk_angle}}
      elseif asteroid_size == "small" then
        probability_data = data.probability_on_range_small or {{position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.small_angle}, {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.small_angle}}
      elseif asteroid_size == "medium" then
        probability_data = data.probability_on_range_medium or {{position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.medium_angle}, {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.medium_angle}}
      elseif asteroid_size == "big" then
        probability_data = data.probability_on_range_big or {{position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.big_angle}, {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.big_angle}}
      elseif asteroid_size == "huge" then
        probability_data = data.probability_on_range_huge or {{position = 0.1, probability = 0, angle_when_stopped = asteroid_functions.huge_angle}, {position = 0.9, probability = 0, angle_when_stopped = asteroid_functions.huge_angle}}
      end

      if asteroid_functions.are_all_zero(probability_data) == false and planet == nil then
        local asteroid_definition =
        {
          asteroid = asteroid_name,
          spawn_points = asteroid_functions.asteroid_spawn_point(asteroid_id, data.type_ratios, probability_data, planet)
        }
        if asteroid_size == "chunk" then
          asteroid_definition.type = "asteroid-chunk"
        end
        table.insert(asteroid_spawn_definitions, asteroid_definition)
      end
      if planet ~= nil and asteroid_id and data.type_ratios and probability_data then
        -- if it's specifying a planet, only care about the probability on that planet, not along the whole route
        local planet_probability = asteroid_functions.asteroid_spawn_point(asteroid_id, data.type_ratios, probability_data, planet)[1].probability
        if planet_probability then
          if planet_probability > 0 then
            local asteroid_definition =
            {
              asteroid = asteroid_name,
              probability = planet_probability,
              speed = asteroid_functions.standard_speed,
              angle_when_stopped = asteroid_functions[asteroid_size.."_angle"]
            }
            if asteroid_size == "chunk" then
              asteroid_definition.type = "asteroid-chunk"
            end
            table.insert(asteroid_spawn_definitions, asteroid_definition)
          end
        else
            if planet then
                log("ei more asteroids: invalid planet_probability func call for "..planet)
            else
                log("ei more asteroids: invalid planet_probability func call for unknown planet")
            end
        end
      end
    end
  end

  return asteroid_spawn_definitions
end

return asteroid_functions