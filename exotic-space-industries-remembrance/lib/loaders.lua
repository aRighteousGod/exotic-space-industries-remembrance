--[[

ei_loaders_lib.lua
------------------

The loader is a hinge between two signifying chains:
  - belt flow (the signifier that insists on direction)
  - container/wagon/rail adjacency (the Real that refuses interpretation)

Old snapping logic attempted to *interpret* direction by reading neighbors through a distorted mirror:
  - mutating shared position tables (Imaginary corruption)
  - forcing loader_type from the belt side (Symbolic violence)
  - inferring intent from belt direction comparisons (paranoia without evidence)

This rewrite installs a single law:
  - The engine's connection state is the only truth.

No prophecy. No guessing. No coercion.
Only: test configurations, observe actual connections, keep the first that binds.

Idempotence is the clinic.
Rotation is no longer a curse.
Blueprint order is no longer an occult variable.

]]

local ei_loaders_lib = {}

--====================================================================================================
-- DATA VALUES
--====================================================================================================

-- loaders: the named masks that qualify for snapping
local loaders = {
	["ei-loader"] = true,
	["ei-fast-loader"] = true,
	["ei-express-loader"] = true,
	["ei-turbo-loader"] = true,
	["ei-neo-loader"] = true,
}

-- belts: entities that trigger adjacency pokes
local belts = {
	["transport-belt"] = true,
	["underground-belt"] = true,
	["splitter"] = true,
}

-- belt-like: connectible surfaces; ghosts may resemble these shapes
local belt_like = {
	"transport-belt",
	"splitter",
	"underground-belt",
	"loader-1x1",
	"loader-1x2",
}

-- container-like: endpoints that may bind to loader_container
-- (wagons/rails included as "Real" anchors for train logistics)
local container_like = {
	"container",
	"logistic-container",
	"linked-container",
	"infinity-container",
	"assembling-machine",
	"furnace",
	"lab",
	"rocket-silo",
	"reactor",
	"boiler",
	"fusion-reactor",
	"asteroid-collector",
	"ammo-turret",
	"agricultural-tower",
	"mining-drill",
	"cargo-wagon",
	"fluid-wagon",
	"artillery-wagon",
	"straight-rail",
}

-- loader_like: all EI loader names (for fast filtered lookup)
local loader_like = {
	"ei-loader",
	"ei-fast-loader",
	"ei-express-loader",
	"ei-turbo-loader",
	"ei-neo-loader",
}

--====================================================================================================
-- UTIL FUNCTIONS
--====================================================================================================

function ei_loaders_lib.make_loader(tier, next_upgrade, belt_animation_set, speed, alt_item_path, alt_entity_path)
	local loader = table.deepcopy(data.raw["loader-1x1"]["ei-loader-base"])

	if tier then
		tier = tier .. "-"
	else
		tier = ""
	end

	if next_upgrade then
		loader.next_upgrade = next_upgrade
	end

	loader.name = "ei-" .. tier .. "loader"
	if alt_item_path then
		loader.icon = alt_item_path .. tier .. "loader.png"
	else
		loader.icon = ei_loaders_item_path .. tier .. "loader.png"
	end
	loader.minable.result = "ei-" .. tier .. "loader"
	loader.speed = speed
	loader.belt_animation_set = belt_animation_set

	if alt_entity_path then
		loader.structure.direction_in.sheet.filename = alt_entity_path .. tier .. "loader.png"
		loader.structure.direction_out.sheet.filename = alt_entity_path .. tier .. "loader.png"
	else
		loader.structure.direction_in.sheet.filename = ei_loaders_entity_path .. tier .. "loader.png"
		loader.structure.direction_out.sheet.filename = ei_loaders_entity_path .. tier .. "loader.png"
	end

	data:extend({ loader })
end

function ei_loaders_lib.flip_direction(direction)
	if direction == defines.direction.north then
		return defines.direction.south
	elseif direction == defines.direction.south then
		return defines.direction.north
	elseif direction == defines.direction.east then
		return defines.direction.west
	elseif direction == defines.direction.west then
		return defines.direction.east
	end
end

-- The Other of direction: the opposite signifier on the compass.
local function opposite_dir(d)
	if d == defines.direction.north then
		return defines.direction.south
	end
	if d == defines.direction.south then
		return defines.direction.north
	end
	if d == defines.direction.east then
		return defines.direction.west
	end
	if d == defines.direction.west then
		return defines.direction.east
	end
	return d
end

