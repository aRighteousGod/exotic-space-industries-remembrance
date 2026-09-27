local report = {checks={}, observations={}}
local function check(name, value)
    report.checks[name] = value == true
    assert(value, name)
end
script.on_init(function()
    local surface = game.surfaces[1]
    surface.request_to_generate_chunks({0,0}, 1)
    surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{area={{-16,-16},{16,16}}}) do entity.destroy() end
    local tiles={}
    for x=-16,16 do for y=-16,16 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    local turret=surface.create_entity{name="flamethrower-turret",position={0,0},force="player"}
    turret.health=321
    turret.kills=17
    turret.damage_dealt=1234
    turret.orientation=0.3
    turret.disabled_by_script=true
    storage.source=turret
    storage.pipe=surface.create_entity{name="pipe",position=turret.fluidbox.get_pipe_connections(1)[1].target_position,force="player"}
    local pole=surface.create_entity{name="small-electric-pole",position={4,0},force="player"}
    storage.pole=pole
    turret.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red,true))
    local behavior=turret.get_or_create_control_behavior()
    behavior.read_ammo=true
    behavior.circuit_enable_disable=true
    behavior.circuit_condition={first_signal={type="virtual",name="signal-A"},comparator=">",constant=5}
    report.observations.fluids_count=turret.fluids_count
    report.observations.fluidboxes=#turret.fluidbox
    for index=1,turret.fluids_count do
        local fluid=turret.set_fluid(index,{name=index==1 and "light-oil" or "crude-oil",amount=5,temperature=25})
        report.observations[index]=fluid
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if event.tick~=1 then return end
    local source=storage.source
    check("pipe-connected",source.fluidbox.get_pipe_connections(1)[1].target~=nil)
    local before=source.get_fluid(1)
    report.observations.before={source=before,pipe=storage.pipe.get_fluid(1),segment=source.fluidbox.get_fluid_segment_contents(1)}
    check("internal-buffer-index",source.fluids_count==2 and #source.fluidbox==1 and source.get_fluid(2).name=="crude-oil")
    local candidate=source.surface.create_entity{name="esir-flamethrower-proof",position=source.position,direction=source.direction,force=source.force,quality=source.quality,create_build_effect_smoke=false}
    check("overlapping-candidate",candidate and source.valid)
    report.observations.after_create={source=source.get_fluid(1),candidate=candidate.get_fluid(1),pipe=storage.pipe.get_fluid(1),segment=source.fluidbox.get_fluid_segment_contents(1)}
    helpers.write_file("flamethrower-proof.json",helpers.table_to_json(report),false)
    candidate.copy_settings(source)
    for _,field in ipairs{"health","kills","damage_dealt","orientation","disabled_by_script","destructible","minable","operable","rotatable","last_user"} do candidate[field]=source[field] end
    candidate.set_fluid(1,before)
    candidate.set_fluid(2,source.get_fluid(2))
    for id,connector in pairs(source.get_wire_connectors(false)) do
        for _,connection in pairs(connector.connections) do
            check("wire-copy",candidate.get_wire_connector(id,true).connect_to(connection.target, false, connection.origin))
        end
    end
    check("copy-circuit-settings",candidate.get_control_behavior().read_ammo and candidate.get_control_behavior().circuit_enable_disable)
    check("mixed-fluid-copy",candidate.get_fluid(1).name=="light-oil" and candidate.get_fluid(2).name=="crude-oil")
    -- Rollback must not modify the original or consume its fuel/wires.
    candidate.destroy()
    source.set_fluid(1,before)
    check("rollback-connected-supply",source.get_fluid(1).amount==before.amount and storage.pipe.get_fluid(1).amount==before.amount)
    check("rollback",source.valid and source.get_fluid(2).amount==5 and source.get_wire_connector(defines.wire_connector_id.circuit_red).connection_count==1)
    candidate=source.surface.create_entity{name="esir-flamethrower-proof",position=source.position,force=source.force}
    candidate.copy_settings(source)
    candidate.set_fluid(1,before)
    candidate.set_fluid(2,source.get_fluid(2))
    candidate.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(storage.pole.get_wire_connector(defines.wire_connector_id.circuit_red,true))
    source.destroy()
    check("commit-connected-supply",candidate.get_fluid(1).amount==before.amount and storage.pipe.get_fluid(1).amount==before.amount)
    check("commit",candidate.valid and candidate.get_fluid(2).amount==5 and candidate.get_wire_connector(defines.wire_connector_id.circuit_red).connection_count==1)
    report.all_pass=true
    helpers.write_file("flamethrower-proof.json",helpers.table_to_json(report),false)
end)
