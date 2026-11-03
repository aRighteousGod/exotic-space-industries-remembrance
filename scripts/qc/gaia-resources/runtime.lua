-- Private native fixture appended in the gameplay mod's runtime environment.
local support = require("__esir-qc-native-tests__.support")
local mapgen = require("scripts/control/gaia-mapgen-data")
local parameters = support.config.parameters
local seed = parameters.seed
local size = parameters.area_size
local resources = parameters.resources
local half = size / 2
local chunks_per_side = size / 32
local chunk_count = chunks_per_side * chunks_per_side
local surface, result
local next_chunk = 0
local checks = {}

local function check(name, passed, detail)
    checks[#checks + 1] = {name=name, passed=passed == true, detail=detail and tostring(detail)}
end

---@param tick integer
---@return EsirNativeResult
local function step(tick)
    if result then return result end
    if not surface then
        assert(seed == 1000 and size == 4096, "Unexpected Gaia acceptance parameters")
        assert(#resources == 6, "Required Gaia resource inventory is incomplete")
        assert(not game.surfaces["esir-qc-gaia-runtime"], "Fixture surface already exists")
        -- Supplying preserved settings selects the historical saved-world branch.
        -- This case exercises fresh current defaults, then pins its test seed.
        local map_settings = mapgen.get_map_gen_settings()
        map_settings.seed = seed
        surface = game.create_surface("esir-qc-gaia-runtime", map_settings)
        check("runtime-effective-seed", surface.map_gen_settings.seed == seed, surface.map_gen_settings.seed)
        local expressions = surface.map_gen_settings.property_expression_names
        check("runtime-current-generation-revision",
            expressions["ei-enemy-generation-revision"] == "ei-enemy-generation-native21")
        check("runtime-gaia-terrain", expressions.elevation == "gaia_elevation"
            and expressions.moisture == "gaia_moisture" and expressions.temperature == "gaia_temperature")
        check("accumulator-cost-setting-off", settings.startup["link-multiplier-to-cost"].value == false)
        check("accumulator-capacity-setting", settings.startup["accumulator-power-capacity"].value == 10)
    end

    -- A finite batch keeps the Lua deadline observable between native generation calls.
    local last_chunk = math.min(next_chunk + 64, chunk_count)
    for index = next_chunk, last_chunk - 1 do
        local x = index % chunks_per_side - chunks_per_side / 2
        local y = math.floor(index / chunks_per_side) - chunks_per_side / 2
        surface.request_to_generate_chunks({x=x * 32 + 16, y=y * 32 + 16}, 0)
    end
    surface.force_generate_chunk_requests()
    for index = next_chunk, last_chunk - 1 do
        local position = {x=index % chunks_per_side - chunks_per_side / 2,
            y=math.floor(index / chunks_per_side) - chunks_per_side / 2}
        assert(surface.is_chunk_generated(position), "Requested Gaia chunk did not complete")
    end
    next_chunk = last_chunk
    if next_chunk < chunk_count then return {complete=false} end

    local bounds = {{-half, -half}, {half, half}}
    local counts = {}
    for _, name in ipairs(resources) do
        local count = surface.count_entities_filtered{area=bounds, name=name}
        counts[name] = count
        check("resource-present-" .. name, count >= 1, count)
    end
    check("bounded-generation-complete", next_chunk == 16384, next_chunk)
    local gaia_tiles = {}
    for name in pairs(mapgen.tile_settings) do gaia_tiles[#gaia_tiles + 1] = name end
    local gaia_tile_count = surface.count_tiles_filtered{area=bounds, name=gaia_tiles}
    check("runtime-gaia-tiles-present", gaia_tile_count > 0, gaia_tile_count)
    result = {complete=true, checks=checks, metrics={seed=seed, area_size=size, bounds=bounds,
        surface_name=surface.name, gaia_tile_count=gaia_tile_count,
        generated_chunks=next_chunk, resource_counts=counts, settings=surface.map_gen_settings, finished_tick=tick}}
    return result
end

remote.add_interface("esir-native-tests", {step=step})
