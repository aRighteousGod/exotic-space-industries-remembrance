--originally from Tougher Lightning Storms by thesixthroc
--now modified to add smooth variation in Fulgora's day length each cycle, with checks to avoid abrupt changes during dark or unstable-light conditions

local CHECK_INTERVAL = 300
local PENDING_CHECK_INTERVAL = 60
local CHECK_JITTER_STEPS = 7
local MAX_DARKNESS_FOR_DAYTIME_CHANGE = 0.35
local MAX_DARKNESS_DELTA_FOR_STABLE_LIGHT = 0.02

local standard_fulgora_day_length = prototypes.space_location.fulgora.surface_properties["day-night-cycle"]
-- Guarantees progress if brightness guards keep rejecting checks.
local FORCE_APPLY_AFTER_TICKS = standard_fulgora_day_length

local model = {}

local function schedule_next_check(state, tick)
	-- Jitter the cadence slightly to avoid phase-locking with ticks_per_day.
	state.check_phase = ((state.check_phase or 0) + 1) % CHECK_JITTER_STEPS
	local jitter = state.check_phase
	state.next_check_tick = tick + CHECK_INTERVAL + jitter
end

function model.updater(event)
	if not event or not event.tick then
		return
	end

	local surface = game.surfaces["fulgora"]
	if not surface then
		return
	end

	local ei_storage = storage and storage.ei
	if not ei_storage then
		return
	end

	if not ei_storage.fulgora_day_length_variation then
		ei_storage.fulgora_day_length_variation = {}
        ei_storage.fulgora_day_length_variation.max_multiplier = ei_lib.config("fulgora-day-length-variation-max-multiplier") or 2
        ei_storage.fulgora_day_length_variation.min_multiplier = ei_lib.config("fulgora-day-length-variation-min-multiplier") or 0.1
	end

	local variation_state = ei_storage.fulgora_day_length_variation
	if not variation_state.cycle_index then
		variation_state.cycle_index = 0
	end

	local current_daytime = surface.daytime or 0
	local last_daytime = variation_state.last_daytime

	-- Detect day wrap to identify a new cycle.
	if last_daytime and current_daytime < last_daytime then
		variation_state.cycle_index = variation_state.cycle_index + 1
		-- New cycle: clear pending state and allow an immediate check.
		variation_state.pending_since_tick = nil
		variation_state.next_check_tick = event.tick
	end

	variation_state.last_daytime = current_daytime

	-- Apply at most once per day-night cycle.
	if variation_state.last_applied_cycle == variation_state.cycle_index then
		return
	end

	if not variation_state.next_check_tick then
		-- Start checks immediately after state initialization.
		variation_state.next_check_tick = event.tick
	end

	local pending = variation_state.pending_since_tick ~= nil
	if pending then
		-- While pending, retry at a cheaper/faster cadence until conditions are safe.
		if event.tick % PENDING_CHECK_INTERVAL ~= 0 then
			return
		end
	elseif event.tick < variation_state.next_check_tick then
		return
	end

	local darkness = surface.darkness or 1
	local last_darkness = variation_state.last_darkness
	variation_state.last_darkness = darkness

	-- Apply only in bright, stable-light windows to avoid abrupt visual shifts.
	local is_daylight_enough = darkness <= MAX_DARKNESS_FOR_DAYTIME_CHANGE
	local is_brightness_stable = not last_darkness
		or math.abs(darkness - last_darkness) <= MAX_DARKNESS_DELTA_FOR_STABLE_LIGHT
	-- Failsafe: eventually apply even if we never hit an ideal window.
	local fallback_due = pending
		and event.tick - variation_state.pending_since_tick >= FORCE_APPLY_AFTER_TICKS

	if not ((is_daylight_enough and is_brightness_stable) or fallback_due) then
		if not pending then
			-- Enter pending mode on first rejected main check.
			variation_state.pending_since_tick = event.tick
		end
		return
	end

	-- Reset pending mode after a successful apply.
	variation_state.pending_since_tick = nil

	local rng = math.random()
	local min_multiplier = ei_storage.fulgora_day_length_variation.min_multiplier
	local max_multiplier = ei_storage.fulgora_day_length_variation.max_multiplier
	local day_length_multiplier = min_multiplier + (max_multiplier - min_multiplier) * rng
	local new_ticks = math.floor(standard_fulgora_day_length * day_length_multiplier + 0.5)

	surface.ticks_per_day = new_ticks
	variation_state.last_applied_cycle = variation_state.cycle_index
    --game.print("fulgora day length changed to " .. math.floor(new_ticks / 60) .. " minutes (" .. string.format("%.0f", day_length_multiplier * 100) .. "% of standard)")
	schedule_next_check(variation_state, event.tick)
end

return model
