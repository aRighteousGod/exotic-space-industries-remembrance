-- Private global record/world reconciliation, using the existing NSBC test hook.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local complete=false
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if complete then return end
        complete=true
        local records=remote.call("nsbc-qc","custody")
        local owned,names={},{}
        for name in pairs(prototypes.mod_data["nsb-beacon-data"].data.definitions) do names[name.."-source"]=true end
        for _,name in ipairs{"nsb-internal-manager","nsb-internal-monitor","nsb-internal-mimic"} do names[name]=true end
        local helpers_count,world_count,bodies=0,0,0
        for _,row in ipairs(records) do
            local record=remote.call("nonstandard-beacons","get-beacon-data",row.unit)
            assert(record and record.beacon.valid and record.phase=="attached","Unattached live record")
            for _,key in ipairs{"source","manager","monitor","mimic"} do
                local helper=record[key]
                if helper then
                    assert(helper.valid and not owned[helper.unit_number],"Missing or multiply owned "..key)
                    owned[helper.unit_number]=row.unit;helpers_count=helpers_count+1
                    assert(helper.surface==record.beacon.surface and helper.force==record.beacon.force,"Helper surface/force mismatch")
                end
            end
        end
        for _,surface in pairs(game.surfaces) do
            for name in pairs(names) do
                for _,helper in pairs(surface.find_entities_filtered{name=name}) do
                    assert(owned[helper.unit_number],"Orphan NSBC helper: "..name.." "..helper.unit_number)
                    world_count=world_count+1
                end
            end
            for name in pairs(prototypes.mod_data["nsb-beacon-data"].data.definitions) do
                for _,entity in pairs(surface.find_entities_filtered{name=name}) do
                    assert(remote.call("nonstandard-beacons","get-beacon-data",entity.unit_number),"Unregistered managed beacon")
                    bodies=bodies+1
                end
            end
        end
        assert(bodies==#records and world_count==helpers_count,"Record/world count mismatch")
        helpers.write_file("beacon-ownership.json",helpers.table_to_json{
            passed=true,engine=script.active_mods.base,beacons=bodies,helpers=world_count,orphan_helpers=0,
            unregistered_bodies=0,multiply_owned_helpers=0,all_surfaces=true},false)
        log("BEACON OWNERSHIP COMPLETE")
    end)
end
