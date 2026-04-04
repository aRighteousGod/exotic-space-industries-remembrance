local public = {}

local BASE_HEIGHT_THRESHOLD = 0.1
local ELEVATED_HEIGHT_THRESHOLD = 2.9
local HIDDEN_POSITION = {1e6, 1e6}
-- This offset matches the helper car sprite alignment used by the original steam wheel setup.
local WHEEL_OFFSET = {x = 0, y = 0.5}

local function set(wheels, locomotive)
	if not wheels or not wheels.valid or not locomotive or not locomotive.valid then
		return
	end

	-- The locomotive's logical position is not the visual center for this sprite. The
	-- selection box center preserves the original wheel alignment.
	local selection_box = locomotive.selection_box
	local center_x = (selection_box.left_top.x + selection_box.right_bottom.x) * 0.5
	local center_y = (selection_box.left_top.y + selection_box.right_bottom.y) * 0.5
	wheels.orientation = locomotive.orientation
	wheels.speed = locomotive.speed
	wheels.teleport({x = center_x + WHEEL_OFFSET.x, y = center_y + WHEEL_OFFSET.y}, locomotive.surface)
end

local function hide(wheels, surface)
	if not wheels or not wheels.valid then
		return
	end

	if wheels.position.x ~= HIDDEN_POSITION[1] or wheels.position.y ~= HIDDEN_POSITION[2] then
		wheels.orientation = 1
		wheels.teleport(HIDDEN_POSITION, surface)
		wheels.speed = 0
	end
end

function public:apply_wheels(locomotive)
	-- https://www.youtube.com/watch?v=CZs-YcmxyUw
	return {
		base = locomotive.surface.create_entity({
			name = "ei-steam-wheels",
			position = locomotive.position,
			orientation = locomotive.orientation,
			force = game.forces.neutral
		}),
		elevated = locomotive.surface.create_entity({
			name = "ei-steam-wheels-elevated",
			position = locomotive.position,
			orientation = locomotive.orientation,
			force = game.forces.neutral
		})
	}
end

function public:get_height_mode(locomotive)
	-- Base rail, elevated rail, and transition ramps each need slightly different handling.
	if not locomotive or not locomotive.valid then
		return 0
	end

	local height = locomotive.draw_data.height
	if height <= BASE_HEIGHT_THRESHOLD then
		return 1
	end
	if height >= ELEVATED_HEIGHT_THRESHOLD then
		return 2
	end

	return 0
end

function public:update_wheel_position(locomotive, wheels, height_mode, previous_height_mode)
	if not locomotive or not locomotive.valid or not wheels then
		return
	end

	height_mode = height_mode or self:get_height_mode(locomotive)
	if height_mode == 1 then
		-- Only hide the opposite helper when the rail mode changes; otherwise the hot path just
		-- updates the visible wheel entity.
		if previous_height_mode ~= 1 then
			hide(wheels.elevated, locomotive.surface)
		end
		set(wheels.base, locomotive)
	elseif height_mode == 2 then
		if previous_height_mode ~= 2 then
			hide(wheels.base, locomotive.surface)
		end
		set(wheels.elevated, locomotive)
	elseif previous_height_mode ~= 0 or previous_height_mode == nil then
		hide(wheels.base, locomotive.surface)
		hide(wheels.elevated, locomotive.surface)
	end
end

return public
