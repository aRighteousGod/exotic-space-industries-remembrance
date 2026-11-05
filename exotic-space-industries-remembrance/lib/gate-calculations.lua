-- blueprint: .codex/esir/blueprints/gate.md#contract
-- Pure gate arithmetic shared by transport and the detached estimator. No world writes.
local lib = require("lib/lib")
local model = {}
model.low_power = 100e9
model.max_stress = 100
model.stress_decay = 1
model.saturation_decay = 1.5
model.residue_threshold = 250

function model.quality_multiplier(level)
    return 1 / (1 + 0.2 * math.max(0, level or 0))
end

function model.energy(burden)
    if not burden or burden <= 0 then return 0 end
    return (burden ^ 1.2) * 100 * 1e6
end

function model.span_ratio(multiplier)
    return lib.clamp((multiplier - 0.15) / (8 - 0.15), 0, 1)
end

---@param kind string local, orbital, distance or unknown
---@param distance number
---@param maximum number
---@return number
function model.distance_multiplier(kind, distance, maximum)
    if kind == "local" then return 0.15 end
    if kind == "orbital" then return 2.5 end
    if kind == "unknown" then return 3 end
    return 2.5 + (8 - 2.5) * lib.clamp(distance / math.max(1, maximum), 0, 1) ^ 0.6
end

---@return table quote Side-effect-free quote; quality multiplier is already normalized.
function model.quote(burden, count, distance_multiplier, quality_multiplier, span_ratio)
    local base = model.energy(burden)
    local ratio = span_ratio or model.span_ratio(distance_multiplier)
    return {count=count, burden=burden, base_energy_j=base,
        energy_multiplier=quality_multiplier, distance_multiplier=distance_multiplier, span_ratio=ratio,
        energy_j=math.floor(base * distance_multiplier * quality_multiplier),
        stress_delta=math.min(35, math.sqrt(math.max(0, burden)) * (1 + 0.75 * ratio)),
        saturation_delta=math.min(20, math.sqrt(math.max(0, burden)) * 0.8), residue_delta=burden}
end

function model.after_transfer(stress, quote)
    local result = lib.clamp(stress + (quote.stress_delta or 0), 0, 100)
    return result, 30 + math.floor(math.sqrt(math.max(0, quote.burden or 0)) * 15) + math.floor(result * 2)
end

function model.upkeep(stress, cooling, multiplier)
    return (30e6 + math.max(0, stress) * 1.5e6 + (cooling and 30e6 or 0)) * multiplier
end

-- Preserve live service's trapezoidal stress integration, including its zero clamp.
function model.elapsed(stress, elapsed_ticks, cooling_ticks, multiplier)
    local seconds = elapsed_ticks / 60
    local ending = lib.clamp(stress - seconds, 0, 100)
    local drain = 30e6 * seconds
    local average = (stress + ending) / 2
    if average > 0 then drain = drain + average * 1.5e6 * seconds end
    if cooling_ticks > 0 then drain = drain + 30e6 * (cooling_ticks / 60) end
    return ending, drain * multiplier
end

return model
