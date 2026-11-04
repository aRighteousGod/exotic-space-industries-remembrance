-- Interactive fixture: real mouse inputs must select ash, Off, On, then ash-free.
-- Installed only by manual.py in a managed private copy; no simulated GUI events.
local support=require("__esir-qc-native-tests__.support")
local config=require("__exotic-space-industries-remembrance__/lib/combustion-turbine-config")
local function poll(model,tick)
    local state=storage.turbine_manual
    if support.phase()=="reload" then
        support.record("mouse-transitions-persist",state and state.stage==4)
        support.complete();return support.poll()
    end
    if not state then
        local surface=game.create_surface("turbine-mouse-check",{width=64,height=64})
        surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
        surface.set_tiles(tiles);surface.set_property("pressure",33)
        local entity=surface.create_entity{name=config.solid,position={0,0},force="player"}
        entity=model.on_built_entity{entity=entity,tick=tick,tags={[config.oxygen_tag]=true}}
        entity.insert{name="coal",count=50}
        surface.create_entity{name="substation",position={8,0},force="player"}
        surface.create_entity{name="esir-turbine-integration-load",position={8,4},force="player"}
        local player=assert(game.connected_players[1])
        player.teleport({0,8},surface)
        player.zoom=0.8
        player.opened=entity
        model.open_gui(player,entity,tick)
        state={stage=0,player=player,surface=surface,started=tick}
        storage.turbine_manual=state
        log("TURBINE MOUSE CHECK READY: select ash, Enabled off, Enabled on, then ash-free")
    end
    local entity=state.surface.find_entities_filtered{type="assembling-machine"}[1]
    if not entity then return end
    local record=storage.ei.combustion_turbine.turbines_by_unit[entity.unit_number]
    -- Fixture-only supplies keep the displayed native generator under full load.
    entity.set_fluid(1,{name="ei-oxygen-gas",amount=200})
    record.generator.clear_fluid(2)
    entity.get_burnt_result_inventory().clear()
    local next_stage=(state.stage==0 and record.ash_requested)
        or (state.stage==1 and not record.enabled)
        or (state.stage==2 and record.enabled)
        or (state.stage==3 and not record.ash_requested)
    if next_stage then
        state.stage=state.stage+1
        support.record("mouse-transition-"..state.stage,true)
        state.capture_due=tick+60
        log("TURBINE MOUSE CHECK STAGE "..state.stage)
    end
    if state.capture_due and tick>=state.capture_due then
        game.take_screenshot{player=state.player,path="turbine-native/mouse-"..state.stage..".png",resolution={1440,900},show_gui=true}
        state.capture_due=nil
        if state.stage==4 then state.finish_due=tick+10 end
    end
    if state.finish_due and tick>=state.finish_due then support.complete();return support.poll() end
end
return {step=function(model,tick)
    local ok,result=xpcall(function() return poll(model,tick) end,debug.traceback)
    if not ok then support.record("mouse-fixture-exception",false,result);support.complete();return support.poll() end
    return result
end}
