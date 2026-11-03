if script.mod_name == "even-pickier-dollies" then
    remote.add_interface("esir-dollies-input", {press = function(name, player_index)
        local player = game.get_player(player_index)
        assert(script.get_event_handler(name)){input_name=name, name=name, player_index=player_index,
            tick=game.tick, cursor_position=player.selected.position}
    end})
elseif script.mod_name == "exotic-space-industries-remembrance" then
    remote.add_interface("esir-dollies-state", {
        open_turbine = function(player,proxy)
            ei_combustion_turbine.open_gui(player,proxy,{tick=game.tick})
        end,
        coverage = function(entity,x,y)
            local fueler=entity.name=="ei-fueler"
            local root=fueler and storage.ei.fueler_rt or storage.ei_emt
            local record=(fueler and root.towers or root.chargers)[entity.unit_number]
            local columns=(fueler and root.tower_chunks or root.charger_chunks)[entity.surface_index]
            if x then
                local bucket=columns and columns[x] and columns[x][y]
                return bucket and bucket[entity.unit_number]~=nil or false
            end
            return {left=record.min_chunk_x or record.coverage_min_chunk_x,
                top=record.min_chunk_y or record.coverage_min_chunk_y}
        end,
        neutron_dirty = function(collector,clear)
            if clear then ei_neutron_collector.update_neutron_collector(collector,nil,false,game.tick) end
            return storage.ei.neutron_runtime.collectors_by_unit[collector.unit_number].queued
        end,
        pylon_dirty = function(hole,clear)
            local record=storage.ei.black_hole[hole.unit_number]
            if clear then ei_black_hole.refresh_nearby_pylons(record,hole,{tick=game.tick},true) end
            return record.cache_dirty
        end,
        heat = function(entity, value)
            local record=storage.ei.railgun_cooling.turrets_by_unit[entity.unit_number]
            if value then record.heat_debt=value end
            return record.heat_debt
        end,
        linked = function(machine, stabilizer)
            local state=storage.ei.matter_runtime
            local a=state.machines[machine.unit_number].nearby_stabilizers[stabilizer.unit_number]
            local b=state.stabilizers[stabilizer.unit_number].linked_machines[machine.unit_number]
            assert(a==b)
            return a==true
        end,
        same_bank = function(a,b)
            local map=storage.ei.orbital_combinator_bank_by_unit
            return map[a.unit_number]~=nil and map[a.unit_number]==map[b.unit_number]
        end,
        bind = function(sender, receiver)
            local data = storage.ei.gate.receiver[receiver.unit_number]
            local gate = ei_gate.find_gate(sender)
            ei_gate.set_manual_receiver(gate.unit_number, data.effective_id, {tick=game.tick})
            ei_gate.refresh_gate_live_state(gate, {tick=game.tick})
        end,
        destination = function(sender)
            local gate = ei_gate.find_gate(sender)
            return storage.ei.gate.gate[gate.unit_number].effective_exit
        end,
    })
end
