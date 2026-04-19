--==============================================================================
-- ESIR FILE MAP
-- owns: tech cost scaling
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, configuration-changed, and research-finished
-- forwarded_events: get_multiplier, init, on_research_finished, on_scripted_research_burst
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup settings, prototype changes
--==============================================================================
-- Count visible, non-repeatable technologies with thematic weighting discounts applied to
-- refinement-heavy branches, then use that total to set technology_price_multiplier.

local ei_tech_scaling = {}
local tech_weighting = require("lib/tech-weighting")
local tech_scaling_common = require("lib/tech-scaling-common")
local tech_scaling_shared = require("lib/tech-scaling-shared")

local CORE_AGES = {
    "dark-age",
    "steam-age",
    "electricity-age",
    "computer-age",
    "quantum-age",
    "exotic-age",
}

local AGE_SEGMENTS = {
    ["dark-age"] = { share = 0.02, curve = "linear" },
    ["steam-age"] = { share = 0.06, curve = "linear" },
    ["electricity-age"] = { share = 0.14, curve = "quadratic" },
    ["computer-age"] = { share = 0.23, curve = "quadratic" },
    ["quantum-age"] = { share = 0.25, curve = "exponential" },
    ["exotic-age"] = { share = 0.30, curve = "exponential" },
}

local AGE_PACK_TO_AGE = {
    ["ei-dark-age-tech"] = "dark-age",
    ["ei-steam-age-tech"] = "steam-age",
    ["ei-electricity-age-tech"] = "electricity-age",
    ["ei-computer-age-tech"] = "computer-age",
    ["ei-advanced-computer-age-tech"] = "advanced-computer-age",
    ["ei-alien-computer-age-tech"] = "alien-computer-age",
    ["ei-quantum-age-tech"] = "quantum-age",
    ["ei-fusion-quantum-age-tech"] = "fusion-quantum-age",
    ["ei-exotic-age-tech"] = "exotic-age",
    ["ei-black-hole-exotic-age-tech"] = "black-hole-exotic-age",
}

local function new_age_total_table()
    local totals = {}

    for _, age in ipairs(CORE_AGES) do
        totals[age] = 0
    end

    return totals
end

local function ensure_age_total_table(age_totals)
    age_totals = type(age_totals) == "table" and age_totals or {}

    for _, age in ipairs(CORE_AGES) do
        if age_totals[age] == nil then
            age_totals[age] = 0
        end
    end

    return age_totals
end

local ensure_researched_snapshot

local function ensure_tech_scaling_storage()
    if not storage.ei then
        storage.ei = {}
    end

    if type(storage.ei.tech_scaling) ~= "table" then
        storage.ei.tech_scaling = {}
    end

    storage.ei.tech_scaling.ageTotals = ensure_age_total_table(storage.ei.tech_scaling.ageTotals)
    storage.ei.tech_scaling.appliedMultiplier = tonumber(storage.ei.tech_scaling.appliedMultiplier) or 1
    storage.ei.tech_scaling.additionalMultiplier = tonumber(storage.ei.tech_scaling.additionalMultiplier) or nil
    storage.ei.tech_scaling.disabled = storage.ei.tech_scaling.disabled == true
    storage.ei.tech_scaling.curveForm = type(storage.ei.tech_scaling.curveForm) == "string"
        and storage.ei.tech_scaling.curveForm
        or nil
    storage.ei.tech_scaling.techMetaByName = type(storage.ei.tech_scaling.techMetaByName) == "table" and storage.ei.tech_scaling.techMetaByName or {}
    storage.ei.tech_scaling.researchedSnapshot = ensure_researched_snapshot(storage.ei.tech_scaling.researchedSnapshot)
    storage.ei.tech_scaling.selectedForceKey = storage.ei.tech_scaling.selectedForceKey or nil
    storage.ei.tech_scaling.cacheRevision = tonumber(storage.ei.tech_scaling.cacheRevision) or 0

    if storage.ei.tech_scaling.unknownAgeLogged == nil then
        storage.ei.tech_scaling.unknownAgeLogged = false
    end

    return storage.ei.tech_scaling
end

local function get_force_key(force)
    return force and force.name or nil
end

local function new_researched_snapshot(force_key)
    return {
        forceKey = force_key,
        totalWeight = 0,
        ageTotals = new_age_total_table(),
        researchedByName = {},
    }
