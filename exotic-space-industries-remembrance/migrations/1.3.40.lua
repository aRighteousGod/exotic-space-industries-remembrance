-- blueprint: .codex/esir/blueprints/railgun-cooling.md#contract
-- Prototype item-handling flags exclude new targets, but saved inserters retain
-- their previous target references. Repair those once without rebuilding coolant
-- helpers or discarding their fluid buffers. Scan inserters so custom reach works too.
---@type table<string, boolean>
local coolant_proxies = {
    ["ei-railgun-cooling-proxy"] = true,
    ["ei-railgun-cooling-proxy-ne"] = true,
    ["ei-railgun-cooling-proxy-nw"] = true,
    ["ei-railgun-cooling-proxy-se"] = true,
    ["ei-railgun-cooling-proxy-sw"] = true,
}

for _, surface in pairs(game.surfaces) do
    for _, inserter in pairs(surface.find_entities_filtered{type = "inserter"}) do
        local target = inserter.drop_target
        if target and target.valid and coolant_proxies[target.name] then
            local position = inserter.drop_position
            local x, y = math.floor(position.x), math.floor(position.y)
            -- The target API requires collision with the tile under the drop point.
            -- A helper can extend beyond the railgun, leaving no valid item target.
            local turrets = surface.find_entities_filtered{
                name = "railgun-turret", area = {{x, y}, {x + 1, y + 1}},
            }
            inserter.drop_target = turrets[1]
        end
    end
end
