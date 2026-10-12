-- Identical baseline/candidate scenes. Timings exclude setup and index bootstrap.
local config=require("test-config")
local function call(name,...) return remote.call("ei-water-qc",name,...) end
local function setup(tick)
    assert(config.scene~="dispersed" or config.performance<=128,"dispersed fixture supports at most 128 turrets")
    local s={started=tick,turrets={},positions={},births=0}
    storage.performance_qc=s
    local surface=game.create_surface("water-performance",{width=2048,height=1536,
        autoplace_settings={entity={treat_missing_as_default=false}}})
    s.surface=surface
    surface.request_to_generate_chunks({0,0},17);surface.force_generate_chunk_requests()
    local spaced=config.scene=="dispersed"
    for i=1,math.max(0,config.performance) do
        local x,y=-480+((i-1)%16)*(spaced and 56 or 4),-200+math.floor((i-1)/16)*(spaced and 56 or 4)
        local tiles={}
        for dx=-2,2 do for dy=-2,2 do tiles[#tiles+1]={name="lab-dark-1",position={x+dx,y+dy}} end end
        surface.set_tiles(tiles)
        local e=surface.create_entity{name="ei-water-turret",position={x,y},force="player",raise_built=true}
        e.destructible=false;call("preferences",e,3,false)
        if config.scene~="dry" then e.insert_fluid{name="water",amount=100} end
        s.turrets[#s.turrets+1]=e;s.positions[#s.positions+1]={x,y}
    end
    for x=-510,450,60 do for y=-230,290,60 do
        surface.create_entity{name="esir-water-qc-pole",position={x,y},force="player"}
        surface.create_entity{name="esir-water-qc-source",position={x,y},force="player"}
    end end
end
script.on_event(defines.events.on_tick,function(event)
    if not storage.performance_qc then setup(event.tick) end
    local s=storage.performance_qc
    local t=event.tick-s.started
    if t==2000 then s.before=call("state").counters;call("start_profile") end
    if t>2000 and t<=8000 then
        local frequent=config.scene=="dense" or config.scene=="dispersed"
        if (frequent and t%120==0) or (config.scene=="burst" and t%600==0) then
            for _,e in ipairs(s.turrets) do e.insert_fluid{name="water",amount=100} end
            for j=1,(config.scene=="burst" and 4 or 1) do for _,p in ipairs(s.positions) do
                s.surface.create_entity{name="ei-oil-fire-flame",position={p[1]+10+j,p[2]+8},force="neutral"}
                s.births=s.births+1
            end end
        end
    end
    if t==8000 then
        local root=call("state")
        local powered=0
        for _,r in pairs(root.records) do if r.powered then powered=powered+1 end end
        local delta={}
        for k,v in pairs(root.counters) do delta[k]=v-(s.before[k] or 0) end
        local calls=call("profile")
        local idle=config.scene=="dry" or config.scene=="wet"
        local indexed=root.schema==2
        local pass=root.count==math.max(0,config.performance) and powered==root.count and calls==6000
        if indexed then pass=pass and delta.searches==0 end
        if indexed and idle then pass=pass and delta.acquisitions==0 end
        if not idle then pass=pass and delta.pulses>0 end
        helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=pass,scene=config.scene,
            count=root.count,powered=powered,ticks=calls,births=s.births,indexed=indexed,counters=delta},false)
    end
end)
