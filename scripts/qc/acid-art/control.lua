local config=require("test-config")
local run_started
local directions={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local projection=math.sqrt(0.5)
local bearing_x,bearing_y=0.0014700282,0.6423900127
-- Projection regression only; visible-outlet acceptance lives in acid-jet QC.
local height=0.87555*projection
local shifts={{bearing_x,-bearing_y+.18},{bearing_y-.18,bearing_x},
    {-bearing_x,bearing_y-.18},{-bearing_y+.18,-bearing_x}}

local function surface(name,size)
    local result=game.create_surface(name,{width=size,height=size,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    result.request_to_generate_chunks({0,0},math.ceil(size/64));result.force_generate_chunk_requests()
    for _,entity in pairs(result.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    result.freeze_daytime=true;result.daytime=0.5
    return result
end

local function pad(s,p,radius)
    local tiles={}
    for x=math.floor(p.x)-radius,math.floor(p.x)+radius do for y=math.floor(p.y)-radius,math.floor(p.y)+radius do
        tiles[#tiles+1]={name="lab-dark-1",position={x,y}}
    end end
    s.set_tiles(tiles)
end

local function target(s,p,angle)
    local point={x=p.x+22*math.sin(angle),y=p.y-22*math.cos(angle)}
    pad(s,point,2)
    local entity=s.create_entity{name="esir-acid-art-target",position=point,force="enemy"}
    entity.active=false
    return entity
end

local function setup(tick)
    log("ACID_ART_SETUP tick="..tick)
    game.forces.player.set_cease_fire("enemy",false)
    game.forces.enemy.set_cease_fire("player",false)
    game.forces.player.set_friend("enemy",false)
    game.forces.enemy.set_friend("player",false)
    local idle_force=game.forces["acid-art-idle"] or game.create_force("acid-art-idle")
    idle_force.set_friend("enemy",true)
    game.forces.enemy.set_friend(idle_force,true)
    idle_force.set_friend("player",true)
    game.forces.player.set_friend(idle_force,true)
    local root={started=tick,probes={},launches={},visual={},cover_visual={},captures={}}
    storage.acid_art=root
    local test=surface("acid-muzzle",512)
    for facing=1,4 do for column,angle in ipairs{-40,0,40} do
        local p={x=(column-2)*96+0.5,y=(facing-2.5)*96+0.5}
        pad(test,p,4)
        local entity=test.create_entity{name="esir-acid-art-probe",position=p,direction=directions[facing],force="player"}
        local actual=entity.position
        local victim=target(test,actual,math.rad((facing-1)*90+angle))
        entity.insert_fluid{name="sulfuric-acid",amount=100}
        entity.set_fluid(2,{name="sulfuric-acid",amount=100});entity.shooting_target=victim
        root.probes[entity.unit_number]={entity=entity,position=actual,target=victim,shift=shifts[facing],angle=angle,facing=facing}
    end end
    local visual=surface("acid-visual",128);root.surface=visual
    local covers=surface("acid-covers",128);root.cover_surface=covers
    pad(visual,{x=0,y=0},35)
    pad(covers,{x=0,y=0},20)
    for row=1,2 do for facing=1,4 do
        local p={x=(facing-2.5)*8+0.5,y=row==1 and -4.5 or 4.5}
        local entity=visual.create_entity{name="esir-acid-art-probe",position=p,direction=directions[facing],force=row==1 and idle_force or "player"}
        local record={entity=entity,facing=facing,active=row==2}
        if row==2 then
            entity.insert_fluid{name="sulfuric-acid",amount=100}
            record.target=target(visual,entity.position,math.rad((facing-1)*90+30))
            entity.set_fluid(2,{name="sulfuric-acid",amount=100});entity.shooting_target=record.target
        end
        for _,connection in pairs(row==2 and entity.fluidbox.get_pipe_connections(1) or {}) do
            local pipe=visual.create_entity{name="pipe",position=connection.target_position,force="player"}
            assert(pipe and pipe.valid,"Pipe connection must accept a normal pipe")
        end
        root.visual[#root.visual+1]=record
        rendering.draw_text{surface=visual,target={p.x-1,p.y+2.8},text=({"N","E","S","W"})[facing]..(row==1 and " idle" or " active"),color={1,1,1}}
        -- Clean comparison uses the actual production prototype on a separate
        -- surface, so streams and helper state markers cannot obscure covers.
        local preview=covers.create_entity{name="ei-acidthrower-turret",position=p,direction=directions[facing],force=idle_force}
        if row==2 then
            for _,connection in pairs(preview.fluidbox.get_pipe_connections(1)) do
                assert(covers.create_entity{name="pipe",position=connection.target_position,force=idle_force})
            end
        end
        root.cover_visual[#root.cover_visual+1]={entity=preview,facing=facing}
    end end
    -- Compare the old and corrected layers against real entities immediately
    -- north/south of every facing. No art, shifts or entity footprints differ.
    local overlap=surface("acid-overlap",128);root.overlap_surface=overlap
    root.overlap_visual={}
    pad(overlap,{x=0,y=0},35)
    for facing=1,4 do for variant=1,2 do
        local p={x=(variant-1.5)*8,y=(facing-2.5)*10+0.5}
        local name=variant==1 and "esir-acid-art-old-draw-order" or "ei-acidthrower-turret"
        local entity=assert(overlap.create_entity{name=name,position=p,direction=directions[facing],force=idle_force})
        p=entity.position
        local half_depth=facing%2==1 and 1.5 or 1
        local half_width=facing%2==1 and 1 or 1.5
        for _,side in ipairs{-1,1} do
            for column=0,half_width*2-1 do
                local pipe_position={p.x-half_width+0.5+column,p.y+side*(half_depth+0.5)}
                assert(overlap.can_place_entity{name="pipe",position=pipe_position,force=idle_force},"Overlap fixture must use valid adjacent pipe positions")
                assert(overlap.create_entity{name="pipe",position=pipe_position,force=idle_force})
            end
        end
        root.overlap_visual[#root.overlap_visual+1]={entity=entity,facing=facing,variant=variant}
        rendering.draw_text{surface=overlap,target={p.x-1.5,p.y+3},
            text=({"N","E","S","W"})[facing]..(variant==1 and " previous" or " corrected"),color={1,1,1}}
    end end
end

local function capture(root,name,daytime,zoom,position,resolution,on_surface)
    if config.visual then
        game.take_screenshot{surface=on_surface or root.surface,position=position or {0,-0.4},resolution=resolution or {1280,700},
            zoom=zoom or 1.2,path="acid-art/"..name..".png",show_gui=false,show_entity_info=false,
            daytime=daytime or 0.5,anti_alias=true,force_render=true}
        root.captures[#root.captures+1]=name
    end
end

script.on_init(function()
    storage.acid_art_pending=true
    -- Fresh graphical freeplay otherwise pauses at its modal intro, regardless
    -- of tick_paused. Persist this before the benchmark creates its player.
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
end)
script.on_event(defines.events.on_player_created,function(event)
    if not storage.acid_art then storage.acid_art_pending=nil;setup(event.tick) end
    game.tick_paused=false
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id~="acid-art-launch" then return end
    local entity=event.source_entity
    if entity and entity.valid and storage.acid_art.probes[entity.unit_number] and not storage.acid_art.launches[entity.unit_number] then
        storage.acid_art.launches[entity.unit_number]={position=event.source_position,orientation=entity.orientation}
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.acid_art then storage.acid_art_pending=nil;setup(event.tick) end
    local root=storage.acid_art;if not root then return end
    if not run_started then
        run_started=event.tick
        log("ACID_ART_UPDATES start="..event.tick.." setup="..root.started.." visual="..tostring(config.visual))
    end
    local offset=event.tick-run_started
    for _,record in pairs(root.probes) do record.entity.insert_fluid{name="sulfuric-acid",amount=100} end
    for _,record in ipairs(root.visual) do if record.active then record.entity.insert_fluid{name="sulfuric-acid",amount=100} end end
    if offset==100 then capture(root,"day-active",0) end
    if offset==110 then capture(root,"night-active",0.5) end
    if offset>=120 and offset<=140 then
        -- Consecutive world-yaw increments within the north placement arc.
        local yaw=(offset-130)*360/256
        local screen=math.atan2(math.sin(math.rad(yaw)),math.cos(math.rad(yaw))*projection)/(2*math.pi)%1
        local record=root.visual[5];record.entity.active=false;record.entity.orientation=screen
        capture(root,"fine-"..(offset-120),0,4,{record.entity.position.x,record.entity.position.y-0.3},{512,512})
    end
    if offset==145 then root.visual[5].entity.active=true end
    if offset==160 then for _,record in ipairs(root.visual) do if record.target and record.target.valid then record.target.destroy() end end end
    if offset>=160 and offset<=205 then
        local p=root.visual[5].entity.position
        capture(root,"shutdown-"..(offset-160),0.5,4,{p.x,p.y-0.3},{512,512})
    end
    if offset==230 then capture(root,"night-idle",0.5) end
    if offset==231 then
        capture(root,"day-idle",0,nil,nil,nil,root.cover_surface)
        capture(root,"covers-only",0,1.2,{0,-4.8},{1280,350},root.cover_surface)
    end
    if offset>=232 and offset<=239 then
        local index=offset-231;local record=root.cover_visual[index];local p=record.entity.position
        capture(root,(index<=4 and "capped-" or "connected-")..record.facing,0,3,{p.x,p.y-0.3},{512,512},root.cover_surface)
    end
    if offset>=240 and offset<=247 then
        local record=root.overlap_visual[offset-239];local p=record.entity.position
        capture(root,"overlap-"..record.facing.."-"..record.variant,0,3,{p.x,p.y-0.3},{640,640},root.overlap_surface)
    end
    if offset==260 then
        local rows={};local all_pass=true
        for id,record in pairs(root.probes) do
            local launch=root.launches[id]
            local row={facing=record.facing,relative_degrees=record.angle,launch=launch,
                status=record.entity.status,fluid=record.entity.get_fluid_contents(),orientation=record.entity.orientation,
                shooting=record.entity.shooting_target and record.entity.shooting_target.name}
            if launch then
                local shift=record.shift
                local angle=launch.orientation*2*math.pi
                local dx,dy=math.sin(angle),-math.cos(angle)
                local length=0.835/math.sqrt(dx*dx+2*dy*dy)
                row.expected={x=shift[1]+dx*length,y=shift[2]-height+dy*length}
                row.actual={x=launch.position.x-record.position.x,y=launch.position.y-record.position.y}
                row.error=math.sqrt((row.expected.x-row.actual.x)^2+(row.expected.y-row.actual.y)^2)
                row.pass=row.error<0.035
            else row.pass=false end
            all_pass=all_pass and row.pass;rows[#rows+1]=row
        end
        helpers.write_file("acid-art-qc.json",helpers.table_to_json{all_pass=all_pass,muzzle=rows,captures=root.captures},false)
        log("ACID_ART_RUNTIME all_pass="..tostring(all_pass))
    end
end)
