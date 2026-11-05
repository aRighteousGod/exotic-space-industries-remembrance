-- Normal-only estimator coverage; the original quality donor intentionally requires Rare.
local previous=script.get_event_handler(defines.events.on_tick)
local checked=false
script.on_event(defines.events.on_tick,function(event)
    previous(event)
    if checked then return end
    checked=true
    local q=storage.__gate_estimator_normal_qc
    local function check(_,name,value) record(name,value) end
    if phase=="candidate" then
        local surface=game.create_surface("estimator-normal-qc",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        local tiles={};for x=-40,40 do for y=-40,40 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        local container=surface.create_entity{name="ei-gate-container",position={0,0},force="player"}
        ei_gate.make_gate(container,event)
        q={container=container,gate=surface.find_entity("ei-gate",container.position),checks={}}
        storage.__gate_estimator_normal_qc=q
        estimator_checks(q,event,check)
        record("normal-only multiplier",ei_gate.get_energy_multiplier(q.gate)==1)
        local player=game.players[1]
        if player then
            estimate_ui.open(player,q.gate.unit_number,event.tick)
            local viewer=storage.ei_gate_estimator.players[player.index]
            record("normal-only native selector",#viewer.qualities==1 and viewer.draft.quality=="normal")
            record("normal-only quote",estimate_ui.scenario(viewer).quality_multiplier==1)
            estimate_ui.close(player.index)
        end
    else
        record("normal-only saved source",q and q.gate.valid and q.container.valid)
        record("normal-only saved multiplier",ei_gate.get_energy_multiplier(q.gate)==1)
    end
    native_result={complete=true,checks=native_checks}
end)
remote.add_interface("esir-native-tests",{step=function() return native_result or {complete=false} end})
