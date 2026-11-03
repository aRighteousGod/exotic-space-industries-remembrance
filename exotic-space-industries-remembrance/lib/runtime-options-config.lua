--==============================================================================
-- ESIR FILE MAP
-- owns: runtime option allowlist, stage-safe migration names and native field metadata
-- loaded_by: settings.lua, runtime option owner and converted feature owners
-- cadence: settings stage and explicit runtime reads
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: native settings prototype metadata, explicit editor snapshot
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-options.md#contract
local lib = require("lib/lib")
local terrain = require("lib/terrain-evolution-config")
local passage = require("lib/factory-passage-config")
---@class EiRuntimeOption
---@field id string Native runtime-global name.
---@field legacy string? Hidden startup migration source.
---@field group string
---@field owner string
---@field label LocalisedString
---@field description LocalisedString
---@field locale_name string Existing setting locale namespace.
---@field type string?
---@field min number?
---@field max number?
---@field values any[]?
---@field default boolean|number|string?
local model = {entries={}, by_id={}, by_legacy={}, groups={
    "administration", "research", "pollution", "effects", "performance", "notifications",
    "ecology-presets", "ecology-processes", "ecology-planets", "ecology-seasons", "ecology-tuning", "ecology-budgets",
}}
local function add(name, group, owner, converted)
    local id = converted and name.."-runtime" or name
    local entry = {id=id, legacy=converted and name or nil, group=group, owner=owner,
        locale_name=name, label={"mod-setting-name."..name}, description={"mod-setting-description."..name}}
    model.entries[#model.entries+1]=entry;model.by_id[id]=entry
    if converted then model.by_legacy[name]=entry end
end
add("ei-admin-tools-enabled", "administration", "admin", true)
add("ei-tech-scaling-curveForm", "research", "research", true)
for _,key in ipairs{"mode","cap","visual-style"} do add("ei-rocket-launch-pollution-"..key,"pollution","rocket",true) end
add("ei-flammable-rupture-fidelity","effects","rupture",true)
add("ei-fluid-safety-ignored-entities","pollution","fluid",true)
for _,key in ipairs{"min","max"} do add("ei-fulgora-day-length-variation-"..key.."-multiplier","pollution","fulgora",true) end
for _,key in ipairs{"em_train_glow","em_train_glow_timetolive","em_charger_glow","em_charger_glow_timetolive",
    "em_updater_que","em_updater_que_width","em_updater_que_transparency","em_updater_que_timetolive"} do
    add("ei-"..key,"effects","em",true)
end
for _,key in ipairs{"max_updates_per_tick","ticks_per_full_update"} do add("ei-"..key,"performance","scheduler",true) end
add("ei-gaian-saucer-wake-visual-fidelity","effects","wake",true)
add("ei-emerald-apocalypse-hover-tank-hover-visual-fidelity","effects","hover",true)
add("ei-water-turret-fire-targeting","effects","water",true)
add("ei-nauvis-pressure-grace","pollution","pressure",true)
add("ei-nauvis-pressure-grace-profile","pollution","pressure",true)
add("ei-check-for-recipe-icons-improvement-mod","notifications","reminder",true)
for _,key in ipairs{"critical","vaporize","damage"} do add("tl-flying-text-"..key,"effects","tesla",true) end
add("ei-alert-icon-set-default","notifications","alert-default",true)
add("ei-admin-new-planets-peaceful","administration","admin-policy")
add("ei-admin-restrict-new-players","administration","admin-policy")
for _,name in ipairs{passage.budget_setting,passage.circuit_enabled_setting,passage.circuit_budget_setting} do
    add(name,"performance","passage")
end
local presets={active=true,intensity=true,performance=true,custom_rate_multiplier=true}
local seasons={seasonal_daylight=true,seasonal_ecology=true,axial_tilt=true,latitude=true,season_strength=true,calendar_days=true}
for _,row in ipairs(terrain.schema) do
    local group="ecology-tuning"
    if presets[row.key] then group="ecology-presets"
    elseif row.key:find("^planet_") then group="ecology-planets"
    elseif seasons[row.key] then group="ecology-seasons"
    elseif terrain.performance_presets.lean[row.key]~=nil then group="ecology-budgets"
    elseif row.type=="boolean" or row.type=="enum" then group="ecology-processes" end
    add(row.setting_name,group,"terrain")
end

---@param name string Legacy or native name; unlisted names are not writable options.
---@return string
function model.runtime_name(name)
    local entry=model.by_legacy[name] or model.by_id[name]
    return entry and entry.id or name
end
---@param name string
---@param fallback any?
---@return any
function model.get(name,fallback)
    local value=settings and settings.global and settings.global[model.runtime_name(name)]
    if value then return value.value end
    return fallback
end

-- Copy definitions after their ordinary constructors have run. Hidden originals
-- remain readable for old maps; no forced value may erase a migration input.
function model.install()
    local definitions={}
    for _,entry in ipairs(model.entries) do
        if entry.legacy then
            local source
            for _,kind in ipairs{"bool-setting","int-setting","double-setting","string-setting"} do
                source=data.raw[kind] and data.raw[kind][entry.legacy]
                if source then break end
            end
            assert(source and source.setting_type=="startup","Missing runtime option migration source: "..entry.legacy)
            local setting=table.deepcopy(source)
            setting.name=entry.id;setting.setting_type="runtime-global";setting.hidden=false
            setting.localised_name=table.deepcopy(entry.label)
            setting.localised_description={"",table.deepcopy(entry.description),"\n",{"ei-runtime-options.runtime-effect-note"}}
            source.hidden=true
            definitions[#definitions+1]=setting
        end
    end
    data:extend(definitions)
end

---@return EiRuntimeOption[]
function model.fields()
    local result={}
    for _,entry in ipairs(model.entries) do
        local prototype=prototypes.mod_setting[entry.id]
        assert(prototype and prototype.setting_type=="runtime-global","Missing ESIR map option: "..entry.id)
        local field=lib.copy_preset(nil,entry)
        local kind=prototype.type
        field.type=({["bool-setting"]="boolean",["int-setting"]="integer",["double-setting"]="number",["string-setting"]="string"})[kind]
        assert(field.type,"Unsupported ESIR map option: "..entry.id)
        field.default=prototype.default_value;field.min=prototype.minimum_value;field.max=prototype.maximum_value
        field.values=prototype.allowed_values and lib.copy_array(prototype.allowed_values) or nil
        if field.type=="string" then
            field.allow_blank=prototype.allow_blank;field.auto_trim=prototype.auto_trim
            if field.values and #field.values>0 then field.type="enum" end
        end
        result[#result+1]=field
    end
    return result
end
return model
