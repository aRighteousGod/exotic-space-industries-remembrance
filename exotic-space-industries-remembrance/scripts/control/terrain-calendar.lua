--==============================================================================
-- ESIR FILE MAP
-- owns: analytical seasonal phase and native daylight tuple ownership
-- loaded_by: terrain-evolution.lua
-- cadence: one due surface per service, target interval 600 ticks
-- forwarded_events: owner-routed callbacks only
-- storage_roots: storage.ei.terrain_evolution.calendar
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner lifecycle and configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- An analytic calendar, not a second tick dispatcher. Owns only the four native
-- daylight boundaries; the independent Fulgora clock is never acquired/released.
local lib=require("lib/lib")
local policy=require("lib/terrain-policy")
local model={}
local function eligible(surface)
    return policy.planet(surface)~=nil and surface.planet.name~="fulgora"
end
local function matches(a,b)
    if not a or not b then return false end
    for _,k in ipairs({"dusk","evening","morning","dawn"}) do if math.abs(a[k]-b[k])>1e-9 then return false end end
    return true
end
local function phase_at(r,tick) return (r.phase+(r.period and (tick-r.epoch)/r.period or 0))%1 end
local function release_record(r)
    if eligible(r.surface) and r.baseline and r.last and matches(r.surface.daytime_parameters,r.last) then r.surface.daytime_parameters=r.baseline end
    r.baseline=nil;r.last=nil;r.suspended=nil
end
local function blocker()
    for _,name in ipairs({"diurnal-dynamics","TerrainEvolution2","TerrainEvolution"}) do if script.active_mods[name] then return name end end
end
---@param baseline table Native four-boundary tuple.
---@param phase number
---@param tilt number
---@param latitude number
---@return table|nil, table|string
function model.calculate_parameters(baseline,phase,tilt,latitude)
    if type(baseline)~="table" or not lib.is_valid_number(phase) then return nil,"invalid-input" end
    local d,e,m,a=baseline.dusk,baseline.evening,baseline.morning,baseline.dawn
    for _,v in ipairs({d,e,m,a}) do if not lib.is_valid_number(v) then return nil,"invalid-baseline" end end
    if not d or not e or not m or not a or not (0<=d and d<e and e<m and m<a and a<=1) then return nil,"invalid-baseline" end
    if not lib.is_valid_number(tilt) or not lib.is_valid_number(latitude) then return nil,"invalid-geometry" end
    local declination=math.asin(math.sin(tilt*math.pi/180)*math.sin(phase*math.pi*2))
    local daylight=math.acos(lib.clamp(-math.tan(latitude*math.pi/180)*math.tan(declination),-1,1))/math.pi
    local requested=(daylight-0.5)/2
    local low=math.max(1e-8-d,a-(1-1e-8),(0.02-(d+1-a))/2)
    local high=(m-e-0.02)/2
    if low>high then return nil,"incompatible-baseline" end
    local delta=lib.clamp(requested,low,high)
    return {dusk=d+delta,evening=e+delta,morning=m-delta,dawn=a-delta},
        {daylight_fraction=d+1-a+2*delta,night_fraction=m-e-2*delta,clamped=math.abs(delta-requested)>1e-9}
