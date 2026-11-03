-- Real provider inputs for co-located helpers, range changes and blocked wire reach.
return function(player, surface, make, step, approach)
    local function probe(name, ...)
        return remote.call("esir-dollies-state", name, ...)
    end
    player.cheat_mode=true
    -- Use a fresh strip of ground outside the baseline fixture.
    surface.request_to_generate_chunks({0,90},3)
    surface.force_generate_chunk_requests()
    local area={{-48,45},{64,134}}
    for _,e in pairs(surface.find_entities_filtered{area=area,type={"tree","simple-entity","cliff","resource"}}) do e.destroy() end
    local tiles={}
    for x=-48,64 do for y=45,134 do tiles[#tiles+1]={position={x,y},name="landfill"} end end
    surface.set_tiles(tiles)
    local assembler=make("ei-exotic-assembler",20,60)
    local stabilizer=make("ei-matter-stabilizer",30,60)
    -- Grid alignment can differ for odd-width prototypes.
    while stabilizer.position.x-assembler.position.x>9 do step(stabilizer,"west",-1) end
    assert(probe("linked",assembler,stabilizer))
    for i=1,3 do step(stabilizer,"east",1) end
    assert(not probe("linked",assembler,stabilizer))
    for i=1,3 do step(stabilizer,"west",-1) end
    assert(probe("linked",assembler,stabilizer))
    local scanner=make("ei-orbital-combinator",0.5,61.5)
    local companion=make("ei-orbital-combinator",-0.5,61.5)
    local neighbor=make("ei-orbital-combinator",2.5,61.5)
    assert(probe("same_bank",scanner,companion))
    step(scanner,"east",1)
    assert(probe("same_bank",scanner,neighbor) and not probe("same_bank",scanner,companion))
    step(scanner,"west",-1)
    assert(probe("same_bank",scanner,companion))
    local function helper_move(name, helper_name, x, y)
        local entity=make(name,x,y)
        local helpers=surface.find_entities_filtered{name=helper_name,position=entity.position,radius=8}
        assert(#helpers==1,helper_name)
        local h=helpers[1]
        local old=h.position
        local opened
        if name=="ei-combustion-turbine-fluid" and player.connected then
            approach(entity.position.x,entity.position.y+6)
            remote.call("esir-dollies-state","open_turbine",player,h)
            opened=assert(player.gui.screen["ei-combustion-turbine-console"] or player.gui.relative["ei-combustion-turbine-console"])
        end
        step(entity,"east",1)
        assert(h.valid and h.position.x==old.x+1 and h.position.y==old.y,
            helper_name.." from "..serpent.line(old).." to "..serpent.line(h.valid and h.position)
            .." owner "..serpent.line(entity.position))
        step(entity,"west",-1)
        assert(h.position.x==old.x)
        if opened then
            assert(opened.valid and opened.parent[opened.name]==opened,"turbine GUI binding")
            player.opened=nil
        end
        return entity
    end
    helper_move("ei-fusion-reactor","ei-fusion-reactor-circuit-interface",20,82)
    local collector=helper_move("ei-neutron-collector","ei-neutron-collector-circuit-interface",40,82)
    local reactor=make("nuclear-reactor",collector.position.x+11,collector.position.y)
    for _,direction in ipairs({"east","west"}) do
        assert(not probe("neutron_dirty",collector,true))
        step(reactor,direction,direction=="east" and 1 or -1)
        assert(probe("neutron_dirty",collector))
    end
    helper_move("ei-combustion-turbine-fluid","ei-combustion-turbine-fluid-open-proxy",-20,82)
    local terminals={"ei-platform-transponder","ei-orbital-selector","ei-orbital-coordinator","ei-orbital-dispatch-uplink"}
    for i,name in ipairs(terminals) do helper_move(name,name.."-power-sensor",i*9,100) end
    for i,name in ipairs({"ei-fueler","ei_charger","nuclear-reactor","rocket-silo","ei-energy-injector-pylon","ei-black-hole"}) do
        local entity=make(name,-40+i*13,121)
        if i<=2 then
            local old=probe("coverage",entity)
            assert(probe("coverage",entity,old.left,old.top))
            for j=1,32 do step(entity,"east",1) end
            assert(not probe("coverage",entity,old.left,old.top))
            for j=1,32 do step(entity,"west",-1) end
            assert(probe("coverage",entity,old.left,old.top))
        else
            step(entity,"east",1);step(entity,"west",-1)
        end
        if name=="ei-black-hole" then
            local pylon=make("ei-energy-extractor-pylon",entity.position.x+20,entity.position.y)
            for _,direction in ipairs({"east","west"}) do
                assert(not probe("pylon_dirty",entity,true))
                step(pylon,direction,direction=="east" and 1 or -1)
                assert(probe("pylon_dirty",entity))
            end
        end
    end
    player.cheat_mode=false
    local a=make("steel-chest",-35.5,60.5)
    local reach=math.floor(a.prototype.get_max_circuit_wire_distance(a.quality))
    local b=make("steel-chest",a.position.x+reach,a.position.y)
    local red=defines.wire_connector_id.circuit_red
    local ca,cb=a.get_wire_connector(red,true),b.get_wire_connector(red,true)
    -- Native reach includes the connector geometry and can exceed the prototype's nominal distance.
    for i=1,10 do
        local pos=b.position
        assert(b.teleport({pos.x+1,pos.y}))
        if not ca.can_wire_reach(cb) then assert(b.teleport(pos)); break end
        assert(i<10,"wire-reach boundary not found")
    end
    assert(ca.connect_to(cb,false,defines.wire_origin.player))
    approach(b.position.x, b.position.y+2)
    step(b,"east",0)
    assert(#b.get_wire_connector(red,true).connections==1)
end