end

ensure_researched_snapshot = function(snapshot, force_key)
    snapshot = type(snapshot) == "table" and snapshot or new_researched_snapshot(force_key)
    snapshot.forceKey = force_key or snapshot.forceKey
    snapshot.totalWeight = tonumber(snapshot.totalWeight) or 0
    snapshot.ageTotals = ensure_age_total_table(snapshot.ageTotals)
    snapshot.researchedByName = type(snapshot.researchedByName) == "table" and snapshot.researchedByName or {}

    return snapshot
end

local function get_primary_force()
    return game.forces.player or game.forces[1]
end

local function get_cached_curve_form(tech_scaling)
    local curve_form = tech_scaling and tech_scaling.curveForm or nil
    return type(curve_form) == "string" and curve_form ~= "" and curve_form or "linear"
end

local function get_cached_additional_multiplier(tech_scaling)
    return tonumber(tech_scaling and tech_scaling.additionalMultiplier) or 1
end

local function tech_scaling_disabled(tech_scaling)
    return tech_scaling and tech_scaling.disabled == true
end

local function static_cache_ready(tech_scaling)
    if type(tech_scaling) ~= "table" or type(tech_scaling.techMetaByName) ~= "table" then
        return false
    end

    if tonumber(tech_scaling.maxCost) == nil
        or tonumber(tech_scaling.startPrice) == nil
        or tonumber(tech_scaling.baseStartPrice) == nil
        or tonumber(tech_scaling.techCount) == nil
    then
        return false
    end

    if type(tech_scaling.curveForm) ~= "string" or tech_scaling.curveForm == "" then
        return false
    end

    if tonumber(tech_scaling.additionalMultiplier) == nil then
        return false
    end

    if tech_scaling.curveForm == "age-ramp" and type(tech_scaling.ageTotals) ~= "table" then
        return false
    end

    return true
end

local function sanitize_prices(max_cost, start_price)
    start_price = math.max(1, tonumber(start_price) or 1)
    max_cost = math.max(start_price, tonumber(max_cost) or start_price)

    return max_cost, start_price
end

local function apply_curve(progress, curve_name)
    progress = math.max(0, math.min(tonumber(progress) or 0, 1))

    if curve_name == "linear" then
        return progress
    end

    if curve_name == "quadratic" then
        return progress * progress
    end

    if curve_name == "exponential" then
        if progress <= 0 then
            return 0
        end

        return (2 ^ progress) - 1
    end

    return progress
end

local function normalize_age(age)
    if not age then
        return nil
    end

    local collapsed_age = ei_data.sub_age[age] or age

    if AGE_SEGMENTS[collapsed_age] then
        return collapsed_age
    end

    return nil
end

local function resolve_technology_prototype(technology, key)
    if not technology then
        return nil, key
    end

    local technology_name = technology.name or key

    if technology.object_name == "LuaTechnologyPrototype" then
        return technology, technology_name
    end

    local technology_prototypes = prototypes and prototypes.technology
    return technology_prototypes and technology_prototypes[technology_name] or nil, technology_name
end

local function get_ingredient_name(ingredient)
    if type(ingredient) ~= "table" then
        return nil
    end

    return ingredient.name or ingredient[1]
end

local function get_runtime_technology_age(prototype)
    if not prototype then
        return nil
    end

    local highest_age
    local research_ingredients = prototype.research_unit_ingredients or {}

    -- Runtime technology prototypes do not expose the custom data-stage `age` field, so use the
    -- finalized research ingredients as the stable post-data-fixes age signal instead.
    for _, ingredient in pairs(research_ingredients) do
        local ingredient_age = AGE_PACK_TO_AGE[get_ingredient_name(ingredient)]

        if ingredient_age and (
            not highest_age
            or (ei_data.ages_with_sub[ingredient_age] or 0) > (ei_data.ages_with_sub[highest_age] or 0)
        ) then
            highest_age = ingredient_age
        end
    end

    return highest_age
end

