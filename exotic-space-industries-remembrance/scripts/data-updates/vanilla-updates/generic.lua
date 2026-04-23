local ei_lib = require("lib/lib")

-- since there is no iron gear used in EI use iron-mechanical parts instead
for i,v in pairs(data.raw["recipe"]) do
    ei_lib.recipe_swap(i, "iron-gear-wheel", "ei-iron-mechanical-parts")
    ei_lib.recipe_swap(i, "iron-stick", "ei-copper-mechanical-parts")
end

--MINING
------------------------------------------------------------------------------------------------------
local oreswaps = {
    ["uranium-ore"] = "ei-poor-uranium-chunk",
    ["iron-ore"] = "ei-poor-iron-chunk",
    ["copper-ore"] = "ei-poor-copper-chunk"
}
-- set output of copper and iron ore to ore chunks
for _,patch in pairs(data.raw.resource) do
    if patch and patch.minable then
        if patch.minable.result then
            if oreswaps[patch.minable.result] then
                log("ei oreswap: swapping: "..patch.minable.result.." for: "..oreswaps[patch.minable.result].." in patch: "..patch.name)
                patch.minable.result = oreswaps[patch.minable.result]
            end
        elseif patch.minable.results then
            for _,resource in pairs(patch.minable.results) do
                if oreswaps[resource] then
                    log("ei oreswap: swapping: "..resource.." for: "..oreswaps[resource].." in patch: "..patch)
                    resource = oreswaps[resource]
                end
            end
        end
    end
end

--ei_lib.raw["resource"]["iron-ore"].minable.result = "ei-poor-iron-chunk"
--ei_lib.raw["resource"]["copper-ore"].minable.result = "ei-poor-copper-chunk"


--Fulgora ruins, scrap recycling, previously below, can now be handled with merge_item
-----------------------------------------------------------------------------------------------------
--[[
replaced = {
    ["iron-gear-wheel"] = "ei-iron-mechanical-parts",
    ["iron-stick"] = "ei-iron-beam"
}

for ruin_name, ruin in pairs(data.raw["simple-entity"]) do
  if ruin.minable and ruin.minable.results then
    for i, result in ipairs(ruin.minable.results) do
      if result.type == "item" then
        local replacement = replaced[result.name]
        if replacement then
          log("ei: Replacing '"..result.name.."' with '"..replacement.."' in ruin: " .. ruin_name)
          result.name = replacement
        end
      end
    end
  end
end

for i, result in ipairs(ei_lib.raw.recipe["scrap-recycling"].results) do
    if result.type == "item" then
        local replacement = replaced[result.name]
        if replacement then
            log("ei: Replacing '"..result.name.."' with '"..replacement.."' in scrap: ")
            result.name = replacement
        end
    end
end
]]
--[[
table.insert(data.raw['simple-entity']['fulgurite'].minable.results, {
  amount_max = 1,
  amount_min = 0,
  name = "ei-alien-seed",
  type = "item"
})
]]

------------------------------------------------------------------------------------------------------

-- set furnace result inv to 2, when they have the smelting crafting category
for i,v in pairs(data.raw["furnace"]) do
    if v.crafting_categories[1] == "smelting" then
        ei_lib.raw["furnace"][i].result_inventory_size = 2
        if v.energy_source then
            if v.energy_source.fuel_categories then
                table.insert(v.energy_source.fuel_categories,"ei-rocket-fuel")
            end
        end
    end
end
for _,reactor in pairs(data.raw.reactor) do
    if reactor and reactor.energy_source then
        if reactor.energy_source.type == "burner" then
            if ei_lib.table_contains_value(reactor.energy_source.fuel_categories,"chemical") then
                table.insert(reactor.energy_source.fuel_categories,"ei-rocket-fuel")
            end
        end
    end
end
