--==============================================================================
-- ESIR FILE MAP
-- owns: shared spider vehicle progression, naming, and balance catalog
-- loaded_by: prototypes/spider-vehicles.lua, scripts/control/spider-vehicles.lua
-- cadence: module load; pure configuration queries
-- forwarded_events: none
-- storage_roots: none
-- rebuild_on: data/control reload
--==============================================================================
local model = {}
model.proxy_prefix="spidertron-enhancements-dummy-"

---@param name string
---@return boolean
function model.is_proxy(name)
    return name:sub(1,#model.proxy_prefix)==model.proxy_prefix
end

---@class ESIRSpiderProfile
---@field item string
---@field source string
---@field health integer[]
---@field cargo integer[]
---@field fuel integer[]
---@field grids integer[][]
---@field power string
model.families = {"scout", "assault", "rocket"}
---@type table<string, ESIRSpiderProfile>
model.profiles = {
    scout = {item="ei-scout-spidertron",source="ei-scout-spidertron",health={1000,1250,1500},cargo={40,60,80},fuel={2,3,4},grids={{4,4},{6,4},{6,6}},power="250kW"},
    assault = {item="assault_spidertron",source="assault_spidertron",health={3000,3500,4000},cargo={80,100,120},fuel={3,4,6},grids={{8,6},{10,6},{10,8}},power="1MW"},
    rocket = {item="spidertron",source="spidertron",health={3000,3500,4000},cargo={80,100,120},fuel={3,4,6},grids={{10,6},{12,6},{12,8}},power="1MW"},
}
model.fuel_categories = {"chemical","ei-rocket-fuel","ei-nuclear-fuel","ei-nuclear-fuel-cell","ei-fusion-fuel","ei-diesel-fuel"}
model.chassis = {"hull","cargo","fuel","efficiency","armor","grid"}
model.branch_order = {"cannon","mg","flamer","artillery","rocket","doeworks"}
-- Each row is the complete cumulative state: cooldown, range, minimum range.
model.weapons = {
    cannon = {{100,30,5},{80,30,5},{60,30,5},{60,35,5},{60,40,5},{60,40,0}},
    mg = {{15,25,0},{2,25,0},{0.5,40,0},{0.5,43,0},{0.5,45,0}},
    flamer = {{1,12,3},{1,15,3},{1,18,3},{1,18,2},{1,18,1}},
    artillery = {false,{250,80,20},{200,80,20},{160,80,20},{160,100,20},{160,120,20}},
    rocket = {{60,36,0},{60,42,0},{60,48,0},{48,48,0},{36,48,0}},
    doeworks = {false,{30,115,35},{20,115,35},{10,115,35},{1.5,115,35}},
}
model.upgrade_names = {
    cannon={"loader-1","loader-2","range-1","range-2","close-engagement"},
    mg={"minigun","heavy-minigun","tracking-1","tracking-2"},
    flamer={"pressure-1","pressure-2","nozzle-1","nozzle-2"},
    artillery={"mount","loader-1","loader-2","range-1","range-2"},
    rocket={"range-1","range-2","reload-1","reload-2"},
    doeworks={"mount","rapid-fire-1","rapid-fire-2","rapid-fire-3"},
}
model.simulation_steps = {cannon=2,mg=1,flamer=2,artillery=2,rocket=2,doeworks=3}
model.smoke = {charge="ei-assault-smoke-charge",technology="ei-assault-smokescreen",cooldown=1800,duration=360,radius=8,interval=60,limit=64}
model.turns = {cannon={shots=2},mg={ticks=120},flamer={ticks=180},artillery={shots=1},rocket={shots=4},doeworks={ticks=90}}
model.groups = {assault={"cannon","mg","flamer","artillery"},rocket={"rocket","doeworks"}}
model.selection = {active_interval=15,idle_interval=60,searches_per_tick=8}

---@param branch string
---@param level integer
---@return string
function model.weapon_technology(branch, level)
    return "ei-spider-"..branch.."-"..model.upgrade_names[branch][level]
end

---@param chassis integer
---@return integer
function model.grid_tier(chassis)
    return chassis >= 12 and 3 or (chassis >= 6 and 2 or 1)
end

---@param family string
---@param tier integer
---@return string
function model.stored_item(family, tier)
    return tier == 1 and model.profiles[family].item or "ei-stored-"..family.."-spidertron-"..tier
end

---@param family string
---@param state table<string, integer>
---@param mode "native"|"hold"|"smart"?
---@return string
function model.variant_name(family, state, mode)
    local chassis = state.chassis or 0
    if family == "scout" then return "ei-spider-scout-h"..chassis end
    local suffix=mode and mode~="native" and "-"..mode or ""
    if family == "rocket" then
        return "ei-spider-rocket-r"..(state.rocket or 0).."-d"..(state.doeworks or 0).."-h"..chassis..suffix
    end
    return "ei-spider-assault-c"..(state.cannon or 0).."-m"..(state.mg or 0).."-f"..(state.flamer or 0).."-a"..(state.artillery or 0).."-h"..chassis..suffix
end

---@param name string
---@return "native"|"hold"|"smart"
function model.mode(name)
    return name:match("%-smart$") and "smart" or (name:match("%-hold$") and "hold" or "native")
end

---@param family string
---@param slot integer
---@return string?
function model.slot_group(family,slot)
    if family=="assault" then return model.groups.assault[slot] end
    if family=="rocket" then return slot<=4 and "rocket" or (slot==5 and "doeworks" or nil) end
end

---@class ESIRSpiderPreferences
---@field cycling boolean
---@field special boolean
---@field selected_slot integer?

---@param family string
---@param researched table<string, integer|boolean>
---@param preferences ESIRSpiderPreferences
---@param smart boolean
---@return string
function model.configured_name(family,researched,preferences,smart)
    local configuration={}
    for key,value in pairs(researched) do configuration[key]=value end
    if not preferences.special then
        if family=="assault" then configuration.artillery=0 end
        if family=="rocket" then configuration.doeworks=0 end
    end
    local mode="native"
    if not preferences.cycling then mode="hold"
    elseif smart then mode=family=="rocket" and "smart" or "hold" end
    return model.variant_name(family,configuration,mode)
end

---@param name string
---@return string? family
function model.family(name)
    if model.is_proxy(name) then name=name:sub(#model.proxy_prefix+1) end
    if name == "spidertron" then return "rocket" end
    if name == "assault_spidertron" then return "assault" end
    if name == "ei-scout-spidertron" then return "scout" end
    local family = name:match("^ei%-spider%-(%a+)%-")
    return model.profiles[family] and family or nil
end

---@param force LuaForce
---@return table<string, integer|boolean>
function model.researched_state(force)
    local state = {chassis=0,smoke=false}
    for level=1,12 do
        local tech=force.technologies["ei-spider-chassis-"..level]
        if not tech or not tech.researched then break end
        state.chassis=level
    end
    for _,branch in ipairs(model.branch_order) do
        state[branch]=0
        for level=1,#model.upgrade_names[branch] do
            local tech=force.technologies[model.weapon_technology(branch,level)]
            if not tech or not tech.researched then break end
            state[branch]=level
        end
    end
    local smoke=force.technologies[model.smoke.technology]
    state.smoke=smoke and smoke.researched or false
    return state
end

return model
