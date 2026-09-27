local model={}
local deltas={{0,-12},{12,-12},{12,0},{12,12},{0,12},{-12,12},{-12,0},{-12,-12}}
function model.setup(tick)
    storage.muzzle={started=tick,events={},turrets={}}
    local surface=game.create_surface("water-muzzle-qc",{width=1024,height=1024,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},12);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    for row,key in ipairs{"a","b","c","d","e"} do for direction=0,7 do
        local id=key.."-"..direction
        local p={x=-279.5+direction*80,y=-199.5+row*80}
        local delta=deltas[direction+1]
        local turret=surface.create_entity{name="esir-water-qc-muzzle-"..id,position=p,force="player"}
        turret.insert_fluid{name="water",amount=100}
        local target=surface.create_entity{name="esir-water-qc-target",position={p.x+delta[1],p.y+delta[2]},force="enemy"}
        target.active=false
        storage.muzzle.turrets[id]={position=p,delta=delta,entity=turret}
    end end
    surface.create_entity{name="esir-water-qc-calibration",position={400,0},source_position={401.25,-2.5},target_position={410,0},force="player"}
end
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id:sub(1,13)~="water-muzzle-" then return end
    local records=storage.muzzle.events
    if not records[event.effect_id] then
        records[event.effect_id]={source=event.source_position,target=event.target_position,
            entity=event.source_entity and event.source_entity.valid and event.source_entity.name or nil}
    end
end)
function model.update(tick)
    local root=storage.muzzle
    if tick-root.started~=600 then return end
    local cases={}
    local calibration=root.events["water-muzzle-calibration"]
    cases.calibration={pass=calibration and calibration.source and math.abs(calibration.source.x-401.25)<0.001 and math.abs(calibration.source.y+2.5)<0.001,detail=calibration}
    local all_pass=cases.calibration.pass==true
    for id,record in pairs(root.turrets) do
        local impact=root.events["water-muzzle-impact-"..id]
        local launch=root.events["water-muzzle-launch-"..id]
        local row={pass=impact~=nil and launch~=nil,center=record.position,delta=record.delta,impact=impact,launch=launch}
        for _,kind in ipairs{"impact","launch"} do
            local event=row[kind]
            if event and event.source then event.offset={x=event.source.x-record.position.x,y=event.source.y-record.position.y} end
        end
        if id:sub(1,1)=="e" and launch and launch.offset then
            local dx,dy=record.delta[1],record.delta[2]+1.3620957621
            local f=2.5962124/math.sqrt(dx*dx+2*dy*dy)
            row.expected={x=dx*f,y=dy*f-1.3620957621}
            row.error=math.sqrt((launch.offset.x-row.expected.x)^2+(launch.offset.y-row.expected.y)^2)
            row.pass=row.pass and row.error<0.02 -- Native positions quantize to 1/256 tile.
        end
        cases[id]=row;all_pass=all_pass and row.pass
    end
    helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=all_pass,cases=cases},false)
end
return model
