-- Native acceptance fixture. Production prototypes and runtime handlers stay loaded.
local config = require("test-config")
local deepcopy = require("util").table.deepcopy
local transport = require("transport")
local heat = require("heat")
local furnaces = require("furnaces")
local candidates = {}
for _, name in ipairs(require("cases")) do candidates[name] = true end
local directions = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}

---@param condition boolean
---@param message string
local function check(condition, message)
    storage.report.counts.assertions = storage.report.counts.assertions + 1
    if not condition then storage.report.failures[#storage.report.failures + 1] = message end
end

---@param entity LuaEntity
---@return table
local function snapshot(entity)
    local result = {direction = entity.direction, mirrored = entity.mirroring, fluids = {}, ports = {}}
    for i = 1, entity.fluids_count do
        result.fluids[i] = entity.get_fluid(i) or false
        result.ports[i] = {}
        for _, port in ipairs(entity.get_fluid_box_pipe_connections(i) or {}) do
            result.ports[i][#result.ports[i] + 1] = {
                x = port.position.x - entity.position.x, y = port.position.y - entity.position.y,
                tx = port.target_position.x - entity.position.x, ty = port.target_position.y - entity.position.y,
                flow = port.flow_direction,
            }
        end
    end
    if entity.type == "inserter" then
        result.pickup = {x = entity.pickup_position.x - entity.position.x, y = entity.pickup_position.y - entity.position.y}
        result.drop = {x = entity.drop_position.x - entity.position.x, y = entity.drop_position.y - entity.position.y}
    elseif entity.type == "mining-drill" then
        result.drop = {x = entity.drop_position.x - entity.position.x, y = entity.drop_position.y - entity.position.y}
    end
    return result
end

---@param left any
---@param right any
---@return boolean
local function same(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) == "number" then return math.abs(left - right) < 0.0001 end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not same(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

---@param entity LuaEntity
---@param before table
---@param after table
---@param horizontal boolean
---@param label string
local function reflected(entity, before, after, horizontal, label)
    check(same(before.fluids, after.fluids), label .. ": fluids conserved by storage index")
    local expected = deepcopy(before)
    for _, ports in pairs(expected.ports) do
        for _, port in ipairs(ports) do
            if horizontal then port.x, port.tx = -port.x, -port.tx else port.y, port.ty = -port.y, -port.ty end
        end
    end
    -- Opted-in entities preserve each fluid-box identity, not merely aggregate ports.
    if candidates[entity.name] or entity.type == "mining-drill" or entity.type == "inserter" then
        check(same(expected.ports, after.ports), label .. ": reflected indexed ports")
    end
    for _, key in ipairs{"pickup", "drop"} do
        if expected[key] then
            expected[key][horizontal and "x" or "y"] = -expected[key][horizontal and "x" or "y"]
            check(same(expected[key], after[key]), label .. ": reflected " .. key)
        end
    end
end

---@param surface LuaSurface
---@param name string
---@param position MapPosition
---@param direction defines.direction
---@return LuaEntity
local function create(surface, name, position, direction)
    return assert(surface.create_entity{name = name, position = position, direction = direction,
        force = "player", create_build_effect_smoke = false}, "create " .. name)
end

---@param entity LuaEntity
---@return string|nil
local function fluid_recipe(entity)
    if entity.type ~= "assembling-machine" then return nil end
    local choices = {}
    for name, recipe in pairs(prototypes.recipe) do
        local allowed = false
        for _, category in pairs(recipe.categories) do
            if entity.prototype.crafting_categories[category] then allowed = true end
        end
        if allowed then
            local score = 0
            for _, part in pairs(recipe.ingredients) do if part.type == "fluid" then score = score + 10 end end
            for _, part in pairs(recipe.products) do if part.type == "fluid" then score = score + 11 end end
            if score > 0 then choices[#choices + 1] = {name = name, score = score} end
        end
    end
    table.sort(choices, function(a, b) return a.score > b.score or (a.score == b.score and a.name < b.name) end)
    for _, choice in ipairs(choices) do
        local ok = pcall(entity.set_recipe, choice.name)
        local recipe = entity.get_recipe()
        if ok and recipe and recipe.name == choice.name then return choice.name end
    end
end

---@param entity LuaEntity
local function fill(entity)
    for i = 1, entity.fluids_count do
        local filter = entity.get_fluid_filter(i)
        local name = filter and filter.name or "water"
        local prototype = prototypes.fluid[name]
        local temperature = math.min(prototype.max_temperature, prototype.default_temperature + 5)
        entity.set_fluid(i, {name = name, amount = 11 + i, temperature = temperature})
    end
    entity.disabled_by_script = true
end

---@param surface LuaSurface
---@param entity LuaEntity
---@param horizontal boolean
---@param label string
---@param keep boolean|nil
local function incompatible_connection(surface, entity, horizontal, label, keep)
    local state = snapshot(entity)
    for index, ports in ipairs(state.ports) do
        local incoming = state.fluids[index]
        if incoming then
            for _, port in ipairs(ports) do
                local tx, ty = horizontal and -port.tx or port.tx, horizontal and port.ty or -port.ty
                local existing
                for old_index, old_ports in ipairs(state.ports) do
                    for _, old in ipairs(old_ports) do
                        if old.tx == tx and old.ty == ty then existing = state.fluids[old_index] end
                    end
                end
                local wrong = existing and existing.name or (incoming.name == "water" and "petroleum-gas" or "water")
                local position = {entity.position.x + tx, entity.position.y + ty}
                if wrong ~= incoming.name and surface.can_place_entity{name = "pipe", position = position, force = "player"} then
                    local pipe = create(surface, "pipe", position, defines.direction.north)
                    pipe.set_fluid(1, {name = wrong, amount = 17})
                    local actual = pipe.get_fluid(1)
                    if actual and actual.name == wrong then
                        local before, pipe_before = snapshot(entity), pipe.get_fluid(1)
                        local success = entity.flip{horizontal = horizontal}
                        local after, pipe_after = snapshot(entity), pipe.get_fluid(1)
                        storage.report.connections[#storage.report.connections + 1] = {
                            label = label, success = success, before = before, after = after,
                            pipe_before = pipe_before, pipe_after = pipe_after,
                        }
                        if not success then
                            check(same(before, after) and same(pipe_before, pipe_after),
                                label .. ": rejected connected flip preserves state")
                        else
                            -- Geometric adjacency is not permission to transfer a different fluid.
                            check(pipe_after and pipe_after.name == wrong, label .. ": conflicting pipe retains its fluid")
                            check(same(before.fluids, after.fluids) and same(pipe_before, pipe_after),
                                label .. ": connected flip conserves fluid amounts and temperatures")
                            for box = 1, entity.fluids_count do
                                local fluid = entity.get_fluid(box)
                                check(not before.fluids[box] or (fluid and fluid.name == before.fluids[box].name),
                                    label .. ": connected flip retains fluid identities")
                            end
                        end
                        storage.report.counts.conflicts = storage.report.counts.conflicts + 1
                        if keep and success then
                            storage.connected[#storage.connected + 1] = {entity = entity, pipe = pipe, state = after, pipe_state = pipe_after}
                            return
                        end
                        if success then entity.flip{horizontal = horizontal} end
                        pipe.destroy()
                        return
                    end
                    pipe.destroy()
                end
            end
        end
    end
end

---@param surface LuaSurface
---@param entity LuaEntity
---@param label string
local function blueprint_roundtrip(surface, entity, label)
    local recipe = entity.get_recipe()
    local properties = {}
    for _, conditions in ipairs{entity.prototype.surface_conditions or {},
        recipe and prototypes.recipe[recipe.name].surface_conditions or {}} do
        for _, condition in ipairs(conditions) do
            if properties[condition.property] == nil then properties[condition.property] = surface.get_property(condition.property) end
            surface.set_property(condition.property, condition.min or condition.max or properties[condition.property])
        end
    end
    local inventory = game.create_inventory(1)
    inventory[1].set_stack{name = "blueprint", count = 1}
    local stack = inventory[1]
    stack.create_blueprint{surface = surface, force = "player", area = entity.bounding_box}
    local definitions = stack.get_blueprint_entities() or {}
    check(#definitions == 1, label .. ": one captured blueprint entity")
    local ghosts = stack.build_blueprint{surface = surface, force = "player", position = {50, 0},
        build_mode = defines.build_mode.forced, skip_fog_of_war = false}
    check(#ghosts == 1, label .. ": mirrored blueprint placed")
    for _, ghost in ipairs(ghosts) do
        local _, revived = ghost.revive{}
        check(revived ~= nil, label .. ": ghost revived")
        if revived then
            check(revived.direction == entity.direction and revived.mirroring == entity.mirroring,
                label .. ": blueprint orientation preserved")
            revived.copy_settings(entity)
            local recipe, copied = entity.get_recipe(), revived.get_recipe()
            check((recipe and recipe.name) == (copied and copied.name), label .. ": recipe copy/paste")
            local left, right = snapshot(entity), snapshot(revived)
            check(same(left.ports, right.ports), label .. ": blueprint ports preserved")
            revived.destroy()
        elseif ghost.valid then ghost.destroy() end
    end
    inventory.destroy()
    for property, value in pairs(properties) do surface.set_property(property, value) end
    storage.report.counts.blueprints = storage.report.counts.blueprints + 1
end

local function write_receipt(suffix)
    storage.report.passed = #storage.report.failures == 0
    helpers.write_file("mirroring/" .. config.tag .. "-" .. suffix .. ".json", helpers.table_to_json(storage.report), false)
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay", "set_skip_intro", true)
        remote.call("freeplay", "set_disable_crashsite", true)
    end
    storage.report = {mode = config.mode, engine = script.active_mods.base, quality = script.active_mods.quality ~= nil,
        counts = {assertions = 0, empty = 0, loaded = 0, blueprints = 0, reload = 0, conflicts = 0},
        failures = {}, entities = {}, connections = {}}
    storage.persisted = {}
    storage.connected = {}
    for _, recipe in pairs(game.forces.player.recipes) do recipe.enabled = true end
    local data = prototypes.mod_data["mirroring-qc"].data
    helpers.write_file("mirroring/" .. config.tag .. "-final.json", helpers.table_to_json(data), false)
    local surface = game.create_surface("mirroring-qc", {width = 1024, height = 1024,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 8)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -120, 220 do for y = -100, 220 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    surface.always_day = true
    if config.mode == "candidate" then
        surface.request_to_generate_chunks({-250, -150}, 4)
        surface.force_generate_chunk_requests()
        local floor = {}
        for x = -320, -140 do for y = -220, -60 do floor[#floor + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(floor)
        transport.setup(surface)
        heat.setup(fluid_recipe)
        furnaces.setup()
        surface.request_to_generate_chunks({0, -280}, 3)
        surface.force_generate_chunk_requests()
        local connected_floor = {}
        for x = -100, 100 do for y = -340, -180 do connected_floor[#connected_floor + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(connected_floor)
    end
    local names = {}
    for name in pairs(data.entities) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local prototype = prototypes.entity[name]
        local row = {name = name, type = prototype.type, allows_flipping = prototype.allows_flipping, cases = {}}
        storage.report.entities[#storage.report.entities + 1] = row
        if candidates[name] then check(row.allows_flipping == (config.mode == "candidate"), name .. ": eligibility") end
        for _, direction in ipairs(directions) do
            for _, horizontal in ipairs{true, false} do
                for _, loaded in ipairs{false, true} do
                    local entity = create(surface, name, {0, 0}, direction)
                    local recipe
                    if loaded then recipe = fluid_recipe(entity) end
                    if not loaded or recipe or entity.type == "mining-drill" or entity.type == "inserter" then
                        if loaded then fill(entity) end
                        local label = name .. "/" .. direction .. "/" .. tostring(horizontal) .. "/" .. tostring(loaded)
                        if loaded and candidates[name] and config.mode == "candidate" then
                            incompatible_connection(surface, entity, horizontal, label)
                        end
                        local before = snapshot(entity)
                        local success = entity.flip{horizontal = horizontal}
                        local after = snapshot(entity)
                        if candidates[name] then
                            -- With no active fluid ports, native flip may be a no-op even with eligible blueprints.
                            check(success == (config.mode == "candidate") or
                                (config.mode == "candidate" and not loaded and entity.fluids_count == 0), label .. ": flip result")
                        elseif entity.type == "inserter" or entity.type == "mining-drill" then check(success, label .. ": native control flip") end
                        if success then
                            reflected(entity, before, after, horizontal, label)
                            if candidates[name] and loaded then blueprint_roundtrip(surface, entity, label) end
                            check(entity.flip{horizontal = horizontal}, label .. ": second flip")
                            local restored = snapshot(entity)
                            if candidates[name] or entity.type == "inserter" or entity.type == "mining-drill" then
                                check(same(before, restored), label .. ": double flip restores state")
                            else check(same(before.fluids, restored.fluids), label .. ": native symmetry conserves fluid") end
                        else check(same(before, after), label .. ": rejected flip preserves state") end
                        row.cases[#row.cases + 1] = {direction = direction, horizontal = horizontal, loaded = loaded,
                            recipe = recipe, success = success, before = before, after = after}
                        local key = loaded and "loaded" or "empty"
                        storage.report.counts[key] = storage.report.counts[key] + 1
                    end
                    entity.destroy()
                end
            end
        end
        if candidates[name] and config.mode == "candidate" then
            local i = #storage.persisted
            local entity = create(surface, name, {40 * (i % 5) - 80, 40 * math.floor(i / 5) + 60}, defines.direction.north)
            local recipe = fluid_recipe(entity)
            fill(entity)
            check(entity.flip{horizontal = true}, name .. ": persisted mirror")
            storage.persisted[#storage.persisted + 1] = {entity = entity, state = snapshot(entity), recipe = recipe}
            local connected = create(surface, name, {40 * (i % 5) - 80, 40 * math.floor(i / 5) - 320}, defines.direction.north)
            fluid_recipe(connected)
            fill(connected)
            incompatible_connection(surface, connected, true, name .. "/connected-persistence", true)
        end
    end
    write_receipt("init")
end)

script.on_event(defines.events.on_tick, function(event)
    if storage.transport then transport.tick(event.tick) end
    if storage.heat then heat.tick(event.tick) end
    if storage.furnaces then furnaces.tick(event.tick, snapshot, same) end
    if event.tick == 600 then
        for _, record in ipairs(storage.connected) do
            check(same(record.state.fluids, snapshot(record.entity).fluids) and same(record.pipe_state, record.pipe.get_fluid(1)),
                record.entity.name .. ": incompatible fluids stay separate after 600 ticks")
        end
        storage.report.counts.connected_persistence = #storage.connected
        write_receipt("reload")
    end
    if storage.checked_reload then return end
    storage.checked_reload = true
    for _, record in ipairs(storage.persisted) do
        check(record.entity.valid and same(record.state, snapshot(record.entity)), record.entity.name .. ": saved state")
        storage.report.counts.reload = storage.report.counts.reload + 1
    end
    write_receipt("reload")
end)
