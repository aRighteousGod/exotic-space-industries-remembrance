-- Existing NSBC player acceptance, run through actual ESIR dispatcher/prototypes.
local fixture = require("player-control")
local player_matrix = require("player-matrix")
local loaded = false
script.on_init(function()
    -- The native freeplay introduction is a modal dialog and pauses a hidden
    -- client. Suppress it only in this disposable automation seed.
    if remote.interfaces.freeplay then remote.call("freeplay", "set_skip_intro", true) end
end)
script.on_load(function() loaded = true end)
script.on_event(defines.events.on_tick, function(event)
    if loaded and storage.native_accepted then
        loaded = false
        local current = remote.call("nsbc-qc", "custody")
        assert(helpers.table_to_json(current) == helpers.table_to_json(storage.custody), "Beacon helper custody changed on reload")
        helpers.write_file("beacon-client-reload.json", helpers.table_to_json{passed=true, helpers=#current,
            engine=script.active_mods.base, tick=event.tick}, false)
        return
    end
    -- ESIR's Alien beacon uses 30 MW, unlike the low-power standalone fixture.
    -- Freeze its native one-item burn after ignition so the rendered panel can
    -- inspect a nonempty burning slot with an empty fuel queue for several frames.
    if storage.ui_phase==7 and storage.ui_tick and not storage.burner_frozen then
        local source=remote.call("nonstandard-beacons","get-beacon-data",storage.ui_beacon.unit_number).source
        if source.burner and source.burner.currently_burning and source.burner.remaining_burning_fuel>0
            and source.get_fuel_inventory().is_empty() then
            source.disabled_by_script=true
            storage.burner_frozen=true
        end
    end
    fixture.tick(event.tick)
    if storage.native_accepted and not storage.custody then
        player_matrix.run(game.connected_players[1])
        storage.custody = remote.call("nsbc-qc", "custody")
        -- Take a second autosave after the custody projection exists.
        game.auto_save("esir-beacon-client-accepted")
        helpers.write_file("beacon-client-custody.json",helpers.table_to_json{passed=true, helpers=#storage.custody},false)
    end
end)
