--==============================================================================
-- ESIR FILE MAP
-- owns: flammable fluid death analysis and rupture spec construction
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: on_entity_died only
-- forwarded_events: on_entity_died
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime prototype changes
--==============================================================================

local ei_lib = require("lib/lib")
local fluid_safety_config = require("lib/fluid-safety-config")
local fluid_rupture_effects = require("scripts/control/fluid-rupture-effects")

local model = {}

local DAMAGE_TYPE_CHANCES = {
    physical = 0.95,
    impact = 0.95,
    poison = 0.45,
    explosion = 0.75,
    fire = 0.95,
    laser = 0.5,
    acid = 0.5,
    electric = 0.5,
    toxic = 0.45,
    ["sore-acid"] = 0.55,
    cold = 0.35,
    ["ei-plasma"] = 0.95,
    script = 1,
}

local DAMAGE_TYPE_HINT_CHANCES = {
    {hint = "plasma", chance = DAMAGE_TYPE_CHANCES["ei-plasma"]},
    {hint = "tesla", chance = DAMAGE_TYPE_CHANCES.electric},
    {hint = "electric", chance = DAMAGE_TYPE_CHANCES.electric},
    {hint = "sore-acid", chance = DAMAGE_TYPE_CHANCES["sore-acid"]},
    {hint = "acid", chance = DAMAGE_TYPE_CHANCES.acid},
    {hint = "toxic", chance = DAMAGE_TYPE_CHANCES.toxic},
    {hint = "poison", chance = DAMAGE_TYPE_CHANCES.poison},
    {hint = "cold", chance = DAMAGE_TYPE_CHANCES.cold},
    {hint = "fire", chance = DAMAGE_TYPE_CHANCES.fire},
    {hint = "laser", chance = DAMAGE_TYPE_CHANCES.laser},
    {hint = "explosion", chance = DAMAGE_TYPE_CHANCES.explosion},
    {hint = "impact", chance = DAMAGE_TYPE_CHANCES.impact},
    {hint = "physical", chance = DAMAGE_TYPE_CHANCES.physical},
}

local NON_FLAMMABLE_FLUIDS = {
    ["ei-liquid-nitrogen"] = true,
}

local OIL_FAMILY_HINTS = {
    "crude",
    "oil",
    "petroleum",
    "diesel",
    "kerosene",
    "destilate",
    "distill",
    "benzol",
    "fuel",
    "naptha",
    "naphtha",
    "tar",
}

local EXOTIC_FAMILY_HINTS = {
    "morphium",
    "phytho",
    "coolant",
    "fusion",
    "critical-steam",
    "drill-fluid",
    "cryoflux",
    "plasma",
    "antimatter",
    "quantum",
    "singularity",
    "protium",
    "deuterium",
    "tritium",
}

local ENERGY_THRESHOLD_MJ = 10

local function get_damage_type_name(event)
    if event and event.damage_type and event.damage_type.name then
        return event.damage_type.name
    end
    return "script"
end

local function get_damage_gate_chance(damage_type_name)
    local chance = DAMAGE_TYPE_CHANCES[damage_type_name]
    if chance then
        return chance
    end

    local lowered = damage_type_name and string.lower(damage_type_name) or nil
    if not lowered then
        return nil
    end

    for _, hint in ipairs(DAMAGE_TYPE_HINT_CHANCES) do
        if string.find(lowered, hint.hint, 1, true) then
            return hint.chance
        end
    end

    return nil
end

local function passes_damage_gate(event)
    local chance = get_damage_gate_chance(get_damage_type_name(event))
    return chance and chance > 0 and math.random() <= chance
end

local function name_has_hint(name, hints)
    for _, hint in ipairs(hints) do
        if string.find(name, hint, 1, true) then
            return true
        end
    end
    return false
end

local function is_flammable_fluid(fluid)
    return fluid and not NON_FLAMMABLE_FLUIDS[fluid.name] and (fluid.fuel_value or 0) > 0
end

local function is_gas_fluid(fluid)
    if not fluid then
        return false
    end

    if fluid.default_temperature and fluid.gas_temperature and fluid.default_temperature >= fluid.gas_temperature then
        return true
    end

    local name = fluid.name or ""
    return (not string.find(name, "gasoline", 1, true))
        and (
            string.find(name, "-gas", 1, true) ~= nil
            or string.find(name, "gas-", 1, true) ~= nil
            or string.find(name, " steam", 1, true) ~= nil
            or string.find(name, "-steam", 1, true) ~= nil
            or name == "steam"
        )