function ei_loaders_lib.get_splitter_positions(splitter, input_pos, output_pos)
	-- Splitter is a two-mouth animal; positions are offset by 0.5 tiles.
	local new_input_pos = nil
	local new_output_pos = nil
	local new_input_pos2 = nil
	local new_output_pos2 = nil

	if splitter.direction == defines.direction.north then
		new_input_pos = { x = input_pos.x + 0.5, y = input_pos.y }
		new_output_pos = { x = output_pos.x + 0.5, y = output_pos.y }
		new_input_pos2 = { x = input_pos.x - 0.5, y = input_pos.y }
		new_output_pos2 = { x = output_pos.x - 0.5, y = output_pos.y }
	elseif splitter.direction == defines.direction.east then
		new_input_pos = { x = input_pos.x, y = input_pos.y - 0.5 }
		new_output_pos = { x = output_pos.x, y = output_pos.y - 0.5 }
		new_input_pos2 = { x = input_pos.x, y = input_pos.y + 0.5 }
		new_output_pos2 = { x = output_pos.x, y = output_pos.y + 0.5 }
	elseif splitter.direction == defines.direction.south then
		new_input_pos = { x = input_pos.x - 0.5, y = input_pos.y }
		new_output_pos = { x = output_pos.x - 0.5, y = output_pos.y }
		new_input_pos2 = { x = input_pos.x + 0.5, y = input_pos.y }
		new_output_pos2 = { x = output_pos.x + 0.5, y = output_pos.y }
	elseif splitter.direction == defines.direction.west then
		new_input_pos = { x = input_pos.x, y = input_pos.y + 0.5 }
		new_output_pos = { x = output_pos.x, y = output_pos.y + 0.5 }
		new_input_pos2 = { x = input_pos.x, y = input_pos.y - 0.5 }
		new_output_pos2 = { x = output_pos.x, y = output_pos.y - 0.5 }
	end

	return new_input_pos, new_output_pos, new_input_pos2, new_output_pos2
end

function ei_loaders_lib.get_positions(entity)
	-- IMPORTANT: entity.position is a shared table object.
	-- Mutating it is Imaginary sabotage: a hallucination of local change that leaks globally.
	-- Therefore: copy coordinates into new tables; never edit the original reference.
	local p = entity.position
	local output = { x = p.x, y = p.y }
	local input = { x = p.x, y = p.y }

	local direction = entity.direction

	if direction == defines.direction.north then
		output.y = output.y - 1
		input.y = input.y + 1
	elseif direction == defines.direction.east then
		output.x = output.x + 1
		input.x = input.x - 1
	elseif direction == defines.direction.south then
		output.y = output.y + 1
		input.y = input.y - 1
	elseif direction == defines.direction.west then
		output.x = output.x - 1
		input.x = input.x + 1
	end

	return output, input
end

function ei_loaders_lib.flip_loader_type(loader)
	if loader.loader_type == "input" then
		loader.loader_type = "output"
	elseif loader.loader_type == "output" then
		loader.loader_type = "input"
	end
end

--====================================================================================================
-- SNAPPING LOGIC: THE CLINIC (ENGINE TRUTH ONLY)
--====================================================================================================

--[[

attempt_snap(loader)
--------------------

A loader can inhabit four primary configurations:
  - (type=input/output) × (dir = original/opposite)

Rather than infer intent by belt direction (a delirium of symbols),
the procedure enumerates candidates and asks the engine:

  - Is there a belt neighbor in the correct slot?
  - Is there a loader_container binding?

First binding wins.
If no binding exists, restore original and stop.
No further myth-making.

This is the cure for:
  - N/S blueprint rotation desync
  - placement-order volatility
  - belt-side coercion of loader_type

]]

