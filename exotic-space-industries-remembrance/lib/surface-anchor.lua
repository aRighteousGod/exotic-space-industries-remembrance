--==============================================================================
-- ESIR FILE MAP
-- owns: shared space-location cache and surface anchor helpers
-- loaded_by: runtime control modules on demand
-- cadence: helper calls only; no top-level events
-- forwarded_events: build_distance_cache, ensure_distance_cache, get_space_location_label, get_surface_anchor, get_surface_universe_position
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: space-location cache schema changes
--==============================================================================

local surface_anchor = {}
local ei_lib = require("lib/lib")
local clamp = ei_lib.clamp

local function lerp(minimum, maximum, ratio)
    return minimum + ((maximum - minimum) * ratio)
end

local function get_space_locations(space_locations)
    if type(space_locations) == "table" then
        return space_locations
    end

    return prototypes and prototypes.space_location or {}
end

function surface_anchor.get_space_location_label(location_name, space_locations)
    local prototype = get_space_locations(space_locations)[location_name]
    if prototype and prototype.localised_name then
        return prototype.localised_name
    end

    return location_name
end

function surface_anchor.build_distance_cache(space_locations)
    local cache = {
        locations = {},
        pair_distance = {},
        max_pair_distance = 1,
    }

    for location_name, prototype in pairs(get_space_locations(space_locations)) do
        local position = prototype.position
        if position and position.x ~= nil and position.y ~= nil then
            cache.locations[location_name] = {
                x = position.x,
                y = position.y,
            }
            cache.pair_distance[location_name] = {}
        end
    end

    for from_name, from_point in pairs(cache.locations) do
        for to_name, to_point in pairs(cache.locations) do
            if cache.pair_distance[from_name][to_name] == nil then
                local dx = from_point.x - to_point.x
                local dy = from_point.y - to_point.y
                local raw_distance = math.sqrt((dx * dx) + (dy * dy))
                cache.pair_distance[from_name][to_name] = raw_distance
                cache.pair_distance[to_name][from_name] = raw_distance
                if raw_distance > cache.max_pair_distance then
                    cache.max_pair_distance = raw_distance
                end
            end
        end
    end

    return cache
end

function surface_anchor.ensure_distance_cache(cache, space_locations)
    if type(cache) ~= "table" or type(cache.locations) ~= "table" or type(cache.pair_distance) ~= "table" then
        cache = surface_anchor.build_distance_cache(space_locations)
    end

    if not cache.max_pair_distance or cache.max_pair_distance <= 0 then
        cache.max_pair_distance = 1
    end

    return cache
end

function surface_anchor.get_surface_universe_position(surface, cache)
    if not surface then
        return nil
    end

    cache = surface_anchor.ensure_distance_cache(cache)

    local platform = surface.platform
    if platform and platform.valid then
        local connection = platform.space_connection
        if connection and connection.valid then
            local from_name = connection.from and connection.from.name
            local to_name = connection.to and connection.to.name
            local from_point = from_name and cache.locations[from_name]
            local to_point = to_name and cache.locations[to_name]
            local route_length = tonumber(connection.length) or 0
            local route_distance = tonumber(platform.distance)

            if from_point and to_point and route_length > 0 and route_distance then
                local progress = clamp(route_distance / route_length, 0, 1)
                return {
                    x = lerp(from_point.x, to_point.x, progress),
                    y = lerp(from_point.y, to_point.y, progress),
                    location_name = nil,
                    from_location_name = from_name,
                    to_location_name = to_name,
                }
            end
        end

        local current_location = platform.space_location
        if current_location and cache.locations[current_location.name] then
            local point = cache.locations[current_location.name]
            return {
                x = point.x,
                y = point.y,
                location_name = current_location.name,
            }
        end

        local last_location = platform.last_visited_space_location
        if last_location and cache.locations[last_location.name] then
            local point = cache.locations[last_location.name]
            return {
                x = point.x,
                y = point.y,
                location_name = last_location.name,
            }
        end
    end

    local planet = surface.planet
    if planet and planet.valid and cache.locations[planet.name] then
        local point = cache.locations[planet.name]
        return {
            x = point.x,
            y = point.y,
            location_name = planet.name,
        }
    end

    if cache.locations[surface.name] then
        local point = cache.locations[surface.name]
        return {
            x = point.x,
            y = point.y,
            location_name = surface.name,
        }
    end

    return nil
end

function surface_anchor.get_surface_anchor(surface, cache, space_locations)
    local anchor = surface_anchor.get_surface_universe_position(surface, cache)
    if not anchor then
        return nil
    end

    if anchor.location_name then
        anchor.label = surface_anchor.get_space_location_label(anchor.location_name, space_locations)
        return anchor
    end

    if anchor.from_location_name and anchor.to_location_name then
        anchor.label = {
            "",
            surface_anchor.get_space_location_label(anchor.from_location_name, space_locations),
            " -> ",
            surface_anchor.get_space_location_label(anchor.to_location_name, space_locations),
        }
    end

    return anchor
end

return surface_anchor
