do
    local old=script.get_event_handler(defines.events.on_tick)
    local done=false
    script.on_event(defines.events.on_tick,function(event)
        old(event)
        if done then return end
        local s=game.surfaces.nauvis
        local names={"ei-rocket-launch-pollution","stone-furnace","rocket-silo"}
        storage.pollution_probe=storage.pollution_probe or {tick=event.tick,rows={}}
        local probe=storage.pollution_probe
        probe.timeline=probe.timeline or {}
        if event.tick==probe.tick then
            for _,name in ipairs(names) do
                local before=s.pollution_statistics.get_input_count(name)
                s.pollute({0,0},123.456,name)
                local string_count=s.pollution_statistics.get_input_count(name)
                s.pollute({0,0},123.456,prototypes.entity[name])
                probe.rows[#probe.rows+1]={name=name,before=before,after_string=string_count,
                    after_prototype=s.pollution_statistics.get_input_count(name)}
            end
        end
        probe.timeline[#probe.timeline+1]={age=event.tick-probe.tick,
            graph=s.pollution_statistics.get_input_count(names[1])}
        if event.tick==probe.tick+10 then
            for _,row in ipairs(probe.rows) do row.after_ten=s.pollution_statistics.get_input_count(row.name) end
            probe.all_inputs=s.pollution_statistics.input_counts;probe.passed=true
            helpers.write_file("pollution-probe.json",helpers.table_to_json(probe),false)
            done=true
        end
    end)
end
