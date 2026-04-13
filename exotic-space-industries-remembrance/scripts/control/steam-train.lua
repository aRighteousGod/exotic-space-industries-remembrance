--==============================================================================
-- ESIR FILE MAP
-- owns: steam locomotive wheel and helper runtime
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init/config rebuild, build/destroy, train state changes, and every-tick runtime updates
-- forwarded_events: addToGlobal, check_global, on_built_entity, on_destroyed_entity, on_train_changed_state, rebuild_runtime_state, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================
local steam_train = {}

local WheelControl = require("lib/handle-wheels.lua")

local STEAM_LOCOMOTIVE_NAME = "ei-steam-basic-locomotive"
local PLACEMENT_ENTITY_NAME = "ei-steam-basic-locomotive-placement-entity"
local BASE_WHEELS_NAME = "ei-steam-wheels"
local ELEVATED_WHEELS_NAME = "ei-steam-wheels-elevated"
-- Keep the visual wheel cadence fairly tight even when the wider mod update cycle is stretched out.
local WHEEL_UPDATE_TICK = math.floor(math.max(1, math.min(5, ei_ticksPerFullUpdate / 30)))
-- Idle trains stay hot for a couple of wheel passes so brief stops do not thrash the active queue.
local IDLE_GRACE_UPDATES = 2

local function new_runtime_state()
	-- The runtime keeps all known steam locomotives in one indexed set, then tracks a smaller
	-- "active" subset for the frequent wheel sync pass.
	return {
		locomotives_by_unit = {},
		tracked_units = {},
		tracked_index_by_unit = {},
		active_units = {},
		active_index_by_unit = {},
		audit_cursor = 1
	}
end

local function destroy_wheels(wheels)
	if not wheels then
		return
	end

	if wheels.base and wheels.base.valid then
		wheels.base.destroy()
	end
	if wheels.elevated and wheels.elevated.valid then
		wheels.elevated.destroy()
	end
end

local function are_wheels_valid(wheels)
	return wheels
		and wheels.base
		and wheels.base.valid
		and wheels.elevated
		and wheels.elevated.valid
end

