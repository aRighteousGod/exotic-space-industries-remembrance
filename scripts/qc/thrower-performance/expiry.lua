-- Load a populated transition save, stop firing, and let saved effects expire.
-- No effects are removed or replaced by the fixture.
local config = require("test-config")
local pending = true
local function effects()
    local result = {stickers = 0, fires = storage.surface.count_entities_filtered{type="fire"}}
    for _,case in ipairs(storage.cases) do result.stickers = result.stickers + #(case.target.stickers or {}) end
    return result
end
script.on_event(defines.events.on_entity_damaged, function(event)
    if not storage.expiry then return end
    for _,case in ipairs(storage.cases) do
        if event.entity == case.target then
            storage.expiry.last_damage_tick = event.tick - storage.expiry.start
            return
        end
    end
end)
script.on_event(defines.events.on_tick, function(event)
    if pending then
        pending = false
        assert(storage.cases and storage.surface, "Expiry requires a populated transition save")
        storage.expiry = {start=event.tick, initial=effects(), peak_stickers=0, last_damage_tick=0}
        for _,case in ipairs(storage.cases) do case.turret.active = false end
    end
    local elapsed = event.tick - storage.expiry.start
    for _,case in ipairs(storage.cases) do
        storage.expiry.peak_stickers = math.max(storage.expiry.peak_stickers, #(case.target.stickers or {}))
    end
    if elapsed == 7800 then
        local final = effects()
        local report = {profile=config.profile, initial=storage.expiry.initial, final=final,
            peak_stickers=storage.expiry.peak_stickers, last_damage_tick=storage.expiry.last_damage_tick,
            all_pass=final.stickers==0 and final.fires==0 and storage.expiry.last_damage_tick<7200}
        helpers.write_file("thrower-expiry.json", helpers.table_to_json(report), false)
        assert(report.all_pass, "Saved thrower effects did not expire naturally")
    end
end)
