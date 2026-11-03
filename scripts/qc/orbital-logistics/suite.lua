-- Dedicated current-source orbital assertions. The common driver owns lifecycle,
-- configuration-event observation, checkpoint production and terminal receipts.
return function(owner, scanner)
  local radar = require("__esir-qc-native-tests__.orbital-radar")
  local cargo = require("__esir-qc-native-tests__.orbital-cargo")(owner,scanner)
  local lifecycle = require("__esir-qc-native-tests__.orbital-lifecycle")(owner,scanner)
  local support = require("__esir-qc-native-tests__.support")
  local checks, started = {}, nil
  local function check(name, passed, detail)
    checks[#checks+1] = {name=name, passed=not not passed, detail=detail and tostring(detail)}
    if not passed then log("ORBITAL_ASSERT_FAILED "..name.." "..tostring(detail)) end
  end
  local function create(surface, name, position, force)
    return assert(surface.create_entity{name=name,position=position,force=force,raise_built=true,create_build_effect_smoke=false}, name)
  end
  local function power(surface, force, position)
    create(surface,"esir-orbital-qc-pole",position,force)
    create(surface,"esir-orbital-qc-source",position,force)
  end
  local function total(filters, name, quality)
    local count=0
    for _, filter in ipairs(filters or {}) do
      local value=filter.value or filter
      if value.name==name and (value.quality or "normal")== (quality or "normal") then count=count+(filter.min or filter.count or 0) end
    end
    return count
  end
  local function requests(platform, filters)
    local point=platform.hub.get_requester_point()
    for _, section in pairs(point.sections) do if section.type==defines.logistic_section_type.manual then section.active=false end end
    local section=point.add_section()
    section.filters=filters
    return section
  end
  local function build()
    local force=game.forces.player
    force.research_all_technologies()
    local surface=game.surfaces.nauvis
    surface.request_to_generate_chunks({512,512},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=460,570 do for y=460,570 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end
    surface.set_tiles(tiles,true)
    for _, entity in pairs(surface.find_entities_filtered{area={{460,460},{570,570}}}) do if entity.type~="character" then entity.destroy() end end
    power(surface,force,{500,500})
    local s={platforms={},entities={},start=game.tick}
    for i=1,3 do
      local platform=force.create_space_platform{name="Orbital QC "..i,planet="nauvis",starter_pack="space-platform-starter-pack"}
      if not platform.hub then platform.apply_starter_pack() end
      assert(platform.hub,"native platform hub")
      platform.hub.request_missing_construction_materials=false
      platform.hub.providing_to_other_platforms=false
      platform.hub.get_inventory(defines.inventory.hub_main).clear()
      power(platform.surface,force,{2,2})
      s.platforms[i]=platform
      s.entities["transponder"..i]=create(platform.surface,"ei-platform-transponder",{2,2},force)
    end
    for _, row in ipairs({{"silo","rocket-silo",{524,500}}, {"uplink","ei-orbital-dispatch-uplink",{516,500}},
      {"selector","ei-orbital-selector",{500,510}}, {"coordinator","ei-orbital-coordinator",{504,510}},
      {"coordinator2","ei-orbital-coordinator",{508,510}}, {"scanner","ei-orbital-combinator",{490,510}},
      {"scanner2","ei-orbital-combinator",{470,510}}}) do
      s.entities[row[1]]=create(surface,row[2],row[3],force)
    end
    local e=s.entities
    check("new-selector-default-policy",owner.export_configuration(e.selector).mode=="policy")
    check("new-uplink-default-native",owner.export_configuration(e.uplink).dispatch_mode=="native")
    check("placement-does-not-enable-native-requests",not e.silo.use_transitional_requests)
    owner.apply_qc_configuration({uplinks={{unit_number=e.uplink.unit_number,binding_silo_unit_number=e.silo.unit_number}},
      transponders={{unit_number=e.transponder1.unit_number,platform_id=101},{unit_number=e.transponder2.unit_number,platform_id=102},
        {unit_number=e.transponder3.unit_number,platform_id=103}}},game.tick)
    s.sections={}
    s.sections[1]=requests(s.platforms[1],{
      {value={type="item",name="iron-plate",quality="normal"},min=100,request_from="planet"},
      {value={type="item",name="copper-plate",quality="normal"},min=60,request_from="platforms"},
      {value={type="item",name="steel-plate",quality="normal"},min=40,request_from="all"}})
    s.sections[2]=requests(s.platforms[2],{})
    s.sections[3]=requests(s.platforms[3],{
      {value={type="item",name="iron-plate",quality="normal"},min=50,request_from="planet"},
      {value={type="item",name="iron-plate",quality="normal"},min=25,request_from="platforms"},
      {value={type="item",name="iron-plate",quality="normal"},min=10,request_from="all"}})
    s.platforms[2].hub.get_inventory(defines.inventory.hub_main).insert{name="iron-plate",count=100}
    local native_force=game.forces["orbital-native-only"] or game.create_force("orbital-native-only")
    native_force.research_all_technologies()
    local native_platform=native_force.create_space_platform{name="Native only",planet="nauvis",starter_pack="space-platform-starter-pack"}
    if not native_platform.hub then native_platform.apply_starter_pack() end
    native_platform.hub.request_missing_construction_materials=false
    power(surface,native_force,{550,500})
    create(surface,"rocket-silo",{550,500},native_force)
    create(surface,"ei-orbital-dispatch-uplink",{542,500},native_force)
    local bridge=scanner.get_platform_mode_filters
    local native_reads=0
    scanner.get_platform_mode_filters=function(platform,...)
      if platform.force==native_force then native_reads=native_reads+1 end
      return bridge(platform,...)
    end
    owner.service_for_qc(64,game.tick)
    scanner.get_platform_mode_filters=bridge
    check("native-only-lanes-do-not-sample-scanner",native_reads==0,native_reads)
    storage.orbital_native_fixture=s
    return s
  end
  local function scanner_checks(s,tick)
    local a=scanner.get_platform_mode_filters(s.platforms[1],"need",tick)
    local b=scanner.get_platform_mode_filters(s.platforms[2],"need",tick)
    check("per-platform-need-keeps-other-platform-stock-isolated",total(a.filters,"iron-plate")+total(b.filters,"iron-plate")==100)
    local planet=scanner.get_platform_mode_filters(s.platforms[1],"requests",tick,"planet")
    local platforms=scanner.get_platform_mode_filters(s.platforms[1],"requests",tick,"platforms")
    local source_evidence=helpers.table_to_json{planet=planet.filters,platforms=platforms.filters,
      compiled=s.platforms[1].hub.get_requester_point().filters,configured=s.sections[1].filters}
    check("planet-eligibility",total(planet.filters,"iron-plate")==100 and total(planet.filters,"copper-plate")==0 and total(planet.filters,"steel-plate")==40,source_evidence)
    check("platform-eligibility",total(platforms.filters,"iron-plate")==0 and total(platforms.filters,"copper-plate")==60 and total(platforms.filters,"steel-plate")==40,source_evidence)
    local shared_planet=scanner.get_platform_mode_filters(s.platforms[3],"requests",tick,"planet")
    local shared_platform=scanner.get_platform_mode_filters(s.platforms[3],"requests",tick,"platforms")
    check("shared-item-source-attribution",total(shared_planet.filters,"iron-plate")==60 and total(shared_platform.filters,"iron-plate")==35,
      helpers.table_to_json{planet=shared_planet.filters,platforms=shared_platform.filters,compiled=s.platforms[3].hub.get_requester_point().filters,configured=s.sections[3].filters})
    local point=s.platforms[3].hub.get_requester_point()
    local scaled=point.add_section()
    scaled.set_slot(1,{value={type="item",name="copper-plate",quality="normal"},min=5,request_from="planet"})
    scaled.multiplier=1.5
    local scaled_payload=scanner.get_platform_mode_filters(s.platforms[3],"requests",tick,"planet")
    check("source-filter-respects-native-section-multiplier",total(scaled_payload.filters,"copper-plate")==total(point.filters,"copper-plate"),
      helpers.table_to_json{compiled=point.filters,filtered=scaled_payload.filters})
    scaled.active=false
    check("source-filter-excludes-disabled-section",total(scanner.get_platform_mode_filters(s.platforms[3],"requests",tick,"planet").filters,"copper-plate")==0)
    local imported=point.add_section()
    imported.set_slot(1,{value={type="item",name="processing-unit",quality="normal"},min=5,request_from="planet",import_from="gleba"})
    check("source-filter-respects-import-location",total(scanner.get_platform_mode_filters(s.platforms[3],"requests",tick,"planet").filters,"processing-unit")==0,
      helpers.table_to_json{compiled=point.filters,configured=imported.filters})
    imported.active=false
    local hub=s.platforms[1].hub
    local tiles,bays={},{}
    for x=4,38 do for y=-4,20 do tiles[#tiles+1]={name="space-platform-foundation",position={x,y}} end end
    hub.surface.set_tiles(tiles)
    for x=0,7 do for y=0,3 do bays[#bays+1]=create(hub.surface,"cargo-bay",{6+x*4,-2+y*4},hub.force) end end
    local inventory=s.platforms[1].hub.get_inventory(defines.inventory.hub_main)
    check("large-cargo-bay-inventory",#inventory>=600,#inventory)
    inventory.insert{name="iron-plate",count=25}
    local after=scanner.get_platform_mode_filters(s.platforms[1],"need",tick)
    check("same-tick-inventory-mutation-invalidates-batch",total(after.filters,"iron-plate")==75)
    inventory.clear()
    inventory[1].set_stack{name="nutrients",count=9}
    inventory[1].spoil_tick=tick-1
    check("spoilage-bulk-parity",total(inventory.get_contents(),"spoilage")==9 and inventory.get_item_count("spoilage")==9)
    inventory.clear()
    local slot_totals={}
    for i=1,#inventory do local stack=inventory[i];if stack.valid_for_read then slot_totals[stack.name..":"..stack.quality.name]=(slot_totals[stack.name..":"..stack.quality.name] or 0)+stack.count end end
    check("empty-bulk-inventory-parity",#inventory.get_contents()==0 and next(slot_totals)==nil)
    inventory[#inventory].set_stack{name="iron-plate",count=17}
    if script.active_mods.quality then inventory[1].set_stack{name="iron-plate",quality="rare",count=13} end
    slot_totals={}
    for i=1,#inventory do local stack=inventory[i];if stack.valid_for_read then slot_totals[stack.name..":"..stack.quality.name]=(slot_totals[stack.name..":"..stack.quality.name] or 0)+stack.count end end
    for _, stack in ipairs(inventory.get_contents()) do slot_totals[stack.name..":"..stack.quality]=(slot_totals[stack.name..":"..stack.quality] or 0)-stack.count end
    local equal=true;for _, count in pairs(slot_totals) do equal=equal and count==0 end
    check("sparse-and-quality-bulk-inventory-parity",equal)
    local output=scanner.get_platform_mode_filters(s.platforms[1],"need",tick)
    check("quality-stock-does-not-credit-normal-request",total(output.filters,"iron-plate")==83)
    inventory.clear()
    local function circuit_count(name,entity)
      local control=(entity or s.entities.scanner).get_control_behavior()
      local result=0
      for index=1,control.sections_count do result=result+total(control.get_section(index).filters,name) end
      return result
    end
    scanner.apply_configuration(s.entities.scanner,{mode="requests",source="planet"})
    scanner.update_orbital_bank(scanner.get_bank_for_unit_number(s.entities.scanner.unit_number),tick)
    check("bank-publishes-planet-filter",circuit_count("copper-plate")==0 and circuit_count("steel-plate")==40)
    scanner.apply_configuration(s.entities.scanner,{mode="requests",source="platforms"})
    scanner.update_orbital_bank(scanner.get_bank_for_unit_number(s.entities.scanner.unit_number),tick)
    check("bank-source-switch-invalidates-output",circuit_count("copper-plate")==60 and circuit_count("steel-plate")==40)
    scanner.apply_configuration(s.entities.scanner,{mode="requests",source="all"})
    scanner.update_orbital_bank(scanner.get_bank_for_unit_number(s.entities.scanner.unit_number),tick)
    local expected=circuit_count("iron-plate")
    scanner.apply_configuration(s.entities.scanner2,{mode="requests",source="platforms"},tick)
    scanner.update_orbital_bank(scanner.get_bank_for_unit_number(s.entities.scanner2.unit_number),tick)
    check("different-source-banks-keep-independent-native-outputs",expected==185 and circuit_count("iron-plate")==expected,
      tostring(expected)..":"..circuit_count("iron-plate"))
    check("peer-bank-retains-platform-only-output",circuit_count("iron-plate",s.entities.scanner2)==35)
    s.entities.scanner2.destroy{raise_destroy=true}
    local legacy=s.entities.scanner.get_control_behavior().get_section(1)
    legacy.group="Orbital legacy QC"
    storage.ei.orbital_combinator_runtime_state_version=5
    scanner.check_init(false,tick)
    scanner.update_orbital_bank(scanner.get_bank_for_unit_number(s.entities.scanner.unit_number),tick)
    check("scanner-upgrade-detaches-legacy-group",s.entities.scanner.get_control_behavior().get_section(1).group==""
      and circuit_count("iron-plate")==185)
    for _, bay in ipairs(bays) do bay.destroy{raise_destroy=true} end
  end
  local function bridge_publication(s,tick)
    local e=s.entities.scanner
    local b=s.bridge_publication
    if not b then
      scanner.apply_configuration(e,{mode="need",source="all"},tick)
      scanner.update_orbital_bank(scanner.get_bank_for_unit_number(e.unit_number),tick)
      b={phase=1};s.bridge_publication=b
    end
    if not b.changed_tick then
      local inventory=s.platforms[1].hub.get_inventory(defines.inventory.hub_main)
      inventory.clear()
      if b.phase==1 then inventory.insert{name="iron-plate",count=25} end
      b.expected=0
      for _, platform in ipairs(s.platforms) do
        b.expected=b.expected+total(scanner.get_platform_mode_filters(platform,"need",tick).filters,"iron-plate")
      end
      b.changed_tick=tick
      return false
    end
    if tick-b.changed_tick<120 then return false end
    local control=e.get_control_behavior();local actual=0
    for index=1,control.sections_count do actual=actual+total(control.get_section(index).filters,"iron-plate") end
    check("bridge-read-publishes-stock-change-"..b.phase,actual==b.expected,tostring(actual)..":"..b.expected)
    if b.phase==1 then b.phase=2;b.changed_tick=nil;return false end
    scanner.apply_configuration(e,{mode="requests",source="all"},tick)
    return true
  end
  local function circuit_identities(s,tick)
    owner.service_for_qc(64,tick)
    for index=1,3 do
      local entity=s.entities["transponder"..index]
      local control=entity.get_control_behavior();local actual,independent=0,true
      for section=1,control.sections_count do
        local output=control.get_section(section)
        actual=actual+total(output.filters,"ei-platform-id")
        independent=independent and output.group==""
      end
      check("transponder-circuit-identity-isolated-"..index,actual==100+index,actual)
      check("transponder-output-not-a-shared-group-"..index,independent)
    end
  end
  local function persistence(s,tick)
    local e=s.entities
    local config=owner.export_configuration(e.uplink)
    check("persist-uplink-cohort-owner",config.dispatch_mode=="cohort")
    check("persist-retention",config.oversize_mode=="threshold" and config.threshold_floor==7)
    check("persist-selector",owner.export_configuration(e.selector).mode=="manual" and owner.export_configuration(e.selector).manual_platform_id==101)
    check("persist-explicit-id",owner.export_configuration(e.transponder1).manual_platform_id==101)
    local snapshot=owner.get_panel_snapshot(e.uplink,tick)
    check("persist-binding",snapshot.silo.unit_number==e.silo.unit_number)
    check("existing-world-survives-reload",e.silo.valid and s.platforms[1].valid)
    if s.lifecycle_done then
      local scanner_config=owner.export_configuration(e.scanner)
      check("persist-scanner-mode-source",scanner_config.mode=="need" and scanner_config.source=="planet")
    end
  end
  local function gui(s,tick)
    if not support.config.checkpoint then return true end
    local player=game.connected_players[1]
    if not s.gui then
      game.speed=1
      owner.service_for_qc(64,tick)
      check("gui-connected-player-required",player~=nil)
      if not player then return true end
      s.gui={index=1,opened_tick=tick}
      -- Close first-join UI and use a fixture observer that can visit platforms.
      player.opened=nil
      player.set_controller{type=defines.controllers.god}
    end
    local entities={s.entities.silo,s.platforms[1].hub,s.entities.uplink,s.entities.selector,s.entities.coordinator,s.entities.transponder1}
    local g=s.gui;local entity=entities[g.index]
    if not entity then player.opened=nil;return true end
    if not g.opened then
      player.opened=nil
      player.teleport({entity.position.x,entity.position.y-6},entity.surface)
      player.opened=entity
      check("native-open-target-"..entity.name,player.opened==entity,
        "controller="..player.controller_type.." gui="..player.opened_gui_type.." surface="..player.surface.name)
      local root=player.gui.relative[g.index<=2 and "ei-orbital-native-console" or "ei-orbital-logistics-console"]
      local children={}
      if root and root.body then for _,child in pairs(root.body.children) do children[#children+1]=child.name end end
      check("visible-panel-"..entity.name,root and root.valid and root.body["native-details"]~=nil,
        table.concat(children,",").." session="..tostring(owner.ui.has_session(player.index)))
      if not root or not root.body["native-details"] then return true end
      local body=root.body["native-details"]
      if g.index<=2 then
        check("compact-native-panel-attached-below-"..entity.type,root.anchor.position==defines.relative_gui_position.bottom)
        if g.index==1 then check("silo-panel-shares-cohort-target",owner.get_panel_snapshot(entity,tick).silo.target_name==s.platforms[1].name) end
      end
      if entity.name=="ei-orbital-coordinator" then
        local rows=owner.get_overview_rows(entity,"platforms",true,"")
        local found=false;for _, row in ipairs(rows) do found=found or row.entity==s.cargo.native_platform.hub end
        check("overview-includes-native-platform-without-transponder",found)
        body.filters.search.text="Native automatic"
        owner.on_gui_text_changed{player_index=player.index,element=body.filters.search,name=defines.events.on_gui_text_changed,tick=tick}
        check("overview-name-search",#body.rows.children==1)
        body.filters.search.text=""
        owner.on_gui_text_changed{player_index=player.index,element=body.filters.search,name=defines.events.on_gui_text_changed,tick=tick}
        owner.on_gui_click{player_index=player.index,element=body["overview-tabs"].lanes,name=defines.events.on_gui_click,tick=tick}
        check("overview-rocket-lanes-tab",#body.rows.children>=1)
      elseif entity.name=="ei-orbital-selector" then
        check("selector-named-dropdown",#body.platform.items>=4 and body.platform.selected_index>1)
      end
      g.opened=true;g.opened_tick=tick
      return false
    end
    if tick-g.opened_tick==10 then
      game.take_screenshot{player=player,path="orbital-native/"..entity.name..".png",resolution={1280,720},show_gui=true}
    end
    if tick-g.opened_tick<15 then return false end
    if entity.name=="ei-orbital-coordinator" then
      local body=player.gui.relative["ei-orbital-logistics-console"].body["native-details"]
      owner.on_gui_click{player_index=player.index,element=body["overview-tabs"].platforms,name=defines.events.on_gui_click,tick=tick}
      local target=owner.get_overview_rows(entity,"platforms",false,"")[1].entity
      check("overview-link-target-is-on-another-surface",target.surface~=entity.surface)
      owner.on_gui_click{player_index=player.index,element=body.rows.children[1],name=defines.events.on_gui_click,tick=tick}
      check("overview-link-enters-native-remote-view",player.controller_type==defines.controllers.remote and player.centered_on==target)
      check("overview-link-opens-native-hub-window",player.opened==target and player.gui.relative["ei-orbital-native-console"]~=nil)
      player.opened=nil
      if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
    end
    if g.index<=2 then
      owner.on_native_gui_closed{player_index=player.index,entity=entity,tick=tick}
      check("native-panel-close-releases-interest-"..entity.type,not player.gui.relative["ei-orbital-native-console"])
    else owner.close_gui(player) end
    g.index=g.index+1;g.opened=false
    return false
  end
  return {step=function(tick)
    started=started or tick
    local s=storage.orbital_native_fixture
    if support.phase()=="reload" or support.phase()=="configuration" then
      if not s then check("saved-fixture-present",false);return {complete=true,checks=checks} end
      if tick-started<120 then return {complete=false} end
      circuit_identities(s,tick)
      persistence(s,tick)
      return {complete=true,checks=checks}
    end
    if not s then
      if support.config.checkpoint then game.speed=4 end
      s=build();return {complete=false}
    end
    if tick-s.start<30 then return {complete=false} end
    if not s.functional_done then
      scanner_checks(s,tick)
      local e=s.entities
      check("explicit-native-adoption",owner.set_dispatch_mode(e.uplink.unit_number,"native",tick) and e.silo.use_transitional_requests)
      owner.service_for_qc(64,tick)
      check("native-owner-no-lease",#owner.get_qc_snapshot(tick).leases==0)
      check("explicit-cohort-adoption",owner.set_dispatch_mode(e.uplink.unit_number,"cohort",tick) and not e.silo.use_transitional_requests)
      check("owner-switch-clears-stale-native-blocker",owner.get_silo_snapshot(e.silo,tick).blocker~="native-owner")
      owner.apply_qc_configuration({selectors={{unit_number=e.selector.unit_number,mode="manual",manual_platform_id=101}},
        uplinks={{unit_number=e.uplink.unit_number,oversize_mode="threshold",threshold_floor=7}}},tick)
      owner.service_for_qc(64,tick)
      e.silo.use_transitional_requests=true
      owner.on_built_entity{entity=e.silo,tick=tick}
      owner.service_for_qc(64,tick)
      check("external-native-owner-suspends-dispatch",#owner.get_qc_snapshot(tick).leases==0)
      e.silo.use_transitional_requests=false
      e.transponder1.get_control_behavior().get_section(1).group="Platform ID"
      owner.rebuild_runtime_state("native-fixture",tick)
      persistence(s,tick)
      local copy=create(e.selector.surface,"ei-orbital-selector",{500,516},e.selector.force)
      owner.on_entity_settings_pasted{source=e.selector,destination=copy,tick=tick}
      check("settings-paste-copies-selector-intent",owner.export_configuration(copy).manual_platform_id==101)
      local blueprint_tags
      owner.on_blueprint{player_index=game.players[1] and game.players[1].index or 1,
        record={set_blueprint_entity_tag=function(_,_,config) blueprint_tags=config end},mapping={get=function() return {[1]=e.uplink} end}}
      if game.players[1] then check("blueprint-excludes-live-binding",blueprint_tags and blueprint_tags.dispatch_mode=="cohort" and blueprint_tags.binding_silo_unit_number==nil) end
      copy.destroy{raise_destroy=true}
      s.functional_done=true
      return {complete=false}
    end
    if not s.bridge_publication_done then
      if not bridge_publication(s,tick) then return {complete=false} end
      s.bridge_publication_done=true
    end
    if not s.radar_done then
      if not radar.step(s,tick,check) then return {complete=false} end
      local circuit_requests=scanner.get_platform_mode_filters(s.platforms[2],"requests",tick,"planet")
      check("source-filter-includes-native-circuit-requests",total(circuit_requests.filters,"iron-plate")==55,helpers.table_to_json(circuit_requests.filters))
      s.radar_done=true
    end
    if not s.cargo_done then
      if not s.lifecycle_done then
        if not lifecycle.step(s,tick,check) then return {complete=false} end
        s.lifecycle_done=true
      end
      if not cargo.step(s,tick,check) then return {complete=false} end
      s.cargo_done=true
    end
    if not s.output_identity_done then
      circuit_identities(s,tick)
      s.output_identity_done=true
    end
    if not gui(s,tick) then return {complete=false} end
    return {complete=true,checks=checks,metrics={platform_count=3,engine=script.active_mods.base,quality=script.active_mods.quality~=nil}}
  end}
end
