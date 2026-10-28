-- Appended to the retained orbital cohort: exercise the real owned launch path.
local delivery_previous=script.get_event_handler(defines.events.on_tick)
local delivery_rows
local delivery_launches={}
script.on_event(defines.events.on_rocket_launch_ordered,function(event)
    delivery_launches[event.rocket_silo.unit_number]=event.tick
end)
script.on_event(defines.events.on_tick,function(event)
    delivery_previous(event)
    local state=ensure_state()
    local elapsed=event.tick-state.base_tick
    if elapsed==520 then
        service_runtime(256)
        local snapshot=remote.call("exotic-industries-qc","get_orbital_logistics_qc_snapshot")
        delivery_rows={}
        for _,pair in ipairs{{"silo_a","uplink_a"},{"silo_b","uplink_b"}} do
            local silo=assert(find_ground_entity(ensure_surface(SURFACE_NAME),get_force(),pair[1],state.entity_units[pair[1]]))
            local lease
            for _,candidate in ipairs(snapshot.leases) do
                if candidate.uplink_unit_number==state.entity_units[pair[2]] then lease=candidate end
            end
            assert(lease,"Missing live dispatch lease")
            local target
            for name,id in pairs(state.platform_ids) do if id==lease.target_platform_id then target=name end end
            local platform=assert(get_existing_platform(get_force(),target))
            local spec=assert(get_platform_spec_by_name(target))
            local products={}
            for _,filter in ipairs(spec.request_filters) do
                products[#products+1]={name=filter.value.name,quality=filter.value.quality or "normal",count=filter.min,
                    baseline=platform.hub.get_inventory(defines.inventory.hub_main).get_item_count{name=filter.value.name,quality=filter.value.quality or "normal"}}
            end
            silo.rocket_parts=silo.prototype.rocket_parts_required
            delivery_rows[#delivery_rows+1]={silo=silo,hub=platform.hub,target=target,products=products,uplink=state.entity_units[pair[2]]}
        end
    end
    if not delivery_rows then return end
    for _,row in ipairs(delivery_rows) do
        row.silo.energy=1000000000
        local inventory=row.silo.get_inventory(defines.inventory.rocket_silo_rocket)
        if inventory and inventory.valid and not row.loaded then
            for _,product in ipairs(row.products) do
                assert(inventory.insert{name=product.name,quality=product.quality,count=product.count}==product.count,"Cargo insertion failed")
            end
            row.loaded=event.tick
        end
    end
    -- Use the existing owned QC service entry, not a substitute launch function.
    if elapsed%30==0 then service_runtime(256) end
    if elapsed==4500 then
        local result={passed=true,rows={}}
        for _,row in ipairs(delivery_rows) do
            local products={}
            for _,product in ipairs(row.products) do
                local count=row.hub.get_inventory(defines.inventory.hub_main).get_item_count{name=product.name,quality=product.quality}
                products[#products+1]={name=product.name,quality=product.quality,expected=product.count+product.baseline,actual=count}
                result.passed=result.passed and count==product.count+product.baseline
            end
            local launched=delivery_launches[row.silo.unit_number]
            result.passed=result.passed and launched~=nil
            result.rows[#result.rows+1]={silo=row.silo.unit_number,uplink=row.uplink,target=row.target,
                loaded=row.loaded,launch_tick=launched,products=products,status=row.silo.rocket_silo_status}
        end
        result.snapshot=remote.call("exotic-industries-qc","get_orbital_logistics_qc_snapshot")
        helpers.write_file("orbital-delivery.json",helpers.table_to_json(result),false)
        assert(result.passed,"Owned orbital launch or cargo delivery failed")
    end
end)
