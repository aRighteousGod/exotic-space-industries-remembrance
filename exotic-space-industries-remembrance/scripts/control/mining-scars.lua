--====================================================================================================
-- MINING SCARS MODULE
-- originally from Mining scars by Mylon
-- Creates terrain degradation effects when resources are depleted by mining drills.
-- Only applies to: burner, steam, electric quarry, and big mining drills.
--====================================================================================================

local mining_scars = {}

-- Configuration
local SCAR_RADIUS = 56
local SCAR_SIZE_RADIUS = 3
local SCAR_PROBABILITY = 0.7

-- Drill types that trigger mining scars
local ENABLED_DRILL_TYPES = {
	["ei-burner-quarry"] = true,
	["ei-steam-quarry"] = true,
	["ei-electric-quarry"] = true,
	["big-mining-drill"] = true,
}

-- Terrain degradation progression table
local DIRT = {
	--Vanilla tiles
	["grass-1"]="grass-3",
	["grass-2"]="grass-3",
	["grass-3"]="grass-4",
	["grass-4"]="dirt-4",
	["dirt-4"]="dirt-6",
	["dirt-6"]="dirt-7",
	["dirt-7"]="dirt-5",
	["dirt-5"]="dirt-3",
	["dirt-3"]="dirt-1",
	["dirt-1"]="dirt-2",
	["dirt-2"]="red-desert-3",
	["red-desert-3"]="sand-3",
	["dry-dirt"]="dirt-2",
	["sand-3"]="sand-2",
	["sand-2"]="sand-1",

	["red-desert-0"]="red-desert-1",
	["red-desert-1"]="red-desert-2",
	["red-desert-2"]="red-desert-3",

	--Space Age Tiles
	--Volcanus
	["volcanic-cracks-hot"]=nil,
	["volcanic-cracks-warm"]="volcanic-cracks-hot",
	["volcanic-cracks"]="volcanic-cracks-warm",
	["volcanic-smooth-stone-warm"]="volcanic-cracks-warm",
	["volcanic-smooth-stone"]="volcanic-smooth-stone-warm",
	["volcanic-folds-warm"]="volcanic-smooth-stone-warm",
	["volcanic-folds"]="volcanic-folds-flat",

	["volcanic-folds-flat"]="volcanic-ash-cracks",
	["volcanic-jagged-ground"]="volcanic-soil-light",
	["volcanic-soil-dark"]=nil,
	["volcanic-soil-light"]="volcanic-soil-dark",
	["volcanic-pumice-stones"]="volcanic-ash-flats",
	["volcanic-ash-flats"]="volcanic-ash-light",
	["volcanic-ash-light"]="volcanic-ash-dark",
	["volcanic-ash-dark"]=nil,
	["volcanic-ash-soil"]="volcanic-soil-light",
	["volcanic-ash-cracks"]="volcanic-pumice-stones",

	--Gleba
	["highland-dark-rock-2"]="highland-dark-rock",
	["highland-yellow-rock"]="highland-dark-rock-2",
	["highland-dark-rock"]="midland-craked-lichen-dark",

	["midland-cracked-lichen-dull"]="midland-cracked-lichen",
	["midland-cracked-lichen"]="midland-cracked-lichen-dark",
	["midland-cracked-lichen-dark"]=nil,

	["wetland-light-green-slime"]="wetland-green-slime",
	["wetland-light-dead-skin"]="wetland-dead-skin",
	["wetland-pink-tentacle"]="wetland-red-tentacle",

	["lowland-olive-blubber"]="lowland-brown-blubber",
	["lowland-olive-blubber-2"]="lowland-olive-blubber",
	["lowland-olive-blubber-3"]="lowland-olive-blubber-2",
	["lowland-red-vein"]="lowland-red-vein-dead",
	["lowland-red-vein-2"]="lowland-red-vein",
	["lowland-red-vein-3"]="lowland-red-vein-2",
	["lowland-red-vein-4"]="lowland-red-vein-3",
	["lowland-red-vein-dead"]="lowland-red-infection",

	--Fulgora
	["fulgoran-sand"]="fulgoran-dust",
	["fulgoran-dust"]="fulgoran-dunes",
	["fulgoran-rock"]="fulgoran-sand",
	["fulgoran-walls"]="fulgoran-dunes",

	--Aquilo
	["snow-lumpy"]="snow-crests",
	["snow-crests"]="snow-flat",
	["snow-patchy"]="ice-smooth",

	--Alien Biome tiles
	["frozen-snow-0"]="frozen-snow-2",
	["frozen-snow-1"]="frozen-snow-2",
	["frozen-snow-3"]="frozen-snow-2",
	["frozen-snow-2"]="frozen-snow-4",

	["frozen-snow-9"]="frozen-snow-7",
	["frozen-snow-8"]="frozen-snow-7",
	["frozen-snow-7"]="frozen-snow-6",
	["frozen-snow-6"]="frozen-snow-5",

	["vegetation-green-grass-1"]="grass-3",
	["vegetation-green-grass-2"]="grass-4",
	["vegetation-green-grass-3"]="grass-2",
	["vegetation-green-grass-4"]="dirt-4",

	["vegetation-blue-grass-1"]="vegetation-blue-grass-2",
	["vegetation-blue-grass-2"]="mineral-aubergine-dirt-2",
	["vegetation-purple-grass-1"]="vegetation-purple-grass-2",
	["vegetation-purple-grass-2"]="mineral-aubergine-dirt-2",
	["mineral-aubergine-dirt-2"]="mineral-aubergine-dirt-3",
	["mineral-aubergine-dirt-3"]="mineral-aubergine-dirt-6",
	["mineral-aubergine-dirt-6"]="mineral-aubergine-dirt-4",
	["mineral-aubergine-dirt-4"]="mineral-aubergine-dirt-1",
	["mineral-aubergine-dirt-1"]="mineral-aubergine-dirt-5",
	["mineral-aubergine-dirt-5"]="mineral-aubergine-sand-2",
	["mineral-aubergine-sand-2"]="mineral-aubergine-sand-3",
	["mineral-aubergine-sand-3"]="mineral-aubergine-sand-1",

	["mineral-beige-dirt-2"]="mineral-beige-dirt-3",
	["mineral-beige-dirt-3"]="mineral-beige-dirt-6",
	["mineral-beige-dirt-6"]="mineral-beige-dirt-4",
	["mineral-beige-dirt-4"]="mineral-beige-dirt-1",
	["mineral-beige-dirt-1"]="mineral-beige-dirt-5",
	["mineral-beige-dirt-5"]="mineral-beige-sand-2",
	["mineral-beige-sand-2"]="mineral-beige-sand-3",
	["mineral-beige-sand-3"]="mineral-beige-sand-1",

	["vegetation-turquoise-grass-1"]="vegetation-turquoise-grass-2",
	["vegetation-turquoise-grass-2"]="mineral-black-dirt-2",
	["mineral-black-dirt-2"]="mineral-black-dirt-3",
	["mineral-black-dirt-3"]="mineral-black-dirt-6",
	["mineral-black-dirt-6"]="mineral-black-dirt-4",
	["mineral-black-dirt-4"]="mineral-black-dirt-1",
	["mineral-black-dirt-1"]="mineral-black-dirt-5",
	["mineral-black-dirt-5"]="mineral-black-sand-2",
	["mineral-black-sand-2"]="mineral-black-sand-3",
	["mineral-black-sand-3"]="mineral-black-sand-1",

	["vegetation-orange-grass-1"]="vegetation-orange-grass-2",
	["vegetation-orange-grass-2"]="mineral-brown-dirt-2",
	["mineral-brown-dirt-2"]="mineral-brown-dirt-3",
	["mineral-brown-dirt-3"]="mineral-brown-dirt-6",
	["mineral-brown-dirt-6"]="mineral-brown-dirt-4",
	["mineral-brown-dirt-4"]="mineral-brown-dirt-1",
	["mineral-brown-dirt-1"]="mineral-brown-dirt-5",
	["mineral-brown-dirt-5"]="mineral-brown-sand-2",
	["mineral-brown-sand-2"]="mineral-brown-sand-3",
	["mineral-brown-sand-3"]="mineral-brown-sand-1",

	["vegetation-yellow-grass-1"]="vegetation-yellow-grass-2",
	["vegetation-yellow-grass-2"]="mineral-cream-dirt-2",
	["mineral-cream-dirt-2"]="mineral-cream-dirt-3",
	["mineral-cream-dirt-3"]="mineral-cream-dirt-6",
	["mineral-cream-dirt-6"]="mineral-cream-dirt-4",
	["mineral-cream-dirt-4"]="mineral-cream-dirt-1",
	["mineral-cream-dirt-1"]="mineral-cream-dirt-5",
	["mineral-cream-dirt-5"]="mineral-cream-sand-2",
	["mineral-cream-sand-2"]="mineral-cream-sand-3",
	["mineral-cream-sand-3"]="mineral-cream-sand-1",

	["mineral-dustyrose-dirt-2"]="mineral-dustyrose-dirt-3",
	["mineral-dustyrose-dirt-3"]="mineral-dustyrose-dirt-6",
	["mineral-dustyrose-dirt-6"]="mineral-dustyrose-dirt-4",
	["mineral-dustyrose-dirt-4"]="mineral-dustyrose-dirt-1",
	["mineral-dustyrose-dirt-1"]="mineral-dustyrose-dirt-5",
	["mineral-dustyrose-dirt-5"]="mineral-dustyrose-sand-2",
	["mineral-dustyrose-sand-2"]="mineral-dustyrose-sand-3",
	["mineral-dustyrose-sand-3"]="mineral-dustyrose-sand-1",

	["mineral-grey-dirt-2"]="mineral-grey-dirt-3",
	["mineral-grey-dirt-3"]="mineral-grey-dirt-6",
	["mineral-grey-dirt-6"]="mineral-grey-dirt-4",
	["mineral-grey-dirt-4"]="mineral-grey-dirt-1",
	["mineral-grey-dirt-1"]="mineral-grey-dirt-5",
	["mineral-grey-dirt-5"]="mineral-grey-sand-2",
	["mineral-grey-sand-2"]="mineral-grey-sand-3",
	["mineral-grey-sand-3"]="mineral-grey-sand-1",

	["mineral-purple-dirt-2"]="mineral-purple-dirt-3",
	["mineral-purple-dirt-3"]="mineral-purple-dirt-6",
	["mineral-purple-dirt-6"]="mineral-purple-dirt-4",
	["mineral-purple-dirt-4"]="mineral-purple-dirt-1",
	["mineral-purple-dirt-1"]="mineral-purple-dirt-5",
	["mineral-purple-dirt-5"]="mineral-purple-sand-2",
	["mineral-purple-sand-2"]="mineral-purple-sand-3",
	["mineral-purple-sand-3"]="mineral-purple-sand-1",

	["vegetation-red-grass-1"]="vegetation-red-grass-2",
	["vegetation-red-grass-2"]="mineral-red-dirt-2",
	["mineral-red-dirt-2"]="mineral-red-dirt-3",
	["mineral-red-dirt-3"]="mineral-red-dirt-6",
	["mineral-red-dirt-6"]="mineral-red-dirt-4",
	["mineral-red-dirt-4"]="mineral-red-dirt-1",
	["mineral-red-dirt-1"]="mineral-red-dirt-5",
	["mineral-red-dirt-5"]="mineral-red-sand-2",
	["mineral-red-sand-2"]="mineral-red-sand-3",
	["mineral-red-sand-3"]="mineral-red-sand-1",

	["vegetation-olive-grass-1"]="vegetation-olive-grass-2",
	["vegetation-olive-grass-2"]="mineral-tan-dirt-2",
	["mineral-tan-dirt-2"]="mineral-tan-dirt-3",
	["mineral-tan-dirt-3"]="mineral-tan-dirt-6",
	["mineral-tan-dirt-6"]="mineral-tan-dirt-4",
	["mineral-tan-dirt-4"]="mineral-tan-dirt-1",
	["mineral-tan-dirt-1"]="mineral-tan-dirt-5",
	["mineral-tan-dirt-5"]="mineral-tan-sand-2",
	["mineral-tan-sand-2"]="mineral-tan-sand-3",
	["mineral-tan-sand-3"]="mineral-tan-sand-1",

	["vegetation-mauve-grass-1"]="vegetation-mauve-grass-2",
	["vegetation-mauve-grass-2"]="mineral-violet-dirt-2",
	["vegetation-violet-grass-1"]="vegetation-violet-grass-2",
	["vegetation-violet-grass-2"]="mineral-violet-dirt-2",
	["mineral-violet-dirt-2"]="mineral-violet-dirt-3",
	["mineral-violet-dirt-3"]="mineral-violet-dirt-6",
	["mineral-violet-dirt-6"]="mineral-violet-dirt-4",
	["mineral-violet-dirt-4"]="mineral-violet-dirt-1",
	["mineral-violet-dirt-1"]="mineral-violet-dirt-5",
	["mineral-violet-dirt-5"]="mineral-violet-sand-2",
	["mineral-violet-sand-2"]="mineral-violet-sand-3",
	["mineral-violet-sand-3"]="mineral-violet-sand-1",

	["mineral-white-dirt-2"]="mineral-white-dirt-3",
	["mineral-white-dirt-3"]="mineral-white-dirt-6",
	["mineral-white-dirt-6"]="mineral-white-dirt-4",
	["mineral-white-dirt-4"]="mineral-white-dirt-1",
	["mineral-white-dirt-1"]="mineral-white-dirt-5",
	["mineral-white-dirt-5"]="mineral-white-sand-2",
	["mineral-white-sand-2"]="mineral-white-sand-3",
	["mineral-white-sand-3"]="mineral-white-sand-1"
}

