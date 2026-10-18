--==============================================================================
-- ESIR FILE MAP
-- owns: read-only Simple ecology field report and native local-day observations
-- loaded_by: terrain-gui.lua
-- cadence: admitted open-viewer presentation only
-- forwarded_events: none; explicit surface and tick inputs
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: no persistent state
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local lib=require("lib/lib")
local model={}
local planets={nauvis=true,gaia=true,vulcanus=true,gleba=true,fulgora=true,aquilo=true}
local phases={"day","dusk","night","dawn"}
local seasons={"spring","summer","autumn","winter"}
local categories={
    ground={"pollution","restoration"},
    woodland={"tree-stress","tree-recovery","regrowth","aging","rot"},
    mining={"depletion-scars","working-scars","mining-restoration"},
    other={"wildfire","flood","drought","cliff","paving","thermal","blood"},
}
local switches={pollution="degradation",restoration="recovery",["tree-stress"]="tree_stress",
    ["tree-recovery"]="tree_stress",regrowth="tree_regrowth",aging="aging",rot="rot",
    ["depletion-scars"]="mining_scars",["working-scars"]="periodic_mining_scars",["mining-restoration"]="mining_recovery",
    wildfire="wildfire",flood="flood",drought="drought",cliff="cliffs",paving="paving",thermal="thermal_scars",blood="blood"}
local function text(key,...) return {"ei-ecology-field."..key,...} end

---Report-specific localized simulation duration; no wall clock or world reads.
---@param ticks number?
---@return LocalisedString
function model.duration(ticks)
    if not lib.is_valid_number(ticks) then return text("no-time") end
    local seconds=math.max(0,math.floor(ticks/60))
    if seconds<60 then return text("duration-s",seconds) end
    if seconds<3600 then return text("duration-ms",math.floor(seconds/60),seconds%60) end
    return text("duration-hm",math.floor(seconds/3600),math.floor(seconds/60)%60)
end

---@class EsirEcologyDayCycle
---@field available boolean
---@field reason string?
---@field phase string?
---@field period number?
---@field fractions number[]? Day, evening, night, morning; starts at full daylight.
---@field position number? Rotation position relative to dawn, in [0,1).
---@field next_phase string?
---@field remaining number?
---@field frozen boolean?
---@field permanent boolean?
---@field variable boolean?
---@field observed_tick MapTick?

---Pure boundary calculation shared with focused fixtures. Does not clamp the
---observer to ESIR's own seasonal limits: externally supplied tuples stay native.
---@param daytime number
---@param period number
---@param tuple DaytimeParameters
---@param frozen boolean
---@param permanent boolean
---@return EsirEcologyDayCycle
function model.calculate_cycle(daytime,period,tuple,frozen,permanent)
    local unavailable={available=false,reason="invalid-cycle"}
    if not lib.is_valid_number(daytime) or not lib.is_valid_number(period) or period<=0 or type(tuple)~="table" then return unavailable end
    local d,e,m,a=tuple.dusk,tuple.evening,tuple.morning,tuple.dawn
    if not lib.is_valid_number(d) or not lib.is_valid_number(e) or not lib.is_valid_number(m) or not lib.is_valid_number(a)
        or not (0<=d and d<e and e<m and m<a and a<=1) then return unavailable end
    local t=daytime%1
    local stage,boundary,next_stage=1,d,2
    if t>=d and t<e then stage,boundary,next_stage=2,e,3
    elseif t>=e and t<m then stage,boundary,next_stage=3,m,4
    elseif t>=m and t<a then stage,boundary,next_stage=4,a,1 end
    return {available=true,phase=permanent and "day" or phases[stage],period=period,
        fractions=permanent and {1,0,0,0} or {d+1-a,e-d,m-e,a-m},position=permanent and t or (t-a)%1,
        next_phase=phases[next_stage],remaining=not frozen and not permanent and ((boundary-t)%1)*period or nil,
        frozen=frozen,permanent=permanent}
end

