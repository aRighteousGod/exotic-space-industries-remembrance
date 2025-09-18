--====================================================================================================
--Vulcanus
--====================================================================================================
--match with recipe changes
local vulcanus = {}
vulcanus.new_ingredients_table = {
    ["big-mining-drill"] = {
    {type="item",name="electric-mining-drill", amount=4},
    {type="item",name="ei-advanced-motor", amount=10},
    {type="item",name="ei-electronic-parts", amount=10},
    {type="item",name="tungsten-carbide", amount=35},
    {type="fluid",name="ei-molten-steel", amount=250},
    {type="item",name="ei-carbon", amount=50},
    },
    ["casting-steel"] = {
        {type="fluid",name="ei-molten-steel",amount=20}
    },

}

ei_lib.add_prerequisite("big-mining-drill","ei-advanced-motor")
ei_lib.add_prerequisite("big-mining-drill","ei-electronic-parts")
ei_lib.add_prerequisite("big-mining-drill","ei-carbon-manipulation")
ei_lib.raw["mining-drill"]["big-mining-drill"].energy_usage = "2MW"
-- foundry
local foundry = ei_lib.raw["assembling-machine"].foundry
if foundry then
    foundry.crafting_speed = 1.5
    foundry.energy_usage = "58MW"
    foundry.module_slots = 2
    foundry.energy_source.emissions_per_minute.pollution=18
    table.insert(foundry.crafting_categories,"ei-casting")
end

ei_lib.recipe_swap("casting-low-density-structure","molten-iron","ei-molten-steel",50)

ei_lib.raw.recipe["casting-steel"].results = {
    {type="item",name="steel-plate",amount=2}
}
ei_lib.raw.recipe["casting-iron-gear-wheel"].results = {
    {type="item",name="ei-iron-mechanical-parts",amount=1}
}
ei_lib.raw.recipe["casting-iron-stick"].results = {
    {type="item",name="ei-iron-beam",amount=1}
}
ei_lib.raw.recipe["molten-copper"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,allow_productivity=false
}
ei_lib.raw.recipe["molten-iron"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,allow_productivity=false
}
ei_lib.raw.recipe["molten-copper-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,allow_productivity=false
}
ei_lib.raw.recipe["molten-iron-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,allow_productivity=false
}

ei_lib.merge_fluid("ei-molten-iron", "molten-iron", false)
ei_lib.merge_fluid("ei-molten-copper", "molten-copper", false)
--allow caster to produce space-age plates
local addToCaster = {
    "holmium-plate",
    "tungsten-plate"
}
for _,toCast in pairs(addToCaster) do
    local recipe = ei_lib.raw.recipe[toCast]
    if recipe then
        if recipe.additional_categories then
            table.insert(recipe.additional_categories,"ei-casting") 
        else
            recipe.additional_categories = {"ei-casting"}
        end
    end
end
--acid neutralisation
local a_n = ei_lib.raw.recipe["acid-neutralisation"]
if a_n then
    --acid neutralisation t2
    local a_n_t2 = table.deepcopy(a_n)
    a_n_t2.name = "ei-acid-neutralisation-t2"
    a_n_t2.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=750},
        {type= "fluid", name= "ei-nitric-acid", amount=250},
    }
    a_n_t2.results = {
        {type= "fluid", name= "steam", amount_min= 9000, amount_max=12500, temperature=500},
        {type = "fluid", name= "ei-acidic-water", amount_min=25,amount_max=125}
    }
    data:extend({
        a_n_t2,
    {
        name = "ei-acid-neutralisation-t2",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/fluid/acid-neutralisation-t2.png",
        icon_size = 64,
        prerequisites = {"ei-nitric-acid","metallurgic-science-pack"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-acid-neutralisation-t2"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
        })
    local a_n_t2_tech = ei_lib.raw.technology["ei-acid-neutralisation-t2"]
    table.insert(a_n_t2_tech.unit.ingredients,{"metallurgic-science-pack",1})
    a_n.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=1000},
    }
    --modify acid neutralization
    a_n.results = {
        {type= "fluid", name= "steam", amount_min= 7500, amount_max=9500, temperature= 280},
        {type = "fluid", name= "ei-acidic-water", amount_min=50,amount_max=250}
    }
end

return vulcanus