end

local function classify_fluid_family(fluid)
    if not fluid then
        return "oil"
    end

    local name = fluid.name or ""
    if name_has_hint(name, EXOTIC_FAMILY_HINTS) then
        return "exotic"
    end
    if is_gas_fluid(fluid) then
        return "gas"
    end
    if name_has_hint(name, OIL_FAMILY_HINTS) then
        return "oil"
    end
    if string.sub(name, 1, 3) == "ei-" then
        return "exotic"
    end
    return "oil"
end

local function analyze_fluidboxes(entity)
    local fluidbox = entity.fluidbox
    if not fluidbox or #fluidbox <= 0 then
        return nil
    end

    local total_energy_mj = 0
    local total_pollution = 0
    local family_energy_mj = {oil = 0, gas = 0, exotic = 0}
    local per_fluid_energy = {}

    for index = 1, #fluidbox do
        local contents = fluidbox[index]
        if contents and contents.name and contents.amount and contents.amount > 0 then
            local fluid = prototypes.fluid[contents.name]
            if is_flammable_fluid(fluid) then
                local fuel_value = fluid.fuel_value or 0
                local energy_mj = (fuel_value * contents.amount) / 1000000
                if energy_mj > 0 then
                    local family = classify_fluid_family(fluid)
                    total_energy_mj = total_energy_mj + energy_mj
                    family_energy_mj[family] = family_energy_mj[family] + energy_mj
                    total_pollution = total_pollution + (((fuel_value / 1800000) * 0.5 * (fluid.emissions_multiplier or 1) * contents.amount) / 1.5)
                    per_fluid_energy[fluid.name] = (per_fluid_energy[fluid.name] or 0) + energy_mj
                end
            end
        end
    end

    local dominant_name = nil
    local dominant_energy_mj = nil
    for fluid_name, energy_mj in pairs(per_fluid_energy) do
        if not dominant_energy_mj or energy_mj > dominant_energy_mj then
            dominant_name = fluid_name
            dominant_energy_mj = energy_mj
        end
    end

    if total_energy_mj <= ENERGY_THRESHOLD_MJ or not dominant_name then
        return nil
    end

    local dominant_family = "oil"
    local dominant_fluid = prototypes.fluid[dominant_name]
    if dominant_fluid then
        dominant_family = classify_fluid_family(dominant_fluid)
    end

    local family_share = {}
    for family, energy_mj in pairs(family_energy_mj) do
        family_share[family] = energy_mj / total_energy_mj
    end

    return {
        total_energy_mj = total_energy_mj,
        total_pollution = total_pollution,
        family_share = family_share,
        dominant_family = dominant_family,
        dominant = {
            family = dominant_family,
            fluid_name = dominant_name,
            energy_mj = dominant_energy_mj,
        },
    }
end

local function build_effect_spec(entity, rupture)
    local carrier_class = entity.type
    if entity.name == "elevated-pipe" then
        carrier_class = "elevated-line"
    elseif entity.type == "storage-tank" or entity.type == "fluid-wagon" then
        carrier_class = "vessel"
    end

    return {
        effect_family = rupture.dominant_family,
        effect_variant = rupture.dominant and rupture.dominant.fluid_name or "rupture",
        carrier_class = carrier_class,
        severity = rupture.total_energy_mj,
        pollution_amount = rupture.total_pollution / 10,
        allow_pipeline_fire = true,
        allow_platform_tile_damage = true,
        source_force_name = entity.force and entity.force.name or "neutral",
        damage_scale = 1,
        family_mix = rupture.family_share,
        rupture = rupture,
    }
end

function model.on_entity_died(event)
    local entity = event and event.entity
    if not entity or not entity.valid or entity.type == "pump" then
        return
    end
    if not passes_damage_gate(event) then
        return
    end
    if fluid_safety_config.is_ignored_entity(entity) then
        return
    end

    local rupture = analyze_fluidboxes(entity)
    if not rupture then
        return
    end

    fluid_rupture_effects.queue_effect(entity, build_effect_spec(entity, rupture), ei_lib.get_event_tick(event))
end

return model
