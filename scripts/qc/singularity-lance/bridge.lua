remote.add_interface("lance-fixture", {
    shot = function(source, target, position, tick)
        ei_singularity_lance.on_script_trigger_effect{effect_id = "ei-singularity-lance-shot", source_entity = source,
            target_entity = target, target_position = position or (target and target.valid and target.position), tick = tick or game.tick}
    end,
    sync = function(force) ei_singularity_lance.on_scripted_research_burst(force, game.tick) end,
    normal_research = function(research) ei_singularity_lance.on_research_finished{research = research, tick = game.tick} end,
    service = function(tick) return ei_singularity_lance.update(1, {tick = tick or game.tick}) end,
    snapshot = function(tick) return ei_singularity_lance.get_qc_snapshot(tick) end,
    configure = function(options) return ei_singularity_lance.configure_qc(options) end,
    legacy = function(value) storage.ei.singularity_lance = value; ei_singularity_lance.check_global() end,
    check = function(tick) ei_singularity_lance.check_global(tick and {tick = tick} or nil) end,
    cues = function(id)
        local record = storage.ei.singularity_lance.lances[id]
        return {beam = record.beam, mark = record.mark, shape = record.beam_shape,
            endpoint = record.beam_endpoint, band = record.wound_band, extensions = record.extensions}
    end,
    packets = function()
        local buckets=storage.ei.singularity_lance.buckets
        local queued,result={},{}
        for _,bucket in pairs(buckets) do for _,packet in ipairs(bucket) do queued[packet]=true end end
        for due,bucket in pairs(buckets) do
            for index,packet in ipairs(bucket) do
                result[#result+1]={due=due,index=index,phase=packet.phase,damage=packet.damage,
                    core_damage=packet.core_damage,radius=packet.radius,cap=packet.cap,
                    include_primary=packet.include_primary,warning=packet.warning,force_index=packet.force_index,
                    echo_is_queued=packet.echo and queued[packet.echo] or false}
            end
        end
        table.sort(result,function(a,b) return a.due==b.due and a.index<b.index or a.due<b.due end)
        return result
    end,
    migrate_schema11 = function()
        -- Synthetic identity check complements the actual old-save reload.
        local runtime=storage.ei.singularity_lance
        local lances,registrations,buckets=runtime.lances,runtime.registrations,runtime.buckets
        for _,bucket in pairs(buckets) do
            for _,packet in ipairs(bucket) do
                assert(not packet.echo and packet.phase~="echo")
                packet.damage,packet.radius,packet.cap=250,3,8
                packet.core_damage,packet.core_radius,packet.include_primary=nil,nil,nil
                packet.phase,packet.due=nil,nil
            end
        end
        runtime.version=11
        ei_singularity_lance.check_global()
        local migrated=storage.ei.singularity_lance
        return {runtime=migrated==runtime,lances=migrated.lances==lances,
            registrations=migrated.registrations==registrations,buckets=migrated.buckets==buckets}
    end,
    old_presentation = function(id, age)
        local runtime = storage.ei.singularity_lance
        local record = runtime.lances[id]
        for _, object in pairs({record.beam, record.mark}) do if object.valid then object.destroy() end end
        for _, segment in pairs(record.extensions or {}) do if segment.beam and segment.beam.valid then segment.beam.destroy() end end
        record.extensions = nil
        record.beam = rendering.draw_sprite{sprite = "ei-singularity-lance-beam-axial", surface = record.entity.surface,
            target = record.entity.position, time_to_live = 14}
        record.mark = rendering.draw_sprite{sprite = "ei-singularity-lance-wound-3", surface = record.target.surface,
            target = {entity = record.target}, time_to_live = 120}
        record.wound_tick = game.tick - (age or 0)
        runtime.presentation_revision = nil
        return {beam = record.beam, mark = record.mark, wound_tick = record.wound_tick}
    end,
})
