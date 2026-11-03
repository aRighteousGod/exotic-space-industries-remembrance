-- Real rockets and native platform pods; no synthetic cargo or launch mock.
return function(owner, scanner)
  local function count(filters,name,quality)
    local result=0
    for _, filter in ipairs(filters or {}) do
      local value=filter.value or filter
      if value.name==name and (value.quality or "normal")== (quality or "normal") then result=result+(filter.min or filter.count or 0) end
    end
    return result
  end
  local function wake(s,tick)
    owner.on_built_entity{entity=s.entities.silo,tick=tick}
    owner.service_for_qc(64,tick)
  end
  return {step=function(s,tick,check)
    local e=s.entities
    local f=s.cargo
    if not f then
      f={step=0,started=tick};s.cargo=f
      for _, platform in ipairs(s.platforms) do
        platform.space_location="nauvis"
        platform.hub.get_or_create_control_behavior().set_requests=false
        platform.hub.providing_to_other_platforms=false
      end
      e.silo.rocket_parts=e.silo.prototype.rocket_parts_required
      return false
    end
    if tick-f.started>(f.step==6 and 4800 or 2400) then
      check("cargo-stage-deadline-"..f.step,false,helpers.table_to_json{lane=owner.get_silo_snapshot(e.silo,tick),
        stock=f.native_platform and f.native_platform.hub.get_inventory(defines.inventory.hub_main).get_contents()})
      return true
    end
    if f.step==0 then
      if e.silo.rocket_silo_status~=defines.rocket_silo_status.rocket_ready then return false end
      local inventory=e.silo.get_inventory(defines.inventory.rocket_silo_rocket)
      inventory.insert{name="iron-plate",count=105}
      inventory.insert{name="steel-plate",count=40}
      inventory.insert{name="copper-plate",count=1}
      wake(s,tick)
      local snapshot=owner.get_silo_snapshot(e.silo,tick)
      check("platform-only-cargo-held",snapshot.blocker=="cargo-mismatch" and snapshot.launch_count==0,helpers.table_to_json(snapshot))
      local ok,reason=owner.set_dispatch_mode(e.uplink.unit_number,"native",tick)
      check("loaded-payload-prevents-owner-switch",not ok and reason=="empty-payload-first")
      local original=owner.export_configuration(e.uplink)
      local source=assert(e.silo.surface.create_entity{name="ei-orbital-dispatch-uplink",position={500,550},force=e.silo.force,raise_built=true})
      owner.on_entity_settings_pasted{source=source,destination=e.uplink,tick=tick}
      check("loaded-settings-paste-preserves-owner",owner.export_configuration(e.uplink).dispatch_mode=="cohort"
        and owner.get_silo_snapshot(e.silo,tick).configuration_error=="empty-payload-first" and not e.silo.use_transitional_requests)
      owner.seed_configuration(e.uplink,original,tick)
      source.destroy{raise_destroy=true}
      inventory.remove{name="copper-plate",count=1}
      if script.active_mods.quality then
        inventory.insert{name="iron-plate",quality="rare",count=1}
        wake(s,tick)
        check("unrequested-quality-held",owner.get_silo_snapshot(e.silo,tick).blocker=="cargo-mismatch")
        inventory.remove{name="iron-plate",quality="rare",count=1}
      end
      -- The launch recheck must see a live power loss in this same tick.
      for _, source in pairs(e.transponder1.surface.find_entities_filtered{name="esir-orbital-qc-source"}) do source.destroy() end
      for _, sensor in pairs(e.transponder1.surface.find_entities_filtered{type="electric-energy-interface"}) do sensor.energy=0 end
      wake(s,tick)
      check("destination-power-loss-holds-rocket",owner.get_silo_snapshot(e.silo,tick).launch_count==0)
      e.transponder1.surface.create_entity{name="esir-orbital-qc-source",position={2,2},force=e.transponder1.force}
      f.step=1;f.started=tick
    elseif f.step==1 then
      if tick-f.started<30 then return false end
      wake(s,tick)
      local snapshot=owner.get_silo_snapshot(e.silo,tick)
      if snapshot.launch_count==0 then return false end
      check("mixed-requested-cargo-launches-with-excess",snapshot.launch_count==1)
      local ok,reason=owner.set_dispatch_mode(e.uplink.unit_number,"native",tick)
      check("launch-prevents-owner-switch",not ok and reason=="launch-underway",reason)
      f.step=2;f.started=tick
    elseif f.step==2 then
      local incoming=scanner.get_platform_mode_filters(s.platforms[1],"on_the_way",tick)
      if not f.saw_incoming and count(incoming.filters,"iron-plate")>0 then
        f.saw_incoming=true
        local need=scanner.get_platform_mode_filters(s.platforms[1],"need",tick,"planet")
        check("incoming-credited-once",count(need.filters,"iron-plate")==0 and count(need.filters,"steel-plate")==0)
      end
      local inventory=s.platforms[1].hub.get_inventory(defines.inventory.hub_main)
      if inventory.get_item_count("iron-plate")<105 then return false end
      check("real-mixed-rocket-delivery",inventory.get_item_count("steel-plate")==40)
      check("real-rocket-incoming-observed",f.saw_incoming)
      check("confirmed-launch-counted-once",owner.get_silo_snapshot(e.silo,tick).launch_count==1)
      s.platforms[2].hub.get_inventory(defines.inventory.hub_main).insert{name="copper-plate",count=60}
      s.platforms[2].hub.providing_to_other_platforms=true
      f.step=3;f.started=tick
    elseif f.step==3 then
      local inventory=s.platforms[1].hub.get_inventory(defines.inventory.hub_main)
      local incoming=scanner.get_platform_mode_filters(s.platforms[1],"on_the_way",tick)
      if count(incoming.filters,"copper-plate")>0 then f.saw_platform_incoming=true end
      if inventory.get_item_count("copper-plate")<60 then return false end
      check("native-platform-transfer-delivered",true)
      check("native-platform-transfer-incoming-combined",f.saw_platform_incoming)
      check("platform-transfer-does-not-count-as-rocket",owner.get_silo_snapshot(e.silo,tick).launch_count==1)
      s.platforms[2].hub.providing_to_other_platforms=false
      f.step=4;f.started=tick
    elseif f.step==4 then
      local switched=owner.set_dispatch_mode(e.uplink.unit_number,"native",tick)
      if not switched then return false end
      local force=e.silo.force
      local platform=force.create_space_platform{name="Native automatic without transponder",planet="nauvis",starter_pack="space-platform-starter-pack"}
      if not platform.hub then platform.apply_starter_pack() end
      platform.hub.request_missing_construction_materials=false
      platform.hub.providing_to_other_platforms=false
      platform.hub.get_inventory(defines.inventory.hub_main).clear()
      local point=platform.hub.get_requester_point()
      for _, section in ipairs(point.sections) do if section.is_manual then section.active=false end end
      point.add_section().filters={
        {value={type="item",name="iron-plate",quality="normal"},min=10,minimum_delivery_count=10},
        {value={type="item",name="copper-plate",quality="normal"},min=10,minimum_delivery_count=10}}
      f.native_platform=platform
      f.port=assert(e.silo.surface.create_entity{name="roboport",position={536,510},force=force,raise_built=true})
      f.port.get_inventory(defines.inventory.roboport_robot).insert{name="logistic-robot",count=30}
      f.supply=assert(e.silo.surface.create_entity{name="passive-provider-chest",position={531,510},force=force,raise_built=true})
      f.supply.get_inventory(defines.inventory.chest).insert{name="iron-plate",count=5}
      e.silo.rocket_parts=e.silo.prototype.rocket_parts_required
      f.step=5;f.started=tick
    elseif f.step==5 then
      local progress=owner.get_silo_snapshot(e.silo,tick)
      f.saw_native_target=f.saw_native_target or progress.native_target_index==f.native_platform.index
      if not f.saw_incoming_guard and #progress.incoming>0 and #progress.payload==0 then
        local ok,reason=owner.set_dispatch_mode(e.uplink.unit_number,"cohort",tick)
        check("incoming-silo-cargo-prevents-owner-switch",not ok and reason=="wait-for-incoming",reason)
        f.saw_incoming_guard=true
      end
      if tick-f.started<600 then return false end
      local snapshot=owner.get_silo_snapshot(e.silo,tick)
      check("native-minimum-delivery-waits-for-supply",snapshot.launch_count==1 and f.native_platform.hub.get_inventory(defines.inventory.hub_main).is_empty())
      local inventory=f.supply.get_inventory(defines.inventory.chest)
      inventory.insert{name="iron-plate",count=5};inventory.insert{name="copper-plate",count=10}
      f.step=6;f.started=tick
    elseif f.step==6 then
      -- Native batching may send a small eligible batch before the other item
      -- arrives. Keep providing rockets, as the fixture's factory would.
      if e.silo.rocket_silo_status==defines.rocket_silo_status.building_rocket then
        e.silo.rocket_parts=e.silo.prototype.rocket_parts_required
      end
      local progress=owner.get_silo_snapshot(e.silo,tick)
      f.saw_native_target=f.saw_native_target or progress.native_target_index==f.native_platform.index
      if not f.saw_incoming_guard and #progress.incoming>0 and #progress.payload==0 then
        local ok,reason=owner.set_dispatch_mode(e.uplink.unit_number,"cohort",tick)
        check("incoming-silo-cargo-prevents-owner-switch",not ok and reason=="wait-for-incoming",reason)
        f.saw_incoming_guard=true
      end
      local inventory=f.native_platform.hub.get_inventory(defines.inventory.hub_main)
      if inventory.get_item_count("iron-plate")<10 or inventory.get_item_count("copper-plate")<10 then return false end
      check("native-automatic-completes-mixed-requests-without-transponder",true)
      check("native-target-authority",progress.dispatch_owner=="native" and f.saw_native_target)
      f.step=7;f.started=tick
    elseif f.step==7 then
      if not owner.set_dispatch_mode(e.uplink.unit_number,"cohort",tick) then return false end
      -- Restore the persisted configuration contract for GUI and reload probes.
      s.platforms[1].hub.get_inventory(defines.inventory.hub_main).clear()
      return true
    end
    return false
  end}
end
