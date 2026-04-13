--==============================================================================
-- ESIR FILE MAP
-- owns: tech cost scaling
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, configuration-changed, and research-finished
-- forwarded_events: get_multiplier, init, on_research_finished
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

--====================================================================================================
--TECH SCALING
--====================================================================================================

local function get_primary_force()
    return game.forces.player or game.forces[1]
end

local function count_researched_weight(force)
    local current_techs = 0

    for _, technology in pairs(force.technologies) do
        -- Runtime force techs carry the live researched/enabled state, while the weighting
        -- helper decides whether that prototype should count at all and by how much.
        if technology.enabled and technology.researched and tech_weighting.should_count_technology(technology.prototype) then
            current_techs = current_techs + tech_weighting.get_technology_weight(technology.name, technology.prototype)
        end
    end

    return current_techs
end

local function count_total_weight()
    local total_techs = 0

    for technology_name, technology in pairs(prototypes.technology) do
        -- The total curve budget is derived from the loaded prototype set, using the same
        -- exclusion and discount rules as the researched-count pass above.
        if tech_weighting.should_count_technology(technology) then
            total_techs = total_techs + tech_weighting.get_technology_weight(technology_name, technology)
        end
    end

    return total_techs
end

local function update_multiplier()
    if ei_lib.config("no-tech-scaling") then
        game.difficulty_settings.technology_price_multiplier = 1
        return
    end

    local maxCost = storage.ei["tech_scaling"].maxCost
    local startPrice = storage.ei["tech_scaling"].startPrice
    local baseStartPrice = storage.ei["tech_scaling"].baseStartPrice
    local techCount = storage.ei["tech_scaling"].techCount

    -- do this for player force -> no support for multiple forces yet
    local force = get_primary_force()
    if not force then
        game.difficulty_settings.technology_price_multiplier = 1
        return
    end

    local currentTechs = count_researched_weight(force)

    local formulaType = ei_lib.config("tech-scaling-curveForm")
    local scaled_cost = tech_scaling_shared.get_scaled_cost(
        maxCost,
        techCount,
        startPrice,
        currentTechs,
        formulaType
    )

    local additional_multiplier = ei_lib.config("tech-scaling-additionalMultiplier")
    local total_multiplier = scaled_cost * additional_multiplier / math.max(1, baseStartPrice)

    -- apply the multiplier
    game.difficulty_settings.technology_price_multiplier = math.min(
        tech_scaling_common.INTERNAL_MULTIPLIER_CAP,
        total_multiplier
    )
end

local function refresh_from_settings()
    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei["tech_scaling"] then
        storage.ei["tech_scaling"] = {}
    end

    local maxCost = ei_lib.switch_string(
        ei_data["tech_scaling"].switch_table,
        ei_lib.config("tech-scaling-maxCost")
    ) or storage.ei["tech_scaling"].maxCost or ei_data["tech_scaling"].switch_table["Default"]

    local startPrice = ei_lib.config("tech-scaling-startPrice") or storage.ei["tech_scaling"].startPrice or 10
    local additional_multiplier = ei_lib.config("tech-scaling-additionalMultiplier") or 1

    storage.ei["tech_scaling"].maxCost = maxCost
    storage.ei["tech_scaling"].startPrice = startPrice
    storage.ei["tech_scaling"].baseStartPrice = tech_scaling_common.get_effective_base_start_price(
        startPrice,
        maxCost,
        additional_multiplier
    )

    -- Rebuild the curve inputs from live settings and the current prototype set instead of
    -- trusting whatever was serialized into the save before this load.
    tech_weighting.audit_technology_weights(prototypes.technology)
    storage.ei["tech_scaling"].techCount = count_total_weight()

    if storage.ei["tech_scaling"].techCount <= 0 then
        log("EI tech scaling rebuilt a zero weighted tech budget; holding research cost multiplier at the safe curve start.")
    end
end

function ei_tech_scaling.init()
    refresh_from_settings()
    update_multiplier()
end

function ei_tech_scaling.on_research_finished()
    if ei_lib.config("no-tech-scaling") then return end
    update_multiplier()
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

        ei_tech_scaling.init()

        local force = get_primary_force()
        local researched_weight = force and count_researched_weight(force) or 0
        local total_weight = storage.ei["tech_scaling"].techCount or 0

        ei_lib.crystal_echo(
            "Tech scaling refresh complete. Multiplier now x"
            .. string.format("%.2f", game.difficulty_settings.technology_price_multiplier or 1)
            .. "; weighted progress "
            .. string.format("%.2f", researched_weight)
            .. "/"
            .. string.format("%.2f", total_weight)
            .. "; configured start "
            .. tostring(storage.ei["tech_scaling"].startPrice or 0)
            .. ", hidden base "
            .. tostring(storage.ei["tech_scaling"].baseStartPrice or 0)
            .. ", ceiling "
            .. tostring(storage.ei["tech_scaling"].maxCost or 0)
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
