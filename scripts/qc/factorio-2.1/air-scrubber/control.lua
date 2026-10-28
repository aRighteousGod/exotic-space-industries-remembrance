-- Native event dispatch, populated replacement and consumed-input refund proof.
-- Uses the shipping ESIR build handler; no private replacement implementation.
local loaded = false
local BASE, TARGET = "atan-air-scrubber", "rare-atan-air-scrubber"
local function check(value, message) assert(value, "AIR SCRUBBER QC: " .. message) end
local function contents(inv)
    local rows = {}
    for _, item in pairs(inv.get_contents()) do rows[#rows + 1] = item.name .. "/" .. item.quality .. "/" .. item.count end
    table.sort(rows)
    return rows
end
local function snapshot(entity)
    local recipe, quality = entity.get_recipe()
    local row = {input = contents(entity.get_inventory(defines.inventory.crafter_input)),
        output = contents(entity.get_inventory(defines.inventory.crafter_output)),
        recipe = recipe and recipe.name, recipe_quality = quality and quality.name,
        result_quality = entity.result_quality and entity.result_quality.name,
        quality = entity.quality.name, direction = entity.direction, mirroring = entity.mirroring}
    for _, key in ipairs({"health", "energy", "crafting_progress", "bonus_progress", "products_finished",
        "disabled_by_script", "minable_flag", "destructible", "operable", "rotatable"}) do row[key] = entity[key] end
    return row
end
local function same(expected, actual, label)
    for key, value in pairs(expected) do
        check(helpers.table_to_json{value} == helpers.table_to_json{actual[key]}, label .. " changed " .. key .. ": " .. helpers.table_to_json{value,actual[key]})
    end
end
local function replace_and_mine(job)
    local before = snapshot(job.entity)
    local surface, position = job.entity.surface, job.entity.position
    check(before.crafting_progress > 0, "native craft must be in progress")
    check(job.entity.get_inventory(defines.inventory.crafter_input).get_item_count("atan-pollution-filter") == 11, "one input was consumed")
    script.raise_script_built{entity = job.entity}
    local replacement = surface.find_entity({name=TARGET, quality="rare"}, position)
    check(replacement and replacement.valid and not job.entity.valid, "quality replacement did not occur")
    -- The quality-specific variant has the authored lower electric usage and
    -- therefore a smaller native buffer. Preserve its capacity, not an overfill.
    local expected = {}
    for key, value in pairs(before) do expected[key] = value end
    expected.energy = math.min(before.energy, replacement.electric_buffer_size)
    local after = snapshot(replacement)
    same(expected, after, job.name)
    local unit = replacement.unit_number
    script.raise_script_built{entity = replacement}
    check(replacement.valid and replacement.unit_number == unit, "prefixed replacement must be idempotent")
    check(#surface.find_entities_filtered{position=position, radius=1, type="furnace"} == 1, "duplicate furnace")
    local inventory = game.create_inventory(10)
    check(replacement.mine{inventory=inventory, ignore_minable=true, raise_destroyed=true}, "native mining failed")
    check(inventory.get_item_count{name="atan-pollution-filter", quality="normal"} == 12, "consumed input refund was lost or duplicated")
    check(inventory.get_item_count{name="atan-used-pollution-filter", quality="normal"} == 5, "output transfer changed")
    check(inventory.get_item_count{name=BASE, quality="rare"} == 1, "mined building quality changed")
    check(#surface.find_entities_filtered{position=position, radius=3, type="item-entity"} == 0, "unexpected ground spill")
    inventory.destroy()
    return {name=job.name, before=before, after=after, state_preserved_except_native_energy_cap=true,
        energy_cap=expected.energy, energy_clamped=before.energy-after.energy, idempotent=true, consumed_input_refund=12,
        used_filters=5, rare_building=1, ground_spill=false}
end
script.on_init(function()
    game.speed = 10
    game.forces.player.recipes["atan-pollution-scrubbing"].enabled = true
    game.forces.player.unlock_quality("rare")
    local surface = game.create_surface("esir-air-qc", {width=128, height=128})
    surface.set_property("pressure", 1000)
    surface.request_to_generate_chunks({0,0}, 2)
    surface.force_generate_chunk_requests()
    storage.jobs = {}
    storage.cases = {}
    for index, name in ipairs({"immediate", "after-native-reload"}) do
        local entity = surface.create_entity{name=BASE, position={index * 8,0}, quality="rare", force="player", direction=defines.direction.east}
        check(entity ~= nil, "fixture placement")
        entity.get_inventory(defines.inventory.crafter_input).insert{name="atan-pollution-filter", count=12}
        entity.get_inventory(defines.inventory.crafter_output).insert{name="atan-used-pollution-filter", count=5}
        storage.jobs[index] = {name=name, entity=entity}
    end
    local normal = surface.create_entity{name=BASE, position={-8,0}, force="player"}
    local normal_unit = normal.unit_number
    script.raise_script_built{entity=normal}
    check(normal.valid and normal.unit_number == normal_unit and normal.name == BASE, "normal quality must remain unchanged")
    storage.normal_unchanged = true
end)
script.on_load(function() loaded = true end)
script.on_event(defines.events.on_tick, function(event)
    if storage.done then
        if loaded then helpers.write_file("air-second-reload.json", helpers.table_to_json{passed=true, tick=event.tick}, false) end
        loaded = false
        return
    end
    if storage.awaiting_reload then
        if not loaded then return end
        local entity = storage.jobs[2].entity
        local after_load = snapshot(entity)
        local expected = {}
        for key, value in pairs(storage.saved_snapshot) do expected[key] = value end
        -- on_tick runs after one native entity update. Script-disabled furnaces
        -- still pay their ordinary electric drain during that first tick.
        local drain = entity.prototype.electric_energy_source_prototype.drain
        check(math.abs(after_load.energy - math.max(0, expected.energy - drain)) < 0.000001, "native reload energy differs from one tick of drain")
        expected.energy = after_load.energy
        same(expected, after_load, "native reload")
        storage.reload_drain = drain
        storage.cases[2] = replace_and_mine(storage.jobs[2])
        storage.done = true
        helpers.write_file("air-scrubber.json", helpers.table_to_json{passed=true, version=script.active_mods.base,
            normal_unchanged=storage.normal_unchanged, native_midcraft_reload=true, cases=storage.cases,
            native_reload_drain=storage.reload_drain,
            limits={"No native player/robot placement, GUI or multiplayer-client claim"}}, false)
        game.server_save("air-complete")
        loaded = false
        return
    end
    loaded = false
    for _, job in ipairs(storage.jobs) do job.entity.energy = job.entity.electric_buffer_size end
    if event.tick >= 60 then
        for _, job in ipairs(storage.jobs) do
            local entity = job.entity
            check(entity.crafting_progress > 0, "machine did not begin real crafting; status=" .. entity.status)
            entity.disabled_by_script = true
            entity.health = entity.max_health * 0.4
            entity.bonus_progress = 0.375
            entity.products_finished = 17
            entity.minable_flag = false
            entity.destructible = false
            entity.operable = false
            entity.rotatable = false
        end
        storage.cases[1] = replace_and_mine(storage.jobs[1])
        storage.saved_snapshot = snapshot(storage.jobs[2].entity)
        storage.awaiting_reload = true
        game.server_save("air-midpoint")
    end
end)
