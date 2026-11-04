-- Appended only to a managed private owner by the gate-quality adapter.
local function quality_checks(q,event,check)
    local model=ei_gate
    local surface=q.container.surface
    local receiver=q.receivers[1]
    local destination=storage.ei.gate.receiver[receiver.unit_number]
    local target=receiver.get_inventory(defines.inventory.chest)
    local normal_receiver=assert(surface.create_entity{name="ei-gate-receiver",position={30,30},force="player"})
    model.register_receiver(normal_receiver,event)
    local function near(label,a,b)
        check(q,label,math.abs(a-b)<0.001)
    end
    near("missing sender defaults to normal",model.get_energy_multiplier(nil),1)
    for _,name in ipairs{"normal","uncommon","rare","epic","legendary"} do
        local level=prototypes.quality[name].level
        local multiplier=1/(1+0.2*level)
        local container=assert(surface.create_entity{name="ei-gate-container",position={0,30},force="player",quality=name})
        model.make_gate(container,event)
        local gate=assert(surface.find_entity("ei-gate",container.position))
        local g=storage.ei.gate.gate[gate.unit_number]
        local source=container.get_inventory(defines.inventory.chest)
        g.manual_enabled=true;gate.energy=1e12
        model.set_manual_receiver(gate.unit_number,destination.effective_id,event)
        model.refresh_gate_live_state(gate,event)
        near(name.." sender multiplier",model.get_energy_multiplier(gate),multiplier)
        check(q,name.." helper remains normal",gate.quality.level==0)
        local entries={{name="iron-plate",count=37}}
        local legacy=model.quote_transfer(entries,surface,surface)
        local quote=model.quote_transfer(entries,surface,surface,gate)
        near(name.." independently calculated local toll",quote.energy_j,math.floor((37*2)^1.2*100e6*0.15*multiplier))
        near(name.." legacy quote",legacy.energy_j,math.floor((37*2)^1.2*100e6*0.15))
        check(q,name.." physical penalties unchanged",quote.stress_delta==legacy.stress_delta
            and quote.saturation_delta==legacy.saturation_delta and quote.residue_delta==legacy.residue_delta)
        local remote_quote=model.quote_transfer(entries,surface,q.receivers[2].surface,gate)
        near(name.." unknown cross-surface toll",remote_quote.energy_j,math.floor((37*2)^1.2*100e6*3*multiplier))
        near(name.." cargo quality independent",model.quote_transfer({{name="iron-plate",count=37,quality="legendary"}},surface,surface,gate).energy_j,quote.energy_j)
        model.set_manual_receiver(gate.unit_number,storage.ei.gate.receiver[normal_receiver.unit_number].effective_id,event)
        model.refresh_gate_live_state(gate,event)
        local before_payment=gate.energy
        check(q,name.." compatibility payment accepted",model.pay_energy(gate,entries,true))
        near(name.." normal receiver same toll",before_payment-gate.energy,quote.energy_j)
        model.set_manual_receiver(gate.unit_number,destination.effective_id,event)
        model.refresh_gate_live_state(gate,event)

        -- Force only five units to fit in a real receiver inventory.
        target.clear();source.clear();destination.saturation=0;g.cooldown_until_tick=0
        model.update_input_lock(gate,g,event)
        for slot=1,#target do target[slot].set_stack{name="stone",count=prototypes.item.stone.stack_size} end
        target[1].set_stack{name="iron-plate",count=prototypes.item["iron-plate"].stack_size-5,quality="rare"}
        source.insert{name="iron-plate",count=37,quality="rare"}
        local before=gate.energy
        model.check_for_teleport(gate.unit_number,gate,event)
        check(q,name.." partial transfer count and quality",source.get_item_count{name="iron-plate",quality="rare"}==32)
        check(q,name.." partial transfer locks immediately",source.get_bar()<=1)
        near(name.." partial transfer charged actual count",before-gate.energy,math.floor((5*2)^1.2*100e6*0.15*multiplier))
        source.clear();target.clear()

        local expensive=model.quote_transfer({{name="iron-plate",count=10000}},surface,surface,gate)
        check(q,name.." affordability case above floor",expensive.energy_j>100e9)
        gate.energy=expensive.energy_j-1
        check(q,name.." below quote rejected",not model.can_pay_quote(gate,expensive))
        gate.energy=expensive.energy_j
        check(q,name.." exact quote accepted",model.can_pay_quote(gate,expensive))
        model.commit_quote(gate,expensive)
        near(name.." exact payment",gate.energy,0)

        -- One-second elapsed interval with cooldown expiring halfway through.
        gate.energy=1e12;g.stress=10;g.cooldown_until_tick=event.tick+30;g.last_energy_tick=event.tick
        near(name.." instantaneous upkeep",model.get_gate_upkeep_watts(gate,g,event),(30e6+15e6+30e6)*multiplier)
        before=gate.energy
        model.update_energy(gate.unit_number,gate,{tick=event.tick+60})
        near(name.." elapsed stressed cooldown upkeep",before-gate.energy,(30e6+9.5*1.5e6+15e6)*multiplier)
        near(name.." stress decay unchanged",g.stress,9)
        check(q,name.." cooldown expires",g.cooldown_until_tick==0)
        g.stress=0;g.last_energy_tick=event.tick
        before=gate.energy
        model.update_energy(gate.unit_number,gate,{tick=event.tick+60})
        near(name.." armed-only upkeep",before-gate.energy,30e6*multiplier)
        local data=model.get_data(gate,event)
        near(name.." GUI multiplier",data.energy_multiplier,multiplier)
        check(q,name.." GUI percentage",data.energy_cost_percent==string.format("%.1f",100*multiplier))
        local player=game.players[1]
        if player then
            player.teleport({0,22},surface)
            player.opened=container
            check(q,name.." native container opened",player.opened==container)
            model.open_gui(player,event)
            local gui=assert(model.get_gui_elements(player))
            check(q,name.." native GUI caption",gui.efficiency.caption[2]==data.energy_cost_percent)
            check(q,name.." native GUI tooltip",gui.efficiency.tooltip[1]=="exotic-industries.gate-gui-energy-cost-tooltip")
            gui.efficiency.destroy()
            model.open_gui(player,event)
            check(q,name.." legacy GUI rebuild",model.get_gui_elements(player).efficiency.valid)
            model.close_gui(player);player.opened=nil
        end
        g.effective_enabled=false;g.last_energy_tick=event.tick;before=gate.energy
        near(name.." disabled reported upkeep",model.get_gate_upkeep_watts(gate,g,event),0)
        model.update_energy(gate.unit_number,gate,{tick=event.tick+60})
        near(name.." disabled drain",before-gate.energy,0)
        g.effective_enabled=true;g.effective_target_entity=nil;g.last_energy_tick=event.tick
        near(name.." invalid target reported upkeep",model.get_gate_upkeep_watts(gate,g,event),0)
        model.update_energy(gate.unit_number,gate,{tick=event.tick+60})
        near(name.." invalid target drain",before-gate.energy,0)
        model.destroy_gate(gate,container,event)
        if container.valid then container.destroy() end
    end
    model.destroy_receiver(normal_receiver,event)
    if normal_receiver.valid then normal_receiver.destroy() end

    -- Keep repair independent of the legacy transport/circuit/travel fixture.
    local repair_container=assert(surface.create_entity{name="ei-gate-container",position={0,30},force="player",quality="rare"})
    model.make_gate(repair_container,event)
    local repair_gate=assert(surface.find_entity("ei-gate",repair_container.position))
    repair_gate.destroy()
    model.rebuild_runtime_state("quality-qc",event)
    repair_gate=assert(surface.find_entity("ei-gate",repair_container.position))
    near("repaired helper uses visible quality",model.get_energy_multiplier(repair_gate),1/1.4)
    repair_gate.energy=1e12
    model.rebuild_runtime_state("quality-qc-existing",event)
    near("existing helper rebuild retains energy",repair_gate.energy,1e12)
    model.destroy_gate(repair_gate,repair_container,event)
    if repair_container.valid then repair_container.destroy() end
end
