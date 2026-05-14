--==============================================================================
-- ESIR FILE MAP
-- owns: black hole GUI and runtime
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build, destroy, GUI dispatch, and every-tick runtime updates
-- forwarded_events: apply_output, built_extractor_pylon, built_injector_pylon, change_stage, check_battery, check_init, close_gui, ensure_runtime_defaults, entity_check, get_data, get_extractor_pylons_in_range, get_injector_pylons_in_range, get_mass, get_power, get_relative_stage_progress, get_stage, get_stage_progress, get_transfer_inv, has_tick_work, invoke_victory, make_energy, make_output, make_stage_picture, mark_nearby_black_holes_dirty, on_built_entity, on_destroyed_entity, on_gui_click, on_gui_opened, open_gui, rebuild_runtime_state, refresh_nearby_pylons, register_black_hole, set_stage_progress, transfer_valid, unregister_black_hole, update, update_battery, update_black_hole, update_black_holes, update_gui, update_mass, update_player_guis, update_stage
-- storage_roots: storage.ei
-- gui_ids: ei-black-hole-console
-- remote_interfaces: none
-- rebuild_on: entity schema changes, GUI schema changes
--==============================================================================
local model = {}
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local get_valid_entity = ei_lib.get_valid_entity
local get_entity_unit_number = ei_lib.get_entity_unit_number
local BLACK_HOLE_NAME = "ei-black-hole"
local ENERGY_INJECTOR_NAME = "ei-energy-injector-pylon"
local ENERGY_EXTRACTOR_NAME = "ei-energy-extractor-pylon"
local BLACK_HOLE_RADIUS = 20
-- The cache self-heals on a timer so stale refs from save/load or missed invalidations
-- do not persist forever, but steady-state black holes avoid scanning every tick.
local BLACK_HOLE_CACHE_REFRESH_TICKS = 300
local BLACK_HOLE_GUI_REFRESH_TICKS = 30
local INJECTOR_MIN_ENERGY = 10 * 1000 * 1000
local GIGA = 1000 * 1000 * 1000

local function is_dormant_black_hole(black_hole_data)
    if not black_hole_data then
        return false
    end

    return (black_hole_data.stage or 0) == 0
        and (black_hole_data.stage_progress or 0) == 0
        and (black_hole_data.mass or 0) <= 0
        and (black_hole_data.energy or 0) <= 0
        and not black_hole_data.cache_dirty
        and not black_hole_data.extractor_state_dirty
        and not black_hole_data.output_stage_active
end

--====================================================================================================
--BLACK HOLE
--====================================================================================================

-- HOW IT WORKS
-- 3 STAGES:
-- 0: no injector pylons needed, no energy produced, at start no mass gets absorbed
-- if stage progress > 1 then mass gets absorbed until 1000 is reached -> stage 1

-- 1: 8 injector pylons needed (not at progess = 0), no energy produced, mass gets constantly absorbed/decays
-- if stage progess > 1, then 8 pylons need to be active, in 60s the black hole builds up to full size -> stage 2

-- 2: 8 injector pylons needed contantly, energy gets produced according to current mass AND mass decaying, can be extracted through extractor pylons

-- when progess is 0 is a kind of waiting state for the player to press a button to start the next stage

-- NOTE: injector pylons are considered as active if they have at least 10GJ of energy in their internal buffer (max is 20GJ),
-- they consume 5GW constantly


--UTIL
------------------------------------------------------------------------------------------------------

function model.get_transfer_inv(transfer)
    -- transfer is either a player index, a robot, or nil
    -- needed to prevent unregistration when the transferer cant mine due to full inv

    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        -- player index
        local player = game.get_player(transfer)
        return player and player.valid and player.get_main_inventory() or nil
    end

    if transfer and transfer.valid then
        -- robot
        local robot = transfer
        return robot.get_inventory(defines.inventory.robot_cargo)
    end

    return nil

end


local function normalize_content_entry(item_key, item_value)
    if type(item_key) == "string" then
        return {
            name = item_key,
            count = item_value
        }
    end

    if type(item_value) == "table" and item_value.name and item_value.count then
        return item_value
    end

    return nil
end


