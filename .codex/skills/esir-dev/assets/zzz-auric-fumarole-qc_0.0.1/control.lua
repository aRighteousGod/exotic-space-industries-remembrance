local RESOURCE_NAME = "ei-auric-fumarole"
local SULFURIC_NAME = "sulfuric-acid-geyser"
local REPORT_PATH = "auric-fumarole-qc.txt"
local REPORT_OFFSETS = {
    [2] = true,
    [60] = true,
    [600] = true,
    [1800] = true,
    [36000] = true,
    [40000] = true,
    [126000] = true,
    [162000] = true,
    [198000] = true,
    [234000] = true,
    [414000] = true,
}

local CHUNK_SIZE = 32
local DISTANCE_ZERO_CHUNKS = 3
local DISTANCE_FULL_CHUNKS = 32
local DISTANCE_WEIGHT_POWER = 1.25
local GENERATE_RADIUS_CHUNKS = 64
local BACKFILL_PROCESS_TICKS = 30
local BACKFILL_CHUNKS_PER_PASS = 4
local AURIC_ACTIVE_FLOOR = 2
local AURIC_QUOTA_RECOVERY_PULSE_TICKS = 1800
local AURIC_QUOTA_RECOVERY_ATTEMPTS_PER_PULSE = 4
local AURIC_QUOTA_RECOVERY_LOW_ATTEMPTS_PER_PULSE = 6
local AURIC_QUOTA_RECOVERY_LOW_RATIO = 0.50
local AURIC_TRACKED_BANDS = {"3-6", "6-16", "16-24", "24-32", "32+"}
local AURIC_BAND_DENSITIES = {
    ["3-6"] = 0.0025,
    ["6-16"] = 0.0080,
    ["16-24"] = 0.0130,
    ["24-32"] = 0.0180,
    ["32+"] = 0.0100,
}

local function ensure_state()
    storage.auric_fumarole_qc = storage.auric_fumarole_qc or {}
    return storage.auric_fumarole_qc
end

