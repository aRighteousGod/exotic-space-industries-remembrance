-- Native shell transactions, fuel custody, wiring and object-destruction lifecycle.
local api="esir-turbine-qc"
local loaded=false
script.on_load(function() loaded=true end)
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end
end)
local function check(value, message)
    storage.report.checks=storage.report.checks+1
    if not value then table.insert(storage.report.failures,message) end
end
local function near(a,b) return math.abs(a-b)<1e-6 end
local function screenshot(args)
    if #game.connected_players>0 then game.take_screenshot(args) end
end
local function physical_fluid_total(entity)
    local total,seen=0,{}
    for index=1,entity.fluids_count do
        if entity.has_fluid_segment(index) then
            local id=entity.get_fluid_segment_id(index)
            if not seen[id] then
                seen[id]=true
                local fluid=entity.get_fluid_segment_fluid(index)
                total=total+(fluid and fluid.amount or 0)
            end
        else
            local fluid=entity.get_fluid(index)
            total=total+(fluid and fluid.amount or 0)
        end
    end
    return total
end
local function spawn(name, x)
    return assert(storage.surface.create_entity{name=name,position={x,0},force="player",quality="rare"})
end
local function prepare(entity,tick)
    entity.health=123
    entity.energy=12345
    entity.minable_flag=false
    entity.destructible=false
    entity.operable=false
    entity.rotatable=false
    entity.disabled_by_script=true
    remote.call(api,"register",entity,tick)
    local peer=assert(storage.surface.create_entity{name="constant-combinator",
        position={entity.position.x,6},force="player"})
    local wire=entity.get_wire_connector(defines.wire_connector_id.circuit_red,true)
    storage.wire_supported[peer.unit_number]=wire~=nil
    storage.report.native_red_circuit_support[entity.name]=wire~=nil
    if wire then
        check(wire.connect_to(peer.get_wire_connector(defines.wire_connector_id.circuit_red,true)),"Wire connected")
    end
    return peer
end
local function verify(entity, name, peer)
    check(entity and entity.valid,"Replacement valid")
    if not (entity and entity.valid) then return end
    check(entity.name==name,"Requested/restored shell identity")
    check(entity.quality.name=="rare","Rare quality preserved")
    check(near(entity.health,123),"Health preserved")
    check(near(entity.energy,12345),"Energy preserved")
    check(entity.minable_flag==false,"Minable flag preserved")
    check(entity.destructible==false,"Destructible flag preserved")
    check(entity.operable==false,"Operable flag preserved")
    check(entity.rotatable==false,"Rotatable flag preserved")
    check(entity.disabled_by_script==true,"Script disabled flag preserved")
    local wire=entity.get_wire_connector(defines.wire_connector_id.circuit_red,false)
    local connected=false
    for _,connection in pairs(wire and wire.real_connections or {}) do
        if connection.target.owner==peer then connected=true end
    end
    if storage.wire_supported[peer.unit_number] then
        check(connected,"Red circuit connection preserved")
    else
        check(wire==nil,"Native absence of a red connector is unchanged")
    end
end
local function ground_count(name)
    local count=0
    for _,item in pairs(storage.surface.find_entities_filtered{type="item-entity"}) do
        if item.stack.name==name and item.stack.quality.name=="rare" then count=count+item.stack.count end
    end
    return count
end

