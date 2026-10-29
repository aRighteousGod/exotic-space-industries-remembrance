local config = require("test-config")
local cases = require("cases")
if config.focus == "smelters" then
    local selected = {}
    for _, case in ipairs(cases) do if case.additive then selected[#selected + 1] = case end end
    cases = selected
end
local profile = config.profile or config.mode
local states = {"working", "idle", "missing-input", "full-output", "disabled", "no-power", "low-power"}
local directions = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}
local status_names = {}
for name, value in pairs(defines.entity_status) do status_names[value] = name end
local function write(name, value)
    helpers.write_file("machine-lights/" .. name .. ".json", helpers.table_to_json(value), false)
end

local function initialise()
    local final = prototypes.mod_data["machine-light-qc"].data
    write(profile .. "-final", final)
    storage.rows, storage.scenes, storage.captures, storage.transitions = {}, {}, {}, {}
    storage.start_tick = game.tick
    for i, case in ipairs(cases) do
        local surface = game.create_surface("machine-light-qc-" .. i, {width = 192, height = 128,
            autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
        surface.request_to_generate_chunks({0, 0}, 4)
        surface.force_generate_chunk_requests()
        for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
        surface.destroy_decoratives{}
        surface.always_day, surface.daytime, surface.freeze_daytime = false, 0.5, true
        local tiles = {}
        for x = -92, 92 do for y = -60, 60 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(tiles)
        local scene = {name = case.name, surface = surface, rows = {}}
        for s, state in ipairs(states) do
            -- Low-power is an electrical state; early fuel machines have six rows.
            local source_type = final.snapshot[case.name].energy_source.type
            if state ~= "low-power" or source_type == "electric" then
                for d, direction in ipairs(directions) do
                    local position = {(s - 4) * 24, (d - 2.5) * 24}
                    local entity = assert(surface.create_entity{name = case.name, position = position, force = "player", direction = direction})
                    if state ~= "idle" and entity.type == "assembling-machine" then entity.set_recipe("machine-light-qc") end
                    if state == "missing-input" and entity.type == "furnace" then
                        entity.get_inventory(defines.inventory.crafter_input).insert{name = "iron-plate", count = 1}
                    end
                    if state == "disabled" then entity.disabled_by_script = true end
                    local row = {entity = entity, state = state, source_type = source_type, direction = direction,
                        position = position, name = case.name, previous = 0, advanced = false}
                    if source_type == "electric" then
                        surface.create_entity{name = "machine-light-qc-pole", position = position, force = "player"}
                        row.supply = surface.create_entity{name = "machine-light-qc-supply", position = position, force = "player"}
                        -- Energy per tick follows the unmodified native machine.
                        -- Native graphics also observes network satisfaction.
                        -- A manually filled buffer alone can select low-power
                        -- tint even while LuaEntity.status reports working.
                        local multiplier = state == "no-power" and 0 or (state == "low-power" and 0.45 or 4)
                        row.supply.power_production = entity.prototype.get_max_energy_usage("normal") * multiplier
                    end
                    storage.rows[#storage.rows + 1] = row
                    scene.rows[#scene.rows + 1] = row
                end
            end
        end
        storage.scenes[#storage.scenes + 1] = scene
    end
    storage.brightness_rows = {}
    if prototypes.mod_data["machine-light-brightness"] then
        local surface = game.create_surface("machine-light-brightness", {width = 128, height = 128,
            autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
        surface.request_to_generate_chunks({0, 0}, 3)
        surface.force_generate_chunk_requests()
        for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
        surface.destroy_decoratives{}
        surface.always_day, surface.daytime, surface.freeze_daytime = false, 0.5, true
        local tiles = {}
        for x = -60, 60 do for y = -60, 60 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
        surface.set_tiles(tiles)
        for _, entry in ipairs(prototypes.mod_data["machine-light-brightness"].data.entries) do
            local row = {}
            for key, value in pairs(entry) do row[key] = value end
            row.entity = assert(surface.create_entity{name = row.name, position = row.position, force = "player"})
            row.direction, row.previous, row.advanced = defines.direction.north, 0, false
            -- A filled buffer alone can craft while the assembler's visual status
            -- still selects orange low-power. Use a real satisfied network here.
            surface.create_entity{name = "machine-light-qc-pole", position = row.position, force = "player"}
            row.supply = assert(surface.create_entity{name = "machine-light-qc-supply", position = row.position, force = "player"})
            row.supply.power_production = row.entity.prototype.get_max_energy_usage("normal") * 4
            if row.state == "working" then row.entity.set_recipe("machine-light-qc") end
            rendering.draw_text{surface = surface, target = {row.position[1] - 3, row.position[2] - 4},
                text = row.label .. " / " .. row.state, color = {1, 1, 1}, scale = 0.7}
            storage.brightness_rows[#storage.brightness_rows + 1] = row
        end
        storage.brightness_surface = surface
    end
end

local function feed(row)
    local entity = row.entity
    if row.state ~= "no-power" and row.state ~= "low-power" then
        if row.source_type == "electric" then entity.energy = 1e12
        elseif row.source_type == "burner" then entity.get_fuel_inventory().insert{name = row.name == "ei-bio-reactor" and "ei-bio-matter" or "coal", count = 1}
        elseif row.source_type == "fluid" then entity.insert_fluid{name = "steam", amount = 200, temperature = 500}
        elseif row.source_type == "heat" then entity.temperature = 1000 end
    end
    if row.state ~= "idle" and row.state ~= "missing-input" then
        entity.get_inventory(defines.inventory.crafter_input).insert{name = "iron-plate", count = 1}
    end
    local output = entity.get_output_inventory()
    if row.state == "full-output" then
        for index = 1, #output do output[index].set_stack{name = "copper-plate", count = prototypes.item["copper-plate"].stack_size} end
    else output.clear() end
    local progress = entity.crafting_progress + entity.products_finished
    if progress > row.previous then row.advanced = true end
    row.previous = progress
end

local function inspect(row)
    local status = status_names[row.entity.status]
    local accepted = {
        working = {working = true}, idle = {no_recipe = true, no_ingredients = row.entity.type == "furnace"},
        ["missing-input"] = {item_ingredient_shortage = true, no_ingredients = row.entity.type == "furnace"},
        ["full-output"] = {full_output = true}, disabled = {disabled_by_script = true, disabled_by_control_behavior = true},
        ["no-power"] = {no_power = true, no_fuel = row.source_type == "burner", no_input_fluid = row.source_type == "fluid", low_temperature = row.source_type == "heat"},
        ["low-power"] = {low_power = true},
    }
    return {name = row.name, state = row.state, direction = row.direction, actual_direction = row.entity.direction, status = status,
        position = {row.entity.position.x, row.entity.position.y},
        energy = row.entity.energy, progress = row.entity.crafting_progress, advanced = row.advanced,
        power_production = row.supply and row.supply.power_production,
        network = row.entity.electric_network_id,
        supports_direction = row.entity.prototype.supports_direction,
        -- Native assemblers without an active directional connection may normalize
        -- the requested orientation to north. The checker compares all modes to
        -- the unmodified baseline's actual direction, not just the request.
        valid = (row.entity.direction == row.direction or row.entity.direction == defines.direction.north)
            and accepted[row.state][status] == true and ((row.state ~= "working" and row.state ~= "low-power") or row.advanced)}
end

if config.overlaps then
    require("overlap").install(cases, feed, inspect)
    return
end
script.on_init(initialise)

local function capture(scene, variant)
    local evidence = {name = scene.name, tick = game.tick, rows = {}}
    for _, row in ipairs(scene.rows) do
        local state = inspect(row)
        assert(state.valid, "Capture-time state: " .. row.name .. " " .. row.state)
        evidence.rows[#evidence.rows + 1] = state
    end
    if variant == 1 then storage.captures[#storage.captures + 1] = evidence end
    local selection = ({ {"day", 0, 1}, {"day", 0, 2}, {"night", 0.5, 1}, {"night", 0.5, 2} })[variant]
    local lighting, daytime, zoom = selection[1], selection[2], selection[3]
    if config.mode == "status" or (lighting == "night" and zoom == 1) then
        game.take_screenshot{surface = scene.surface, position = {0, 0}, zoom = zoom,
            resolution = {5632 * zoom, 3584 * zoom}, path = "machine-lights/" .. profile .. "/" .. scene.name .. "-" .. lighting .. "-" .. zoom .. ".png",
            daytime = daytime, show_gui = false, show_entity_info = false,
            hide_clouds = true, hide_fog = true, anti_alias = zoom == 1, force_render = true}
        -- Do not queue another multi-hundred-megabyte frame while this one saves.
        game.set_wait_for_screenshots_to_finish()
    end
end

local function transition_evidence(label, rows)
    for _, row in ipairs(rows or storage.transition_rows) do
        local result = inspect(row)
        assert(result.valid, "Transition " .. label .. ": " .. row.name .. " " .. result.status)
        result.transition = label
        storage.transitions[#storage.transitions + 1] = result
        if config.visual and config.mode == "status" then
            game.take_screenshot{surface = row.entity.surface, position = row.position, zoom = 2,
                resolution = {768, 768}, path = "machine-lights/" .. (config.focus == "smelters" and profile .. "-transitions/" or "transitions/") .. row.name .. "-" .. label .. ".png",
                daytime = 0.5, show_gui = false, show_entity_info = false, hide_clouds = true,
                hide_fog = true, anti_alias = true, force_render = true}
        end
    end
    if config.visual then game.set_wait_for_screenshots_to_finish() end
end

script.on_event(defines.events.on_tick, function(event)
    local elapsed = event.tick - storage.start_tick
    if elapsed == 1 then
        -- Graphical loading creates a player in the headless-created save.
        -- Freeplay's crash-site intro otherwise opens a modal at about tick 720,
        -- pausing all later transitions while the graphics benchmark keeps going.
        if remote.interfaces.freeplay then
            remote.call("freeplay", "set_skip_intro", true)
            remote.call("freeplay", "set_disable_crashsite", true)
        end
        for _, player in pairs(game.players) do
            if player.controller_type == defines.controllers.cutscene then player.exit_cutscene() end
        end
        for _, row in ipairs(storage.rows) do row.entity.direction = row.direction end
    end
    for _, row in ipairs(storage.rows) do feed(row) end
    for _, row in ipairs(storage.brightness_rows or {}) do feed(row) end
    if elapsed == 240 then
        local report = {mode = config.mode, focus = config.focus, startup = settings.startup["ei-production-machine-lights"].value, rows = {}, failed = 0}
        for _, row in ipairs(storage.rows) do
            local result = inspect(row)
            report.rows[#report.rows + 1] = result
            if not result.valid then report.failed = report.failed + 1 end
        end
        report.arc_preset = settings.startup["ei-arc-furnace-light-flicker-preset"].value
        write(profile .. "-runtime", report)
        assert(report.failed == 0, "Machine light native states failed: " .. report.failed)
    end
    if config.visual and not config.transitions_only and elapsed >= 260 and (elapsed - 260) % 2 == 0 then
        local step = (elapsed - 260) / 2
        local index = math.floor(step / 4) + 1
        local variant = step % 4 + 1
        local scene = storage.scenes[index]
        if scene then capture(scene, variant) end
        if index == #storage.scenes and variant == 4 then
            game.set_wait_for_screenshots_to_finish()
            write(profile .. "-visual", {scenes = #storage.scenes, images = #storage.scenes * (config.mode == "status" and 4 or 1), complete = true, captures = storage.captures})
        end
    end
    if elapsed == 320 and storage.brightness_surface then
        local report = {rows = {}}
        for _, row in ipairs(storage.brightness_rows) do
            local result = inspect(row)
            assert(result.valid, "Brightness reference state " .. row.name)
            result.source, result.reference, result.intensity, result.lamps = row.source, row.reference, row.intensity, row.lamps
            result.reference_lamp = row.reference_lamp
            result.reference_colors = row.reference_colors
            report.rows[#report.rows + 1] = result
        end
        if config.visual and not config.transitions_only then
            for _, lighting in ipairs{{"day", 0}, {"night", 0.5}} do
                for _, zoom in ipairs{1, 2} do
                    game.take_screenshot{surface = storage.brightness_surface, position = {0, 0}, zoom = zoom,
                        resolution = {2816 * zoom, 3584 * zoom}, path = "machine-lights/brightness-" .. lighting[1] .. "-" .. zoom .. ".png",
                        daytime = lighting[2], show_gui = false, show_entity_info = false, hide_clouds = true,
                        hide_fog = true, anti_alias = true, force_render = true}
                end
            end
        end
        write("brightness-reference", report)
    end
    if elapsed == 520 then
        storage.transition_rows = {}
        for index, case in ipairs(cases) do
            if #case.lights > 0 then
                local row = storage.scenes[index].rows[1]
                row.state = "disabled"
                local source = assert(row.entity.surface.create_entity{name = "constant-combinator",
                    position = {row.position[1] - 10, row.position[2]}, force = "player"})
                local connector = row.entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
                assert(connector.connect_to(source.get_wire_connector(defines.wire_connector_id.circuit_red, true), false, defines.wire_origin.script))
                local behavior = row.entity.get_or_create_control_behavior()
                if row.entity.type == "assembling-machine" then behavior.circuit_set_recipe = false end
                behavior.circuit_enable_disable = true
                behavior.circuit_condition = {first_signal = {type = "virtual", name = "signal-A"}, comparator = ">", constant = 0}
                storage.transition_rows[#storage.transition_rows + 1] = row
            end
        end
    elseif elapsed == 560 then
        for _, row in ipairs(storage.transition_rows) do assert(row.entity.disabled_by_control_behavior, "Native circuit disable") end
        transition_evidence("circuit-disabled")
    elseif elapsed == 561 then
        -- Screenshots render after the update. Change state only after the
        -- captured state has crossed a render boundary.
        for _, row in ipairs(storage.transition_rows) do
            row.state, row.advanced = "working", false
            row.entity.get_or_create_control_behavior().circuit_condition = {first_signal = {type = "virtual", name = "signal-A"}, comparator = "=", constant = 0}
        end
    elseif elapsed == 600 then
        transition_evidence("circuit-resumed")
    elseif elapsed == 601 then
        for _, row in ipairs(storage.transition_rows) do
            row.state = "no-power"
            row.entity.energy = 0
            if row.supply then row.supply.power_production = 0; row.supply.energy = 0 end
            if row.source_type == "burner" then
                row.entity.get_fuel_inventory().clear()
                row.entity.burner.remaining_burning_fuel = 0
                row.entity.burner.currently_burning = nil
            elseif row.source_type == "heat" then row.entity.temperature = 15 end
        end
    elseif elapsed == 660 then
        transition_evidence("energy-lost")
    elseif elapsed == 661 then
        for _, row in ipairs(storage.transition_rows) do
            row.state, row.advanced = "working", false
            if row.supply then row.supply.power_production = row.entity.prototype.get_max_energy_usage("normal") * 4 end
        end
    elseif elapsed == 700 then
        transition_evidence("energy-restored")
    elseif elapsed == 701 then
        for _, row in ipairs(storage.transition_rows) do row.state = "full-output" end
    elseif elapsed == 760 then
        transition_evidence("output-blocked")
    elseif elapsed == 761 then
        for _, row in ipairs(storage.transition_rows) do row.state, row.advanced = "working", false end
    elseif elapsed == 800 then
        transition_evidence("output-cleared")
    elseif elapsed == 801 then
        storage.power_transition_rows = {}
        for _, row in ipairs(storage.transition_rows) do
            if row.source_type == "electric" then
                row.supply.power_production = row.entity.prototype.get_max_energy_usage("normal") * 0.45
                row.supply.energy = 0
                row.entity.energy = 0
                row.state, row.advanced = "low-power", false
                storage.power_transition_rows[#storage.power_transition_rows + 1] = row
            end
        end
    elseif elapsed == 900 then
        transition_evidence("power-limited", storage.power_transition_rows)
    elseif elapsed == 901 then
        for _, row in ipairs(storage.power_transition_rows) do
            row.supply.power_production = row.entity.prototype.get_max_energy_usage("normal") * 4
            row.state, row.advanced = "working", false
        end
    elseif elapsed == 960 then
        transition_evidence("power-restored", storage.power_transition_rows)
        if config.visual then game.set_wait_for_screenshots_to_finish() end
        write(profile .. "-transitions", {complete = true, checks = #storage.transitions, rows = storage.transitions})
    end
end)