local function clamp01(value)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function round(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

local function safe_ratio(numerator, denominator)
    if not denominator or denominator <= 0 then
        return 0
    end

    return round(numerator / denominator)
end

local function chunk_center(chunk_x, chunk_y)
    return {
        x = chunk_x * CHUNK_SIZE + (CHUNK_SIZE / 2),
        y = chunk_y * CHUNK_SIZE + (CHUNK_SIZE / 2),
    }
end

local function get_distance_weight(chunk_x, chunk_y)
    local center = chunk_center(chunk_x, chunk_y)
    local distance_chunks = math.sqrt(center.x * center.x + center.y * center.y) / CHUNK_SIZE
    if distance_chunks <= DISTANCE_ZERO_CHUNKS then
        return 0
    end
    local ramp = clamp01((distance_chunks - DISTANCE_ZERO_CHUNKS) / (DISTANCE_FULL_CHUNKS - DISTANCE_ZERO_CHUNKS))
    return ramp ^ DISTANCE_WEIGHT_POWER
end

local function get_band(distance_chunks)
    if distance_chunks <= 3 then
        return "0-3"
    end
    if distance_chunks <= 6 then
        return "3-6"
    end
    if distance_chunks <= 16 then
        return "6-16"
    end
    if distance_chunks <= 24 then
        return "16-24"
    end
    if distance_chunks <= 32 then
        return "24-32"
    end
    return "32+"
end

local function new_band_counts()
    return {
        ["0-3"] = 0,
        ["3-6"] = 0,
        ["6-16"] = 0,
        ["16-24"] = 0,
        ["24-32"] = 0,
        ["32+"] = 0,
    }
end

local function band_summary(counts)
    return table.concat({
        "0-3=" .. counts["0-3"],
        "3-6=" .. counts["3-6"],
        "6-16=" .. counts["6-16"],
        "16-24=" .. counts["16-24"],
        "24-32=" .. counts["24-32"],
        "32+=" .. counts["32+"],
    }, ", ")
end

local function new_axis_counts()
    return {
        E = 0,
        W = 0,
        N = 0,
        S = 0,
    }
end

local function new_quadrant_counts()
    return {
        NE = 0,
        NW = 0,
        SE = 0,
        SW = 0,
    }
end

local function copy_quadrant_counts(counts)
    return {
        NE = counts.NE or 0,
        NW = counts.NW or 0,
        SE = counts.SE or 0,
        SW = counts.SW or 0,
    }
end

local function quadrant_delta(current, baseline)
    baseline = baseline or new_quadrant_counts()
    return {
        NE = (current.NE or 0) - (baseline.NE or 0),
        NW = (current.NW or 0) - (baseline.NW or 0),
        SE = (current.SE or 0) - (baseline.SE or 0),
        SW = (current.SW or 0) - (baseline.SW or 0),
    }
end

local function update_population_sample_state(state, active_count)
    state.auric_min_active_since_reset = math.min(state.auric_min_active_since_reset or active_count, active_count)

    if active_count == 0 then
        state.auric_zero_sample_count = (state.auric_zero_sample_count or 0) + 1
        state.auric_current_zero_sample_streak = (state.auric_current_zero_sample_streak or 0) + 1
    else
        state.auric_current_zero_sample_streak = 0
    end
    state.auric_longest_zero_sample_streak = math.max(
        state.auric_longest_zero_sample_streak or 0,
        state.auric_current_zero_sample_streak or 0
    )

    if active_count < AURIC_ACTIVE_FLOOR then
        state.auric_below_floor_sample_count = (state.auric_below_floor_sample_count or 0) + 1
        state.auric_current_below_floor_sample_streak = (state.auric_current_below_floor_sample_streak or 0) + 1
    else
        state.auric_current_below_floor_sample_streak = 0
    end
    state.auric_longest_below_floor_sample_streak = math.max(
        state.auric_longest_below_floor_sample_streak or 0,
        state.auric_current_below_floor_sample_streak or 0
    )
end

local function tracked_band_summary(counts)
    local parts = {}
    for _, band_name in ipairs(AURIC_TRACKED_BANDS) do
        parts[#parts + 1] = band_name .. "=" .. (counts[band_name] or 0)
    end
    return table.concat(parts, ", ")
end

local function tracked_band_ratio_summary(numerators, denominators)
    local parts = {}
    for _, band_name in ipairs(AURIC_TRACKED_BANDS) do
        parts[#parts + 1] = band_name .. "=" .. safe_ratio(
            numerators[band_name] or 0,
            denominators[band_name] or 0
        )
    end
    return table.concat(parts, ", ")
end

local function get_band_targets(generated_eligible_counts)
    local targets = new_band_counts()
    local total_target = 0

    for _, band_name in ipairs(AURIC_TRACKED_BANDS) do
        local target = math.ceil((generated_eligible_counts[band_name] or 0) * (AURIC_BAND_DENSITIES[band_name] or 0))
        targets[band_name] = target
        total_target = total_target + target
    end

    return targets, total_target
end

local function get_band_fill_ratios(active_counts, target_counts)
    local ratios = new_band_counts()
    local weakest_band = nil
    local weakest_fill = math.huge
    local below_threshold = false

    for _, band_name in ipairs(AURIC_TRACKED_BANDS) do
        local target = target_counts[band_name] or 0
        local fill = target > 0 and ((active_counts[band_name] or 0) / target) or 0
        ratios[band_name] = round(fill)

        if target > 0 and fill < weakest_fill then
            weakest_fill = fill
            weakest_band = band_name
        end

        if target > 0 and fill < 0.70 then
            below_threshold = true
        end
    end

    return ratios, weakest_band or "none", weakest_fill == math.huge and 0 or round(weakest_fill), below_threshold
end

local function get_band_delta_counts(active_counts, target_counts, positive)
    local counts = new_band_counts()
    for _, band_name in ipairs(AURIC_TRACKED_BANDS) do
        local delta = (target_counts[band_name] or 0) - (active_counts[band_name] or 0)
        if positive then
            counts[band_name] = math.max(0, delta)
        else
            counts[band_name] = math.max(0, -delta)
        end
    end
    return counts
end

local function get_recovery_attempt_budget(total_active, total_target)
    if total_target > 0 and safe_ratio(total_active, total_target) < AURIC_QUOTA_RECOVERY_LOW_RATIO then
        return AURIC_QUOTA_RECOVERY_LOW_ATTEMPTS_PER_PULSE
    end

    return AURIC_QUOTA_RECOVERY_ATTEMPTS_PER_PULSE
end

local function update_quota_sample_state(state, active_counts, target_counts, total_active, total_target, relative_tick)
    local fill_ratios, weakest_band, weakest_fill, below_threshold = get_band_fill_ratios(active_counts, target_counts)
    local deficit_counts = get_band_delta_counts(active_counts, target_counts, true)
    local surplus_counts = get_band_delta_counts(active_counts, target_counts, false)
    local previous_active_count = state.previous_auric_total
    local previous_relative_tick = state.previous_report_relative_tick
    local previous_delta = previous_active_count and (total_active - previous_active_count) or 0
    local previous_pulses = 0

    if previous_relative_tick then
        previous_pulses = math.floor(math.max(0, relative_tick - previous_relative_tick) / AURIC_QUOTA_RECOVERY_PULSE_TICKS)
    end

    local previous_recovery_budget = 0
    local previous_target_total = state.previous_quota_total_target or total_target
    local previous_underfilled = state.previous_quota_below_threshold == true
    if previous_underfilled then
        local previous_budget_per_pulse = get_recovery_attempt_budget(previous_active_count or 0, previous_target_total)
        previous_recovery_budget = previous_pulses * previous_budget_per_pulse
        state.auric_recovery_attempt_window_count = (state.auric_recovery_attempt_window_count or 0) + 1
        state.auric_recovery_attempt_budget_total = (state.auric_recovery_attempt_budget_total or 0) + previous_recovery_budget

        if previous_delta > 0 then
            state.auric_recovery_success_window_count = (state.auric_recovery_success_window_count or 0) + 1
            state.auric_recovery_observed_spawn_delta_total =
                (state.auric_recovery_observed_spawn_delta_total or 0) + previous_delta
        else
            state.auric_recovery_failed_window_count = (state.auric_recovery_failed_window_count or 0) + 1
        end
    end

    if below_threshold then
        state.auric_below_quota_band_sample_count = (state.auric_below_quota_band_sample_count or 0) + 1
        state.auric_current_below_quota_band_sample_streak =
            (state.auric_current_below_quota_band_sample_streak or 0) + 1
    else
        state.auric_current_below_quota_band_sample_streak = 0
    end
    state.auric_longest_below_quota_band_sample_streak = math.max(
        state.auric_longest_below_quota_band_sample_streak or 0,
        state.auric_current_below_quota_band_sample_streak or 0
    )

    return {
        total_target = total_target,
        total_fill_ratio = safe_ratio(total_active, total_target),
        weakest_band = weakest_band,
        weakest_fill = weakest_fill,
        below_threshold = below_threshold,
        fill_ratios = fill_ratios,
        deficit_counts = deficit_counts,
        surplus_counts = surplus_counts,
        previous_delta = previous_delta,
        pulses_previous = previous_pulses,
        attempt_budget_previous = previous_recovery_budget,
        attempt_budget_per_pulse = get_recovery_attempt_budget(total_active, total_target),
    }
end

local function axis_summary(counts)
    return table.concat({
        "E=" .. counts.E,
        "W=" .. counts.W,
        "N=" .. counts.N,
        "S=" .. counts.S,
    }, ", ")
end

local function quadrant_summary(counts)
    return table.concat({
        "NE=" .. counts.NE,
        "NW=" .. counts.NW,
        "SE=" .. counts.SE,
        "SW=" .. counts.SW,
    }, ", ")
end

local function record_position_axes(position, counts)
    if position.x > 0 then
        counts.E = counts.E + 1
    elseif position.x < 0 then
        counts.W = counts.W + 1
    end

    if position.y < 0 then
        counts.N = counts.N + 1
    elseif position.y > 0 then
        counts.S = counts.S + 1
    end
end

local function record_position_quadrants(position, counts)
    if position.x > 0 and position.y < 0 then
        counts.NE = counts.NE + 1
    elseif position.x < 0 and position.y < 0 then
        counts.NW = counts.NW + 1
    elseif position.x > 0 and position.y > 0 then
        counts.SE = counts.SE + 1
    elseif position.x < 0 and position.y > 0 then
        counts.SW = counts.SW + 1
    end
end

local function is_inner_dead_zone(position)
    local distance_chunks = math.sqrt(position.x * position.x + position.y * position.y) / CHUNK_SIZE
    return distance_chunks <= DISTANCE_ZERO_CHUNKS
end

local function is_off_center(entity)
    local chunk_x = math.floor(entity.position.x / CHUNK_SIZE)
    local chunk_y = math.floor(entity.position.y / CHUNK_SIZE)
    local center = chunk_center(chunk_x, chunk_y)
    return math.abs(entity.position.x - center.x) > 0.01 or math.abs(entity.position.y - center.y) > 0.01
end

local function count_chunk_bands(radius_chunks)
    local totals = {
        all = new_band_counts(),
        eligible = new_band_counts(),
        eligible_axes = new_axis_counts(),
        eligible_quadrants = new_quadrant_counts(),
    }

    for chunk_x = -radius_chunks, radius_chunks do
        for chunk_y = -radius_chunks, radius_chunks do
            local center = chunk_center(chunk_x, chunk_y)
            local distance_chunks = math.sqrt(center.x * center.x + center.y * center.y) / CHUNK_SIZE
            local band = get_band(distance_chunks)
            totals.all[band] = totals.all[band] + 1

            if get_distance_weight(chunk_x, chunk_y) > 0 then
                totals.eligible[band] = totals.eligible[band] + 1
                record_position_axes(center, totals.eligible_axes)
                record_position_quadrants(center, totals.eligible_quadrants)
            end
        end
    end

    return totals
end

local function count_generated_chunk_bands(surface)
    local totals = {
        all = new_band_counts(),
        eligible = new_band_counts(),
        eligible_axes = new_axis_counts(),
        eligible_quadrants = new_quadrant_counts(),
        generated_count = 0,
        eligible_count = 0,
    }

    for chunk in surface.get_chunks() do
        if surface.is_chunk_generated({x = chunk.x, y = chunk.y}) then
            local center = chunk_center(chunk.x, chunk.y)
            local distance_chunks = math.sqrt(center.x * center.x + center.y * center.y) / CHUNK_SIZE
            local band = get_band(distance_chunks)
            totals.generated_count = totals.generated_count + 1
            totals.all[band] = totals.all[band] + 1

            if get_distance_weight(chunk.x, chunk.y) > 0 then
                totals.eligible_count = totals.eligible_count + 1
                totals.eligible[band] = totals.eligible[band] + 1
                record_position_axes(center, totals.eligible_axes)
                record_position_quadrants(center, totals.eligible_quadrants)
            end
        end
    end

    return totals
end

local function get_iterator_prefix_quadrants(surface, limit)
    local counts = new_quadrant_counts()
    local taken = 0

    for chunk in surface.get_chunks() do
        if surface.is_chunk_generated({x = chunk.x, y = chunk.y}) then
            local center = chunk_center(chunk.x, chunk.y)
            record_position_quadrants(center, counts)
            taken = taken + 1
            if taken >= limit then
                break
            end
        end
    end

    return counts
end

local function get_surface_names()
    local names = {}
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid then
            names[#names + 1] = surface.name
        end
    end
    table.sort(names)
    return names
end

local function prepare_vulcanus_surface()
    local existing = game.surfaces["vulcanus"]
    if existing and existing.valid then
        existing.request_to_generate_chunks({0, 0}, GENERATE_RADIUS_CHUNKS)
        existing.force_generate_chunk_requests()
        return existing
    end

    local planet = game.planets and game.planets["vulcanus"] or nil
    if planet and planet.surface and planet.surface.valid then
        planet.surface.request_to_generate_chunks({0, 0}, GENERATE_RADIUS_CHUNKS)
        planet.surface.force_generate_chunk_requests()
        return planet.surface
    end

    if planet and planet.create_surface then
        local created = planet.create_surface()
        if created and created.valid then
            created.request_to_generate_chunks({0, 0}, GENERATE_RADIUS_CHUNKS)
            created.force_generate_chunk_requests()
            return created
        end
    end

    return nil
end

local function build_report()
    local surface = game.surfaces["vulcanus"]
    if not (surface and surface.valid) then
        return {
            "tick=" .. game.tick,
            "vulcanus=missing",
            "surfaces=" .. table.concat(get_surface_names(), ", "),
        }
    end

    local chunks = count_chunk_bands(GENERATE_RADIUS_CHUNKS)
    local generated_chunks = count_generated_chunk_bands(surface)
    local aurics = surface.find_entities_filtered({name = RESOURCE_NAME})
    local sulfurics = surface.find_entities_filtered({name = SULFURIC_NAME})
    local non_vulcanus_aurics = 0
    local auric_bands = new_band_counts()
    local auric_axes = new_axis_counts()
    local sulfuric_axes = new_axis_counts()
    local auric_quadrants = new_quadrant_counts()
    local sulfuric_quadrants = new_quadrant_counts()
    local off_center = {}
    local off_center_total = 0
    local inner_dead_zone_count = 0
    local state = ensure_state()

    for _, other_surface in pairs(game.surfaces) do
        if other_surface and other_surface.valid and other_surface.name ~= "vulcanus" then
            non_vulcanus_aurics = non_vulcanus_aurics + #other_surface.find_entities_filtered({name = RESOURCE_NAME})
        end
    end

    for _, entity in pairs(aurics) do
        if entity.valid then
            local distance_chunks = math.sqrt(entity.position.x * entity.position.x + entity.position.y * entity.position.y) / CHUNK_SIZE
            local band = get_band(distance_chunks)
            auric_bands[band] = auric_bands[band] + 1
            record_position_axes(entity.position, auric_axes)
            record_position_quadrants(entity.position, auric_quadrants)

            if is_off_center(entity) then
                off_center_total = off_center_total + 1
                if #off_center < 12 then
                    off_center[#off_center + 1] = string.format(
                        "(%.1f, %.1f)",
                        round(entity.position.x),
                        round(entity.position.y)
                    )
                end
            end

            if is_inner_dead_zone(entity.position) then
                inner_dead_zone_count = inner_dead_zone_count + 1
            end
        end
    end

    for _, entity in pairs(sulfurics) do
        if entity.valid then
            record_position_axes(entity.position, sulfuric_axes)
            record_position_quadrants(entity.position, sulfuric_quadrants)
        end
    end

    if not state.start_auric_quadrants then
        state.start_auric_quadrants = copy_quadrant_counts(auric_quadrants)
        state.start_auric_total = #aurics
    end

    local previous_quadrants = state.previous_auric_quadrants or copy_quadrant_counts(auric_quadrants)
    local previous_total = state.previous_auric_total or #aurics
    local delta_from_start = quadrant_delta(auric_quadrants, state.start_auric_quadrants)
    local delta_from_previous = quadrant_delta(auric_quadrants, previous_quadrants)
    local relative_tick = game.tick - (state.start_tick or 0)
    update_population_sample_state(state, #aurics)
    local band_targets, total_target = get_band_targets(generated_chunks.eligible)
    local quota = update_quota_sample_state(state, auric_bands, band_targets, #aurics, total_target, relative_tick)

    local lines = {
        "tick=" .. game.tick,
        "vulcanus_chunks_all=" .. band_summary(chunks.all),
        "vulcanus_chunks_eligible=" .. band_summary(chunks.eligible),
        "vulcanus_chunks_eligible_axes=" .. axis_summary(chunks.eligible_axes),
        "vulcanus_chunks_eligible_quadrants=" .. quadrant_summary(chunks.eligible_quadrants),
        "vulcanus_generated_chunks=" .. generated_chunks.generated_count,
        "vulcanus_generated_chunks_all=" .. band_summary(generated_chunks.all),
        "vulcanus_generated_eligible_chunks=" .. generated_chunks.eligible_count,
        "vulcanus_generated_chunks_eligible=" .. band_summary(generated_chunks.eligible),
        "auric_entities=" .. #aurics,
        "non_vulcanus_auric_entities=" .. non_vulcanus_aurics,
        "auric_bands=" .. band_summary(auric_bands),
        "auric_quadrants=" .. quadrant_summary(auric_quadrants),
        "auric_east_west=E=" .. auric_axes.E .. ", W=" .. auric_axes.W,
        "auric_north_south=N=" .. auric_axes.N .. ", S=" .. auric_axes.S,
        "sulfuric_quadrants=" .. quadrant_summary(sulfuric_quadrants),
        "sulfuric_east_west=E=" .. sulfuric_axes.E .. ", W=" .. sulfuric_axes.W,
        "sulfuric_north_south=N=" .. sulfuric_axes.N .. ", S=" .. sulfuric_axes.S,
        "auric_quadrant_delta_start=" .. quadrant_summary(delta_from_start),
        "auric_quadrant_delta_previous=" .. quadrant_summary(delta_from_previous),
        "auric_total_delta_start=" .. (#aurics - (state.start_auric_total or 0)),
        "auric_total_delta_previous=" .. (#aurics - previous_total),
        "auric_active_floor=" .. AURIC_ACTIVE_FLOOR,
        "auric_min_active_since_reset=" .. state.auric_min_active_since_reset,
        "auric_zero_sample_count=" .. (state.auric_zero_sample_count or 0),
        "auric_below_floor_sample_count=" .. (state.auric_below_floor_sample_count or 0),
        "auric_longest_zero_sample_streak=" .. (state.auric_longest_zero_sample_streak or 0),
        "auric_longest_below_floor_sample_streak=" .. (state.auric_longest_below_floor_sample_streak or 0),
        "auric_quota_band_densities=" .. tracked_band_summary(AURIC_BAND_DENSITIES),
        "auric_quota_band_targets=" .. tracked_band_summary(band_targets),
        "auric_quota_band_fill_ratios=" .. tracked_band_summary(quota.fill_ratios),
        "auric_quota_band_deficit=" .. tracked_band_summary(quota.deficit_counts),
        "auric_quota_band_surplus=" .. tracked_band_summary(quota.surplus_counts),
        "auric_quota_total_target=" .. quota.total_target,
        "auric_quota_total_fill_ratio=" .. quota.total_fill_ratio,
        "auric_quota_weakest_band=" .. quota.weakest_band,
        "auric_quota_weakest_fill_ratio=" .. quota.weakest_fill,
        "auric_below_quota_band_sample_count=" .. (state.auric_below_quota_band_sample_count or 0),
        "auric_longest_below_quota_band_sample_streak=" .. (state.auric_longest_below_quota_band_sample_streak or 0),
        "auric_recovery_attempt_pulse_ticks=" .. AURIC_QUOTA_RECOVERY_PULSE_TICKS,
        "auric_recovery_attempts_per_pulse=" .. AURIC_QUOTA_RECOVERY_ATTEMPTS_PER_PULSE,
        "auric_recovery_attempts_per_pulse_low_total=" .. AURIC_QUOTA_RECOVERY_LOW_ATTEMPTS_PER_PULSE,
        "auric_recovery_low_total_ratio=" .. AURIC_QUOTA_RECOVERY_LOW_RATIO,
        "auric_recovery_pulses_previous=" .. quota.pulses_previous,
        "auric_recovery_attempt_budget_previous=" .. quota.attempt_budget_previous,
        "auric_recovery_attempt_budget_per_pulse=" .. quota.attempt_budget_per_pulse,
        "auric_recovery_attempt_budget_total=" .. (state.auric_recovery_attempt_budget_total or 0),
        "auric_recovery_attempt_window_count=" .. (state.auric_recovery_attempt_window_count or 0),
        "auric_recovery_success_window_count=" .. (state.auric_recovery_success_window_count or 0),
        "auric_recovery_failed_window_count=" .. (state.auric_recovery_failed_window_count or 0),
        "auric_recovery_delta_previous=" .. quota.previous_delta,
        "auric_recovery_observed_spawn_delta_total=" .. (state.auric_recovery_observed_spawn_delta_total or 0),
        "backfill_estimated_serviced_since_reset=" .. (math.floor(relative_tick / BACKFILL_PROCESS_TICKS) * BACKFILL_CHUNKS_PER_PASS),
        "surface_iterator_prefix_240_quadrants=" .. quadrant_summary(get_iterator_prefix_quadrants(surface, 240)),
        "surface_iterator_prefix_2400_quadrants=" .. quadrant_summary(get_iterator_prefix_quadrants(surface, 2400)),
        "auric_off_center_total=" .. off_center_total,
        "auric_inner_dead_zone=" .. inner_dead_zone_count,
        "sulfuric_geysers=" .. #sulfurics,
        "surfaces=" .. table.concat(get_surface_names(), ", "),
    }

    if #off_center > 0 then
        lines[#lines + 1] = "auric_off_center_samples=" .. table.concat(off_center, ", ")
    end

    state.previous_auric_quadrants = copy_quadrant_counts(auric_quadrants)
    state.previous_auric_total = #aurics
    state.previous_report_relative_tick = relative_tick
    state.previous_quota_total_target = quota.total_target
    state.previous_quota_below_threshold = quota.below_threshold

    return lines
end

local function write_file(path, contents, append)
    if helpers and helpers.write_file then
        helpers.write_file(path, contents, append and true or false)
        return
    end

    if game and game.write_file then
        game.write_file(path, contents, append and true or false, 0)
    end
end

local function write_report()
    local lines = build_report()
    write_file(REPORT_PATH, table.concat(lines, "\n") .. "\n---\n", true)
end

local function reset_report_window()
    local state = ensure_state()
    state.start_tick = game.tick
    state.start_auric_quadrants = nil
    state.start_auric_total = nil
    state.previous_auric_quadrants = nil
    state.previous_auric_total = nil
    state.previous_report_relative_tick = nil
    state.previous_quota_total_target = nil
    state.previous_quota_below_threshold = nil
    state.auric_min_active_since_reset = nil
    state.auric_zero_sample_count = nil
    state.auric_below_floor_sample_count = nil
    state.auric_current_zero_sample_streak = nil
    state.auric_current_below_floor_sample_streak = nil
    state.auric_longest_zero_sample_streak = nil
    state.auric_longest_below_floor_sample_streak = nil
    state.auric_below_quota_band_sample_count = nil
    state.auric_current_below_quota_band_sample_streak = nil
    state.auric_longest_below_quota_band_sample_streak = nil
    state.auric_recovery_attempt_budget_total = nil
    state.auric_recovery_attempt_window_count = nil
    state.auric_recovery_success_window_count = nil
    state.auric_recovery_failed_window_count = nil
    state.auric_recovery_observed_spawn_delta_total = nil
    write_file(REPORT_PATH, "", false)
end

script.on_init(function()
    prepare_vulcanus_surface()
    reset_report_window()
end)

script.on_configuration_changed(function()
    prepare_vulcanus_surface()
    reset_report_window()
end)

script.on_event(defines.events.on_tick, function(event)
    local state = ensure_state()
    if not state.start_tick then
        prepare_vulcanus_surface()
        reset_report_window()
        state = ensure_state()
    end

    local start_tick = state.start_tick or event.tick
    local relative_tick = event.tick - start_tick
    if REPORT_OFFSETS[relative_tick] then
        write_report()
    end
end)
