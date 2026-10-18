-- Standalone field-report regression checks. Actual owner, native reads mocked.
local checks,failed=0,0
local function check(ok,name)
    checks=checks+1
    if not ok then failed=failed+1;print("FAIL "..name) end
end
package.loaded["lib/lib"]={is_valid_number=function(v)
    return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end}
helpers={is_valid_sprite_path=function() return true end}
local field=dofile("exotic-space-industries-remembrance/scripts/control/terrain-field-report.lua")
local tuple={dusk=.25,evening=.45,morning=.55,dawn=.75}
local vectors={{0,"day",9000},{.25,"dusk",7200},{.45,"night",3600},
    {.55,"dawn",7200},{.75,"day",18000},{.999,"day",9036},{1,"day",9000}}
for _,v in ipairs(vectors) do
    local result=field.calculate_cycle(v[1],36000,tuple,false,false)
    check(result.available and result.phase==v[2] and math.abs(result.remaining-v[3])<1e-7,"cycle boundary/wrap "..v[1])
end
for _,t in ipairs{.25-1e-10,.45-1e-10,.55-1e-10,.75-1e-10} do
    local c=field.calculate_cycle(t,36000,tuple,false,false)
    check(c.remaining>0 and c.remaining<1e-4,"strictly-before boundary remains current stage "..t)
end
local frozen=field.calculate_cycle(.5,36000,tuple,true,false)
check(frozen.available and frozen.phase=="night" and frozen.remaining==nil and frozen.frozen,"frozen night has no forecast")
local permanent=field.calculate_cycle(.5,36000,tuple,false,true)
check(permanent.available and permanent.remaining==nil and permanent.permanent,"permanent daylight has no forecast")
check(permanent.phase=="day" and permanent.fractions[1]==1 and permanent.fractions[3]==0,"permanent light never implies an active night segment")
check(not field.calculate_cycle(.5,0,tuple,false,false).available,"zero period rejected")
check(not field.calculate_cycle(0/0,36000,tuple,false,false).available,"nonfinite phase rejected")
check(not field.calculate_cycle(.5,36000,{dusk=.45,evening=.25,morning=.55,dawn=.75},false,false).available,"unordered boundaries rejected")
for _,spec in ipairs{
    {{.5,.2,.1,.2},600,{300,120,60,120}},
    {{.02,.01,.96,.01},600,{12,6,576,6}},
    {{.96,.01,.02,.01},600,{576,6,12,6}},
    {{0,.1,.8,.1},600,{0,60,480,60}},
    {{.333333,.000001,.333333,.333333},317,nil},
} do
    local widths=field.segment_widths(spec[1],spec[2]);local sum=0;local valid=true
    for i,w in ipairs(widths) do sum=sum+w;valid=valid and w>=0 and w==math.floor(w) and (not spec[3] or w==spec[3][i]) end
    check(valid and sum==spec[2],"integer partition sums to "..spec[2].." for "..table.concat(spec[1],","))
end
local function has(node,key)
    if type(node)~="table" then return false end
    if node[1]==key then return true end
    for _,child in pairs(node) do if has(child,key) then return true end end
    return false
end
local function category(node,name)
    if type(node)~="table" then return nil end
    if node[1]=="ei-ecology-field.effect" and type(node[2])=="table" and node[2][1]=="ei-ecology.category-"..name then return node end
    for _,child in pairs(node) do local found=category(child,name);if found then return found end end
end
local cfg={}
for _,key in ipairs{"degradation","recovery","tree_stress","tree_regrowth","aging","rot","mining_scars", "periodic_mining_scars","mining_recovery","flood","drought","cliffs","paving","thermal_scars","blood","seasonal_daylight"} do cfg[key]=true end
cfg.wildfire="contained";cfg.pollution_high=100;cfg.pollution_low=25;cfg.dirty_seconds=300;cfg.clean_seconds=600
local function compose(planet,pollution,overrides,extra,report_extra)
    local c={};for k,v in pairs(cfg) do c[k]=v end;for k,v in pairs(overrides or {}) do c[k]=v end
    local fields={valid=true,name=planet,index=1,planet={name=planet,prototype={localised_name=planet}},
        daytime=.5,ticks_per_day=36000,daytime_parameters=tuple,freeze_daytime=false,always_day=false}
    for k,v in pairs(extra or {}) do fields[k]=v end
    local surface=setmetatable({},{__index=fields,__newindex=function() error("observer wrote a surface field") end})
    local report={status="enabled",sample_age=0,pollution_supported=pollution,
        woodland_supported=planet~="fulgora" and planet~="aquilo",effective=c,effects={},effect_ticks={},global={}}
    for k,v in pairs(report_extra or {}) do report[k]=v end
    return field.compose(report,surface,600,{report_status=function()return{managed=false}end},600).values
end
local function applicable(values,name,expected,why)
    local row=category(values,name)
    check(row and has(row,"ei-ecology-field.feature-unavailable")==not expected,why)
end
local gleba=compose("gleba",false)
for _,name in ipairs{"pollution","restoration","tree-stress","tree-recovery","regrowth","wildfire"} do
    applicable(gleba,name,false,"spore input cannot drive "..name)
end
for _,planet in ipairs{"gaia","vulcanus","gleba"} do
    local values=compose(planet,true)
    applicable(values,"aging",false,planet.." has no approved aging replacement")
    applicable(values,"rot",false,planet.." has no approved deadwood")
