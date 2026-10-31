-- Runs unchanged on the preserved 2.0 donor and the current 2.1 migration target.
local modern = script.active_mods.base:sub(1, 3) == "2.1"
local config = require("legacy-config")
local recipes = require("recipes")
local cases = require("legacy-cases")
local reload_pending = false

---@param entity LuaEntity
local function snapshot(entity)
    local state = {direction = entity.direction, mirrored = entity.mirroring, ports = {}, fluids = {}}
    local count = modern and entity.fluids_count or #entity.fluidbox
    for i = 1, count do
        local fluid, filter, ports
        if modern then
            fluid, filter, ports = entity.get_fluid(i), entity.get_fluid_filter(i), entity.get_fluid_box_pipe_connections(i)
        else
            fluid, filter, ports = entity.fluidbox[i], entity.fluidbox.get_filter(i), entity.fluidbox.get_pipe_connections(i)
        end
        local name = fluid and fluid.name or (filter and filter.name) or ""
        if fluid then
            local key = fluid.name .. "/" .. string.format("%.4f", fluid.temperature)
            state.fluids[key] = (state.fluids[key] or 0) + fluid.amount
        end
        for _, port in ipairs(ports or {}) do
            state.ports[#state.ports + 1] = {name = name, flow = port.flow_direction,
                x = port.position.x - entity.position.x, y = port.position.y - entity.position.y,
                tx = port.target_position.x - entity.position.x, ty = port.target_position.y - entity.position.y}
        end
    end
    table.sort(state.ports, function(a, b)
        return (a.name .. "/" .. a.flow .. "/" .. a.x .. "/" .. a.y .. "/" .. a.tx .. "/" .. a.ty)
            < (b.name .. "/" .. b.flow .. "/" .. b.x .. "/" .. b.y .. "/" .. b.tx .. "/" .. b.ty)
    end)
    if entity.type == "inserter" then
        state.pickup = {x = entity.pickup_position.x - entity.position.x, y = entity.pickup_position.y - entity.position.y}
        state.drop = {x = entity.drop_position.x - entity.position.x, y = entity.drop_position.y - entity.position.y}
    elseif entity.type == "mining-drill" then
        state.drop = {x = entity.drop_position.x - entity.position.x, y = entity.drop_position.y - entity.position.y}
    end
    return state
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) == "number" then return math.abs(a - b) < 0.001 end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function inspect(phase)
    local report = {engine = script.active_mods.base, passed = true, cases = {}}
    for _, row in ipairs(storage.records) do
        local actual = row.entity.valid and snapshot(row.entity) or {}
        -- Pumpjack migration may change numeric direction/mirroring while preserving geometry.
        local passed = same(row.before.ports, actual.ports) and same(row.before.fluids, actual.fluids)
            and same(row.before.pickup, actual.pickup) and same(row.before.drop, actual.drop)
        report.passed = report.passed and passed
        report.cases[#report.cases + 1] = {name = row.name, requested_direction = row.direction,
            requested_mirror = row.mirror, before = row.before, after = actual, passed = passed}
    end
    helpers.write_file("mirroring/legacy-" .. phase .. ".json", helpers.table_to_json(report), false)
end

script.on_init(function()
    assert(not modern, "Create the historical donor with actual 2.0.77 and preserved 1.3.41 source")
    assert(script.active_mods.base == "2.0.77")
    storage.records = {}
    local surface = game.create_surface("mirroring-legacy", {width = 1024, height = 1024,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 11)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    for _, recipe in pairs(game.forces.player.recipes) do recipe.enabled = true end
    for _, name in ipairs(cases) do
        assert(prototypes.entity[name], "Missing historical prototype: " .. name)
        for _, direction in ipairs{0, 4, 8, 12} do
            for _, mirror in ipairs{false, true} do
                local i = #storage.records
                local entity = assert(surface.create_entity{name = name, position = {(i % 18) * 32 - 272, math.floor(i / 18) * 32 - 304},
                    direction = direction, force = "player"})
                if recipes[name] and prototypes.recipe[recipes[name]] then entity.set_recipe(recipes[name]) end
                entity.mirroring = mirror
                entity.active = false
                for box = 1, #entity.fluidbox do
                    local filter = entity.fluidbox.get_filter(box)
                    local fluid_name = entity.fluidbox.get_locked_fluid(box) or (filter and filter.name)
                    if fluid_name then
                        local fluid = prototypes.fluid[fluid_name]
                        entity.fluidbox[box] = {name = fluid_name, amount = math.min(10, entity.fluidbox.get_capacity(box) / 4),
                            temperature = math.min(fluid.max_temperature, fluid.default_temperature + 5)}
                    end
                end
                storage.records[#storage.records + 1] = {entity = entity, name = name, direction = direction, mirror = mirror, before = snapshot(entity)}
            end
        end
    end
    inspect("donor")
end)

script.on_configuration_changed(function()
    if modern then
        inspect(config.phase)
        storage.save_pending = config.phase == "adopt"
    end
end)
script.on_load(function() reload_pending = true end)
script.on_event(defines.events.on_tick, function()
    if not modern then return end
    if reload_pending then inspect(config.phase); reload_pending = false end
    if storage.save_pending then
        storage.save_pending = false
        game.auto_save("mirroring-migrated")
    end
end)
