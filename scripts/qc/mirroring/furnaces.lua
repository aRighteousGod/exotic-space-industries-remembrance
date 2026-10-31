-- Furnaces choose recipes from supplied inputs; they have no set_recipe API.
local M = {}
local config = require("test-config")
function M.setup()
    local surface = game.create_surface("mirroring-furnaces", {width = 256, height = 256,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 3)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    storage.furnaces = {}
    for _, name in ipairs{"ei-arc-furnace", "ei-cooler", "ei-plasma-heater"} do
        local choices = {}
        for recipe_name, recipe in pairs(prototypes.recipe) do
            local allowed, score = false, 0
            for _, category in ipairs(recipe.categories) do
                if prototypes.entity[name].crafting_categories[category] then allowed = true end
            end
            for _, part in ipairs(recipe.ingredients) do if part.type == "fluid" then score = score + 1 end end
            if allowed and score > 0 then choices[#choices + 1] = recipe_name end
        end
        table.sort(choices)
        assert(#choices > 0, name .. ": no representative fluid recipe")
        local recipe = prototypes.recipe[choices[1]]
        for _, direction in ipairs{0, 4, 8, 12} do
            for _, horizontal in ipairs{true, false} do
                local i = #storage.furnaces
                local entity = assert(surface.create_entity{name = name, position = {(i % 6) * 18 - 45, math.floor(i / 6) * 18 - 27},
                    direction = direction, force = "player"})
                storage.furnaces[#storage.furnaces + 1] = {entity = entity, recipe = recipe.name, direction = direction, horizontal = horizontal}
            end
        end
    end
end
function M.tick(tick, snapshot, same)
    for _, row in ipairs(storage.furnaces) do
        local entity, recipe = row.entity, prototypes.recipe[row.recipe]
        entity.energy = 1e12
        for _, part in ipairs(recipe.ingredients) do
            if part.type == "item" then entity.get_inventory(defines.inventory.crafter_input).insert{name = part.name, count = part.amount}
            else
                for i = 1, entity.fluids_count do
                    local box = entity.get_fluid_box_prototype(i)
                    if box and box.production_type == "input" then
                        entity.set_fluid(i, {name = part.name, amount = entity.get_fluid_capacity(i),
                            temperature = part.temperature or part.minimum_temperature or prototypes.fluid[part.name].default_temperature})
                    end
                end
            end
        end
        entity.get_output_inventory().clear()
    end
    if tick ~= 120 then return end
    local report = {passed = true, cases = {}}
    for _, row in ipairs(storage.furnaces) do
        local entity = row.entity
        local recipe = entity.get_recipe()
        local before = snapshot(entity)
        local success = entity.flip{horizontal = row.horizontal}
        local after = snapshot(entity)
        local reversed = not success or entity.flip{horizontal = row.horizontal}
        local restored = snapshot(entity)
        local conserved = same(before.fluids, after.fluids) and same(before.fluids, restored.fluids)
        local passed = recipe ~= nil and conserved and reversed and entity.prototype.allows_flipping
        report.passed = report.passed and passed
        report.cases[#report.cases + 1] = {name = entity.name, requested_recipe = row.recipe,
            recipe = recipe and recipe.name, direction = row.direction, horizontal = row.horizontal,
            success = success, before = before, after = after, restored = restored, passed = passed}
    end
    helpers.write_file("mirroring/" .. config.tag .. "-furnaces.json", helpers.table_to_json(report), false)
    storage.furnaces = nil
end
return M
