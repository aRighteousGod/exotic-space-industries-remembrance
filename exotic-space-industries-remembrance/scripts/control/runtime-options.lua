--==============================================================================
-- ESIR FILE MAP
-- owns: native map-option transactions, synchronous event batching and legacy import
-- loaded_by: control.lua, administration Options
-- cadence: explicit settings edits, init and configuration change; no tick service
-- forwarded_events: on_settings_changed, migrate
-- storage_roots: storage.ei.runtime_options (migration revision only)
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: one-time configuration migration; native values remain authoritative
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-options.md#contract
local catalog=require("lib/runtime-options-config")
local lib=require("lib/lib")
local model={}
local reconcile
-- These frames exist only during synchronous callbacks, never across ticks or saves.
local batches={}
---@param callback fun(changes:table<string,boolean>,tick:MapTick)
function model.configure(callback) reconcile=callback end
function model.begin_batch() batches[#batches+1]={} end
---@param tick MapTick
---@param commit boolean
function model.end_batch(tick,commit)
    local changes=assert(batches[#batches],"Unbalanced runtime option batch")
    batches[#batches]=nil
    if not commit then return end
    local parent=batches[#batches]
    if parent then for id in pairs(changes) do parent[id]=true end
    elseif next(changes) then reconcile(changes,tick) end
end
---@param event EventData.on_runtime_mod_setting_changed
---@return boolean handled
function model.on_settings_changed(event)
    if event.setting_type~="runtime-global" or not catalog.by_id[event.setting] then return false end
    local batch=batches[#batches]
    if batch then batch[event.setting]=true
    else reconcile({[event.setting]=true},event.tick) end
    return true
end
---@return table
function model.snapshot()
    local fields,values=catalog.fields(),{}
    for _,field in ipairs(fields) do values[field.id]=settings.global[field.id].value end
    return {id="options",fields=fields,values=values}
end

local function validate(field,value)
    if field.type=="boolean" then
        if type(value)=="boolean" then return value end
        return nil
    elseif field.type=="enum" then
        for _,allowed in ipairs(field.values) do if value==allowed then return value end end
        return nil
    elseif field.type=="string" then
        if type(value)~="string" then return nil end
        if field.auto_trim then value=value:match("^%s*(.-)%s*$") end
        if value=="" and not field.allow_blank then return nil end
        return value
    end
    value=tonumber(value)
    if not lib.is_valid_number(value) or (field.min and value<field.min) or (field.max and value>field.max)
        or (field.type=="integer" and value%1~=0) then return nil end
    if field.values and #field.values>0 then
        for _,allowed in ipairs(field.values) do if value==allowed then return value end end
        return nil
    end
    return value
end

local function write_setting(name,value)
    settings.global[name]={value=value}
end

---@param baseline table<string,boolean|number|string>
---@param changes table<string,boolean|number|string>
---@param tick MapTick
---@return boolean,LocalisedString,table<string,boolean|number|string>?
function model.apply(baseline,changes,tick)
    if type(baseline)~="table" or type(changes)~="table" then return false,{"ei-runtime-options.invalid-request"} end
    local snapshot=model.snapshot()
    local fields,validated={},{}
    for _,field in ipairs(snapshot.fields) do fields[field.id]=field end
    for _,id in ipairs(lib.sorted_scalar_keys(changes)) do
        local field=fields[id]
        if not field then return false,{"ei-runtime-options.invalid-field",tostring(id)} end
        local value=validate(field,changes[id])
        if value==nil then return false,{"ei-runtime-options.invalid-value",field.label} end
        if baseline[id]~=snapshot.values[id] then return false,{"ei-runtime-options.conflict",field.label} end
        if value~=snapshot.values[id] then validated[id]=value end
    end
    if validated["ei-terrain-pollution-low"]~=nil or validated["ei-terrain-pollution-high"]~=nil then
        local low=validated["ei-terrain-pollution-low"] or snapshot.values["ei-terrain-pollution-low"]
        local high=validated["ei-terrain-pollution-high"] or snapshot.values["ei-terrain-pollution-high"]
        if low>=high then return false,{"ei-runtime-options.invalid-pair"} end
    end
    local ordered=lib.sorted_scalar_keys(validated)
    if #ordered==0 then return true,{"ei-runtime-options.no-changes"},{} end
    model.begin_batch()
    local written,readback={},{}
    local ok,failure=pcall(function()
        for _,id in ipairs(ordered) do
            -- Include the attempted field: a native receiver may fail after the write.
            written[#written+1]=id
            write_setting(id,validated[id])
            readback[id]=settings.global[id].value
            assert(readback[id]==validated[id],"Runtime option readback mismatch: "..id)
        end
    end)
    if not ok then
        local rollback_errors={}
        for index=#written,1,-1 do
            local id=written[index]
            local restored,restore_error=pcall(write_setting,id,snapshot.values[id])
            if not restored or settings.global[id].value~=snapshot.values[id] then
                rollback_errors[#rollback_errors+1]=id..": "..tostring(restore_error)
            end
        end
        -- Reconcile actual values if an external receiver prevents restoration.
        model.end_batch(tick,#rollback_errors>0)
        if #rollback_errors>0 then return false,{"ei-runtime-options.rollback-failed",table.concat(rollback_errors,"; ")} end
        return false,{"ei-runtime-options.failed",tostring(failure)}
    end
    model.end_batch(tick,true)
    return true,{"ei-runtime-options.applied",#ordered},readback
end

-- blueprint-ref: .codex/esir/blueprints/runtime-options.md#migration
-- Fresh maps keep native Map selections. Existing maps import their currently
-- synchronized startup inputs exactly once, before ordinary owner initialization.
---@param tick MapTick
---@param fresh boolean
---@return boolean imported
function model.migrate(tick,fresh)
    storage.ei=storage.ei or {}
    local state=storage.ei.runtime_options or {}
    storage.ei.runtime_options=state
    if (state.migration_version or 0)>=1 then return false end
    if fresh then state.migration_version=1;return false end
    local snapshot=model.snapshot()
    local changes={}
    for _,entry in ipairs(catalog.entries) do
        if entry.legacy then changes[entry.id]=settings.startup[entry.legacy].value end
    end
    model.begin_batch()
    local ok,message=model.apply(snapshot.values,changes,tick)
    -- Lifecycle reconciliation follows in control.lua after all owners are ready.
    model.end_batch(tick,false)
    assert(ok,"ESIR runtime option migration failed: "..serpent.line(message))
    state.migration_version=1
    return true
end
return model