---Constant-count native getters, called only for an admitted open Simple view.
---This observer never passes a tuple back to the calendar or writes the surface.
---@param surface LuaSurface
---@param tick MapTick
---@param fulgora EsirFulgoraDayReportApi
---@return EsirEcologyDayCycle
function model.observe_cycle(surface,tick,fulgora)
    if not surface or not surface.valid or surface.platform or not surface.planet then return {available=false,reason="no-cycle"} end
    local cycle=model.calculate_cycle(surface.daytime,surface.ticks_per_day,surface.daytime_parameters,surface.freeze_daytime,surface.always_day)
    cycle.observed_tick=tick
    cycle.variable=fulgora.report_status(surface).managed
    return cycle
end

---Integer partition keeps tiny external light phases from widening the strip.
---@param fractions number[]
---@param width integer
---@return integer[]
function model.segment_widths(fractions,width)
    local widths={};local sum,previous=0,0
    for i=1,4 do
        sum=sum+fractions[i]
        local edge=i==4 and width or math.floor(sum*width+1e-8)
        widths[i]=edge-previous;previous=edge
    end
    return widths
end

local function activity(report,category,tick,planet)
    local count=(report.effects or {})[category] or 0
    local cfg=report.effective or {}
    local when=(report.effect_ticks or {})[category]
    local detail=count==0 and text("no-activity") or when and text("last",model.duration(tick-when)) or text("no-time")
    local woodland=category=="tree-stress" or category=="tree-recovery" or category=="regrowth" or category=="wildfire"
    local industrial=woodland or category=="pollution" or category=="restoration" or category=="mining-restoration"
    local unavailable=report.status=="unsupported"
        or ((category=="flood" or category=="drought") and planet~="nauvis")
        or ((category=="aging" or category=="rot") and planet~="nauvis")
        or (woodland and report.woodland_supported==false)
        or (industrial and report.pollution_supported==false)
    if unavailable then detail={"",detail,"; ",text("feature-unavailable")}
    elseif cfg.enabled==false or cfg[switches[category]]==false or (category=="wildfire" and cfg.wildfire=="off")
        or (category=="working-scars" and cfg.mining_scars==false)
        or (category=="mining-restoration" and cfg.recovery==false)
        or (category=="paving" and cfg.blood==false) then detail={"",detail,"; ",text("feature-off")} end
    return text("effect",{"ei-ecology.category-"..category},count,detail)
end

