-- Actual lane delivery on original crane prototypes, including native fast replacement.
local M = {}
local config = require("test-config")
local directions = {0, 4, 8, 12}
local function center(p) return {x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5} end

---@param surface LuaSurface
function M.setup(surface)
    storage.transport = {rows = {}, checks = 0, failures = {}, ports = {}}
    for _, position in ipairs{{-285, -175}, {-205, -175}} do
        local port = assert(surface.create_entity{name = "roboport", position = position, force = "player"})
        port.insert{name = "construction-robot", count = 25}
        port.energy = 100000000
        storage.transport.ports[#storage.transport.ports + 1] = port
        local supply = assert(surface.create_entity{name = "passive-provider-chest", position = {position[1], position[2] + 4}, force = "player"})
        supply.insert{name = "ei-big-inserter-normal", count = 16}
    end
    for _, name in ipairs{"ei-small-inserter-normal", "ei-big-inserter-normal"} do
        for _, direction in ipairs(directions) do
            for _, horizontal in ipairs{true, false} do
                for _, mirrored in ipairs{false, true} do
                    local n = #storage.transport.rows
                    local position = {x = -300 + (n % 8) * 16, y = -200 + math.floor(n / 8) * 16}
                    local entity = assert(surface.create_entity{name = name, position = position, direction = direction, force = "player"})
                    local belt_direction = (direction + 4) % 16
                    if mirrored then
                        assert(entity.flip{horizontal = horizontal})
                        belt_direction = horizontal and (16 - belt_direction) % 16 or (8 - belt_direction) % 16
                    end
                    local before = {direction = entity.direction, mirroring = entity.mirroring,
                        pickup = entity.pickup_position, drop = entity.drop_position}
                    local upgraded = name == "ei-small-inserter-normal" and mirrored
                    if upgraded then
                        assert(entity.order_upgrade{target = "ei-big-inserter-normal", force = "player"})
                    end
                    local source = assert(surface.create_entity{name = "steel-chest", position = center(entity.pickup_position), force = "player"})
                    source.insert{name = "iron-plate", count = 10}
                    local belt = assert(surface.create_entity{name = "transport-belt", position = center(entity.drop_position),
                        direction = belt_direction, force = "player"})
                    local offset = {x = entity.drop_position.x - belt.position.x, y = entity.drop_position.y - belt.position.y}
                    local right = ({[0] = offset.x, [4] = offset.y, [8] = -offset.x, [12] = -offset.y})[belt_direction]
                    storage.transport.rows[#storage.transport.rows + 1] = {entity = entity, source = source, belt = belt,
                        name = name, direction = direction, horizontal = horizontal, mirrored = mirrored,
                        upgraded = upgraded, before = before, expected_lane = right < 0 and 1 or 2,
                        position = entity.position, surface = surface}
                end
            end
        end
    end
end

---@param tick uint
function M.tick(tick)
    for _, port in ipairs(storage.transport.ports) do port.energy = 100000000 end
    for _, row in ipairs(storage.transport.rows) do
        if not row.entity.valid then
            row.entity = assert(row.surface.find_entity("ei-big-inserter-normal", row.position), "Native crane upgrade missing replacement")
        end
        row.entity.energy = 1000000
    end
    if tick < 1800 then return end
    local report = {passed = true, cases = {}}
    for _, row in ipairs(storage.transport.rows) do
        local lane1 = row.belt.get_transport_line(1).get_item_count("iron-plate")
        local lane2 = row.belt.get_transport_line(2).get_item_count("iron-plate")
        local lane_ok = row.expected_lane == 1 and lane1 > 0 and lane2 == 0 or row.expected_lane == 2 and lane2 > 0 and lane1 == 0
        local e, b = row.entity, row.before
        local upgrade_ok = not row.upgraded or (e.name == "ei-big-inserter-normal" and e.mirroring == b.mirroring and e.direction == b.direction
            and e.pickup_position.x == b.pickup.x and e.pickup_position.y == b.pickup.y
            and e.drop_position.x == b.drop.x and e.drop_position.y == b.drop.y)
        report.cases[#report.cases + 1] = {name = row.name, direction = row.direction,
            horizontal = row.horizontal, mirrored = row.mirrored, upgraded = row.upgraded,
            expected_lane = row.expected_lane, lane1 = lane1, lane2 = lane2, lane_ok = lane_ok, upgrade_ok = upgrade_ok,
            actual_name = e.name, actual_direction = e.direction, actual_mirroring = e.mirroring,
            original = b, pickup = e.pickup_position, drop = e.drop_position}
        report.passed = report.passed and lane_ok and upgrade_ok
    end
    helpers.write_file("mirroring/" .. config.tag .. "-transport.json", helpers.table_to_json(report), false)
    storage.transport = nil
end

return M
