local REPORT_PATH = "scripted-research-qc.txt"
local MAIN_SURFACE_NAME = "scripted-research-main"
local AUX_SURFACE_NAME = "scripted-research-aux"
local SURFACE_NAMES = {
    MAIN_SURFACE_NAME,
    AUX_SURFACE_NAME,
}
local BUILD_AREA = {
    left_top = {x = -160, y = -96},
    right_bottom = {x = 160, y = 96},
}
local TESLA_BASIC_ORIGIN = {x = -120, y = -84}
local TESLA_ADVANCED_ORIGIN = {x = 20, y = -84}
local TESLA_GRID_ROWS = 8
local TESLA_GRID_COLUMNS = 8
local TESLA_GRID_STEP = 4
local RAIL_LINE_Y = {-30, -18, -6, 6, 18, 30}
local RAIL_START_X = -120
local RAIL_END_X = 120
local RAIL_STEP = 2
local CHARGER_START_X = -104
local CHARGER_END_X = 104
local CHARGER_STEP = 16
local TRAIN_START_X = -96
local TRAIN_END_X = 96
local TRAIN_STEP = 32
local EMERALD_TANK_NAME = "ei-emerald-apocalypse-hover-tank"
local EMERALD_TANK_POSITION = {x = -136, y = 74}
local RESEARCH_TRIGGER_DELAY = 10
local POST_BURST_REPORT_DELAY = 4
local QC_REMOTE = "exotic-industries-qc"

local function ensure_state()
    storage.scripted_research_qc = storage.scripted_research_qc or {}
    return storage.scripted_research_qc
end

local function write_report(contents, append)
    if log then
        local message = tostring(contents or ""):gsub("%s+$", ""):gsub("\n", " | ")
        if message ~= "" then
            log("SCRIPTED_RESEARCH_QC " .. message)
        end
    end

    if helpers and helpers.write_file then
        local ok = pcall(helpers.write_file, REPORT_PATH, contents, append and true or false, 0)
        if ok then
            return
        end
    end

    if game and game.write_file then
        local ok = pcall(game.write_file, game, REPORT_PATH, contents, append and true or false, 0)
        if ok then
            return
        end
    end
end

local function get_force()
    return game.forces.player or game.forces[1]
end

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, inner_value in pairs(value) do
        copy[deep_copy(key)] = deep_copy(inner_value)
    end
    return copy
end

local function get_surface_map_gen_settings()
    local base_surface = game.surfaces["nauvis"] or game.surfaces[1]
    if base_surface and base_surface.valid and base_surface.map_gen_settings then
        return deep_copy(base_surface.map_gen_settings)
    end

    return deep_copy(game.default_map_gen_settings)
end

local function ensure_surface(name)
    local existing = game.surfaces[name]
    if existing and existing.valid then
        return existing
    end

    return game.create_surface(name, get_surface_map_gen_settings())
end

local function clear_build_area(surface)
    surface.request_to_generate_chunks({0, 0}, 10)
    surface.force_generate_chunk_requests()

    local tiles = {}
    for x = BUILD_AREA.left_top.x, BUILD_AREA.right_bottom.x do
        for y = BUILD_AREA.left_top.y, BUILD_AREA.right_bottom.y do
            tiles[#tiles + 1] = {
                name = "grass-1",
                position = {x = x, y = y},
            }
        end
    end

    surface.set_tiles(tiles, true)
    surface.destroy_decoratives({area = BUILD_AREA})

    for _, entity in pairs(surface.find_entities_filtered({area = BUILD_AREA})) do
        if entity.valid and entity.type ~= "character" then
            entity.destroy({raise_destroy = false})
        end
    end
end

local function place_entity(surface, definition)
    definition.create_build_effect_smoke = false
    local entity = surface.create_entity(definition)
    if entity and entity.valid and entity.energy then
        entity.energy = math.max(entity.energy, 1000000000)
    end
    return entity
end

