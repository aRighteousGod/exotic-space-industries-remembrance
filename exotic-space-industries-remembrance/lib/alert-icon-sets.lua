--==============================================================================
-- ESIR FILE MAP
-- owns: stage-safe alert icon sets, provider registration and personal selection
-- loaded_by: settings.lua, prototypes/alerts.lua, lib/alerts.lua, terrain-gui.lua, provider mods
-- cadence: settings/data registration and explicit runtime preference lifecycle
-- forwarded_events: none; callers normalize selections at game-available boundaries
-- storage_roots: none; native setting values are authoritative
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration change refreshes the module-local prototype cache
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-alerts.md#contract
local catalog = require("__exotic-space-industries-remembrance__/lib/alert-catalog")
local lib = require("__exotic-space-industries-remembrance__/lib/lib")
local model = {
    setting_name="ei-alert-icon-set", default_setting_name="ei-alert-icon-set-default",
    sentinel="startup-default", builtin_ids={"original","svg","rendered","vanilla"},
}
local builtin = {original=true,svg=true,rendered=true,vanilla=true}
local runtime_ids, runtime_members
local runtime_diagnostics={}

---@class EsirAlertIconArtwork
---@field icon string? Single PNG; mutually exclusive with icons.
---@field icon_size integer? Required for a single PNG.
---@field icons data.IconData[]? Layers with explicit icon sizes.
---@class EsirAlertIconSetManifest
---@field api_version integer Must be 1.
---@field provider string Installed provider mod name.
---@field id string Local stable ID containing lower-case letters, digits and hyphens.
---@field fallback "original"|"svg"|"rendered"|"vanilla"? Defaults to rendered, independent of startup selection.
---@field icons table<string, EsirAlertIconArtwork>? Overrides keyed by existing catalogue alert ID.

local function valid_set_id(id)
    return type(id)=="string" and (builtin[id] or id:match("^[%w_-]+__[a-z0-9%-]+$")~=nil)
end

---@param set_id string
---@param alert_id string
---@return string
function model.signal_name(set_id,alert_id)
    local definition=catalog.by_id[alert_id]
    assert(definition and valid_set_id(set_id),"Unknown ESIR alert or invalid icon set ID")
    local name=set_id=="original" and definition.icon_signal or "ei-alert-set-"..set_id.."__"..alert_id
    assert(#name<=200 and name:match("^[%w_-]+$"),"ESIR alert signal name exceeds Factorio prototype limits")
    return name
end

---@param id string
---@return LocalisedString
function model.choice_caption(id)
    return {"?",{"string-mod-setting."..model.setting_name.."-"..id},id}
end

---@return table[] Startup and runtime-per-user string-setting prototypes.
function model.setting_definitions()
    local personal=lib.copy_array(model.builtin_ids)
    table.insert(personal,1,model.sentinel)
    return {
        {type="string-setting",name=model.default_setting_name,setting_type="startup",default_value="rendered",
            allowed_values=lib.copy_array(model.builtin_ids),hidden=false,order="e-alert-00-0"},
        {type="string-setting",name=model.setting_name,setting_type="runtime-per-user",default_value=model.sentinel,
            allowed_values=personal,hidden=false,order="d-ecology-alert-000"},
    }
end

local function signal_prototype(set_id,entry,artwork)
    local prototype={type="virtual-signal",name=model.signal_name(set_id,entry.id),hidden=true,
        hidden_in_factoriopedia=true,localised_name=entry.localised_name,
        subgroup="virtual-signal-special",order=entry.order.."-"..set_id}
    if artwork.icons then
        prototype.icons={};lib.recursive_copy(prototype.icons,artwork.icons)
    else prototype.icon,prototype.icon_size=artwork.icon,artwork.icon_size end
    return prototype
end

---@return data.VirtualSignalPrototype[]
function model.builtin_prototypes()
    local result={}
    for _,id in ipairs(model.builtin_ids) do
        local folder=id=="original" and "" or id.."/"
        for _,entry in ipairs(catalog.entries) do
            result[#result+1]=signal_prototype(id,entry,{
                icon="__exotic-space-industries-remembrance__/graphics/gui/alerts/"..folder..entry.id..".png",icon_size=128})
        end
    end
    return result
end

-- Provider manifests are data only; reject callbacks/cycles before any prototype mutation.
local function validate_manifest_values(value,seen,depth)
    local kind=type(value)
    assert(kind=="table" or kind=="string" or kind=="boolean" or (kind=="number" and lib.is_valid_number(value)),
        "ESIR icon manifests must contain only plain data")
    if kind~="table" then return end
    assert(depth<=8 and not seen[value] and getmetatable(value)==nil,"ESIR icon manifests cannot contain cycles or metatables")
    seen[value]=true
    for key,child in pairs(value) do
        assert(type(key)=="string" or (type(key)=="number" and lib.is_valid_number(key)),"Invalid ESIR icon manifest key")
        validate_manifest_values(child,seen,depth+1)
    end
    seen[value]=nil
end

