-- Private native lab research and Rocket silo completion; real dispatcher runs.
do
    local prior_tick=script.get_event_handler(defines.events.on_tick)
    local prior_research=script.get_event_handler(defines.events.on_research_finished)
    script.on_event(defines.events.on_research_finished,function(event)
        prior_research(event)
        if event.research.force.name:find('esir-qc-science-',1,true)==1 or event.research.force.name=='esir-qc-travel' then
            storage.upgrade_progression.events[#storage.upgrade_progression.events+1]={name=event.research.name,
                force=event.research.force.name,by_script=event.by_script,tick=event.tick}
        end
    end)
    local function check(ok,label) assert(ok,'UPGRADE PROGRESSION: '..label) end
    script.on_event(defines.events.on_tick,function(event)
        prior_tick(event)
        if storage.upgrade_progression and storage.upgrade_progression.done then return end
        if not storage.upgrade_progression then
            local state={events={},cases={},started=event.tick};storage.upgrade_progression=state
            local surface=game.create_surface('esir-upgrade-research',{width=128,height=128})
            surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities()) do entity.destroy() end
            for index,ingredients in ipairs{{'ei-dark-age-tech'},{'space-science-pack'},{'ei-dark-age-tech','space-science-pack'}} do
                local name='esir-qc-science-'..index
                local force=game.create_force(name)
                local lab=surface.create_entity{name='lab',position={index*8,0},force=force}
                for _,item in ipairs(ingredients) do check(lab.insert{name=item,count=4}==4,'lab accepts '..item) end
                check(force.add_research(name),'queue '..name)
                state.cases[#state.cases+1]={lab=lab,force=force,name=name,ingredients=ingredients}
            end
            local force=game.create_force('esir-qc-travel');state.travel=force
            local function complete_prerequisites(technology)
                for _,prerequisite in pairs(technology.prerequisites) do
                    if not prerequisite.researched then complete_prerequisites(prerequisite);prerequisite.researched=true end
                end
            end
            local silo=force.technologies['rocket-silo']
            complete_prerequisites(silo)
            force.unlock_travel_to_space_platforms=false
            check(force.add_research('rocket-silo'),'queue Rocket silo')
            force.research_progress=1
        end
        local state=storage.upgrade_progression
        for _,case in ipairs(state.cases) do case.lab.energy=1000000 end
        if event.tick-state.started<300 then return end
        local cases={}
        for _,case in ipairs(state.cases) do
            check(case.force.technologies[case.name].researched,'native lab finishes '..case.name)
            local remaining={}
            for _,name in ipairs(case.ingredients) do
                remaining[name]=case.lab.get_item_count(name)
                check(remaining[name]==1,'exactly three science consumed: '..name)
            end
            local found=false
            for _,finished in ipairs(state.events) do
                if finished.force==case.force.name and finished.name==case.name and not finished.by_script then found=true end
            end
            check(found,'native normal research event '..case.name)
            cases[#cases+1]={name=case.name,ingredients=case.ingredients,remaining=remaining}
        end
        check(state.travel.technologies['rocket-silo'].researched,'native Rocket silo completion')
        check(not state.travel.unlock_travel_to_space_platforms,'Rocket silo leaves personal travel locked')
        local normal=false
        for _,finished in ipairs(state.events) do
            if finished.force=='esir-qc-travel' and finished.name=='rocket-silo' and not finished.by_script then normal=true end
        end
        check(normal,'Rocket silo normal completion event')
        state.done=true
        helpers.write_file('upgrade-progression.json',helpers.table_to_json{passed=true,cases=cases,
            platform_travel=false,events=state.events,
            limits={'Lab technologies are short private fixtures; no full recipe/science reachability or GUI claim'}},false)
        log('UPGRADE PROGRESSION COMPLETE')
    end)
end
