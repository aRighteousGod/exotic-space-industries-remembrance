--==============================================================================
-- ESIR FILE MAP
-- owns: late data-final entity presentation registry orchestration
-- loaded_by: exotic-space-industries-remembrance\data-final-fixes.lua
-- cadence: data-final-updates load
-- forwarded_events: entity-presentation-machines, entity-presentation-combat
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: entity presentation registry or Base presentation helper changes
--==============================================================================

local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")

local registry_modules = {
    "scripts/data-final-updates/entity-presentation-machines",
    "scripts/data-final-updates/entity-presentation-combat",
}

local entity_prototype_types = {
    accumulator = true,
    ["agricultural-tower"] = true,
    ["ammo-turret"] = true,
    ["arithmetic-combinator"] = true,
    ["assembling-machine"] = true,
    ["artillery-turret"] = true,
    ["artillery-wagon"] = true,
    asteroid = true,
    ["asteroid-collector"] = true,
    beacon = true,
    boiler = true,
    ["burner-generator"] = true,
    car = true,
    ["cargo-bay"] = true,
    ["cargo-landing-pad"] = true,
    ["cargo-wagon"] = true,
    character = true,
    cliff = true,
    ["combat-robot"] = true,
    ["construction-robot"] = true,
    ["constant-combinator"] = true,
    container = true,
    ["decider-combinator"] = true,
    ["display-panel"] = true,
    ["electric-energy-interface"] = true,
    ["electric-pole"] = true,
    ["electric-turret"] = true,
    ["fluid-turret"] = true,
    ["fluid-wagon"] = true,
    furnace = true,
    ["fusion-generator"] = true,
    ["fusion-reactor"] = true,
    gate = true,
    generator = true,
    ["heat-interface"] = true,
    ["heat-pipe"] = true,
    ["infinity-container"] = true,
    ["infinity-pipe"] = true,
    inserter = true,
    lab = true,
    lamp = true,
    ["land-mine"] = true,
    ["legacy-curved-rail"] = true,
    ["legacy-straight-rail"] = true,
    ["lightning-attractor"] = true,
    ["linked-belt"] = true,
    ["linked-container"] = true,
    loader = true,
    ["loader-1x1"] = true,
    locomotive = true,
    ["logistic-robot"] = true,
    ["logistic-container"] = true,
    market = true,
    ["mining-drill"] = true,
    ["offshore-pump"] = true,
    pipe = true,
    ["pipe-to-ground"] = true,
    plant = true,
    ["power-switch"] = true,
    ["programmable-speaker"] = true,
    pump = true,
    radar = true,
    ["rail-chain-signal"] = true,
    ["rail-ramp"] = true,
    ["rail-signal"] = true,
    ["rail-support"] = true,
    reactor = true,
    resource = true,
    roboport = true,
    ["rocket-silo"] = true,
    ["selector-combinator"] = true,
    ["simple-entity"] = true,
    ["simple-entity-with-force"] = true,
    ["simple-entity-with-owner"] = true,
    ["solar-panel"] = true,
    ["space-platform-hub"] = true,
    ["spider-unit"] = true,
    ["spider-vehicle"] = true,
    splitter = true,
    ["storage-tank"] = true,
    ["straight-rail"] = true,
    thruster = true,
    ["train-stop"] = true,
    ["transport-belt"] = true,
    tree = true,
    turret = true,
    ["underground-belt"] = true,
    unit = true,
    ["unit-spawner"] = true,
    wall = true,
}

local function copy_value(value)
    if type(value) == "table" then
        return table.deepcopy(value)
    end

    return value
end

local function door(open_sound, close_sound)
    return {
        open = open_sound,
        close = close_sound,
    }
end

