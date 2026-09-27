local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local config=require("test-config")
if config.overlap then require("overlap").install(config);return end
if config.transition then require("transition").install(config);return end
if config.combat then require("combat").install();return end
if config.matrix then require("fuel-matrix").install();return end
if config.effects then require("effects").install(config);return end
local function status() return remote.call("esir-flame-qc","status") end
local function check(name,value)
    storage.report.checks[name]=value==true
    if not value then
        storage.report.status=status()
        helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
        error("Flamethrower QC: "..name)
    end
end
local function turret(position)
    return storage.surface.find_entities_filtered{position=position,type="fluid-turret"}[1]
end
local function build(name,position,fluid)
    local entity=storage.surface.create_entity{name=name,position=position,force="player",quality="rare",raise_built=true}
    assert(entity)
    entity.disabled_by_script=true
    if fluid then entity.set_fluid(2,{name=fluid,amount=5,temperature=25}) end
    return entity
end
script.on_init(function()
    storage.start=game.tick
    storage.report={checks={},performance={}}
    local surface=game.create_surface("flame-qc",{width=512,height=512,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},9)
    surface.force_generate_chunk_requests()
    storage.surface=surface
    local tiles={}
    for x=-160,160 do for y=-160,160 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    if config.performance>0 then
        for index=1,config.performance do
            local position={x=(index%40)*6-120,y=math.floor(index/40)*6-100}
            build(catalog.base_turret,position,"ei-diesel")
        end
        storage.performance_start=game.tick
        return
    end
    for i,fuel in ipairs(catalog.fuels) do
        build(config.enabled and catalog.base_turret or fuel.turret,{i*6,0},fuel.fluid)
    end
    local entity=build(catalog.base_turret,{0,10},"heavy-oil")
    entity.health=321
    entity.kills=17
    entity.damage_dealt=1234
    entity.orientation=0.35
    storage.pipe=surface.create_entity{name="pipe",position=entity.fluidbox.get_pipe_connections(1)[1].target_position,force="player"}
    entity.set_fluid(1,{name="ei-diesel",amount=7,temperature=60})
    entity.set_priority_target(1,"small-biter")
    entity.ignore_unprioritised_targets=true
    local behavior=entity.get_or_create_control_behavior()
    behavior.read_ammo=true
    behavior.circuit_enable_disable=true
    behavior.circuit_condition={first_signal={type="virtual",name="signal-A"},comparator=">",constant=5}
    local pole=surface.create_entity{name="small-electric-pole",position={4,10},force="player"}
    entity.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red,true))
    storage.original=entity
    storage.pole=pole
    game.forces.player.worker_robots_speed_modifier=10
    storage.robot_port=surface.create_entity{name="roboport",position={70,40},force="player"}
    storage.robot_port.energy=100000000
    storage.robot_port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=2}
    surface.create_entity{name="storage-chest",position={75,40},force="player"}
    build(catalog.base_turret,{80,40},"ei-diesel")
    local ghost=surface.create_entity{name="entity-ghost",inner_name=catalog.by_fluid["ei-diesel"].turret,position={-80,0},force="player",quality="rare",tags={flame_qc="retained"}}
    script.raise_script_built{entity=ghost}
    ghost=surface.find_entities_filtered{position={-80,0},type="entity-ghost"}[1]
    storage.report.ghost={name=ghost.ghost_name,quality=ghost.quality.name,tags=ghost.tags}
    local player=game.get_player(1)
    if player then
        player.cursor_stack.set_stack{name="blueprint"}
        player.cursor_stack.set_blueprint_entities{{entity_number=1,name=catalog.by_fluid["ei-diesel"].turret,position={0,0}}}
        remote.call("esir-flame-qc","blueprint",player.index)
        check("blueprint-normalized",player.cursor_stack.get_blueprint_entities()[1].name==catalog.base_turret)
        player.cursor_stack.clear()
    end
    remote.call("esir-flame-qc","fail",true)
end)

script.on_event(defines.events.on_robot_mined_entity,function(event)
    if math.abs(event.entity.position.x-80)<1 and math.abs(event.entity.position.y-40)<1 then storage.robot_mined=true end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
    if math.abs(event.entity.position.x-80)<1 and math.abs(event.entity.position.y-40)<1 then
        storage.robot_built=true
        event.entity.disabled_by_script=true
        event.entity.set_fluid(2,{name="light-oil",amount=5})
    end
end)