local function build_tesla_grid(surface, force)
    local basic = 0
    local advanced = 0

    for row = 0, TESLA_GRID_ROWS - 1 do
        for column = 0, TESLA_GRID_COLUMNS - 1 do
            local basic_entity = place_entity(surface, {
                name = "tl-basic-tesla-coil",
                position = {
                    x = TESLA_BASIC_ORIGIN.x + column * TESLA_GRID_STEP,
                    y = TESLA_BASIC_ORIGIN.y + row * TESLA_GRID_STEP,
                },
                force = force,
                raise_built = true,
            })
            if basic_entity then
                basic = basic + 1
            end

            local advanced_entity = place_entity(surface, {
                name = "tl-advanced-tesla-coil",
                position = {
                    x = TESLA_ADVANCED_ORIGIN.x + column * TESLA_GRID_STEP,
                    y = TESLA_ADVANCED_ORIGIN.y + row * TESLA_GRID_STEP,
                },
                force = force,
                raise_built = true,
            })
            if advanced_entity then
                advanced = advanced + 1
            end
        end
    end

    return basic, advanced
end

local function build_em_layout(surface, force)
    local rail_count = 0
    local charger_count = 0
    local train_count = 0

    for _, line_y in ipairs(RAIL_LINE_Y) do
        for x = RAIL_START_X, RAIL_END_X, RAIL_STEP do
            local rail = surface.create_entity({
                name = "straight-rail",
                position = {x = x, y = line_y},
                direction = defines.direction.east,
                force = force,
                create_build_effect_smoke = false,
            })
            if rail then
                rail_count = rail_count + 1
            end
        end

        for x = CHARGER_START_X, CHARGER_END_X, CHARGER_STEP do
            local charger = place_entity(surface, {
                name = "ei_charger",
                position = {x = x, y = line_y - 4},
                force = force,
                raise_built = true,
            })
            if charger then
                charger_count = charger_count + 1
            end
        end

        for x = TRAIN_START_X, TRAIN_END_X, TRAIN_STEP do
            local train = place_entity(surface, {
                name = "ei_em-locomotive",
                position = {x = x, y = line_y},
                direction = defines.direction.east,
                force = force,
                raise_built = true,
            })
            if train then
                train_count = train_count + 1
            end
        end
    end

    return rail_count, charger_count, train_count
end

local function build_emerald_layout(surface, force)
    local ok, tank = pcall(function()
        return surface.create_entity({
            name = EMERALD_TANK_NAME,
            position = EMERALD_TANK_POSITION,
            direction = defines.direction.east,
            force = force,
            create_build_effect_smoke = false,
            raise_built = true,
        })
    end)

    if ok and tank and tank.valid then
        return 1
    end

    return 0
end

local function rebuild_runtime()
    if remote.interfaces[QC_REMOTE] and remote.interfaces[QC_REMOTE].rebuild_scripted_research_runtime then
        remote.call(QC_REMOTE, "rebuild_scripted_research_runtime")
    elseif remote.interfaces[QC_REMOTE] and remote.interfaces[QC_REMOTE].rebuild_research_hitch_runtime then
        remote.call(QC_REMOTE, "rebuild_research_hitch_runtime")
    end
end

local function get_esir_qc_snapshot()
    if not remote.interfaces[QC_REMOTE] or not remote.interfaces[QC_REMOTE].get_research_hitch_qc_snapshot then
        return nil
    end

    local ok, snapshot = pcall(function()
        return remote.call(QC_REMOTE, "get_research_hitch_qc_snapshot")
    end)
    if ok and type(snapshot) == "table" then
        return snapshot
    end

    return nil
end

