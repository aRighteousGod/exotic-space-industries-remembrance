local util = require "__core__.lualib.util"

local recipes = {}

for name,item in pairs(data.raw['item']) do
    energy = item['fuel_value'] and util.parse_energy(item['fuel_value'])
    if energy and string.find(item['fuel_category'], 'chemical') then
        --log(string.format("found fuel to burn:  %s  (%s)", name, energy))
        speed = item['fuel_top_speed_multiplier'] or 1
        table.insert(recipes, {
            type = "recipe",
            name = "ei-warm-fire-from-" .. name,
            localised_name = {"ei-warm-fire"},
            category = "ei-burning",
            icon = "__core__/graphics/arrows/heat-exchange-indication.png",
            icon_size = 48,
            energy_required = (12.3 + energy / 1e6) * speed,
            enabled = true,
            always_show_products = true,
            show_amount_in_title = false,
            allow_as_intermediate = false,
            hide_from_player_crafting = true,
            ingredients = {{type="item", name=name, amount=1}},
            results = {{
                type = "item",
                name = item['burnt_result'] or "atan-ash",
                amount = 1,
                probability = 1,
                emissions_multiplier = item['fuel_emissions_multiplier'] or 1,
            }},
        })
    end
end

data:extend(recipes)
