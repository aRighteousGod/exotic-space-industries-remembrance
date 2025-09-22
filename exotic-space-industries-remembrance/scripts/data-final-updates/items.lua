--[[
data.raw['tool']['space-science-pack'].icon = data.raw['item']['ei-space-data'].icon
data.raw['tool']['space-science-pack'].pictures = data.raw['item']['ei-space-data'].pictures
data.raw['tool']['space-science-pack'].icon_size = data.raw['item']['ei-space-data'].icon_size
]]

data.raw['item']["iron-plate"].icon = ei_graphics_item_path.."iron-ingot.png"
data.raw['item']["copper-plate"].icon = ei_graphics_item_path.."copper-ingot.png"
data.raw['item']["steel-plate"].icon = ei_graphics_item_path.."steel-ingot.png"


data.raw['item']["iron-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["copper-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["steel-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-gold-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-lead-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-neodym-ingot"].subgroup = "ei-refining-ingot"

ei_lib.disable("automation-science-pack")
ei_lib.disable("logistic-science-pack")
ei_lib.disable("chemical-science-pack")
ei_lib.disable("military-science-pack")
ei_lib.disable("production-science-pack")
ei_lib.disable("utility-science-pack")

--[[
for _, item in pairs(data.raw.item) do
--  if endswith(item.name,"-barrel") then item.stack_size = 100 end
  if item.type == "gun" then item.stack_size = 1 end
  if item.subgroup == "gun" then item.stack_size = 1 end
end
]]
local cap_size = {
    "logistic-container",
    "container"
}
for _,entity_class in pairs(cap_size) do
    for _,entity in pairs(data.raw[entity_class]) do
        if entity and entity.inventory_size > 64 then
            entity.inventory_size = 64
        end
    end
end

--rocket stack size adjustments
--from Rockets Launch Stacks @hopefuldecay
-- Minimum amount of stacks a rocket should carry.
local weightmultiplier = 5
-- Set of possible flags
local possibleFlags = { "draw-logistic-overlay", "hidden", "always-show", "hide-from-bonus-gui", "hide-from-fuel-tooltip", "not-stackable", "can-extend-inventory", "primary-place-result", "mod-openable", "only-in-cursor", "spawnable" }
-- Set for item types
local itemTypes = {"item", "ammo", "capsule", "module", "tool", "repair-tool", "item-with-entity-data", "rail-planner", "rail-signal", "rail-chain-signal", "gun"}
-- Check set return true/false
function table.contains(table, element)
	for _, value in ipairs(table) do
		if value == element then
			return true
		end
	end
	return false
end
-- Loop through items and check flags
for _, itemType in pairs(itemTypes) do
    for _, item in pairs(data.raw[itemType]) do
        local shouldChange = true
        if item.flags then
            for _, flag in ipairs(item.flags) do
                --if table.contains(possibleFlags, flag) then
                    if flag == "not-stackable" then
                        shouldChange = false
                        break
                    --end
                end
            end
        end
        if shouldChange then
			if item.weight ~= nil then
				if item.weight > 1000/item.stack_size/weightmultiplier * kg then
					item.weight = 1000/item.stack_size/weightmultiplier * kg
				end
			elseif item.stack_size ~= nil then
				item.weight = 1000/item.stack_size/weightmultiplier * kg
			end
        end
    end
end

--don't make ash from rocket nuclear fusion
local removeash = {
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-rocket-fuel",
    "ei-fusion-fuel"
}
for _,item in pairs(data.raw.item) do
    if item.fuel_category then
        if item.burnt_result == "atan-ash" and ei_lib.table_contains_value(removeash,item.fuel_category) then
            item.burnt_result = nil
        end
    end
end