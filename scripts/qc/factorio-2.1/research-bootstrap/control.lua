script.on_init(function()
    helpers.write_file("research-bootstrap.json", helpers.table_to_json(prototypes.mod_data["esir-qc-research-bootstrap"].data), false)
end)

-- Separate QC mod: exercise the native lab and save loader without replacing
-- ESIR's dispatcher, research receivers, technology effects or lab prototypes.
local config = require("test-config")
local loaded = false
script.on_load(function() loaded = true end)

local function complete_prerequisites(technology)
    for _, prerequisite in pairs(technology.prerequisites) do
        if not prerequisite.researched then
            complete_prerequisites(prerequisite)
            prerequisite.researched = true
        end
    end
end

local function snapshot(state)
    local force = state.force
    local result = {researched={}, queue={}, inventory={}, progress=force.research_progress}
    for name, technology in pairs(force.technologies) do
        if technology.researched then result.researched[name] = technology.level end
    end
    for _, technology in ipairs(force.research_queue or {}) do
        result.queue[#result.queue+1] = technology.name
    end
    for _, name in ipairs(state.packs) do result.inventory[name] = state.lab.get_item_count(name) end
    result.metallurgic_recipe_enabled = force.recipes["metallurgic-science-pack"].enabled
    return result
end

script.on_event(defines.events.on_research_finished, function(event)
    local state = storage.bootstrap
    if state and event.research.force == state.force and event.research.name == "metallurgic-science-pack" then
        state.completion = {tick=event.tick, by_script=event.by_script}
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if config.runtime == "reload" and loaded then
        loaded = false
        assert(storage.bootstrap and storage.bootstrap.done, "Missing accepted native lab state")
        local actual = snapshot(storage.bootstrap)
        helpers.write_file("research-bootstrap-reload.json", helpers.table_to_json{
            actual=actual, expected=storage.bootstrap.accepted, engine=script.active_mods.base}, false)
        return
    end
    if config.runtime ~= "lab" or (storage.bootstrap and storage.bootstrap.done) then return end
    if not storage.bootstrap then
        assert(config.no_triggers, "Native lab case requires science-cost mode")
        local force = game.create_force("esir-qc-bootstrap")
        local technology = force.technologies["metallurgic-science-pack"]
        complete_prerequisites(technology)
        local surface = game.create_surface("esir-qc-bootstrap", {width=64, height=64})
        surface.request_to_generate_chunks({0,0}, 1)
        surface.force_generate_chunk_requests()
        for _, entity in pairs(surface.find_entities()) do entity.destroy() end
        local lab = assert(surface.create_entity{name="ei-big-lab", position={0,0}, force=force})
        local packs = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech", "ei-computer-age-tech"}
        for _, name in ipairs(packs) do assert(lab.insert{name=name, count=40} == 40, "Lab rejects "..name) end
        assert(lab.get_item_count("metallurgic-science-pack") == 0, "Unexpected Metallurgic science")
        assert(#technology.research_unit_ingredients == 4, "Wrong native technology ingredients")
        force.laboratory_speed_modifier = 99
        force.laboratory_productivity_bonus = 0
        assert(force.add_research(technology), "Cannot start Metallurgic science")
        storage.bootstrap = {force=force, lab=lab, packs=packs, started=event.tick}
    end
    local state = storage.bootstrap
    state.lab.energy = 1000000000
    if not state.force.technologies["metallurgic-science-pack"].researched then
        assert(event.tick-state.started < 1000, "Metallurgic science stalled without its own science pack")
        return
    end
    assert(state.completion and not state.completion.by_script, "Expected ordinary native lab completion")
    for _, name in ipairs(state.packs) do
        assert(state.lab.get_item_count(name) == 30, "Expected ten consumed "..name)
    end
    assert(state.force.recipes["metallurgic-science-pack"].enabled, "Science recipe remains locked")
    -- Save unrelated in-progress research and completed research alongside the lab.
    local next_technology = state.force.technologies["ei-acid-neutralisation-t2"]
    complete_prerequisites(next_technology)
    assert(state.force.add_research(next_technology), "Cannot queue intended post-Metallurgic technology")
    state.force.research_progress = 0.375
    state.lab.disabled_by_script = true
    state.accepted = snapshot(state)
    state.done = true
    helpers.write_file("research-bootstrap-native.json", helpers.table_to_json{
        engine=script.active_mods.base, accepted=state.accepted, completion=state.completion,
        started=state.started, finished=event.tick, passed=true}, false)
    if game.is_multiplayer() then game.server_save("research-bootstrap-fixed") end
    log("RESEARCH BOOTSTRAP NATIVE PASSED")
end)
