-- Private native research and exact migration-body checks; never packaged.
do
    local prior_tick=script.get_event_handler(defines.events.on_tick)
    local prior_research=script.get_event_handler(defines.events.on_research_finished)
    local function check(ok,label) assert(ok,'NATIVE PLATFORM TRAVEL: '..label) end
    script.on_event(defines.events.on_research_finished,function(event)
        prior_research(event)
        if event.research.force.name:find('esir-qc-platform-',1,true)==1 then
            storage.platform_travel_qc.events[#storage.platform_travel_qc.events+1]={
                force=event.research.force.name,name=event.research.name,by_script=event.by_script}
        end
    end)
    local function prerequisites(technology)
        for _,prerequisite in pairs(technology.prerequisites) do
            if not prerequisite.researched then prerequisites(prerequisite);prerequisite.researched=true end
        end
    end
    -- Local marker resets on each control-stage load without replacing ESIR's
    -- on_load lifecycle handler or writing persistent state during loading.
    local loaded=true
    script.on_event(defines.events.on_tick,function(event)
        prior_tick(event)
        local state=storage.platform_travel_qc
        if not state then
            loaded=false
            state={events={},cases={},started=event.tick};storage.platform_travel_qc=state
            for index,name in ipairs{'rocket-silo','planet-discovery-vulcanus','planet-discovery-gleba','planet-discovery-fulgora'} do
                local force=game.create_force('esir-qc-platform-'..index)
                prerequisites(force.technologies[name])
                check(not force.unlock_travel_to_space_platforms,'prerequisites leave travel locked: '..name)
                force.character_running_speed_modifier=0.37
                check(force.add_research(name),'queue '..name);force.research_progress=1
                state.cases[#state.cases+1]={force=force,name=name,expected=index~=1}
            end
            return
        end
        if state.done then
            if loaded then
                for _,case in ipairs(state.cases) do
                    check(case.force.unlock_travel_to_space_platforms==case.expected,'reload '..case.name)
                    check(case.force.character_running_speed_modifier==0.37,'reload unrelated bonus')
                end
                helpers.write_file('platform-travel-reload.json',helpers.table_to_json{passed=true,cases=state.results},false)
                loaded=false
            end
            if game.is_multiplayer() and not state.saved then state.saved=true;game.server_save('platform-travel') end
            return
        end
        if event.tick-state.started<10 then return end
        local results={}
        for _,case in ipairs(state.cases) do
            check(case.force.technologies[case.name].researched,'native completion '..case.name)
            check(case.force.unlock_travel_to_space_platforms==case.expected,'native travel effect '..case.name)
            local normal=false
            for _,finished in ipairs(state.events) do
                if finished.force==case.force.name and finished.name==case.name and not finished.by_script then normal=true end
            end
            check(normal,'ordinary research event '..case.name)
            -- Simulate the new flag missing on an already researched 2.0 force;
            -- execute the exact shipping migration body inside ESIR's context.
            case.force.unlock_travel_to_space_platforms=false
        end
        platform_travel_qc_migrate()
        for _,case in ipairs(state.cases) do
            check(case.force.unlock_travel_to_space_platforms==case.expected,'migration adopts discovered travel '..case.name)
            check(case.force.character_running_speed_modifier==0.37,'migration preserves unrelated bonus')
            results[#results+1]={technology=case.name,travel_unlocked=case.expected,native_research=true,migration_body=true}
        end
        state.results=results;state.done=true
        helpers.write_file('platform-travel.json',helpers.table_to_json{passed=true,cases=results,events=state.events,
            limits={'Already-researched discovery cases execute the exact migration body on native 2.1 forces; actual 2.0 donor migration is checked separately'}},false)
        log('NATIVE PLATFORM TRAVEL COMPLETE')
    end)
end
