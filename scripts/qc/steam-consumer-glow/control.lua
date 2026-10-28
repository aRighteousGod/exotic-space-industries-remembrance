-- Isolated native fixture: no ESIR runtime changes, all timing from callback ticks.
local config = require("test-config")
local cases = require("cases")
local statuses = {}
local modern = script.active_mods.base:sub(1, 3) == "2.1"
for name, value in pairs(defines.entity_status) do statuses[value] = name end
local function drain(entity, name, amount)
    if not modern then return entity.remove_fluid{name=name,amount=amount} end
    local removed=0
    for index=1,entity.fluids_count do
        local fluid=entity.get_fluid(index)
        if fluid and fluid.name==name then
            local taken=entity.remove_fluid(index,amount-removed)
            removed=removed+(taken and taken.amount or 0)
        end
        if removed>=amount then break end
    end
    return removed
end

---@param surface LuaSurface
---@param name string
---@param position MapPosition
---@param direction defines.direction|nil
---@return LuaEntity
local function create(surface, name, position, direction)
    return assert(surface.create_entity{name = name, position = position, direction = direction,
        force = "player", create_build_effect_smoke = false}, name)
end

script.on_init(function()
    -- A graphical player is created before the first simulation tick. Set these
    -- before saving the fixture so freeplay cannot pause it in the intro dialog.
    if remote.interfaces.freeplay then
        remote.call("freeplay", "set_skip_intro", true)
        remote.call("freeplay", "set_disable_crashsite", true)
    end
    storage.start_tick, storage.rows = game.tick, {}
    helpers.write_file("steam-glow/" .. config.mode .. "-final.json",
        helpers.table_to_json(prototypes.mod_data["steam-glow-qc"].data), false)
    for index, name in ipairs(cases) do
        local surface = game.create_surface("steam-glow-" .. index, {width = 64, height = 64,
            autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
        surface.request_to_generate_chunks({0, 0}, 2)
        surface.force_generate_chunk_requests()
        for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
        surface.destroy_decoratives{}
        local tiles = {}
        for x = -30, 30 do for y = -30, 30 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(tiles)
        surface.always_day, surface.daytime, surface.freeze_daytime = false, 0.5, true
        for _, state in ipairs{"working", "starved"} do
            local x = state == "working" and -10 or 10
            if name == "ei-steam-offshore-pump" then
                local water = {}
                for dx = -3, 3 do for y = -5, -1 do water[#water + 1] = {name = "water", position = {x + dx, y}} end end
                surface.set_tiles(water)
            elseif name == "ei-steam-miner" or name == "ei-steam-quarry" then
                for dx = -2, 2 do for dy = -2, 2 do
                    surface.create_entity{name = "iron-ore", position = {x + dx, dy}, amount = 100000}
                end end
            elseif name == "ei-steam-oil-pumpjack" then
                surface.create_entity{name = "crude-oil", position = {x, 0}, amount = 100000}
            end
            local entity = create(surface, name, {x, 0}, name == "ei-steam-loader" and defines.direction.east or defines.direction.north)
            local row = {entity = entity, name = name, state = state, activity = 0, previous = 0, statuses = {}}
            for i = 1, modern and entity.fluids_count or #entity.fluidbox do
                local filter
                if modern then filter=entity.get_fluid_filter(i) else filter=entity.fluidbox.get_filter(i) end
                if filter and filter.name == "steam" then row.steam_box = i end
            end
            assert(row.steam_box, "Steam energy fluid box: " .. name)
            if entity.type == "offshore-pump" then
                row.fluid_output = create(surface, "pipe", {entity.position.x, entity.position.y + 1})
            end
            if entity.type == "assembling-machine" then
                entity.set_recipe("steam-glow-qc")
            elseif entity.type == "inserter" then
                row.input = create(surface, "steel-chest", entity.pickup_position)
                row.output = create(surface, "steel-chest", entity.drop_position)
            elseif entity.type == "mining-drill" and name ~= "ei-steam-oil-pumpjack" then
                row.output = create(surface, "steel-chest", entity.drop_position)
            elseif entity.type == "loader-1x1" then
                entity.loader_type = "output"
                row.input = create(surface, "steel-chest", {x - 1, 0})
                row.belt = create(surface, "transport-belt", {x + 1, 0}, defines.direction.east)
            end
            storage.rows[#storage.rows + 1] = row
        end
    end
end)

---@param row table Fixture row, including live native entity and activity counters.
local function service(row)
    local entity = row.entity
    assert(entity.valid)
    row.statuses[statuses[entity.status]] = true
    if entity.type == "assembling-machine" then
        local progress = entity.products_finished + entity.crafting_progress
        if progress ~= row.previous then row.activity = row.activity + 1 end
        row.previous = progress
        entity.get_inventory(modern and defines.inventory.crafter_input or defines.inventory.assembling_machine_input).insert{name = "iron-plate", count = 2}
        entity.get_output_inventory().clear()
    elseif row.output then
        local count = row.output.get_item_count()
        row.activity = row.activity + count
        row.output.clear_items_inside()
    elseif row.belt then
        for i = 1, 2 do
            local line = row.belt.get_transport_line(i)
            row.activity = row.activity + line.get_item_count()
            line.clear()
        end
    else
        if row.fluid_output then
            row.activity = row.activity + entity.pumped_last_tick
            if modern then row.fluid_output.clear_fluids() else row.fluid_output.clear_fluid_inside() end
        end
        for fluid in pairs(entity.get_fluid_contents()) do
            if fluid ~= "steam" then
                row.activity = row.activity + drain(entity,fluid,100000)
            end
        end
    end
    if row.input then row.input.insert{name = "iron-plate", count = 10} end
    if row.state == "working" then
        if modern then entity.set_fluid(row.steam_box,{name = "steam", amount = 200, temperature = 500})
        else entity.fluidbox[row.steam_box] = {name = "steam", amount = 200, temperature = 500} end
    else
        drain(entity,"steam",100000)
        entity.energy = 0
    end
end

script.on_event(defines.events.on_tick, function(event)
    local elapsed = event.tick - storage.start_tick
    if elapsed == 1 and remote.interfaces.freeplay then
        remote.call("freeplay", "set_skip_intro", true)
        remote.call("freeplay", "set_disable_crashsite", true)
    end
    if elapsed == 1 then
        for _, player in pairs(game.players) do
            if player.controller_type == defines.controllers.cutscene then player.exit_cutscene() end
        end
    end
    for _, row in ipairs(storage.rows) do service(row) end
    -- Start after a warmup so inserters and loaders have time to transfer items.
    if elapsed >= 600 and elapsed < 620 then
        local row = storage.rows[elapsed - 599]
        local entity = row.entity
        row.capture_status = statuses[entity.status]
        row.capture_energy = entity.energy
        row.capture_tick = event.tick
        assert((row.state == "working" and row.activity > 0) or
            (row.state == "starved" and row.activity == 0 and entity.energy == 0),
            row.name .. "/" .. row.state .. ": activity=" .. row.activity .. ", status=" .. row.capture_status
                .. ", fluids=" .. helpers.table_to_json(entity.get_fluid_contents()))
        if config.visual then
            game.take_screenshot{surface = entity.surface, position = entity.position, resolution = {768, 640}, zoom = 2,
                path = "steam-glow/" .. config.mode .. "/" .. row.name .. "-" .. row.state .. ".png",
                daytime = 0.5, show_gui = false, show_entity_info = false, hide_clouds = true, hide_fog = true,
                anti_alias = true, force_render = true}
            game.set_wait_for_screenshots_to_finish()
        end
    elseif elapsed == 625 then
        local report = {passed=true,mode = config.mode, visual = config.visual, engine=script.active_mods.base,rows = {}}
        for _, row in ipairs(storage.rows) do
            report.rows[#report.rows + 1] = {name = row.name, state = row.state, activity = row.activity,
                status = row.capture_status, energy = row.capture_energy, tick = row.capture_tick, statuses = row.statuses}
        end
        helpers.write_file("steam-glow/" .. config.mode .. (config.visual and "-visual" or "-runtime") .. ".json",
            helpers.table_to_json(report), false)
        log("STEAM GLOW COMPLETE " .. config.mode)
    end
end)
