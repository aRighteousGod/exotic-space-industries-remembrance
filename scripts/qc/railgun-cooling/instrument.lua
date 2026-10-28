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
    snapshot = function()
        local result = {}
        local modern = script.active_mods.base:match("^2%.1%.") ~= nil
        local runtime = storage.ei.railgun_cooling
        for unit, record in pairs(runtime.turrets_by_unit) do
            local proxy = record.proxy
            local cold, hot
            if modern then cold, hot = proxy.get_fluid(1), proxy.get_fluid(2)
            else cold, hot = proxy.fluidbox[1], proxy.fluidbox[2] end
            result[unit] = {proxy = proxy.unit_number, heat = record.heat_debt,
                last_shot = record.last_shot_tick, last_effect = record.last_cooling_effect_tick,
                due = runtime.recovery_pending_by_unit[unit], health = record.turret.health,
                cold = cold and cold.amount or 0, cold_temperature = cold and cold.temperature,
                hot = hot and hot.amount or 0, hot_temperature = hot and hot.temperature,
                owner_disabled = record.disabled_by_railgun_cooling, blocked = record.blocked_reason}
        end
        return result
    end,
})
