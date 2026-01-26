local public = {}

function public:apply_wheels(locomotive)
	--https://www.youtube.com/watch?v=CZs-YcmxyUw
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

function public:update_wheel_position(locomotive, wheels)
	if not locomotive or not locomotive.valid then return end

	if locomotive.draw_data.height > 0.1 then
		if wheels.base.position.x ~= 1e6 then
			wheels.base.orientation = 1
			wheels.base.teleport({1e6, 1e6}, locomotive.surface)
			wheels.base.speed = 0
		end
	elseif wheels.base.speed ~= 0 or locomotive.speed ~= 0 or wheels.base.orientation ~= locomotive.orientation then
		set(wheels.base, locomotive)
	end

	if locomotive.draw_data.height < 2.9 then
		if wheels.elevated.position.x ~= 1e6 then
			wheels.elevated.orientation = 1
			wheels.elevated.teleport({1e6, 1e6}, locomotive.surface)
			wheels.elevated.speed = 0
		end
	elseif wheels.elevated.speed ~= 0 or locomotive.speed ~= 0 or wheels.elevated.orientation ~= locomotive.orientation then
		set(wheels.elevated, locomotive)
	end
end

function set(wheels, locomotive)
	if not wheels or not wheels.valid or not locomotive or not locomotive.valid then return end

	wheels.orientation = locomotive.orientation
	local offset = {x = 0, y = 0.5}
	local b = locomotive.selection_box
	local bx = (b.left_top.x + b.right_bottom.x) * 0.5
	local by = (b.left_top.y + b.right_bottom.y) * 0.5
	wheels.speed = locomotive.speed
	wheels.teleport({x = bx + offset.x, y = by + offset.y}, locomotive.surface)
end

return public
