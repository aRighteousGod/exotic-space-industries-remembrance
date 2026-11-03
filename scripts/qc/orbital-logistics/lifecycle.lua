-- Native clone, blueprint placement/paste, conflicts, arbitration and lease rotation.
return function(owner,scanner)
  local function create(surface,name,position,force)
    return assert(surface.create_entity{name=name,position=position,force=force,raise_built=true},name)
  end
  local function target(snapshot,unit)
    for _, lease in ipairs(snapshot.leases) do if lease.uplink_unit_number==unit then return lease.target_platform_id end end
  end
  return {step=function(s,tick,check)
    local e=s.entities;local f=s.lifecycle
    if not f then
      f={start=tick};s.lifecycle=f
      local surface,force=e.silo.surface,e.silo.force
      for _, platform in ipairs(s.platforms) do
        platform.space_location="nauvis"
        platform.hub.get_or_create_control_behavior().set_requests=false
      end
      local left=create(surface,"rocket-silo",{539,558},force)
      local right=create(surface,"rocket-silo",{555,558},force)
      local ambiguous=create(surface,"ei-orbital-dispatch-uplink",{547,558},force)
      check("ambiguous-adjacent-silos-stay-unbound",owner.get_panel_snapshot(ambiguous,tick).silo.unit_number==nil)
      for _, entity in ipairs({ambiguous,left,right}) do entity.destroy{raise_destroy=true} end
      f.selector=assert(e.selector.clone{position={500,524}})
      check("native-clone-copies-selector-configuration",owner.export_configuration(f.selector).manual_platform_id==101)
      scanner.apply_configuration(e.scanner,{mode="need",source="planet"},tick)
      f.scanner=assert(e.scanner.clone{position={490,524}})
      local copied=owner.export_configuration(f.scanner)
      check("native-clone-copies-scanner-source",copied.mode=="need" and copied.source=="planet")
      f.scanner.destroy{raise_destroy=true}
      f.silo=create(surface,"rocket-silo",{524,524},force)
      f.uplink=create(surface,"ei-orbital-dispatch-uplink",{516,524},force)
      check("unambiguous-adjacent-silo-bound",owner.get_panel_snapshot(f.uplink,tick).silo.unit_number==f.silo.unit_number)
      owner.set_dispatch_mode(f.uplink.unit_number,"cohort",tick)
      f.selector3=create(surface,"ei-orbital-selector",{504,524},force)
      -- Keep a third demand contender for rotation; restore its request section later.
      f.section=s.platforms[2].hub.get_requester_point().add_section()
      f.section.filters={{value={type="item",name="steel-plate",quality="normal"},min=80}}
      f.section3=s.platforms[3].hub.get_requester_point().add_section()
      f.section3.filters={{value={type="item",name="iron-plate",quality="normal"},min=85}}
      owner.apply_qc_configuration({selectors={{unit_number=f.selector.unit_number,mode="manual",manual_platform_id=102},
        {unit_number=f.selector3.unit_number,mode="manual",manual_platform_id=103}}},tick)
      -- A real blueprint stack carries the owner's tags through native ghost revival.
      f.inventory=game.create_inventory(1);local stack=f.inventory[1];stack.set_stack{name="blueprint"}
      local mapping=stack.create_blueprint{surface=surface,force=force,area={{499,509},{501,511}}}
      owner.on_blueprint{player_index=1,record=stack,mapping={get=function() return mapping end}}
      local ghosts=stack.build_blueprint{surface=surface,force=force,position={500,532},raise_built=true}
      for _, ghost in ipairs(ghosts) do local _,entity=ghost.revive{raise_revive=true};if entity and entity.name=="ei-orbital-selector" then f.blueprint_copy=entity end end
      check("native-blueprint-revival-keeps-selector",f.blueprint_copy and owner.export_configuration(f.blueprint_copy).manual_platform_id==101)
      if f.blueprint_copy then
        owner.set_selector_configuration(f.blueprint_copy,"policy",nil,tick)
        stack.build_blueprint{surface=surface,force=force,position={500,532},raise_built=true}
        check("native-blueprint-paste-keeps-selector",owner.export_configuration(f.blueprint_copy).mode=="manual"
          and owner.export_configuration(f.blueprint_copy).manual_platform_id==101)
        f.blueprint_copy.destroy{raise_destroy=true}
      end
      f.inventory.destroy()
      return false
    end
    if tick-f.start<30 then return false end
    if f.conflict then
      if tick-f.conflict_tick<120 then return false end
      owner.service_for_qc(64,tick)
      local conflicts=0
      for _, row in ipairs(owner.get_qc_snapshot(tick).transponders) do if row.platform_id==101 and row.conflict then conflicts=conflicts+1 end end
      check("copied-explicit-id-reports-conflict",conflicts>=2,conflicts)
      f.conflict.destroy{raise_destroy=true}
      owner.service_for_qc(64,tick)
      return true
    end
    owner.service_for_qc(64,tick)
    local first=target(owner.get_qc_snapshot(tick),f.uplink.unit_number)
    check("second-lane-leased-to-distinct-demand",first==102 or first==103,first)
    owner.apply_qc_configuration({uplinks={{unit_number=f.uplink.unit_number,binding_silo_unit_number=false}}},tick)
    owner.service_for_qc(64,tick)
    owner.apply_qc_configuration({uplinks={{unit_number=f.uplink.unit_number,binding_silo_unit_number=f.silo.unit_number}}},tick)
    owner.service_for_qc(64,tick)
    local second=target(owner.get_qc_snapshot(tick),f.uplink.unit_number)
    check("released-lane-fairness-rotates",second~=first and (second==102 or second==103),tostring(first)..":"..tostring(second))
    local former=e.coordinator.unit_number
    e.coordinator.destroy{raise_destroy=true};owner.service_for_qc(64,tick)
    local found=false
    for _, cohort in ipairs(owner.get_qc_snapshot(tick).cohorts) do
      found=found or cohort.active_coordinator_unit_number==e.coordinator2.unit_number
    end
    check("coordinator-failover",found,former)
    e.coordinator=create(e.silo.surface,"ei-orbital-coordinator",{504,510},e.silo.force)
    f.conflict=assert(e.transponder1.clone{position={-2,2},surface=s.platforms[3].surface})
    f.conflict_tick=tick
    f.section.active=false
    f.section3.active=false
    for _, entity in ipairs({f.selector,f.selector3,f.uplink,f.silo}) do entity.destroy{raise_destroy=true} end
    owner.service_for_qc(64,tick)
    return false
  end}
end
