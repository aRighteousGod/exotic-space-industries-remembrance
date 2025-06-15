
steam_train = {}

local WheelControl = require("lib/handle_wheels.lua")
--====================================================================================================
--Steam locomotive by cupcakescankill / IonShield
--====================================================================================================
WHEEL_UPDATE_TICK = math.max(1,math.min(5,ei_ticksPerFullUpdate/30)) --Looks ridiculous if they don't happen often enough
CLEANUP_UPDATE_TICK = ei_ticksPerFullUpdate*10 --600
function steam_train.updater(event)
   	if event.tick % WHEEL_UPDATE_TICK > 0 then
		return
	end
	for i = 1, #storage.ei.locomotives, 1 do
		local v = storage.ei.locomotives[i]
		if not v then
			return
		end

		if steam_train.is_locomotive_valid(i, v) then
			if not v.wheels or not v.wheels.base.valid or not v.wheels.elevated.valid then
				v.wheels = WheelControl:apply_wheels(v.locomotive)
			end
			WheelControl:update_wheel_position(v.locomotive, v.wheels)
		else
			if v.wheels and v.wheels.base and v.wheels.base.valid then
				v.wheels.base.destroy()
			end
			if v.wheels and v.wheels.elevated and v.wheels.elevated.valid then
				v.wheels.elevated.destroy()
			end
		end
	end
end

function steam_train.on_built_entity(e)
	if e and e.entity and e.entity.valid then
		if (e.entity.name == 'ei-steam-basic-locomotive-placement-entity') then
			local force = game.forces.neutral
			if (e.player_index) then
				local player = game.get_player(e.player_index)
	---@diagnostic disable-next-line: cast-local-type
				force = player and player.force or force
			elseif (e.robot) then
				force = e.robot.force
			end
			local position = e.entity.position
			local orientation = e.entity.orientation
			local surface = e.entity.surface
			local quality = e.entity.quality
			e.entity.destroy()
			local locomotive = surface.create_entity({
				name = "ei-steam-basic-locomotive",
				position = position,
				orientation = orientation,
				force = force,
				quality = quality,
				raise_script_built = false
			})
			steam_train.addToGlobal(locomotive)
		elseif (e.entity.name == 'ei-steam-basic-locomotive') then
			steam_train.addToGlobal(e.entity)
		end
	end
end


function steam_train.addToGlobal(locomotive)
	table.insert(storage.ei.locomotives, {
		locomotive = locomotive,
		wheels = WheelControl:apply_wheels(locomotive)
	})
end

function steam_train.is_locomotive_valid(i, v)
	if not v then
		table.remove(storage.ei.locomotives, i)
		return false
	end
	if not v.locomotive or not v.locomotive.valid then
		table.remove(storage.ei.locomotives, i)
		if v.wheels then
			v.wheels.base.destroy()
			v.wheels.elevated.destroy()
			v.wheels = nil
		end
		return false
	else
		return true
	end
end
--[[
function steam_train.on_script_built(event)
	local entity = event.entity
		if entity and entity.name == 'ei-steam-basic-locomotive' then
			addToGlobal(entity)
		end
end
]]
function steam_train.steam_locomotive_cleanup()
	local wheels = {}
	local elevated_wheels = {}
	local locomotives = {}

	for i,v in pairs(storage.ei.locomotives) do
		wheels[v.wheels.base.unit_number] = true
		elevated_wheels[v.wheels.elevated.unit_number] = true
		locomotives[v.locomotive.unit_number] = true
	end

	for _, surface in pairs(game.surfaces) do
		for _, v in pairs(surface.find_entities_filtered({name={"ei-steam-wheels","ei-steam-wheels-elevated","ei-steam-basic-locomotive","ei-steam-basic-locomotive-placement-entity"}})) do
			if v and v.valid then
				if v.name == "ei-steam-wheels" then
					if not wheels[v.unit_number] then
						v.destroy()
					end
				elseif v.name == "ei-steam-wheels-elevated" then
					if not elevated_wheels[v.unit_number] then
						v.destroy()
					end
				elseif v.name == "ei-steam-basic-locomotive" then
					if not locomotives[v.unit_number] then
						addToGlobal(v)
					end
				elseif v.name == "ei-steam-basic-locomotive-placement-entity" then
					v.destroy()
				end
			end
		end
	end
end

return steam_train