local sound_presets = {
    machine = door(sounds.machine_open, sounds.machine_close),
    electric_large = door(sounds.electric_large_open, sounds.electric_large_close),
    electric_network = door(sounds.electric_network_open, sounds.electric_network_close),
    drill = door(sounds.drill_open, sounds.drill_close),
    lab = door(sounds.lab_open, sounds.lab_close),
    metallic_chest = door(sounds.metallic_chest_open, sounds.metallic_chest_close),
    metal_small = door(sounds.metal_small_open, sounds.metal_small_close),
    metal_large = door(sounds.metal_large_open, sounds.metal_large_close),
    turret = door(sounds.turret_open, sounds.turret_close),
    reactor = door(sounds.reactor_open, sounds.reactor_close),
    steam = door(sounds.steam_open, sounds.steam_close),
    inserter = door(sounds.inserter_open, sounds.inserter_close),
    transport_belt = door(sounds.transport_belt_open, sounds.transport_belt_close),
    cargo_wagon = door(sounds.cargo_wagon_open, sounds.cargo_wagon_close),
    artillery = door(sounds.artillery_open, sounds.artillery_close),
    combinator = door(sounds.combinator_open, sounds.combinator_close),
    beacon = door(
        {filename = "__base__/sound/open-close/beacon-open.ogg", volume = 0.25},
        {filename = "__base__/sound/open-close/beacon-close.ogg", volume = 0.25}
    ),
    roboport = door(
        {filename = "__base__/sound/open-close/roboport-open.ogg", volume = 0.5},
        {filename = "__base__/sound/open-close/roboport-close.ogg", volume = 0.4}
    ),
    car_door = door(
        {filename = "__base__/sound/car-door-open.ogg", volume = 0.5},
        {filename = "__base__/sound/car-door-close.ogg", volume = 0.4}
    ),
    train_door = door(
        {filename = "__base__/sound/train-door-open.ogg", volume = 0.5},
        {filename = "__base__/sound/train-door-close.ogg", volume = 0.4}
    ),
}

local hit_presets = {
    entity = function() return hit_effects.entity() end,
    rock = function() return hit_effects.rock() end,
    wall = function() return hit_effects.wall() end,
    flying_robot = function() return hit_effects.flying_robot() end,
    biter = function() return hit_effects.biter() end,
}

local function quote(value)
    return string.format("%q", tostring(value))
end

local function number_literal(value, default_value)
    local number = tonumber(value)

    if number == nil then
        number = default_value or 0
    end

    return string.format("%.3f", number)
end

local function position_literal(position, default_position)
    local source = type(position) == "table" and position or default_position or {0, 0}
    local x = source.x or source[1] or 0
    local y = source.y or source[2] or 0

    return "{" .. number_literal(x, 0) .. ", " .. number_literal(y, 0) .. "}"
end

local function direction_literal(direction)
    if direction == nil or direction == false then
        return nil
    end

    if type(direction) == "number" then
        return tostring(direction)
    end

    local direction_name = tostring(direction)
    if direction_name:find("defines%.direction%.") == 1 then
        return direction_name
    end

    return "defines.direction." .. direction_name
end

local function area_points(area, default_area)
    local source = type(area) == "table" and area or default_area or {{-8, -5}, {8, 5}}
    return source.left_top or source[1] or {-8, -5}, source.right_bottom or source[2] or {8, 5}
end