-- Decorative removal rules
local DECORATIVE_COLLISIONS = {
	{ tile="dirt", decorative="grass" },
	{ tile="sand", decorative="brown" },
	{ tile="dirt", decorative="green" },
	{ tile="sand", decorative="mud" },
	{ tile="dirt", decorative="garballo"}
}

local DECORATIVE_EXCEPTION = "desert"

--====================================================================================================
-- Create scars at the depleted resource location
--====================================================================================================
function mining_scars.on_resource_depleted(event)
	-- Validate that we have an entity
	if not (event.entity and not event.entity.prototype.infinite_resource) then return end

	-- Filter to enabled drill types only
	if not ENABLED_DRILL_TYPES[event.entity.name] then return end

	local surface = event.entity.surface
	
	-- Pick an epicenter of the effect using double-dice roll for weighted distribution
	local radius = SCAR_RADIUS * (math.random() + math.random() - 1)
	local angle = math.random() * math.pi
	local position = {
		x = event.entity.position.x + math.sin(angle) * radius,
		y = event.entity.position.y + math.cos(angle) * radius
	}
	
	-- Identify candidate scar positions
	local scar_positions = {}
	for x = position.x - SCAR_SIZE_RADIUS, position.x + SCAR_SIZE_RADIUS do
		for y = position.y - SCAR_SIZE_RADIUS, position.y + SCAR_SIZE_RADIUS do
			if (position.x - x)^2 + (position.y - y)^2 + 0.7 < SCAR_SIZE_RADIUS ^ 2 then
				if math.random() < SCAR_PROBABILITY then
					scar_positions[x] = scar_positions[x] or {}
					scar_positions[x][y] = true
				end
			end
		end
	end
	
	-- Build scar with valid tiles only
	local scar = {}
	for x, ys in pairs(scar_positions) do
		for y, _ in pairs(ys) do
			local validTile = surface.get_tile(x, y)
			if not validTile.collides_with("water_tile") and not validTile.hidden_tile then
				local newtile = DIRT[validTile.name]
				if prototypes.tile[newtile] then
					table.insert(scar, {name=newtile, position={x, y}})
				end
			end
		end
	end
	
	-- Apply tiles
	if #scar > 0 then
		surface.set_tiles(scar, true, false)
	end
	
	-- Remove decoratives that match collision rules
	for _, tile in pairs(scar) do
		for __, decorative in pairs(surface.find_decoratives_filtered{position=tile.position}) do
			for ___, collision in pairs(DECORATIVE_COLLISIONS) do
				if string.find(tile.name, collision.tile) and
				string.find(decorative.decorative.name, collision.decorative) and
				not string.find(decorative.decorative.name, DECORATIVE_EXCEPTION) then
					surface.destroy_decoratives{position=tile.position, exclude_soft=false}
				end
			end
		end
	end
end

return mining_scars
