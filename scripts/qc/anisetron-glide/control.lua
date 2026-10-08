-- Fixture-only native physics. No position/speed overrides or hostile stickers.
local options=require("options")
local profiles=require("profiles")
local config=require("test-config")
local function check(name,pass,detail) storage.results[name]={pass=pass==true,detail=detail} end
local function flush(record)
    if #record.buffer==0 then return end
    helpers.write_file("anisetron-glide/"..record.key..".jsonl",helpers.table_to_json(record.buffer).."\n",record.appended==true)
    record.appended=true;record.buffer={}
end
local function setup(tick)
    storage.start_tick,storage.records,storage.results=tick,{},{}
    local surface=game.create_surface("anisetron-glide",{width=5000,height=5000,water=0,
        cliff_settings={cliff_elevation_interval=0},autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false}}})
    for x=-1200,1200,400 do for y=-1400,1400,400 do surface.request_to_generate_chunks({x,y},7) end end
    surface.force_generate_chunk_requests();storage.surface=surface
    surface.freeze_daytime=true;surface.daytime=.4
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    local force=game.create_force("anisetron-glide");storage.force=force
    for equipped=0,(options.equipped and 1 or 0) do
        for _,profile in ipairs(profiles) do for heading=0,options.headings-1 do
            local index=#storage.records+1
            local key=profile.id.."-h"..heading.."-e"..equipped
            local orientation=options.headings==1 and .25 or heading/options.headings
            local name=options.visual and not profile.saucer and profile.count==10 and "ei-anisetron" or "anisetron-glide-"..profile.id
            local source=surface.create_entity{name=name,position={0,(index-40)*18},force=force,raise_built=true}
            source.orientation=orientation;source.torso_orientation=orientation
            source.vehicle_automatic_targeting_parameters={auto_target_without_gunner=false,auto_target_with_gunner=false}
            if equipped==1 then
                local reactor=source.grid.put{name="fusion-reactor-equipment",position={0,0}};reactor.energy=100000000
                local legs=source.grid.put{name="exoskeleton-equipment",position={4,0}};legs.energy=100000000
            end
            local record={key=key,profile=profile,entity=source,heading=orientation,equipped=equipped,
                origin=source.position,last=source.position,buffer={},metrics={}}
            storage.records[index]=record
            local a=orientation*math.pi*2
            source.autopilot_destination={source.position.x+math.sin(a)*1400,source.position.y-math.cos(a)*1400}
            check("native-legs-"..key,#source.get_spider_legs()==profile.count,#source.get_spider_legs())
        end end
    end
    local player=assert(game.get_player(1),"Copied player seed required")
    player.force=force;player.set_controller{type=defines.controllers.spectator};player.teleport({0,0},surface)
    force.chart(surface,{{-2400,-2400},{2400,2400}})
end
local function destination(record,orientation,distance)
    local source=record.entity;local a=orientation*math.pi*2
    source.autopilot_destination={source.position.x+math.sin(a)*distance,source.position.y-math.cos(a)*distance}
end
local function add_stat(record,phase,speed,distance,dvx,dvy)
    local s=record.metrics[phase] or {count=0,sum=0,sum2=0,min=math.huge,max=0,distance=0,zero_ticks=0,max_delta=0,delta2=0}
    s.count=s.count+1;s.sum=s.sum+speed;s.sum2=s.sum2+speed*speed
    s.min=math.min(s.min,speed);s.max=math.max(s.max,speed);s.distance=s.distance+distance
    if distance<.00001 then s.zero_ticks=s.zero_ticks+1 end
    local delta=math.sqrt(dvx*dvx+dvy*dvy);s.max_delta=math.max(s.max_delta,delta);s.delta2=s.delta2+delta*delta
    record.metrics[phase]=s
end
script.on_event(defines.events.on_tick,function(event)
    if storage.complete then return end
    if not storage.start_tick then setup(event.tick) end
    local t=event.tick-storage.start_tick
    local phase=t<300 and "warmup" or t<900 and "cruise" or t<1050 and "stop" or t<1350 and "restart"
        or t<1700 and "turn45" or t<2050 and "turn90" or t<2400 and "turn180" or t<3100 and "approach" or "final-stop"
    for _,record in ipairs(storage.records) do
        local source=record.entity
        if t==900 then source.autopilot_destination=nil end
        if t==1050 then destination(record,record.heading,1400) end
        if t==1350 then destination(record,record.heading+.125,800) end
        if t==1700 then destination(record,record.heading+.375,800) end
        if t==2050 then destination(record,record.heading+.875,800) end
        if t==2400 then destination(record,record.heading+.875,30) end
        if t==3200 then destination(record,record.heading,100) end
        local p=source.position;local dx,dy=p.x-record.last.x,p.y-record.last.y
        local distance=math.sqrt(dx*dx+dy*dy)
        add_stat(record,phase,source.speed,distance,dx-(record.dx or 0),dy-(record.dy or 0))
        local feet={}
        for _,leg in ipairs(source.get_spider_legs()) do feet[#feet+1]={leg.position.x-p.x,leg.position.y-p.y} end
        record.buffer[#record.buffer+1]={t,p.x,p.y,source.speed,source.orientation,source.torso_orientation,feet}
        record.last=p;record.dx,record.dy=dx,dy
        if t%120==119 then flush(record) end
        if options.visual and not record.profile.saucer and t%3==0 and t<=2400 then
            local path=string.format("anisetron-glide/captures/%s/%04d.png",record.key,t)
            game.take_screenshot{player=1,surface=storage.surface,position={p.x,p.y-2},resolution={512,512},zoom=1,
                path=path,show_gui=false,show_entity_info=false,anti_alias=false,force_render=true}
        end
    end
    if t>=options.duration-1 then
        local records={}
        for _,record in ipairs(storage.records) do
            flush(record)
            check("valid-at-finish-"..record.key,record.entity.valid and #record.entity.get_spider_legs()==record.profile.count)
            records[#records+1]={key=record.key,profile=record.profile,heading=record.heading,equipped=record.equipped,
                metrics=record.metrics,trace="anisetron-glide/"..record.key..".jsonl"}
        end
        storage.complete=true
        local all,count=true,0
        for _,result in pairs(storage.results) do all=all and result.pass;count=count+1 end
        helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=count,complete=true,
            profile="native-glide",fixture_version=1,cases=storage.results,records=records,options=options},false)
    end
end)