local function card(report,key,tick,planet)
    local result={""}
    for _,category in ipairs(categories[key]) do
        if #result>1 then result[#result+1]="\n" end
        result[#result+1]=activity(report,category,tick,planet)
    end
    return result
end

---@class EsirEcologyFieldReport
---@field values table<string, LocalisedString|string|number|boolean>
---@field cycle EsirEcologyDayCycle
---@field planet string?

---Compose scalar readings and captions, with no history walks or world searches.
---@param report SurfaceEcologyReport
---@param surface LuaSurface
---@param tick MapTick
---@param fulgora EsirFulgoraDayReportApi
---@param strip_width integer
---@return EsirEcologyFieldReport
function model.compose(report,surface,tick,fulgora,strip_width)
    local planet=surface.planet and not surface.platform and surface.planet.name or nil
    local cfg=report.effective or {};local calendar=report.calendar or {}
    local cycle=model.observe_cycle(surface,tick,fulgora)
    local status=report.status=="unsupported" and "unsupported" or report.status=="disabled" and "disabled"
        or report.status~="enabled" and "suspended" or not report.sample_age and "unknown"
        or report.sample_age>1200 and "outdated" or "observed"
    local season=lib.is_valid_number(calendar.phase) and math.floor((calendar.phase%1)*4)+1 or 0
    local icon=planet and "space-location/"..planet or "utility/clock"
    if not helpers.is_valid_sprite_path(icon) then icon="utility/clock" end
    local values={
        identity=text("identity",planet and surface.planet.prototype.localised_name or text("status-unsupported"),surface.name),
        status=text("status-"..status),icon=icon,
        banner=planets[planet] and "ei-ecology-banner-"..planet or "ei-ecology-banner-neutral",
        banner_visible=planets[planet]==true,
        tree="ei-ecology-tree-"..(seasons[season] or "summer"),
        day=text(cycle.reason or "invalid-cycle"),day_marker=0,day_available=cycle.available,
        season=text("no-calendar"),season_marker=0,calendar_tip=text("no-calendar"),season_available=false,
        ground=card(report,"ground",tick,planet),woodland=card(report,"woodland",tick,planet),
        mining=card(report,"mining",tick,planet),other=card(report,"other",tick,planet),
        ground_note=report.pollution_supported==true and cfg.pollution_high and text("ground-conditions",cfg.pollution_high,
            model.duration(cfg.dirty_seconds*60),cfg.pollution_low,model.duration(cfg.clean_seconds*60)) or text("pollution-unavailable"),
        woodland_note=text(report.woodland_supported==false and "woodland-unavailable" or "woodland-help"),
        mining_note=text(cfg.mining_recovery and "mining-recovery-on" or "mining-recovery-off"),
    }
    if report.status=="unsupported" or report.pollution_supported==false or cfg.enabled==false or cfg.recovery==false then
        values.mining_note={"",{"ei-ecology.category-mining-restoration"},": ",
            text((report.status=="unsupported" or report.pollution_supported==false) and "feature-unavailable" or "feature-off")}
    end
    if cycle.available then
        local next_light=cycle.permanent and text(cycle.frozen and "permanent-held" or "permanent")
            or cycle.frozen and text("held") or text("next-light",text(cycle.next_phase),model.duration(cycle.remaining))
        if cycle.variable then next_light={"",next_light,"\n",text("variable")} end
        -- Allocate whole display seconds together so rounding cannot lose a
        -- second from each phase and make the four parts disagree with the day.
        local seconds=model.segment_widths(cycle.fractions,math.floor(cycle.period/60))
        values.day=text("clock",text(cycle.permanent and "permanent" or cycle.phase),model.duration(cycle.period),
            model.duration(seconds[1]*60),model.duration(seconds[3]*60),
            model.duration(seconds[2]*60),model.duration(seconds[4]*60),next_light)
        values.day_marker=math.max(0,math.min(strip_width-20,math.floor(cycle.position*strip_width-10)))
    end
    local widths=model.segment_widths(cycle.available and cycle.fractions or {0.25,0.25,0.25,0.25},strip_width)
    for i=1,4 do values["day_width_"..i]=widths[i];values["day_visible_"..i]=widths[i]>0 end
    if season>0 and lib.is_valid_number(calendar.period_ticks) and calendar.period_ticks>0 then
        values.season_available=true
        local phase=calendar.phase%1;local progress=(phase*4)%1
        values.season=text("seasons",{"ei-ecology.season-"..season},math.floor(progress*100),math.floor(phase*100),
            model.duration((1-progress)*calendar.period_ticks/4),model.duration(calendar.period_ticks),
            cycle.available and string.format("%.1f",calendar.period_ticks/cycle.period) or "—")
        values.season_marker=math.max(0,math.min(strip_width-20,math.floor(phase*strip_width-10)))
        values.calendar_tip=text("calendar-help",string.format("%.1f",calendar.reference_days or 0))
    end
    local cs=calendar.status
    local daylight=planet=="fulgora" and "independent" or cfg.seasonal_daylight==false and "disabled"
        or (cycle.frozen or cycle.permanent) and "paused" or (cs=="active" or cs=="active-clamped") and "active"
        or (cs=="external-control" or calendar.blocker) and "external"
        or (cs=="disabled" or cfg.seasonal_daylight==false) and "disabled"
        or cs=="frozen" and "paused" or "pending"
    values.daylight=values.season_available and text("daylight-"..daylight) or ""
    local coverage=report.coverage=="observed" and "observed" or report.coverage=="discovering" and "discovering"
        or (report.coverage and report.coverage~="unknown") and "limited" or "unknown"
    values.survey=report.sample_age and text("survey",model.duration(report.sample_age),text("coverage-"..coverage)) or text("survey-none")
    return {values=values,cycle=cycle,planet=planet}
end
return model