function model.transfer_valid(source, transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        -- case for when destroyed by gun f.e. -> need to unregister
        return true
    end

    -- check if contents of source and the source itself can be inserted into the target
    local source_inv = source.get_inventory(defines.inventory.chest)
    local source_contents = source_inv and source_inv.get_contents() or {}

    local return_value = true

    for item_key, item_value in pairs(source_contents) do
        local item = normalize_content_entry(item_key, item_value)
        if item then
            local insertable_probe = ei_lib.make_item_with_quality_id(item) or item.name
            local ok, insertable_count = pcall(target_inv.get_insertable_count, insertable_probe)

            if not ok or insertable_count < item.count then
                return_value = false
            end
        end
    end

    -- check if the source itself can be inserted into the target
    local source_stack = ei_lib.make_item_with_quality_id(source) or {name = source.name}
    source_stack.count = 1
    local ok, can_insert = pcall(target_inv.can_insert, source_stack)

    if not ok or not can_insert then
        return_value = false
    end

    if return_value == true then
        if type(transfer) ~= "number" then
            -- robot
            -- if the source inv is not empty, the robot will not mine the source
            if source_inv and not source_inv.is_empty() then
                return_value = false
            end
        end
    end

    return return_value

end


function model.entity_check(entity)
    return ei_lib.entity_check(entity)

end


function model.check_init(id)

    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei.black_hole then
        storage.ei.black_hole = {}
    end

    if not id then
        return
    end

    if not storage.ei.black_hole[id] then
        storage.ei.black_hole[id] = {}
    end

end


local function get_entity_ref_id(entity)
    -- Most nearby pylons have a unit number, but the fallback keeps the cache comparison
    -- resilient for entities that only have position-based identity.
    if not entity or not entity.valid then
        return nil
    end

    local unit_number = get_entity_unit_number(entity)
    if unit_number then
        return unit_number
    end

    return table.concat({
        entity.surface.index,
        entity.name,
        entity.position.x,
        entity.position.y
    }, ":")
end


local function same_entity_refs(current_refs, new_refs)
    -- Compare membership instead of table identity so fresh scan results can reuse the
    -- same cache unless the nearby set actually changed.
    local current = {}
    local current_count = 0

    for _, entity in ipairs(current_refs or {}) do
        local id = get_entity_ref_id(entity)
        if id then
            current[id] = true
            current_count = current_count + 1
        end
    end

    local new_count = 0
    for _, entity in ipairs(new_refs or {}) do
        local id = get_entity_ref_id(entity)
        if not id or not current[id] then
            return false
        end

        new_count = new_count + 1
    end

    return current_count == new_count
end


function model.ensure_runtime_defaults(black_hole_data, event)
    -- Cache fields are transient runtime state, so they must be rebuilt lazily for older
    -- saves and for pre-existing black holes after script changes.
    if not black_hole_data then
        return
    end

    if not black_hole_data.injectors then
        black_hole_data.injectors = {}
    end

    if not black_hole_data.extractors then
        black_hole_data.extractors = {}
    end

    if black_hole_data.cache_dirty == nil then
        black_hole_data.cache_dirty = true
    end

    if black_hole_data.last_cache_refresh == nil then
        black_hole_data.last_cache_refresh = event and event.tick or 0
    end

    if black_hole_data.cached_injector_count == nil then
        black_hole_data.cached_injector_count = 0
    end

    if black_hole_data.cached_active_injector_count == nil then
        black_hole_data.cached_active_injector_count = 0
    end

    if black_hole_data.cached_extractor_count == nil then
        black_hole_data.cached_extractor_count = 0
    end

    if black_hole_data.extractor_state_dirty == nil then
        black_hole_data.extractor_state_dirty = true
    end

    if black_hole_data.output_stage_active == nil then
        black_hole_data.output_stage_active = false
    end

    if black_hole_data.last_overlay_stage == nil then
        black_hole_data.last_overlay_stage = -1
    end
end

local function render_object_is_valid(render_object)
    local ok, valid = pcall(function()
        return render_object and render_object.valid
    end)

    return ok and valid == true
end

local function destroy_render_object(render_object)
    if render_object_is_valid(render_object) then
        render_object.destroy()
    end
end

local function ensure_black_hole_animation(black_hole_data, entity)
    if render_object_is_valid(black_hole_data.animation) then
        return
    end

    black_hole_data.animation = rendering.draw_animation{
        animation = "ei-black-hole_animation",
        target = entity,
        surface = entity.surface,
        render_layer = "object",
        x_scale = 1,
        y_scale = 1,
    }
end


function model.refresh_nearby_pylons(black_hole_data, entity, event, force_refresh)
    -- The hot-path UPS win is here: refresh nearby pylons only when topology changed or
    -- the periodic self-heal window expires, then reuse entity refs every tick.
    model.ensure_runtime_defaults(black_hole_data, event)

    local tick = event and event.tick or 0
    if not force_refresh
       and not black_hole_data.cache_dirty
       and tick - black_hole_data.last_cache_refresh < BLACK_HOLE_CACHE_REFRESH_TICKS then
        return false
    end

    local injectors = entity.surface.find_entities_filtered{
        name = ENERGY_INJECTOR_NAME,
        position = entity.position,
        radius = BLACK_HOLE_RADIUS,
    }
    local extractors = entity.surface.find_entities_filtered{
        name = ENERGY_EXTRACTOR_NAME,
        position = entity.position,
        radius = BLACK_HOLE_RADIUS,
    }

    local injectors_changed = not same_entity_refs(black_hole_data.injectors, injectors)
    local extractors_changed = not same_entity_refs(black_hole_data.extractors, extractors)

    black_hole_data.injectors = injectors
    black_hole_data.extractors = extractors
    black_hole_data.cached_injector_count = #injectors
    black_hole_data.cached_extractor_count = #extractors
    black_hole_data.cache_dirty = false
    black_hole_data.last_cache_refresh = tick

    if extractors_changed then
        black_hole_data.extractor_state_dirty = true
    end

    return injectors_changed or extractors_changed
end


function model.mark_nearby_black_holes_dirty(entity)
    -- Pylon build/destroy is rare compared to on_tick, so paying the radius search here
    -- is much cheaper than making every black hole rediscover neighbors constantly.
    if not model.entity_check(entity) then
        return
    end

    if entity.name ~= ENERGY_INJECTOR_NAME and entity.name ~= ENERGY_EXTRACTOR_NAME then
        return
    end

    if not storage.ei or not storage.ei.black_hole then
        return
    end

    local black_holes = entity.surface.find_entities_filtered{
        name = BLACK_HOLE_NAME,
        position = entity.position,
        radius = BLACK_HOLE_RADIUS,
    }

    for _, black_hole in ipairs(black_holes) do
        local unit = get_entity_unit_number(black_hole)
        if model.entity_check(black_hole) and unit and storage.ei.black_hole[unit] then
            local black_hole_data = storage.ei.black_hole[unit]
            black_hole_data.cache_dirty = true
            if entity.name == ENERGY_EXTRACTOR_NAME then
                black_hole_data.extractor_state_dirty = true
            end
        end
    end
end


--UPDATE
------------------------------------------------------------------------------------------------------

function model.update_black_holes(event)

    if not storage.ei.black_hole then
        return
    end


    for unit,_ in pairs(storage.ei.black_hole) do
        model.update_black_hole(unit,event)
    end

end


function model.update_black_hole(unit, event)
    local black_hole_data = storage.ei.black_hole[unit]
    if not black_hole_data then
        return
    end

    local entity = black_hole_data.entity

    if not model.entity_check(entity) then
        return
    end

    -- Core simulation still runs every tick while the hole is active. Fully idle stage-0
    -- holes only keep the cheap mass probe and the existing cache self-heal window alive.
    model.ensure_runtime_defaults(black_hole_data, event)
    local tick = event and event.tick or 0
    local cache_refresh_due = tick - (black_hole_data.last_cache_refresh or 0) >= BLACK_HOLE_CACHE_REFRESH_TICKS
    if is_dormant_black_hole(black_hole_data) and not cache_refresh_due then
        model.update_mass(black_hole_data, entity)
        if is_dormant_black_hole(black_hole_data) then
            ei_runtime_scheduler.bump_counter("black-hole", "dormant_skipped", 1)
            return
        end
    end

    model.refresh_nearby_pylons(black_hole_data, entity, event)

    -- aborb all items in inventory and add them to mass count
    model.update_mass(black_hole_data, entity)

    model.update_battery(black_hole_data)

    model.make_energy(black_hole_data, event)

    model.make_output(black_hole_data)

    model.check_battery(black_hole_data, entity, event)

    model.update_stage(black_hole_data)

    model.make_stage_picture(black_hole_data, entity)

    model.apply_output(black_hole_data)

end


function model.update_mass(black_hole_data, entity)

    if black_hole_data.stage == 0 and black_hole_data.stage_progress == 0 then
        return
    end

    local inv = entity.get_inventory(defines.inventory.chest)
    -- Most black holes spend long stretches empty, so skip the contents walk entirely in
    -- the common steady-state case.
    if not inv or inv.is_empty() then
        return
    end

    local mass_gain = 0
    local items = inv.get_contents()
    for _, item in ipairs(items) do
        mass_gain = mass_gain + item.count
    end

    if mass_gain <= 0 then
        return
    end

    black_hole_data.mass = black_hole_data.mass + mass_gain
    inv.clear()

    -- game.print("Black hole mass: "..storage.ei.black_hole[unit].mass)

end


function model.update_battery(black_hole_data)

    local battery = 0
    local cache_dirty = false

    -- Battery now derives from cached injector refs rather than a fresh surface scan.
    for _, injector in ipairs(black_hole_data.injectors) do
        if injector and injector.valid then
            if not injector.disabled_by_control_behavior and injector.energy > INJECTOR_MIN_ENERGY then
                battery = battery + 1
            end
        else
            cache_dirty = true
        end
    end

    black_hole_data.battery = battery
    black_hole_data.cached_active_injector_count = battery
    if cache_dirty then
        black_hole_data.cache_dirty = true
    end

    -- game.print("Black hole battery: "..storage.ei.black_hole[unit].battery)

end


function model.check_battery(black_hole_data, entity, event)

    if black_hole_data.stage == 0 then
        return
    end

    if black_hole_data.stage == 1 and black_hole_data.stage_progress == 0 then
        return
    end

    -- if battery less then 8 then reset the stage and stage progress
    -- and print warning

    if black_hole_data.battery < 8 then
        black_hole_data.stage = 0
        black_hole_data.stage_progress = 0
        ei_lib.crystal_echo_floating("WARNING: Black hole containment failure!",entity,6000,nil)

        -- also print chat message
        ei_lib.notify_connected_players(
            "black_hole",
            "WARNING: Black hole containment failure at "..entity.position.x..", "..entity.position.y.."!",
            {mode = "crystal_echo", font = "default-bold"}
        )
    end

end


function model.make_energy(black_hole_data, event)
    if not black_hole_data or not event then
        log("ei blackhole make_energy passed nil unit or event")
        return
    end
    -- calc energy radiated away per second

    local mass = black_hole_data.mass

    if mass < 0 then
        mass = 0
    end

    local energy = mass * 0.1
    local mass_loss = math.floor(mass * 0.005)

    if mass_loss < 1 then
        mass_loss = 1
    end

    if mass - mass_loss < 0 then
        mass_loss = 0
    end
    
    black_hole_data.mass = mass - mass_loss
    local energy = energy + mass_loss * 25 -- in GW

    -- safe this value if its 30 ticks after last save
    local tick = event.tick
    if tick - black_hole_data.last_tick > 30 then
        black_hole_data.energy_last = black_hole_data.energy
        black_hole_data.last_tick = tick
    end

    black_hole_data.energy = energy / 100 -- energy generated in this tick in GJ
    -- *60 to get power output in GW

    -- game.print("Black hole energy: "..storage.ei.black_hole[unit].energy.." GW")

end


function model.make_output(black_hole_data)

    -- calc energy output

    local energy = black_hole_data.energy
    local energy_last = black_hole_data.energy_last

    local energy_out = (energy + energy_last) / 2

    black_hole_data.energy_out = energy_out

    -- game.print("Black hole energy out: "..storage.ei.black_hole[unit].energy_out.." GW")

end


function model.apply_output(black_hole_data)

    local power_out = black_hole_data.energy_out -- in GJ per tick
    local cache_dirty = false
    local stage_is_active = black_hole_data.stage == 2

    if not stage_is_active then
        -- Leaving stage 2 is when we need to zero/disable extractors. Avoid repeating the
        -- same writes every tick once the cached set is already in the correct state.
        if black_hole_data.output_stage_active or black_hole_data.extractor_state_dirty then
            for _, extractor in ipairs(black_hole_data.extractors) do
                if extractor and extractor.valid then
                    if extractor.energy ~= 0 then
                        extractor.energy = 0
                    end
                    if extractor.active then
                        extractor.active = false
                    end
                else
                    cache_dirty = true
                end
            end
            black_hole_data.extractor_state_dirty = false
        end

        black_hole_data.output_stage_active = false
        if cache_dirty then
            black_hole_data.cache_dirty = true
        end
        return
    end

    -- Active output still updates every tick, but it walks the cached extractor refs
    -- instead of rediscovering pylons in the world first.
    for _, extractor in ipairs(black_hole_data.extractors) do
        if extractor and extractor.valid then
            -- a single extractor can extract 100GJ/s == 100GJ/60 ticks
            if power_out * 60 > 100 then
                extractor.energy = extractor.energy + 100 * GIGA / 60
                power_out = power_out - 100 / 60
            else
                extractor.energy = extractor.energy + GIGA * power_out
                power_out = 0
            end

            if not extractor.active then
                extractor.active = true
            end
        else
            cache_dirty = true
        end
    end

    black_hole_data.output_stage_active = true
    black_hole_data.extractor_state_dirty = false
    if cache_dirty then
        black_hole_data.cache_dirty = true
    end

end


function model.update_stage(black_hole_data)

    -- stage progess of 0 means stage before is completed, but button for next stage is not pressed yet
    -- button press sets progress to 1

    if black_hole_data.stage == 0 then

        if black_hole_data.stage_progress > 0 then

            -- 1000 mass is needed to get to stage 1
            if black_hole_data.mass >= 1000 then
                black_hole_data.stage = 1
                black_hole_data.stage_progress = 0
            else
                black_hole_data.stage_progress = black_hole_data.mass / 1000 * 100
            end

        end

    end

    if black_hole_data.stage == 1 then

        if black_hole_data.stage_progress > 0 then

            -- machine needs to run with 8 pylons active (40 GW in) for 1 minute
            -- so here count stageprogess in ticks

            if black_hole_data.stage_progress < 3600 then
                black_hole_data.stage_progress = black_hole_data.stage_progress + 1
            else
                black_hole_data.stage = 2
                black_hole_data.stage_progress = 0

                model.invoke_victory(black_hole_data)
            end

        end

    end

    -- nothing to do for stage 2
    -- game.print("stage: "..storage.ei.black_hole[unit].stage)
    -- game.print("stage progress: "..storage.ei.black_hole[unit].stage_progress)

end


function model.make_stage_picture(black_hole_data, entity)

    local stage = black_hole_data.stage
    local overlay = black_hole_data.overlay

    if overlay and not overlay.valid then
        overlay = nil
        black_hole_data.overlay = nil
    end

    -- for stage 0 noting to do
    
    if stage == 0 then
        if overlay ~= nil then
            overlay.destroy()
            black_hole_data.overlay = nil
        end
        black_hole_data.last_overlay_stage = stage
        black_hole_data.last_overlay_frame = nil
        return
    end

    if stage == 1 then
        -- draw an overlay according to the current stage progress, the overlay has 36 frames total
        local progress = black_hole_data.stage_progress
        -- max progress is 3600 ticks, so 1 new frame every 100 ticks

        local frame = math.floor(progress / 100)
        if frame > 35 then
            frame = 35
        end

        -- Rendering property writes are not free, so only touch the overlay when the
        -- visible frame actually changes.
        if black_hole_data.last_overlay_stage == stage
           and black_hole_data.last_overlay_frame == frame
           and overlay ~= nil then
            return
        end

        if overlay == nil then
            overlay = rendering.draw_animation{
                animation = "ei-black-hole_growing",
                target = entity,
                surface = entity.surface,
                render_layer = "object",
                animation_speed = 0,
                animation_offset = frame,
                x_scale = 1,
                y_scale = 1,
            }
        else
            if black_hole_data.last_overlay_stage ~= stage then
                overlay.animation = "ei-black-hole_growing"
                overlay.animation_speed = 0
            end
            overlay.animation_offset = frame
        end

        black_hole_data.overlay = overlay
        black_hole_data.last_overlay_stage = stage
        black_hole_data.last_overlay_frame = frame
        return
    end

    if black_hole_data.last_overlay_stage == stage and overlay ~= nil then
        return
    end

    if overlay == nil then
        overlay = rendering.draw_animation{
            animation = "ei-black-hole_glowing",
            target = entity,
            surface = entity.surface,
            render_layer = "object",
            x_scale = 1,
            y_scale = 1,
            animation_speed = 0.3,
        }
    else
        overlay.animation = "ei-black-hole_glowing"
        overlay.animation_speed = 0.3
    end

    black_hole_data.overlay = overlay
    black_hole_data.last_overlay_stage = stage
    black_hole_data.last_overlay_frame = nil

end


function model.invoke_victory(black_hole_data)

    -- get force of black hole and check if this force has achieved victory
    -- if no give victory to this force

    local force = black_hole_data.entity.force

    if not storage.ei.victory then
        storage.ei.victory = {}
    end

    if storage.ei.victory[force.name] == true then
        return
    end

    storage.ei.victory[force.name] = true

    ei_victory.add_interface()
	game.reset_game_state()
	game.enable_galaxy_of_fame_button = true
	game.set_game_state({
		game_finished = true,
		player_won = true,
		can_continue = true,
		victorious_force = force,
	})
    if remote.interfaces["better-victory-screen"] and remote.interfaces["better-victory-screen"]["trigger_victory"] then
        remote.call("better-victory-screen", "trigger_victory", force)
    end
    -- else
    --     game.set_game_state{game_finished = true, player_won = true, can_continue = true, victorious_force = force}
    -- end
end


--REGISTERS
------------------------------------------------------------------------------------------------------

function model.register_black_hole(entity, event)
    if model.entity_check(entity) == false or entity.name ~= BLACK_HOLE_NAME then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    model.check_init(unit_number)

    -- register this black hole
    local black_hole_data = storage.ei.black_hole[unit_number]
    black_hole_data.entity = entity
    black_hole_data.mass = 0
    black_hole_data.battery = 0       -- energy for containement field (multiple of 5GW)
    black_hole_data.energy = 0
    black_hole_data.energy_last = 0
    black_hole_data.last_tick = event.tick
    black_hole_data.energy_out = 0 -- mean of energy values
    black_hole_data.stage = 0
    black_hole_data.stage_progress = 0 -- max 100

    -- spawn the animation in
    local animation = rendering.draw_animation{
        animation = "ei-black-hole_animation",
        target = entity,
        surface = entity.surface,
        render_layer = "object",
        x_scale = 1,
        y_scale = 1,
    }

    black_hole_data.animation = animation
    black_hole_data.overlay = nil
    black_hole_data.last_overlay_frame = nil

    model.ensure_runtime_defaults(black_hole_data, event)
    black_hole_data.cache_dirty = true
    model.refresh_nearby_pylons(black_hole_data, entity, event, true)

end


function model.rebuild_runtime_state(reason, event_or_tick)
    -- Init/config repair must not reset active black holes. It only reconnects live
    -- entities to storage, recreates missing visuals, and drops stale serialized refs.
    local _ = reason
    model.check_init()

    local tick = 0
    if type(event_or_tick) == "table" then
        tick = event_or_tick.tick or 0
    elseif type(event_or_tick) == "number" then
        tick = event_or_tick
    elseif game then
        tick = game.tick
    end
    local event = {tick = tick}
    local seen_units = {}

    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = BLACK_HOLE_NAME}) do
            local unit_number = get_entity_unit_number(entity)
            if unit_number then
                seen_units[unit_number] = true
                if not storage.ei.black_hole[unit_number] then
                    model.register_black_hole(entity, event)
                else
                    local black_hole_data = storage.ei.black_hole[unit_number]
                    black_hole_data.entity = entity
                    black_hole_data.mass = black_hole_data.mass or 0
                    black_hole_data.battery = black_hole_data.battery or 0
                    black_hole_data.energy = black_hole_data.energy or 0
                    black_hole_data.energy_last = black_hole_data.energy_last or 0
                    black_hole_data.last_tick = black_hole_data.last_tick or tick
                    black_hole_data.energy_out = black_hole_data.energy_out or 0
                    black_hole_data.stage = black_hole_data.stage or 0
                    black_hole_data.stage_progress = black_hole_data.stage_progress or 0
                    model.ensure_runtime_defaults(black_hole_data, event)
                    ensure_black_hole_animation(black_hole_data, entity)
                    black_hole_data.cache_dirty = true
                    model.refresh_nearby_pylons(black_hole_data, entity, event, true)
                end
            end
        end
    end

    for unit_number, black_hole_data in pairs(storage.ei.black_hole) do
        if not seen_units[unit_number] then
            destroy_render_object(black_hole_data.animation)
            destroy_render_object(black_hole_data.overlay)
            storage.ei.black_hole[unit_number] = nil
        end
    end
