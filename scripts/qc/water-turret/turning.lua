-- Real engine samples: scripted suppression must turn before spending water.
local model={}
local speed,height=0.02,1.3620957621
local function delta(a,b) return (a-b+0.5)%1-0.5 end
local function call(name,...) return remote.call("ei-water-qc",name,...) end

local function setup(tick)
    local root={started=tick,cases={}}
    storage.water_turning=root
    local specs={
        {name="long",from=0.05,to=0.42},
        {name="wrap-positive",from=0.97,to=0.03},
        {name="wrap-negative",from=0.03,to=0.97},
        {name="half-turn",from=0.25,to=0.75},
        {name="cancel",from=0.05,to=0.45,cancel=true},
        {name="blackout",from=0.05,to=0.45,blackout=true},
        {name="enemy-first-idle",from=0.05,to=0.42,mode=1},
    }
    for index,spec in ipairs(specs) do
        local position={x=-249.5+(index-1)*70,y=200.5}
        local entity=storage.surface.create_entity{name="ei-water-turret",position=position,force="player",raise_built=true}
        entity.insert_fluid{name="water",amount=15}
        call("preferences",entity,spec.mode or 3,false)
        entity.orientation=spec.from
        local angle=spec.to*2*math.pi
        local fire=storage.surface.create_entity{name="ei-oil-fire-flame",
            position={position.x+math.sin(angle)*12,position.y-math.cos(angle)*12-height},force="neutral"}
        spec.entity,spec.fire,spec.previous=entity,fire,entity.orientation
        spec.goal=(math.atan2(fire.position.y-position.y+height,fire.position.x-position.x)/(2*math.pi)+0.25)%1
        spec.sign=delta(spec.goal,spec.previous)>0 and 1 or -1
        spec.steps,spec.bounded,spec.shortest,spec.before_alignment=0,true,true,true
        spec.direction=entity.direction
        spec.ports=helpers.table_to_json(entity.fluidbox.get_pipe_connections(1))
        root.cases[#root.cases+1]=spec
    end
end

function model.update(tick,check)
    if not storage.water_turning then
        if tick-storage.started<1000 then return end
        setup(tick)
    end
    local root=storage.water_turning
    if root.finished then return end
    for _,record in ipairs(root.cases) do
        local entity=record.entity
        local step=delta(entity.orientation,record.previous)
        if math.abs(step)>0.000001 then
            record.steps=record.steps+1
            record.bounded=record.bounded and math.abs(step)<=speed+0.0001
            if not record.shot then record.shortest=record.shortest and step*record.sign>=-0.0001 end
        end
        local water=entity.get_fluid_count("water")
        if not record.shot and water<14.99 then
            record.shot=tick
            record.before_alignment=math.abs(delta(record.goal,entity.orientation))<0.0001
            record.spent=15-water
        end
        local power=call("record",entity).power
        if record.cancel and record.steps>=3 and not record.cancelled then
            record.fire.destroy();record.cancelled=tick
        end
        if record.blackout and record.steps>=3 and not record.pause then
            record.pause=tick;record.paused_orientation=entity.orientation
        end
        if record.pause and tick-record.pause<60 then
            power.energy=0
            record.paused_safe=(record.paused_safe~=false) and not record.shot
                and math.abs(delta(entity.orientation,record.paused_orientation))<0.0001
        else power.energy=50000 end
        record.previous=entity.orientation
    end
    -- Initial stagger/search delays plus blackout recovery can exceed 200 ticks.
    if tick-root.started<400 then return end
    for _,record in ipairs(root.cases) do
        local name="turn-"..record.name
        log(name.." "..helpers.table_to_json{steps=record.steps,orientation=record.entity.orientation,
            goal=record.goal,shot=record.shot,water=record.entity.get_fluid_count("water"),
            bounded=record.bounded,shortest=record.shortest,pause=record.pause})
        check(name.."-bounded",record.bounded,{steps=record.steps,orientation=record.entity.orientation})
        check(name.."-shortest",record.shortest)
        check(name.."-multiple-steps",record.steps>1,record.steps)
        check(name.."-base-and-ports",record.entity.direction==record.direction
            and helpers.table_to_json(record.entity.fluidbox.get_pipe_connections(1))==record.ports)
        if record.cancel then
            check(name.."-no-shot",not record.shot and record.entity.get_fluid_count("water")==15)
        else
            check(name.."-aligned-before-water",record.before_alignment and record.shot~=nil)
            check(name.."-one-pulse",record.spent and math.abs(record.spent-15)<0.001)
            check(name.."-extinguished",not record.fire.valid)
        end
        if record.blackout then check(name.."-pause-and-resume",record.paused_safe and record.shot~=nil and record.shot>record.pause+60) end
    end
    root.finished=true
end
return model
