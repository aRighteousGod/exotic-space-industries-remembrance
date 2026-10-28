-- Startup/tick smoke only; explicit limits prevent mistaking this for integration acceptance.
script.on_event(defines.events.on_tick,function(event)
    if storage.done or event.tick<600 then return end
    storage.done=true
    helpers.write_file("optional-smoke.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,tick=event.tick,
        crystal_recipes=prototypes.mod_data["esir-qc-optional-crystals"].data.recipes,
        rocket_productivity=prototypes.mod_data["esir-qc-optional-productivity"] and prototypes.mod_data["esir-qc-optional-productivity"].data,
        mods=script.active_mods,limits={"No optional progression, migration, manual interaction, audio or multiplayer acceptance"}},false)
end)
