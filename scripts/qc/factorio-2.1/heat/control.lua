-- Paired native 2.0/2.1 heat topology and output probe on unchanged identities.
local function modern() return script.active_mods.base:sub(1,3)=="2.1" end
script.on_init(function()
    local surface=game.create_surface("esir-heat-parity",{width=512,height=512})
    surface.request_to_generate_chunks({0,0},8)
    surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    storage.cases={}
    for family,name in ipairs{"ei-burner-heater","ei-fluid-heater"} do
        for index,layout in ipairs{{label="single"},{label="north",{0,-3}},{label="east",{3,0}},
            {label="south",{0,3}},{label="west",{-3,0}},{label="diagonal",{3,3}},
            {label="four",{0,-3},{3,0},{0,3},{-3,0}},{label="mixed",mixed=true,{3,0}}} do
            local position={x=(index-4)*40,y=(family-1)*60}
            local entities={surface.create_entity{name=name,position=position,force="player",raise_built=true}}
            for _,offset in ipairs(layout) do
                local neighbour=layout.mixed and (family==1 and "ei-fluid-heater" or "ei-burner-heater") or name
                entities[#entities+1]=surface.create_entity{name=neighbour,position={position.x+offset[1],position.y+offset[2]},force="player",raise_built=true}
            end
            for _,entity in ipairs(entities) do
                entity.temperature=20
                if entity.burner then assert(entity.get_fuel_inventory().insert{name="coal",count=20}==20)
                elseif modern() then entity.set_fluid(1,{name="light-oil",amount=200,temperature=25})
                else entity.fluidbox[1]={name="light-oil",amount=200,temperature=25} end
            end
            if modern() then
                -- set_fluid addresses a local share after native segment merge;
                -- seed the same physical total as the old separate input buffers.
                local segments={}
                for _,entity in ipairs(entities) do
                    if not entity.burner then
                        local id=entity.get_fluid_segment_id(1)
                        segments[id]=segments[id] or {entity=entity,amount=0}
                        segments[id].amount=segments[id].amount+200
                    end
                end
                for _,segment in pairs(segments) do
                    segment.entity.set_fluid_segment_fluid(1,{name="light-oil",amount=segment.amount,temperature=25})
                end
            end
            storage.cases[#storage.cases+1]={name=name,layout=layout.label,entities=entities}
        end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done or (event.tick~=60 and event.tick~=120) then return end
    local rows={}
    for _,case in ipairs(storage.cases) do
        local entity=case.entities[1]
        local fluids={}
        for index=1,entity.fluids_count do fluids[index]=entity.get_fluid(index) or false end
        local capacity,segment
        if not entity.burner then
            capacity=modern() and entity.get_fluid_segment_capacity(1) or entity.fluidbox.get_capacity(1)
            segment=modern() and entity.get_fluid_segment_fluid(1) or entity.fluidbox.get_fluid_segment_contents(1)
        end
        local total,seen=0,{}
        for _,member in ipairs(case.entities) do
            if not member.burner then
                local id=modern() and member.get_fluid_segment_id(1) or member.fluidbox.get_fluid_segment_id(1)
                if not modern() then total=total+member.get_fluid_count() end
                if not seen[id] then
                    seen[id]=true
                    if modern() then total=total+member.get_fluid_segment_fluid(1).amount
                    else total=total+(member.fluidbox.get_fluid_segment_contents(1)["light-oil"] or 0) end
                end
            end
        end
        rows[#rows+1]={name=case.name,layout=case.layout,bonus=entity.neighbour_bonus,
            temperature=entity.temperature,heat_neighbours=#entity.heat_neighbours,
            energy=entity.energy,fluid_storages=fluids,total_fluids=entity.get_fluid_contents(),
            segment_capacity=capacity,segment_fluid=segment,
            physical_fluid_total=total,
            fuel_remaining=entity.burner and entity.burner.remaining_burning_fuel,
            fluid=not entity.burner and (modern() and entity.get_fluid(1) or entity.fluidbox[1]) or nil}
    end
    helpers.write_file("heat-parity-" .. event.tick .. ".json",helpers.table_to_json{engine=script.active_mods.base,tick=event.tick,cases=rows,
        fluid_fuel_value=prototypes.fluid["light-oil"].fuel_value},false)
    storage.done=event.tick==120
end)
