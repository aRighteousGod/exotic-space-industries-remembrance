
--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["Flow Control"] then
    return
end


local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--CHANGES
--====================================================================================================

-- make recipes of junctions disabled and add their unlocks to tech tree

data.raw.recipe["pipe-junction"].enabled = false
data.raw.recipe["pipe-elbow"].enabled = false
data.raw.recipe["pipe-straight"].enabled = false

ei_lib.add_unlock_recipe("fluid-handling","pipe-junction")
ei_lib.add_unlock_recipe("fluid-handling","pipe-elbow")
ei_lib.add_unlock_recipe("fluid-handling","pipe-straight")
