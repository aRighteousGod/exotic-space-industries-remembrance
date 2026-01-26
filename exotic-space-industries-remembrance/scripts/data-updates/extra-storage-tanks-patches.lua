
--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["extra-storage-tank"] then
    return
end

local ei_lib = require("lib/lib")

--====================================================================================================
--CHANGES
--====================================================================================================

ei_lib.raw.technology["steel-storage-tank"].age = "steam-age"
ei_lib.raw.technology["steel-storage-tank"].prerequisites = {"ei-tank"}

ei_lib.recipe_new("steel-storage-tank", {
    {type="item", name="storage-tank", amount=3},
    {type="item", name="steel-plate", amount=15},
    {type="item", name="ei-iron-mechanical-parts", amount=20}
})

--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["extra-storage-tank-minibuffer"] then
    return
end

--====================================================================================================
--CHANGES
--====================================================================================================

ei_lib.raw.technology["minibuffer"].age = "steam-age"
ei_lib.raw.technology["minibuffer"].prerequisites = {"ei-tank"}