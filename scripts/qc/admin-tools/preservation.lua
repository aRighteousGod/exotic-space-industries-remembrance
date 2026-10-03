-- Fixture-only preservation probes. Loaded inside the staged ESIR control context.
-- No normal simulation ticks occur between a snapshot and its two owner repairs.
local model={}
local function serial(value)return serpent.line(value,{comment=false,sortkeys=true})end
local function fields(record,names)
    local result={}
    for _,name in ipairs(names)do result[name]=record[name] end
    return serial(result)
end
local function fluids(entity)
    local result={}
    for index=1,entity.fluids_count do
        local fluid=entity.get_fluid(index)
        result[index]=fluid and {name=fluid.name,amount=fluid.amount,temperature=fluid.temperature} or false
    end
    return serial(result)
end
function model.run(owners,registry,actor,tick)
    local checks={}
    local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
    local function twice(id,verify)
        for pass=1,2 do
            local invoked,ok,message=pcall(registry.repair,actor,id,tick)
            check(id.." repair pass "..pass,invoked and ok,invoked and message or tostring(ok))
            if invoked and ok then verify(pass) end
        end
    end
    -- Probe the published owner keys without invoking mutating status getters.
    -- Cache values are fixture-only; restore the exact original slot afterwards.
    local function cached_probe(id,key,values)
        local modules=storage.ei.runtime_scheduler.modules
        local previous=modules[key]
        local probe={last_tick=tick,status=values}
        modules[key]=probe
        local before=serial(probe)
        local snapshot=registry.peek(id,tick)
        local matched=snapshot.cache_updated_tick==tick
        for name,value in pairs(values) do matched=matched and snapshot.cached[name]==value end
        check(id.." diagnostics uses owner cache key",matched)
        check(id.." diagnostic peek leaves cached owner state unchanged",modules[key]==probe and serial(probe)==before)
        modules[key]=previous
    end
    local ok,err=pcall(function()
        assert(actor and actor.valid and actor.admin,"Preservation fixture requires a real administrator")
        local surface=game.create_surface("admin-preservation-"..tick,{
            water="none",autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
        local function create(name,x,y)
            local entity=surface.create_entity{name=name,position={x,y},force=actor.force,raise_built=true}
            assert(entity and entity.valid,"Could not create native "..name)
            return entity
        end
        -- Isolate existing GUI scheduling tables, not gameplay registrations.
        -- Closed service must be observational after its one stale-queue cleanup.
        local function closed_gui_probe(id,root_key,bucket_key,service,frontier_key)
            local saved=storage.ei[root_key]
            local probe={open_by_player={},last_gui_service_tick=tick-1}
            probe[bucket_key]={}
            if frontier_key then probe[frontier_key]=0 end
            storage.ei[root_key]=probe
            local ok_probe,error_probe=pcall(function()
                local empty=probe[bucket_key]
                service(tick)
                check(id.." closed GUI retains empty bucket identity",probe[bucket_key]==empty)
                check(id.." closed GUI leaves service timestamp unchanged",probe.last_gui_service_tick==tick-1)
                probe[bucket_key]={[tick]={actor.index}}
                if frontier_key then probe[frontier_key]=tick end
                service(tick)
                local cleaned=probe[bucket_key]
                check(id.." closed GUI clears stale scheduling once",next(cleaned)==nil
                    and (not frontier_key or probe[frontier_key]==0))
                service(tick+1)
                check(id.." cleaned closed GUI remains idle",probe[bucket_key]==cleaned
                    and probe.last_gui_service_tick==tick-1)
                storage.ei[root_key]=nil
                service(tick+2)
                check(id.." closed GUI does not initialize missing state",storage.ei[root_key]==nil)
            end)
            storage.ei[root_key]=saved
            check(id.." closed GUI fixture completed",ok_probe,ok_probe and nil or tostring(error_probe))
        end
        closed_gui_probe("neutron","neutron_runtime","gui_refresh_buckets",owners.neutron.service_gui_refreshes)
        closed_gui_probe("matter","matter_stabilizer_gui","refresh_buckets",owners.matter.service_due_gui_refreshes,"next_refresh_tick")
        -- A real quality locomotive outside every charger retains the remainder
        -- of an already earned grace window across both administrator repairs.
        for y=-12,12,2 do
            assert(surface.create_entity{name="straight-rail",position={-80,y},direction=defines.direction.north,force=actor.force})
        end
        local locomotive=assert(surface.create_entity{name="ei_em-locomotive",position={-80,0},
            direction=defines.direction.north,quality="rare",force=actor.force,raise_built=true})
        owners.em.register_train(locomotive)
        local train_entry=storage.ei_emt.trains[locomotive.unit_number]
        local grace_deadline=tick+300
        train_entry.grace_until_tick=grace_deadline
        local fuel=assert(owners.em.get_selected_em_fuel_prototype())
        locomotive.burner.currently_burning=fuel
        locomotive.burner.remaining_burning_fuel=10000000
        local fuel_before=locomotive.burner.remaining_burning_fuel
        local burning_before=serial(locomotive.burner.currently_burning)
        check("EM native locomotive starts with active grace",locomotive.valid and train_entry.grace_until_tick>tick)
        twice("em-trains",function(pass)
            local entry=storage.ei_emt.trains[locomotive.unit_number]
            check("EM earned grace deadline preserved "..pass,entry and entry.entity==locomotive and entry.grace_until_tick==grace_deadline)
            check("EM native burner reserve preserved "..pass,serial(locomotive.burner.currently_burning)==burning_before
                and locomotive.burner.remaining_burning_fuel==fuel_before,{fuel=locomotive.burner.currently_burning,energy=locomotive.burner.remaining_burning_fuel})
        end)
        owners.em.update_train(locomotive,tick)
        check("EM repaired train keeps propulsion outside coverage",
            storage.ei_emt.trains[locomotive.unit_number].grace_until_tick==grace_deadline
            and serial(locomotive.burner.currently_burning)==burning_before and locomotive.burner.remaining_burning_fuel>=fuel_before,
            {fuel=locomotive.burner.currently_burning,energy=locomotive.burner.remaining_burning_fuel})
        -- Fusion's authoritative state is its selection and native assembler buffers,
        -- not an invented heat/instability value.
        local fusion=create("ei-fusion-reactor",-90,-60)
        owners.fusion.on_built_entity(fusion,tick)
        local fr=storage.ei.fusion_reactor.reactors_by_unit[fusion.unit_number]
        fr.control_source="circuit"
        fr.manual_selection={fuel_1="ei-heated-tritium",fuel_2="ei-heated-helium-3",temperature="high",injection_rate="low",corrected=false}
        fusion.crafting_progress=.375
        local filled=0
        for index=1,#fusion.fluidbox do
            local filter=fusion.fluidbox.get_filter(index)
            local name=filter and filter.name or fusion.fluidbox.get_locked_fluid(index)
            if name and prototypes.fluid[name] then
                local temperature=prototypes.fluid[name].default_temperature
                if filter then temperature=math.max(filter.minimum_temperature,math.min(temperature,filter.maximum_temperature)) end
                if fusion.set_fluid(index,{name=name,amount=1,temperature=temperature}) then filled=filled+1 end
            end
        end
        check("fusion native input/output buffers populated",filled>0,filled)
        local fusion_selection=fields(fr,{"control_source","manual_selection","effective_selection"})
        local fusion_fluids=fluids(fusion)
        local fusion_progress=fusion.crafting_progress
        local fusion_recipe=fusion.get_recipe().name
        twice("fusion-reactor",function(pass)
            local after=storage.ei.fusion_reactor.reactors_by_unit[fusion.unit_number]
            check("fusion record retained "..pass,after==fr)
            check("fusion selections preserved "..pass,fields(after,{"control_source","manual_selection","effective_selection"})==fusion_selection)
            check("fusion native buffers/progress preserved "..pass,fluids(fusion)==fusion_fluids and fusion.crafting_progress==fusion_progress and fusion.get_recipe().name==fusion_recipe)
        end)
        local crystal=create("ei-crystal-accumulator",-50,-60)
        owners.crystal.on_built_entity{entity=crystal,tick=tick}
        local cr=storage.ei.crystal_accumulator.by_unit[crystal.unit_number]
        assert(cr,"Native crystal record missing")
        crystal.energy=1234567
        cr.instability=.42;cr.last_energy=1234000;cr.backlash_cooldown_until=tick+777
        cr.last_telemetry_key="strain-fallback";cr.frozen=true
        local crystal_names={"instability","last_energy","last_load_band","last_telemetry_key","backlash_cooldown_until","frozen"}
        local crystal_before=fields(cr,crystal_names)
        local crystal_energy=crystal.energy
        local crystal_due=storage.ei.crystal_accumulator.surface_due_tick_by_surface[surface.index]
        cached_probe("crystal-accumulator","crystal_accumulator",{live_crystals=1,queued_surfaces=2,next_surface_due_tick=tick+9})
        local crystal_summary=registry.peek("crystal-accumulator",tick)
        check("crystal diagnostics exposes existing live count",crystal_summary.fields.live_crystal_count==storage.ei.crystal_accumulator.live_crystal_count)
        twice("crystal-accumulator",function(pass)
            local runtime=storage.ei.crystal_accumulator
            local after=runtime.by_unit[crystal.unit_number]
            check("crystal record retained "..pass,after==cr)
            check("crystal memory/cooldown preserved "..pass,fields(after,crystal_names)==crystal_before)
            check("crystal native energy/deadline preserved "..pass,crystal.energy==crystal_energy and runtime.surface_due_tick_by_surface[surface.index]==crystal_due)
        end)
        local railgun=create("railgun-turret",-10,-60)
        owners.railgun.on_built_entity{entity=railgun,tick=tick}
        local rr=storage.ei.railgun_cooling.turrets_by_unit[railgun.unit_number]
        assert(rr and rr.proxy and rr.proxy.valid,"Native railgun coolant proxy missing")
        rr.proxy.set_fluid(1,{name="fluoroketone-cold",amount=5,temperature=-150})
        rr.proxy.set_fluid(2,{name="fluoroketone-hot",amount=7,temperature=180})
        owners.railgun.on_script_trigger_effect{effect_id="ei-railgun-cooling-shot",source_entity=railgun,tick=tick}
        -- Represents fresh coolant arriving while an earlier shot still has debt.
        rr.proxy.set_fluid(1,{name="fluoroketone-cold",amount=3,temperature=-150})
        check("railgun shot created debt",rr.heat_debt>0,rr.heat_debt)
        local rail_names={"heat_debt","last_shot_tick","last_cooling_effect_tick","hot_visual_until_tick","disabled_by_railgun_cooling"}
        local rail_before=fields(rr,rail_names)
        local rail_fluids=fluids(rr.proxy)
        local rail_proxy=rr.proxy
        local rail_due=storage.ei.railgun_cooling.recovery_pending_by_unit[railgun.unit_number]
        check("railgun shot owns delayed recovery",rail_due and rail_due>tick,rail_due)
        twice("railgun-cooling",function(pass)
            local runtime=storage.ei.railgun_cooling
            local after=runtime.turrets_by_unit[railgun.unit_number]
            check("railgun record/proxy retained "..pass,after==rr and after.proxy==rail_proxy)
            check("railgun debt/coolant preserved "..pass,fields(after,rail_names)==rail_before and fluids(after.proxy)==rail_fluids)
            check("railgun recovery deadline preserved "..pass,runtime.recovery_pending_by_unit[railgun.unit_number]==rail_due)
        end)
        local tank=create(owners.emerald.tank_name,30,-60)
        owners.emerald.on_built_entity{entity=tank,tick=tick}
        local ammo=tank.get_inventory(defines.inventory.car_ammo)
        assert(ammo and ammo.insert{name=owners.emerald.charge_item,count=1}==1,"Native Emerald ammo setup failed")
        local trunk=tank.get_inventory(defines.inventory.car_trunk)
        assert(trunk and trunk.insert{name=owners.emerald.charge_item,count=1}==1,"Native Emerald reserve setup failed")
        -- The native gun consumes one charge before its script effect. Debit native
        -- inventory explicitly to enter that same post-consumption owner boundary.
        assert(ammo.remove{name=owners.emerald.charge_item,count=1}==1)
        local committed=owners.emerald.on_script_trigger_effect{effect_id=owners.emerald.charge_effect_id,source_entity=tank,target_position={80,-60},tick=tick}
        check("Emerald paid trigger committed",committed)
        local er=storage.ei.emerald_apocalypse_hover_tank
        local tr=er.tanks_by_unit[tank.unit_number]
        tr.drift_x=.125;tr.drift_y=-.25;tr.cooldown_until_tick=tick+37
        er.tank_settings_by_unit[tank.unit_number]={targeting_mode="focus-fire",shard_count_override=2,doctrine_toggles={reclaim_charges=false}}
        owners.emerald.on_entity_damaged{entity=tank,tick=tick}
        local tank_names={"charge_started_tick","charge_due_tick","charge_profile","cooldown_until_tick","aim_range","aim_target_x","aim_target_y","drift_x","drift_y","last_shield_pulse_tick"}
        local tank_before=fields(tr,tank_names)
        local tank_due=er.pending_by_unit[tank.unit_number]
        local tank_buckets=serial(er.charge_buckets)
        local tank_settings=serial(er.tank_settings_by_unit[tank.unit_number])
        local ammo_before=ammo.get_item_count(owners.emerald.charge_item)
        local pulse_table=er.shield_pulses
        local pulse_id=er.next_pulse_id
        check("Emerald owns paid delayed charge",tank_due and tank_due>tick and ammo_before==0,tank_due)
        cached_probe("emerald-apocalypse","emerald-apocalypse-hover-tank",{tracked_tanks=1,charging=1,charge_bucket_items=1})
        local emerald_summary=registry.peek("emerald-apocalypse",tick)
        check("Emerald diagnostics exposes real charge and pulse deadlines",
            emerald_summary.fields.next_charge_due_tick==er.next_charge_due_tick
            and emerald_summary.fields.next_pulse_cleanup_tick==er.next_pulse_cleanup_tick
            and er.next_charge_due_tick==tank_due)
        local started,message=registry.start_inspection(actor,"emerald-apocalypse",tick)
        check("Emerald detailed inspection admitted",started,message)
        if started then
            for step=1,100 do
                if not registry.has_tick_work() then break end
                registry.updater{tick=tick}
            end
            local inspection=registry.get_inspection(actor)
            local by_path={}
            if inspection and inspection.id=="emerald-apocalypse" then
                for _,collection in ipairs(inspection.collections) do by_path[collection.path]=collection end
            end
            check("Emerald inspection sees committed paid charge collections",
                by_path.charge_buckets and not by_path.charge_buckets.missing and by_path.charge_buckets.entries>0
                and by_path.pending_by_unit and not by_path.pending_by_unit.missing and by_path.pending_by_unit.entries>0
                and by_path["charge_queue.items"] and not by_path["charge_queue.items"].missing)
            if registry.has_tick_work() then registry.cancel_inspection(actor) end
        end
        twice("emerald-apocalypse",function(pass)
            local runtime=storage.ei.emerald_apocalypse_hover_tank
            local after=runtime.tanks_by_unit[tank.unit_number]
            check("Emerald record retained "..pass,after==tr)
            check("Emerald paid charge/cooldown/drift preserved "..pass,fields(after,tank_names)==tank_before)
            check("Emerald paid bucket/ammo preserved "..pass,runtime.pending_by_unit[tank.unit_number]==tank_due and serial(runtime.charge_buckets)==tank_buckets and ammo.get_item_count(owners.emerald.charge_item)==ammo_before and trunk.get_item_count(owners.emerald.charge_item)==1)
            check("Emerald doctrine/pulse queue preserved "..pass,serial(runtime.tank_settings_by_unit[tank.unit_number])==tank_settings and runtime.shield_pulses==pulse_table and runtime.next_pulse_id==pulse_id)
        end)
        local accepted,id,message=owners.effects.queue_effect_at(surface,{x=90,y=70},{effect_family="gas",energy_mj=20},tick)
        assert(accepted,message or "Environmental rupture admission failed")
        local rupture=storage.ei.flammable_ruptures
        local job=rupture.jobs[id]
        local rings=job.rings
        local due=rupture.next_ring_due_tick
        local ring_buckets=serial(rupture.ring_buckets)
        local next_ring=job.next_ring
        local pending_rings=rupture.pending_ring_count
        twice("flammable-ruptures",function(pass)
            local runtime=storage.ei.flammable_ruptures
            check("rupture paid job/rings retained "..pass,runtime.jobs[id]==job and job.rings==rings and job.next_ring==next_ring)
            check("rupture due/buckets/count preserved "..pass,runtime.next_ring_due_tick==due and serial(runtime.ring_buckets)==ring_buckets and runtime.pending_ring_count==pending_rings)
        end)
    end)
    check("preservation fixture completed",ok,ok and nil or tostring(err))
    return checks
end
return model