local function append_post_burst_report(current_tick)
    local snapshot = get_esir_qc_snapshot()
    if type(snapshot) ~= "table" then
        write_report(
            "post_burst_tick=" .. tostring(current_tick)
                .. "\nqc_snapshot=unavailable\n",
            true
        )
        return
    end

    local burst = type(snapshot.scripted_research_burst) == "table" and snapshot.scripted_research_burst or {}
    local emerald = type(snapshot.emerald_apocalypse_hover_tank) == "table"
        and snapshot.emerald_apocalypse_hover_tank
        or {}
    local shards = type(emerald.orbital_shards) == "table" and emerald.orbital_shards or {}

    write_report(
        "post_burst_tick=" .. tostring(current_tick)
            .. "\npending_force_count=" .. tostring(burst.pending_force_count or 0)
            .. "\nnext_due_tick=" .. tostring(burst.next_due_tick or 0)
            .. "\nemerald_shard_records=" .. tostring(shards.shard_records or 0)
            .. "\nemerald_shard_force_cache_count=" .. tostring(shards.shard_force_cache_count or 0)
            .. "\nemerald_shard_laser_7_levels=" .. tostring(shards.shard_current_laser_7_levels or 0)
            .. "\nemerald_shard_multiplier=" .. tostring(shards.shard_current_multiplier or 0)
            .. "\nemerald_shard_swarm_dps=" .. tostring(shards.shard_current_swarm_dps or 0)
            .. "\nemerald_shard_quality_multiplier=" .. tostring(shards.shard_current_quality_multiplier or 1)
            .. "\nemerald_shard_effective_swarm_dps=" .. tostring(shards.shard_current_effective_swarm_dps or 0)
            .. "\n",
        true
    )
end

local function prepare_world(reason)
    local state = ensure_state()
    if state.prepared then
        return
    end

    local force = get_force()
    if not force then
        return
    end

    local lines = {
        "prepare:" .. tostring(reason),
    }
    local total_basic = 0
    local total_advanced = 0

    for _, surface_name in ipairs(SURFACE_NAMES) do
        local surface = ensure_surface(surface_name)
        clear_build_area(surface)
        local basic_count, advanced_count = build_tesla_grid(surface, force)
        total_basic = total_basic + basic_count
        total_advanced = total_advanced + advanced_count
        lines[#lines + 1] = surface_name .. ":basic=" .. tostring(basic_count) .. ",advanced=" .. tostring(advanced_count)
    end

    local main_surface = game.surfaces[MAIN_SURFACE_NAME]
    local rail_count, charger_count, train_count = build_em_layout(main_surface, force)
    local emerald_tank_count = build_emerald_layout(main_surface, force)
    lines[#lines + 1] = "em:rails=" .. tostring(rail_count)
        .. ",chargers=" .. tostring(charger_count)
        .. ",trains=" .. tostring(train_count)
    lines[#lines + 1] = "emerald:tanks=" .. tostring(emerald_tank_count)

    rebuild_runtime()

    state.prepared = true
    state.trigger_tick = (game.tick or 0) + RESEARCH_TRIGGER_DELAY
    state.fired = false
    state.awaiting_flush_report = false
    state.report_tick = 0

    lines[#lines + 1] = "tesla_basic=" .. tostring(total_basic)
    lines[#lines + 1] = "tesla_advanced=" .. tostring(total_advanced)
    lines[#lines + 1] = "trigger_tick=" .. tostring(state.trigger_tick)
    write_report(table.concat(lines, "\n") .. "\n", false)
end

script.on_init(function()
    prepare_world("init")
end)

script.on_configuration_changed(function()
    local state = ensure_state()
    if not state.prepared then
        prepare_world("configuration-changed")
        return
    end

    rebuild_runtime()
    write_report("rebuild:configuration-changed\n", true)
end)

script.on_event(defines.events.on_tick, function(event)
    local state = ensure_state()
    if not state.prepared then
        return
    end

    if state.fired then
        if state.awaiting_flush_report and event.tick >= (state.report_tick or 0) then
            append_post_burst_report(event.tick)
            state.awaiting_flush_report = false
        end
        return
    end

    if event.tick < (state.trigger_tick or RESEARCH_TRIGGER_DELAY) then
        return
    end

    local force = get_force()
    if not force then
        return
    end

    force.research_all_technologies()
    state.fired = true
    state.awaiting_flush_report = true
    state.report_tick = event.tick + POST_BURST_REPORT_DELAY

    local researched_count = 0
    for _, technology in pairs(force.technologies) do
        if technology and technology.researched then
            researched_count = researched_count + 1
        end
    end

    write_report(
        "burst_tick=" .. tostring(event.tick)
            .. "\nresearched_count=" .. tostring(researched_count)
            .. "\npost_burst_report_tick=" .. tostring(state.report_tick)
            .. "\n",
        true
    )
end)
