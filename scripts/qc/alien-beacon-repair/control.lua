local test = require("test-config")
local cases = {}
for _, quality in ipairs{"normal", "legendary"} do
    for variant = 1, 3 do
        cases[#cases + 1] = {name = "ei-alien-beacon_off-" .. variant, quality = quality}
    end
end

script.on_event(defines.events.script_raised_built, function(event)
    if event.entity.name == "ei-alien-beacon" then
        storage.builds = (storage.builds or 0) + 1
    end
end)

local function check(ok, message)
    assert(ok, "Alien beacon repair QC: " .. message)
    storage.checks = (storage.checks or 0) + 1
end

local function start_case(event)
    local case = cases[storage.index]
    local player = game.players[1]
    local surface = game.surfaces["alien-beacon-repair-qc"]
    local position = {x = storage.index * 12, y = 0}
    local ruin = assert(surface.create_entity{name = case.name, position = position,
        force = "neutral", quality = case.quality})
    position = ruin.position
    player.teleport({position.x, -6}, surface)
    check(player.cursor_stack.set_stack{name = "ei-alien-beacon-repair", count = 1}, "cursor tool")
    local builds = storage.builds or 0
    remote.call("alien-beacon-repair-qc", "repair", {item = "ei-alien-beacon-repair",
        entities = {ruin}, player_index = player.index, tick = event.tick})
    check(not ruin.valid, "ruin replaced")
    check(not player.cursor_stack.valid_for_read, "one repair kit consumed")
    local nearby = surface.find_entities_filtered{name = "ei-alien-beacon", position = position, radius = 3}
    local beacon = assert(nearby[1], case.name .. "/" .. case.quality .. " replacement missing")
    check(beacon.force.name == "neutral", "force preserved")
    check(beacon.quality.name == case.quality, "quality preserved")
    check(beacon.position.x == position.x and beacon.position.y == position.y, "position preserved")
    local metadata = remote.call("nonstandard-beacons", "get-beacon-data", beacon.unit_number)
    if test.baseline then
        check(metadata == nil, "baseline has missing metadata")
        log("ALIEN_BEACON_REPAIR_BASELINE missing metadata; selecting beacon for native hover callback")
    else
        check(storage.builds == builds + 1, "exactly one native build notification")
        check(metadata and metadata.beacon == beacon, "registered beacon metadata")
        check(metadata.source.valid and metadata.manager.valid, "valid source and manager")
        check(metadata.source.quality.name == case.quality, "source quality preserved")
        check(surface.count_entities_filtered{name = "ei-alien-beacon-source", position = position} == 1,
            "exactly one fuel source")
        check(metadata.source.get_fuel_inventory().insert{name = "ei-bio-matter", count = 20} > 0,
            "fuel accepted by actual source")
        check(beacon.get_module_inventory().insert{name = "speed-module", count = 1} == 1, "module accepted")
    end
    player.selected = beacon
    check(player.selected == beacon, "native hover selection")
    storage.beacon = beacon
    storage.due = event.tick + 60
end

script.on_event(defines.events.on_tick, function(event)
    if storage.done then return end
    -- Keep the small native fuel inventory supplied throughout the hover window.
    -- The normal 30 MW draw can exhaust one inserted stack before the checkpoint.
    if not test.baseline and storage.beacon and storage.beacon.valid then
        local metadata = remote.call("nonstandard-beacons", "get-beacon-data", storage.beacon.unit_number)
        metadata.source.get_fuel_inventory().insert{name = "ei-bio-matter", count = 20}
    end
    if not storage.index then
        check(game.players[1] ~= nil, "fixture save has a native player")
        game.players[1].clear_cursor()
        local surface = game.create_surface("alien-beacon-repair-qc", {
            autoplace_settings = {entity = {treat_missing_as_default = false},
                decorative = {treat_missing_as_default = false}}})
        surface.request_to_generate_chunks({36, 0}, 2)
        surface.force_generate_chunk_requests()
        storage.index = 1
        start_case(event)
    elseif event.tick >= storage.due then
        local beacon = storage.beacon
        local metadata = remote.call("nonstandard-beacons", "get-beacon-data", beacon.unit_number)
        check(metadata.source.burner.currently_burning ~= nil, "source burns fuel: " .. helpers.table_to_json({
            status = metadata.source.status, active = metadata.source.active,
            fuel = metadata.source.get_fuel_inventory().get_contents(),
            remaining = metadata.source.burner.remaining_burning_fuel}))
        check(not beacon.disabled_by_script, "fueled beacon enabled")
        check(beacon.custom_status ~= nil, "native hover status updated without crashing")
        local unit = beacon.unit_number
        game.players[1].selected = nil
        beacon.destroy{raise_destroy = true}
        check(remote.call("nonstandard-beacons", "get-beacon-data", unit) == nil, "metadata cleaned on removal")
        check(not metadata.source.valid and not metadata.manager.valid, "helper entities cleaned on removal")
        storage.index = storage.index + 1
        if storage.index <= #cases then
            start_case(event)
        else
            storage.done = true
            local report = {all_pass = true, cases = #cases, checks = storage.checks,
                factorio = script.active_mods.base, nonstandard_beacons = script.active_mods["zzz-nonstandard-beacons"],
                scope = "Native entities, cursor consumption, build events, hover callback, fuel and removal; no rendered UI or multiplayer review."}
            helpers.write_file("alien-beacon-repair.json", helpers.table_to_json(report), false)
            log("ALIEN_BEACON_REPAIR_QC " .. helpers.table_to_json(report))
        end
    end
end)
