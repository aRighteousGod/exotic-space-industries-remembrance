-- Original machine graphics and native operation; only unrelated atlases are reduced.
local config = require("test-config")
local recipes = require("recipes")
local names = require("cases")
names[#names + 1] = "ei-steam-oil-pumpjack"
local statuses = {}
for name, value in pairs(defines.entity_status) do statuses[value] = name end

---@param surface LuaSurface
---@param conditions table
local function conditions(surface, conditions)
    for _, condition in ipairs(conditions or {}) do
        surface.set_property(condition.property, condition.min or condition.max or surface.get_property(condition.property))
    end
end

local function initialize()
    if remote.interfaces.freeplay then
        remote.call("freeplay", "set_skip_intro", true)
        remote.call("freeplay", "set_disable_crashsite", true)
    end
    for _, recipe in pairs(game.forces.player.recipes) do recipe.enabled = true end
    storage.scenes, storage.captures = {}, {}
    local final = prototypes.mod_data["mirroring-qc"].data
    for index, name in ipairs(names) do
        local surface = game.create_surface("mirror-render-" .. index, {width = 128, height = 128,
            autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
        surface.request_to_generate_chunks({0, 0}, 2)
        surface.force_generate_chunk_requests()
        for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
        surface.destroy_decoratives{}
        local tiles = {}
        for x = -60, 60 do for y = -48, 48 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(tiles)
        surface.always_day, surface.daytime, surface.freeze_daytime = false, 0, true
        conditions(surface, prototypes.entity[name].surface_conditions)
        if recipes[name] then conditions(surface, prototypes.recipe[recipes[name]].surface_conditions) end
        local scene = {name = name, surface = surface, rows = {}}
        for column, direction in ipairs{0, 4, 8, 12} do
            for mirror = 0, 1 do
                local position = {x = (column - 2.5) * 20, y = (mirror - 0.5) * 24}
                if name == "ei-steam-oil-pumpjack" then surface.create_entity{name = "crude-oil", position = position, amount = 1000000} end
                local entity = assert(surface.create_entity{name = name, position = position, direction = direction, force = "player"})
                if recipes[name] then entity.set_recipe(recipes[name]) end
                if mirror == 1 then assert(entity.flip{horizontal = direction == 0 or direction == 8}, name) end
                local source = final.entities[name].energy_source
                local row = {entity = entity, source = source.type, direction = direction, mirror = mirror,
                    previous = 0, advanced = false, pipes = {}}
                if source.type == "electric" then
                    surface.create_entity{name = "mirroring-qc-pole", position = position, force = "player"}
                    row.supply = surface.create_entity{name = "mirroring-qc-supply", position = position, force = "player"}
                    row.supply.power_production = entity.prototype.get_max_energy_usage("normal") * 5
                end
                local connector = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
                if connector then
                    local other = surface.create_entity{name = "constant-combinator", position = {position.x + 8, position.y + 5}, force = "player"}
                    row.wired = connector.connect_to(other.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
                end
                rendering.draw_text{surface = surface, target = {position.x - 7, position.y - 9},
                    text = ({"N", "E", "S", "W"})[column] .. (mirror == 1 and " mirrored" or " normal"),
                    color = {1, 1, 1}, scale = 1}
                scene.rows[#scene.rows + 1] = row
            end
        end
        storage.scenes[#storage.scenes + 1] = scene
    end
end

---@param row table
local function service(row)
    local entity = row.entity
    if row.source == "electric" then entity.energy = 1e12
    elseif row.source == "heat" then entity.temperature = 1000
    elseif row.source == "burner" then
        entity.get_fuel_inventory().insert{name = entity.name == "ei-auric-inoculation-vat" and "nutrients" or "ei-bio-matter", count = 5}
        if entity.burner.burnt_result_inventory then entity.burner.burnt_result_inventory.clear() end
    end
    local recipe = entity.type == "assembling-machine" and entity.get_recipe()
    local ingredients = {}
    if recipe then
        for _, part in pairs(recipe.ingredients) do
            if part.type == "item" then entity.get_inventory(defines.inventory.crafter_input).insert{name = part.name, count = part.amount}
            else ingredients[part.name] = part end
        end
        entity.get_output_inventory().clear()
    end
    for i = 1, entity.fluids_count do
        local filter = entity.get_fluid_filter(i)
        local name = filter and filter.name
        local box = entity.get_fluid_box_prototype(i)
        local output = box and box.production_type == "output"
        if name and not output and (ingredients[name] or name == "steam") then
            local ingredient = ingredients[name] or {}
            local temperature = ingredient.temperature or ingredient.minimum_temperature or prototypes.fluid[name].default_temperature
            if name == "steam" then temperature = 500 end
            entity.set_fluid(i, {name = name, amount = entity.get_fluid_capacity(i), temperature = temperature})
        else entity.remove_fluid(i, 1000000) end
    end
    local progress = recipe and (entity.crafting_progress + entity.products_finished) or entity.mining_progress
    row.advanced = row.advanced or progress ~= row.previous
    row.previous = progress
end

local function capture(scene, phase)
    local report = {name = scene.name, phase = phase, rows = {}}
    for _, row in ipairs(scene.rows) do
        report.rows[#report.rows + 1] = {direction = row.entity.direction, mirrored = row.entity.mirroring,
            status = statuses[row.entity.status], advanced = row.advanced, wired = row.wired or false,
            fluids = row.entity.get_fluid_contents(), position = row.entity.position}
    end
    storage.captures[#storage.captures + 1] = report
    game.take_screenshot{surface = scene.surface, position = {0, 0}, zoom = 0.65,
        resolution = {1792, 1280}, path = "mirroring/render/" .. scene.name .. "-" .. phase .. ".png",
        daytime = phase == "night" and 0.5 or 0, show_gui = false, show_entity_info = false,
        hide_clouds = true, hide_fog = true, anti_alias = true, force_render = true}
    game.set_wait_for_screenshots_to_finish()
    if phase ~= "covers" then
        for index = 1, 2 do
            local row = scene.rows[index]
            game.take_screenshot{surface = scene.surface, position = row.entity.position, zoom = 1.5,
                resolution = {1024, 1024}, path = "mirroring/render/" .. scene.name .. "-" .. phase .. "-close-" .. index .. ".png",
                daytime = phase == "night" and 0.5 or 0, show_gui = false, show_entity_info = false,
                hide_clouds = true, hide_fog = true, anti_alias = true, force_render = true}
        end
        game.set_wait_for_screenshots_to_finish()
    end
end

script.on_init(initialize)
script.on_event(defines.events.on_tick, function(event)
    for _, scene in ipairs(storage.scenes) do for _, row in ipairs(scene.rows) do service(row) end end
    if event.tick >= 180 and event.tick < 199 then capture(storage.scenes[event.tick - 179], "covers") end
    if event.tick == 210 then
        for _, scene in ipairs(storage.scenes) do
            for _, row in ipairs(scene.rows) do
                for i = 1, row.entity.fluids_count do
                    for _, port in ipairs(row.entity.get_fluid_box_pipe_connections(i) or {}) do
                        if scene.surface.can_place_entity{name = "pipe", position = port.target_position, force = "player"} then
                            row.pipes[#row.pipes + 1] = scene.surface.create_entity{name = "pipe", position = port.target_position, force = "player"}
                        end
                    end
                end
            end
        end
    end
    if event.tick >= 240 and event.tick < 259 then capture(storage.scenes[event.tick - 239], "pipes") end
    if event.tick >= 300 and event.tick < 319 then capture(storage.scenes[event.tick - 299], "night") end
    if event.tick == 320 then
        helpers.write_file("mirroring/render/receipt.json", helpers.table_to_json({engine = script.active_mods.base, captures = storage.captures}), false)
    end
end)