local function count_weighted_technologies(technologies, include_technology, tech_meta_by_name)
    local total_weight = 0
    local age_weights = new_age_total_table()
    local tech_scaling = ensure_tech_scaling_storage()

    tech_meta_by_name = tech_meta_by_name or {}

    for key, technology in pairs(technologies or {}) do
        local prototype, technology_name = resolve_technology_prototype(technology, key)

        if include_technology(technology, prototype, technology_name, key) then
            technology_name = technology_name or (prototype and prototype.name) or key
            local weight = tech_weighting.get_technology_weight(technology_name, prototype)
            local runtime_age = get_runtime_technology_age(prototype)
            local age = normalize_age(runtime_age)

            if not age then
                age = "dark-age"

                if not tech_scaling.unknownAgeLogged then
                    log(
                        "EI tech scaling age-ramp encountered an unknown technology age for "
                            .. tostring(technology_name)
                            .. " ("
                            .. tostring(runtime_age)
                            .. "); bucketing it to dark-age for this rebuild."
                    )
                    tech_scaling.unknownAgeLogged = true
                end
            end

            age_weights[age] = (age_weights[age] or 0) + weight
            total_weight = total_weight + weight
            tech_meta_by_name[technology_name] = {
                countable = true,
                weight = weight,
                age = age,
            }
        end
    end

    return total_weight, age_weights, tech_meta_by_name
end

local function build_researched_snapshot(force, tech_meta_by_name)
    local snapshot = new_researched_snapshot(get_force_key(force))
    local force_technologies = force and force.technologies or nil

    if not force_technologies then
        return snapshot
    end

    tech_meta_by_name = tech_meta_by_name or ensure_tech_scaling_storage().techMetaByName or {}

    for technology_name, meta in pairs(tech_meta_by_name) do
        local technology = force_technologies[technology_name]

        if technology and technology.enabled and technology.researched and meta and meta.countable then
            snapshot.totalWeight = snapshot.totalWeight + meta.weight
            snapshot.ageTotals[meta.age] = (snapshot.ageTotals[meta.age] or 0) + meta.weight
            snapshot.researchedByName[technology_name] = true
        end
    end

    return snapshot
end

local function rebuild_researched_snapshot_from_cache(force)
    local tech_scaling = ensure_tech_scaling_storage()
    local force_key = get_force_key(force)

    if not force_key or not static_cache_ready(tech_scaling) then
        return false
    end

    if next(tech_scaling.techMetaByName) == nil and (tonumber(tech_scaling.techCount) or 0) > 0 then
        return false
    end

    tech_scaling.selectedForceKey = force_key
    tech_scaling.researchedSnapshot = ensure_researched_snapshot(
        build_researched_snapshot(force, tech_scaling.techMetaByName),
        force_key
    )
    tech_scaling.cacheRevision = (tonumber(tech_scaling.cacheRevision) or 0) + 1

    return true
end

local function rebuild_runtime_cache(force)
    local tech_scaling = ensure_tech_scaling_storage()

    tech_scaling.unknownAgeLogged = false

    local maxCost = ei_lib.switch_string(
        ei_data["tech_scaling"].switch_table,
        ei_lib.config("tech-scaling-maxCost")
    ) or tech_scaling.maxCost or ei_data["tech_scaling"].switch_table["Default"]

    local startPrice = ei_lib.config("tech-scaling-startPrice") or tech_scaling.startPrice or 10
    local additional_multiplier = tonumber(ei_lib.config("tech-scaling-additionalMultiplier")) or 1
    local curve_form = ei_lib.config("tech-scaling-curveForm")

    tech_scaling.maxCost = maxCost
    tech_scaling.startPrice = startPrice
    tech_scaling.additionalMultiplier = additional_multiplier
    tech_scaling.disabled = ei_lib.config("no-tech-scaling") == true
    tech_scaling.curveForm = curve_form
    tech_scaling.baseStartPrice = tech_scaling_common.get_effective_base_start_price(
        startPrice,
        maxCost,
        additional_multiplier
    )

    local technology_prototypes = prototypes and prototypes.technology or nil
    tech_weighting.audit_technology_weights(technology_prototypes)

    local tech_meta_by_name = {}
    local total_weight, age_weights = count_weighted_technologies(
        technology_prototypes,
        function(technology, prototype)
            return prototype and tech_weighting.should_count_technology(prototype)
        end,
        tech_meta_by_name
    )

    local active_force = force or get_primary_force()

    tech_scaling.techMetaByName = tech_meta_by_name
    tech_scaling.techCount = total_weight
    tech_scaling.ageTotals = ensure_age_total_table(age_weights)
    tech_scaling.selectedForceKey = get_force_key(active_force)
    tech_scaling.researchedSnapshot = ensure_researched_snapshot(
        build_researched_snapshot(active_force, tech_meta_by_name),
        tech_scaling.selectedForceKey
    )
    tech_scaling.cacheRevision = (tonumber(tech_scaling.cacheRevision) or 0) + 1

    if tech_scaling.techCount <= 0 then
        log("EI tech scaling rebuilt a zero weighted tech budget; holding research cost multiplier at the safe curve start.")
    end

    return tech_scaling
