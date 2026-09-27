-- Every visual identity must natively fire every fuel while replacement is delayed.
local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local module={}
function module.install()
    script.on_init(function()
        local surface=game.create_surface("flame-matrix",{width=512,height=640,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},10);surface.force_generate_chunk_requests()
        local names={catalog.base_turret}
        for _,fuel in ipairs(catalog.fuels) do names[#names+1]=fuel.turret end
        storage.cases={}
        for row,name in ipairs(names) do
            for column,fuel in ipairs(catalog.fuels) do
                local x,y=(column-5)*40,(row-6)*50
                local tiles={}
                for tx=x-4,x+4 do for ty=y-25,y+4 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
                surface.set_tiles(tiles)
                -- Deliberately do not raise built: this fixture holds identities fixed.
                local turret=surface.create_entity{name=name,position={x,y},force="player"}
                local target=surface.create_entity{name="esir-flame-qc-target",position={x,y-20},force="enemy"}
                turret.set_fluid(1,{name=fuel.fluid,amount=100})
                turret.set_fluid(2,{name=fuel.fluid,amount=5})
                turret.shooting_target=target
                storage.cases[#storage.cases+1]={turret=turret,target=target,initial=target.health,name=name,fuel=fuel.id}
            end
        end
    end)
    script.on_event(defines.events.on_tick,function(event)
        if event.tick~=600 then return end
        local report={all_pass=true,cases={}}
        for _,case in ipairs(storage.cases) do
            local damage=case.initial-case.target.health
            local supply=case.turret.get_fluid(1)
            local passed=damage>0 and case.turret.name==case.name and (not supply or supply.amount<100)
            report.cases[#report.cases+1]={turret=case.name,fuel=case.fuel,damage=damage,passed=passed}
            if not passed then report.all_pass=false end
        end
        helpers.write_file("flamethrower-qc.json",helpers.table_to_json(report),false)
        assert(report.all_pass,"A turret identity failed to fire a supported fuel")
    end)
end
return module
