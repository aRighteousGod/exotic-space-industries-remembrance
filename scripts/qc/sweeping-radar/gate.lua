local tests={}
local function check(name,condition,detail)
    tests[#tests+1]={name=name,pass=condition==true,detail=detail}
end
local function wire(a,b,color)
    local id=defines.wire_connector_id["circuit_"..color]
    assert(a.get_wire_connector(id,true).connect_to(b.get_wire_connector(id,true),false,defines.wire_origin.script))
end
local function signal(entity,name,value)
    local behavior=entity.get_or_create_control_behavior()
    local section=behavior.get_section(1) or behavior.add_section()
    section.set_slot(1,{value={type="virtual",name=name,quality="normal"},min=value})
end
script.on_init(function()
    local surface=game.create_surface("radar-gate",{width=512,height=512,autoplace_controls={}})
    surface.request_to_generate_chunks({0,0},8)
    surface.force_generate_chunk_requests()
    storage.shells={}
    for name,quality in pairs(prototypes.quality) do
        if quality.level>=0 then
            local force=game.create_force("radar-gate-"..name)
            local radar=surface.create_entity{name="ei-radar-qc-shell",position={0,0},force=force,quality=name}
            radar.disabled_by_script=true
            force.clear_chart(surface)
            storage.shells[#storage.shells+1]=radar
        end
    end
    local active_force=game.create_force("radar-gate-active")
    storage.active=surface.create_entity{name="ei-radar-qc-shell",position={40,0},force=active_force}
    active_force.clear_chart(surface)
    local force=storage.shells[1].force
    local radar=storage.shells[1]
    storage.input=surface.create_entity{name="constant-combinator",position={-3,0},force=force}
    storage.output=surface.create_entity{name="ei-sweeping-radar-output",position={0,0},force=force}
    signal(storage.input,"signal-A",17)
    signal(storage.output,"signal-B",29)
    wire(storage.input,radar,"red");wire(storage.output,radar,"green")
    storage.buffer=surface.create_entity{name="ei-sweeping-radar-power",position={0,0},force=force}
    storage.buffer.energy=0
    storage.source=surface.create_entity{name="ei-radar-qc-source",position={4,4},force=force}
    surface.create_entity{name="substation",position={4,0},force=force}
    storage.events=0
    storage.leaks=0
end)
script.on_event(defines.events.on_sector_scanned,function(event)
    if event.radar==storage.active then storage.events=storage.events+1
    else storage.leaks=storage.leaks+1 end
end)
script.on_event(defines.events.on_tick,function(event)
    if event.tick==60 then
        local radar=storage.shells[1]
        local red=defines.wire_connector_id.circuit_red
        local green=defines.wire_connector_id.circuit_green
        check("red-input",radar.get_signal({type="virtual",name="signal-A"},red)==17)
        check("green-output",radar.get_signal({type="virtual",name="signal-B"},green)==29)
        check("wire-isolation",radar.get_signal({type="virtual",name="signal-B"},red)==0)
        check("buffer-refill",storage.buffer.energy>0,storage.buffer.energy)
        local before=storage.buffer.energy
        storage.buffer.energy=before-1234
        check("exact-joule-deduction",math.abs(storage.buffer.energy-(before-1234))<0.001)
        signal(storage.input,"signal-A",0)
    elseif event.tick==90 then
        check("zero-input",storage.shells[1].get_signal({type="virtual",name="signal-A"},defines.wire_connector_id.circuit_red)==0)
    elseif event.tick==1200 then
        for _,radar in ipairs(storage.shells) do
            local clean=true
            for x=-4,4 do for y=-4,4 do
                if radar.force.is_chunk_charted(radar.surface,{x,y})
                    or radar.force.is_chunk_requested_for_charting(radar.surface,{x,y}) then clean=false end
            end end
            check("no-native-chart-requests-"..radar.quality.name,clean)
        end
        check("no-native-events",storage.leaks==0,storage.leaks)
        check("positive-control",storage.events>0 and (storage.active.force.is_chunk_charted(storage.active.surface,{1,0})
            or storage.active.force.is_chunk_requested_for_charting(storage.active.surface,{1,0})),storage.events)
        local pass=true
        for _,test in ipairs(tests) do if not test.pass then pass=false end end
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=pass,tests=tests}),false)
    end
end)