local layer_fields={icon=true,icon_size=true,scale=true,shift=true,tint=true,draw_background=true,floating=true}
local function validate_layer(layer)
    assert(type(layer)=="table" and type(layer.icon)=="string" and layer.icon~="", "ESIR icon layers require a file path")
    assert(type(layer.icon_size)=="number" and layer.icon_size>0 and layer.icon_size%1==0,
        "ESIR icon layers require an explicit positive integer icon_size")
    for key in pairs(layer) do assert(layer_fields[key],"Unsupported ESIR icon layer field: "..tostring(key)) end
    if layer.scale~=nil then assert(type(layer.scale)=="number" and layer.scale>0,"Invalid ESIR icon layer scale") end
    if layer.shift~=nil then
        assert(type(layer.shift)=="table" and type(layer.shift.x or layer.shift[1])=="number"
            and type(layer.shift.y or layer.shift[2])=="number","Invalid ESIR icon layer shift")
        for key,value in pairs(layer.shift) do
            assert((key=="x" or key=="y" or key==1 or key==2) and type(value)=="number","Invalid ESIR icon shift coordinate")
        end
    end
    if layer.tint~=nil then
        assert(type(layer.tint)=="table","Invalid ESIR icon layer tint")
        local count=0
        for key,value in pairs(layer.tint) do
            assert((key=="r" or key=="g" or key=="b" or key=="a" or key==1 or key==2 or key==3 or key==4)
                and type(value)=="number" and value>=0 and value<=255,"Invalid ESIR icon tint channel")
            if type(key)=="number" then count=count+1 end
        end
        assert(count==0 or ((count==3 or count==4) and layer.tint[1]~=nil and layer.tint[2]~=nil
            and layer.tint[3]~=nil and (count==3 or layer.tint[4]~=nil)),"Invalid ESIR icon tint array")
    end
    for _,field in ipairs{"draw_background","floating"} do
        assert(layer[field]==nil or type(layer[field])=="boolean","Invalid ESIR icon layer boolean")
    end
end

