-- Appended only to the disposable staged main mod for rendered locale acceptance.
do
    local spec = require("matrix-capture-config")
    local pending, translations, remaining = {}, {}, 0
    local started, elapsed = false, 0
    local previous_translation = script.get_event_handler(defines.events.on_string_translated)
    script.on_event(defines.events.on_string_translated, function(event)
        if previous_translation then previous_translation(event) end
        local key = pending[event.id]
        if key then
            assert(event.translated and not event.result:find("Unknown key"), "Missing translation: " .. key)
            translations[key] = event.result
            pending[event.id] = nil
            remaining = remaining - 1
        end
    end)
    local previous_tick = script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick, function(event)
        previous_tick(event)
        local q, player = storage.induction_circuit_qc, game.connected_players[1]
        if not (q and q.complete and player) then return end
        elapsed = elapsed + 1
        if not started then
            started = true
            assert(player.locale == spec.locale, "Unexpected client locale: " .. player.locale)
            assert(math.abs(player.display_scale - spec.scale) < 0.02, "Unexpected UI scale: " .. player.display_scale)
            local keys = {"gui-control-behavior.circuit-connection", "gui-control-behavior.connected-to-network",
                "gui-control-behavior.not-connected", "gui-control-behavior-modes-guis.output-signal",
                "item-description.ei-induction-matrix-core-circuit-interface"}
            for _, suffix in ipairs{"stored","capacity","max-io","percent","output-tooltip","shared-tooltip","timing-tooltip","percent-tooltip"} do
                keys[#keys+1] = "exotic-industries.induction-matrix-circuit-" .. suffix
            end
            for _, key in ipairs(keys) do
                local id = assert(player.request_translation{key})
                pending[id] = key; remaining = remaining + 1
            end
            -- The saved player's remembered display resolution can exceed the hidden
            -- client's screenshot canvas. Use a fixed review position, not auto-centering.
            local root = ei_induction_matrix.get_gui(player)
            root.auto_center=false;root.location={16,16}
        end
        if elapsed == 40 or elapsed == 44 then
            local root = ei_induction_matrix.get_gui(player)
            root.auto_center=false;root.location={16,16};root.bring_to_front()
        end
        if elapsed == 45 then
            assert(remaining == 0, "Locale translations did not finish")
            game.take_screenshot{player=player, resolution={1280,900},show_gui=true,force_render=true,
                path="matrix-captures/"..spec.tag.."-panel.png"}
        elseif elapsed == 60 then
            -- This sheet renders the exact shipping tooltip strings for font/wrapping review;
            -- it is intentionally distinct from a claim of native mouse-hover interaction.
            local sheet=player.gui.screen.add{type="frame",name="matrix-qc-tooltips",direction="vertical",
                caption={"gui-control-behavior.circuit-connection"}}
            sheet.style.width=560
            for _,key in ipairs{"output-tooltip","shared-tooltip","timing-tooltip","percent-tooltip"} do
                local label=sheet.add{type="label",caption={"exotic-industries.induction-matrix-circuit-"..key}}
                label.style.single_line=false;label.style.maximal_width=520
                sheet.add{type="line"}
            end
            sheet.location={16,16}
        elseif elapsed == 75 then
            game.take_screenshot{player=player,resolution={1280,900},show_gui=true,force_render=true,
                path="matrix-captures/"..spec.tag.."-tooltips.png"}
            helpers.write_file("matrix-captures/"..spec.tag..".json",helpers.table_to_json{
                all_pass=true,locale=player.locale,scale=player.display_scale,tag=spec.tag,
                display_resolution=player.display_resolution,location=ei_induction_matrix.get_gui(player).location,
                translations=translations},false)
            log("INDUCTION_CIRCUIT_QC CAPTURE_COMPLETE "..spec.tag)
        end
    end)
end
