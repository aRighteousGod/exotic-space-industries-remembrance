-- Test-only native icon/settings boundary; production modules remain the subjects.
local model={}
local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
end
local function encode(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys={};for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(value[k]) end
    return '{'..table.concat(out,',')..'}'
end
function model.install(catalog)
    local lib=package.loaded['lib/lib'] or {}
    lib.copy_array=function(t)local r={};for i,v in ipairs(t or {}) do r[i]=v end;return r end
    lib.recursive_copy=function(target,source)for k,v in pairs(source)do target[k]=copy(v)end end
    lib.is_valid_number=function(n)return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
    lib.copy_localised_string=copy
    package.loaded['lib/lib']=lib
    package.loaded['__exotic-space-industries-remembrance__/lib/lib']=lib
    package.loaded['__exotic-space-industries-remembrance__/lib/alert-catalog']=catalog
    prototypes=prototypes or {};prototypes.virtual_signal={['signal-fire']={},['signal-info']={}}
    prototypes.mod_setting={['ei-alert-icon-set']={allowed_values={'startup-default','original','svg','rendered','vanilla'}}}
    settings={startup={['ei-alert-icon-set-default']={value='rendered'}},player_default={}}
    helpers=helpers or {};helpers.table_to_json=encode
    for _,entry in ipairs(catalog.entries)do
        prototypes.virtual_signal[entry.icon_signal]={}
        for _,id in ipairs{'svg','rendered','vanilla'}do prototypes.virtual_signal['ei-alert-set-'..id..'__'..entry.id]={} end
    end
    local sets=require('lib/alert-icon-sets');sets.refresh_runtime()
    return sets
end
function model.player(player,on_add,on_remove)
    player._native={}
    player.add_custom_alert=function(entity,icon,message,map)
        if on_add then on_add(entity,icon,message,map) end
        for _,n in ipairs(player._native)do
            if n.target==entity and n.icon.name==icon.name and encode(n.message)==encode(message) then n.tick=game.tick;return end
        end
        player._native[#player._native+1]={target=entity,icon=copy(icon),message=copy(message),tick=game.tick}
    end
    player.remove_alert=function(filter)
        if on_remove then on_remove(filter) end
        if filter.icon then assert(prototypes.virtual_signal[filter.icon.name],'invalid deleted native signal filter') end
        for i=#player._native,1,-1 do
            local n=player._native[i]
            if (not filter.entity or n.target==filter.entity) and (not filter.icon or n.icon and n.icon.name==filter.icon.name)
                and (not filter.message or encode(n.message)==encode(filter.message)) then table.remove(player._native,i) end
        end
    end
    player.get_alerts=function(filter)
        local rows={}
        for _,n in ipairs(player._native)do
            if n.target.valid and (not filter.entity or n.target==filter.entity) then rows[#rows+1]=n end
        end
        return {[player.surface.index]={[defines.alert_type.custom]=rows}}
    end
end
return model
