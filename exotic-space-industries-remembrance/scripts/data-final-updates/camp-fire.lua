local util = require "__core__.lualib.util"

local recipes = {}
local exceptions = {
    ["wood"] = "2MJ",
    ["wooden-chest"] = "4MJ",
    ["lumber"] = "4MJ"
}

local function add_recipe(energy,speed,name,item)
    speed = item['fuel_top_speed_multiplier'] or 1
    table.insert(recipes, {
        type = "recipe",
        name = "ei-warm-fire-from-" .. name,
        localised_name = {"recipe-name.ei-warm-fire"},
        category = "ei-burning",
        icon = "__core__/graphics/arrows/heat-exchange-indication.png",
        icon_size = 48,
        energy_required = (12.3 + energy / 1e6) * speed,
        enabled = true,
        always_show_products = true,
        show_amount_in_title = false,
        allowed_effects = {"speed", "consumption","quality","productivity"},
        hide_from_player_crafting = true,
        allow_productivity = true,
        ingredients = {{type="item", name=name, amount=1}},
        surface_conditions = {
            {property = "pressure",    min = 33, max = 100000},
        },
        results = {{
            type = "item",
            name = item['burnt_result'] or "atan-ash",
            --Using below for amount varies ash output with energy density
            --but is detrimental in every application other than burning
            --in chemical labs directly for ash, so....
            --math.min(3,math.max(1,math.floor((12.3 + energy / 1e6) * speed))),
            amount = 1,
            probability = 1,
            emissions_multiplier = item['fuel_emissions_multiplier'] or 1,
        }}}
    )
    --[[
    table.insert(recipes, {
        type = "recipe",
        name = "ei-oxygenated-warm-fire-from-" .. name,
        localised_name = {"recipe-name.ei-oxygenated-warm-fire"},
        category = "ei-burning",
        icon = "__core__/graphics/arrows/heat-exchange-indication.png",
        icon_size = 48,
        energy_required = (12.3 + energy / 1e6) * speed,
        enabled = true,
        always_show_products = true,
        show_amount_in_title = false,
        allowed_effects = {"speed", "consumption","quality","productivity"},
        hide_from_player_crafting = true,
        allow_productivity = true,
        ingredients = {
            {type="fluid", name="ei-oxygen-gas", amount=math.max(1,(12.3 + energy / 1e6) * speed)},
            {type="item", name=name, amount=1}
        },
        results = {{
            type = "item",
            name = item['burnt_result'] or "atan-ash",
            amount = 1 + math.floor((((12.3 + energy / 1e6) * speed) ^ 0.5) / 3),
            probability = 1,
            emissions_multiplier = item['fuel_emissions_multiplier'] or 1,
        }}}
    )]]
end

for name,item in pairs(data.raw['item']) do
    local energy = item['fuel_value'] and util.parse_energy(item['fuel_value'])
    local speed = item['fuel_top_speed_multiplier'] or 1
    if energy and string.find(item['fuel_category'], 'chemical') then
        --log(string.format("found fuel to burn:  %s  (%s)", name, energy))
        add_recipe(energy,speed,name,item)
    elseif exceptions[name] then
        energy = util.parse_energy(exceptions[name])
        if energy then
            add_recipe(energy,speed,name,item)
        else
            log("ei camp_fire failed to add exception: "..name.." to burnables due to unparseable fuel value.")
        end
    end
end

data:extend(recipes)
