-- Controlled host checks. Final-data and native engine receipts provide engine acceptance.
local main = assert(arg[1], "Pass the gameplay source directory")
package.path = main .. "/?.lua;" .. package.path
local checks, messages = 0, {}
function log(message) messages[#messages + 1] = message end
local function check(value, name)
    assert(value, name)
    checks = checks + 1
end
function table.deepcopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, nested in pairs(value) do copy[key] = table.deepcopy(nested) end
    return copy
end
ei_lib = require("lib/lib")
mods = {quality = "2.1.24"}
data = {raw = {recipe = {}, item = {}, technology = {}}}

for _, field in ipairs({"ingredients", "results"}) do
    local output = field == "results"
    data.raw.recipe.empty = {}
    ei_lib.recipe_swap("empty", "old", "new", nil, output)
    ei_lib.fix_recipe("empty", output)
    check(data.raw.recipe.empty[field] == nil, field .. " absent remains absent")
    local empty = {}
    data.raw.recipe.empty[field] = empty
    ei_lib.recipe_swap("empty", "old", "new", nil, output)
    ei_lib.fix_recipe("empty", output)
    check(data.raw.recipe.empty[field] == empty and next(empty) == nil, field .. " empty remains empty")

    data.raw.recipe.sample = {[field] = {
        {type="item", name="old", amount=2}, {type="item", name="old", amount=3},
    }}
    ei_lib.fix_recipe("sample", output)
    local values = data.raw.recipe.sample[field]
    check(#values == 1 and values[1].amount == 5, field .. " duplicate amounts preserved")
    ei_lib.recipe_swap("sample", "old", "new", nil, output)
    check(values[1].name == "new" and values[1].amount == 5, field .. " swap preserves amount")
    check(values[1].type == "item", field .. " swap preserves metadata")

    local before = #messages
    data.raw.recipe.malformed = {[field] = false}
    ei_lib.recipe_swap("malformed", "old", "new", nil, output)
    ei_lib.fix_recipe("malformed", output)
    check(#messages == before + 2, field .. " malformed target retains diagnostics")
end
local before = #messages
ei_lib.recipe_swap("absent", "old", "new")
check(#messages == before + 1, "Missing recipe retains swap diagnostic")
check(not pcall(ei_lib.fix_recipe, "absent"), "Missing normalization target still fails")
before = #messages
local absent = ei_lib.raw.item["required-missing"]
check(absent == nil and #messages == before + 1, "Required prototype diagnostic remains active")

for _, technologyPresent in ipairs({false, true}) do
    for _, paracelsin in ipairs({false, true}) do
        mods = {["Accumulator-V2"]="1.0.8", SolarMatrix="1.0.9", Paracelsin=paracelsin or nil}
        data.raw = {
            accumulator = {accumulator={}, ["accumulator-v2"]={name="accumulator-v2", energy_source={}, minable={}}},
            technology = {["electric-energy-accumulators"]={}},
            item = {accumulator={}, ["accumulator-v2"]={icon="donor-item",icon_size=64}},
            recipe = {["accumulator-v2"]={enabled=true}},
        }
        if technologyPresent then
            data.raw.technology["accumulator-v2"] = {icon="donor-tech", icon_size=128}
        end
        before = #messages
        dofile(main .. "/scripts/data-updates/accumulator-v2.lua")
        check(#messages == before, "Conditional accumulator technology stays quiet")
        local technology = data.raw.technology["electric-energy-accumulators"]
        if technologyPresent and not paracelsin then
            check(technology.icon == "donor-tech" and technology.icon_size == 128, "Technology icon inheritance")
            check(data.raw.technology["accumulator-v2"].hidden == true, "Conditional technology hidden")
        else
            check(technology.icon == "__Accumulator-V2__/graphics/icons/accumulatortech_icon.png"
                and technology.icon_size == 256, "Technology icon fallback")
        end
        check(data.raw.item["accumulator-v2"].hidden == true, "Duplicate accumulator item hidden")
        check(data.raw.recipe["accumulator-v2"].enabled == paracelsin, "Paracelsin recipe availability retained")
    end
end

mods = {["Accumulator-V2"]="1.0.8"}
data.raw = {
    ["bool-setting"] = {["link-multiplier-to-cost"]={default_value=true}},
    ["double-setting"] = {["accumulator-power-capacity"]={default_value=50}},
}
before = #messages
dofile(main .. "/settings-updates.lua")
local setting = data.raw["bool-setting"]["link-multiplier-to-cost"]
check(setting.hidden and setting.forced_value == false and setting.default_value == false, "Actual dependency setting forced Off")
check(#messages == before, "Current dependency settings produce no missing-setting diagnostic")

local function read_source(path)
    local file = assert(io.open(main .. "/" .. path, "rb"))
    local text = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return text
end
local recipe_source = read_source("scripts/data-final-updates/final-recipe-fixes.lua")
local optional_gear = assert(recipe_source:match('(local sg =.-)\nif mods and mods%["aai%-signal%-transmission"%] then'))
for _, name in ipairs({"absent", "steel-gear-wheel", "kr-steel-gear-wheel"}) do
    data.raw = {recipe={}, item={}, technology={["steel-processing"]={effects={}}}}
    if name ~= "absent" then data.raw.recipe[name] = {enabled=true} end
    before = #messages
    assert(load(optional_gear, "optional-gear-presence"))()
    check(#messages == before, "Optional gear presence stays quiet")
    ei_lib.add_unlock_recipe("steel-processing", "kr-steel-gear-wheel")
    if name ~= "absent" then
        check(data.raw.recipe[name].hidden and not data.raw.recipe[name].enabled, "Optional gear hidden and disabled")
    end
    local effects = data.raw.technology["steel-processing"].effects
    check(#effects == (name == "kr-steel-gear-wheel" and 1 or 0), "Optional gear unlock behavior retained")
end
data.raw = {
    item={old={}, target={}},
    recipe={consumer={ingredients={{type="item",name="old",amount=4}},results={{type="item",name="old",amount=2}},main_product="old"}},
}
ei_lib.merge_item("target", "old", false)
local merged = data.raw.recipe.consumer
check(merged.ingredients[1].name == "target" and merged.ingredients[1].amount == 4, "Item merge ingredients retained")
check(merged.results[1].name == "target" and merged.results[1].amount == 2 and merged.main_product == "target", "Item merge products retained")
check(data.raw.item.old.hidden, "Merged source item hidden")

local tesla_source = read_source("teslas_legacy/overlay_ei.lua")
local category_body = assert(tesla_source:match('(local function ensure_ammo_category%([^)]+%).-)\nlocal function ensure_placeable_by'))
local ensure_category = assert(load("local raw = ei_lib.raw\n" .. category_body .. "\nreturn ensure_ammo_category"))()
data.raw = {["ammo-category"]={tesla={bonus_gui_order="a"}}}
local created = 0
function data:extend(prototypes)
    for _, prototype in ipairs(prototypes) do
        check(self.raw[prototype.type][prototype.name] == nil, "Category created exactly once")
        self.raw[prototype.type][prototype.name] = prototype
        created = created + 1
    end
end
before = #messages
for _, name in ipairs({"ei-legacy-tesla-family", "ei-legacy-tesla-turret"}) do
    ensure_category(name)
    ensure_category(name)
    check(data.raw["ammo-category"][name].bonus_gui_order == "a", "Tesla category order inherited")
end
check(created == 2 and #messages == before, "Category creation is idempotent and quiet")
print('DATA_HELPERS passed=true checks=' .. checks .. ' evidence=controlled-host-lua')
