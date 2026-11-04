-- Focused 2.1.24 vanilla scaling and saved startup-setting transitions.
local support = require("support")
local test = require("test-config")
local started
local checks, measurements = {}, {}
local offsets = {{-3,-3},{0,-3},{3,-3},{-3,0},{3,0}}

---@param name string
---@param value boolean
local function check(name, value)
    checks[#checks+1] = {name=name, passed=value == true}
    assert(value, name)
end

---@param row table
---@param index integer
local function add_beacon(row, index)
    local offset = offsets[index]
    local beacon = assert(row.machine.surface.create_entity{name="beacon",
        position={row.machine.position.x+offset[1], offset[2]}, force="player",
        quality=row.quality, raise_built=true})
    local inventory = beacon.get_module_inventory()
    assert(#inventory>0 and inventory.insert{name="speed-module", count=#inventory} == #inventory,
        "Fill the shipped vanilla module slots")
    beacon.energy = 1000000000
    row.beacons[index] = beacon
end

---@return nil
local function init()
    local surface = game.create_surface("vanilla-beacon-profile-qc", {width=512,height=128})
    surface.request_to_generate_chunks({0,0}, 8)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x=-20,210 do for y=-12,12 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.profile_cases, storage.profile_history = {}, {}
    storage.profile_config_changes = 0
    for index, spec in ipairs{{1,"normal"},{2,"normal"},{4,"normal"},{5,"normal"},{1,"legendary"},{4,"legendary"}} do
        local machine = assert(surface.create_entity{name="esir-beacon-qc-machine",
            position={(index-1)*36,0}, force="player", raise_built=true})
        local row = {machine=machine, count=spec[1], quality=spec[2], beacons={}}
        storage.profile_cases[index] = row
        for i=1,row.count do add_beacon(row,i) end
    end
end

---@param tick integer
---@return EsirNativeResult
local function poll(tick)
    started = started or tick
    local elapsed = tick-started
    for _, row in ipairs(storage.profile_cases) do
        for _, beacon in pairs(row.beacons) do if beacon.valid then beacon.energy=1000000000 end end
    end
    if elapsed == 120 then
        check("actual-overload-setting",settings.startup["ei-beacon-overload"].value == test.overload)
        check("save-history-length",#storage.profile_history == test.previous)
        check("startup-transition-count",storage.profile_config_changes == test.previous)
        for i, mode in ipairs(storage.profile_history) do
            check("saved-mode-"..i,mode == (i%2 == 1))
        end
        local normal = storage.profile_cases[1].machine.effects.speed or 0
        local legendary = storage.profile_cases[5].machine.effects.speed or 0
        check("positive-single-beacon-effect",normal>0 and legendary>normal)
        for i, row in ipairs(storage.profile_cases) do
            local count = #(row.machine.get_beacons() or {})
            check("native-coverage-"..i,count == row.count)
            local actual = row.machine.effects.speed or 0
            local multiplier = test.overload and 1 or ({1,0.7071,0.5773,0.5,0.4472})[row.count]
            local beacon = row.beacons[1]
            local prototype = beacon.prototype
            local strength = prototype.distribution_effectivity +
                prototype.distribution_effectivity_bonus_per_quality_level*beacon.quality.level
            local expected = beacon.effects.speed*strength*row.count*multiplier
            -- Native effect quantization can lose up to 0.01 per beacon.
            local tolerance = row.count*0.01001
            check("native-scaling-"..i,math.abs(actual-expected)<tolerance)
            check("native-overload-"..i,row.machine.disabled_by_script == (test.overload and row.count>4))
            measurements[#measurements+1]={count=count,quality=row.quality,actual=actual,expected=expected}
        end
        local row = storage.profile_cases[4]
        row.beacons[5].destroy{raise_destroy=true}
        row.beacons[5] = nil
    elseif elapsed == 240 then
        local row = storage.profile_cases[4]
        check("removal-coverage",#row.machine.get_beacons() == 4)
        check("removal-restores-operation",not row.machine.disabled_by_script)
        check("removal-restores-four-beacon-effect",math.abs(row.machine.effects.speed-storage.profile_cases[3].machine.effects.speed)<0.00001)
        add_beacon(row,5)
    elseif elapsed == 360 then
        local row = storage.profile_cases[4]
        check("readdition-coverage",#row.machine.get_beacons() == 5)
        check("readdition-overload",row.machine.disabled_by_script == test.overload)
        storage.profile_history[#storage.profile_history+1] = test.overload
        return {complete=true,checks=checks,metrics={effects=measurements,history=storage.profile_history}}
    end
    return {complete=false,checks=checks}
end

return {init=init,poll=poll,configuration_changed=function(event)
    assert(event.mod_startup_settings_changed,"Expected a real startup-setting transition")
    storage.profile_config_changes = storage.profile_config_changes+1
end}
