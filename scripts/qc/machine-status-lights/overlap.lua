-- Private native-character occlusion fixture; never loaded by shipping ESIR.
local config = require("test-config")
local M = {}
local variants = {"status", "legacy", "light-only"}
local directions = {0, 4, 8, 12}
local poses = {"exposed", "ground-front", "ground-back", "air-full", "air-partial", "departed"}
local views = {{"day", 0, 1}, {"day", 0, 2}, {"night", 0.5, 1}, {"night", 0.5, 2}}

---@param cases table[]
---@param feed fun(row: table)
---@param inspect fun(row: table): table
function M.install(cases, feed, inspect)
    script.on_init(function()
        storage.overlap = {rows = {}, groups = {}, captures = {}, start = game.tick}
        local final = prototypes.mod_data["machine-light-qc"].data
        helpers.write_file("machine-lights/" .. config.profile .. "-final.json", helpers.table_to_json(final), false)
        for _, case in ipairs(cases) do
            if #case.lights > 0 then
                local surface = game.create_surface("overlap-" .. case.name, {width = 160, height = 256,
                    autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
                surface.request_to_generate_chunks({0, 0}, 5)
                surface.force_generate_chunk_requests()
                for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
                surface.destroy_decoratives{}
                surface.freeze_daytime, surface.daytime = true, 0.5
                surface.build_checkerboard{{-76, -124}, {76, 124}}
                for lamp, offset in ipairs(case.lights) do
                    for d, direction in ipairs(directions) do
                        local group = {name = case.name, lamp = lamp, direction = direction, rows = {}}
                        local y = ((lamp - 1) * 4 + d - 6.5) * 18
                        for v, variant in ipairs(variants) do
                            local x = (v - 2) * 40
                            local name = variant == "status" and case.name or "machine-light-" .. variant .. "-" .. case.name
                            local entity = assert(surface.create_entity{name = name, position = {x, y}, direction = direction, force = "player"})
                            if entity.type == "assembling-machine" then entity.set_recipe("machine-light-qc") end
                            local row = {entity = entity, name = case.name, variant = variant, direction = direction,
                                position = {x, y}, state = "working", previous = 0, advanced = false,
                                source_type = final.snapshot[case.name].energy_source.type,
                                lamp = {x + offset[1], y + offset[2]}}
                            if row.source_type == "electric" then
                                surface.create_entity{name = "machine-light-qc-pole", position = {x, y}, force = "player"}
                                row.supply = assert(surface.create_entity{name = "machine-light-qc-supply", position = {x, y}, force = "player"})
                                row.supply.power_production = entity.prototype.get_max_energy_usage("normal") * 4
                            end
                            row.actor = assert(surface.create_entity{name = "character", position = {x + 8, y + 4}, force = "player"})
                            row.actor.destructible = false
                            row.actor.disable_flashlight()
                            group.rows[#group.rows + 1] = row
                            storage.overlap.rows[#storage.overlap.rows + 1] = row
                        end
                        storage.overlap.groups[#storage.overlap.groups + 1] = group
                    end
                end
            end
        end
    end)
    script.on_event(defines.events.on_tick, function(event)
        local state = storage.overlap
        local elapsed = event.tick - state.start
        if elapsed == 1 then
            if remote.interfaces.freeplay then
                remote.call("freeplay", "set_skip_intro", true)
                remote.call("freeplay", "set_disable_crashsite", true)
            end
            for _, player in pairs(game.players) do
                if player.controller_type == defines.controllers.cutscene then player.exit_cutscene() end
            end
        end
        for _, row in ipairs(state.rows) do feed(row) end
        -- Each pose gets a native settling interval, then four small crops for
        -- every group. Matched controls render at the same tick and world phase.
        local duration = 80 + #state.groups * 8
        local pose_index = math.floor((elapsed - 240) / duration) + 1
        local phase = (elapsed - 240) % duration
        local pose = poses[pose_index]
        if elapsed < 240 or not pose then return end
        if phase == 0 then
            for _, row in ipairs(state.rows) do
                local actor, point = row.actor, row.lamp
                local air = pose:find("air", 1, true) ~= nil
                actor.walking_state = {walking = false, direction = defines.direction.north}
                if air then
                    if actor.get_inventory(defines.inventory.character_armor).is_empty() then
                        actor.get_inventory(defines.inventory.character_armor).insert{name = "mech-armor", count = 1}
                    end
                    -- Native flight is triggered by walking over water. Only
                    -- the private fixture floor changes; real actor art is used.
                    local tiles = {}
                    for x = -3, 3 do for y = -2, 5 do
                        tiles[#tiles + 1] = {name = "water", position = {math.floor(point[1]) + x, math.floor(point[2]) + y}}
                    end end
                    row.entity.surface.set_tiles(tiles, true, false, false, false)
                    assert(row.entity.valid and actor.valid, "Flight floor must preserve native actors")
                    assert(actor.teleport({point[1], point[2] + 3}))
                    actor.walking_state = {walking = true, direction = defines.direction.north}
                elseif pose == "ground-front" then
                    assert(actor.teleport({point[1], math.max(point[2] + 0.8, row.entity.position.y + 0.4)}))
                elseif pose == "ground-back" then
                    assert(actor.teleport({point[1], math.min(point[2] - 0.8, row.entity.position.y - 0.4)}))
                else
                    assert(actor.teleport({point[1] + 5, point[2] + 4}))
                end
            end
        end
        if pose:find("air", 1, true) and phase > 0 then
            for _, row in ipairs(state.rows) do
                local actor = row.actor
                if phase >= 60 then assert(actor.is_flying and actor.flight_height > 0, "Mech must fly: " .. row.name) end
                -- Keep a real flying actor at the measured screen-space lamp
                -- center while its native walking/flight animation continues.
                if actor.is_flying then
                    assert(actor.teleport({row.lamp[1] + (pose == "air-partial" and 0.5 or 0),
                        row.lamp[2] + actor.flight_height + 0.8}))
                end
            end
        end
        if phase >= 80 and (phase - 80) % 2 == 0 then
            local step = (phase - 80) / 2
            local group = state.groups[math.floor(step / 4) + 1]
            local view = views[step % 4 + 1]
            if group then
                local capture = {name = group.name, lamp = group.lamp, direction = group.direction,
                    pose = pose, lighting = view[1], zoom = view[3], tick = event.tick, rows = {}}
                for _, row in ipairs(group.rows) do
                    local native = inspect(row)
                    assert(native.valid, "Overlap machine status: " .. row.name)
                    local actor = row.actor
                    native.variant, native.lamp = row.variant, row.lamp
                    native.actor = {position = actor.position, direction = actor.direction,
                        flying = actor.is_flying, height = actor.flight_height,
                        machine_relative_y = actor.position.y - row.entity.position.y,
                        armor = actor.get_inventory(defines.inventory.character_armor).get_item_count("mech-armor")}
                    if pose:find("air", 1, true) then assert(native.actor.flying and native.actor.height > 0)
                    elseif pose:find("ground", 1, true) then assert(not native.actor.flying and native.actor.height == 0) end
                    native.path = string.format("%s/%s-l%d-d%d-%s-%s-z%d-%s.png", config.profile,
                        group.name, group.lamp, group.direction, pose, view[1], view[3], row.variant)
                    if config.visual then
                        game.take_screenshot{surface = row.entity.surface, position = row.lamp,
                            zoom = view[3], resolution = {160 * view[3], 160 * view[3]},
                            path = "machine-lights/" .. native.path, daytime = view[2], show_gui = false,
                            show_entity_info = false, hide_clouds = true, hide_fog = true,
                            anti_alias = view[3] == 1, force_render = true}
                    end
                    capture.rows[#capture.rows + 1] = native
                end
                state.captures[#state.captures + 1] = capture
                if config.visual then game.set_wait_for_screenshots_to_finish() end
                if pose_index == #poses and step == #state.groups * 4 - 1 then
                    helpers.write_file("machine-lights/" .. config.profile .. "-overlaps.json", helpers.table_to_json{
                        complete = true, visual = config.visual, groups = #state.groups, captures = state.captures}, false)
                end
            end
        end
    end)
end
return M