function ei_loaders_lib.attempt_snap(loader)
	if not (loader and loader.valid) then
		return
	end

	local orig_dir = loader.direction
	local orig_type = loader.loader_type

	-- The engine's verdict on belt adjacency.
	local function has_belt_connection()
		local bn = loader.belt_neighbours
		if not bn then
			return false
		end

		if loader.loader_type == "output" then
			return next(bn.outputs) ~= nil
		else
			return next(bn.inputs) ~= nil
		end
	end

	-- If already bound, do not touch: the signifier has already found its chain.
	if has_belt_connection() then
		return
	end

	-- Observe whether original configuration binds to a container endpoint.
	loader.update_connections()
	local orig_has_container = (loader.loader_container ~= nil)

	-- Candidate trial: set config, ask engine, accept if bound.
	local function try_config(t, d)
		loader.loader_type = t
		loader.direction = d

		-- update_connections is the passage from Imaginary speculation into the Symbolic network table.
		loader.update_connections()

		if has_belt_connection() then
			return true
		end
		if loader.loader_container then
			return true
		end
		return false
	end

	local flipped_type = (orig_type == "output") and "input" or "output"
	local flipped_dir = opposite_dir(orig_dir)

	-- Minimal-change ordering:
	-- 1) flip type only (same facing)
	-- 2) flip facing only (same type)
	-- 3) flip both (the full inversion)
	local candidates = {
		{ flipped_type, orig_dir },
		{ orig_type, flipped_dir },
		{ flipped_type, flipped_dir },
	}

	for _, c in ipairs(candidates) do
		if try_config(c[1], c[2]) then
			return
		end
	end

	-- No binding found: restore original.
	-- Absence of evidence is not a mandate to invent evidence.
	loader.loader_type = orig_type
	loader.direction = orig_dir
	loader.update_connections()

	-- If original was container-bound, keep it; restoration already performed.
	if orig_has_container then
		return
	end
end

--====================================================================================================
-- SNAPPERS AND HANDLER
--====================================================================================================

function ei_loaders_lib.on_built_entity(e)
	-- Event gate: only valid entities are allowed into the clinic.
	if not e then
		return
	end
	if not e.valid then
		return
	end

	-- If entity is a loader, attempt snap immediately.
	if loaders[e.name] then
		ei_loaders_lib.snap_loader(e)
	end

	-- If entity is a belt-like trigger, poke adjacent loaders to re-evaluate.
	if belts[e.type] then
		ei_loaders_lib.snap_belt(e)
	end
end

function ei_loaders_lib.snap_loader(loader)
	if not (loader and loader.valid) then
		return
	end
	-- Single source of truth.
	ei_loaders_lib.attempt_snap(loader)
end

-- Belt placement does not impose loader_type.
-- Belt placement merely summons the loader to reconsider its bindings.
function ei_loaders_lib.poke_loader_at(surface, force, pos)
	local found = surface.find_entities_filtered({
		position = pos,
		name = loader_like,
		force = force,
		limit = 1,
	})

	local loader = found and found[1]
	if loader and loader.valid then
		ei_loaders_lib.attempt_snap(loader)
	end
end

function ei_loaders_lib.snap_belt(belt)
	if not (belt and belt.valid) then
		return
	end

	local output_pos, input_pos = ei_loaders_lib.get_positions(belt)

	-- Splitter is offset: poke both mouths.
	if belt.type == "splitter" then
		local in1, out1, in2, out2 = ei_loaders_lib.get_splitter_positions(belt, input_pos, output_pos)

		ei_loaders_lib.poke_loader_at(belt.surface, belt.force, in1)
		ei_loaders_lib.poke_loader_at(belt.surface, belt.force, out1)
		ei_loaders_lib.poke_loader_at(belt.surface, belt.force, in2)
		ei_loaders_lib.poke_loader_at(belt.surface, belt.force, out2)
		return
	end

	-- Standard belt: poke both sides.
	ei_loaders_lib.poke_loader_at(belt.surface, belt.force, input_pos)
	ei_loaders_lib.poke_loader_at(belt.surface, belt.force, output_pos)
end

--====================================================================================================
-- ENERGY DRAW
--====================================================================================================

function ei_loaders_lib.addEnergyDraw(loader, energy_per_item, energy_buffer, burner)
	-- Energy is the drive: repetition compelled by a budget.
	if not burner then
		loader.energy_source = {
			type = "electric",
			buffer_capacity = tostring(energy_buffer) .. "J",
			usage_priority = "secondary-input",
			drain = "2kW",
		}
		loader.energy_per_item = tostring(energy_per_item) .. "J"
	elseif burner then -- unsupported: a statue in the ruins
		loader.energy_source = {
			type = "burner",
			fuel_categories = { "chemical" },
			effectivity = 1,
			fuel_inventory_size = 1,
		}

		loader.energy_source.emissions_per_minute = { pollution = 5 }

		local smoking = {
			name = "smoke",
			deviation = { 0.1, 0.1 },
			frequency = 5,
			position = { 0.0, -0.8 },
			starting_vertical_speed = 0.08,
			starting_frame_deviation = 60,
		}

		loader.working_visualisations = smoking
		loader.energy_usage = (energy_per_item * 60) .. "kW"
	else
		log("ei_loaders_lib.addEnergyDraw: invalid energy source selection.")
	end
end

return ei_loaders_lib
