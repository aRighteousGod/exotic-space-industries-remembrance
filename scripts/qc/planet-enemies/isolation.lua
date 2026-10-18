-- Native Nauvis placement with foreign planetary controls disabled.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local complete=false
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if complete then return end
        complete=true
        local report={all_pass=true,checks={}}
        for _,seed in ipairs({1000,421337}) do
            local baseline
            for _,control in ipairs({"default","ei-vulcanus-explosive-enemies","ei-aquilo-cold-enemies"}) do
                local settings=table.deepcopy(prototypes.space_location.nauvis.map_gen_settings)
                settings.seed=seed
                if control~="default" then settings.autoplace_controls[control]={frequency=0,size=0,richness=1} end
                local surface=game.create_surface("planet-enemy-isolation-"..seed.."-"..control,settings)
                for _,position in ipairs({{0,0},{1024,1024},{2048,0},{0,2048}}) do surface.request_to_generate_chunks(position,3) end
                surface.force_generate_chunk_requests()
                local rows={}
                for _,entity in pairs(surface.find_entities_filtered{type={"unit-spawner","turret"}}) do
                    rows[#rows+1]=entity.name..":"..entity.position.x..":"..entity.position.y
                end
                table.sort(rows)
                local signature=table.concat(rows,";")
                if control=="default" then baseline=signature end
                local pass=signature==baseline and #rows>0
                report.checks[#report.checks+1]={name="nauvis/"..seed.."/"..control,pass=pass,nests_and_worms=#rows}
                report.all_pass=report.all_pass and pass
                game.delete_surface(surface)
            end
        end
        helpers.write_file("planet-enemies-isolation.json",helpers.table_to_json(report),false)
    end)
end