script.on_event(defines.events.on_tick,function(event)
    if loaded then
        loaded=false
        if storage.report and storage.report.passed then
            storage.reload_start=event.tick
            local state=remote.call(api,"status")
            check(state.tracked_turbines==4,"Actual reload retains four turbine owners")
            check(state.solid_mode_turbines==3 and state.fluid_mode_turbines==1,"Actual reload retains modes")
            check(storage.clone.valid and storage.gui_solid.valid and storage.solid.valid,"Actual reload retains body identities")
            local record=remote.call(api,"record",storage.clone)
            check(record and record.proxy and record.proxy.valid,"Actual reload retains clone proxy ownership")
            remote.call(api,"open",1,storage.clone,event.tick)
            local gui=remote.call(api,"gui",1)
            storage.report.reload_gui={valid=gui.valid,mode=gui.mode,unit=gui.unit,
                clone_name=storage.clone.name,clone_position=storage.clone.position,
                record_mode=record.mode,proxy_position=record.proxy.position,
                connected=game.get_player(1).connected}
            check(gui.valid and gui.mode=="fluid","Reloaded service-hatch GUI opens in fluid mode")
        end
    end
    if storage.reload_start then
        local elapsed=event.tick-storage.reload_start
        if elapsed==2 then
            screenshot{player=1,path="turbine-fluid-reload.png",show_gui=true,
                position=storage.clone.position,surface=storage.surface,resolution={1600,1000},zoom=0.8}
        elseif elapsed==3 then
            remote.call(api,"native_close",1)
            check(not remote.call(api,"gui",1).valid,"Native close still closes the current fluid console")
            remote.call(api,"open",1,storage.clone,event.tick)
            check(remote.call(api,"gui",1).valid,"Current fluid console reopens after native close")
        elseif elapsed==5 then
            remote.call(api,"open",1,storage.gui_solid,event.tick)
            check(remote.call(api,"gui",1).valid,"Reloaded solid GUI opens")
        elseif elapsed==7 then
            screenshot{player=1,path="turbine-solid-reload.png",show_gui=true,
                position=storage.gui_solid.position,surface=storage.surface,resolution={1600,1000},zoom=0.8}
        elseif elapsed==10 then
            remote.call(api,"leave",1)
            storage.report.passed=#storage.report.failures==0
            helpers.write_file("turbine-client-reload.json",helpers.table_to_json(storage.report),false)
            assert(storage.report.passed,helpers.table_to_json(storage.report.failures))
            log("TURBINE RELOAD COMPLETE")
            game.auto_save("turbine-client-reloaded")
        end
        return
    end
    if event.tick==1 then
        storage.report={version=script.active_mods.base,checks=0,failures={},native_red_circuit_support={}}
        storage.wire_supported={}
        storage.surface=game.create_surface("turbine-transaction-qc",{width=256,height=128})
        storage.surface.request_to_generate_chunks({0,0},4)
        storage.surface.force_generate_chunk_requests()
        for _,entity in pairs(storage.surface.find_entities()) do entity.destroy() end
        local solid=spawn("ei-combustion-turbine",-80)
        local peer=prepare(solid,event.tick)
        check(solid.get_fuel_inventory().insert{name="coal",count=17,quality="rare"}==17,"Solid fuel seeded")
        local fluid=remote.call(api,"swap",solid,"fluid",event.tick)
        verify(fluid,"ei-combustion-turbine-fluid",peer)
        check(ground_count("coal")==17,"Successful solid-to-fluid switch refunds 17 rare coal")
        local record=remote.call(api,"record",fluid)
        check(record and record.proxy and record.proxy.valid,"Fluid GUI proxy created")
        storage.fluid=fluid
        storage.old_proxy=record.proxy.unit_number
        record.proxy.destroy()

        local rollback=spawn("ei-combustion-turbine",-30)
        peer=prepare(rollback,event.tick)
        rollback.get_fuel_inventory().insert{name="coal",count=13,quality="rare"}
        rollback.burner.currently_burning="coal"
        rollback.burner.remaining_burning_fuel=123456
        local restored=remote.call(api,"swap",rollback,"fluid",event.tick,1)
        check(restored==rollback,"Failed solid switch retains original identity")
        verify(restored,"ei-combustion-turbine",peer)
        check(restored.get_fuel_inventory().get_item_count{name="coal",quality="rare"}==13,"Failed switch retains fuel in inventory")
        check(near(restored.burner.remaining_burning_fuel,123456),"Failed switch retains burning fuel energy")
        check(ground_count("coal")==17,"Failed switch does not spill another 13 rare coal")
        storage.solid=restored

        local fluid_source=spawn("ei-combustion-turbine-fluid",30)
        peer=prepare(fluid_source,event.tick)
        local pipe=assert(storage.surface.create_entity{name="pipe",position={35,0},force="player"})
        check(fluid_source.has_fluid_segment(1),"Fluid shell has a segment")
        fluid_source.set_fluid_segment_fluid(1,{name="ei-diesel",amount=230,temperature=60})
        local before=fluid_source.get_fluid_segment_fluid(1)
        restored=remote.call(api,"swap",fluid_source,"solid",event.tick,1)
        check(restored==fluid_source,"Failed fluid switch retains original identity")
        verify(restored,"ei-combustion-turbine-fluid",peer)
        local after=restored.get_fluid_segment_fluid(1)
        storage.report.fluid_before=before
        storage.report.fluid_after=after
        check(after and near(after.amount,before.amount),"Failed switch retains connected fluid total")
        check(after and near(after.temperature,60),"Failed switch retains fluid temperature")
        storage.restored=restored
    elseif event.tick==5 then
        local record=remote.call(api,"record",storage.fluid)
        check(record and record.proxy and record.proxy.valid,"Destroyed GUI proxy recreated")
        check(record.proxy.unit_number~=storage.old_proxy,"Proxy replacement has a new identity")
        local proxy=record.proxy
        storage.fluid.destroy()
        storage.removed_proxy=proxy
    elseif event.tick==10 then
        check(not storage.removed_proxy.valid,"Destroyed turbine removes its GUI proxy")
        remote.call(api,"rebuild",event.tick)
        local state=remote.call(api,"status")
        check(state.tracked_turbines==2,"Rebuild tracks exactly two surviving turbines")
        check(state.fluid_mode_turbines==1 and state.solid_mode_turbines==1,"Rebuild retains both modes")
        local proxies=storage.surface.find_entities_filtered{name="ei-combustion-turbine-fluid-open-proxy"}
        check(#proxies==1,"Rebuild leaves exactly one owned GUI proxy")
        storage.report.status=state
        helpers.write_file("turbine-runtime.json",helpers.table_to_json(storage.report),false)
        assert(#storage.report.failures==0,helpers.table_to_json(storage.report.failures))
        log("TURBINE TRANSACTIONS COMPLETE")
    elseif event.tick==12 and game.get_player(1) then
        local player=game.get_player(1)
        player.teleport({30,10},storage.surface)
        storage.restored.operable=true
        remote.call(api,"open",player.index,storage.restored,event.tick)
        local gui=remote.call(api,"gui",player.index)
        check(gui.valid and gui.mode=="fluid","Native fluid GUI opens")
        storage.gui_unit=gui.unit
    elseif event.tick==14 and game.get_player(1) then
        screenshot{player=1,path="turbine-fluid.png",show_gui=true,
            position=storage.restored.position,surface=storage.surface,resolution={1280,800},zoom=0.8}
    elseif event.tick==20 and game.get_player(1) then
        local gui=remote.call(api,"gui",1,"solid",event.tick,1)
        check(gui.valid and gui.unit==storage.gui_unit and gui.mode=="fluid","Failed GUI switch retains viewer and source")
        check(near(physical_fluid_total(gui.entity),230),"Failed GUI switch retains 230 diesel including private buffer")
    elseif event.tick==25 and game.get_player(1) then
        local gui=remote.call(api,"gui",1,"solid",event.tick)
        check(gui.valid and gui.unit~=storage.gui_unit and gui.mode=="solid","Successful GUI switch retargets viewer")
        check(gui.tags.unit_number==gui.unit,"GUI tags follow replacement identity")
        storage.gui_solid=gui.entity
    elseif event.tick==27 and game.get_player(1) then
        screenshot{player=1,path="turbine-solid.png",show_gui=true,
            position=storage.gui_solid.position,surface=storage.surface,resolution={1280,800},zoom=0.8}
    elseif event.tick==30 then
        local tagged=spawn("ei-combustion-turbine",80)
        local position=tagged.position
        remote.call(api,"register",tagged,event.tick,{ei_combustion_turbine_mode="fluid"})
        check(not tagged.valid,"Fluid build tag changes canonical solid shell")
        local fluid=storage.surface.find_entities_filtered{name="ei-combustion-turbine-fluid",position=position,radius=1}[1]
        check(fluid and fluid.valid,"Tagged build creates fluid shell")
        helpers.write_file("turbine-build-debug.json",helpers.table_to_json{position=position,
            failures=storage.report.failures,tagged_valid=tagged.valid},false)
        assert(fluid,"Tagged fluid shell was not found")
        storage.clone=fluid.clone{position={80,30},surface=storage.surface,force="player"}
        check(storage.clone and storage.clone.valid,"Native clone created")
        remote.call(api,"paste",storage.solid,fluid,event.tick)
        check(not fluid.valid,"Settings paste changes destination mode")
        check(#storage.surface.find_entities_filtered{name="ei-combustion-turbine",position=position,radius=1}==1,"Pasted solid mode retained")
    elseif event.tick==35 then
        local record=remote.call(api,"record",storage.clone)
        check(record and record.proxy and record.proxy.valid,"Native clone owns its GUI proxy")
        check(record.proxy.position.x==storage.clone.position.x and record.proxy.position.y==storage.clone.position.y,
            "Off-grid clone and GUI proxy share the exact position")
        local proxy_unit=record.proxy.unit_number
        remote.call(api,"register",storage.clone,event.tick)
        check(remote.call(api,"record",storage.clone).proxy.unit_number==proxy_unit,"Clone proxy remains stable on registration")
        if game.get_player(1) then
            remote.call(api,"leave",1)
            check(not remote.call(api,"gui",1).valid,"Player departure closes turbine GUI")
            check(remote.call(api,"status").open_gui_count==0,"Player departure clears viewer state")
        end
    elseif event.tick==40 then
        storage.report.passed=#storage.report.failures==0
        helpers.write_file("turbine-client.json",helpers.table_to_json(storage.report),false)
        assert(storage.report.passed,helpers.table_to_json(storage.report.failures))
        log("TURBINE ACTORS COMPLETE")
        if game.get_player(1) then game.auto_save("turbine-accepted") end
    end
end)
