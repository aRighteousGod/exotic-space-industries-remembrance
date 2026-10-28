-- Real circuit networks, neutron invalidation, paste and helper lifecycle.
local manual={fuel_1="ei-heated-deuterium",fuel_2="ei-heated-tritium",temperature="low",injection_rate="high"}
local function check(condition,label)
    table.insert(storage.report.checks,{name=label,passed=condition and true or false})
    if not condition then table.insert(storage.report.failures,label) end
end
local function signals(values)
    local section=storage.source.get_control_behavior().get_section(1)
    for i=1,section.filters_count do section.clear_slot(i) end
    for index,pair in ipairs(values) do
        section.set_slot(index,{value={type="virtual",name="ei-fusion-set-"..pair[1],quality="normal"},min=pair[2]})
    end
end
local function service(tick)
    remote.call("esir-fusion-qc","service",tick)
    return remote.call("esir-fusion-qc","record",storage.reactor)
end
local function maintain_source()
    local entity=storage.reactor
    if not entity.valid then return end
    entity.energy=1e12
    for i=1,entity.fluids_count do
        local filter=entity.get_fluid_filter(i)
        if filter and filter.name=="ei-hot-coolant" then entity.clear_fluid(i)
        elseif filter then entity.set_fluid(i,{name=filter.name,amount=200,
            temperature=prototypes.fluid[filter.name].default_temperature}) end
    end
end

script.on_event(defines.events.on_tick,function(event)
    if event.tick==1 then
        local surface=game.create_surface("fusion-actors-qc",{width=192,height=128,peaceful_mode=true})
        surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.report={engine=script.active_mods.base,checks={},failures={}}
        storage.surface=surface
        storage.reactor=assert(surface.create_entity{name="ei-fusion-reactor",position={0,0},force="player",raise_built=true})
        storage.copy=assert(surface.create_entity{name="ei-fusion-reactor",position={40,0},force="player",raise_built=true})
        storage.collector=assert(surface.create_entity{name="ei-neutron-collector",position={9,0},force="player",raise_built=true})
        storage.source=assert(surface.create_entity{name="constant-combinator",position={-7,0},force="player"})
        check(remote.call("esir-fusion-qc","status").records==2,"script-raised construction registers both reactors")
        remote.call("esir-fusion-qc","select",storage.reactor,manual,"manual",event.tick)
        assert(storage.source.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
            storage.reactor.get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.player))
    elseif storage.reactor then
        if event.tick==61 then
            local collector=remote.call("esir-fusion-qc","collector_state",storage.collector)
            check(collector.source==storage.reactor.unit_number,"collector binds native working fusion source")
            check(collector.efficiency>0 and not collector.disabled,"low-temperature flux enables collector")
            signals{{"fuel-1",4},{"fuel-2",4},{"temperature",3},{"injection",1}}
            remote.call("esir-fusion-qc","select",storage.reactor,manual,"circuit",event.tick)
        elseif event.tick==123 then
            local entry=service(event.tick)
            check(entry.control_source=="circuit","circuit mode remains selected")
            check(entry.manual_selection.fuel_1==manual.fuel_1 and entry.manual_selection.injection_rate==manual.injection_rate,"manual fallback retained")
            check(entry.effective_selection.fuel_1=="ei-heated-helium-3" and entry.effective_selection.fuel_2=="ei-heated-helium-3"
                and entry.effective_selection.temperature=="high" and entry.effective_selection.injection_rate=="low","all four native circuit commands apply")
            check(entry.signal_cache.power==7560 and entry.signal_cache.coolant_rate==18900 and entry.signal_cache.neutron_flux==0,"circuit telemetry reports authored output and flux")
            local collector=remote.call("esir-fusion-qc","collector_state",storage.collector)
            check(collector.efficiency==0 and collector.disabled,"high-temperature zero flux disables collector")
            signals{{"temperature",1}}
        elseif event.tick==185 then
            local entry=service(event.tick)
            check(entry.effective_selection.fuel_1==manual.fuel_1 and entry.effective_selection.fuel_2==manual.fuel_2
                and entry.effective_selection.injection_rate==manual.injection_rate,"partial signals use manual fallbacks")
            check(entry.signal_cache.power==1600 and entry.signal_cache.neutron_flux==180,"partial circuit telemetry is not self-feedback")
            local collector=remote.call("esir-fusion-qc","collector_state",storage.collector)
            check(collector.efficiency>0 and not collector.disabled,"collector recovers after recipe change")
            remote.call("esir-fusion-qc","paste",storage.reactor,storage.copy,event.tick)
            local copied=remote.call("esir-fusion-qc","record",storage.copy)
            check(copied.control_source=="circuit" and copied.manual_selection.injection_rate=="high","settings paste preserves control and fallback")
            storage.old_proxy=entry.wire_proxy.unit_number
            entry.wire_proxy.destroy()
        elseif event.tick==187 then
            local entry=service(event.tick)
            check(entry.wire_proxy.valid and entry.wire_proxy.unit_number~=storage.old_proxy,"missing telemetry proxy is recreated")
            check(entry.wire_proxy_connected,"recreated proxy reconnects")
            local orphan=storage.surface.create_entity{name="ei-fusion-reactor-circuit-interface",position={70,0},force="player"}
            local live_proxy=entry.wire_proxy.unit_number
            remote.call("esir-fusion-qc","repair",event.tick)
            check(not orphan.valid,"repair removes unowned telemetry helper")
            check(remote.call("esir-fusion-qc","record",storage.reactor).wire_proxy.unit_number==live_proxy,"repair retains valid owned helper")
        elseif event.tick==200 then
            storage.reactor.destroy{raise_destroy=true}
            local remaining=remote.call("esir-fusion-qc","status")
            check(remaining.pending==1 and remaining.units[1]==storage.copy.unit_number,"removal keeps dense service index valid")
            storage.copy.destroy{raise_destroy=true}
            local state=remote.call("esir-fusion-qc","status")
            check(state.records==0,"script-raised destruction unregisters reactors")
            check(state.pending==0,"destroyed reactors do not leave scheduled work")
            check(storage.surface.count_entities_filtered{name="ei-fusion-reactor-circuit-interface"}==0,"destruction removes all telemetry helpers")
            storage.report.passed=#storage.report.failures==0
            helpers.write_file("fusion-actors.json",helpers.table_to_json(storage.report),false)
            assert(storage.report.passed,"Fusion actor failures: "..table.concat(storage.report.failures,", "))
            log("FUSION ACTORS COMPLETE")
        end
    end
    if storage.reactor then maintain_source() end
end)
