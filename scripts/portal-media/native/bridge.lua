-- Appended ONLY to the staged gameplay copy: production controls and read-only evidence.
local portal_radar_config=require("lib/sweeping-radar-config")
remote.add_interface("esir_portal_capture",{
    radar_configure=function(entity,tick)
        local options=portal_radar_config.defaults();options.mode=1
        for _,mode in pairs(options.modes) do mode.radius=2;mode.near=0 end
        ei_sweeping_radar.set_settings(assert(ei_sweeping_radar.get_record(entity)),options,tick)
    end,
    radar_open=function(player,entity,tick) ei_sweeping_radar_gui.open(player.index,entity,tick) end,
    radar_state=function(entity)
        local r=assert(ei_sweeping_radar.get_record(entity))
        return {ready=r.ready,passes=r.passes or 0,observations=r.observations or 0,mode=r.settings.mode,energy=r.power.energy}
    end,
    water_preferences=function(player,entity,mode,tick)
        player.opened=entity
        ei_water_turret.on_gui_opened{player_index=player.index,entity=entity,tick=tick}
        for _,root in pairs(player.gui.relative.children) do
            if root.body and root.body.content and root.body.content.mode then
                local dropdown=root.body.content.mode
                dropdown.selected_index=mode
                ei_water_turret.on_gui_changed{player_index=player.index,element=dropdown,tick=tick}
            end
        end
        player.opened=nil
    end,
    water_open=function(player,entity,tick) ei_water_turret.on_gui_opened{player_index=player.index,entity=entity,tick=tick} end,
    water_state=function(entity)
        local r=assert(storage.ei.water_turret.records[entity.unit_number])
        return {phase=r.phase,available=r.available,power=r.power and r.power.energy,counters=storage.ei.water_turret.counters}
    end,
    vat_open=function(player,entity,tick) player.opened=entity;ei_auric_inoculation_vat.open_gui(player,tick) end,
    vat_state=function(entity)
        local r=assert(storage.ei.auric_inoculation_vat.vats_by_unit[entity.unit_number],"Vat registration missing")
        return {phase=r.phase,progress=r.phase_progress,cycles=r.completed_cycles,basin=r.basin_size,valid=r.claim_valid,nodes=r.ready_nodes or 0,vigor=r.vigor}
    end,
    gate_configure=function(player,container,receiver,tick)
        local gate=assert(ei_gate.find_gate(container))
        local r=assert(storage.ei.gate.receiver[receiver.unit_number])
        ei_gate.set_manual_receiver(gate.unit_number,r.effective_id or r.auto_id,{tick=tick})
        ei_gate.toggle_state(player,gate.unit_number,{tick=tick})
    end,
    gate_open=function(player,container,tick) player.opened=container;ei_gate.build_gui(player,ei_gate.find_gate(container)) end,
    gate_state=function(container)
        local gate=assert(ei_gate.find_gate(container));local r=storage.ei.gate.gate[gate.unit_number]
        return {energy=gate.energy,stress=r.stress,receiver=r.manual_receiver_id,enabled=r.manual_enabled}
    end,
    spider_open=function(player,entity,tick) player.opened=entity;ei_spider_vehicles.on_gui_opened{player_index=player.index,entity=entity,tick=tick} end,
    spider_entity=function(id)
        local r=storage.ei.spider_vehicles.vehicles[id]
        return r and r.entity
    end,
})
