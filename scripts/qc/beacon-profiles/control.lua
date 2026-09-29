local test = require("test-config")
local NAMES = {"ei-copper-beacon", "ei-iron-beacon", "ei-alien-beacon", "ei-warp-beacon"}
local OFFSETS = {{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{1,-1},{-1,1},{1,1},
    {-2,-2},{-1,-2},{0,-2},{1,-2},{2,-2},{2,-1},{2,0},{2,1}}
local EFFECTS = {"speed", "consumption", "pollution", "productivity", "quality"}
local loaded = false
local configuration_changed = false
script.on_load(function() loaded = true end)

local function supply(beacon)
    -- Nonstandard Beacons discovers the deliberately isolated receivers during
    -- configuration migration. Fuel its real source instead of overriding the
    -- beacon's disabled flag, so the transition exercises its normal power gate.
    local source = beacon
    if remote.interfaces["nonstandard-beacons"] then
        local metadata = remote.call("nonstandard-beacons", "get-beacon-data", beacon.unit_number)
        if metadata and metadata.source and metadata.source.valid then source = metadata.source end
    end
    if source.burner then
        source.burner.inventory.insert{name="ei-bio-matter", count=100}
    elseif #source.fluidbox > 0 then
        source.fluidbox[1] = {name="ei-liquid-nitrogen", amount=100, temperature=25}
    else
        source.energy = 1000000000
    end
end

local function add_case(id, names, quality, slots)
    local index = #storage.cases + 1
    local origin = {x=(index-1)*240, y=0}
    local surface = storage.surface
    surface.request_to_generate_chunks(origin, 1)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities_filtered{area={{origin.x-25,-25},{origin.x+25,25}}}) do entity.destroy() end
    local tiles = {}
    for x=origin.x-22,origin.x+22 do for y=-22,22 do tiles[#tiles+1]={name="refined-concrete", position={x,y}} end end
    surface.set_tiles(tiles)
    local machine = assert(surface.create_entity{name="esir-beacon-qc-machine", position=origin, force="player"})
    remote.call("esir-beacon-profile-qc", "built", machine)
    local case = {id=id, machine=machine, beacons={}, baseline=machine.effects}
    for i, name in ipairs(names) do
        local spacing = (#names > 1 and (name == NAMES[1] or name == NAMES[2])) and 3 or 5
        -- Mixed layouts use a common five-tile ring; all four tiers cover it.
        if id:find("mixed") then spacing = 5 end
        local beacon = assert(surface.create_entity{name=name, position={origin.x+OFFSETS[i][1]*spacing, OFFSETS[i][2]*spacing},
            force="player", quality=quality or "normal"})
        local inventory = beacon.get_module_inventory()
        local module = (name == "beacon" or name == "esir-beacon-qc-third-party") and "speed-module" or "esir-beacon-qc-module"
        local inserted = inventory.insert{name=module, count=slots or #inventory}
        assert(inserted == (slots or #inventory), "Module insertion " .. id)
        supply(beacon)
        case.beacons[#case.beacons+1] = beacon
        remote.call("esir-beacon-profile-qc", "built", beacon)
    end
    storage.cases[index] = case
end

script.on_init(function()
    game.speed = 10
    storage.cases = {}
    storage.history = {}
    storage.start = game.tick
    storage.surface = game.create_surface("beacon-profile-qc", {autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface.peaceful_mode = true
    for _, name in ipairs(NAMES) do
        for _, count in ipairs{1,2,4,8,16} do
            local names = {}
            for i=1,count do names[i] = name end
            add_case(name .. "-" .. count, names)
        end
    end
    add_case("legendary-iron", {NAMES[2]}, "legendary")
    add_case("mixed-all-tiers", NAMES)
    add_case("mixed-warp-copper", {NAMES[4],NAMES[1]})
    add_case("mixed-third-party", {NAMES[1],"esir-beacon-qc-third-party"}, nil, 1)
    add_case("mixed-vanilla", {NAMES[1],"beacon"}, nil, 1)
end)

script.on_configuration_changed(function(event)
    configuration_changed = true
    storage.start = game.tick
    storage.startup_changed = event.mod_startup_settings_changed == true
end)

local function check()
    local report = {profile=settings.startup["ei-beacon-diminishing-returns"].value,
        overload=settings.startup["ei-beacon-overload"].value, startup_changed=storage.startup_changed,
        cases={}, failures={}, all_pass=true, history=storage.history}
    local function expect(ok, message)
        if not ok then report.all_pass=false; report.failures[#report.failures+1]=message end
    end
    for _, case in ipairs(storage.cases) do
        local beacons = case.machine.get_beacons() or {}
        expect(#beacons == #case.beacons, case.id .. " receiver count")
        local expected, actual = {}, case.machine.effects
        for _, effect in ipairs(EFFECTS) do expected[effect] = case.baseline[effect] or 0 end
        local weight = 0
        local transmitters = {}
        for _, beacon in ipairs(case.beacons) do
            local metadata = remote.interfaces["nonstandard-beacons"] and remote.call("nonstandard-beacons", "get-beacon-data", beacon.unit_number)
            local source = metadata and metadata.source
            transmitters[#transmitters+1] = {name=beacon.name, active=beacon.active, energy=beacon.energy,
                source_status=source and source.status, source_energy=source and source.energy,
                source_fuel=source and source.burner and source.burner.inventory.get_item_count("ei-bio-matter"),
                status=beacon.status, disabled=beacon.disabled_by_script, effects=beacon.effects}
            local prototype = beacon.prototype
            local count = #beacons
            if prototype.beacon_counter == "same_type" then
                count=0
                for _, other in ipairs(beacons) do if other.name == beacon.name then count=count+1 end end
            end
            local profile = prototype.profile or {1}
            if #profile == 0 then profile = {1} end
            local multiplier = profile[math.min(count, #profile)]
            local strength = prototype.distribution_effectivity + prototype.distribution_effectivity_bonus_per_quality_level * beacon.quality.level
            for _, effect in ipairs(EFFECTS) do
                expected[effect] = expected[effect] + (beacon.effects[effect] or 0) * strength * multiplier
            end
            if beacon.name ~= NAMES[3] and beacon.name ~= NAMES[4] then weight=weight+(beacon.name==NAMES[2] and 2 or 1) end
        end
        local snapshot = remote.call("esir-beacon-profile-qc", "snapshot", case.machine.unit_number)
        local overloaded = test.overload and weight > 4
        expect(snapshot.machine.overloaded == overloaded, case.id .. " overload flag")
        expect(snapshot.machine.icon_present == overloaded, case.id .. " overload icon")
        expect(case.machine.active == not overloaded, case.id .. " active state")
        if not test.overload then
            expect(snapshot.machine.linked_beacon_count==0 and not snapshot.machine.registration_number, case.id .. " disabled topology")
        end
        for _, effect in ipairs(EFFECTS) do
            -- Native module effects quantize each beacon contribution to 0.01.
            expect(math.abs((actual[effect] or 0)-expected[effect]) <= #beacons*0.01001, case.id .. " " .. effect)
        end
        report.cases[#report.cases+1] = {id=case.id, count=#beacons, expected=expected, actual=actual,
            active=case.machine.active, snapshot=snapshot, unit=case.machine.unit_number, transmitters=transmitters}
    end
    local state=remote.call("esir-beacon-profile-qc", "snapshot")
    if not test.overload then
        expect(state.relationship_count==0 and state.object_registration_count==0 and state.overloaded_count==0, "disabled global cleanup")
    end
    report.state=state
    storage.history[#storage.history+1]={profile=report.profile, overload=report.overload, startup_changed=report.startup_changed}
    helpers.write_file("beacon-profile-report.json", helpers.table_to_json(report), false)
    log("BEACON_PROFILE_QC_RUNTIME " .. helpers.table_to_json(report))
    assert(report.all_pass, "Beacon profile acceptance: " .. table.concat(report.failures, ", "))
    game.server_save("beacon-profile-" .. test.phase)
end

script.on_event(defines.events.on_tick, function(event)
    if loaded then
        loaded = false
        storage.start = event.tick
        if not configuration_changed then storage.startup_changed = false end
    end
    if event.tick%5==0 then
        for _, case in ipairs(storage.cases) do for _, beacon in ipairs(case.beacons) do supply(beacon) end end
    end
    if event.tick-storage.start == 900 then check() end
end)
