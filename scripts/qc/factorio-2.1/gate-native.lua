-- Private staged owner fixture: native transport, circuit control and physical travel.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local first=true
    local checked_reload=false
    local gate_model=ei_gate
    local function check(q,label,condition)
        q.checks[#q.checks+1]={name=label,pass=not not condition}
        assert(condition,label)
    end
    local function snapshot(q)
        local g=storage.ei.gate.gate[q.gate.unit_number]
        local receivers={}
        for _,entity in ipairs(q.receivers) do
            local row=storage.ei.gate.receiver[entity.unit_number]
            receivers[#receivers+1]={unit=entity.unit_number,id=row.effective_id,
                items=entity.get_inventory(defines.inventory.chest).get_contents()}
        end
        return {unit=q.gate.unit_number,container=q.container.unit_number,
            proxy=g.wire_proxy.unit_number,manual=g.manual_enabled,alerts=g.alerts_enabled,
            receiver=g.manual_receiver_id,items=q.container.get_inventory(defines.inventory.chest).get_contents(),
            receivers=receivers}
    end
    local function report(q,phase)
        q.passed=true;q.phase=phase;q.engine=script.active_mods.base
        helpers.write_file("gate-native.json",helpers.table_to_json{
            passed=true,phase=phase,engine=q.engine,checks=q.checks,snapshot=snapshot(q),
            quotes=q.quotes,physical_travel=q.physical_travel},false)
        log("GATE NATIVE COMPLETE "..phase)
        if game.is_multiplayer() then game.auto_save("gate-"..phase) end
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local q=storage.__upgrade_gate_qc
        if first then
            first=false
            if q then
                check(q,"actual saved gate identity, settings, helpers and inventories",
                    serpent.line(snapshot(q),{sortkeys=true})==q.baseline)
                q.reload_at=event.tick+600
                checked_reload=true
            else
                q={checks={},quotes={},receivers={},start=event.tick}
                storage.__upgrade_gate_qc=q
                for index=1,2 do
                    local s=game.create_surface("upgrade-gate-"..index,{width=128,height=128,peaceful_mode=true})
                    s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
                    for _,entity in pairs(s.find_entities()) do entity.destroy() end
                    local tiles={}
                    for x=-40,40 do for y=-40,40 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
                    s.set_tiles(tiles)
                    q.receivers[index]=s.create_entity{name="ei-gate-receiver",position={20,0},force="player",quality="rare",raise_built=true}
                    gate_model.register_receiver(q.receivers[index],event)
                end
                local surface=q.receivers[1].surface
                q.container=surface.create_entity{name="ei-gate-container",position={0,0},force="player",quality="rare",raise_built=true}
                gate_model.make_gate(q.container,event)
                q.gate=surface.find_entity("ei-gate",{0,0})
                local g=storage.ei.gate.gate[q.gate.unit_number]
                local source=q.container.get_inventory(defines.inventory.chest)
                g.manual_enabled=true;q.gate.energy=1e12
                for index,target in ipairs(q.receivers) do
                    local receiver=storage.ei.gate.receiver[target.unit_number]
                    check(q,"force-local receiver ID "..index,receiver.effective_id~=nil)
                    gate_model.set_manual_receiver(q.gate.unit_number,receiver.effective_id,event)
                    gate_model.refresh_gate_live_state(q.gate,event)
                    g.cooldown_until_tick=0
                    check(q,"insert rare input "..index,source.insert{name="iron-plate",count=37,quality="rare"}==37)
                    local quote=gate_model.quote_transfer({{name="iron-plate",count=37}},surface,target.surface)
                    q.quotes[index]=quote
                    local energy=q.gate.energy
                    gate_model.check_for_teleport(q.gate.unit_number,q.gate,event)
                    check(q,"rare transfer conservation "..index,source.is_empty() and target.get_inventory(defines.inventory.chest).get_item_count{name="iron-plate",quality="rare"}==37)
                    check(q,"exact quoted energy paid "..index,math.abs(energy-q.gate.energy-quote.energy_j)<1)
                    check(q,"cooldown/stress/saturation applied "..index,g.cooldown_until_tick>event.tick and g.stress>0 and receiver.saturation>0)
                end
                local receiver=storage.ei.gate.receiver[q.receivers[2].unit_number]
                g.cooldown_until_tick=0;source.insert{name="copper-plate",count=11,quality="rare"}
                q.gate.energy=0
                gate_model.check_for_teleport(q.gate.unit_number,q.gate,event)
                check(q,"no transfer without power",source.get_item_count{name="copper-plate",quality="rare"}==11)
                q.gate.energy=1e12;receiver.saturation=100
                gate_model.check_for_teleport(q.gate.unit_number,q.gate,event)
                check(q,"saturated receiver retains source",source.get_item_count{name="copper-plate",quality="rare"}==11)
                receiver.saturation=0
                local target=q.receivers[2].get_inventory(defines.inventory.chest)
                for slot=1,#target do target[slot].set_stack{name="stone",count=50} end
                gate_model.check_for_teleport(q.gate.unit_number,q.gate,event)
                check(q,"full receiver retains source",source.get_item_count{name="copper-plate",quality="rare"}==11)
                target.clear()
                q.control=surface.create_entity{name="constant-combinator",position={7,0},force="player"}
                q.section=q.control.get_or_create_control_behavior().get_section(1)
                q.section.set_slot(1,{value={type="virtual",name="signal-E",quality="normal"},min=-1})
                check(q,"native circuit connection",q.control.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
                    q.container.get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.player))
            end
        end
        if checked_reload then
            if q.reload_at and event.tick>=q.reload_at then
                q.reload_at=nil
                check(q,"gate state after 600 more native ticks",serpent.line(snapshot(q),{sortkeys=true})==q.baseline)
                report(q,"reload")
            end
            return
        end
        local elapsed=event.tick-q.start
        local g=storage.ei.gate.gate[q.gate.unit_number]
        if elapsed==2 then
            gate_model.refresh_gate_live_state(q.gate,event)
            check(q,"circuit disables manual On",g.effective_enabled==false)
            q.section.set_slot(1,{value={type="virtual",name="signal-E",quality="normal"},min=1})
        elseif elapsed==4 then
            gate_model.refresh_gate_live_state(q.gate,event)
            check(q,"circuit enables gate",g.effective_enabled==true)
            q.section.clear_slot(1)
            local player=game.players[1]
            if player and player.character then
                player.teleport({0,10},q.container.surface)
                local character=player.character
                player.set_controller{type=defines.controllers.remote,surface=q.receivers[1].surface,position={30,20}}
                check(q,"remote view retains physical character",player.physical_surface==q.container.surface)
                gate_model.teleport_player(character,q.gate)
                check(q,"gate exits remote and moves physical character",player.controller_type==defines.controllers.character
                    and player.physical_surface==q.receivers[2].surface and character.surface==q.receivers[2].surface)
                q.physical_travel=true
            else q.physical_travel=false end
            g.manual_enabled=false;g.alerts_enabled=false;q.gate.energy=0
            q.container.get_inventory(defines.inventory.chest).clear()
        elseif elapsed==10 then
            gate_model.refresh_gate_live_state(q.gate,event)
            q.baseline=serpent.line(snapshot(q),{sortkeys=true})
            report(q,"donor")
        end
    end)
end
