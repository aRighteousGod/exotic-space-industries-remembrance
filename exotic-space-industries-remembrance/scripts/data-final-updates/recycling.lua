local ei_lib = require("lib/lib")
--====================================================================================================
--Recycling
--====================================================================================================

local recycler = ei_lib.raw.furnace.recycler
if recycler then
    --alt t1 recipe which doesn't require processing units
    data:extend({
    {
        type = "recipe",
        name = "ei-recycler",
        ingredients =
        {
            {type = "item", name = "ei-electronic-parts", amount = 45},
            {type = "item", name = "steel-plate", amount = 15},
            {type = "item", name = "ei-steel-beam", amount = 4},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 20},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
            {type = "item", name = "electric-engine-unit", amount = 12},
            {type = "item", name = "concrete", amount = 20}
        },
        results = {{type="item", name="recycler", amount=1}},
        energy_required = 30,
        enabled = false,
        icons = {
             {
                icon = ei_graphics_other_path.."overlay_1.png",
                icon_size = 64,
             },
             {
                 icon = data.raw.item.recycler.icon,
                 icon_size = data.raw.item.recycler.icon_size,
             }
         }
    }
    })

    ei_lib.add_unlock_recipe("recycling","ei-recycler")
    local r_recipe = ei_lib.raw.recipe["recycler"]
    if r_recipe then
        r_recipe.ingredients = {
            {type = "item", name = "processing-unit", amount = 8},
            {type = "item", name = "steel-plate", amount = 15},
            {type = "item", name = "ei-steel-beam", amount = 4},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 20},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
            {type = "item", name = "ei-advanced-motor", amount = 3},
            {type = "item", name = "refined-concrete", amount = 5}
        }
        r_recipe.icons = {
             {
                icon = ei_graphics_other_path.."overlay_2.png",
                icon_size = 64,
             },
             {
                 icon = data.raw.item.recycler.icon,
                 icon_size = data.raw.item.recycler.icon_size,
             }
         }
    end

    --run vanilla recycling recipe generator again
    local recycling = require("__quality__/prototypes/recycling")

    -- auto_recycle = false tells the recycling recipe generator to skip

    -- Generating the recycle (reverse) recipes
    for name, recipe in pairs(data.raw.recipe) do
        if not string.find(name, "^ei%-auric%-vat%-") then
            recycling.generate_recycling_recipe(recipe)
        end
    end
    for name, recipe in pairs(data.raw.recipe) do
        local remove_recipe = recipe.category == "recycling" and string.find(name, "^ei%-auric%-vat%-")
        if not remove_recipe and recipe.category == "recycling" then
            for _, result in pairs(recipe.results or {}) do
                if result.name == "ei-auric-cyst" then
                    remove_recipe = true
                    break
                end
            end
        end
        if remove_recipe then
            data.raw.recipe[name] = nil
        end
    end
    --Swap superior data for simulation else nobody will ever do the space crafting chain
    ei_lib.raw.recipe["processing-unit-recycling"].results = {
        {type="item",name="ei-electronic-parts", amount_min=0,amount_max=1,probability=0.21},
        {type="item",name="ei-advanced-semiconductor", amount_min=0,amount=1,probability=0.06},
        {type="item",name="ei-simulation-data", amount_min=0,amount=1,probability=0.01},
        {type="item",name="ei-crushed-gold", amount_min=0,amount_max=1,probability=0.16},
    }

    -- Late merge/swap passes can leave stale alias recyclers behind.
    data.raw.recipe["iron-stick-recycling"] = nil
    data.raw.recipe["iron-gear-wheel-recycling"] = nil
    data.raw.recipe["uranium-fuel-cell-recycling"] = nil
    for _, recipe_name in pairs({
        "ei-used-uranium-235-fuel-recycling",
        "ei-used-uranium-233-fuel-recycling",
        "ei-used-plutonium-239-fuel-recycling",
        "ei-used-thorium-232-fuel-recycling",
    }) do
        data.raw.recipe[recipe_name] = nil
    end

    -- Use Quality's own self-recycling shape for raw loops that should only return themselves.
    for _, item_name in pairs({
        "ei-neodym-ingot",
        "atan-ash",
        "iron-ore",
        "copper-ore",
    }) do
        data.raw.recipe[item_name.."-recycling"] = nil
        if data.raw.item[item_name] then
            recycling.generate_self_recycling_recipe(data.raw.item[item_name])
        end
    end

    -- Crushed intermediates should recycle into themselves rather than back into parent materials.
    for recipe_name, recipe in pairs(data.raw.recipe) do
        local crushed_item_name = string.gsub(recipe_name, "%-recycling$", "")
        if recipe.category == "recycling"
        and crushed_item_name ~= recipe_name
        and string.find(crushed_item_name, "crushed", 1, true)
        and data.raw.item[crushed_item_name] then
            recipe.ingredients = {
                {type = "item", name = crushed_item_name, amount = 1, ignored_by_stats = 1},
            }
            recipe.results = {
                {type = "item", name = crushed_item_name, amount = 1, probability = 0.25, ignored_by_stats = 1},
            }
        end
    end

    -- Prefer the sensible base craft when multi-route items would otherwise recycle into odd byproducts.
    local stone_brick_recycling = ei_lib.raw.recipe["stone-brick-recycling"]
    if stone_brick_recycling then
        stone_brick_recycling.results = {
            {type = "item", name = "stone", amount = 0.25, extra_count_fraction = 0.25},
        }
    end
    local neutron_container_recycling = ei_lib.raw.recipe["ei-neutron-container-recycling"]
    if neutron_container_recycling then
        neutron_container_recycling.results = {
            {type = "item", name = "ei-empty-cryo-container", amount = 0.15, extra_count_fraction = 0.15},
            {type = "item", name = "ei-carbon-structure", amount = 0.05, extra_count_fraction = 0.05},
        }
    end
    ei_lib.raw.recipe["ei-energy-crystal-recycling"].results = {
        {type="item",name="ei-sand", amount_min=0,amount_max=1,probability=0.18},
        {type="item",name="ei-crushed-sulfur", amount_min=0,amount=1,probability=0.11},
    }
    ei_lib.raw.recipe["ei-coke-recycling"].results = {
        {type="item",name="coal", amount_min=0,amount_max=1,probability=0.17},
    }
    --fit output size to new scrap recipe
    recycler.result_inventory_size = 24
    ei_lib.raw.recipe["scrap-recycling"].results = {
        {type="item",name="ei-iron-mechanical-parts", amount_min=0,amount_max=1,probability=0.07},
        {type="item",name="ei-copper-mechanical-parts", amount_min=0,amount_max=1,probability=0.07},
        {type="item",name="ei-steel-mechanical-parts", amount_min=0,amount_max=1,probability=0.07},
        {type="item",name="ei-iron-beam", amount_min=0,amount_max=1,probability=0.04},
        {type="item",name="ei-copper-beam", amount_min=0,amount_max=1,probability=0.03},
        {type="item",name="ei-steel-beam", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="steel-plate", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="iron-plate", amount_min=0,amount_max=1,probability=0.025},
        {type="item",name="concrete", amount_min=0,amount_max=1,probability=0.05},
        {type="item",name="ice", amount_min=0,amount_max=1,probability=0.06},
        {type="item",name="battery", amount_min=0,amount_max=1,probability=0.04},
        {type="item",name="stone", amount_min=0,amount_max=1,probability=0.025},
        {type="item",name="ei-slag", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="electronic-circuit", amount_min=0,amount_max=1,probability=0.04},
        {type="item",name="advanced-circuit", amount_min=0,amount_max=1,probability=0.03},
        {type="item",name="ei-electronic-parts", amount_min=0,amount_max=1,probability=0.03},
        {type="item",name="copper-cable", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="ei-electron-tube", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="ei-insulated-wire", amount_min=0,amount_max=1,probability=0.02},
        {type="item",name="low-density-structure", amount_min=0,amount_max=1,probability=0.01},
        {type="item",name="holmium-ore", amount_min=0,amount_max=1,probability=0.01},
        {type="item",name="rp-steam-soul", amount_min=0,amount_max=1,probability=0.005},
        {type="item",name="rp-steam-calculator", amount_min=0,amount_max=1,probability=0.005},
        {type="item",name="ei-module-part", amount_min=0,amount_max=1,probability=0.02}
    }
    local sac = ei_lib.raw.recipe["ei-scrap-asteroid-crushing"]
    local sac_exclude = {
    "ei-electronic-parts",
    "holmium-ore",
    "low-density-structure"
    }
    local saca = ei_lib.raw.recipe["ei-advanced-scrap-asteroid-crushing"]
    local saca_exclude = {
    "stone",
    "advanced-circuit",
    "ice"
    }

    for _,output in pairs(data.raw.recipe["scrap-recycling"].results) do
    local output_bak = table.deepcopy(output)
    if sac and not ei_lib.table_contains_value(sac_exclude,output.name) then
        output.amount_min = output.amount_min or 0
        output.amount_max = 4--output.amount_max or 1
        table.insert(sac.results,output)
    end
    if saca and not ei_lib.table_contains_value(saca_exclude,output.name) then
        output_bak.amount_min = output.amount_min or 0
        output_bak.amount_max = 4--output.amount_max or 1
        table.insert(saca.results,output_bak)
    end
    end
    data.raw.recipe["ei-nuclear-waste-recycling"] = nil
end
