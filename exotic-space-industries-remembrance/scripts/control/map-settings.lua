--==============================================================================
-- ESIR FILE MAP
-- owns: validated native map edits, future-planet overrides and enabled values
-- loaded_by: control.lua, scripts/control/gaia.lua
-- cadence: explicit edits and surface lifecycle; no recurring work
-- forwarded_events: on_configuration_changed, on_surface_created, on_surface_ready, on_surface_deleted, on_biter_base_built, explicit apply/prepare_creation
-- storage_roots: storage.ei.map_settings
-- gui_ids: none (administration map-settings editor owns GUI drafts)
-- remote_interfaces: none
-- rebuild_on: init/configuration change (legacy policy import and saved override application)
--==============================================================================
-- blueprint: .codex/esir/blueprints/map-settings.md#contract
local lib = require("lib/lib")
local schema = require("lib/map-settings-config")
local enemies = require("scripts/control/planet-enemies")
local model = {}

---@class EiMapOverride
---@field values table<string,number|boolean>
---@field revision integer
---@class EiMapSettingsState
---@field overrides table<string,EiMapOverride>
---@field enabled table<string,table<string,AutoplaceControl>>
---@field evolution_revisions table<uint32,integer>|nil
---@field legacy_imported boolean|nil
---@class EiMapSettingsTarget
---@field scope "global"|nil
---@field planet string|nil
---@field surface_index uint32|nil
---@field surface_name string|nil
local function peek() return storage.ei and storage.ei.map_settings end
local function state()
    storage.ei = storage.ei or {}
    storage.ei.map_settings = storage.ei.map_settings or {overrides={}, enabled={}}
    return storage.ei.map_settings
end

---@param target EiMapSettingsTarget
---@return LuaSurface|nil,string|nil,string|nil
local function resolve(target)
    if target.surface_index then
        local surface = game.get_surface(target.surface_index)
        if not surface or not surface.valid or (target.surface_name and surface.name ~= target.surface_name) then return nil,nil,"deleted" end
        if surface.platform then return nil,nil,"platform" end
        return surface, enemies.planet_name(surface)
    end
    local planet = target.planet and game.planets[target.planet]
    if not planet then return nil,nil,"unavailable" end
    return planet.surface, planet.name
end

local function key_for(surface, planet)
    if planet and game.planets[planet] then return "planet:"..planet end
    return "surface:"..surface.index
end

local function defaults_for(planet)
    local prototype = planet and prototypes.space_location[planet]
    return prototype and prototype.map_gen_settings or {}
end

local function control_values(mgs, defaults, remembered, name)
    local source = (mgs.autoplace_controls or {})[name] or (defaults.autoplace_controls or {})[name] or {}
    local fallback = (defaults.autoplace_controls or {})[name] or {}
    local values = {}
    for _, property in ipairs({"frequency", "size", "richness"}) do
        local value = source[property]
        if value == nil then value = 1 end
        values[property] = value
    end
    local enabled = values.frequency > 0 and values.size > 0
    if not enabled then
        for _, property in ipairs({"frequency", "size", "richness"}) do
            local value = remembered and remembered[property] or fallback[property] or 1
            values[property] = property == "richness" and value or (value > 0 and value or 1)
        end
    end
    values.enabled = enabled
    return values
end

local function control_id(name, property) return "control/"..name.."/"..property end
local function field_map(fields)
    local result = {}
    for _, field in ipairs(fields) do result[field.id] = field end
    return result
end