local function append_tile_fill(lines, tile_name, area)
    local left_top, right_bottom = area_points(area)

    lines[#lines + 1] = "for x = " .. number_literal(left_top.x or left_top[1], -8) .. ", " .. number_literal(right_bottom.x or right_bottom[1], 8) .. ", 1 do"
    lines[#lines + 1] = "  for y = " .. number_literal(left_top.y or left_top[2], -5) .. ", " .. number_literal(right_bottom.y or right_bottom[2], 5) .. ", 1 do"
    lines[#lines + 1] = "    surface.set_tiles{{name = " .. quote(tile_name) .. ", position = {x, y}}}"
    lines[#lines + 1] = "  end"
    lines[#lines + 1] = "end"
end

local function append_tile_definition(lines, tile, default_area)
    if type(tile) == "string" then
        append_tile_fill(lines, tile, default_area)
        return
    end

    if type(tile) ~= "table" or type(tile.name) ~= "string" then
        return
    end

    if tile.area then
        append_tile_fill(lines, tile.name, tile.area)
        return
    end

    if type(tile.positions) == "table" then
        for _, position in ipairs(tile.positions) do
            lines[#lines + 1] = "surface.set_tiles{{name = " .. quote(tile.name) .. ", position = " .. position_literal(position) .. "}}"
        end
        return
    end

    lines[#lines + 1] = "surface.set_tiles{{name = " .. quote(tile.name) .. ", position = " .. position_literal(tile.position) .. "}}"
end

local function append_tiles(lines, opts, default_area)
    local tiles = opts.tiles

    if tiles == nil then
        return
    end

    if tiles == false then
        return
    end

    if type(tiles) == "string" then
        return
    end

    if type(tiles) == "table" and tiles.name then
        append_tile_definition(lines, tiles, opts.tile_area or default_area)
        return
    end

    for _, tile in ipairs(tiles) do
        append_tile_definition(lines, tile, opts.tile_area or default_area)
    end
end

local function append_raw_init(lines, init)
    if type(init) ~= "string" or init == "" then
        return
    end

    lines[#lines + 1] = "do"
    for line in init:gmatch("[^\r\n]+") do
        lines[#lines + 1] = "  " .. line
    end
    lines[#lines + 1] = "end"
end

local function append_create_entity(lines, variable_name, spec, default_name, default_position, default_direction, default_force, default_orientation)
    local entity_name = spec.name or default_name
    if not entity_name then
        return
    end

    local args = {
        "name = " .. quote(entity_name),
        "position = " .. position_literal(spec.position, default_position),
    }

    local direction = spec.direction
    if direction == nil then
        direction = default_direction
    end

    local direction_value = direction_literal(direction)
    if direction_value then
        args[#args + 1] = "direction = " .. direction_value
    end

    local orientation = spec.orientation
    if orientation == nil then
        orientation = default_orientation
    end

    if orientation ~= nil and orientation ~= false then
        args[#args + 1] = "orientation = " .. number_literal(orientation, 0)
    end

    local force = spec.force
    if force == nil then
        force = default_force
    end

    if force ~= nil and force ~= false then
        args[#args + 1] = "force = " .. quote(force)
    end

    local prefix = ""
    if variable_name then
        prefix = "local " .. variable_name .. " = "
    end

    lines[#lines + 1] = prefix .. "surface.create_entity{" .. table.concat(args, ", ") .. "}"
end

local function append_entity_inventory_setup(lines, variable_name, opts)
    local function append_insert(item_name, count)
        lines[#lines + 1] = "if " .. variable_name .. " and " .. variable_name .. ".valid then"
        lines[#lines + 1] = "  pcall(function() " .. variable_name .. ".insert{name = " .. quote(item_name) .. ", count = " .. number_literal(count, 50) .. "} end)"
        lines[#lines + 1] = "end"
    end

    local function append_fluid(fluid_name, amount, index, temperature)
        local fluid = "{name = " .. quote(fluid_name) .. ", amount = " .. number_literal(amount, 100)
        if tonumber(temperature) ~= nil then
            fluid = fluid .. ", temperature = " .. number_literal(temperature, 15)
        end
        fluid = fluid .. "}"

        lines[#lines + 1] = "if " .. variable_name .. " and " .. variable_name .. ".valid and " .. variable_name .. ".fluidbox then"
        lines[#lines + 1] = "  pcall(function() " .. variable_name .. ".fluidbox[" .. tostring(tonumber(index) or 1) .. "] = " .. fluid .. " end)"
        lines[#lines + 1] = "end"
    end

    if type(opts.recipe) == "string" then
        lines[#lines + 1] = "if " .. variable_name .. " and " .. variable_name .. ".valid then"
        lines[#lines + 1] = "  pcall(function() " .. variable_name .. ".set_recipe(" .. quote(opts.recipe) .. ") end)"
        lines[#lines + 1] = "end"
    end

    if type(opts.ammo) == "string" then
        append_insert(opts.ammo, opts.ammo_count)
    end

    if type(opts.fluid) == "string" then
        append_fluid(opts.fluid, opts.fluid_amount, opts.fluidbox_index, opts.fluid_temperature)
    end

    if type(opts.items) == "table" then
        for _, item in ipairs(opts.items) do
            if type(item) == "string" then
                append_insert(item, 50)
            elseif type(item) == "table" and type(item.name) == "string" then
                append_insert(item.name, item.count or item.amount or 50)
            end
        end
    end

    if type(opts.fluids) == "table" then
        for index, fluid in ipairs(opts.fluids) do
            if type(fluid) == "string" then
                append_fluid(fluid, 100, index)
            elseif type(fluid) == "table" and type(fluid.name) == "string" then
                append_fluid(fluid.name, fluid.amount or 100, fluid.index or fluid.fluidbox_index or index, fluid.temperature)
            end
        end
    end

    local energy = tonumber(opts.energy)
    if energy == nil and opts.power == true then
        energy = 1000000000
    end

    if energy ~= nil then
        lines[#lines + 1] = "if " .. variable_name .. " and " .. variable_name .. ".valid then"
        lines[#lines + 1] = "  pcall(function() " .. variable_name .. ".energy = " .. number_literal(energy, 0) .. " end)"
        lines[#lines + 1] = "end"
    end

    if opts.active == true then
        lines[#lines + 1] = "if " .. variable_name .. " and " .. variable_name .. ".valid then"
        lines[#lines + 1] = "  pcall(function() " .. variable_name .. ".active = true end)"
        lines[#lines + 1] = "end"
    end
end

local function make_simulation(opts, lines)
    local simulation = {
        init = table.concat(lines, "\n"),
    }
    local init_update_count = opts.init_update_count

    if opts.hide_gradient == true then
        simulation.hide_factoriopedia_gradient = true
    end

    if init_update_count == nil
        and (
            opts.active == true
            or opts.power == true
            or opts.energy ~= nil
            or type(opts.recipe) == "string"
            or type(opts.ammo) == "string"
            or type(opts.fluid) == "string"
            or type(opts.items) == "table"
            or type(opts.fluids) == "table"
        )
    then
        init_update_count = 90
    end

    if init_update_count ~= nil then
        simulation.init_update_count = init_update_count
    end

    return simulation
end

local function make_entity_simulation(name, opts)
    opts = opts or {}

    local default_force = opts.force
    if default_force == nil or default_force == false then
        default_force = "player"
    end

    local lines = {
        "game.simulation.camera_position = " .. position_literal(opts.camera_position, {0, 0}),
        "game.simulation.camera_zoom = " .. number_literal(opts.camera_zoom, 1.35),
        "local surface = game.surfaces[1]",
    }

    if opts.daytime ~= nil then
        lines[#lines + 1] = "surface.daytime = " .. number_literal(opts.daytime, 0.62)
        if opts.freeze_daytime == true then
            lines[#lines + 1] = "surface.freeze_daytime = true"
        end
    end

    append_tiles(lines, opts, opts.tile_area or {{-8, -5}, {8, 5}})
    append_raw_init(lines, opts.init)

    local main_entity_spec = {
        name = name,
        position = opts.position,
        direction = opts.direction,
        force = opts.force,
        orientation = opts.orientation,
    }

    append_create_entity(lines, "main_entity", main_entity_spec, name, {0, 0}, opts.direction == false and false or "south", default_force)
    append_entity_inventory_setup(lines, "main_entity", opts)
    append_raw_init(lines, opts.post_init)

    return make_simulation(opts, lines)
end

local function append_train_consist(lines, name, consist, default_force, rail_y)
    if type(consist) ~= "table" then
        append_create_entity(lines, "rolling_stock", {name = name}, name, {0, rail_y + 2}, nil, default_force, 0.25)
        return
    end

    local count = 0
    for _ in ipairs(consist) do
        count = count + 1
    end

    if count == 0 then
        append_create_entity(lines, "rolling_stock", {name = name}, name, {0, rail_y + 2}, nil, default_force, 0.25)
        return
    end

    local start_x = (count - 1) * -3
    for index, stock in ipairs(consist) do
        local spec = type(stock) == "table" and stock or {name = stock}
        local variable_name = spec.name == name and "rolling_stock" or nil

        append_create_entity(
            lines,
            variable_name,
            spec,
            nil,
            {start_x + ((index - 1) * 6), rail_y + 2},
            nil,
            default_force,
            0.25
        )
    end
end

local function make_train_simulation(name, opts)
    opts = opts or {}

    local rail_y = tonumber(opts.rail_y) or -1
    local default_force = opts.force
    if default_force == nil or default_force == false then
        default_force = "player"
    end

    local rail_opts = type(opts.rails) == "table" and opts.rails or {}
    local rail_length = tonumber(rail_opts.length or opts.rail_length) or 6

    local lines = {
        "game.simulation.camera_position = " .. position_literal(opts.camera_position, {0, 0.5}),
        "game.simulation.camera_zoom = " .. number_literal(opts.camera_zoom, 1.25),
        "local surface = game.surfaces[1]",
    }

    if opts.daytime ~= nil then
        lines[#lines + 1] = "surface.daytime = " .. number_literal(opts.daytime, 0.62)
        if opts.freeze_daytime == true then
            lines[#lines + 1] = "surface.freeze_daytime = true"
        end
    end

    append_tiles(lines, opts, opts.tile_area or {{-10, -4}, {10, 4}})
    append_raw_init(lines, opts.init)
    lines[#lines + 1] = "for x = -" .. number_literal(rail_length, 10) .. ", " .. number_literal(rail_length, 10) .. ", 2 do"
    lines[#lines + 1] = "  surface.create_entity{name = \"straight-rail\", position = {x, " .. number_literal(rail_y, -1) .. "}, direction = defines.direction.east}"
    lines[#lines + 1] = "end"
    append_train_consist(lines, name, nil, default_force, rail_y)

    return make_simulation(opts, lines)
end

local function make_belt_simulation(name, opts)
    opts = opts or {}
    opts.init_update_count = opts.init_update_count or 90

    local belt_name = opts.belt or name
    local default_force = opts.force
    if default_force == nil then
        default_force = "player"
    end

    local lines = {
        "game.simulation.camera_position = " .. position_literal(opts.camera_position, {0, 0}),
        "game.simulation.camera_zoom = " .. number_literal(opts.camera_zoom, 1.6),
        "local surface = game.surfaces[1]",
    }

    if opts.daytime ~= nil then
        lines[#lines + 1] = "surface.daytime = " .. number_literal(opts.daytime, 0.62)
        if opts.freeze_daytime == true then
            lines[#lines + 1] = "surface.freeze_daytime = true"
        end
    end

    append_tiles(lines, opts, opts.tile_area or {{-7, -4}, {7, 4}})
    lines[#lines + 1] = "surface.create_entity{name = " .. quote(belt_name) .. ", position = {0, 0}, direction = defines.direction.east, force = " .. quote(default_force) .. "}"

    return make_simulation(opts, lines)
end

local api = {
    sound = sound_presets,
    hit = hit_presets,
    simulation = {},
}

function api.entity(name, opts)
    opts = opts or {}

    local entry = {
        type = opts.type or opts.prototype_type,
        name = name,
        hit = opts.hit or opts.damaged_trigger_effect,
        sound = opts.sound,
        simulation = opts.simulation or opts.factoriopedia_simulation,
        force = opts.force,
    }

    if opts.open_sound or opts.close_sound then
        entry.sound = entry.sound or {
            open = opts.open_sound,
            close = opts.close_sound,
        }
    end

    return entry
end

api.simulation.entity = make_entity_simulation
api.simulation.train = make_train_simulation
api.simulation.belt = make_belt_simulation

local function has_flag(flags, flag_name)
    if type(flags) ~= "table" then
        return false
    end

    for key, value in pairs(flags) do
        if key == flag_name or value == flag_name then
            return true
        end
    end

    return false
end

local place_result_names

local function has_placeable_item(prototype)
    if prototype.placeable_by ~= nil then
        return true
    end

    if place_result_names == nil then
        place_result_names = {}

        for _, prototypes in pairs(data.raw) do
            if type(prototypes) == "table" then
                for _, candidate in pairs(prototypes) do
                    if type(candidate) == "table" and type(candidate.place_result) == "string" then
                        place_result_names[candidate.place_result] = true
                    end
                end
            end
        end
    end

    return place_result_names[prototype.name] == true
end

local function is_player_facing(prototype)
    if prototype.hidden == true or prototype.hidden_in_factoriopedia == true then
        return false
    end

    if has_flag(prototype.flags, "hidden") or has_flag(prototype.flags, "not-in-factoriopedia") then
        return false
    end

    if prototype.selectable_in_game == false and prototype.factoriopedia_simulation == nil and not has_placeable_item(prototype) then
        return false
    end

    return true
end

local function find_prototype(entry)
    if type(entry.name) ~= "string" then
        return nil
    end

    if type(entry.type) == "string" then
        local prototypes = data.raw[entry.type]
        return prototypes and prototypes[entry.name] or nil
    end

    local found

    for prototype_type in pairs(entity_prototype_types) do
        local prototypes = data.raw[prototype_type]
        local prototype = prototypes and prototypes[entry.name]

        if prototype then
            if found then
                return nil
            end

            found = prototype
        end
    end

    return found
end

local function resolve_value(value, entry, prototype, preset_table, preset_kind)
    if value == nil or value == false then
        return nil
    end

    if type(value) == "string" and preset_table then
        local preset = preset_table[value]

        if preset == nil then
            error("entity-presentation: unknown " .. preset_kind .. " preset '" .. value .. "' for " .. tostring(entry.name))
        end

        value = preset
    end

    if type(value) == "function" then
        value = value(entry, prototype)
    end

    return value
end

local function assign_if_unset(prototype, field_name, value, force)
    if value == nil or value == false then
        return
    end

    if prototype[field_name] ~= nil and not (force and force[field_name] == true) then
        return
    end

    prototype[field_name] = copy_value(value)
end

local function apply_entry(entry)
    if type(entry) ~= "table" then
        return
    end

    local prototype = find_prototype(entry)
    if not prototype or not is_player_facing(prototype) then
        return
    end

    local force = type(entry.force) == "table" and entry.force or nil
    local hit = resolve_value(entry.damaged_trigger_effect or entry.hit, entry, prototype, hit_presets, "hit")
    local simulation = resolve_value(entry.factoriopedia_simulation or entry.simulation, entry, prototype)
    local sound = entry.sound

    if sound == nil and (entry.open_sound or entry.close_sound) then
        sound = {
            open = entry.open_sound,
            close = entry.close_sound,
        }
    end

    sound = resolve_value(sound, entry, prototype, sound_presets, "sound")

    assign_if_unset(prototype, "damaged_trigger_effect", hit, force)

    if type(sound) == "table" then
        assign_if_unset(prototype, "open_sound", sound.open or sound.open_sound or sound[1], force)
        assign_if_unset(prototype, "close_sound", sound.close or sound.close_sound or sound[2], force)
    end

    assign_if_unset(prototype, "factoriopedia_simulation", simulation, force)
end

local function append_entries(target, source, module_path)
    if source == nil then
        return
    end

    if type(source) ~= "table" then
        error("entity-presentation: " .. module_path .. " must return a sequence of entries")
    end

    for index, entry in ipairs(source) do
        if type(entry) ~= "table" then
            error("entity-presentation: entry #" .. tostring(index) .. " from " .. module_path .. " must be a table")
        end

        target[#target + 1] = entry
    end
end

local function is_missing_module_error(message, module_path)
    return (message:find("module '" .. module_path .. "' not found", 1, true) ~= nil)
        or (message:find("module " .. module_path .. " not found", 1, true) ~= nil)
end

local function load_registry(module_path)
    local ok, registry_or_error = pcall(require, module_path)

    if not ok then
        local message = tostring(registry_or_error)

        if is_missing_module_error(message, module_path) then
            return nil
        end

        error(registry_or_error)
    end

    if type(registry_or_error) ~= "function" then
        error("entity-presentation: " .. module_path .. " must return a function(api)")
    end

    return registry_or_error
end

local entries = {}

for _, module_path in ipairs(registry_modules) do
    local registry = load_registry(module_path)

    if registry then
        append_entries(entries, registry(api), module_path)
    end
end

for _, entry in ipairs(entries) do
    apply_entry(entry)
end

return api