end

local function get_cached_researched_snapshot(force)
    local tech_scaling = ensure_tech_scaling_storage()
    local force_key = get_force_key(force)
    local snapshot = tech_scaling.researchedSnapshot

    if force_key
        and tech_scaling.selectedForceKey == force_key
        and static_cache_ready(tech_scaling)
        and type(tech_scaling.techMetaByName) == "table"
        and type(snapshot) == "table"
        and snapshot.forceKey == force_key
    then
        return ensure_researched_snapshot(snapshot, force_key)
    end

    return nil
end

local function nearly_equal(a, b)
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.000001
end

local function apply_difficulty_multiplier(tech_scaling, multiplier)
    multiplier = math.min(
        tech_scaling_common.INTERNAL_MULTIPLIER_CAP,
        tonumber(multiplier) or 1
    )

    local difficulty_settings = game and game.difficulty_settings or nil
    local current_multiplier = difficulty_settings and difficulty_settings.technology_price_multiplier or nil

    if difficulty_settings and not nearly_equal(current_multiplier, multiplier) then
        difficulty_settings.technology_price_multiplier = multiplier
    end

    tech_scaling.appliedMultiplier = multiplier
    return multiplier
end

local function apply_research_delta(force, research)
    local tech_scaling = ensure_tech_scaling_storage()
    local force_key = get_force_key(force)

    if not force_key or force_key ~= tech_scaling.selectedForceKey or type(research) ~= "table" then
        return "cache-miss"
    end

    local technology_name = research.name or (research.technology and research.technology.name)

    if not technology_name then
        return "cache-miss"
    end

    if type(tech_scaling.techMetaByName) ~= "table" then
        return "cache-miss"
    end

    local meta = tech_scaling.techMetaByName and tech_scaling.techMetaByName[technology_name]

    if not meta or not meta.countable then
        return "ignored"
    end

    local snapshot = ensure_researched_snapshot(tech_scaling.researchedSnapshot, force_key)
    if snapshot.researchedByName[technology_name] then
        tech_scaling.researchedSnapshot = snapshot
        return "already-applied", snapshot
    end

    local technology = force and force.technologies and force.technologies[technology_name] or nil
    if not (technology and technology.enabled and technology.researched) then
        return "cache-miss"
    end

    snapshot.totalWeight = snapshot.totalWeight + meta.weight
    snapshot.ageTotals[meta.age] = (snapshot.ageTotals[meta.age] or 0) + meta.weight
    snapshot.researchedByName[technology_name] = true

    tech_scaling.researchedSnapshot = snapshot
    tech_scaling.cacheRevision = (tonumber(tech_scaling.cacheRevision) or 0) + 1

    return "applied", snapshot
end

local function get_age_ramp_scaled_cost(max_cost, start_price, researched_age_weights, total_age_weights)
    max_cost, start_price = sanitize_prices(max_cost, start_price)

    local total_progress = 0

    for _, age in ipairs(CORE_AGES) do
        local segment = AGE_SEGMENTS[age]
        local total_weight = total_age_weights[age] or 0
        local researched_weight = researched_age_weights[age] or 0
        local local_progress = 0

        if total_weight > 0 then
            local_progress = math.max(0, math.min(researched_weight / total_weight, 1))
        end

        total_progress = total_progress + segment.share * apply_curve(local_progress, segment.curve)
    end

    return start_price + (max_cost - start_price) * math.max(0, math.min(total_progress, 1))
end

