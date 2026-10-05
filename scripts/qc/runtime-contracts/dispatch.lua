-- Appended only to the staged control chunk; exercise real registered routes.
do
    local previous = assert(script.get_event_handler(defines.events.on_tick))
    local finished = false
    script.on_event(defines.events.on_tick, function(tick_event)
        previous(tick_event)
        if finished then return end
        finished = true
        local checks, trace = {}, {}
        local function check(label, condition, detail)
            checks[#checks + 1] = {name = label, pass = not not condition,
                detail = detail and tostring(detail) or nil}
            assert(condition, label .. (detail and (": " .. tostring(detail)) or ""))
        end
        local function run()
            local auric, matter = ei_auric_inoculation_vat, ei_matter_stabilizer
            local player = game.get_player(1)
            check("saved-player", player and player.valid)
            local connected = false
            for _, p in pairs(game.connected_players) do if p == player then connected = true end end
            check("connected-player", connected and player.connected)
            player.opened = nil
            player.cursor_stack.clear()
            auric.close_gui(player)
            matter.close_gui(player)
            local surface = game.create_surface("runtime-contracts-gui", {
                width = 128, height = 128, water = 0, autoplace_controls = {}})
            surface.request_to_generate_chunks({0, 0}, 2)
            surface.force_generate_chunk_requests()
            local tiles = {}
            for x = -48, 48 do for y = -48, 48 do
                tiles[#tiles + 1] = {name = "landfill", position = {x, y}}
            end end
            surface.set_tiles(tiles, true)
            check("teleport", player.teleport({0, 12}, surface))
            local function build(name, x)
                return assert(surface.create_entity{name = name, position = {x, 0},
                    force = player.force, raise_built = true, create_build_effect_smoke = false})
            end
            local vat, assembler, chest = build("ei-auric-inoculation-vat", -20),
                build("ei-exotic-assembler", 0), build("iron-chest", 20)
            local empty = game.create_surface("runtime-contracts-empty", {width = 32, height = 32})
            local function payload(name, fields)
                local event = {name = assert(defines.events[name]), tick = tick_event.tick,
                    player_index = player.index, gui_type = defines.gui_type.entity}
                for k, v in pairs(fields or {}) do event[k] = v end
                return event
            end
            local function route(label, owner, export, index, event, count, argument)
                local original = assert(owner[export])
                argument = argument or event
                local calls, matches = 0, 0
                local entity_name = event.entity and event.entity.valid and event.entity.name or nil
                local element_name = event.element and event.element.valid and event.element.name or nil
                owner[export] = function(...)
                    calls = calls + 1
                    if select(index, ...) == argument then matches = matches + 1 end
                    return original(...)
                end
                local ok, err = pcall(assert(script.get_event_handler(event.name)), event)
                owner[export] = original
                trace[#trace + 1] = {label = label, export = export, event_name = event.name,
                    tick = event.tick, player_index = event.player_index,
                    entity_name = entity_name, element_name = element_name,
                    argument_kind = argument == event and "event" or "player", calls = calls, matches = matches}
                check(label .. "-handler", ok, err)
                check(label .. "-count", calls == count, calls)
                check(label .. "-identity", matches == calls)
            end
            local function auric_open(label)
                player.opened = vat
                route(label, auric, "on_gui_opened", 1, payload("on_gui_opened", {entity = vat}), 1)
                check(label .. "-session", auric.has_open_gui_session(player.index))
                check(label .. "-panel", player.gui.relative["ei-auric-inoculation-vat-console"])
            end
            local function auric_closed(label)
                check(label .. "-session-cleared", not auric.has_open_gui_session(player.index))
                check(label .. "-pending-cleared", storage.ei.auric_inoculation_vat.ui_pending_by_player[player.index] == nil)
                check(label .. "-panel-cleared", not player.gui.relative["ei-auric-inoculation-vat-console"])
            end
            local function click(label, owner, root)
                local button = root.add{type = "button", name = "runtime-contracts-noop", caption = "QC",
                    tags = {parent_gui = root.name, action = "qc-noop"}}
                route(label, owner, "on_gui_click", 1, payload("on_gui_click", {element = button}), 1)
                check(label .. "-panel-retained", root.valid)
                button.destroy()
            end
            auric_open("auric-open")
            click("auric-click", auric, player.gui.relative["ei-auric-inoculation-vat-console"])
            -- Simulate the stale-session admission path with a real opened
            -- chest. Suppress only the property's native GUI notifications,
            -- restore both routes, then deliver the original-shaped payload.
            local old_open = script.get_event_handler(defines.events.on_gui_opened)
            local old_close = script.get_event_handler(defines.events.on_gui_closed)
            script.on_event(defines.events.on_gui_opened, function() end)
            script.on_event(defines.events.on_gui_closed, function() end)
            local opened_ok, opened_err = pcall(function() player.opened = chest end)
            script.on_event(defines.events.on_gui_opened, old_open)
            script.on_event(defines.events.on_gui_closed, old_close)
            check("unrelated-property-restored", opened_ok, opened_err)
            route("auric-unrelated-open", auric, "on_gui_opened", 1, payload("on_gui_opened", {entity = chest}), 1)
            auric_closed("auric-unrelated-open")
            for _, kind in ipairs({"entity", "root"}) do
                auric_open("auric-reopen-" .. kind)
                local fields = kind == "entity" and {entity = vat}
                    or {element = player.gui.relative["ei-auric-inoculation-vat-console"]}
                route("auric-close-" .. kind, auric, "on_gui_closed", 1, payload("on_gui_closed", fields), 1)
                auric_closed("auric-close-" .. kind)
            end
            for _, kind in ipairs({"entity", "root"}) do
                player.opened = assembler
                local label = "matter-open-" .. kind
                route(label, matter, "open_gui", 2, payload("on_gui_opened", {entity = assembler}), 1)
                local gui = storage.ei.matter_stabilizer_gui
                check(label .. "-session", gui.open_by_player[player.index])
                check(label .. "-watcher", gui.watchers_by_unit[assembler.unit_number][player.index])
                check(label .. "-panel", player.gui.relative["ei-exotic-assembler-console"])
                if kind == "entity" then click("matter-click", matter, player.gui.relative["ei-exotic-assembler-console"]) end
                local fields = kind == "entity" and {entity = assembler}
                    or {element = player.gui.relative["ei-exotic-assembler-console"]}
                route("matter-close-" .. kind, matter, "close_gui", 1, payload("on_gui_closed", fields), 1, player)
                check(label .. "-session-cleared", gui.open_by_player[player.index] == nil)
                check(label .. "-watcher-cleared", gui.watchers_by_unit[assembler.unit_number] == nil)
                check(label .. "-panel-cleared", not player.gui.relative["ei-exotic-assembler-console"])
            end
            player.opened = nil
            check("guide-absent-before", not auric.has_active_placement_guide(player.index))
            for _, name in ipairs({"on_player_changed_position", "on_player_toggled_alt_mode"}) do
                for _, active in ipairs({false, true}) do
                    local original, admissions = auric.has_active_placement_guide, 0
                    auric.has_active_placement_guide = function(index)
                        check(name .. "-predicate-player", index == player.index)
                        admissions = admissions + 1
                        return active
                    end
                    local label = name .. (active and "-admitted" or "-idle")
                    local ok, err = pcall(route, label, auric, name, 1,
                        payload(name, {alt_mode = true}), active and 1 or 0)
                    auric.has_active_placement_guide = original
                    check(label .. "-restored", ok, err)
                    check(label .. "-predicate-once", admissions == 1)
                end
            end
            check("guide-absent-after", not auric.has_active_placement_guide(player.index))
            for _, name in ipairs({"on_player_cursor_stack_changed", "on_player_changed_surface"}) do
                route(name, auric, name, 1, payload(name, {surface_index = surface.index}), 1)
            end
            for _, name in ipairs({"on_pre_surface_deleted", "on_pre_surface_cleared"}) do
                route(name, auric, "on_pre_surface_deleted", 1, payload(name, {surface_index = empty.index}), 1)
            end
        end
        local ok, err = pcall(run)
        helpers.write_file("runtime-contracts-dispatch.json", helpers.table_to_json{
            all_pass = ok, checks = checks, trace = trace, error = not ok and tostring(err) or nil}, false)
        assert(ok, err)
        log("RUNTIME_CONTRACTS mode=dispatch COMPLETE")
    end)
end
