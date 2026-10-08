--==============================================================================
-- ESIR FILE MAP
-- owns: terrain settings schema, intensity and deterministic work limits
-- loaded_by: settings.lua, terrain runtime, admin ecology
-- cadence: settings/lifecycle changes only
-- forwarded_events: owner-routed callbacks only
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner lifecycle and configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- Settings are resolved at lifecycle boundaries, never in the ecology hot path.
---@class EsirTerrainSetting
---@field key string
---@field type "boolean"|"integer"|"number"|"enum"
---@field default boolean|number|string
---@field min number?
---@field max number?
---@field values string[]?
---@field surface boolean
---@field setting_name string
---@field label LocalisedString
local model={schema={},definitions={},by_key={},planets={"nauvis","gaia","vulcanus","gleba","fulgora","aquilo"}}
local types={boolean="bool-setting",integer="int-setting",number="double-setting",enum="string-setting"}
local function define(key,kind,default,min,max,values,surface)
    local name="ei-terrain-"..key:gsub("_","-")
    local row={key=key,type=kind,default=default,min=min,max=max,values=values,surface=surface~=false,setting_name=name,label={"mod-setting-name."..name}}
    model.schema[#model.schema+1]=row;model.by_key[key]=row
    local entry={name=name,type=types[kind],setting_type="runtime-global",default_value=default,order=string.format("d-terrain-%03d",#model.schema)}
    entry.minimum_value=min;entry.maximum_value=max;entry.allowed_values=values
    model.definitions[#model.definitions+1]=entry
end
model.definitions[1]={type="bool-setting",name="ei-terrain-evolution-enabled",setting_type="startup",default_value=true,order="d-terrain-000"}
define("active","boolean",true)
define("intensity","enum","restrained",nil,nil,{"restrained","standard","severe","custom"})
define("performance","enum","lean",nil,nil,{"ultra-low","low","lean","balanced","detailed","high-fidelity","ultra-high-fidelity","custom"},false)
define("custom_rate_multiplier","number",1,0.05,4)
for _,key in ipairs({"degradation","recovery","mining_scars","tree_stress","tree_regrowth","thermal_scars","seasonal_daylight"}) do define(key,"boolean",true) end
for _,key in ipairs({"mining_recovery","aging","rot","flood","drought","cliffs","blood","paving","seasonal_ecology"}) do define(key,"boolean",false) end
define("wildfire","enum","off",nil,nil,{"off","contained","spreading"})
for _,planet in ipairs(model.planets) do define("planet_"..planet,"boolean",true,nil,nil,nil,false) end
local numbers={
    {"pollution_high",100,1,100000},{"pollution_low",25,0,99999},
    {"mining_probability",0.7,0,1},{"wildfire_probability",0.01,0,1},
    {"flood_probability",0.02,0,1},{"drought_probability",0.02,0,1},
    {"cliff_probability",0.01,0,1},{"blood_probability",0.1,0,1},{"paving_probability",0.01,0,1},
    {"axial_tilt",23.5,0,60},{"latitude",45,-75,75},{"season_strength",0.25,0,0.75},
}
for _,r in ipairs(numbers) do define(r[1],"number",r[2],r[3],r[4]) end
local integers={
    {"dirty_seconds",300,1,86400},{"clean_seconds",600,1,86400},{"soil_seconds",60,1,86400},
    {"recovery_seconds",240,1,86400},{"mining_radius",56,0,128},{"mining_patch_radius",3,1,8},
    {"tree_growth_seconds",600,1,86400},{"tree_density_limit",16,1,64},{"tree_neighborhood",4,1,8},
    {"tree_stress_seconds",300,1,86400},{"tree_aging_seconds",3600,60,604800},
    {"tree_rot_seconds",1800,60,604800},{"hazard_seconds",600,30,86400},
    {"wildfire_radius",2,1,8},{"hazard_radius",1,1,4},{"calendar_days",360,30,3600},
    {"protection_buffer",2,0,16},{"max_depth",32,1,32},{"seed_distance",8,1,16},
}
for _,r in ipairs(integers) do define(r[1],"integer",r[2],r[3],r[4]) end
-- blueprint-ref: .codex/esir/blueprints/terrain-evolution.md#scheduling
-- Smaller, frequent services do not multiply the indivisible entity-query rate.
-- Candidates retain room for Gaia's atomic 27-credit biome/placement operation.
model.performance_presets={
    ["ultra-low"]={interval=16,search_interval=128,cold_chunks=1,active_chunks=2,candidates=32,histories=1,writes=1,recovery_reserved=1,searches=1,result_limit=32,events=1,mining_queries=1,mining_candidates=32,admissions=4,active_cap=512,pending_cap=256,tile_history_cap=8192,tree_history_cap=1024},
    low={interval=16,search_interval=64,cold_chunks=1,active_chunks=2,candidates=32,histories=2,writes=2,recovery_reserved=1,searches=1,result_limit=32,events=2,mining_queries=1,mining_candidates=32,admissions=8,active_cap=1024,pending_cap=512,tile_history_cap=16384,tree_history_cap=2048},
    lean={interval=16,search_interval=32,cold_chunks=1,active_chunks=2,candidates=32,histories=4,writes=4,recovery_reserved=2,searches=1,result_limit=32,events=4,mining_queries=1,mining_candidates=32,admissions=16,active_cap=2048,pending_cap=1024,tile_history_cap=32768,tree_history_cap=4096},
    balanced={interval=8,search_interval=16,cold_chunks=1,active_chunks=2,candidates=32,histories=4,writes=4,recovery_reserved=2,searches=1,result_limit=32,events=4,mining_queries=1,mining_candidates=32,admissions=16,active_cap=4096,pending_cap=2048,tile_history_cap=65536,tree_history_cap=8192},
    detailed={interval=4,search_interval=8,cold_chunks=1,active_chunks=2,candidates=32,histories=8,writes=4,recovery_reserved=2,searches=1,result_limit=32,events=8,mining_queries=1,mining_candidates=32,admissions=16,active_cap=8192,pending_cap=4096,tile_history_cap=131072,tree_history_cap=16384},
    ["high-fidelity"]={interval=2,search_interval=4,cold_chunks=1,active_chunks=4,candidates=32,histories=8,writes=4,recovery_reserved=2,searches=1,result_limit=32,events=8,mining_queries=1,mining_candidates=32,admissions=24,active_cap=8192,pending_cap=4096,tile_history_cap=131072,tree_history_cap=16384},
    ["ultra-high-fidelity"]={interval=1,search_interval=2,cold_chunks=2,active_chunks=8,candidates=64,histories=16,writes=8,recovery_reserved=4,searches=2,result_limit=32,events=16,mining_queries=1,mining_candidates=32,admissions=32,active_cap=16384,pending_cap=8192,tile_history_cap=262144,tree_history_cap=32768},
}
local budgets={"interval","search_interval","cold_chunks","active_chunks","candidates","histories","writes","recovery_reserved","searches","result_limit","events","mining_queries","mining_candidates","admissions","active_cap","pending_cap","tile_history_cap","tree_history_cap"}
-- Custom maxima remain independent of smaller named batches; formerly valid
-- upper limits survive preset retuning. Minima keep mandatory work reachable.
local minima={interval=1,search_interval=1,active_chunks=2,candidates=27,mining_queries=0}
local maxima={interval=256,search_interval=256,cold_chunks=8,active_chunks=16,candidates=128,histories=128,writes=32,recovery_reserved=16,searches=4,result_limit=32,events=32,mining_queries=1,mining_candidates=32,admissions=32,active_cap=16384,pending_cap=8192,tile_history_cap=262144,tree_history_cap=32768}
for _,key in ipairs(budgets) do define(key,"integer",model.performance_presets.lean[key],minima[key] or 1,maxima[key],nil,false) end

local function checked(row,value)
    if row.type=="boolean" then if type(value)=="boolean" then return value end
    elseif row.type=="enum" then for _,v in ipairs(row.values) do if value==v then return value end end
    elseif type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
        and value>=row.min and value<=row.max and (row.type~="integer" or value==math.floor(value)) then return value end
end
local function finish(snapshot)
    local preset=model.performance_presets[snapshot.performance]
    if preset then for _,key in ipairs(budgets) do snapshot[key]=preset[key] end end
    snapshot.recovery_reserved=math.min(snapshot.recovery_reserved,snapshot.writes)
    snapshot.tree_density_limit=math.min(snapshot.tree_density_limit,snapshot.result_limit)
    snapshot.intensity_multiplier=({restrained=0.5,standard=1,severe=2})[snapshot.intensity] or snapshot.custom_rate_multiplier
    return snapshot
end
---@param base table
---@param overrides table|nil
---@param surface_only boolean|nil
---@return table, table[]
function model.apply_overrides(base,overrides,surface_only)
    local result,errors={enabled=base.enabled~=false},{}
    for _,r in ipairs(model.schema) do
        local v=base[r.key];if v==nil then v=r.default end
        result[r.key]=v
    end
    for key,value in pairs(overrides or {}) do
        local row=model.by_key[key]
        local value_checked=row and checked(row,value)
        if not row or (surface_only and not row.surface) or value_checked==nil then
            errors[#errors+1]={key=key,reason="invalid"}
        else result[key]=value_checked end
    end
    if result.pollution_low>=result.pollution_high then
        errors[#errors+1]={key="pollution_low",reason="threshold-order"}
        result.pollution_low=math.min(25,result.pollution_high-1)
    end
    return finish(result),errors
end
function model.resolve(runtime_values,startup_values)
    local runtime=runtime_values or settings.global
    local startup=startup_values or settings.startup
    local values={}
    for _,r in ipairs(model.schema) do
        local v=runtime[r.key];if v==nil then v=runtime[r.setting_name] end
        if type(v)=="table" then v=v.value end
        if v~=nil then values[r.key]=v end
    end
    local master=startup["ei-terrain-evolution-enabled"]
    if type(master)=="table" then master=master.value end
    return model.apply_overrides({enabled=master~=false},values)
end
function model.resolve_surface(base,planet,overrides)
    local result,errors=model.apply_overrides(base,overrides,true)
    result.planet=planet
    result.enabled=base.enabled==true and result.active and base["planet_"..tostring(planet)]==true
    result.year_days=result.calendar_days;result.tilt=result.axial_tilt
    if planet=="fulgora" then result.seasonal_daylight=false end
    return result,errors
end
return model