end


function model.unregister_black_hole(entity, transfer)
    if model.entity_check(entity) == false or entity.name ~= BLACK_HOLE_NAME then
        return
    end

    if not model.transfer_valid(entity, transfer) then
        return
    end

    model.check_init()

    -- unregister this black hole
    local unit_number = get_entity_unit_number(entity)
    if unit_number then
        storage.ei.black_hole[unit_number] = nil
    end

end


function model.built_injector_pylon(entity)
    if entity.name ~= ENERGY_INJECTOR_NAME then
        return
    end

    model.mark_nearby_black_holes_dirty(entity)
end


function model.built_extractor_pylon(entity)
    if entity.name ~= ENERGY_EXTRACTOR_NAME then
        return
    end

    model.mark_nearby_black_holes_dirty(entity)
end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(event)
    local entity = event.entity
    if model.entity_check(entity) == false then
        return
    end

    model.register_black_hole(entity, event)

    model.built_injector_pylon(entity)

    model.built_extractor_pylon(entity)

end


function model.on_destroyed_entity(entity, transfer)
    if entity.name == ENERGY_INJECTOR_NAME or entity.name == ENERGY_EXTRACTOR_NAME then
        model.mark_nearby_black_holes_dirty(entity)
        return
    end

    model.unregister_black_hole(entity, transfer)