end
for _,planet in ipairs{"fulgora","aquilo"} do
    local values=compose(planet,true)
    for _,name in ipairs{"tree-stress","tree-recovery","regrowth","aging","rot","wildfire"} do
        applicable(values,name,false,planet.." has no approved native fuel/woodland for "..name)
    end
end
for _,spec in ipairs{
    {"working-scars",{mining_scars=false},"working scars require general mining switch"},
    {"mining-restoration",{recovery=false},"mining restoration requires general recovery"},
    {"paving",{blood=false},"paving depends on blood"},
} do
    local row=category(compose("nauvis",true,spec[2]),spec[1])
    check(row and has(row,"ei-ecology-field.feature-off"),spec[3])
end
-- General terrain recovery does not gate native tree-grey recovery.
local greening=category(compose("nauvis",true,{recovery=false}),"tree-recovery")
check(greening and not has(greening,"ei-ecology-field.feature-off"),"tree greening remains independent of terrain recovery")
check(has(compose("nauvis",true,{recovery=false}).mining_note,"ei-ecology-field.feature-off"),"mining note respects the general recovery switch")
check(has(compose("gleba",false).mining_note,"ei-ecology-field.feature-unavailable"),"mining recovery note does not imply spores can provide clean industrial readings")
local legacy=compose("nauvis",true,nil,nil,{effects={pollution=9}})
check(category(legacy,"pollution")[3]==9 and has(category(legacy,"pollution"),"ei-ecology-field.no-time"),"old totals survive without invented times")
local repeated=compose("nauvis",true,nil,nil,{effects={pollution=9},effect_ticks={pollution=540}})
check(category(repeated,"pollution")[3]==9 and has(category(repeated,"pollution"),"ei-ecology-field.last"),"repeated changes remain cumulative events with latest success")
check(compose("nauvis",true,nil,nil,{sample_age=1201}).status[1]=="ei-ecology-field.status-outdated","older local observations are identified")
check(compose("nauvis",true,{enabled=false},nil,{status="disabled"}).status[1]=="ei-ecology-field.status-disabled","disabled report remains distinct from unknown")
local calendar=compose("nauvis",true,nil,nil,{calendar={phase=.25,period_ticks=36000,reference_days=360,status="active"}})
check(calendar.season_marker==140 and calendar.season[2][1]=="ei-ecology.season-2","season boundary centers its marker on the full-width strip")
local wrapped=compose("nauvis",true,nil,nil,{calendar={phase=1.25,period_ticks=36000,reference_days=360,status="active"}})
check(wrapped.season_marker==calendar.season_marker,"season phase wraps independently of local time")
local empty_surface={valid=true,name="utility"}
local no_cycle=field.compose({status="unsupported",effects={}},empty_surface,600,
    {report_status=function()error("utility must not consult a controller")end},600).values
check(no_cycle.day_available==false and no_cycle.season_available==false,"unavailable cycles hide both diagrams")
check(no_cycle.daylight=="" and no_cycle.season[1]=="ei-ecology-field.no-calendar","utility has one unavailable-calendar message and no fictional future check")
local adapted=compose("unadapted",true,nil,nil,{status="unsupported"})
check(adapted.day_available and adapted.banner=="ei-ecology-banner-neutral" and not adapted.season_available,"unknown planet retains labelled native cycle with a neutral banner")
local platform=compose("nauvis",true,nil,{platform={}}, {status="unsupported"})
check(not platform.day_available and platform.banner=="ei-ecology-banner-neutral","platform association never creates a planetary report")
check(not platform.banner_visible,"utility/platform fallback uses the neutral native panel without stretching a small icon")
local full_light=compose("nauvis",true,nil,{always_day=true,freeze_daytime=true})
check(full_light.day_visible_1 and not full_light.day_visible_2 and not full_light.day_visible_3 and not full_light.day_visible_4,"zero-duration segments are explicitly hidden")
local reads=0
local native={valid=true,name="fulgora",planet={name="fulgora"},daytime=.1,ticks_per_day=6000,
    daytime_parameters=tuple,freeze_daytime=false,always_day=false}
local observer=setmetatable({},{__index=function(_,key)reads=reads+1;return native[key]end,
    __newindex=function()error("read-only observer attempted mutation")end})
local independent={report_status=function(s)return{managed=s==observer}end}
local first=field.observe_cycle(observer,0,independent)
native.ticks_per_day=12000
local second=field.observe_cycle(observer,60,independent)
check(first.variable and second.period==first.period*2 and second.remaining==first.remaining*2,"variable native duration is observed afresh")
check(reads<=20,"native scalar reads remain finite")
prototypes={space_location={fulgora={surface_properties={["day-night-cycle"]=6000}}}}
game={surfaces={fulgora=observer}}
local fulgora=dofile("exotic-space-industries-remembrance/scripts/control/fulgora-day-length-variation.lua")
check(fulgora.report_status(observer).managed,"independent controller identifies its actual target")
check(not fulgora.report_status({valid=true,planet={name="fulgora"}}).managed,"planet association alone does not claim independent ownership")
game.surfaces.fulgora=nil
check(not fulgora.report_status(observer).managed,"rename/removal retires independent-controller identity")
print(string.format("%d source-review assertions; %d failed",checks,failed))
if failed>0 then os.exit(1) end
