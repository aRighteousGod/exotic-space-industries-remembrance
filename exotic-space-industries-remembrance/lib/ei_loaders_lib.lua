local ei_loaders_lib = {}

--====================================================================================================
--DATA VALUES
--====================================================================================================

-- for building handler
---------------------------------------------------------
local loaders = {
    ["ei-loader"] = true,
    ["ei-fast-loader"] = true,
    ["ei-express-loader"] = true,
    ["ei-turbo-loader"] = true,
    ["ei-neo-loader"] = true,
}

local belts = {
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
}

-- for utility functions
---------------------------------------------------------
local belt_like = {
    "transport-belt",
    "splitter",
    "underground-belt",
    "loader-1x1", 
    "loader-1x2",
}

local container_like = {
    "container",
    "logistic-container",
    "linked-container",
    "assembling-machine",
    "furnace",
    "lab",
    "rocket-silo",
    "reactor",
    "boiler",
    "fusion-reactor",
    "asteroid-collector",
    "ammo-turret",
    "agricultural-tower",
    "mining-drill",
}

local loader_like = {
    "ei-loader",
    "ei-fast-loader",
    "ei-express-loader",
    "ei-turbo-loader",
    "ei-neo-loader",
}

--====================================================================================================
--UTIL FUNCTIONS
--====================================================================================================

function ei_loaders_lib.flip_direction(direction)
    if direction == defines.direction.north then
        return defines.direction.south
    elseif direction == defines.direction.south then
        return defines.direction.north
    elseif direction == defines.direction.east then
        return defines.direction.west
    elseif direction == defines.direction.west then
        return defines.direction.east
    end
end


function ei_loaders_lib.get_splitter_positions(splitter, input_pos, output_pos)
    local new_input_pos = nil
    local new_output_pos = nil
    local new_input_pos2 = nil
    local new_output_pos2 = nil
    
    if splitter.direction == defines.direction.north then
        new_input_pos = {x = input_pos.x + 0.5, y = input_pos.y}
        new_output_pos = {x = output_pos.x + 0.5, y = output_pos.y}

        new_input_pos2 = {x = input_pos.x - 0.5, y = input_pos.y}
        new_output_pos2 = {x = output_pos.x - 0.5, y = output_pos.y}
    elseif splitter.direction == defines.direction.east then
        new_input_pos = {x = input_pos.x, y = input_pos.y - 0.5}
        new_output_pos = {x = output_pos.x, y = output_pos.y - 0.5}

        new_input_pos2 = {x = input_pos.x, y = input_pos.y + 0.5}
        new_output_pos2 = {x = output_pos.x, y = output_pos.y + 0.5}
    elseif splitter.direction == defines.direction.south then
        new_input_pos = {x = input_pos.x - 0.5, y = input_pos.y}
        new_output_pos = {x = output_pos.x - 0.5, y = output_pos.y}

        new_input_pos2 = {x = input_pos.x + 0.5, y = input_pos.y}
        new_output_pos2 = {x = output_pos.x + 0.5, y = output_pos.y}
    elseif splitter.direction == defines.direction.west then
        new_input_pos = {x = input_pos.x, y = input_pos.y + 0.5}
        new_output_pos = {x = output_pos.x, y = output_pos.y + 0.5}

        new_input_pos2 = {x = input_pos.x, y = input_pos.y - 0.5}
        new_output_pos2 = {x = output_pos.x, y = output_pos.y - 0.5}
    end

    return new_input_pos, new_output_pos, new_input_pos2, new_output_pos2
end


function ei_loaders_lib.get_positions(entity)
    -- get the position of the entity and the direction it is facing
    -- return output and input position

    -- input [->] output

    -- or

    -- input
    -- [V]
    -- output

    -- factorio positions:
    -- | -y
    -- |
    -- ------> +x

    local output = entity.position
    local input = entity.position
    local direction = entity.direction

    if direction == defines.direction.north then
        output.y = output.y - 1
        input.y = input.y + 1
    elseif direction == defines.direction.east then
        output.x = output.x + 1
        input.x = input.x - 1
    elseif direction == defines.direction.south then
        output.y = output.y + 1
        input.y = input.y - 1
    elseif direction == defines.direction.west then
        output.x = output.x - 1
        input.x = input.x + 1
    end

    return output, input
end


function ei_loaders_lib.flip_loader_type(loader)
    if loader.loader_type == "input" then
        loader.loader_type = "output"
    elseif loader.loader_type == "output" then
        loader.loader_type = "input"
    end