end


function model.has_tick_work(_event)
    local black_holes = storage and storage.ei and storage.ei.black_hole or nil
    if type(black_holes) == "table" and next(black_holes) ~= nil then
        return true
    end

    if game and type(game.connected_players) == "table" then
        for _, player in pairs(game.connected_players) do
            if player.gui
                and player.gui.relative
                and player.gui.relative["ei-black-hole-console"]
            then
                return true
            end
        end
    end

    return false
end


function model.update(event)
    local tick = event.tick
    model.update_black_holes(event)
    if tick % BLACK_HOLE_GUI_REFRESH_TICKS == 0 then
        model.update_player_guis()
    end

end


--GUI related
------------------------------------------------------------------------------------------------------

-- WHAT NEEDS GUI TO DO
-- show: current mass, energy produced last tick, energy injector pylons in range, energy extractor pylons in range
-- show: current stage, stage progress

-- Button: start next stage (only if stage progress = 0, sets stage progress to 1)

-- everything related to the black hole is stored in storage.ei.black_hole[unit], here unit is the unit number of the black hole entity (container)

-- ===== GETTERS =====

function model.get_mass(unit)
    -- mass stored in the black hole

    model.check_init(unit)

    return storage.ei.black_hole[unit].mass

end


function model.get_power(unit)
    -- energy produced last second

    model.check_init(unit)

    return storage.ei.black_hole[unit].energy*60 -- in GW

