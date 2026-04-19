require("util")

local REPORT_PATH = "research-hitch-qc.txt"
local MAIN_SURFACE_NAME = "research-hitch-a"
local SURFACE_NAMES = {
    MAIN_SURFACE_NAME,
    "research-hitch-b",
    "research-hitch-c",
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
local RESEARCH_COMPLETE_INTERVAL = 60

local TARGET_ORDER = {"charger", "tesla", "acceleration", "speed"}
local TARGET_GROUPS = {
    tesla = {
        "ei-exotic-waveform-convergence",
        "ei-reactance-overdrive-3",
        "ei-bridge-coupling-2",
        "ei-dielectric-rupture-3",
        "ei-storm-lattice-3",
        "ei-waveform-harmonics-3",
    },
    charger = {"ei_eff_5", "ei_eff_4", "ei_eff_3", "ei_eff_2", "ei_eff_1"},
    acceleration = {
        "ei_acc_20", "ei_acc_19", "ei_acc_18", "ei_acc_17", "ei_acc_16",
        "ei_acc_15", "ei_acc_14", "ei_acc_13", "ei_acc_12", "ei_acc_11",
        "ei_acc_10", "ei_acc_9", "ei_acc_8", "ei_acc_7", "ei_acc_6",
        "ei_acc_5", "ei_acc_4", "ei_acc_3", "ei_acc_2", "ei_acc_1",
    },
    speed = {
        "ei_spd_20", "ei_spd_19", "ei_spd_18", "ei_spd_17", "ei_spd_16",
        "ei_spd_15", "ei_spd_14", "ei_spd_13", "ei_spd_12", "ei_spd_11",
        "ei_spd_10", "ei_spd_9", "ei_spd_8", "ei_spd_7", "ei_spd_6",
        "ei_spd_5", "ei_spd_4", "ei_spd_3", "ei_spd_2", "ei_spd_1",
    },
}

local function ensure_state()
    storage.research_hitch_qc = storage.research_hitch_qc or {}
    return storage.research_hitch_qc
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

local function get_force()
    return game.forces.player or game.forces[1]
end

local function get_surface_map_gen_settings()
    local base_surface = game.surfaces["nauvis"] or game.surfaces[1]
    if base_surface and base_surface.valid and base_surface.map_gen_settings then
        return table.deepcopy(base_surface.map_gen_settings)
    end

    return table.deepcopy(game.default_map_gen_settings)
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

local function pick_target_researches(force)
    local selected = {}
    local used = {}

    for _, group_name in ipairs(TARGET_ORDER) do
        for _, candidate in ipairs(TARGET_GROUPS[group_name]) do
            local technology = force.technologies[candidate]
            if technology and technology.enabled and not used[candidate] then
                selected[group_name] = candidate
                used[candidate] = true
                break
            end
        end
    end

    return selected
end

local function set_bulk_research_state(force, selected)
    local skipped = {}
    local researched_count = 0

    for _, technology_name in pairs(selected) do
        skipped[technology_name] = true
    end

    for technology_name, technology in pairs(force.technologies) do
        if technology.enabled and not skipped[technology_name] then
            local ok = pcall(function()
                technology.researched = true
            end)
            if ok and technology.researched then
                researched_count = researched_count + 1
            end
        end
    end

    for _, technology_name in pairs(selected) do
        local technology = force.technologies[technology_name]
        if technology then
            pcall(function()
                technology.researched = false
            end)
        end
    end

    return researched_count
end

local function queue_target_researches(force, selected)
    local queued = {}

    for _, group_name in ipairs(TARGET_ORDER) do
        local technology_name = selected[group_name]
        local technology = technology_name and force.technologies[technology_name] or nil
        if technology and technology.enabled and not technology.researched then
            local ok = pcall(function()
                force.add_research(technology_name)
            end)
            if ok then
                queued[#queued + 1] = technology_name
            end
        end
    end

    return queued
end

local function sync_main_mod_runtime()
    if not remote.interfaces["exotic-industries-qc"] then
        return false
    end

    if not remote.interfaces["exotic-industries-qc"]["rebuild_research_hitch_runtime"] then
        return false
    end

    remote.call("exotic-industries-qc", "rebuild_research_hitch_runtime")
    return true
end

local function append_runtime_snapshot(label, research_name)
    if not remote.interfaces["exotic-industries-qc"] then
        return false
    end

    if not remote.interfaces["exotic-industries-qc"]["get_research_hitch_qc_snapshot"] then
        return false
    end

    local ok, snapshot = pcall(
        remote.call,
        "exotic-industries-qc",
        "get_research_hitch_qc_snapshot"
    )
    if not ok or type(snapshot) ~= "table" then
        return false
    end

    local tech_scaling = type(snapshot.tech_scaling) == "table" and snapshot.tech_scaling or {}
    local scripted_research_burst = type(snapshot.scripted_research_burst) == "table"
        and snapshot.scripted_research_burst
        or {}
    local tesla = type(snapshot.tesla) == "table" and snapshot.tesla or {}
    local em_trains = type(snapshot.em_trains) == "table" and snapshot.em_trains or {}
    local age_totals = tech_scaling.age_totals or {}
    local age_parts = {}

    for _, age in ipairs({
        "dark-age",
        "steam-age",
        "electricity-age",
        "computer-age",
        "quantum-age",
        "exotic-age",
    }) do
        age_parts[#age_parts + 1] = age .. "=" .. tostring(tonumber(age_totals[age]) or 0)
    end

    local lines = {
        "[snapshot]",
        "label=" .. tostring(label),
        "research=" .. tostring(research_name),
        "tick=" .. tostring(snapshot.tick or 0),
        "tech_scaling.applied_multiplier=" .. tostring(tonumber(tech_scaling.applied_multiplier) or 1),
        "tech_scaling.cache_revision=" .. tostring(tonumber(tech_scaling.cache_revision) or 0),
        "tech_scaling.selected_force_key=" .. tostring(tech_scaling.selected_force_key),
        "tech_scaling.researched_total_weight=" .. tostring(tonumber(tech_scaling.researched_total_weight) or 0),
        "tech_scaling.age_totals=" .. table.concat(age_parts, ", "),
        "scripted_research_burst.pending_force_count=" .. tostring(tonumber(scripted_research_burst.pending_force_count) or 0),
        "scripted_research_burst.next_due_tick=" .. tostring(tonumber(scripted_research_burst.next_due_tick) or 0),
        "scripted_research_burst.due_bucket_count=" .. tostring(tonumber(scripted_research_burst.due_bucket_count) or 0),
        "scripted_research_burst.due_bucket_items=" .. tostring(tonumber(scripted_research_burst.due_bucket_items) or 0),
        "tesla.force_cache_count=" .. tostring(tonumber(tesla.force_cache_count) or 0),
        "tesla.variant_sync_job_count=" .. tostring(tonumber(tesla.variant_sync_job_count) or 0),
        "tesla.variant_sync_pending_job_count=" .. tostring(tonumber(tesla.variant_sync_pending_job_count) or 0),
        "tesla.variant_sync_restart_requested_count=" .. tostring(tonumber(tesla.variant_sync_restart_requested_count) or 0),
        "tesla.variant_sync_bucket_items=" .. tostring(tonumber(tesla.variant_sync_bucket_items) or 0),
        "tesla.variant_sync_last_surface_index_max=" .. tostring(tonumber(tesla.variant_sync_last_surface_index_max) or 0),
        "em_trains.charger_count=" .. tostring(tonumber(em_trains.charger_count) or 0),
        "em_trains.train_count=" .. tostring(tonumber(em_trains.train_count) or 0),
        "em_trains.research_rollout_charger_queue_items=" .. tostring(tonumber(em_trains.research_rollout_charger_queue_items) or 0),
        "em_trains.research_rollout_train_queue_items=" .. tostring(tonumber(em_trains.research_rollout_train_queue_items) or 0),
        "em_trains.research_rollout_charger_rescan_pending=" .. tostring(em_trains.research_rollout_charger_rescan_pending == true),
        "em_trains.research_rollout_train_rescan_pending=" .. tostring(em_trains.research_rollout_train_rescan_pending == true),
        "em_trains.research_rollout_charger_target_generation=" .. tostring(tonumber(em_trains.research_rollout_charger_target_generation) or 0),
        "em_trains.research_rollout_train_target_generation=" .. tostring(tonumber(em_trains.research_rollout_train_target_generation) or 0),
        "",
    }

    write_file(REPORT_PATH, table.concat(lines, "\n"), true)
    return true
end

local function queue_snapshot_request(state, tick, label, research_name)
    if not state then
        return
    end

    state.snapshot_requests = type(state.snapshot_requests) == "table" and state.snapshot_requests or {}

    local bucket = state.snapshot_requests[tick]
    if type(bucket) ~= "table" then
        bucket = {}
        state.snapshot_requests[tick] = bucket
    end

    bucket[#bucket + 1] = {
        label = label,
        research_name = research_name,
    }
end

local function capture_due_snapshots(state, tick)
    if not state or type(state.snapshot_requests) ~= "table" then
        return
    end

    local bucket = state.snapshot_requests[tick]
    if type(bucket) ~= "table" then
        return
    end

    state.snapshot_requests[tick] = nil

    for _, request in ipairs(bucket) do
        append_runtime_snapshot(request.label, request.research_name)
    end
end

local function write_report(state)
    local lines = {
        "initialized=" .. tostring(state.initialized == true),
        "queue_interval_ticks=" .. tostring(RESEARCH_COMPLETE_INTERVAL),
        "runtime_synced=" .. tostring(state.runtime_synced == true),
        "main_surface=" .. tostring(state.main_surface_name),
        "surfaces=" .. table.concat(state.surface_names or {}, ", "),
        "queued_researches=" .. table.concat(state.queued_researches or {}, ", "),
        "bulk_researched_count=" .. tostring(state.bulk_researched_count or 0),
        "rail_count=" .. tostring(state.rail_count or 0),
        "charger_count=" .. tostring(state.charger_count or 0),
        "train_count=" .. tostring(state.train_count or 0),
        "tesla_basic_count=" .. tostring(state.tesla_basic_count or 0),
        "tesla_advanced_count=" .. tostring(state.tesla_advanced_count or 0),
    }

    write_file(REPORT_PATH, table.concat(lines, "\n") .. "\n", false)
end

local function update_tick_registration()
    local state = ensure_state()
    if state.initialized then
        script.on_event(defines.events.on_tick, function(event)
            local current_state = ensure_state()
            if not current_state.initialized then
                return
            end

            capture_due_snapshots(current_state, event.tick)

            if event.tick % RESEARCH_COMPLETE_INTERVAL ~= 0 then
                return
            end

            local force = get_force()
            if not force then
                return
            end

            local current_research = force.current_research
            if not current_research then
                if current_state.research_queue_finished_tick == nil then
                    append_runtime_snapshot("queue-finished", current_state.last_completed_research)
                end
                current_state.research_queue_finished_tick = event.tick
                return
            end

            current_state.research_queue_finished_tick = nil
            append_runtime_snapshot("pre-complete", current_research.name)
            force.research_progress = 1
            current_state.last_completed_research = current_research.name
            current_state.last_completion_tick = event.tick
            append_runtime_snapshot("post-immediate", current_research.name)
            queue_snapshot_request(current_state, event.tick + 1, "post-plus-1", current_research.name)
            queue_snapshot_request(current_state, event.tick + 2, "post-plus-2", current_research.name)
        end)
    else
        script.on_event(defines.events.on_tick, nil)
    end
end

local function build_scenario()
    local state = ensure_state()
    if state.initialized then
        update_tick_registration()
        return
    end

    local force = get_force()
    if not force then
        return
    end

    local tesla_basic_total = 0
    local tesla_advanced_total = 0
    local main_surface = nil

    for _, surface_name in ipairs(SURFACE_NAMES) do
        local surface = ensure_surface(surface_name)
        if surface and surface.valid then
            clear_build_area(surface)
            local basic_count, advanced_count = build_tesla_grid(surface, force)
            tesla_basic_total = tesla_basic_total + basic_count
            tesla_advanced_total = tesla_advanced_total + advanced_count

            if surface_name == MAIN_SURFACE_NAME then
                main_surface = surface
            end
        end
    end

    if not (main_surface and main_surface.valid) then
        return
    end

    local rail_count, charger_count, train_count = build_em_layout(main_surface, force)
    local selected = pick_target_researches(force)
    local bulk_researched_count = set_bulk_research_state(force, selected)
    local queued_researches = queue_target_researches(force, selected)
    local runtime_synced = sync_main_mod_runtime()

    state.initialized = true
    state.main_surface_name = MAIN_SURFACE_NAME
    state.surface_names = table.deepcopy(SURFACE_NAMES)
    state.bulk_researched_count = bulk_researched_count
    state.queued_researches = queued_researches
    state.rail_count = rail_count
    state.charger_count = charger_count
    state.train_count = train_count
    state.tesla_basic_count = tesla_basic_total
    state.tesla_advanced_count = tesla_advanced_total
    state.runtime_synced = runtime_synced
    state.snapshot_requests = {}

    write_report(state)
    update_tick_registration()
end

script.on_init(function()
    build_scenario()
end)

script.on_configuration_changed(function()
    local state = ensure_state()
    if state.initialized then
        state.runtime_synced = sync_main_mod_runtime()
        write_report(state)
    end
    update_tick_registration()
end)

script.on_load(function()
    update_tick_registration()
end)
