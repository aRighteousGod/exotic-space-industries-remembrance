-- A real four-way save upgraded to the shipped eight-way prototype, without migration.
local config=require("test-config")
local function compare(a,b,path,differences)
    if type(a)~=type(b) then differences[#differences+1]=path;return end
    if type(a)=="table" then
        for k,v in pairs(a) do compare(v,b[k],path.."/"..k,differences) end
        for k in pairs(b) do if a[k]==nil then differences[#differences+1]=path.."/"..k end end
    elseif type(a)=="number" then
        if math.abs(a-b)>.0001 then differences[#differences+1]={path=path,before=a,after=b} end
    elseif a~=b then differences[#differences+1]={path=path,before=a,after=b} end
end
local function snapshot(e)
    local fluids,ports,wires={},{},{}
    for i=1,e.fluids_count do fluids[i]=e.get_fluid(i) or false end
    for i,p in ipairs(e.get_fluid_box_pipe_connections(1)) do
        ports[i]={position=p.position,target_position=p.target_position,target=p.target and p.target.unit_number}
    end
    for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
        local ids={};for _,c in ipairs(e.get_wire_connector(id,false).real_connections) do ids[#ids+1]=c.target.owner.unit_number end
        table.sort(ids);wires[tostring(id)]=ids
    end
    return {unit_number=e.unit_number,direction=e.direction,position=e.position,health=e.health,quality=e.quality.name,
        read_ammo=e.get_control_behavior().read_ammo,fluids=fluids,ports=ports,wires=wires}
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.acid_upgrade then
        assert(config.phase=="legacy-seed")
        local s=game.create_surface("acid-cardinal-upgrade",{width=128,height=128})
        s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
        for _,e in pairs(s.find_entities()) do e.destroy() end
        local tiles={};for x=-40,40 do for y=-12,12 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end;s.set_tiles(tiles)
        local root={start=event.tick,entities={}};storage.acid_upgrade=root
        for i=0,3 do
            local e=assert(s.create_entity{name="ei-acidthrower-turret",position={(i-1.5)*12,0},direction=i*4,force="player",quality=i==3 and "rare" or "normal"})
            e.health=e.health-17-i;e.get_or_create_control_behavior().read_ammo=true
            for _,p in ipairs(e.get_fluid_box_pipe_connections(1)) do s.create_entity{name="pipe",position=p.target_position,force="player"} end
            local pole=s.create_entity{name="medium-electric-pole",position={e.position.x+3,e.position.y+3},force="player"}
            for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do assert(e.get_wire_connector(id,true).connect_to(pole.get_wire_connector(id,true))) end
            e.insert_fluid{name="sulfuric-acid",amount=150,temperature=25};root.entities[#root.entities+1]=e
        end
    end
    local root=storage.acid_upgrade
    if config.phase=="legacy-seed" and not root.saved and event.tick-root.start>=120 then
        root.saved={};for _,e in ipairs(root.entities) do root.saved[#root.saved+1]=snapshot(e) end
        helpers.write_file("acid-eight-legacy-seed.json",helpers.table_to_json{passed=true,entities=root.saved},false)
        game.auto_save("acid-eight-legacy-seed")
    elseif config.phase=="legacy-load" and not root.verified then
        local current,differences={},{}
        for i,e in ipairs(root.entities) do
            current[i]=snapshot(e);compare(root.saved[i],current[i],tostring(i),differences)
            game.take_screenshot{surface=e.surface,position=e.position,resolution={512,512},zoom=3,daytime=0,
                path="acid-eight/legacy-"..i..".png",show_gui=false,force_render=true}
        end
        game.set_wait_for_screenshots_to_finish();root.verified=true
        helpers.write_file("acid-eight-legacy-load.json",helpers.table_to_json{passed=#differences==0,entities=current,before=root.saved,differences=differences,scripted_migration=false},false)
        assert(#differences==0,"Existing cardinal state changed: "..helpers.table_to_json(differences))
    end
end)