---@param target EiMapSettingsTarget
---@return table|nil snapshot
---@return LocalisedString|nil error
function model.snapshot(target)
    local fields, values = {}, {}
    if target.scope == "global" then
        for _, source in ipairs(schema.global) do
            local field = table.deepcopy(source)
            fields[#fields+1] = field
            values[field.id] = field.difficulty and game.difficulty_settings[field.key]
                or game.map_settings[field.native_group or field.group][field.key]
        end
        return {id="global", target={scope="global"}, fields=fields, values=values, pending=false}
    end
    local surface, planet, error = resolve(target)
    if error then return nil,{"ei-map-settings."..error} end
    local defaults = defaults_for(planet)
    local mgs = surface and surface.map_gen_settings or table.deepcopy(defaults)
    local key = key_for(surface, planet)
    local root = peek()
    local remembered = root and root.enabled[key] or {}
    local saved = root and root.overrides[key]
    for _, source in ipairs(schema.surface) do
        if surface or not source.live_only then
            local field = table.deepcopy(source)
            fields[#fields+1] = field
            if field.id == "evolution" then values[field.id] = game.forces.enemy.get_evolution_factor(surface)
            elseif field.id == "new_bases" then values[field.id] = not saved or saved.values.new_bases ~= false
            elseif surface and (field.id == "peaceful_mode" or field.id == "no_enemies_mode") then values[field.id] = surface[field.id]
            else
                local value = mgs[field.id]
                if value == nil then
                    if field.type == "boolean" then value = false else value = field.id == "starting_area" and 1 or 0 end
                end
                values[field.id] = value
            end
        end
    end
    local controls = {}
    for name in pairs(defaults.autoplace_controls or {}) do controls[name] = true end
    for name in pairs(mgs.autoplace_controls or {}) do controls[name] = true end
    for _, name in ipairs(lib.sorted_scalar_keys(controls)) do
        local prototype = prototypes.autoplace_control[name]
        if prototype and not prototype.hidden then
            local current = control_values(mgs, defaults, remembered[name], name)
            for _, property in ipairs({"enabled", "frequency", "size", "richness"}) do
                if (property ~= "enabled" or prototype.can_be_disabled)
                    and (property ~= "richness" or (prototype.category == "resource" and prototype.richness)) then
                    local field = {id=control_id(name,property),kind="control",control=name,key=property,
                        group=prototype.category,type=property == "enabled" and "boolean" or "number",
                        min=0,max=6,mapgen=true,slider=property ~= "enabled",label=prototype.localised_name,
                        description=prototype.localised_description,scale=prototype.category == "terrain" and property == "frequency"}
                    fields[#fields+1] = field
                    values[field.id] = current[property]
                end
            end
        end
    end
    local cliffs=mgs.cliff_settings
    if cliffs and (defaults.cliff_settings or not game.planets[planet]) and (not cliffs.control or cliffs.control=="")
        and cliffs.name and cliffs.name~="" then
        for _, entry in ipairs({{id="cliff/interval",key="cliff_elevation_interval",max=65535},
            {id="cliff/continuity",key="richness",max=6,mapgen=true}}) do
            fields[#fields+1]={id=entry.id,key=entry.key,kind="cliff",group="cliff",type="number",min=0,max=entry.max,mapgen=entry.mapgen}
            values[entry.id]=cliffs[entry.key]
        end
    end
    if not surface and saved then
        for id, value in pairs(saved.values) do if values[id] ~= nil then values[id] = value end end
        for name in pairs(controls) do
            local frequency, size = control_id(name,"frequency"), control_id(name,"size")
            if values[frequency] == 0 or values[size] == 0 then
                values[control_id(name,"enabled")] = false
                local positive=control_values({autoplace_controls={[name]={frequency=0,size=0}}},defaults,remembered[name],name)
                if values[frequency] == 0 then values[frequency]=positive.frequency end
                if values[size] == 0 then values[size]=positive.size end
            end
        end
    end
    if surface then values["$evolution_revision"]=root and root.evolution_revisions and root.evolution_revisions[surface.index] or 0 end
    return {id=key,target={planet=planet,surface_index=surface and surface.index,surface_name=surface and surface.name},
        fields=fields,values=values,pending=surface == nil,revision=saved and saved.revision or 0,
        armoured_shared=planet=="nauvis" and settings.startup["ab-enable-nest"] and not settings.startup["ab-enable-nest"].value,
        suppressed=surface and surface.no_enemies_mode or values.no_enemies_mode}
end

local function validate(field, value)
    if field.type == "boolean" then if type(value) == "boolean" then return value end;return nil end
    value = tonumber(value)
    if not lib.is_valid_number(value) or value < field.min or value > field.max
        or (field.integer and value % 1 ~= 0) or (field.mapgen and value > 0 and value < 1/6) then return nil end
    return value
end

-- Converts sparse editor values into a copied native record, preserving every
-- unrelated expression, allowlist and territory setting from the actual surface.
local function merge(mgs, planet, key, changes, remember)
    local result = table.deepcopy(mgs)
    local defaults = defaults_for(planet)
    local root = peek()
    local previous = root and root.enabled[key] or {}
    local controls = {}
    for id, value in pairs(changes) do
        local name, property = id:match("^control/(.-)/([^/]+)$")
        if name then controls[name] = controls[name] or {};controls[name][property] = value
        elseif id == "cliff/interval" then result.cliff_settings.cliff_elevation_interval=value
        elseif id == "cliff/continuity" then result.cliff_settings.richness=value
        elseif id ~= "new_bases" and id ~= "evolution" then result[id] = value end
    end
    local memories = {}
    for name, edits in pairs(controls) do
        if prototypes.autoplace_control[name] then
            local current = control_values(result, defaults, previous[name], name)
            memories[name] = {frequency=current.frequency,size=current.size,richness=current.richness}
            for property, value in pairs(edits) do
                current[property] = value
                if property == "richness" or (property ~= "enabled" and value > 0) then memories[name][property]=value end
            end
            if current.frequency == 0 or current.size == 0 then current.enabled = false end
            local enabled = current.enabled
            current.enabled = nil
            if not enabled then current.frequency = 0;current.size = 0 end
            result.autoplace_controls = result.autoplace_controls or {}
            result.autoplace_controls[name] = current
        end
    end
    if remember and next(memories) then
        local saved = state();saved.enabled[key] = saved.enabled[key] or {}
        for name, values in pairs(memories) do saved.enabled[key][name] = values end
    end
    return result, memories
end

---@param planet string
---@param mgs MapGenSettings
---@return MapGenSettings
function model.prepare_creation(planet, mgs)
    local root = peek()
    local key = "planet:"..planet
    local saved = root and root.overrides[key]
    if not saved then return mgs end
    return (merge(mgs, planet, key, saved.values, true))
end

---@param target EiMapSettingsTarget
---@param baseline table<string,number|boolean>
---@param changes table<string,number|boolean|string>
---@param tick MapTick
---@return boolean,LocalisedString
---@return table<string,number|boolean>|nil readback Native or persisted pending values of edited fields.
function model.apply(target, baseline, changes, tick)
    local snapshot, error = model.snapshot(target)
    if not snapshot then return false,error end
    local catalog = field_map(snapshot.fields)
    local validated, combined = {}, table.deepcopy(snapshot.values)
    for id, value in pairs(changes) do
        local field = catalog[id]
        if not field then return false,{"ei-map-settings.invalid-field",id} end
        local valid = validate(field,value)
        if valid == nil then return false,{"ei-map-settings.invalid-value",id} end
        local conflict_id=id=="evolution" and "$evolution_revision" or id
        if baseline[conflict_id] ~= snapshot.values[conflict_id] then return false,{"ei-map-settings.conflict",id} end
        validated[id] = valid;combined[id] = valid
    end
    if not next(validated) then return true,{"ei-map-settings.no-changes"} end
    if target.scope == "global" then
        for _, pair in ipairs({{"settler_group_min_size","settler_group_max_size"},{"min_expansion_cooldown","max_expansion_cooldown"}}) do
            if combined["enemy_expansion."..pair[1]] > combined["enemy_expansion."..pair[2]] then return false,{"ei-map-settings.invalid-pair"} end
        end
        local before = {}
        local function write(id,value)
            local field = catalog[id]
            if field.difficulty then game.difficulty_settings[field.key] = value
            else game.map_settings[field.native_group or field.group][field.key] = value end
        end
        local ok, failure = pcall(function()
            for _, id in ipairs(lib.sorted_scalar_keys(validated)) do before[id]=snapshot.values[id];write(id,validated[id]) end
        end)
        if not ok then for id,value in pairs(before) do pcall(write,id,value) end;return false,{"ei-map-settings.failed",tostring(failure)} end
    else
        local surface, planet = resolve(snapshot.target)
        local before = surface and surface.map_gen_settings
        local source=before or table.deepcopy(defaults_for(planet))
        local existing=peek() and peek().overrides[snapshot.id]
        if not surface and existing then source=merge(source,planet,snapshot.id,existing.values,false) end
        local updated, memories=merge(source,planet,snapshot.id,validated,false)
        local ok, failure = pcall(function()
            if surface then
                surface.map_gen_settings = updated
                if validated.evolution ~= nil then game.forces.enemy.set_evolution_factor(validated.evolution,surface) end
            end
        end)
        if not ok then
            if surface then pcall(function() surface.map_gen_settings=before end) end
            return false,{"ei-map-settings.failed",tostring(failure)}
        end
        local root = state()
        local saved = root.overrides[snapshot.id] or {values={},revision=0}
        root.overrides[snapshot.id] = saved
        for id, value in pairs(validated) do if id ~= "evolution" then saved.values[id] = value end end
        for name, memory in pairs(memories) do
            local enabled_id=control_id(name,"enabled")
            if validated[control_id(name,"frequency")]==0 or validated[control_id(name,"size")]==0 then
                saved.values[enabled_id]=false
            elseif validated[enabled_id]==true then
                -- Explicit On restores the remembered positive tuple on recreation too.
                for _,dimension in ipairs({"frequency","size"}) do
                    saved.values[control_id(name,dimension)]=memory[dimension]
                end
            end
        end
        saved.revision = saved.revision+1
        if surface and validated.evolution~=nil then
            root.evolution_revisions=root.evolution_revisions or {}
            root.evolution_revisions[surface.index]=(root.evolution_revisions[surface.index] or 0)+1
        end
        if memories then
            root.enabled[snapshot.id] = root.enabled[snapshot.id] or {}
            for name, value in pairs(memories) do root.enabled[snapshot.id][name] = value end
        end
        if surface then
            enemies.on_policy_changed(surface,tick)
        end
    end
    local actual=model.snapshot(snapshot.target)
    local readback,lines={}, {""}
    local message={"",{snapshot.pending and "ei-map-settings.saved-pending" or "ei-map-settings.applied",snapshot.id},lines}
    local actual_surface=target.scope~="global" and resolve(snapshot.target) or nil
    local native=actual_surface and actual_surface.map_gen_settings
    for _,id in ipairs(lib.sorted_scalar_keys(validated)) do
        local field=catalog[id]
        local value=actual.values[id]
        if snapshot.pending then
            local saved=peek().overrides[snapshot.id].values
            if saved[id]~=nil then value=saved[id] end
        end
        if native and field.kind=="control" and field.key~="enabled" then
            value=((native.autoplace_controls or {})[field.control] or {})[field.key] or 1
        end
        readback[id]=value
        local shown=value
        if type(value)=="number" then
            shown=field.scale and (value>0 and 1/value or 0) or value*(field.factor or 1)
        elseif type(value)=="boolean" then shown={value and "gui.yes" or "gui.no"} end
        local label=field.label and {"",field.label," / ",{"ei-map-settings."..(field.scale and "scale" or field.key)}} or {"ei-map-settings."..id}
        if #lines>=18 then lines={""};message[#message+1]=lines end
        lines[#lines+1]={"","\n",label,": ",type(shown)=="number" and string.format("%.10g",shown) or shown}
    end
    return true,message,readback
end

---@param surface LuaSurface
---@param tick MapTick
function model.on_surface_ready(surface, tick)
    if not surface or not surface.valid or surface.platform then return end
    local planet = enemies.planet_name(surface)
    local key = key_for(surface,planet)
    local root = peek()
    local saved = root and root.overrides[key]
    if saved then
        surface.map_gen_settings = merge(surface.map_gen_settings,planet,key,saved.values,true)
    end
    enemies.on_policy_changed(surface,tick)
end

---@param surface LuaSurface
---@return table
function model.get_policy(surface)
    local root = peek()
    local saved = root and root.overrides[key_for(surface,enemies.planet_name(surface))]
    return {spawning=not surface.no_enemies_mode,peaceful=surface.peaceful_mode,
        peaceful_override=saved and saved.values.peaceful_mode,expansion=not saved or saved.values.new_bases ~= false,
        daytime=surface.daytime,freeze=surface.freeze_daytime,evolution=game.forces.enemy.get_evolution_factor(surface)}
end

---@param event EventData.on_biter_base_built
function model.on_biter_base_built(event)
    local entity = lib.get_valid_entity(event.entity)
    if entity and entity.force == game.forces.enemy and not model.get_policy(entity.surface).expansion then
        entity.destroy{raise_destroy=true}
    end
end

---@param tick MapTick
function model.on_configuration_changed(tick)
    local legacy = storage.ei and storage.ei.admin_tools and storage.ei.admin_tools.world
    if legacy and legacy.policies and not (peek() and peek().legacy_imported) then
        local root = state()
        for key, policy in pairs(legacy.policies) do
            local surface_name = key:match("^surface:(.+)$")
            local surface = surface_name and game.get_surface(surface_name)
            if surface then key = key_for(surface,enemies.planet_name(surface)) end
            if not surface_name or surface then
                local saved = root.overrides[key] or {values={},revision=0}
                root.overrides[key] = saved
                if saved.values.peaceful_mode == nil then saved.values.peaceful_mode = policy.peaceful end
                if saved.values.no_enemies_mode == nil and policy.spawning ~= nil then saved.values.no_enemies_mode = not policy.spawning end
                if saved.values.new_bases == nil then saved.values.new_bases = policy.expansion end
            end
        end
        root.legacy_imported = true
    end
    for _, surface in pairs(game.surfaces) do model.on_surface_ready(surface,tick) end
end

---@param event EventData.on_surface_created
function model.on_surface_created(event)
    model.on_surface_ready(game.get_surface(event.surface_index),event.tick)
end

---@param event EventData.on_surface_deleted
function model.on_surface_deleted(event)
    local root = peek()
    if root then
        local key = "surface:"..event.surface_index
        root.overrides[key] = nil;root.enabled[key] = nil
        if root.evolution_revisions then root.evolution_revisions[event.surface_index]=nil end
    end
end

---@return table
function model.peek_summary()
    local root = peek()
    local count = 0
    for _ in pairs(root and root.overrides or {}) do count = count+1 end
    return {status=root and "ready" or "not-initialized",overrides=count}
end
return model