end


--====================================================================================================
--SNAPPING LOGIC
--====================================================================================================


function ei_loaders_lib.snap_input(loader, mode)
    -- check for belt like and container like
    local output_pos, input_pos = ei_loaders_lib.get_positions(loader)

    if mode == "container_like" then
        -- for container like
        local container_like = loader.surface.find_entities_filtered{
            position = output_pos,
            type = container_like,
            force = loader.force,
        }

        if #container_like > 0 then
            -- is the belt part of the loader facing the container?
            local loader_type = loader.loader_type

            -- output is default loader type
            if loader_type == "output" then
                -- here the belt part of the loader is always facing to the container
                -- like, therfore we need to flip the entire loader
                loader.direction = ei_loaders_lib.flip_direction(loader.direction)
            end
        end
    end
    
    if mode == "belt_like" then
        -- for belt like
        local belt_like = loader.surface.find_entities_filtered{
            position = output_pos,
            type = belt_like,
            force = loader.force,
        }

        if #belt_like > 0 then
            if not belt_like[1].valid then
                return
            end

            -- get  direction of loader and belt_like
            local belt_direction = belt_like[1].direction
            local loader_direction = loader.direction

            -- only need to flip loader if loader type is wrong way
            if belt_direction == ei_loaders_lib.flip_direction(loader_direction) then
                ei_loaders_lib.flip_loader_type(loader)
            end
        end
    end
end


function ei_loaders_lib.call_snap_input(belt, pos)
    local loader = belt.surface.find_entities_filtered{
        position = pos,
        name = loader_like,
        force = belt.force,
    }

    if #loader > 0 then
        loader[1].loader_type = "output"
        ei_loaders_lib.snap_input(loader[1], "belt_like")
    end
end


--====================================================================================================
--SNAPPERS AND HANDLER
--====================================================================================================

-- building handler
---------------------------------------------------------
function ei_loaders_lib.on_built_entity(e)
    if not e then return end
    if not e.valid then return end

    -- if entity is a loader
    if loaders[e.name] then
        ei_loaders_lib.snap_loader(e)
    end

    -- if entity is a belt
    if belts[e.type] then
        ei_loaders_lib.snap_belt(e)
    end

end

-- snapping functions
---------------------------------------------------------
function ei_loaders_lib.snap_loader(loader)
    if not loader.valid then
        return
    end

    -- snap loader to belt or conatiner like entities

    -- treat input position
    ei_loaders_lib.snap_input(loader, "container_like")
    ei_loaders_lib.snap_input(loader, "belt_like")
end


function ei_loaders_lib.snap_belt(belt)
    if not belt.valid then
        return
    end

    -- get top and down position of the belt
    local output_pos, input_pos = ei_loaders_lib.get_positions(belt)

    -- if splitter offset by 0.5 in the direction it is facing
    if belt.type == "splitter" then
        input_pos, output_pos, input_pos2, output_pos2 = ei_loaders_lib.get_splitter_positions(belt, input_pos, output_pos)

        ei_loaders_lib.call_snap_input(belt, input_pos2)
        ei_loaders_lib.call_snap_input(belt, output_pos2)
    end

    -- if there is a loader on these positions snap it
    ei_loaders_lib.call_snap_input(belt, input_pos)
    ei_loaders_lib.call_snap_input(belt, output_pos)
end

function ei_loaders_lib.addEnergyDraw(loader, energy_per_item, energy_buffer, burner)
    if not burner then
        loader.energy_source = {
            type = "electric",
            buffer_capacity = tostring(energy_buffer) .. "J",
            usage_priority = "secondary-input",
            drain = "2kW",
        }
        loader.energy_per_item = tostring(energy_per_item) .. "J"
    elseif burner then --unsupported
        loader.energy_source = {
        type = "burner",
        fuel_categories = {"chemical"},  -- or "biomass", "nuclear", etc. if supported
        effectivity = 1,
        fuel_inventory_size = 1,
        }

        loader.energy_source.emissions_per_minute = {pollution = 5}

        local smoking = {
            name = "smoke",
            deviation = {0.1, 0.1},
            frequency = 5,
            position = {0.0, -0.8},
            starting_vertical_speed = 0.08,
            starting_frame_deviation = 60
            }
        loader.working_visualisations = smoking

        loader.energy_usage = (energy_per_item * 60) .. "kW"
    else
        log("ei_loaders_lib.addEnergyDraw: Invalid loader type. Must be electric or burner.")
    end

end


return ei_loaders_lib