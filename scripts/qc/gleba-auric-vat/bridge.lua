-- Test-only bridge inserted before return model in the staged owner module.
-- It exercises native entities and production owner functions; never ships in ESIR.
do
    local qc = {}
    function qc.check(value, message)
        local state = storage.ei.gleba_vat_qc
        state.checks = (state.checks or 0) + 1
        assert(value, "GLEBA VAT: " .. message)
    end
    function qc.record(index)
        return get_runtime().vats_by_unit[storage.ei.gleba_vat_qc.units[index]]
    end
    function qc.freeze(record)
        record.entity.active = false
        queue_vat_due(get_runtime(), record.unit_number, game.tick + 10000000)
    end
    function qc.clear_nodes(record)
        for _, node in ipairs(record.entity.surface.find_entities_filtered{name=CYST_NODE_NAME, area={
            {record.position.x-20,record.position.y-20},{record.position.x+20,record.position.y+20}}}) do node.destroy() end
    end
    function qc.prepare()
        storage.ei.gleba_vat_qc = {checks=0, units={}, baseline={}}
        local state = storage.ei.gleba_vat_qc
        local surface = game.create_surface("gleba-vat-fields-qc", {
            width=512,height=128,autoplace_controls={},
            autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.set_property("pressure", 2000)
        surface.request_to_generate_chunks({0,0}, 8)
        surface.force_generate_chunk_requests()
        for _, entity in pairs(surface.find_entities()) do if entity.valid then entity.destroy() end end
        local tiles={}
        for x=-256,255 do for y=-64,63 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
        surface.set_tiles(tiles)
        for index, size in ipairs({24,40,56,72,88,104,128}) do
            local x=(index-4)*48
            tiles={}
            for n=0,size-1 do tiles[#tiles+1]={name="wetland-light-green-slime",position={x+6+n%10,-8+math.floor(n/10)}} end
            surface.set_tiles(tiles)
            local entity=surface.create_entity{name=VAT_NAME,position={x,0},force="player"}
            qc.check(entity and entity.valid,"vat created "..index)
            local record=register_vat(get_runtime(),entity,game.tick)
            qc.check(record.claim_valid and record.basin_size==size and record.band_index==index,"native basin "..index)
            state.units[index]=entity.unit_number
            record.phase="ferment-enriched"
            record.active_phase_key="ferment-enriched"
            record.vigor=76
            record.contamination=11
            record.completed_cycles=7
            record.enriched_bloom=true
            record.ferment_enrichment_until_tick=nil
            apply_phase_recipe(record,game.tick)
            entity.crafting_progress=0.375
            record.phase_progress=675
            qc.freeze(record)
            local tile=record.claim_tiles[1]
            local node=surface.create_entity{name=CYST_NODE_NAME,position={tile.x+0.5,tile.y+0.5},force="neutral",register_plant=true,tick_grown=game.tick}
            qc.check(node and node.valid,"baseline node "..index)
            state.baseline[index]={unit=entity.unit_number,signature=record.claim_footprint_signature,node=node}
        end
        return true
    end
    function qc.complete_bloom(record, enriched, vigor, contamination)
        record.phase="bloom"
        record.active_phase_key="bloom"
        record.enriched_bloom=enriched
        record.vigor=vigor or 100
        record.contamination=contamination or 0
        apply_phase_recipe(record,game.tick)
        record.entity.crafting_progress=1
        process_due_vat(get_runtime(),record,game.tick)
        qc.freeze(record)
    end
    function qc.run()
        local state=storage.ei.gleba_vat_qc
        qc.check(state and #state.units==7,"pre-feature vats exist")
        local yields={2,2,4,4,6,8,10}
        local capacities={6,8,12,16,20,24,28}
        local results={}
        for index=1,7 do
            local record=qc.record(index)
            local before=state.baseline[index]
            qc.check(record and record.entity.valid and record.unit_number==before.unit,"vat identity "..index)
            qc.check(record.claim_valid and record.claim_footprint_signature==before.signature and before.node.valid,"claims and old node "..index)
            qc.check(record.phase=="ferment-enriched" and record.vigor==76 and record.contamination==11 and record.completed_cycles==7,"biological state "..index.." "..helpers.table_to_json({phase=record.phase,vigor=record.vigor,contamination=record.contamination,cycles=record.completed_cycles}))
            qc.check(math.abs(record.entity.crafting_progress-0.375)<0.00001,"native crafting progress "..index)
            qc.clear_nodes(record)
            record.expected_yield=999 -- deliberately stale pre-change cache
            record.phase="bloom"
            record.enriched_bloom=false
            qc.check(build_snapshot(get_runtime(),record,game.tick).expected_yield==yields[index],"uncached ordinary display "..index)
            qc.complete_bloom(record,false)
            qc.check(record.phase=="rest" and record.ready_nodes==yields[index],"ordinary bloom "..index)
            qc.check(model._count_cyst_nodes_in_basin(record)==yields[index],"ordinary world count "..index)
            qc.clear_nodes(record)
            record.enriched_bloom=true
            qc.check(build_snapshot(get_runtime(),record,game.tick).expected_yield==yields[index]+2,"enriched display "..index)
            qc.complete_bloom(record,true)
            qc.check(record.ready_nodes==yields[index]+2,"enriched bloom "..index)
            while model._count_cyst_nodes_in_basin(record)<capacities[index] do
                local count=spawn_cyst_nodes(record,game.tick)
                qc.check(count>0,"capacity filling progress "..index)
            end
            qc.check(model._count_cyst_nodes_in_basin(record)==capacities[index],"standing capacity "..index)
            qc.check(spawn_cyst_nodes(record,game.tick)==0,"full field blocks spawning "..index)
            qc.check(build_snapshot(get_runtime(),record,game.tick).cyst_capacity==capacities[index],"capacity display "..index)
            -- Remove one native node and verify only the one remaining slot is filled.
            local node=record.entity.surface.find_entities_filtered{name=CYST_NODE_NAME,position=record.position,radius=20}[1]
            node.destroy()
            qc.check(spawn_cyst_nodes(record,game.tick)==1,"partial capacity "..index)
            results[index]={band=index,ordinary=yields[index],enriched=yields[index]+2,capacity=capacities[index]}
        end
        -- Exercise an exhausted placement list independently of the population ceiling.
        local record=qc.record(1)
        local claims=record.claim_tiles
        local nodes=record.entity.surface.find_entities_filtered{name=CYST_NODE_NAME,position=record.position,radius=20}
        local node=nodes[1]
        for index=2,#nodes do nodes[index].destroy() end
        record.claim_tiles={{x=math.floor(node.position.x),y=math.floor(node.position.y)}}
        qc.check(model._count_cyst_nodes_in_basin(record)==1,"placement case has spare population capacity")
        qc.check(spawn_cyst_nodes(record,game.tick)==0,"no free claimed tile")
        record.claim_tiles=claims
        for _, failure in ipairs({{39,0},{100,61}}) do
            qc.clear_nodes(record)
            qc.complete_bloom(record,true,failure[1],failure[2])
            qc.check(record.phase=="rest" and model._count_cyst_nodes_in_basin(record)==0,"failed bloom produces no nodes")
        end
        -- Retain a blocked drain, then free its native runoff before advancing.
        record=qc.record(2)
        record.phase="drain";record.active_phase_key="drain";record.enriched_bloom=false
        record.drain_runoff_pending=true
        record.entity.clear_fluid_inside()
        apply_phase_recipe(record,game.tick)
        local out=get_filtered_output_fluidbox_index(record.entity,"ei-dirty-water")
        if not out then
            local boxes={}
            for index,box in pairs(record.entity.prototype.fluidbox_prototypes) do boxes[#boxes+1]={index=index,production=box.production_type,filter=box.filter and box.filter.name} end
            error("Drain output missing "..helpers.table_to_json({count=#record.entity.fluidbox,boxes=boxes}))
        end
        record.entity.fluidbox[out]={name="ei-dirty-water",amount=35}
        process_due_vat(get_runtime(),record,game.tick)
        qc.check(record.phase=="drain","runoff blocks drain")
        record.entity.remove_fluid{name="ei-dirty-water",amount=10000}
        process_due_vat(get_runtime(),record,game.tick)
        qc.check(record.phase=="bloom","cleared runoff advances")
        qc.freeze(record)
        -- A complete fed cycle uses the real machine recipes and normal dispatcher.
        record=qc.record(7)
        qc.clear_nodes(record)
        record.phase="seed";record.active_phase_key="seed"
        record.completed_cycles=0;record.enriched_bloom=false
        record.vigor=100;record.contamination=0;record.drain_runoff_pending=false
        record.entity.clear_fluid_inside()
        record.entity.get_inventory(defines.inventory.assembling_machine_input).clear()
        apply_phase_recipe(record,game.tick)
        record.entity.crafting_progress=0
        record.entity.active=true
        queue_vat_due(get_runtime(),record.unit_number,game.tick+1)
        state.cycle_start=game.tick
        state.results=results
        return {checks=state.checks,bands=results}
    end
    function qc.service_cycle()
        local state=storage.ei.gleba_vat_qc
        local record=qc.record(7)
        if state.cycle_done then return true end
        if record.completed_cycles>=1 and record.phase=="seed" then
            qc.check(model._count_cyst_nodes_in_basin(record)==12,"real fed enriched cycle yields twelve")
            qc.check(game.tick-state.cycle_start>=175*60,"native phase durations")
            state.cycle_done=true
            state.cycle_ticks=game.tick-state.cycle_start
            qc.freeze(record)
            return true
        end
        local entity=record.entity
        if entity.get_fuel_inventory().get_item_count("nutrients")<10 then entity.get_fuel_inventory().insert{name="nutrients",count=100} end
        local inputs=entity.get_inventory(defines.inventory.assembling_machine_input)
        for _,name in ipairs({"spoilage","jelly","yumako-mash","bioflux"}) do if inputs.get_item_count(name)<50 then entity.insert{name=name,count=100} end end
        for index=1,#entity.fluidbox do
            local resolved=entity.fluidbox.get_prototype(index)
            for _,box in ipairs(resolved.production_type and {resolved} or resolved) do
                if box.production_type=="input" and box.filter then entity.fluidbox[index]={name=box.filter.name,amount=entity.fluidbox.get_capacity(index)} end
            end
        end
        for _,name in ipairs({"ei-dirty-water","ei-acidic-water"}) do
            local index=get_filtered_output_fluidbox_index(entity,name)
            if index then entity.fluidbox[index]=nil end
        end
        return false
    end
    function qc.checkpoint()
        local state=storage.ei.gleba_vat_qc
        local entries={}
        for index=1,7 do
            local record=qc.record(index)
            qc.freeze(record)
            entries[index]={unit=record.unit_number,phase=record.phase,vigor=record.vigor,contamination=record.contamination,
                cycles=record.completed_cycles,claims=record.claim_footprint_signature,nodes=model._count_cyst_nodes_in_basin(record)}
        end
        return entries
    end
    function qc.verify_checkpoint(entries)
        for index,before in ipairs(entries) do
            local record=qc.record(index)
            qc.check(record.entity.valid and record.unit_number==before.unit and record.phase==before.phase,"reload vat and phase "..index)
            qc.check(record.vigor==before.vigor and record.contamination==before.contamination and record.completed_cycles==before.cycles,"reload biological state "..index)
            qc.check(record.claim_footprint_signature==before.claims and model._count_cyst_nodes_in_basin(record)==before.nodes,"reload claims and nodes "..index)
        end
        return true
    end
    function qc.report()
        local state=storage.ei.gleba_vat_qc
        return {checks=state.checks,bands=state.results,cycle_ticks=state.cycle_ticks,cycle_done=state.cycle_done}
    end
    function qc.visual(player_index)
        local player=game.get_player(player_index)
        local record=qc.record(7)
        record.expected_yield=5
        record.enriched_bloom=true
        record.entity.surface.always_day=true
        player.opened=nil
        player.teleport(record.position,record.entity.surface)
        player.zoom=0.8
        player.opened=record.entity
        model.open_gui(player,game.tick)
    end
    remote.add_interface("ei-gleba-vat-qc",qc)
end
