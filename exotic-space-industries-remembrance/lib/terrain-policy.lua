--==============================================================================
-- ESIR FILE MAP
-- owns: immutable planetary transition and species eligibility rules
-- loaded_by: mining/ecology owners
-- cadence: none; immutable lookup and lifecycle validation
-- forwarded_events: owner-routed callbacks only
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner lifecycle and configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- Immutable terrain vocabulary shared by depletion scars and natural ecology.
-- Transitions originate in ESIR's Mining scars integration (Mylon); this is not
-- a reverse recovery graph. Runtime owners retain their own causes and history.
local model = {}
model.transitions = {
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
	["highland-dark-rock"]="midland-cracked-lichen-dark",

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
model.transitions["ei-gaia-grass-2"] = "ei-gaia-grass-1"
model.transitions["ei-gaia-grass-2-var"] = "ei-gaia-grass-1"
model.transitions["ei-gaia-grass-2-var-2"] = "ei-gaia-grass-1-var"
model.transitions["ei-gaia-grass-1"] = "ei-gaia-rock-1"
model.transitions["ei-gaia-grass-1-var"] = "ei-gaia-rock-1"
model.planets = {nauvis=true,gaia=true,vulcanus=true,gleba=true,fulgora=true,aquilo=true}
model.drills = {"ei-burner-quarry","ei-steam-quarry","ei-electric-quarry","big-mining-drill"}
model.freshwater = {water=true,deepwater=true,["water-green"]=true,["deepwater-green"]=true}
model.coast = {["sand-1"]=true,["sand-2"]=true,["sand-3"]=true}
model.dead_trees = {["dry-tree"]=true,["dead-dry-hairy-tree"]=true,["dead-grey-trunk"]=true,["dead-tree-desert"]=true,["dry-hairy-tree"]=true}
model.natural_trees = {}
for i=1,9 do model.natural_trees[string.format("tree-%02d",i)]=true end
model.natural_trees["tree-02-red"]=true
model.natural_trees["tree-06-brown"]=true
model.natural_trees["tree-08-brown"]=true
model.natural_trees["tree-08-red"]=true
model.natural_trees["tree-09-brown"]=true
model.natural_trees["tree-09-red"]=true
for i=1,6 do model.natural_trees[string.format("ei-gaia-tree-%02d",i)]=true end
for name in pairs(model.dead_trees) do model.natural_trees[name]=true end
model.natural_trees["ashland-lichen-tree"]=true
model.natural_trees["ashland-lichen-tree-flaming"]=true
model.gleba_trees={cuttlepop=true,slipstack=true,funneltrunk=true,hairyclubnub=true,teflilly=true,
    lickmaw=true,stingfrond=true,boompuff=true,sunnycomb=true,["water-cane"]=true}
for name in pairs(model.gleba_trees) do model.natural_trees[name]=true end
model.natural_tiles={}
for source,target in pairs(model.transitions) do model.natural_tiles[source]=true;model.natural_tiles[target]=true end
-- Additional wild-tree habitats; fruit-growing soils remain excluded.
model.natural_tiles["wetland-blue-slime"]=true
model.natural_tiles["gleba-deep-lake"]=true

---@param name string
---@param planet string
---@return boolean
function model.native_tree(name,planet)
    if not model.natural_trees[name] then return false end
    if name:find("^ei%-gaia%-tree%-") then return planet=="gaia" end
    if name:find("^ashland%-lichen%-tree") then return planet=="vulcanus" end
    if model.gleba_trees[name] then return planet=="gleba" end
    return planet=="nauvis"
end

---@param surface LuaSurface
---@return string|nil
function model.planet(surface)
    if not surface or not surface.valid or surface.platform then return nil end
    local planet=surface.planet
    if not planet then return nil end
    local name=planet.name
    if model.planets[name] then return name end
end

function model.family(name)
    if name=="gleba-deep-lake" then return "gleba" end
    if name:find("^ei%-gaia%-") then return "gaia" end
    if name:find("^volcanic%-") then return "vulcanus" end
    if name:find("^fulgoran%-") then return "fulgora" end
    if name:find("^snow%-") or name=="ice-smooth" then return "aquilo" end
    if name:find("^highland%-") or name:find("^midland%-") or name:find("^lowland%-") or name:find("^wetland%-") then return "gleba" end
    return "nauvis"
end

---@param name string
---@param planet string
---@return string|nil
function model.next_tile(name,planet)
    if model.family(name)~=planet then return nil end
    return model.transitions[name]
end

function model.compile(tile_prototypes)
    local valid,missing={},{}
    for source,target in pairs(model.transitions) do
        if tile_prototypes[source] and tile_prototypes[target] then valid[source]=target
        elseif tile_prototypes[source] then missing[#missing+1]=source.." -> "..target end
    end
    table.sort(missing)
    -- Finite acyclic routes keep sparse recovery record size bounded.
    for source in pairs(valid) do
        local seen,cursor={},source
        for _=1,32 do
            if not cursor then break end
            assert(not seen[cursor],"Terrain transition cycle: "..source)
            seen[cursor]=true;cursor=valid[cursor]
        end
        assert(cursor==nil,"Terrain transition path exceeds 32: "..source)
    end
    return valid,missing
end
return model
