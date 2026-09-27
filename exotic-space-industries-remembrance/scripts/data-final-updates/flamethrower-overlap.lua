--==============================================================================
-- ESIR FILE MAP
-- owns: creation notifications for supported flamethrower stickers/ground fires
-- loaded_by: data-final-fixes.lua, after thrower-performance's private copies
-- cadence: data stage only; runtime cleanup lives in control/flamethrower-fuels
--==============================================================================
local catalog=require("lib/flamethrower-fuels")
local visited={}

-- Follow trigger tables, including other weapons referencing vanilla fire.
-- Shared tables are visited once; unrelated trigger flags remain untouched.
---@param node table
local function notify_creation(node)
    if visited[node] then return end
    visited[node]=true
    if (node.type=="create-sticker" and catalog.fire_stickers[node.sticker])
        or (node.type=="create-fire" and catalog.ground_fires[node.entity_name]) then
        node.trigger_created_entity=true
    end
    for _,value in pairs(node) do
        if type(value)=="table" then notify_creation(value) end
    end
end
notify_creation(data.raw)
