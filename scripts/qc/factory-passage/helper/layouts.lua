local layouts={}
local function build(surface,name,x,y,direction,quality)
    return assert(surface.create_entity{name=name,position={x,y},direction=direction,quality=quality,force="player",snap_to_grid=false,raise_built=true})
end
layouts.build=build

function layouts.create(surface)
    local walkers={}
    local row=0
    local function lane(name,body,shape,options)
        local y=row*18;row=row+1
        local xshift=body=="ei-passage-qc-heat" and 0.5 or 0
        y=y+xshift
        local entities={}
        for x=-16,shape=="corner" and 0 or 16 do entities[#entities+1]=build(surface,body,x+xshift,y) end
        if shape=="corner" or shape=="tee" or shape=="cross" or shape=="grid" then
            for dy=1,6 do build(surface,body,(shape=="corner" and 0 or -3)+xshift,y+dy) end
        end
        if shape=="cross" or shape=="grid" then for dy=1,6 do build(surface,body,-3+xshift,y-dy) end end
        if shape=="grid" then for x=-16,16 do build(surface,body,x+xshift,y+1) end end
        options=options or {}
        walkers[#walkers+1]={name=name,start={x=(shape=="corner" and -0.5 or shape and -2.5 or 0.5)+xshift,y=y-2},line=y,kind=options.kind or "joint",
            direction=options.diagonal and defines.direction.southeast or defines.direction.south,speed=options.speed or 0,
            entities=entities,body=body}
        if shape then
            local column=shape=="corner" and 0 or -3
            walkers[#walkers+1]={name=name.." vertical-arm",start={x=column-2,y=y+2.5},axis="x",line=column,kind="joint",direction=4,speed=0}
        end
        if shape=="grid" then walkers[#walkers+1]={name="grid internal lane",start={x=-8.5,y=y+0.5},axis="x",line=-8,kind="joint",direction=4,speed=0} end
        return entities
    end
    lane("straight","pipe")
    lane("diagonal","pipe",nil,{diagonal=true})
    lane("accelerated","pipe",nil,{speed=4})
    lane("corner-branch","pipe","corner")
    lane("T-junction","pipe","tee")
    lane("cross-junction","pipe","cross")
    lane("connected-grid","pipe","grid")
    local heat=lane("heat-network","ei-passage-qc-heat")
    heat[17].temperature=900
    lane("vanilla-heat-preserved","heat-pipe",nil,{kind="open"})
    for heading=0,7 do
        local y=-20+heading*30
        for _,x in ipairs{108,110,112,114,120,122,124,126} do
            local direction=(x==112 or x==114) and (heading*2+2)%16 or heading*2
            build(surface,"ei-passage-qc-eight-way",x,y,direction)
        end
        for _,x in ipairs{111,123} do
            walkers[#walkers+1]={name="eight-way "..heading..(x==111 and " mixed" or " same"),start={x=x,y=y-2},line=y,kind="turrets",direction=8,speed=0}
        end
    end
    -- Ordinary side-by-side pipes cross-connect. Different native connection
    -- categories make these two runs genuinely separate rather than a grid.
    for x=40,41 do for y=-10,10 do build(surface,"ei-passage-qc-pipe-"..(x==40 and "a" or "b"),x,y) end end
    walkers[#walkers+1]={name="separate-parallel",start={x=40.5,y=-8},line=-6,kind="lane",direction=8,speed=0}
    local underground={build(surface,"pipe-to-ground",50,0,defines.direction.west),build(surface,"pipe-to-ground",55,0,defines.direction.east)}
    build(surface,"pipe",49,0);build(surface,"pipe",56,0)
    for x=45,48 do build(surface,"pipe",x,0) end
    walkers[#walkers+1]={name="underground mouth",start={x=49.5,y=-2},line=0,kind="mouth",direction=8,speed=0}
    walkers[#walkers+1]={name="underground-span",start={x=52.5,y=-2},line=0,kind="open",direction=8,speed=0}
    local pump=build(surface,"pump",65,0,defines.direction.north)
    local pump_pipe=build(surface,"pipe",65,-1.5)
    local tank=build(surface,"storage-tank",75,0,nil,"rare")
    local tank_pipe=build(surface,"pipe",74,-2)
    local crafter=build(surface,"assembling-machine-2",85.5,0.5)
    -- A chemical plant gives a native recipe-dependent port for the observation case.
    local chemical=build(surface,"ei-passage-qc-crafter",95.5,0.5)
    chemical.set_recipe("ei-passage-qc-fluid-recipe")
    local chemical_pipe=build(surface,"pipe",94.5,-1.5)
    local reserve_pipe=build(surface,"pipe",85.5,-1.5)
    local couplings={}
    local coupling_names={"pump","storage-tank","chemical-plant"}
    for _,name in ipairs{"one-way-valve","overflow-valve","top-up-valve"} do
        if prototypes.entity[name] then coupling_names[#coupling_names+1]=name end
    end
    for family,name in ipairs(coupling_names) do
        for rotation=0,3 do
            local x,y=140.5+rotation*14,20.5+family*20
            local prototype=prototypes.entity[name]
            local width,height=prototype.tile_width,prototype.tile_height
            if rotation%2==1 then width,height=height,width end
            x=math.floor(x)+(width%2==1 and 0.5 or 0)
            y=math.floor(y)+(height%2==1 and 0.5 or 0)
            local entity=build(surface,name,x,y,rotation*4)
            if name=="chemical-plant" then entity.set_recipe("ei-passage-qc-fluid-recipe") end
            local port
            for index=1,entity.fluids_count do
                for _,connection in ipairs(entity.get_fluid_box_pipe_connections(index) or {}) do
                    if connection.connection_type=="normal" then port=connection;break end
                end
                if port then break end
            end
            assert(port,"Missing native coupling port: "..name)
            local pipe=build(surface,"pipe",port.target_position.x,port.target_position.y)
            local p,q=port.position,port.target_position
            for step=1,6 do build(surface,"pipe",q.x+(q.x-p.x)*step,q.y+(q.y-p.y)*step) end
            local vertical=math.abs(p.x-q.x)<0.01
            local mid={x=(p.x+q.x)/2,y=(p.y+q.y)/2}
            local axis=vertical and "x" or "y"
            local start={x=mid.x,y=mid.y};start[axis]=start[axis]-2
            walkers[#walkers+1]={name=name.." coupling "..rotation,start=start,axis=axis,line=mid[axis],kind="joint",direction=vertical and 4 or 8,speed=0}
            couplings[#couplings+1]={entity=entity,pipe=pipe}
        end
    end
    local behavior=pump.get_or_create_control_behavior()
    for family,name in ipairs{"flamethrower-turret","ei-acidthrower-turret"} do
        if prototypes.entity[name] then for rotation=0,7 do
            -- Both ports stay connected, but each moving character gets its own
            -- turret copy. Crossing actor paths otherwise contaminate the test.
            for watched=1,2 do
                local entity=build(surface,name,40+rotation*18,160+family*25-(watched-1)*256,rotation*2)
                local ports=entity.get_fluid_box_pipe_connections(1)
                assert(#ports==2,"Expected two native turret ports")
                for index,port in ipairs(ports) do
                    if port.connection_type=="normal" then
                        local p,q=port.position,port.target_position
                        local pipe=build(surface,"pipe",q.x,q.y)
                        for step=1,6 do build(surface,"pipe",q.x+(q.x-p.x)*step,q.y+(q.y-p.y)*step) end
                        if index==watched then
                            local vertical=math.abs(p.x-q.x)<0.01
                            local mid={x=(p.x+q.x)/2,y=(p.y+q.y)/2}
                            local axis=vertical and "x" or "y"
                            local start={x=mid.x,y=mid.y};start[axis]=start[axis]-2
                            walkers[#walkers+1]={name=name.." port "..index.." heading "..(rotation*2),start=start,axis=axis,line=mid[axis],kind="joint",direction=vertical and 4 or 8,speed=0}
                        end
                        couplings[#couplings+1]={entity=entity,pipe=pipe}
                    end
                end
            end
        end end
    end
    behavior.circuit_enable_disable=true
    behavior.circuit_condition={condition={comparator=">",first_signal={type="virtual",name="signal-A"},constant=2}}
    local reactors={build(surface,"nuclear-reactor",120.5,180.5),build(surface,"nuclear-reactor",125.5,180.5)}
    for _,reactor in ipairs(reactors) do
        for name,item in pairs(prototypes.item) do
            local compatible=false
            for _,category in pairs(item.fuel_categories or {}) do if reactor.burner.fuel_categories[category] then compatible=true end end
            if compatible then reactor.insert{name=name,count=1};break end
        end
    end
    local names={"ei-steam-crusher","ei-burner-heater","ei-steam-assembler"}
    for index,name in ipairs(names) do
        if prototypes.entity[name] then
            local y=190+index*16
            for x=-12,12,3 do build(surface,name,x+0.5,y+0.5) end
            walkers[#walkers+1]={name=name,start={x=2,y=y-2.5},line=y+0.5,kind=name=="ei-steam-assembler" and "open" or name=="ei-burner-heater" and "power" or "production",direction=8,speed=0}
        end
    end
    -- Isolated finite inventories are snapshot before and after all mode changes.
    local fluid={}
    for x=110,114 do fluid[#fluid+1]=build(surface,"pipe",x,0) end
    fluid[1].insert_fluid{name="water",amount=200,temperature=80}
    tank.insert_fluid{name="water",amount=1200,temperature=65}
    return {walkers=walkers,heat=heat,underground=underground,pump=pump,pump_pipe=pump_pipe,tank=tank,tank_pipe=tank_pipe,
        crafter=crafter,reserve_pipe=reserve_pipe,chemical=chemical,chemical_pipe=chemical_pipe,fluid=fluid,couplings=couplings,reactors=reactors}
end

function layouts.snapshot(surface)
    local entities={}
    for _,entity in pairs(surface.find_entities_filtered{type={"pipe","pipe-to-ground","pump","storage-tank","heat-pipe","assembling-machine","reactor"}}) do
        local fluid={};local connections={}
        for index=1,entity.fluids_count do
            fluid[index]=entity.get_fluid(index) or false
            for _,connection in pairs(entity.get_fluid_box_pipe_connections(index) or {}) do
                if connection.target then connections[#connections+1]=connection.target.unit_number..":"..connection.connection_type end
            end
        end
        table.sort(connections)
        local heat={}
        for _,other in ipairs(entity.heat_neighbours) do heat[#heat+1]=other.unit_number end
        table.sort(heat)
        local behavior=entity.type=="pump" and entity.get_control_behavior()
        local recipe,quality
        if entity.type=="assembling-machine" then recipe,quality=entity.get_recipe() end
        entities[tostring(entity.unit_number)]={name=entity.name,position=entity.position,direction=entity.direction,quality=entity.quality.name,
            fluid=fluid,connections=connections,temperature=entity.type=="heat-pipe" and entity.temperature or nil,heat_neighbours=heat,
            circuit=behavior and behavior.circuit_condition or nil,neighbour_bonus=entity.type=="reactor" and entity.neighbour_bonus or nil,
            recipe=recipe and recipe.name or nil,recipe_quality=quality and quality.name or nil}
    end
    return entities
end
return layouts
