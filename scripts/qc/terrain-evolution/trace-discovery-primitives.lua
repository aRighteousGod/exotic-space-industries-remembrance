            -- Diagnostic-only native iterator split; exact original control flow.
            local trace_enabled=root.__qc_trace_until and (root.__qc_trace_tick or 0)<=root.__qc_trace_until
                and (root.__qc_trace_tick or 0)>=(root.__qc_trace_from or 0)
            local create_timer
            if not entry.iterator or not entry.iterator.valid then
                if trace_enabled then create_timer=helpers.create_profiler() end
                entry.iterator=entry.surface.get_chunks()
                if create_timer then create_timer.stop() end
            end
            local next_timer=trace_enabled and helpers.create_profiler()
            local chunk=entry.iterator()
            if next_timer then next_timer.stop() end
            if create_timer then
                log({"","ECOLOGY_COMPONENT name=iterator_create tick="..root.__qc_trace_tick.." elapsed=",create_timer,
                    " surface="..entry.surface.index})
            end
            if next_timer then
                log({"","ECOLOGY_COMPONENT name=iterator_next tick="..root.__qc_trace_tick.." elapsed=",next_timer,
                    " surface="..entry.surface.index.." chunk="..(chunk and (chunk.x..":"..chunk.y) or "end")})
            end
