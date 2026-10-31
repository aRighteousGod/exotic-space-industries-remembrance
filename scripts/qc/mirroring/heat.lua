-- Exercise the changed distillation tower and an unchanged heat chemical control.
local M = {}
local config = require("test-config")
function M.setup(choose_recipe)
    local surface = game.create_surface("mirroring-heat", {width = 128, height = 128,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    storage.heat = {}
    for _, name in ipairs{"ei-destill-tower", "ei-heat-chemical-plant"} do
        for _, direction in ipairs{0, 4, 8, 12} do
            for _, mirrored in ipairs{false, true} do
                local i = #storage.heat
                local entity = assert(surface.create_entity{name = name, position = {(i % 4) * 12 - 18, math.floor(i / 4) * 12 - 18},
                    direction = direction, force = "player"})
                choose_recipe(entity)
                if mirrored then assert(entity.flip{horizontal = true}) end
                entity.disabled_by_script = true
                local box, p = entity.bounding_box, entity.position
                local radius = math.ceil((box.right_bottom.x - box.left_top.x) / 2)
                for dx = -radius, radius do for dy = -radius, radius do
                    if math.abs(dx) == radius or math.abs(dy) == radius then
                        surface.create_entity{name = "heat-pipe", position = {p.x + dx, p.y + dy}, force = "player"}
                    end
                end end
                local neighbours = entity.heat_neighbours
                assert(#neighbours > 0, name .. ": missing native heat connections")
                storage.heat[#storage.heat + 1] = {entity = entity, heater = neighbours[1],
                    name = name, direction = direction, mirrored = mirrored, neighbours = #neighbours, initial = entity.temperature}
            end
        end
    end
end
function M.tick(tick)
    for _, row in ipairs(storage.heat) do row.heater.temperature = 1000 end
    if tick ~= 600 then return end
    local report = {passed = true, cases = {}}
    for _, row in ipairs(storage.heat) do
        local passed = row.entity.temperature > row.initial and #row.entity.heat_neighbours == row.neighbours
        report.passed = report.passed and passed
        report.cases[#report.cases + 1] = {name = row.name, direction = row.direction, mirrored = row.mirrored,
            initial = row.initial, temperature = row.entity.temperature, neighbours = row.neighbours, passed = passed}
    end
    helpers.write_file("mirroring/" .. config.tag .. "-heat.json", helpers.table_to_json(report), false)
    storage.heat = nil
end
return M
