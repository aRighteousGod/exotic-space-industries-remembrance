-- Appended only to the disposable ESIR copy. Production keeps its normal dispatcher.
remote.add_interface("esir-railgun-qc", {
    proxy = function(turret)
        return storage.ei.railgun_cooling.turrets_by_unit[turret.unit_number].proxy
    end,
    shot = function(turret)
        ei_railgun_cooling.on_script_trigger_effect{
            effect_id = "ei-railgun-cooling-shot", source_entity = turret, tick = game.tick,
        }
    end,
    rebuild = function()
        ei_railgun_cooling.rebuild_runtime_state("inserter-qc", game.tick)
    end,
})