local function format_age_ramp_progress(researched_age_weights, total_age_weights)
    local parts = {}

    for _, age in ipairs(CORE_AGES) do
        local total_weight = total_age_weights[age] or 0
        local researched_weight = researched_age_weights[age] or 0
        local local_progress = 0

        if total_weight > 0 then
            local_progress = researched_weight / total_weight * 100
        end

        parts[#parts + 1] = age .. " " .. string.format("%.2f/%.2f", researched_weight, total_weight) .. " (" .. string.format("%.1f", local_progress) .. "%)"
    end

    return table.concat(parts, "; ")
end

local function update_multiplier(force, snapshot_override)
    local tech_scaling = ensure_tech_scaling_storage()

    if tech_scaling_disabled(tech_scaling) then
        apply_difficulty_multiplier(tech_scaling, 1)
        return
    end

    local maxCost = tech_scaling.maxCost
    local startPrice = tech_scaling.startPrice
    local baseStartPrice = tech_scaling.baseStartPrice
    local techCount = tech_scaling.techCount

    -- do this for player force -> no support for multiple forces yet
    force = force or get_primary_force()
    if not force then
        apply_difficulty_multiplier(tech_scaling, 1)
        return
    end

    local force_key = get_force_key(force)
    local snapshot = nil

    if type(snapshot_override) == "table"
        and (snapshot_override.forceKey == nil or snapshot_override.forceKey == force_key)
    then
        snapshot = ensure_researched_snapshot(snapshot_override, force_key)
    else
        snapshot = get_cached_researched_snapshot(force)
    end

    if not snapshot then
        if rebuild_researched_snapshot_from_cache(force) then
            tech_scaling = ensure_tech_scaling_storage()
        else
            tech_scaling = rebuild_runtime_cache(force)
        end

        snapshot = ensure_researched_snapshot(tech_scaling.researchedSnapshot, get_force_key(force))
        maxCost = tech_scaling.maxCost
        startPrice = tech_scaling.startPrice
        baseStartPrice = tech_scaling.baseStartPrice
        techCount = tech_scaling.techCount
    end

    local formulaType = get_cached_curve_form(tech_scaling)
    local scaled_cost

    if formulaType == "age-ramp" then
        scaled_cost = get_age_ramp_scaled_cost(
            maxCost,
            startPrice,
            snapshot.ageTotals,
            tech_scaling.ageTotals
        )
    else
        scaled_cost = tech_scaling_shared.get_scaled_cost(
            maxCost,
            techCount,
            startPrice,
            snapshot.totalWeight,
            formulaType
        )
    end

    local additional_multiplier = get_cached_additional_multiplier(tech_scaling)
    local total_multiplier = scaled_cost * additional_multiplier / math.max(1, baseStartPrice)

    apply_difficulty_multiplier(tech_scaling, total_multiplier)
end

local function refresh_from_settings(force)
    rebuild_runtime_cache(force)
end

function ei_tech_scaling.init()
    local force = get_primary_force()
    refresh_from_settings(force)
    update_multiplier(force)
end

function ei_tech_scaling.on_research_finished(event)
    local tech_scaling = ensure_tech_scaling_storage()
    if tech_scaling_disabled(tech_scaling) then
        return
    end

    local force = get_primary_force()
    if not force then
        return
    end

    local research = event and event.research or nil
    local research_force = research and research.force or nil

    if not research_force or get_force_key(force) ~= get_force_key(research_force) then
        return
    end

    local delta_result, snapshot = apply_research_delta(force, research)

    if delta_result == "applied" then
        update_multiplier(force, snapshot)
        return
    end

    if delta_result == "ignored" or delta_result == "already-applied" then
        return
    end

    if rebuild_researched_snapshot_from_cache(force) then
        update_multiplier(force)
        return
    end

    refresh_from_settings(force)
    update_multiplier(force)
end

function ei_tech_scaling.on_scripted_research_burst(force)
    if tech_scaling_disabled(ensure_tech_scaling_storage()) then
        return false
    end

    local primary_force = get_primary_force()
    if not primary_force or not force or get_force_key(primary_force) ~= get_force_key(force) then
        return false
    end

    if not rebuild_researched_snapshot_from_cache(primary_force) then
        refresh_from_settings(primary_force)
    end

    update_multiplier(primary_force)
    return true
end

commands.add_command(
    "refresh_tech_scaling",
    "Rebuilds tech scaling state from live settings and recalculates the active research cost multiplier.",
    function(command)
        local player = command.player_index and game.get_player(command.player_index) or nil
        if command.player_index and (not player or not player.admin) then
            return
        end

        ei_lib.crystal_echo("Tech scaling refresh initiated.")

        local force = get_primary_force()
        ei_tech_scaling.init()

        local tech_scaling = ensure_tech_scaling_storage()
        local snapshot = force and get_cached_researched_snapshot(force) or tech_scaling.researchedSnapshot
        local researched_weight = snapshot and snapshot.totalWeight or 0
        local researched_age_weights = snapshot and snapshot.ageTotals or new_age_total_table()
        local total_weight = tech_scaling.techCount or 0
        local formulaType = get_cached_curve_form(tech_scaling)

        if formulaType == "age-ramp" then
            ei_lib.crystal_echo(
                "Age-ramp progress: "
                    .. format_age_ramp_progress(
                        researched_age_weights,
                        tech_scaling.ageTotals or new_age_total_table()
                    )
            )
        end

        ei_lib.crystal_echo(
            "Tech scaling refresh complete. Multiplier now x"
                .. string.format("%.2f", game.difficulty_settings.technology_price_multiplier or 1)
                .. "; weighted progress "
                .. string.format("%.2f", researched_weight)
                .. "/"
                .. string.format("%.2f", total_weight)
                .. "; configured start "
                .. tostring(tech_scaling.startPrice or 0)
                .. ", hidden base "
                .. tostring(tech_scaling.baseStartPrice or 0)
                .. ", ceiling "
                .. tostring(tech_scaling.maxCost or 0)
                .. "."
        )
    end
)

--FORMULA DERIVATION
------------------------------------------------------------------------------------------------------
-- we plot cost (in y) over n number of technologies (in x) -> (y, n)
-- assume start point: A = (0, C)           ...C is the start price
-- assume end point:   B = (N, X)           ...C is the max cost

-- Linear: Form y = ax + b <-> cost(n) = a*n + b
-- b: use point A -> cost(0) = a*0 + b =!= C <-> b = C
-- a: use point B -> cost(N) = a*N + b =!= X <-> a = (X - b)/N

-- Quadratic: Form y = ax^2 + bx + c <-> cost(n) = a*n^2 + c | here we wont need b
-- c: use point A -> c = C
-- a: use point B -> cost(N) = a*N^2 + C =!= X <-> a = (X - C)/N^2

-- Exp: Form y = exp(b*x) + c <-> cost(n) = exp(b*n) + c
-- c: use point A -> cost(0) = 1 + c =!= C <-> c = C - 1
-- b: use point B -> cost(N) = exp(b*N) + C - 1 <-> b = ln(X + 1 - C)/N

-- we got:  cost_lin(n) = (X - C)/N * n + C
--          cost_qua(n) = (X - C)/N^2 * n^2 + C
--          cost_exp(n) = exp(n/N * ln(X + 1 - C)) + C - 1

-- since we need technology_price_multiplier use Ansatz: cost(n) =!= f(...) * C
-- we get:  f_lin(...) = (X - C)/(N*C) * n + 1
--          f_qua(...) = (X - C)/(N^2 * C) * n^2 + 1
--          f_exp(...) = (exp(n/N * ln(X + 1 - C)) - 1)/C + 1

-- we use the following variables for X, N, C, n
-- X .. maxCost
-- N .. techCount
-- C .. startPrice
-- n .. currentTechs

-- NOTE: Linear will increase strongly in early game, but will make late game "easier"
--       Exponential will increase slowly in early game, but will make late game much harder
--       Quadratic will begin to get more difficult earlier in the game then exp but wont be as steep as exp

-- OVERALL USAGE:
-- we can integrate the 3 curves to get their area, which corresponds to the total needed science packs
-- integrate from 0 to N ofc
-- S cost_lin(n) dn = N/2 * (X + C)
-- S cost_qua(n) dn = N/3 * (X + 2C)
-- S cost_exp(n) dn = N(C - 1 + (X + 1 - C)/ln(X + 1 - C))

-- for big X we can assume ln(X + 1 - C) ~ ln(X) f.e. ln(X=10k) ~ 9
--              -> Area(exp) = N(C - 1 + 1/9 * (X + 1 - C)) ~ N*X/9
--              -> Area(lin) ~ N*X/2
--              -> Area(qua) ~ N*X/3

-- therfore overall exponential is cheapest, then quadratic and linear is most difficult

function ei_tech_scaling.get_multiplier(X, N, C, n, formulaType)
    return tech_scaling_shared.get_multiplier(X, N, C, n, formulaType)
end


return ei_tech_scaling
