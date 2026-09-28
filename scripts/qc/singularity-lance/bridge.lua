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
    cues = function(id)
        local record = storage.ei.singularity_lance.lances[id]
        return {beam = record.beam, mark = record.mark, shape = record.beam_shape,
            endpoint = record.beam_endpoint, band = record.wound_band}
    end,
    old_presentation = function(id, age)
        local runtime = storage.ei.singularity_lance
        local record = runtime.lances[id]
        for _, object in pairs({record.beam, record.mark}) do if object.valid then object.destroy() end end
        record.beam = rendering.draw_sprite{sprite = "ei-singularity-lance-beam-axial", surface = record.entity.surface,
            target = record.entity.position, time_to_live = 14}
        record.mark = rendering.draw_sprite{sprite = "ei-singularity-lance-wound-3", surface = record.target.surface,
            target = {entity = record.target}, time_to_live = 120}
        record.wound_tick = game.tick - (age or 0)
        runtime.presentation_revision = nil
        return {beam = record.beam, mark = record.mark, wound_tick = record.wound_tick}
    end,
})
