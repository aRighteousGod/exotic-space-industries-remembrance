-- Staged-only native flood plus normal research trace, appended to control.lua.
do
    local previous_tick = assert(script.get_event_handler(defines.events.on_tick))
    local previous_research = assert(script.get_event_handler(defines.events.on_research_finished))
    local originals, checks, scripted, normal, snapshots = {}, {}, {}, {}, {}
    local context, native_event, first_tick, dispatch_tick
    local scripted_events, normal_events, targets = 0, {}, {}
    local relevance = {calls = 0, matching_event_name = 0, positive = {}}
    local finished = false
    local function pack(...) return {n = select("#", ...), ...} end
    local function check(name, condition, detail)
        checks[#checks + 1] = {name = name, pass = not not condition, detail = detail and tostring(detail) or nil}
        assert(condition, name .. (detail and (": " .. tostring(detail)) or ""))
    end
    local function finish(ok, err)
        finished = true
        for _, entry in ipairs(originals) do entry.owner[entry.key] = entry.original end
        script.on_event(defines.events.on_research_finished, previous_research)
        script.on_event(defines.events.on_tick, previous_tick)
        helpers.write_file("runtime-contracts-research.json", helpers.table_to_json{
            all_pass = ok, checks = checks, scripted = scripted, normal = normal,
            native_scripted_event_count = scripted_events, native_normal_events = normal_events,
            tesla_relevance = relevance, targets = targets, snapshots = snapshots,
            error = not ok and tostring(err) or nil}, false)
        assert(ok, err)
        log("RUNTIME_CONTRACTS mode=research COMPLETE")
    end
    local function install(owner, key, label, kind, tick_argument)
        local original = assert(owner[key], "Missing export: " .. label)
        originals[#originals + 1] = {owner = owner, key = key, original = original}
        owner[key] = function(...)
            local arguments = pack(...)
            if label == "tech-scripted" then
                context = {force = arguments[1], dispatch_tick = dispatch_tick, rows = {}, previous = context}
                scripted[#scripted + 1] = context.rows
            end
            local active, row = context, nil
            if active then
                local force = kind == "event" and arguments[1].research.force or arguments[1]
                row = {label = label, arguments = arguments.n,
                    force_index = kind ~= "none" and force.index or nil,
                    tick = tick_argument and arguments[tick_argument] or nil,
                    dispatch_tick = active.dispatch_tick}
                if kind == "event" then
                    row.research = arguments[1].research.name
                    row.by_script = arguments[1].by_script
                    row.original_event = arguments[1] == active.event
                elseif kind == "force" then row.original_force = arguments[1] == active.force end
                if label == "tesla-scripted" or label == "spider-scripted" then row.relevant = arguments[2] end
                active.rows[#active.rows + 1] = row
            end
            local returns = pack(original(...))
            if row then
                row.returns, row.first_return_type = returns.n, type(returns[1])
                if row.first_return_type == "boolean" or row.first_return_type == "number" or row.first_return_type == "string" then
                    row.first_return = returns[1]
                end
            end
            if label == "emerald-scripted" then context = active.previous end
            return table.unpack(returns, 1, returns.n)
        end
    end
    for _, entry in ipairs({
        {ei_tech_scaling, "tech"}, {ei_teslas_legacy, "tesla", 3}, {ei_spider_vehicles, "spider"},
        {ei_singularity_lance, "lance", 2}, {ei_sweeping_radar, "radar", 2},
        {ei_informatron_messager, "informatron"}, {em_trains, "em"},
        {ei_nauvis_pressure_grace, "pressure", 2}, {ei_emerald_apocalypse_hover_tank, "emerald", 2},
    }) do
        install(entry[1], "on_scripted_research_burst", entry[2] .. "-scripted", "force", entry[3])
        install(entry[1], "on_research_finished", entry[2] .. "-normal", "event")
    end
    install(ei_flamethrower_fuels, "sync_force", "flamethrower", "force")
    install(em_trains_gui, "force_has_access", "em-access", "force")
    install(em_trains_gui, "mark_dirty", "em-dirty", "none")
    do
        local original = ei_teslas_legacy.is_variant_sync_research
        originals[#originals + 1] = {owner = ei_teslas_legacy, key = "is_variant_sync_research", original = original}
        ei_teslas_legacy.is_variant_sync_research = function(name)
            local returns = pack(original(name))
            if native_event and native_event.by_script then
                relevance.calls = relevance.calls + 1
                if name == native_event.research.name then relevance.matching_event_name = relevance.matching_event_name + 1 end
                if returns[1] then relevance.positive[#relevance.positive + 1] = name end
            end
            return table.unpack(returns, 1, returns.n)
        end
    end
    script.on_event(defines.events.on_research_finished, function(event)
        local saved_context, saved_event = context, native_event
        native_event = event
        if event.by_script then scripted_events = scripted_events + 1
        else
            local rows = {}
            normal[#normal + 1] = rows
            normal_events[#normal_events + 1] = {research = event.research.name,
                force_index = event.research.force.index, tick = event.tick, by_script = event.by_script}
            context = {force = event.research.force, event = event, dispatch_tick = event.tick, rows = rows}
        end
        local returns = pack(pcall(previous_research, event))
        context, native_event = saved_context, saved_event
        if not returns[1] then finish(false, returns[2]) end
        return table.unpack(returns, 2, returns.n)
    end)
    local function snapshot(label)
        local value = remote.call("exotic-industries-qc", "get_research_hitch_qc_snapshot")
        snapshots[#snapshots + 1] = {label = label, value = value}
        return value
    end
    local function find(rows, label)
        local result, count, index = nil, 0, nil
        for i, row in ipairs(rows) do if row.label == label then result, count, index = row, count + 1, i end end
        return result, count, index
    end
    local scripted_order = {"tech-scripted", "tesla-scripted", "spider-scripted", "flamethrower",
        "lance-scripted", "radar-scripted", "informatron-scripted", "em-scripted", "pressure-scripted", "emerald-scripted"}
    local normal_order = {"tech-normal", "radar-normal", "flamethrower", "spider-normal",
        "tesla-normal", "lance-normal", "informatron-normal", "em-normal", "pressure-normal", "emerald-normal"}
    local function validate(rows, is_scripted, label)
        local core = {}
        for _, row in ipairs(rows) do
            if row.label ~= "em-access" and row.label ~= "em-dirty" then core[#core + 1] = row.label end
            if row.original_event ~= nil then
                check(label .. "-" .. row.label .. "-identity", row.original_event)
                check(label .. "-" .. row.label .. "-native", row.by_script == false)
            elseif row.original_force ~= nil then check(label .. "-" .. row.label .. "-force", row.original_force) end
            if row.tick ~= nil then check(label .. "-" .. row.label .. "-tick", row.tick == row.dispatch_tick) end
        end
        check(label .. "-order", table.concat(core, ",") == table.concat(is_scripted and scripted_order or normal_order, ","), table.concat(core, ","))
        local em, _, em_index = find(rows, is_scripted and "em-scripted" or "em-normal")
        check(label .. "-em-receiver", em ~= nil)
        local access, access_count, access_index = find(rows, "em-access")
        local _, dirty_count, dirty_index = find(rows, "em-dirty")
        local _, _, pressure_index = find(rows, is_scripted and "pressure-scripted" or "pressure-normal")
        local changed = em.first_return == true
        if is_scripted then
            check(label .. "-access-short-circuit", access_count == (changed and 0 or 1))
            check(label .. "-dirty", dirty_count == ((changed or (access and access.first_return == true)) and 1 or 0))
        else
            check(label .. "-no-access", access_count == 0)
            check(label .. "-dirty", dirty_count == ((changed or em.research == "ei_em-trains") and 1 or 0))
        end
        for _, index in pairs({access_index, dirty_index}) do
            check(label .. "-em-position-" .. index, index > em_index and index < pressure_index)
        end
    end
    local function complete(force, name)
        local technology = assert(force.technologies[name])
        check(name .. "-enabled", technology.enabled)
        force.research_queue = {}
        technology.researched = false
        check(name .. "-queued", force.add_research(name))
        check(name .. "-current", force.current_research and force.current_research.name == name)
        force.research_progress = 1
    end
    script.on_event(defines.events.on_tick, function(event)
        if finished then return end
        first_tick, dispatch_tick = first_tick or event.tick, event.tick
        local ok, err = pcall(function()
            previous_tick(event)
            local relative, force = event.tick - first_tick, game.forces.player
            if relative == 30 then
                check("native-scripted-flood", scripted_events > 1, scripted_events)
                check("one-fanout", #scripted == 1, #scripted)
                validate(scripted[1], true, "scripted")
                check("tesla-original-name", relevance.calls > 0 and relevance.calls == relevance.matching_event_name)
                check("tesla-relevance-admitted", assert(find(scripted[1], "tesla-scripted")).relevant == true)
                local state = snapshot("post-scripted")
                check("burst-drained", state.scripted_research_burst.pending_force_count == 0 and state.scripted_research_burst.next_due_tick == 0)
                check("live-em-chargers", state.em_trains.charger_count > 0)
                check("live-em-trains", state.em_trains.train_count > 0)
                check("live-tesla-cache", state.tesla.force_cache_count > 0)
                for _, name in ipairs({"ei-exotic-waveform-convergence", "ei-reactance-overdrive-3", "ei-bridge-coupling-2", "ei-dielectric-rupture-3", "ei-storm-lattice-3", "ei-waveform-harmonics-3"}) do
                    local technology = force.technologies[name]
                    if technology and technology.enabled and ei_teslas_legacy.is_variant_sync_research(name) then targets.tesla = name; break end
                end
                check("tesla-target", targets.tesla ~= nil)
                targets.em = "ei_em-trains"
                complete(force, targets.tesla)
            elseif relative == 60 then
                check("first-normal-completion", #normal == 1, #normal)
                check("tesla-normal-target", normal_events[1].research == targets.tesla)
                validate(normal[1], false, "normal-tesla")
                snapshot("post-normal-tesla")
                complete(force, targets.em)
            elseif relative == 180 then
                check("two-normal-completions", #normal == 2, #normal)
                check("em-normal-target", normal_events[2].research == targets.em)
                validate(normal[2], false, "normal-em")
                local state = snapshot("final")
                check("final-backlog-empty", state.scripted_research_burst.pending_force_count == 0
                    and state.scripted_research_burst.next_due_tick == 0 and state.scripted_research_burst.due_bucket_items == 0)
                check("fanout-still-once", #scripted == 1)
                -- Focused replay after caches settle: the native flood changed
                -- EM buffs and skipped access. Exercise the unchanged-buffs
                -- branch using the real queue/flush functions and exports.
                queue_scripted_research_burst({research = force.technologies[targets.em],
                    by_script = true, tick = event.tick})
                check("focused-flush", flush_scripted_research_burst_for_force(force.index, event.tick))
                check("focused-second-fanout", #scripted == 2)
                validate(scripted[2], true, "focused-scripted")
                check("focused-em-unchanged", assert(find(scripted[2], "em-scripted")).first_return == false)
                local access, access_count = find(scripted[2], "em-access")
                check("focused-required-access-executed", access_count == 1 and access.first_return == true)
                snapshot("post-focused-replay")
                finish(true)
            end
        end)
        if not ok and not finished then finish(false, err) end
    end)
end
