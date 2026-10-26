local cases = require("cases")
local config = require("test-config")
local bottleneck_enabled = settings.startup["bnl-enable"] and settings.startup["bnl-enable"].value or false
assert(bottleneck_enabled == (config.bottleneck == "enabled" or config.bottleneck == "custom"), "Actual Bottleneck startup mode differs from fixture")
local snapshot, expected = {}, {}
local function capture(name, required)
    local prototype = data.raw["assembling-machine"][name] or (data.raw.furnace and data.raw.furnace[name])
    if required then assert(prototype, "Missing body " .. name) end
    snapshot[name] = prototype and table.deepcopy(prototype) or false
end
for _, case in ipairs(cases) do
    capture(case.name, true)
    expected[case.name] = case.lights
end
for _, name in ipairs{
    "ei-alien-console", "ei-alien-stabilizer", "ei-rift-stabilizer", "ei-drone-port",
    "ei-arc-furnace", "ei-plasma-heater", "ei-caster", "ei-cooler", "ei-matter-stabilizer",
    "ei-exchanger", "ei-accelerator", "assembling-machine-1", "assembling-machine-2",
} do capture(name) end
data:extend{{type = "mod-data", name = "machine-light-qc", data_type = "machine-light-qc",
    data = {snapshot = snapshot, expected = expected, mode = config.mode,
        early = data.raw["mod-data"]["machine-light-early-qc"].data,
        bottleneck_version = mods["BottleneckLite"] or "absent",
        bottleneck_enabled = bottleneck_enabled}}}

-- Deterministic recipes are a fixture-only adapter, AFTER the final snapshot.
-- Native machine IDs, graphics, energy sources, speed and fluid boxes are retained.
data:extend{
    {type = "recipe-category", name = "machine-light-qc"},
    {type = "recipe", name = "machine-light-qc", category = "machine-light-qc", enabled = true,
        energy_required = 0.25, ingredients = {{type = "item", name = "iron-plate", amount = 1}},
        results = {{type = "item", name = "copper-plate", amount = 1}}},
}
for _, case in ipairs(cases) do
    local prototype = data.raw["assembling-machine"][case.name] or data.raw.furnace[case.name]
    prototype.crafting_categories = {"machine-light-qc"}
    prototype.fixed_recipe = nil
end

-- Invisible fixture power supplies isolate each low-power network from other rows.
local pole = table.deepcopy(data.raw["electric-pole"]["substation"])
pole.name = "machine-light-qc-pole"
pole.minable = nil
pole.collision_box = {{0, 0}, {0, 0}}
pole.collision_mask = {layers = {}}
pole.supply_area_distance = 9
pole.maximum_wire_distance = 0
pole.pictures = {filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1}
pole.connection_points = {{wire = {}, shadow = {}}}
pole.radius_visualisation_picture = nil
pole.light = nil
data:extend{pole, {
    type = "electric-energy-interface", name = "machine-light-qc-supply",
    icon = "__base__/graphics/icons/accumulator.png", icon_size = 64,
    flags = {"not-on-map"}, collision_box = {{0, 0}, {0, 0}}, collision_mask = {layers = {}},
    energy_source = {type = "electric", buffer_capacity = "100MJ", usage_priority = "primary-output",
        input_flow_limit = "0W", output_flow_limit = "1TW"},
    energy_production = "0W", energy_usage = "0W",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
}}

require("brightness")
