-- Final snapshots precede fixture-only invisible electrical supplies.
local snapshot = {}
for _, spec in ipairs{
    {"furnace", "ei-cooler"},
    {"beacon", "ei-copper-beacon"}, {"beacon", "ei-iron-beacon"},
    {"assembling-machine", "ei-copper-beacon-source"}, {"assembling-machine", "ei-iron-beacon-source"},
    {"beacon", "ei-alien-beacon"}, {"beacon", "ei-warp-beacon"},
    {"assembling-machine", "ei-alien-beacon-source"}, {"assembling-machine", "ei-warp-beacon-source"},
    {"boiler", "ei-fluid-boiler"}, {"reactor", "ei-fluid-heater"},
    {"assembling-machine", "ei-high-temperature-reactor"}, {"generator", "ei-big-turbine"},
    {"recipe", "ei-liquid-nitrogen"}, {"recipe", "ei-cooler"},
    {"recipe", "ei-copper-beacon"}, {"recipe", "ei-iron-beacon"},
} do
    snapshot[spec[2]] = snapshot[spec[2]] or {}
    snapshot[spec[2]][spec[1]] = table.deepcopy(assert(data.raw[spec[1]][spec[2]], spec[2]))
end
data:extend{{type = "mod-data", name = "cryo-mist-qc", data = snapshot}}
local pole = table.deepcopy(data.raw["electric-pole"].substation)
pole.name, pole.minable, pole.maximum_wire_distance = "cryo-qc-pole", nil, 0
pole.supply_area_distance, pole.collision_mask = 3, {layers = {}}
pole.pictures = {filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1}
pole.connection_points, pole.radius_visualisation_picture, pole.light = {{wire = {}, shadow = {}}}, nil, nil
data:extend{pole, {
    type = "electric-energy-interface", name = "cryo-qc-supply",
    icon = "__base__/graphics/icons/accumulator.png", icon_size = 64,
    flags = {"not-on-map"}, collision_mask = {layers = {}},
    energy_source = {type = "electric", buffer_capacity = "100MJ", usage_priority = "primary-output",
        input_flow_limit = "0W", output_flow_limit = "1GW"},
    energy_production = "100MW", energy_usage = "0W",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
}}

-- Render-only isolation after the full snapshot: unrelated machines/effects
-- consume most atlas memory. Their PNGs become empty; the five cooling bodies,
-- terrain, UI and all gameplay fields stay intact. No shipping files are changed.
if require("test-config").visual then
    local keep = { ["ei-cooler"] = true, ["ei-copper-beacon"] = true, ["ei-iron-beacon"] = true,
        ["ei-copper-beacon-source"] = true, ["ei-iron-beacon-source"] = true }
    local seen = {}
    local function empty_unrelated_sprites(value)
        if type(value) ~= "table" or seen[value] then return end
        seen[value] = true
        local png = type(value.filename) == "string" and value.filename:match("%.png$")
        local esir = png and value.filename:find("__exotic%-space%-industries")
        local files = value.filenames or value.stripes
        if files then
            local first = files[1]
            local filename = type(first) == "table" and first.filename or first
            esir = type(filename) == "string" and filename:find("__exotic%-space%-industries")
        end
        if esir then
            value.filename = "__zzz-esir-cryo-mist-qc__/empty-atlas.png"
            value.filenames, value.stripes, value.hr_version = nil, nil, nil
            value.width, value.height, value.size, value.x, value.y = 1, 1, nil, 0, 0
            value.dice, value.dice_x, value.dice_y, value.slice = nil, nil, nil, nil
            -- Preserve mandatory frame/direction counts and alignment between
            -- mixed vanilla/ESIR layers. Every frame is a transparent pixel.
            value.lines_per_file = nil
            if value.mipmap_count then value.mipmap_count = 1 end
        end
        for _, child in pairs(value) do empty_unrelated_sprites(child) end
    end
    -- Shared sprite tables must not let another prototype mutate a kept body.
    local preserved = {}
    for kind, prototypes in pairs(data.raw) do
        for name, prototype in pairs(prototypes) do
            if keep[name] then preserved[#preserved + 1] = {kind = kind, name = name, prototype = table.deepcopy(prototype)} end
        end
    end
    for kind, prototypes in pairs(data.raw) do
        if kind ~= "tile" and kind ~= "mod-data" and kind ~= "gui-style" and kind ~= "font" and kind ~= "utility-sprites" then
            for name, prototype in pairs(prototypes) do if not keep[name] then empty_unrelated_sprites(prototype) end end
        end
    end
    for _, row in ipairs(preserved) do data.raw[row.kind][row.name] = row.prototype end
end