end


function model.get_injector_pylons_in_range(unit)
    -- number of pylons in range

    model.check_init(unit)

    local black_hole_data = storage.ei.black_hole[unit]
    model.ensure_runtime_defaults(black_hole_data)

    -- GUI reads the same cached value the runtime uses, so opening the console does not
    -- trigger extra world scans.
    return black_hole_data.cached_active_injector_count or 0

end


function model.get_extractor_pylons_in_range(unit)
    -- number of pylons in range

    model.check_init(unit)

    local black_hole_data = storage.ei.black_hole[unit]
    model.ensure_runtime_defaults(black_hole_data)

    -- Extractor count is cached for the same reason as injectors: GUI updates should stay
    -- read-only from the world's perspective.
    return black_hole_data.cached_extractor_count or 0

end


function model.get_stage(unit)
    -- current stage

    model.check_init(unit)

    return storage.ei.black_hole[unit].stage

end


function model.get_stage_progress(unit)
    -- current stage progress

    model.check_init(unit)

    return storage.ei.black_hole[unit].stage_progress

end


function model.get_relative_stage_progress(unit)
    -- get stage progress relative to max amaount for current stage
    -- returns values between 0 and 100

    model.check_init(unit)

    local stage = storage.ei.black_hole[unit].stage
    local progress = storage.ei.black_hole[unit].stage_progress

    if stage == 0 then
        return progress
    end

    if stage == 1 then
        return progress / 3600 * 100
    end

    if stage == 2 then
        return 0
    end
    
