local tech_scaling_shared = {}

local MAX_TECH_PRICE_MULTIPLIER = 1000
local MIN_TECH_PRICE_MULTIPLIER = 0.001

local function sanitize_prices(max_cost, start_price)
    start_price = math.max(1, tonumber(start_price) or 1)
    max_cost = math.max(start_price, tonumber(max_cost) or start_price)

    return max_cost, start_price
end

function tech_scaling_shared.get_normalized_base_price(max_cost, start_price)
    max_cost, start_price = sanitize_prices(max_cost, start_price)

    -- Factorio caps the live technology price multiplier at x1000. Raise the shared
    -- prototype count floor when needed so high named ceilings remain reachable while
    -- still letting the runtime curve start below x1.
    return math.max(start_price, math.ceil(max_cost / MAX_TECH_PRICE_MULTIPLIER))
end

local function clamp_progress(current_techs, tech_count)
    tech_count = math.max(0, tonumber(tech_count) or 0)
    current_techs = tonumber(current_techs) or 0

    if tech_count <= 0 then
        return 0, 0
    end

    return math.max(0, math.min(current_techs, tech_count)), tech_count
end

function tech_scaling_shared.get_scaled_cost(max_cost, tech_count, start_price, current_techs, formula_type)
    max_cost, start_price = sanitize_prices(max_cost, start_price)
    current_techs, tech_count = clamp_progress(current_techs, tech_count)
    formula_type = formula_type or "quadratic"

    if tech_count <= 0 then
        return start_price
    end

    if formula_type == "linear" then
        return ((max_cost - start_price) / tech_count) * current_techs + start_price
    end

    if formula_type == "quadratic" then
        return ((max_cost - start_price) / (tech_count ^ 2)) * (current_techs ^ 2) + start_price
    end

    if formula_type == "exponential" then
        if max_cost == start_price then
            return start_price
        end

        return math.exp(current_techs / tech_count * math.log(max_cost + 1 - start_price)) + start_price - 1
    end

    return start_price
end

function tech_scaling_shared.get_multiplier(max_cost, tech_count, start_price, current_techs, formula_type, base_price)
    base_price = math.max(
        1,
        tonumber(base_price) or tech_scaling_shared.get_normalized_base_price(max_cost, start_price)
    )

    local scaled_cost = tech_scaling_shared.get_scaled_cost(
        max_cost,
        tech_count,
        start_price,
        current_techs,
        formula_type
    )

    return math.max(
        MIN_TECH_PRICE_MULTIPLIER,
        math.min(MAX_TECH_PRICE_MULTIPLIER, scaled_cost / base_price)
    )
end

return tech_scaling_shared
