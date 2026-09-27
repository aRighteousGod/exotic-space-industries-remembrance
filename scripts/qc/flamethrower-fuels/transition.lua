local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local module={}
function module.install(config)
    script.on_init(function()
        local surface=game.surfaces[1]
        surface.request_to_generate_chunks({0,0},1)
        surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities_filtered{area={{-12,-12},{12,12}}}) do entity.destroy() end
        local tiles={}
        for x=-10,10 do for y=-10,10 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
        surface.set_tiles(tiles)
        storage.report={checks={}}
        storage.start=game.tick
        for i,fluid in ipairs{"ei-diesel","heavy-oil"} do
            local entity=surface.create_entity{name="flamethrower-turret",position={i*4,0},force="player",quality="epic",raise_built=true}
            entity.disabled_by_script=true
            entity.health=321
            entity.kills=17
            entity.set_fluid(2,{name=fluid,amount=5,temperature=25})
        end
    end)
    script.on_configuration_changed(function()
        storage.start=game.tick
        storage.report={checks={}}
    end)
    script.on_event(defines.events.on_tick,function(event)
        local elapsed=event.tick-storage.start
        if elapsed==180 then
            local status=remote.call("esir-flame-qc","status")
            assert(status.enabled==config.enabled,"startup-mode")
            local checks=storage.report.checks
            for i,fluid in ipairs{"ei-diesel","heavy-oil"} do
                local entity=game.surfaces[1].find_entities_filtered{position={i*4,0},type="fluid-turret"}[1]
                assert(entity and entity.name==(config.enabled and catalog.by_fluid[fluid].turret or "flamethrower-turret"),"transition-identity")
                assert(entity.health==321 and entity.kills==17 and entity.quality.name=="epic","transition-state")
                assert(entity.get_fluid(2).name==fluid and entity.get_fluid(2).amount==5,"transition-fluid")
                checks[fluid]=true
            end
            storage.checks_before=status.counters.checks
        elseif elapsed==240 then
            local status=remote.call("esir-flame-qc","status")
            if not config.enabled then assert(status.count==0 and status.counters.checks==storage.checks_before,"disabled-steady-state") end
            storage.report.status=status
            storage.report.all_pass=true
            helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
            game.server_save("flame-transition")
        end
    end)
end
return module