end

-- ===== SETTERS =====

function model.set_stage_progress(unit, value)
    -- current stage progress, use 1 to startup next stage

    model.check_init(unit)

    storage.ei.black_hole[unit].stage_progress = value

end


--GUI
------------------------------------------------------------------------------------------------------

function model.open_gui(player)

    if player.gui.relative["ei-black-hole-console"] then
        model.close_gui(player)
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-black-hole-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-black-hole",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.black-hole-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_nondraggable_spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-black-hole-console",
                action = "goto-informatron",
                page = "black_hole"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do -- Status subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.black-hole-gui-status-title"},
            style = "subheader_caption_label",
        }
    
        local status_flow = main_container.add{
            type = "flow",
            name = "status-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        status_flow.add{
            type = "label",
            name = "mass",
            caption = {"exotic-industries.black-hole-gui-status-mass", 0},
            tooltip = {"exotic-industries.black-hole-gui-status-mass-tooltip"},
        }

        status_flow.add{
            type = "label",
            name = "power",
            caption = {"exotic-industries.black-hole-gui-status-power", 0},
            tooltip = {"exotic-industries.black-hole-gui-status-power-tooltip"},
        }

        status_flow.add{
            type = "progressbar",
            name = "injectors",
            caption = {"exotic-industries.black-hole-gui-status-injectors", 0},
            style = "ei_status_progressbar_red"
        }

        status_flow.add{
            type = "progressbar",
            name = "extractors",
            caption = {"exotic-industries.black-hole-gui-status-extractors", 0},
            style = "ei_status_progressbar_grey"
        }
    end

    do -- Control

        main_container.add{
            type = "frame",
            style = "ei_subheader_frame_with_top_border",
        }.add{
            type = "label",
            caption = {"exotic-industries.black-hole-gui-control-title"},
            style = "subheader_caption_label",
        }

        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        control_flow.add{
            type = "progressbar",
            name = "stage",
            caption = {"exotic-industries.black-hole-gui-control-stage", 0},
            style = "ei_status_progressbar"
        }

        control_flow.add{
            type = "progressbar",
            name = "stage-progress",
            caption = {"exotic-industries.black-hole-gui-control-stage-progress", 0},
            style = "ei_status_progressbar_grey"
        }

        control_flow.add{
            type = "button",
            name = "control-button",
            caption = {"exotic-industries.black-hole-gui-control-button"},
            style = "ei_green_button",
            tags = {
                action = "control-start",
                parent_gui = "ei-black-hole-console",
            }
        }

    end

