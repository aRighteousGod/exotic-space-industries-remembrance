local tech_scaling_common = {}

tech_scaling_common.INTERNAL_MULTIPLIER_CAP = 1000

function tech_scaling_common.get_effective_base_start_price(start_price, max_cost, additional_multiplier)
    local configured_start_price = math.max(1, start_price or 1)
    local configured_max_cost = math.max(configured_start_price, max_cost or configured_start_price)
    local final_multiplier = math.max(1, additional_multiplier or 1)

    -- Factorio hard-caps technology_price_multiplier at x1000. Raise the hidden prototype
    -- base count just enough that the configured late-game ceiling can still be represented
    -- after the extra multiplier is applied.
    local required_base_start_price = math.ceil(
        configured_max_cost * final_multiplier / tech_scaling_common.INTERNAL_MULTIPLIER_CAP
    )

    return math.max(configured_start_price, required_base_start_price)
end

function tech_scaling_common.get_runtime_start_price_scale(configured_start_price, effective_base_start_price)
    local configured = math.max(1, configured_start_price or 1)
    local effective = math.max(1, effective_base_start_price or configured)

    return configured / effective
end

return tech_scaling_common
