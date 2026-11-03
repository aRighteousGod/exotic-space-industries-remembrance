-- Offline owner test: passage controls moved from Map Settings to Options.
-- Native setting events/writes are mocked here; runtime-options has native coverage.
package.path="exotic-space-industries-remembrance/?.lua;"..package.path
local key="ei-factory-passage-update-budget"
local toggle="ei-factory-passage-circuit-scanner-enabled"
local scans="ei-factory-passage-circuit-scan-budget"
storage={ei={}}
table.deepcopy=function(value)
    if type(value)~="table" then return value end
    local copy={};for k,v in pairs(value) do copy[k]=table.deepcopy(v) end;return copy
end
package.loaded["lib/lib"]={is_valid_number=function(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end,
    sorted_scalar_keys=function(t) local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys);return keys end}
package.loaded["scripts/control/planet-enemies"]={}
local fields={
    {id=key,type="integer",min=1,max=1024,label={"budget"}},
    {id=toggle,type="boolean",label={"scanner"}},
    {id=scans,type="integer",min=1,max=1024,label={"scans"}},
}
package.loaded["lib/runtime-options-config"]={by_id={[key]=true,[toggle]=true,[scans]=true},fields=function()return fields end}
local values={[key]=256,[toggle]=true,[scans]=1}
local owner,fail_key
settings={global=setmetatable({},{__index=function(_,name)return {value=values[name]} end,
    __newindex=function(_,name,record)
        values[name]=record.value
        owner.on_settings_changed{setting_type="runtime-global",setting=name,tick=0}
        if name==fail_key then fail_key=nil;error("injected native write failure") end
    end})}
local schema=require("lib/map-settings-config")
game={map_settings={},difficulty_settings={}}
for _,field in ipairs(schema.global) do
    local group=field.difficulty and game.difficulty_settings or game.map_settings[field.native_group or field.group] or {}
    if not field.difficulty then game.map_settings[field.native_group or field.group]=group end
    group[field.key]=field.type=="boolean" or math.max(field.min or 0,1)
end
local map=require("scripts/control/map-settings")
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local map_snapshot=map.snapshot{scope="global"}
check(map_snapshot.values[key]==nil and map_snapshot.values[toggle]==nil and map_snapshot.values[scans]==nil,"Map Settings no longer duplicates passage controls")
check(not map.apply({scope="global"},map_snapshot.values,{[key]=1024},0),"Map Settings cannot write moved option")
owner=require("scripts/control/runtime-options")
local refreshes=0;owner.configure(function()refreshes=refreshes+1 end)
local snapshot=owner.snapshot()
check(snapshot.values[key]==256,"Options snapshot reads native setting")
for _,bad in ipairs{0,1025,1.5,"bad",math.huge} do check(not owner.apply(snapshot.values,{[key]=bad},0),"invalid setting rejected") end
local ok,_,actual=owner.apply(snapshot.values,{[key]=1024},0)
check(ok and actual[key]==1024 and settings.global[key].value==1024,"native write/readback")
check(not owner.apply(snapshot.values,{[key]=1},0),"stale same-field edit rejected")
snapshot=owner.snapshot()
ok=owner.apply(snapshot.values,{[toggle]=false,[scans]=1024},0)
check(ok and owner.snapshot().values[toggle]==false,"false survives snapshot and readback")
check(not owner.apply(snapshot.values,{[toggle]=false},0),"boolean edit conflicts with stale draft")
snapshot=owner.snapshot()
for _,bad in ipairs{0,1025,1.5,"bad"} do check(not owner.apply(snapshot.values,{[scans]=bad},0),"invalid circuit allowance rejected") end
check(not owner.apply(snapshot.values,{[toggle]=1},0),"scanner toggle rejects nonboolean value")
local before_refresh=refreshes;fail_key=key
ok=owner.apply(snapshot.values,{[key]=1,[scans]=1},0)
check(not ok and settings.global[key].value==1024 and settings.global[scans].value==1024,"later native failure rolls both attempted options back")
check(refreshes==before_refresh,"failed transaction suppresses owner reconciliation")
print("PASS "..checks.." passage Options validation/conflict/rollback checks (offline native boundaries mocked)")