end


function model.update_player_guis()

    for _, player in pairs(game.connected_players) do
        if player.gui.relative["ei-black-hole-console"] then
            local entity = get_valid_entity(player.opened)
            if not entity or entity.name ~= BLACK_HOLE_NAME then
                model.close_gui(player)
            else
                local unit = get_entity_unit_number(entity)
                if not unit then
                    model.close_gui(player)
                else
                    local data = model.get_data(unit)
                    model.update_gui(player, data)
                end
            end
        end
    end

end


function model.get_data(unit)

    local data = {}

    local injectors = model.get_injector_pylons_in_range(unit)
    local extractors = model.get_extractor_pylons_in_range(unit)
    local stage_progress = model.get_relative_stage_progress(unit)
    local stage = model.get_stage(unit)

    data.mass = model.get_mass(unit)
    data.power = model.get_power(unit)

    -- adjust power for stages
    if stage ~= 2 then
        data.power = 0
    end


    -- injector progressbar
    data.injectors = {}
    data.injectors.caption = injectors
    data.injectors.value = injectors / 8
    data.injectors.max = 8

    if stage == 0 then
        data.injectors.value = 1 -- no injectors needed at stage 0
        data.injectors.max = 0
    end

    if data.injectors.value > 1 then
        data.injectors.value = 1
    end


    -- extractor progressbar
    data.extractors = {}
    data.extractors.caption = extractors
    data.extractors.max = 0

    if data.power == 0 then
        data.extractors.value = 1
        data.extractors.max = 0
        data.extractors.caption = 0
    end

    if data.power > 0 then
        data.extractors.value = extractors * 100 / data.power
        data.extractors.max = math.floor(data.power / 100 + 0.5)
    end

    if data.extractors.value > 1 then
        data.extractors.value = 1
    end


    -- stage progressbar
    data.stage_progress = {}
    data.stage_progress.caption = stage_progress
    data.stage_progress.value = stage_progress/100

    data.stage = {}
    data.stage.caption = stage
    data.stage.value = stage/2

    if stage_progress > 0 then
        data.stage.value = data.stage.value + 0.25
    end

    if data.stage.value > 1 then
        data.stage.value = 1
    end


    -- control button
    data.control_button = 1

    if stage == 0 and stage_progress == 0 then
        data.control_button = 1
    elseif stage == 0 and stage_progress > 0 then
        data.control_button = 2
    elseif stage == 1 and stage_progress == 0 then
        data.control_button = 3
    elseif stage == 1 and stage_progress > 0 then
        data.control_button = 4
    elseif stage == 2 and stage_progress == 0 then
        data.control_button = 5
    elseif stage == 2 and stage_progress > 0 then
        data.control_button = 5 -- should not be possible
    end

    return data