end
function model.initialize(root,tick)
    local c=root.calendar or {records={},reference_day=game.surfaces.nauvis and game.surfaces.nauvis.ticks_per_day or 25200}
    root.calendar=c;c.order={};c.order_index={};c.cursor=1;c.blocker=blocker();c.next_tick=tick
    c.reference_distance=c.reference_distance or prototypes.space_location.nauvis.distance
    for _,surface in pairs(game.surfaces) do
        if eligible(surface) then
            local r=c.records[surface.index]
            if not r or r.surface~=surface then
                r={surface=surface,phase=surface.planet.prototype.orientation%1,epoch=tick,status="pending"}
                c.records[surface.index]=r
            end
            r.distance=surface.planet.prototype.distance
            c.order[#c.order+1]=surface.index
        end
    end
    for index,r in pairs(c.records) do if not r.surface.valid or not eligible(r.surface) then c.records[index]=nil end end
    table.sort(c.order)
    for i,index in ipairs(c.order) do c.order_index[index]=i end
end
function model.add_surface(root,surface,tick)
    if not eligible(surface) then return end
    local c=root.calendar
    if not c or not c.order_index then model.initialize(root,tick);return end
    local r=c.records[surface.index]
    if not r or r.surface~=surface then
        c.records[surface.index]={surface=surface,phase=surface.planet.prototype.orientation%1,epoch=tick,
            distance=surface.planet.prototype.distance,status="pending"}
    end
    if not c.order_index[surface.index] then c.order[#c.order+1]=surface.index;c.order_index[surface.index]=#c.order end
end
function model.remove_surface(root,index)
    local c=root.calendar;if not c then return end
    c.records[index]=nil
    local i=c.order_index[index];if not i then return end
    local last=c.order[#c.order];c.order[i]=last;c.order[#c.order]=nil;c.order_index[index]=nil
    if last~=index then c.order_index[last]=i end
    if c.cursor>#c.order then c.cursor=1 end
end
function model.configure(root,tick)
    if not root.calendar then model.initialize(root,tick) end
    root.calendar.blocker=blocker();root.calendar.next_tick=tick
    for _,r in pairs(root.calendar.records) do r.next_tick=tick end
end
function model.service(root,tick,resolve_config)
    local c=root.calendar
    if not c or #c.order==0 then return false end
    if c.cursor>#c.order then c.cursor=1 end
    local r=c.records[c.order[c.cursor]];c.cursor=c.cursor%#c.order+1
    if not r or not eligible(r.surface) or tick<(r.next_tick or 0) then return false end
    r.next_tick=tick+600
    local cfg=resolve_config(r.surface)
    local period=math.max(1,math.floor(c.reference_day*(cfg.year_days or 360)*(math.max(r.distance,0.001)/c.reference_distance)^1.5))
    if r.period~=period then r.phase=phase_at(r,tick);r.epoch=tick;r.period=period end
    r.tilt=cfg.tilt or 23.5;r.latitude=cfg.latitude or 45
    if c.blocker or not cfg.enabled or not cfg.seasonal_daylight then
        release_record(r);r.status=c.blocker or "disabled";return true
    end
    if r.suspended then r.status="external-control";return true end
    local observed=r.surface.daytime_parameters
    if (r.last or r.baseline) and not matches(observed,r.last or r.baseline) then r.suspended=true;r.status="external-control";return true end
    if r.surface.always_day or r.surface.freeze_daytime then r.status="frozen";return true end
    r.baseline=r.baseline or observed
    local target,details=model.calculate_parameters(r.baseline,phase_at(r,tick),r.tilt,r.latitude)
    if not target then r.status=details;return true end
    if not matches(observed,target) then r.surface.daytime_parameters=target;r.last=target end
    r.status=details.clamped and "active-clamped" or "active"
    return true
end
function model.release(root)
    if not root.calendar then return end
    for _,r in pairs(root.calendar.records) do release_record(r);r.status="released" end
end
function model.release_surface(root,index)
    local r=root.calendar and root.calendar.records[index]
    if r then release_record(r);r.status="released" end
end
function model.snapshot(root,surface,tick)
    if not eligible(surface) then return {status="excluded"} end
    local c=root.calendar;local r=c and c.records[surface.index]
    if not r or r.surface~=surface then return {status="pending"} end
    return {status=r.status,phase=phase_at(r,tick),period_ticks=r.period,
        reference_days=r.period and r.period/c.reference_day,
        local_days=r.period and r.period/surface.ticks_per_day,
        hours=r.period and r.period/216000,next_tick=r.next_tick,blocker=c.blocker,
        owns_daylight=r.last~=nil and not r.suspended}
end
function model.set_phase(root,surface,phase,tick)
    if not eligible(surface) then return false,{"ei-terrain.unsupported"} end
    if not lib.is_valid_number(phase) or phase<0 or phase>1 then return false,{"ei-terrain.invalid-value"} end
    local r=root.calendar and root.calendar.records[surface.index]
    if not r then return false,{"ei-terrain.unsupported"} end
    r.phase=phase%1;r.epoch=tick;r.next_tick=tick
    return true,{"ei-terrain.updated"}
end
return model