---@param def EsirAlertIconSetManifest
---@return string set_id
---@return string fallback
local function validate_manifest(def)
    assert(type(def)=="table","ESIR icon registration requires a manifest")
    validate_manifest_values(def,{},0)
    for key in pairs(def) do
        assert(key=="api_version" or key=="provider" or key=="id" or key=="fallback" or key=="icons",
            "Unknown ESIR icon manifest field: "..tostring(key))
    end
    assert(def.api_version==1,"Unsupported ESIR alert icon API version")
    assert(type(def.provider)=="string" and def.provider:match("^[%w_-]+$") and mods and mods[def.provider],
        "ESIR icon provider must name an installed mod")
    assert(type(def.id)=="string" and def.id:match("^[a-z0-9%-]+$"),"Invalid ESIR local icon set ID")
    local fallback=def.fallback or "rendered"
    assert(builtin[fallback],"ESIR icon fallback must be original, svg, rendered or vanilla")
    assert(def.icons==nil or type(def.icons)=="table","ESIR icon overrides must be a table")
    local set_id=def.provider.."__"..def.id
    for _,entry in ipairs(catalog.entries) do model.signal_name(set_id,entry.id) end
    for alert_id,artwork in pairs(def.icons or {}) do
        assert(catalog.by_id[alert_id],"Undeclared ESIR alert icon override: "..tostring(alert_id))
        assert(type(artwork)=="table","ESIR alert icon override must be a table")
        if artwork.icons~=nil then
            assert(artwork.icon==nil and artwork.icon_size==nil,"ESIR icon overrides cannot mix icon and icons")
            for key in pairs(artwork) do assert(key=="icons","Unsupported layered ESIR icon override field") end
            assert(type(artwork.icons)=="table" and #artwork.icons>0,"ESIR layered icon cannot be empty")
            local count=0
            for key,layer in pairs(artwork.icons) do
                assert(type(key)=="number" and key%1==0 and key>=1 and key<=#artwork.icons,"ESIR layers must be a dense array")
                validate_layer(layer);count=count+1
            end
            assert(count==#artwork.icons,"ESIR layers must be a dense array")
        else
            for key in pairs(artwork) do assert(key=="icon" or key=="icon_size","Unsupported single ESIR icon override field") end
            validate_layer(artwork)
        end
    end
    return set_id,fallback
end

-- Both stages use data.raw as registration authority, including cross-mod requires.
---@param def EsirAlertIconSetManifest
---@return string set_id
function model.register_settings(def)
    local set_id=validate_manifest(def)
    local changes={}
    for _,name in ipairs{model.default_setting_name,model.setting_name} do
        local prototype=data and data.raw["string-setting"] and data.raw["string-setting"][name]
        assert(prototype and prototype.allowed_values,"Register ESIR icon settings after the ESIR settings stage")
        local values,addons={},{}
        for _,id in ipairs(prototype.allowed_values) do
            assert(id~=set_id,"Duplicate ESIR icon set settings registration: "..set_id)
            if not builtin[id] and id~=model.sentinel then addons[#addons+1]=id end
        end
        addons[#addons+1]=set_id;table.sort(addons)
        if name==model.setting_name then values[#values+1]=model.sentinel end
        for _,id in ipairs(model.builtin_ids) do values[#values+1]=id end
        for _,id in ipairs(addons) do values[#values+1]=id end
        changes[#changes+1]={prototype=prototype,values=values}
    end
    for _,change in ipairs(changes) do change.prototype.allowed_values=change.values end
    return set_id
end

---@param def EsirAlertIconSetManifest
---@return string set_id
function model.register_data(def)
    local set_id,fallback=validate_manifest(def)
    local signals=data and data.raw["virtual-signal"]
    assert(signals,"Register ESIR icon data after ESIR prototypes")
    local definitions={}
    for _,entry in ipairs(catalog.entries) do
        assert(not signals[model.signal_name(set_id,entry.id)],"Duplicate ESIR icon set data registration: "..set_id)
        local source=def.icons and def.icons[entry.id] or signals[model.signal_name(fallback,entry.id)]
        assert(source,"Missing ESIR builtin fallback icon: "..entry.id)
        definitions[#definitions+1]=signal_prototype(set_id,entry,source)
    end
    data:extend(definitions)
    return set_id
end

-- Keep diagnostics local and deterministic: unchanged configuration refreshes do
-- not repeat a warning, while a repaired and later broken family is reported again.
local function report_runtime_diagnostics(current)
    local keys={}
    for id in pairs(current) do keys[#keys+1]=id end
    table.sort(keys)
    for _,id in ipairs(keys) do
        if current[id]~=runtime_diagnostics[id] and log then
            log("[ESIR alerts] Icon set settings/data mismatch: "..current[id])
        end
    end
    runtime_diagnostics=current
end

---@return string[] Valid sets in builtin order, followed by sorted provider IDs.
function model.refresh_runtime()
    runtime_ids,runtime_members={},{}
    local prototype=prototypes and prototypes.mod_setting and prototypes.mod_setting[model.setting_name]
    local allowed,diagnostics={},{}
    if not prototype then
        diagnostics["setting:"..model.setting_name]="missing personal selector '"..model.setting_name.."'; using Rendered fallback."
    end
    for _,id in pairs(prototype and prototype.allowed_values or {}) do
        if valid_set_id(id) then allowed[id]=true
        elseif id~=model.sentinel then
            local value=type(id)=="string" and id or "<"..type(id)..">"
            diagnostics["invalid:"..value]="invalid set ID '"..value.."' in '"..model.setting_name.."'; excluding this choice."
        end
    end
    local addons={}
    for id in pairs(allowed) do if not builtin[id] then addons[#addons+1]=id end end
    table.sort(addons)
    local candidates=lib.copy_array(model.builtin_ids)
    for _,id in ipairs(addons) do candidates[#candidates+1]=id end
    for _,id in ipairs(candidates) do
        local complete=allowed[id]
        if complete then
            for _,entry in ipairs(catalog.entries) do
                local name=id=="original" and entry.icon_signal or "ei-alert-set-"..id.."__"..entry.id
                if #name>200 then
                    diagnostics[id]="set '"..id.."' produces a signal name longer than 200 characters ('"..name.."'); excluding this choice."
                    complete=false;break
                end
                local signal=prototypes and prototypes.virtual_signal and prototypes.virtual_signal[name]
                if not signal or signal.valid==false then
                    diagnostics[id]="set '"..id.."' is missing signal '"..name.."'; register the same manifest in settings and data stages. Excluding this choice."
                    complete=false;break
                end
            end
        end
        if complete then runtime_ids[#runtime_ids+1]=id;runtime_members[id]=true end
    end
    report_runtime_diagnostics(diagnostics)
    return lib.copy_array(runtime_ids)
end

---@return string[]
function model.available_sets()
    if not runtime_ids then model.refresh_runtime() end
    return lib.copy_array(runtime_ids)
end

---@param player LuaPlayer?
---@return string
function model.player_set(player)
    if not runtime_members then model.refresh_runtime() end
    local setting=player and player.valid and player.mod_settings[model.setting_name]
    local selected=setting and setting.value
    if runtime_members[selected] then return selected end
    local startup=settings and settings.startup and settings.startup[model.default_setting_name]
    return startup and runtime_members[startup.value] and startup.value or "rendered"
end

---@param player LuaPlayer
---@return string resolved
---@return boolean changed
function model.normalize_player(player)
    local resolved=model.player_set(player)
    if not player or not player.valid then return resolved,false end
    local previous=player.mod_settings[model.setting_name]
    if previous and previous.value==resolved then return resolved,false end
    player.mod_settings[model.setting_name]={value=resolved}
    return resolved,true
end

---@return boolean changed
function model.normalize_map_default()
    local defaults=settings and settings.player_default
    if not defaults then return false end
    local previous=defaults[model.setting_name]
    if previous and previous.value==model.sentinel then return false end
    defaults[model.setting_name]={value=model.sentinel}
    return true
end
return model
