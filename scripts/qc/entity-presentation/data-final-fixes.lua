-- Opt-in fixture: validate final inheritance and transport exact native scenes.
local util = require("__core__.lualib.util")
local scene_specs = {
    {"spider-vehicle", "ei-anisetron"},
    {"spider-vehicle", "ei-scout-spidertron"},
    {"spider-vehicle", "assault_spidertron"},
    {"spider-vehicle", "spidertron"},
    {"radar", "ei-sweeping-radar"},
    {"radar", "ei-phased-array-radar"},
    {"land-mine", "ei-prediction-snare-mine"},
    {"combat-robot", "ei-incinerator"},
}
local body_specs = {
    {"burner-generator", "ei-combustion-turbine"},
    {"generator", "ei-combustion-turbine-fluid"},
    {"electric-energy-interface", "ei-crystal-accumulator"},
    {"electric-energy-interface", "ei-crystal-accumulator-low"},
    {"electric-energy-interface", "ei-crystal-accumulator-surged"},
    {"radar", "ei-sweeping-radar-placement"},
    {"radar", "ei-phased-array-radar-placement"},
    {"fluid-turret", "ei-water-turret"},
    {"fluid-turret", "flamethrower-turret"},
    {"spider-vehicle", "ei-gaian-saucer"},
    {"electric-energy-interface", "ei-sweeping-radar-power"},
    {"electric-energy-interface", "ei-phased-array-radar-power"},
    {"constant-combinator", "ei-sweeping-radar-output"},
}
local fields = {"damaged_trigger_effect", "open_sound", "close_sound", "factoriopedia_simulation",
    "dying_explosion", "dying_trigger_effect", "attack_parameters", "action", "destroy_action",
    "time_to_live", "max_health", "minable", "flags", "hidden", "hidden_in_factoriopedia",
    "selectable_in_game", "factoriopedia_alternative"}
local inheritance_fields = {"damaged_trigger_effect", "open_sound", "close_sound", "factoriopedia_simulation",
    "dying_explosion", "dying_trigger_effect"}
local snapshot = {entities = {}, spider_bodies = {}, fuel_shells = 0, operational_bodies = 0}
local scenes = {}
for _, spec in ipairs(scene_specs) do
    body_specs[#body_specs + 1] = spec
    local prototype = assert(data.raw[spec[1]][spec[2]], spec[2])
    assert(prototype.damaged_trigger_effect, "Missing hit: " .. spec[2])
    local scene = assert(prototype.factoriopedia_simulation, "Missing scene: " .. spec[2])
    assert(type(scene.init) == "string" and #scene.init > 0, "Missing init: " .. spec[2])
    scenes[#scenes + 1] = {name = spec[2], kind = spec[1], simulation = scene}
end
for _, spec in ipairs(body_specs) do
    local prototype = assert(data.raw[spec[1]][spec[2]], spec[2])
    local row = {type = spec[1], name = spec[2]}
    for _, field in ipairs(fields) do row[field] = prototype[field] end
    snapshot.entities[spec[2]] = row
end
for name, prototype in pairs(data.raw["spider-vehicle"]) do
    local family = name:match("^ei%-spider%-(scout)%-") or name:match("^ei%-spider%-(assault)%-") or name:match("^ei%-spider%-(rocket)%-")
    if family then
        local source = data.raw["spider-vehicle"][({scout = "ei-scout-spidertron", assault = "assault_spidertron", rocket = "spidertron"})[family]]
        for _, field in ipairs(inheritance_fields) do
            local a, b = prototype[field], source[field]
            assert(a == b or type(a) == "table" and type(b) == "table" and util.table.compare(a, b), name .. ": " .. field)
        end
        snapshot.spider_bodies[family] = (snapshot.spider_bodies[family] or 0) + 1
    end
end
for name, prototype in pairs(data.raw["fluid-turret"]) do
    if name:find("^ei%-flamethrower%-turret%-") then
        for _, field in ipairs(inheritance_fields) do
            local a, b = prototype[field], data.raw["fluid-turret"]["flamethrower-turret"][field]
            assert(a == b or type(a) == "table" and type(b) == "table" and util.table.compare(a, b), name .. ": " .. field)
        end
        snapshot.fuel_shells = snapshot.fuel_shells + 1
    end
end
for _, body in ipairs{
    {"ei-combustion-turbine-fluid", "ei-combustion-turbine"},
    {"ei-crystal-accumulator-low", "ei-crystal-accumulator"},
    {"ei-crystal-accumulator-surged", "ei-crystal-accumulator"},
    {"ei-sweeping-radar-placement", "ei-sweeping-radar"},
    {"ei-phased-array-radar-placement", "ei-phased-array-radar"},
} do
    local child, source = snapshot.entities[body[1]], snapshot.entities[body[2]]
    for _, field in ipairs{"damaged_trigger_effect", "open_sound", "close_sound"} do
        local a, b = child[field], source[field]
        assert(type(a) == "table" and type(b) == "table" and util.table.compare(a, b), body[1] .. ": " .. field)
    end
    assert(child.hidden and child.hidden_in_factoriopedia and child.factoriopedia_simulation == nil, body[1] .. ": hidden scene")
    snapshot.operational_bodies = snapshot.operational_bodies + 1
end
assert(snapshot.entities["ei-incinerator"].factoriopedia_simulation.update, "Robot preview expiry")
assert(snapshot.entities["ei-incinerator"].open_sound == nil and snapshot.entities["ei-incinerator"].close_sound == nil)
for _, name in ipairs{"ei-sweeping-radar", "ei-phased-array-radar"} do
    assert(snapshot.entities[name].open_sound and snapshot.entities[name].close_sound, name .. ": GUI sounds")
end
for _, name in ipairs{"ei-sweeping-radar-power", "ei-phased-array-radar-power", "ei-sweeping-radar-output"} do
    local row = snapshot.entities[name]
    assert(row.factoriopedia_simulation == nil and row.selectable_in_game == false, name .. ": helper")
end
assert(snapshot.fuel_shells > 0 and snapshot.spider_bodies.assault > 1 and snapshot.spider_bodies.scout > 1 and snapshot.spider_bodies.rocket > 1)

-- The compact snapshot uses the same JSON shape as a selected full dump.
local function quoted(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end
local function json(value)
    local kind = type(value)
    if kind == "string" then return quoted(value)
    elseif kind == "boolean" then return tostring(value)
    elseif kind == "number" then return string.format("%.17g", value)
    elseif kind == "table" then
        local rows, array = {}, #value > 0
        for key in pairs(value) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value then array = false; break end
        end
        if array then for _, v in ipairs(value) do rows[#rows + 1] = json(v) end
        else for k, v in pairs(value) do rows[#rows + 1] = quoted(tostring(k)) .. ":" .. json(v) end; table.sort(rows) end
        return (array and "[" or "{") .. table.concat(rows, ",") .. (array and "]" or "}")
    end
    error("Unsupported snapshot value: " .. kind)
end
log("ESIR_PRESENTATION_FINAL_DATA " .. json(snapshot))
data:extend{{type = "mod-data", name = "esir-presentation-qc", data_type = "esir.presentation-qc", data = {scenes = scenes}}}
