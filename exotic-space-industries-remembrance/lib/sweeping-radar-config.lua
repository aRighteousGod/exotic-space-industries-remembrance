--==============================================================================
-- ESIR FILE MAP
-- owns: sweeping radar hardware, research, interfaces and deterministic budgets
-- loaded_by: prototypes/sweeping-radar and scripts/control/sweeping-radar
-- cadence: constants only; safe in data and control stages
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local config = {}
---@class ESIRRadarManualGeometry
---@field radius number
---@field near number
---@field start number
---@field stop number
---@field bearing number
---@field direction number

---@class ESIRRadarSettings
---@field version integer
---@field mode integer
---@field speed number
---@field policy integer
---@field contacts integer
---@field expiry number
---@field run number
---@field trigger number
---@field modes table<integer,ESIRRadarManualGeometry>
---@field overrides table<string,{enabled:boolean,signal:SignalID?}>
config.version = 1
config.capability_revision = 2
config.input = "ei-sweeping-radar-open"
config.output = "ei-sweeping-radar-output"
config.tag = "ei_sweeping_radar"
config.gui = "ei_sweeping_radar_gui"
config.hardware = {
    ["ei-sweeping-radar"] = {range=16, rate=2, joules=8000000, idle=1000000,
        input=64000000, buffer=16000000, health=250, tint={0.75,0.9,1}, tier=1},
    ["ei-phased-array-radar"] = {range=24, rate=8, joules=5000000, idle=2000000,
        input=128000000, buffer=10000000, health=500, tint={0.9,0.65,1}, tier=2},
}
config.names = {"ei-sweeping-radar", "ei-phased-array-radar"}
config.budget = {control=4, geometry=64, observation=2, aggregate=64,
    maintenance=64, publish=2, viewer=1, jobs=32, generation_jobs=16,
    generation_interval=30,generation_timeout=3600}
config.poll_ticks = 10
config.ui_ticks = 15
config.contact_limit = 2048
config.query_limit = 129
config.range_bonus = {0,2,4,8}
config.rate_bonus = {1,1.25,1.5,2}
config.energy_bonus = {1,0.9,0.8,0.7}
-- Fixed quality-level anchors keep existing rarities stable when mods add tiers.
-- Range is a selectable ceiling; quality never enlarges saved manual geometry.
config.quality_anchors = {
    {level=0,range=0,rate=1,energy=1},
    {level=1,range=1,rate=1.10,energy=0.95},
    {level=2,range=2,rate=1.20,energy=0.90},
    {level=3,range=3,rate=1.35,energy=0.85},
    {level=5,range=4,rate=1.50,energy=0.80},
}

---@param level number Quality prototype level; bonuses saturate at Legendary.
---@return integer range_bonus
---@return number rate_multiplier
---@return number energy_multiplier
function config.quality_effects(level)
    if type(level)~="number" or level~=level then level=0 end
    level=math.max(0,math.min(5,level))
    for index=2,#config.quality_anchors do
        local upper,lower=config.quality_anchors[index],config.quality_anchors[index-1]
        if level<=upper.level then
            local fraction=(level-lower.level)/(upper.level-lower.level)
            return math.floor(lower.range+(upper.range-lower.range)*fraction),
                lower.rate+(upper.rate-lower.rate)*fraction,
                lower.energy+(upper.energy-lower.energy)*fraction
        end
    end
    error("Radar quality anchors must cover levels 0 through 5")
end
config.branches = {"range", "capacity", "efficiency"}
config.fields = {
    {key="mode", signal="M", min=1, max=5},
    {key="radius", signal="R", min=1, max=36},
    {key="near", signal="N", min=0, max=35},
    {key="start", signal="B", angle=true},
    {key="stop", signal="E", angle=true},
    {key="bearing", signal="H", angle=true},
    {key="speed", signal="S", min=0, max=100},
    {key="direction", signal="D", min=-1, max=1},
    {key="policy", signal="P", min=0, max=1},
    {key="contacts", signal="C", min=1, max=3},
    {key="expiry", signal="T", min=1, max=300},
    {key="run", signal="G"},
    {key="trigger", signal="X"},
}
config.outputs = {"ready", "scanning", "valid", "contacts", "bearing", "distance",
    "report-age", "contact-age", "incomplete", "heading", "sample-age"}

---@return ESIRRadarSettings
function config.defaults()
    local modes = {}
    for mode=1,5 do
        modes[mode] = {radius=12, near=mode==3 and 10 or 0,
            start=(mode==2 or mode==4) and 315 or 0,
            stop=(mode==2 or mode==4) and 45 or 0, bearing=0,
            direction=mode==2 and 0 or 1}
    end
    return {version=1, mode=1, speed=100, policy=1, contacts=1, expiry=30,
        run=1, trigger=0, modes=modes, overrides={}}
end

---@param value ESIRRadarSettings|table|nil
---@return ESIRRadarSettings
function config.copy_settings(value)
    local result = config.defaults()
    if type(value) ~= "table" then return result end
    for _,key in ipairs{"mode","speed","policy","contacts","expiry","run","trigger"} do
        if type(value[key]) == "number" then result[key] = value[key] end
    end
    result.mode = math.max(1,math.min(5,math.floor(result.mode)))
    for mode=1,5 do
        local source = value.modes and (value.modes[mode] or value.modes[tostring(mode)])
        if type(source)=="table" then
            for key in pairs(result.modes[mode]) do
                if type(source[key])=="number" then result.modes[mode][key]=source[key] end
            end
        end
    end
    for _,field in ipairs(config.fields) do
        local source=value.overrides and value.overrides[field.key]
        if type(source)=="table" then
            local signal=source.signal
            result.overrides[field.key]={enabled=source.enabled==true}
            if type(signal)=="table" and type(signal.name)=="string" then
                result.overrides[field.key].signal={type=signal.type or "item",name=signal.name,
                    quality=signal.quality or "normal"}
            end
        end
    end
    return result
end
return config
