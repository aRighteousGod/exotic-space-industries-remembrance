-- Native-only acceptance of placement, pipe topology, aiming and rendered state.
-- This module is loaded only by the isolated QC helper, never the shipped mod.
local config=require("test-config")
local names={"north","northeast","east","southeast","south","southwest","west","northwest"}
local ids={0,2,4,6,8,10,12,14}
local q=math.sqrt(.5)
local loaded=false
local scene_update,scene_camera,scene_surface
local function near(a,b) return math.abs(a-b)<.0001 end
local function rotate(x,y,n)
    for _=1,n do x,y=-y,x end
    return x,y
end
local function expected(i)
    local source=i%2==1 and {{-.5,1,-1.5,1},{.5,1,1.5,1}} or {{-1,0,-2,0},{0,1,0,2}}
    local rows={}
    for _,p in ipairs(source) do
        local x,y=rotate(p[1],p[2],math.floor((i-1)/2))
        local tx,ty=rotate(p[3],p[4],math.floor((i-1)/2))
        rows[#rows+1]={x=x,y=y,tx=tx,ty=ty}
    end
    return rows
end
local function surface(name,size)
    local s=game.create_surface(name,{width=size,height=size,autoplace_settings={
        entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.freeze_daytime=true;s.daytime=0
    return s
end
local function pad(s,p,r)
    s.request_to_generate_chunks(p,math.ceil(r/32)+1);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities_filtered{area={{p.x-r,p.y-r},{p.x+r,p.y+r}},type={"unit","unit-spawner","tree","turret"}}) do e.destroy() end
    local tiles={}
    for x=math.floor(p.x-r),math.ceil(p.x+r) do for y=math.floor(p.y-r),math.ceil(p.y+r) do
        tiles[#tiles+1]={name="lab-dark-1",position={x,y}}
    end end
    s.set_tiles(tiles)
end
local function body(s,p,i,name)
    return assert(s.create_entity{name=name or "ei-acidthrower-turret",position=p,direction=ids[i],force="player"})
end
local function ports(e,i,pipes)
    assert(e.fluids_count==2,"Supply segment and private firing buffer")
    local actual=e.get_fluid_box_pipe_connections(1)
    assert(#actual==2)
    for j,w in ipairs(expected(i)) do
        local a=actual[j]
        assert(near(a.position.x,e.position.x+w.x) and near(a.position.y,e.position.y+w.y),"Native port position")
        assert(near(a.target_position.x,e.position.x+w.tx) and near(a.target_position.y,e.position.y+w.ty),"Native pipe target")
        assert(a.target==(pipes and pipes[j] or nil),"Actual connected entity")
    end
end
local function attach(e,i,mask)
    local pipes={}
    for j,p in ipairs(expected(i)) do
        if mask==3 or mask==j then
            pipes[j]=assert(e.surface.create_entity{name="pipe",position={e.position.x+p.tx,e.position.y+p.ty},force=e.force})
        end
    end
    ports(e,i,pipes)
    return pipes
end
local function wires(e,pole)
    for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
        assert(e.get_wire_connector(id,true).connect_to(pole.get_wire_connector(id,true)))
    end
end
local function check_wires(e,pole)
    for _,id in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green} do
        local found=false
        for _,edge in pairs(e.get_wire_connector(id,false).real_connections) do
            if edge.target.owner==pole then found=true end
        end
        assert(found,"Native circuit wire persistence")
    end
end
local function capture(key,s,p,day,zoom,size)
    if config.phase~="visual" then return end
    game.take_screenshot{surface=s,position=p,resolution=size or {512,512},zoom=zoom or 3,daytime=day or 0,
        path="acid-eight/"..key..".png",show_gui=false,show_entity_info=false,anti_alias=false,force_render=true}
    storage.acid_eight.captures[#storage.acid_eight.captures+1]=key
end
local function fluid_total(e)
    local total=0
    for index=1,e.fluids_count do local f=e.get_fluid(index);total=total+(f and f.amount or 0) end
    return total
end
local function fill(e)
    for index=1,e.fluids_count do e.set_fluid(index,{name="sulfuric-acid",amount=100,temperature=25}) end
    return fluid_total(e)
end
local function capture_pose(row,key,t)
    local p=row.entity.position
    capture(key,row.entity.surface,{p.x,p.y-.3},0,4)
    local root=storage.acid_eight
    root.report.visual[#root.report.visual+1]={key=key,case=row.key,facing=row.facing,tick=t,orientation=row.entity.orientation,
        position=p,camera={p.x,p.y-.3},source=row.last_source}
end
local function snapshot(e)
    local fluid={}
    for i=1,e.fluids_count do fluid[i]=e.get_fluid(i) or false end
    return {direction=e.direction,orientation=e.orientation,position=e.position,health=e.health,quality=e.quality.name,fluids=fluid}
end
local function setup(tick)
    helpers.write_file("final-data.json",helpers.table_to_json(prototypes.mod_data["acid-eight-final"].data),false)
    local root={start=tick,flow={},combat={},by_unit={},by_target={},captures={},report={engine=script.active_mods.base,flow={},muzzle={},rotations={},replacement={},visual={},ticks={}}}
    storage.acid_eight=root
    local s=surface("acid-eight-connections",256);pad(s,{x=0,y=0},70);root.surface=s
    for i=1,8 do for mask=0,3 do
        local e=body(s,{(i-4.5)*12,(mask-1.5)*12},i)
        local pipes=attach(e,i,mask)
        local supplied=0
        for _,p in pairs(pipes) do supplied=supplied+p.insert_fluid{name="sulfuric-acid",amount=100} end
        root.flow[#root.flow+1]={entity=e,pipes=pipes,facing=i,mask=mask,supplied=supplied}
    end end
    -- Eight actual native rotation steps each way; aiming is independent.
    for i=1,8 do
        local e=body(s,{(i-4.5)*12,48},i)
        local reference=body(s,{(i-4.5)*12,60},i,"flamethrower-turret")
        for _,reverse in ipairs{false,true} do
            local sequence={}
            for step=1,8 do
                assert(e.rotate{reverse=reverse},"Native rotation failed")
                assert(reference.rotate{reverse=reverse})
                assert(e.direction==reference.direction,"Native flamethrower rotation parity")
                sequence[#sequence+1]=e.direction
            end
            root.report.rotations[#root.report.rotations+1]={facing=i,reverse=reverse,sequence=sequence}
        end
        e.destroy();reference.destroy()
        local old=body(s,{(i-4.5)*12,48},i,"flamethrower-turret")
        local pipes=attach(old,i,3)
        local pole=assert(s.create_entity{name="medium-electric-pole",position={old.position.x+3,old.position.y+2},force="player"})
        wires(old,pole)
        for _,name in ipairs{"ei-acidthrower-turret","flamethrower-turret"} do
            local e2=assert(s.create_entity{name=name,position=old.position,direction=ids[i],force="player",fast_replace=true,spill=false})
            assert(not old.valid and e2.direction==ids[i]);ports(e2,i,pipes);check_wires(e2,pole);old=e2
        end
        root.report.replacement[#root.report.replacement+1]={facing=i,passed=true}
    end
    local c=surface("acid-eight-combat",2048);root.combat_surface=c
    for i=1,8 do for a,angle in ipairs{-47.9,0,47.9} do for r,range in ipairs{9.2,24,37.8} do
        local p={x=(i-4.5)*128,y=((a-1)*3+r-5)*128};pad(c,p,45)
        local e=body(c,p,i);p=e.position
        local radians=math.rad((i-1)*45+angle)
        local target=assert(c.create_entity{name="acid-eight-target",position={p.x+range*math.sin(radians),p.y-range*math.cos(radians)},force="enemy"})
        assert(math.abs(math.sqrt((target.position.x-p.x)^2+(target.position.y-p.y)^2)-range)<.01,"Off-grid target distance")
        target.disabled_by_script=true;local initial=fill(e);e.shooting_target=target
        local row={entity=e,target=target,facing=i,angle=angle,range=range,launches=0,consumed=0,last_total=initial,damage=0,key=i.."-"..a.."-"..r}
        root.combat[#root.combat+1]=row;root.by_unit[e.unit_number]=row;root.by_target[target.unit_number]=row
    end end end
    local simulation=prototypes.mod_data["acid-eight-final"].data.turret.factoriopedia_simulation
    scene_surface=surface("acid-eight-factoriopedia",64);pad(scene_surface,{x=0,y=0},20)
    scene_camera={}
    local facade=setmetatable({surfaces={[1]=scene_surface},simulation=scene_camera},{__index=function(_,key) return game[key] end})
    local env=setmetatable({game=facade,storage={}},{__index=_G})
    assert(load(simulation.init,"=acid-factoriopedia","t",env))()
    scene_update=simulation.update and assert(load(simulation.update,"=acid-factoriopedia-update","t",env))
    assert(#scene_surface.find_entities_filtered{name="ei-acidthrower-turret"}==1)
    root.report.factoriopedia={body="ei-acidthrower-turret",preroll=simulation.init_update_count or 0,camera=scene_camera}
    local death=surface("acid-eight-death",64);pad(death,{x=0,y=0},20)
    root.death=body(death,{0,0},2)
end
local function source(event)
    local root=storage.acid_eight
    local row=root and event.source_entity and root.by_unit[event.source_entity.unit_number]
    if not row then return end
    row.launches=row.launches+1
    local theta=(row.facing-1)*math.pi/4
    local hx=.0014700282*math.cos(theta)+(.6423900127-.18)*math.sin(theta)
    local hy=.0014700282*math.sin(theta)-(.6423900127-.18)*math.cos(theta)
    -- The weapon orientation points from the entity origin. Native stream
    -- launch uses the target vector from the shifted gun center instead.
    local gx,gy=row.entity.position.x+hx,row.entity.position.y+hy-.886152416900*q
    local dx,dy=row.target.position.x-gx,row.target.position.y-gy
    local length=.854090101414/math.sqrt(dx*dx+2*dy*dy)
    local ex,ey=gx+dx*length,gy+dy*length
    local error=math.sqrt((ex-event.source_position.x)^2+(ey-event.source_position.y)^2)
    row.max_error=math.max(row.max_error or 0,error)
    if not row.worst or error>row.worst.error then row.worst={error=error,expected={x=ex,y=ey},actual=event.source_position,orientation=row.entity.orientation,tick=event.tick} end
    assert(error<1/32,"Native gun-center launch tolerance: "..row.key.." "..error)
    row.last_source={position=event.source_position,tick=event.tick,orientation=row.entity.orientation}
end
local function tick(event)
    if not storage.acid_eight then setup(event.tick) end
    local root=storage.acid_eight;local t=event.tick-root.start
    if loaded and root.finished then
        for _,row in ipairs(root.flow) do
            local now=snapshot(row.entity);local old=row.saved
            assert(now.direction==old.direction and now.quality==old.quality and near(now.health,old.health))
            assert(near(now.position.x,old.position.x) and near(now.position.y,old.position.y))
            ports(row.entity,row.facing,row.pipes)
            for i,f in ipairs(old.fluids) do
                if f then assert(now.fluids[i] and now.fluids[i].name==f.name and near(now.fluids[i].amount,f.amount)) end
            end
        end
        helpers.write_file("acid-eight-reload.json",helpers.table_to_json{passed=true,entities=#root.flow,engine=script.active_mods.base},false)
        loaded=false;return
    end
    if root.finished then return end
    if scene_update then scene_update() end
    if t==60 then capture("factoriopedia",scene_surface,scene_camera.camera_position,0,scene_camera.camera_zoom,{512,384}) end
    if t==118 then capture("death-before",root.death.surface,root.death.position,0,3) end
    if t==120 then
        root.death_surface=root.death.surface;assert(root.death.die());assert(not root.death.valid)
        root.report.death={passed=true,effect=prototypes.mod_data["acid-eight-final"].data.turret.dying_explosion}
    end
    if t>=120 and t<=160 and t%4==0 then capture("death-"..t,root.death_surface,{0,0},0,3) end
    if t==120 then
        for _,row in ipairs(root.flow) do
            local e=row.entity;ports(e,row.facing,row.pipes)
            local buffer=e.get_fluid(2)
            local segment=e.get_fluid_segment_fluid(1)
            local total=(buffer and buffer.amount or 0)+(segment and segment.amount or 0)
            assert(math.abs(total-row.supplied)<.001,"Native fluid conservation")
            if row.mask>0 then assert(buffer and buffer.amount>0) else assert(not buffer or buffer.amount==0) end
            root.report.flow[#root.report.flow+1]={facing=row.facing,mask=row.mask,buffer=buffer,total=total,ports=e.get_fluid_box_pipe_connections(1)[1].position}
            local direction=e.direction;e.orientation=(e.orientation+.03)%1;assert(e.direction==direction);ports(e,row.facing,row.pipes)
            if row.mask>0 then
                for j,p in pairs(row.pipes) do p.destroy();row.pipes[j]=nil end
                ports(e,row.facing,nil);row.pipes=attach(e,row.facing,row.mask)
            end
            capture("ports-"..row.facing.."-"..row.mask,root.surface,{e.position.x,e.position.y-.3},0)
            capture("ports-night-"..row.facing.."-"..row.mask,root.surface,{e.position.x,e.position.y-.3},.5)
        end
    end
    for _,row in ipairs(root.combat) do
        if t<400 and t%30==0 then
            -- Internal supply-to-firing transfer must cancel from consumption;
            -- sampling only the private buffer depends on the native tick phase.
            row.consumed=row.consumed+row.last_total-fluid_total(row.entity)
            row.last_total=fill(row.entity)
        end
        if t==240 then
            assert(row.launches>0,"No launch: "..row.key)
            root.report.muzzle[#root.report.muzzle+1]={key=row.key,facing=row.facing,range=row.range,angle=row.angle,launches=row.launches,
                max_error=row.max_error,worst=row.worst,damage=row.target.max_health-row.target.health,consumed=row.consumed,last_source=row.last_source,
                position=row.entity.position,target=row.target.position,orientation=row.entity.orientation,status=row.entity.status,
                event_damage=row.damage,target_health=row.target.health,target_max_health=row.target.max_health,destructible=row.target.destructible,
                cease_fire=row.entity.force.get_cease_fire(row.target.force)}
            capture_pose(row,"firing-"..row.key,t)
        end
        if row.angle==0 and row.range==24 then
            if t<=120 and t%8==0 then
                capture("startup-"..row.facing.."-"..t,root.combat_surface,row.entity.position,.5,3)
                capture("startup-day-"..row.facing.."-"..t,root.combat_surface,row.entity.position,0,3)
            end
            if t>=260 and t<=380 then
                local radians=math.rad((row.facing-1)*45-46+92*(t-260)/120)
                row.target.teleport({row.entity.position.x+24*math.sin(radians),row.entity.position.y-24*math.cos(radians)})
                if t%4==0 then capture_pose(row,"aim-"..row.facing.."-"..t,t) end
            end
            if t==245 then capture("active-night-"..row.facing,root.combat_surface,row.entity.position,.5,4) end
            if t>=400 and t<=480 and t%4==0 then
                capture("shutdown-"..row.facing.."-"..t,root.combat_surface,row.entity.position,.5,3)
                capture("shutdown-day-"..row.facing.."-"..t,root.combat_surface,row.entity.position,0,3)
            end
        end
        if t==241 or (row.angle==0 and row.range==24 and t>=260 and t<=382) then
            root.report.ticks[#root.report.ticks+1]={case=row.key,tick=t,orientation=row.entity.orientation}
        end
        if t==400 then row.target.destroy() end
    end
    if t==500 then
        for _,row in ipairs(root.flow) do row.saved=snapshot(row.entity) end
        root.report.passed=true;root.report.captures=root.captures
        root.report.failures={}
        for _,row in ipairs(root.report.muzzle) do
            if row.event_damage<=0 or row.damage<=0 or row.consumed<=0 then
                root.report.passed=false;root.report.failures[#root.report.failures+1]={case=row.key,reason="native damage/fluid use"}
            end
        end
        helpers.write_file("acid-eight-native.json",helpers.table_to_json(root.report),false)
        if config.phase=="visual" then game.set_wait_for_screenshots_to_finish() end
        root.finished=true
        if config.phase=="visual" then game.auto_save("acid-eight-native") end
    end
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_script_trigger_effect,function(event) if event.effect_id=="acid-eight-launch" then source(event) end end)
script.on_event(defines.events.on_entity_damaged,function(event)
    local root=storage.acid_eight;local row=root and root.by_target[event.entity.unit_number]
    if row then row.damage=row.damage+event.final_damage_amount end
end)
script.on_event(defines.events.on_tick,tick)