end


function model.update_gui(player, data)

    local root = player.gui.relative["ei-black-hole-console"]
    local status = root["main-container"]["status-flow"]
    local control = root["main-container"]["control-flow"]

    local mass = status["mass"]
    local power = status["power"]
    local injectors = status["injectors"]
    local extractors = status["extractors"]

    local stage = control["stage"]
    local stage_progress = control["stage-progress"]
    local control_button = control["control-button"]

    -- Update status
    mass.caption = {"exotic-industries.black-hole-gui-status-mass", string.format("%.1f", data.mass/100)}
    power.caption = {"exotic-industries.black-hole-gui-status-power", string.format("%.1f", data.power)} -- in GW

    injectors.caption = {"exotic-industries.black-hole-gui-status-injectors", data.injectors.caption, data.injectors.max}
    injectors.value = data.injectors.value
    if data.injectors.value == 1 then
        injectors.style = "ei_status_progressbar"
    else
        injectors.style = "ei_status_progressbar_red"
    end

    extractors.caption = {"exotic-industries.black-hole-gui-status-extractors", data.extractors.caption, data.extractors.max}
    extractors.value = data.extractors.value

    -- Update control
    stage.caption = {"exotic-industries.black-hole-gui-control-stage", data.stage.caption}
    stage.value = data.stage.value

    stage_progress.caption = {"exotic-industries.black-hole-gui-control-stage-progress", string.format("%.1f", data.stage_progress.caption)}
    stage_progress.value = data.stage_progress.value

    -- Update control button
    if data.control_button == 1 then
        control_button.caption = {"exotic-industries.black-hole-gui-control-control-button-1"}
        control_button.style = "ei_green_button"
    elseif data.control_button == 2 then
        control_button.caption = {"exotic-industries.black-hole-gui-control-control-button-2"}
        control_button.style = "ei_button"
    elseif data.control_button == 3 then
        control_button.caption = {"exotic-industries.black-hole-gui-control-control-button-3"}
        control_button.style = "ei_green_button"
    elseif data.control_button == 4 then
        control_button.caption = {"exotic-industries.black-hole-gui-control-control-button-4"}
        control_button.style = "ei_button"
    elseif data.control_button == 5 then
        control_button.caption = {"exotic-industries.black-hole-gui-control-control-button-5"}
        control_button.style = "ei_button"
    end



end


function model.change_stage(player)

    local entity = get_valid_entity(player and player.opened)
    if not entity or entity.name ~= BLACK_HOLE_NAME then
        return
    end

    local unit = get_entity_unit_number(entity)
    if not unit then
        return
    end

    -- if stage progress > 0, do nothing
    if model.get_stage_progress(unit) > 0 then
        return
    end

    -- otherwise set it to 1
    model.set_stage_progress(unit, 1)

end


function model.on_gui_click(event)
    if event.element.tags.action == "control-start" then
        model.change_stage(game.get_player(event.player_index))
    end
end


function model.close_gui(player)
    if player.gui.relative["ei-black-hole-console"] then
        player.gui.relative["ei-black-hole-console"].destroy()
    end
end


function model.on_gui_opened(event)
    model.open_gui(game.get_player(event.player_index))
end

function model.get_runtime_status()
    model.check_init()

    local black_hole_count = 0
    local cache_dirty_count = 0
    local extractor_state_dirty_count = 0
    local output_stage_active_count = 0
    local stage_two_count = 0

    for _, black_hole_data in pairs(storage.ei.black_hole or {}) do
        if black_hole_data then
            black_hole_count = black_hole_count + 1
            if black_hole_data.cache_dirty then
                cache_dirty_count = cache_dirty_count + 1
            end
            if black_hole_data.extractor_state_dirty then
                extractor_state_dirty_count = extractor_state_dirty_count + 1
            end
            if black_hole_data.output_stage_active then
                output_stage_active_count = output_stage_active_count + 1
            end
            if black_hole_data.stage == 2 then
                stage_two_count = stage_two_count + 1
            end
        end
    end

    local status = {
        black_hole_count = black_hole_count,
        cache_dirty_count = cache_dirty_count,
        extractor_state_dirty_count = extractor_state_dirty_count,
        output_stage_active_count = output_stage_active_count,
        stage_two_count = stage_two_count,
        entries = black_hole_count,
    }

    ei_runtime_scheduler.set_module_status("black-hole", status)
    return status
end

return model