local function add_to_queue(queue, index_by_unit, unit_number)
	if not unit_number or index_by_unit[unit_number] then
		return
	end

	queue[#queue + 1] = unit_number
	index_by_unit[unit_number] = #queue
end

local function remove_from_queue(queue, index_by_unit, unit_number)
	-- Swap-remove keeps queue mutation O(1) and avoids the table-shifting cost of table.remove().
	local index = index_by_unit[unit_number]
	if not index then
		return
	end

	local last_index = #queue
	local last_unit = queue[last_index]
	queue[index] = last_unit
	queue[last_index] = nil
	index_by_unit[unit_number] = nil

	if last_unit and last_unit ~= unit_number then
		index_by_unit[last_unit] = index
	end
end

local function clamp_audit_cursor(runtime)
	-- The slow audit walks the tracked queue in slices, so its cursor has to stay valid as
	-- records are removed mid-pass.
	local tracked_count = #runtime.tracked_units
	if tracked_count == 0 then
		runtime.audit_cursor = 1
	elseif runtime.audit_cursor > tracked_count then
		runtime.audit_cursor = 1
	elseif runtime.audit_cursor < 1 then
		runtime.audit_cursor = 1
	end
end

local function ensure_wheels(record)
	-- Missing helper entities are repaired lazily here so saves recover automatically after
	-- script drift, prototype churn, or manual cleanup.
	if are_wheels_valid(record.wheels) then
		return false
	end

	destroy_wheels(record.wheels)
	record.wheels = WheelControl:apply_wheels(record.locomotive)
	record.last_speed = nil
	record.last_orientation = nil
	record.last_height_mode = nil
	record.last_surface_index = nil
	record.idle_ticks = 0
	return true
end

local function remove_record(runtime, unit_number)
	-- Teardown is centralized so destroy events, audits, and invalid runtime entries all
	-- clean up wheels and queue membership the same way.
	local record = runtime.locomotives_by_unit[unit_number]
	if record then
		destroy_wheels(record.wheels)
		runtime.locomotives_by_unit[unit_number] = nil
	end

	remove_from_queue(runtime.active_units, runtime.active_index_by_unit, unit_number)
	remove_from_queue(runtime.tracked_units, runtime.tracked_index_by_unit, unit_number)
	clamp_audit_cursor(runtime)
end

local function activate_record(runtime, record)
	-- "Active" means this locomotive deserves the short-cadence wheel pass.
	record.idle_ticks = 0
	add_to_queue(runtime.active_units, runtime.active_index_by_unit, record.unit_number)
end

local function sync_record(runtime, record, force_sync)
	-- The hot path is deliberately narrow: only locomotives whose visual state changed, moved,
	-- or just had their wheels recreated do the full wheel sync work.
	local locomotive = record.locomotive
	if not locomotive or not locomotive.valid then
		remove_record(runtime, record.unit_number)
		return false
	end

	local recreated_wheels = ensure_wheels(record)
	local speed = locomotive.speed
	local orientation = locomotive.orientation
	local surface_index = locomotive.surface.index
	local height_mode = WheelControl:get_height_mode(locomotive)
	local state_changed = force_sync
		or recreated_wheels
		or record.last_speed == nil
		or speed ~= record.last_speed
		or orientation ~= record.last_orientation
		or height_mode ~= record.last_height_mode
		or surface_index ~= record.last_surface_index

	if speed ~= 0 or state_changed then
		WheelControl:update_wheel_position(locomotive, record.wheels, height_mode, record.last_height_mode)
		activate_record(runtime, record)
	else
		record.idle_ticks = (record.idle_ticks or 0) + 1
		if record.idle_ticks >= IDLE_GRACE_UPDATES then
			remove_from_queue(runtime.active_units, runtime.active_index_by_unit, record.unit_number)
		end
	end

	record.last_speed = speed
	record.last_orientation = orientation
	record.last_height_mode = height_mode
	record.last_surface_index = surface_index
	return true
end

local function register_locomotive(runtime, locomotive, force_sync)
	-- Registration is idempotent so rebuilds, build events, and train wakeups can all funnel
	-- through one path without duplicate runtime entries.
	if not locomotive or not locomotive.valid or locomotive.name ~= STEAM_LOCOMOTIVE_NAME then
		return nil
	end

	local unit_number = locomotive.unit_number
	if not unit_number then
		return nil
	end

	local record = runtime.locomotives_by_unit[unit_number]
	if record then
		record.locomotive = locomotive
	else
		record = {
			unit_number = unit_number,
			locomotive = locomotive,
			wheels = nil,
			last_speed = nil,
			last_orientation = nil,
			last_height_mode = nil,
			last_surface_index = nil,
			idle_ticks = 0
		}
		runtime.locomotives_by_unit[unit_number] = record
		add_to_queue(runtime.tracked_units, runtime.tracked_index_by_unit, unit_number)
	end

	activate_record(runtime, record)
	sync_record(runtime, record, force_sync)
	return record
end

local function mark_train_locomotives_active(runtime, train)
	-- Train state changes are the cheap wakeup signal for parked locomotives that are about to
	-- matter again.
	if not train or not train.valid or not train.locomotives then
		return
	end

	for _, group in pairs(train.locomotives) do
		for _, locomotive in pairs(group) do
			if locomotive and locomotive.valid and locomotive.name == STEAM_LOCOMOTIVE_NAME then
				local record = runtime.locomotives_by_unit[locomotive.unit_number]
				if record then
					record.locomotive = locomotive
					activate_record(runtime, record)
				else
					register_locomotive(runtime, locomotive, true)
				end
			end
		end
	end
end

local function run_audit(runtime)
	-- The audit spreads repair work across the configured full-update window so every tracked
	-- locomotive is revisited eventually without reintroducing an every-pass world scan.
	local tracked_count = #runtime.tracked_units
	if tracked_count == 0 then
		runtime.audit_cursor = 1
		return
	end

	local batch_size = math.max(1, math.ceil(tracked_count / math.max(1, ei_ticksPerFullUpdate)))
	local processed = 0

	while processed < batch_size and #runtime.tracked_units > 0 do
		clamp_audit_cursor(runtime)

		local unit_number = runtime.tracked_units[runtime.audit_cursor]
		local record = unit_number and runtime.locomotives_by_unit[unit_number] or nil
		if not record or not record.locomotive or not record.locomotive.valid then
			if unit_number then
				remove_record(runtime, unit_number)
			else
				runtime.audit_cursor = runtime.audit_cursor + 1
			end
			processed = processed + 1
		else
			if ensure_wheels(record) then
				sync_record(runtime, record, true)
			else
				local locomotive = record.locomotive
				local height_mode = WheelControl:get_height_mode(locomotive)
				if locomotive.speed ~= 0
					or record.last_speed == nil
					or locomotive.orientation ~= record.last_orientation
					or height_mode ~= record.last_height_mode
					or locomotive.surface.index ~= record.last_surface_index
				then
					activate_record(runtime, record)
				end
			end

			runtime.audit_cursor = runtime.audit_cursor + 1
			processed = processed + 1
		end
	end

	clamp_audit_cursor(runtime)
end

function steam_train.check_global()
	if not storage.ei then
		storage.ei = {}
	end

	local runtime = storage.ei.locomotives
	if type(runtime) ~= "table"
		or not runtime.locomotives_by_unit
		or not runtime.tracked_units
		or not runtime.tracked_index_by_unit
		or not runtime.active_units
		or not runtime.active_index_by_unit
	then
		storage.ei.locomotives = new_runtime_state()
		return storage.ei.locomotives
	end

	runtime.audit_cursor = runtime.audit_cursor or 1
	return runtime
end

function steam_train.rebuild_runtime_state(reason)
	-- Rebuild throws away runtime bookkeeping and reconstructs it from the world. This is the
	-- supported repair path for init, configuration changes, and any future admin rescan hook.
	local _ = reason
	local runtime = new_runtime_state()
	local locomotives = {}
	local seen_units = {}
	local stale_entities = {}

	for _, surface in pairs(game.surfaces) do
		for _, entity in pairs(surface.find_entities_filtered({
			name = {
				STEAM_LOCOMOTIVE_NAME,
				BASE_WHEELS_NAME,
				ELEVATED_WHEELS_NAME,
				PLACEMENT_ENTITY_NAME
			}
		})) do
			if entity and entity.valid then
				if entity.name == STEAM_LOCOMOTIVE_NAME then
					local unit_number = entity.unit_number
					if unit_number and not seen_units[unit_number] then
						seen_units[unit_number] = true
						locomotives[#locomotives + 1] = entity
					end
				else
					-- Wheels and placement entities are helper artifacts; rebuild recreates the
					-- good ones and clears the rest.
					stale_entities[#stale_entities + 1] = entity
				end
			end
		end
	end

	for i = 1, #stale_entities do
		local entity = stale_entities[i]
		if entity.valid then
			entity.destroy()
		end
	end

	for i = 1, #locomotives do
		register_locomotive(runtime, locomotives[i], true)
	end

	storage.ei.locomotives = runtime
end

function steam_train.updater(event)
	local runtime = steam_train.check_global()
	-- Run a small repair slice every tick so missing wheels and stale records heal on their own.
	run_audit(runtime)

	if event.tick % WHEEL_UPDATE_TICK > 0 then
		return
	end

	for i = #runtime.active_units, 1, -1 do
		local unit_number = runtime.active_units[i]
		local record = unit_number and runtime.locomotives_by_unit[unit_number] or nil
		if not record then
			if unit_number then
				remove_from_queue(runtime.active_units, runtime.active_index_by_unit, unit_number)
			end
		else
			sync_record(runtime, record, false)
		end
	end
end

function steam_train.on_built_entity(e)
	if not e or not e.entity or not e.entity.valid then
		return
	end

	local runtime = steam_train.check_global()
	if e.entity.name == PLACEMENT_ENTITY_NAME then
		-- The placement entity exists only to provide the custom build-time visuals; runtime
		-- always swaps it to the real locomotive immediately.
		local force = game.forces.neutral
		if e.player_index then
			local player = game.get_player(e.player_index)
			force = player and player.force or force
		elseif e.robot then
			force = e.robot.force
		end

		local position = e.entity.position
		local orientation = e.entity.orientation
		local surface = e.entity.surface
		local quality = e.entity.quality
		e.entity.destroy()

		local locomotive = surface.create_entity({
			name = STEAM_LOCOMOTIVE_NAME,
			position = position,
			orientation = orientation,
			force = force,
			quality = quality,
			raise_script_built = false
		})

		if locomotive and locomotive.valid then
			register_locomotive(runtime, locomotive, true)
		end
	elseif e.entity.name == STEAM_LOCOMOTIVE_NAME then
		register_locomotive(runtime, e.entity, true)
	end
end

function steam_train.addToGlobal(locomotive)
	-- Kept as a compatibility shim for any existing callers that still use the old helper name.
	register_locomotive(steam_train.check_global(), locomotive, true)
end

function steam_train.on_destroyed_entity(entity)
	-- Destroy handlers fire before the steady-state updater sees the invalid locomotive, which
	-- lets us retire its wheel helpers immediately instead of waiting for the next poll.
	if not entity or not entity.valid or entity.name ~= STEAM_LOCOMOTIVE_NAME then
		return
	end

	local unit_number = entity.unit_number
	if unit_number then
		remove_record(steam_train.check_global(), unit_number)
	end
end

function steam_train.on_train_changed_state(train)
	mark_train_locomotives_active(steam_train.check_global(), train)
end

return steam_train
