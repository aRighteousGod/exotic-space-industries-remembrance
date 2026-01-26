ei_lib = require("lib/lib")

ei_lib.raw["car"]["car"].inventory_size = 14
ei_lib.raw["car"]["tank"].inventory_size = 16

if mods["aai-programmable-vehicles"] then
	ei_lib.raw["container"]["vehicle-depot-chest"].inventory_size = 18
end

if mods["aai-vehicles-hauler"] then
	ei_lib.raw["car"]["vehicle-hauler"].inventory_size = 18
end

if mods["aai-vehicles-miner"] then
	local inventory_size = {8, 12, 16, 24, 32}
	for i = 1,5 do
		local suffix = (i > 1) and ("-mk" .. i) or ""
		ei_lib.raw["car"]["vehicle-miner"..suffix].inventory_size
			= inventory_size[i]
	end
end

if mods["aai-vehicles-ironclad"] then
	ei_lib.raw["car"]["ironclad"].inventory_size = 16
end 
if mods["ironclad-gunboat-and-mortar-turret-fork"] then
	ei_lib.raw["car"]["ironclad-gunboat"].inventory_size = 16
end 