script.on_event(defines.events.on_tick,function(event)
    local engine_tick=event.tick
    event={tick=event.tick-storage.start}
    if storage.robot_port then storage.robot_port.energy=100000000 end
    local s=status()
    if s.counters.checks~=(storage.previous_checks or 0) or s.counters.attempts~=(storage.previous_attempts or 0) then
        check("scheduled-step-only",engine_tick%16==15)
    end
    storage.previous_checks=s.counters.checks
    storage.previous_attempts=s.counters.attempts
    check("check-cap",(s.counters.last_checks or 0)<=config.budget)
    check("replacement-budget",s.replacement_budget==config.budget)
    check("replacement-cap",(s.counters.last_attempts or 0)<=config.budget)
    storage.report.max_attempts=math.max(storage.report.max_attempts or 0,s.counters.last_attempts or 0)
    if config.performance>0 then
        -- Performance phases count dispatcher cycles, while caps are checked
        -- above on every engine tick, including the 15 unserviced steps.
        if event.tick%16~=0 then return end
        event={tick=event.tick/16}
        if event.tick==1 then remote.call("esir-flame-qc","profile","start") end
        if event.tick==2400 then
            remote.call("esir-flame-qc","profile","initial")
            storage.report.performance={count=config.performance,budget=config.budget,status=s}
            check("all-adapted",s.counters.replaced==config.performance)
            storage.replaced=s.counters.replaced
        elseif event.tick==2520 then
            check("unchanged-no-replacements",s.counters.replaced==storage.replaced)
            remote.call("esir-flame-qc","profile","start")
            for _,entity in pairs(storage.surface.find_entities_filtered{type="fluid-turret"}) do entity.set_fluid(2,{name="petroleum-gas",amount=5}) end
        elseif event.tick==4920 then
            remote.call("esir-flame-qc","profile","switch")
            check("all-switched",s.counters.replaced==config.performance*2)
            storage.report.performance.final_status=s
            storage.report.all_pass=true
            helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
        end
        return
    end
    if event.tick==65 then
        local ghost=storage.surface.find_entities_filtered{position={-80,0},type="entity-ghost"}[1]
        check("ghost-normalized",ghost.ghost_name==catalog.base_turret and ghost.quality.name=="rare" and ghost.tags.flame_qc=="retained")
        storage.report.fluids={source=storage.original.get_fluid(1),pipe=storage.pipe.get_fluid(1)}
        check("rollback-original-valid",storage.original.valid)
        check("rollback-buffer",storage.original.get_fluid(2).name=="heavy-oil" and storage.original.get_fluid(2).amount==5)
        check("rollback-connected-supply",storage.original.get_fluid(1).amount==7 and storage.pipe.get_fluid(1).amount==7)
        check("rollback-wire",storage.original.get_wire_connector(defines.wire_connector_id.circuit_red).connection_count==1)
        check("rollback-no-extra-turrets",#storage.surface.find_entities_filtered{type="fluid-turret"}==12)
        remote.call("esir-flame-qc","fail",false)
    elseif event.tick==240 then
        for i,fuel in ipairs(catalog.fuels) do
            check("fuel-"..fuel.id,turret({i*6,0}).name==(config.enabled and fuel.turret or catalog.base_turret))
        end
        local entity=turret({0,10})
        check("buffer-before-supply",entity.name==(config.enabled and catalog.by_fluid["heavy-oil"].turret or catalog.base_turret))
        check("quality-health-stats",entity.quality.name=="rare" and entity.health==321 and entity.kills==17 and entity.damage_dealt==1234)
        check("both-fluid-storages",entity.get_fluid(1).name=="ei-diesel" and entity.get_fluid(1).amount==7 and entity.get_fluid(1).temperature==60 and entity.get_fluid(2).amount==5)
        check("connected-supply-preserved",storage.pipe.get_fluid(1).amount==7 and storage.pipe.get_fluid(1).temperature==60)
        check("wire-and-condition",entity.get_wire_connector(defines.wire_connector_id.circuit_red).connection_count==1 and entity.get_control_behavior().circuit_condition.constant==5)
        check("priority",entity.get_priority_target(1).name=="small-biter" and entity.ignore_unprioritised_targets)
        entity.set_fluid(2,nil)
        turret({80,40}).order_deconstruction(game.forces.player)
        storage.stable_count=s.counters.replaced
    elseif event.tick==360 then
        local robot_entity=turret({80,40})
        storage.report.robot={exists=robot_entity~=nil,marked=robot_entity and robot_entity.to_be_deconstructed(),minable=robot_entity and robot_entity.minable,robots=storage.robot_port.get_inventory(defines.inventory.roboport_robot).get_contents(),energy=storage.robot_port.energy}
        check("native-robot-mining",storage.robot_mined==true)
        storage.surface.create_entity{name="entity-ghost",inner_name=catalog.base_turret,position={80,40},quality="rare",force="player",expires=false}
        local entity=turret({0,10})
        check("empty-buffer-fallback",entity.name==(config.enabled and catalog.by_fluid["ei-diesel"].turret or catalog.base_turret))
        entity.set_fluid(1,nil)
        entity.set_fluid(2,nil)
        storage.empty_unit=entity.unit_number
        storage.stable_count=s.counters.replaced
        storage.stable_checks=s.counters.checks
    elseif event.tick==480 then
        check("empty-retains-variant",turret({0,10}).unit_number==storage.empty_unit)
        if not config.enabled then check("disabled-idle",s.count==0 and s.counters.checks==storage.stable_checks) end
        local force=game.forces.player
        force.technologies.flamethrower.researched=true
        force.technologies["ei-destill-tower"].researched=true
        force.set_turret_attack_modifier(catalog.base_turret,0.7)
        remote.call("esir-flame-qc","sync_force",force.index)
        for _,fuel in ipairs(catalog.fuels) do check("research-"..fuel.id,math.abs(force.get_turret_attack_modifier(fuel.turret)-0.7)<0.00001) end
        check("old-save-unlock",force.recipes["ei-flamethrower-ammo-kerosene"].enabled)
        local source=turret({0,10})
        local clone=source.clone{position={0,20},surface=storage.surface,force=force}
        clone.set_fluid(2,{name="light-oil",amount=5})
        source.destroy{raise_destroy=true}
    elseif event.tick==500 then
        local clone=turret({0,20})
        local reference=storage.surface.create_entity{name=catalog.base_turret,position={-20,20},force="player",quality=clone.quality}
        reference.disabled_by_script=true
        reference.set_fluid(2,clone.get_fluid(2))
        check("native-rotation-parity",clone.rotate()==reference.rotate())
        reference.destroy()
        clone.direction=defines.direction.east
        storage.clone_direction=clone.direction
        check("native-teleport",clone.teleport({2,20}))
        clone.set_fluid(2,{name="petroleum-gas",amount=5})
    elseif event.tick==600 then
        check("native-robot-building",storage.robot_built==true)
        check("robot-build-adapts",turret({80,40}).name==(config.enabled and catalog.by_fluid["light-oil"].turret or catalog.base_turret))
        local clone=turret({2,20})
        check("clone-adapts",clone.name==(config.enabled and catalog.by_fluid["petroleum-gas"].turret or catalog.base_turret))
        check("rotation-teleport-preserved",clone.direction==storage.clone_direction)
        local player=game.get_player(1)
        if player then
            player.teleport({6,4},storage.surface)
            check("native-player-mining",player.mine_entity(turret({6,0})))
            player.cursor_stack.set_stack{name=catalog.base_turret,count=1,quality="rare"}
            player.build_from_cursor{position={6,0}}
            check("native-player-building",turret({6,0})~=nil)
        end
        for _,entity in pairs(storage.surface.find_entities_filtered{type="fluid-turret"}) do entity.destroy() end
    elseif event.tick==610 then
        if not config.enabled then
            check("full-restoration-budget",storage.report.max_attempts==math.min(config.budget,10))
        end
        check("destroy-without-event-cleanup",s.count==0)
        check("dispatcher-idle",not remote.call("esir-flame-qc","has_tick_work"))
        storage.report.status=s
        storage.report.all_pass=true
        helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
    end
end)
