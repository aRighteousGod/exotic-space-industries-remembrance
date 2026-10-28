-- Private paired native module/quality and rail handling inventory.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local start,rows,modules,qualities,wagons,machines,fluids,locomotives=nil,{},{},{},{},{},{},{}
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not start then
            start=event.tick
            local surface=game.create_surface("quality-trains-qc",{width=1024,height=1024,water=0,peaceful_mode=true})
            surface.request_to_generate_chunks({0,0},9);surface.force_generate_chunk_requests()
            for _,e in pairs(surface.find_entities()) do e.destroy() end
            local tiles={}
            for x=-200,200 do for y=-240,40 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
            surface.set_tiles(tiles)
            local names={}
            for name,p in pairs(prototypes.entity) do
                if p.type=="locomotive" and not name:find("placement%-entity$") then names[#names+1]=name end
                if p.type=="cargo-wagon" then
                    local sizes={}
                    for _,q in ipairs{"normal","uncommon","rare","epic","legendary"} do
                        sizes[q]=p.get_inventory_size(defines.inventory.cargo_wagon,q)
                    end
                    wagons[name]=sizes
                end
                if p.type=="fluid-wagon" then
                    local sizes={}
                    for _,q in ipairs{"normal","uncommon","rare","epic","legendary"} do sizes[q]=p.get_fluid_capacity(q) end
                    fluids[name]=sizes
                end
                if p.type=="locomotive" then
                    local values={}
                    for _,q in ipairs{"normal","uncommon","rare","epic","legendary"} do
                        values[q]={energy_usage=p.get_max_energy_usage(q),max_speed=script.active_mods.base:sub(1,3)=="2.1" and p.get_max_speed(q) or p.max_speed}
                    end
                    locomotives[name]=values
                end
            end
            table.sort(names)
            local index=0
            for _,name in ipairs(names) do
                for _,quality in ipairs{"normal","rare","legendary"} do
                    index=index+1
                    local x=(index-10)*12
                    local target
                    for y=-220,20,2 do
                        local rail=assert(surface.create_entity{name="straight-rail",position={x,y},direction=defines.direction.north,force="player"})
                        if y==-200 then target=rail end
                    end
                    local entity=assert(surface.create_entity{name=name,position={x,0},quality=quality,force="player"})
                    entity.train.schedule={current=1,records={{rail=target,temporary=true,wait_conditions={{type="time",compare_type="and",ticks=180}}}}}
                    entity.train.manual_mode=false
                    local fuel
                    for _,candidate in ipairs{"coal","nuclear-fuel","ei_emt-fuel_0_0","ei-diesel-fuel-unit"} do
                        if prototypes.item[candidate] and entity.get_fuel_inventory().insert{name=candidate,count=1}>0 then fuel=candidate;break end
                    end
                    assert(fuel,"No native train fuel: "..name)
                    rows[#rows+1]={entity=entity,name=name,quality=quality,fuel=fuel,samples={}}
                end
            end
            for name,p in pairs(prototypes.item) do
                if p.type=="module" then
                    local effects={}
                    for q in pairs(prototypes.quality) do effects[q]=p.get_module_effects(q) end
                    modules[name]=effects
                    for _,q in ipairs{"normal","uncommon","rare","epic","legendary"} do
                        local n=#machines
                        local machine=assert(surface.create_entity{name="assembling-machine-3",position={-180+(n%20)*6,60+math.floor(n/20)*6},force="player"})
                        machine.set_recipe("esir-module-qc")
                        assert(machine.get_module_inventory().insert{name=name,quality=q,count=1}==1,"Module rejected: "..name)
                        machines[#machines+1]={entity=machine,module=name,quality=q}
                    end
                end
            end
            for name,p in pairs(prototypes.quality) do
                qualities[name]={level=p.level,default_multiplier=p.default_multiplier,next_probability=p.next_probability}
                if script.active_mods.base:sub(1,3)=="2.1" then
                    for _,field in ipairs{"chain_probability","previous_probability","previous_chain_probability","locomotive_power_multiplier","rolling_stock_max_speed_multiplier","cargo_wagon_inventory_size_multiplier","module_consumption_multiplier","module_pollution_multiplier","module_productivity_multiplier","module_quality_multiplier","module_speed_multiplier","science_capacity_multiplier","spoil_ticks_multiplier"} do
                        qualities[name][field]=p[field]
                    end
                end
            end
        end
        local elapsed=event.tick-start
        if elapsed==1 or elapsed==10 or elapsed==30 or elapsed==60 or elapsed==120 or elapsed==180 then
            for _,row in ipairs(rows) do
                assert(row.entity.valid)
                row.samples[#row.samples+1]={tick=elapsed,speed=row.entity.train.speed,position=row.entity.position,health=row.entity.health,state=row.entity.train.state}
            end
        end
        if elapsed==180 then
            for _,row in ipairs(rows) do
                local moved=false
                for _,sample in ipairs(row.samples) do moved=moved or math.abs(sample.speed)>0 end
                assert(moved,"Train failed to accelerate: "..row.name)
                row.entity=nil
            end
            for _,row in ipairs(machines) do
                row.productivity_bonus=row.entity.productivity_bonus
                row.speed_bonus=row.entity.speed_bonus
                row.consumption_bonus=row.entity.consumption_bonus
                row.pollution_bonus=row.entity.pollution_bonus
                row.effects=row.entity.effects
                row.entity=nil
            end
            helpers.write_file("quality-trains.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,modules=modules,qualities=qualities,trains=rows,wagons=wagons,machines=machines,fluids=fluids,locomotives=locomotives},false)
        end
    end)
end
