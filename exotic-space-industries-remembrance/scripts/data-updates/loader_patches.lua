-- changes to exotic-industries-loaders mod

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--CHECK FOR MOD
--====================================================================================================
--[[
if not mods["exotic-industries-loaders"] then
    return
end
]]
--====================================================================================================
--CHECK FOR LOADER COMPLEXITY TOGGLE MOVED TO SETTINGS
--====================================================================================================

--====================================================================================================
--CHANGES
--====================================================================================================
--[[]
-- change where loaders are unlocked
ei_lib.remove_unlock_recipe("logistics", "ei-loader")
table.insert(data.raw.technology["fast-inserter"].effects, {
    type = "unlock-recipe",
    recipe = "ei-loader"
})

ei_lib.remove_unlock_recipe("logistics-2", "ei-fast-loader")
table.insert(data.raw.technology["advanced-circuit"].effects, {
    type = "unlock-recipe",
    recipe = "ei-fast-loader"
})

ei_lib.remove_unlock_recipe("logistics-3", "ei-express-loader")
table.insert(data.raw.technology["bulk-inserter"].effects, {
    type = "unlock-recipe",
    recipe = "ei-express-loader"
})
]]
-- make new loader recipes
ei_lib.recipe_new("ei-loader", {
    {type="item", name="transport-belt", amount=4},
    {type="item", name="electric-engine-unit", amount=4},
    {type="item", name="inserter", amount=2},
    {type="item", name="electronic-circuit", amount=6},
})

ei_lib.recipe_new("ei-fast-loader", {
    {type="item", name="fast-transport-belt", amount=6},
    {type="item", name="advanced-circuit", amount=8},
    {type="item", name="ei-loader", amount=1},
    {type="item", name="fast-inserter", amount=2},
})

ei_lib.recipe_new("ei-express-loader", {
    {type="item", name="express-transport-belt", amount=8},
    {type="item", name="bulk-inserter", amount=2},
    {type="item", name="ei-fast-loader", amount=1},
    {type="item", name="processing-unit", amount=10},
})

ei_lib.recipe_new("ei-neo-loader", {
    {type="item", name="ei-neo-belt", amount=10},
    {type="item", name="ei-express-loader", amount=1},
    {type="item", name="ei-magnet", amount=12},
    {type="item", name="stack-inserter", amount=2},
})


    local loader = data.raw["loader-1x1"]["ei-express-loader"]
    loader.max_belt_stack_size = 1
    loader.filter_count = 2
    loader.per_lane_filters = true
    --Express loader having a processing unit says it ought to be able to filter
    loader = data.raw["loader-1x1"]["ei-neo-loader"]
    -- Set loader properties
    loader.max_belt_stack_size = 4-- Default for loaders is 1; increase to inserter value
    loader.filter_count = 2 -- Default is 5; set to 2 for lane filters to work
    loader.per_lane_filters = true -- Enable lane-specific filtering
    --Neo loader has stacker inserters and magnets ergo blessed with the bounty of filtering & stacking
