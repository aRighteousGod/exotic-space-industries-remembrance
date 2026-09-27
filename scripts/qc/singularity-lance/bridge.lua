remote.add_interface("lance-fixture", {
    shot = function(source, target, position, tick)
        ei_singularity_lance.on_script_trigger_effect{effect_id = "ei-singularity-lance-shot", source_entity = source,
            target_entity = target, target_position = position or (target and target.valid and target.position), tick = tick or game.tick}
    end,
    sync = function(force) ei_singularity_lance.on_scripted_research_burst(force, game.tick) end,
    normal_research = function(research) ei_singularity_lance.on_research_finished{research = research, tick = game.tick} end,
    service = function(tick) return ei_singularity_lance.update(1, {tick = tick or game.tick}) end,
    snapshot = function() return ei_singularity_lance.get_qc_snapshot() end,
    configure = function(options) return ei_singularity_lance.configure_qc(options) end,
    legacy = function(value) storage.ei.singularity_lance = value; ei_singularity_lance.check_global() end,
    check = function() ei_singularity_lance.check_global() end,
})
