local support=require("__esir-qc-native-tests__.support")
local config=require("__exotic-space-industries-remembrance__/lib/combustion-turbine-config")
local process=require("__exotic-space-industries-remembrance__/scripts/control/combustion-turbine-process")
local checks=support.record
local expansion=require("__esir-qc-native-tests__.expansion")
local function near(a,b,tolerance) return math.abs(a-b)<(tolerance or 0.001) end
local function amount(entity,index)
    local fluid=entity.get_fluid(index)
    return fluid and fluid.amount or 0
end
local function record(entity) return storage.ei.combustion_turbine.turbines_by_unit[entity.unit_number] end
local function capture(entity)
    local r=record(entity)
    local state=process.capture(entity,r)
    local fuel=state.fuel
    local chemical=entity.burner and
        (entity.get_fuel_inventory().get_item_count("coal")*prototypes.item.coal.fuel_value+entity.burner.remaining_burning_fuel)
        or (fuel and fuel.amount*prototypes.fluid[fuel.name].fuel_value or 0)
    local p=state.process or {}
    local generator=r.generator
    return {name=entity.name,requested=r.oxygen_requested,oxygen=p.oxygen and p.oxygen.amount or 0,
        working=(p.working and p.working.amount or 0)+(generator and amount(generator,1) or 0),
        co2=generator and amount(generator,2) or 0,progress=p.progress or 0,process_energy=p.energy or 0,
        chemical=chemical,heat=entity.burner and entity.burner.heat or 0,
        electrical=state.electrical_energy,stored_heat=state.atmospheric_heat+(p.energy or 0),
        crafting=process.is_oxygen(entity) and entity.is_crafting() or false}
end
local function flat_equal(before,after,fields,label)
    for _,key in ipairs(fields) do
        local expected,actual=before[key],after[key]
        checks(label.."-"..key,type(expected)=="number" and near(expected,actual,0.05) or expected==actual,
            helpers.table_to_json{before=before,after=after})
    end
end
local function surface(name,pressure)
    local s=game.create_surface(name,{width=256,height=128})
    s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
    local tiles={}
    for x=-12,124 do for y=-12,20 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    s.set_tiles(tiles);s.set_property("pressure",pressure)
    return s
end
local function build(model,s,x,mode,preference)
    local e=assert(s.create_entity{name=config.solid,position={x,0},force="player",
        quality=script.active_mods.quality and "rare" or "normal"})
    return assert(model.on_built_entity{entity=e,tick=game.tick,tags={
        [config.mode_tag]=mode,[config.oxygen_tag]=preference}})
end
local function poll(model,tick)
    expansion.step(model,tick)
    local state=storage.turbine_integration
    if support.phase()=="reload" then
        checks("checkpoint-completed",state and state.completed)
        for index,r in ipairs(state.records) do
            flat_equal(r.saved,capture(r.body),{"name","requested","oxygen","working","co2","progress","process_energy","chemical","electrical","stored_heat"},
                "reload-"..index)
            checks("reload-helper-"..index,record(r.body).generator.valid)
        end
        support.complete();return support.poll()
    end
    if not state then
        state={started=tick,records={}}
        storage.turbine_integration=state
        local s=surface("turbine-integration",33)
        for index,mode in ipairs({"solid","solid","fluid","fluid"}) do
            local x=(index-1)*30
            local body=build(model,s,x,mode,false)
            checks(mode.."-at-33-atmospheric-"..index,not process.is_oxygen(body))
            body=model.swap_to_mode(body,mode,tick,nil,true)
            checks(mode.."-optional-oxygen-"..index,process.is_oxygen(body) and record(body).oxygen_requested)
            body.set_fluid(process.oxygen_index(body),{name="ei-oxygen-gas",amount=200})
            if mode=="solid" then body.insert{name="coal",count=50}
            else body.set_fluid_segment_fluid(1,{name="ei-diesel",amount=400,temperature=60}) end
            local load=assert(s.create_entity{name="esir-turbine-integration-load",position={x+8,4},force="player"})
            s.create_entity{name="substation",position={x+8,0},force="player"}
            state.records[index]={body=body,mode=mode,load=load}
            checks("working-link-"..index,body.get_fluid_box_linked_connection(1)==record(body).generator)
        end
        state.boundary=surface("turbine-boundary",33)
        state.boundary_body=build(model,state.boundary,0,"solid",false)
        state.boundary_body.energy=11111
        state.boundary_body.burner.heat=22222
        checks("native-electrical-and-burner-buffers-independent",
            near(state.boundary_body.energy,11111) and near(state.boundary_body.burner.heat,22222),
            helpers.table_to_json{energy=state.boundary_body.energy,heat=state.boundary_body.burner.heat})
        state.boundary_body.energy=0
        state.boundary_body.burner.heat=0
        local platform=assert(game.forces.player.create_space_platform{
            name="Turbine oxygen QC",planet="nauvis",starter_pack="space-platform-starter-pack"})
        platform.apply_starter_pack(true)
        local deck={}
        for x=-12,74 do for y=-12,12 do deck[#deck+1]={name="space-platform-foundation",position={x,y}} end end
        platform.surface.set_tiles(deck)
        checks("real-platform-pressure-zero",platform.surface.get_property("pressure")==0)
        state.platform_records={}
        for index,mode in ipairs({"solid","fluid"}) do
            local x=30+(index-1)*30
            checks("platform-canonical-placement-"..mode,platform.surface.can_place_entity{
                name=config.solid,position={x,0},force="player",build_check_type=defines.build_check_type.manual})
            local body=build(model,platform.surface,x,mode,false)
            checks("platform-forces-oxygen-"..mode,process.is_oxygen(body) and not record(body).oxygen_requested)
            local inlet=assert(platform.surface.create_entity{name="pipe",position={x,-5},force="player"})
            local outlet=assert(platform.surface.create_entity{name="pipe",position={x,5},force="player"})
            inlet.set_fluid_segment_fluid(1,{name="ei-oxygen-gas",amount=100})
            if mode=="solid" then body.insert{name="coal",count=50}
            else
                assert(platform.surface.create_entity{name="pipe",position={x+5,0},force="player"})
                body.set_fluid_segment_fluid(1,{name="ei-diesel",amount=400})
            end
            platform.surface.create_entity{name="esir-turbine-integration-load",position={x+8,4},force="player"}
            state.platform_records[index]={body=body,mode=mode,inlet=inlet,outlet=outlet}
        end
        return
    end
    local elapsed=tick-state.started
    if elapsed==120 then
        for _,r in ipairs(state.records) do r.start=capture(r.body) end
    end
    if elapsed==121 then
        for index,r in ipairs(state.records) do
            if index%2==0 then
                local before=capture(r.body)
                for _=1,20 do
                    r.body=model.swap_to_mode(r.body,r.mode,tick,nil,false)
                    checks("dormant-helper-"..index,record(r.body).generator.disabled_by_script)
                    r.body=model.swap_to_mode(r.body,r.mode,tick,nil,true)
                end
                flat_equal(before,capture(r.body),{"oxygen","working","co2","progress","chemical","process_energy","crafting"},
                    "loaded-toggle-"..index)
            end
        end
    end
    if elapsed==300 then
        local snapshots={}
        for index,r in ipairs(state.records) do snapshots[index]=capture(r.body) end
        for index,r in ipairs(state.records) do
            local after=snapshots[index]
            checks("oxygen-rate-"..index,near(r.start.oxygen-after.oxygen,60,1.01),helpers.table_to_json{before=r.start,after=after})
            checks("co2-rate-"..index,near(after.co2-r.start.co2,60,0.7))
            checks("fuel-efficiency-"..index,near(r.start.chemical-after.chemical,36000000/(r.mode=="solid" and 3 or 2.25),300000))
            if index%2==0 then
                flat_equal(snapshots[index-1],after,{"oxygen","working","co2","chemical","progress"},
                    "toggle-control-"..index)
            end
            local generator=record(r.body).generator
            if index%2==1 then
                generator.set_fluid(2,{name="ei-carbon-dioxide",amount=200})
                r.body.set_fluid(process.oxygen_index(r.body),{name="ei-oxygen-gas",amount=200})
            else
                r.body.clear_fluid(process.oxygen_index(r.body))
                generator.clear_fluid(2)
            end
        end
        for _,r in ipairs(state.platform_records) do
            local exhaust=r.outlet.get_fluid_segment_fluid(1)
            checks("real-platform-produces-co2-"..r.mode,capture(r.body).co2+(exhaust and exhaust.amount or 0)>20)
            checks("platform-native-exhaust-port-"..r.mode,exhaust and exhaust.name=="ei-carbon-dioxide" and exhaust.amount>0)
            local inlet=r.inlet.get_fluid_segment_fluid(1)
            checks("platform-native-oxygen-port-"..r.mode,not inlet or inlet.amount<99)
            r.body.disabled_by_script=true
            record(r.body).generator.disabled_by_script=true
        end
        state.boundary.set_property("pressure",32.999)
    end
    if elapsed==360 then
        for _,r in ipairs(state.records) do r.stopped=capture(r.body) end
    end
    if elapsed==365 then
        state.boundary_body=state.boundary.find_entities_filtered{name=config.oxygen_solid}[1]
        checks("strict-below-33-forces-oxygen",state.boundary_body~=nil)
        checks("forced-keeps-false-preference",record(state.boundary_body).oxygen_requested==false)
        local b=state.boundary_body
        b=model.swap_to_mode(b,"solid",tick,nil,false)
        checks("cannot-disable-below-33",process.is_oxygen(b))
        state.boundary.set_property("pressure",33)
    end
    if elapsed==430 then
        local b=state.boundary.find_entities_filtered{name=config.solid}[1]
        checks("at-33-restores-atmospheric-preference",b~=nil)
        b.insert{name="coal",count=13}
        b.burner.currently_burning="coal";b.burner.remaining_burning_fuel=123456
        local before=capture(b)
        storage.ei.turbine_qc_fail=true
        local failed=model.swap_to_mode(b,"solid",tick,nil,true)
        checks("failed-manual-keeps-identity",failed==b)
        flat_equal(before,capture(b),{"requested","chemical","name"},"failed-manual")
        state.boundary.set_property("pressure",0)
        state.boundary_body=b
    end
    if elapsed==495 then
        checks("failed-forced-disables-atmospheric",state.boundary_body.valid and state.boundary_body.disabled_by_script)
        state.retry_before=capture(state.boundary_body)
        storage.ei.turbine_qc_fail=nil
    end
    if elapsed==480 then
        for index,r in ipairs(state.records) do
            flat_equal(r.stopped,capture(r.body),{"oxygen","co2","chemical"},(index%2==1 and "blocked-exhaust-" or "oxygen-starved-")..index)
            r.body.disabled_by_script=true
            record(r.body).generator.disabled_by_script=true
        end
    end
    if elapsed==560 then
        local b=state.boundary.find_entities_filtered{name=config.oxygen_solid}[1]
        checks("forced-retries",b and not b.disabled_by_script)
        local before,after=state.retry_before,capture(b)
        local function potential(s) return s.chemical*3+s.stored_heat+s.electrical+(s.working+s.progress)*600000 end
        checks("forced-retry-preserves-energy",near(potential(before),potential(after),1),
            helpers.table_to_json{before=before,after=after})
        state.boundary_body=b
        local tag_built=build(model,state.boundary,30,"fluid",true)
        checks("tag-import-both-modes",tag_built.name==config.oxygen_fluid and record(tag_built).oxygen_requested)
        model.on_entity_settings_pasted{source=b,destination=tag_built,tick=tick}
        local pasted=state.boundary.find_entities_filtered{name=config.oxygen_solid,position={30,0}}[1]
        checks("paste-stored-false-while-forced",pasted and not record(pasted).oxygen_requested)
        state.boundary.set_property("pressure",33)
    end
    if elapsed==625 then
        checks("paste-restores-atmospheric-at-33",#state.boundary.find_entities_filtered{name=config.solid}==2)
        model.rebuild_runtime_state("native-fixture",tick)
        for index,r in ipairs(state.records) do
            checks("rebuild-keeps-shell-"..index,r.body.valid)
            record(r.body).generator.disabled_by_script=true
            r.saved=capture(r.body)
        end
        local player=assert(game.connected_players[1])
        state.boundary.set_property("pressure",0)
        local b=state.boundary.find_entities_filtered{name=config.solid,position={0,0}}[1]
        b=model.swap_to_mode(b,"solid",tick,nil,false)
        state.boundary_body=b
        local inventory=game.create_inventory(2)
        inventory[1].set_stack{name="blueprint"}
        local mapping=inventory[1].create_blueprint{surface=b.surface,force=b.force,area={{-5,-5},{5,5}}}
        model.on_blueprint{player_index=player.index,stack=inventory[1],mapping={get=function() return mapping end},tick=tick}
        local blueprint_index
        for index,source in pairs(mapping) do if source==b then blueprint_index=index end end
        assert(blueprint_index,"Native blueprint includes turbine")
        checks("blueprint-stored-false-under-forced-mode",inventory[1].get_blueprint_entity_tag(blueprint_index,config.oxygen_tag)==false)
        inventory[2].import_stack(inventory[1].export_stack())
        checks("blueprint-export-import-false",inventory[2].get_blueprint_entity_tag(blueprint_index,config.oxygen_tag)==false)
        checks("blueprint-export-import-fuel",inventory[2].get_blueprint_entity_tag(blueprint_index,config.mode_tag)=="solid")
        inventory.destroy()
        local clone=assert(b.clone{position={60,0},surface=b.surface,force=b.force})
        checks("native-clone-preference",record(clone).oxygen_requested==false)
        flat_equal(capture(b),capture(clone),{"oxygen","working","co2","chemical","progress","electrical","stored_heat"},"clone-custody")
        for _,direction in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
            local before_rotation=capture(clone)
            clone.direction=direction
            clone=model.on_moved_entity{entity=clone,tick=tick}
            checks("rotation-helper-"..direction,record(clone).generator.direction==direction
                and clone.get_fluid_box_linked_connection(1)==record(clone).generator,
                helpers.table_to_json{requested=direction,body=clone.direction,generator=record(clone).generator.direction,
                    linked=clone.get_fluid_box_linked_connection(1)==record(clone).generator})
            flat_equal(before_rotation,capture(clone),{"oxygen","working","co2","chemical","progress","electrical","stored_heat"},"rotation-custody-"..direction)
        end
        local before_move=capture(clone)
        local destination=surface("turbine-movement",33)
        local donor=clone
        -- Native 2.1 machine teleport is same-surface only; cloning is the
        -- supported cross-surface path. The clone dispatcher may replace it.
        donor.clone{position={0,0},surface=destination,force=donor.force}
        clone=assert(destination.find_entities_filtered{name=config.solid,position={0,0}}[1])
        checks("cross-surface-clone-restores-atmospheric",record(clone).generator.surface==destination)
        flat_equal(before_move,capture(clone),{"oxygen","working","co2","chemical","electrical","stored_heat"},"cross-surface-clone-custody")
        donor.destroy{raise_destroy=true}
        local helper=record(clone).generator
        clone.destroy{raise_destroy=true}
        checks("body-destruction-removes-helper",not helper.valid)
        local persistence_surface=surface("turbine-dormant-save",0)
        local persistent=assert(b.clone{position={0,0},surface=persistence_surface,force=b.force})
        state.records[#state.records+1]={body=persistent,mode="solid"}
        player.teleport({0,9},state.boundary)
        player.opened=b
        model.open_gui(player,b,tick)
        local root=assert(player.gui.relative["ei-combustion-turbine-console"])
        local toggle=root["main-container"]["options-flow"]["oxygen-fed-toggle"]
        checks("forced-gui-checked-disabled",toggle.state and not toggle.enabled)
        checks("oxygen-gui-native-anchor",root.anchor.gui==defines.relative_gui_type.assembling_machine_gui)
        state.gui_player=player
    end
    if elapsed==635 and support.config.checkpoint then
        game.take_screenshot{player=state.gui_player,path="turbine-native/forced-solid.png",resolution={1440,900},show_gui=true}
    end
    if elapsed==645 then
        local player=state.gui_player
        state.boundary.set_property("pressure",33)
        local b=model.swap_to_mode(state.boundary_body,"solid",tick,nil,false)
        state.boundary_body=b
        local root=assert(player.gui.relative["ei-combustion-turbine-console"])
        local toggle=root["main-container"]["options-flow"]["oxygen-fed-toggle"]
        checks("atmospheric-gui-enabled-unchecked",toggle.enabled and not toggle.state)
        toggle.state=true
        local changed=assert(script.get_event_handler(defines.events.on_gui_checked_state_changed))
        changed{element=toggle,player_index=player.index,tick=tick}
        b=state.boundary.find_entities_filtered{name=config.oxygen_solid,position={0,0}}[1]
        checks("gui-checkbox-dispatch-selects-oxygen",b and record(b).oxygen_requested)
        state.boundary_body=b
        checks("gui-retargets-native-owner",player.opened==b)
    end
    if elapsed==655 and support.config.checkpoint then
        game.take_screenshot{player=state.gui_player,path="turbine-native/optional-solid.png",resolution={1440,900},show_gui=true}
    end
    if elapsed==650 then
        local player=state.gui_player
        local root=player.gui.relative["ei-combustion-turbine-console"]
        local changed=assert(script.get_event_handler(defines.events.on_gui_checked_state_changed))
        local ash=root["main-container"]["options-flow"]["ash-toggle"]
        ash.state=true
        changed{element=ash,player_index=player.index,tick=tick}
        local b=player.opened
        state.boundary_body=b
        checks("ash-gui-native-checkbox",b.name==config.oxygen_ash_solid and record(b).ash_requested)
        root=player.gui.relative["ei-combustion-turbine-console"]
        local enabled=root["main-container"]["options-flow"]["enabled-toggle"]
        enabled.state=false
        changed{element=enabled,player_index=player.index,tick=tick}
        checks("enabled-gui-native-checkbox",b.disabled_by_script and record(b).generator.disabled_by_script)
        storage.ei.turbine_qc_player_alias=player.index
        storage.ei.combustion_turbine.open_by_player[1000000]=b.unit_number
        storage.ei.turbine_qc_reads=0
        model.updater{tick=tick-tick%60}
        checks("two-viewer-entries-share-one-snapshot",storage.ei.turbine_qc_reads==1)
        storage.ei.combustion_turbine.open_by_player[1000000]=nil
        model.close_gui(player)
        storage.ei.turbine_qc_reads=0
        model.updater{tick=tick-tick%60}
        checks("closed-panels-read-no-statistics",storage.ei.turbine_qc_reads==0)
        storage.ei.turbine_qc_player_alias=nil
        player.opened=b
        model.open_gui(player,b,tick)
        local inv=game.create_inventory(1)
        inv[1].set_stack{name="blueprint"}
        local mapping=inv[1].create_blueprint{surface=b.surface,force=b.force,area={{-5,-5},{5,5}}}
        model.on_blueprint{player_index=player.index,stack=inv[1],mapping={get=function() return mapping end},tick=tick}
        for index,source in pairs(mapping) do if source==b then
            checks("blueprint-ash-enabled-tags",inv[1].get_blueprint_entity_tag(index,config.ash_tag)==true
                and inv[1].get_blueprint_entity_tag(index,config.enabled_tag)==false)
        end end
        inv.destroy()
    end
    if elapsed==660 then
        local b=state.boundary_body
        b.get_burnt_result_inventory().clear()
        b=model.swap_to_mode(b,"solid",tick,nil,nil,false,true)
        checks("ash-gui-roundtrip",b.name==config.oxygen_solid and not b.disabled_by_script)
        state.boundary_body=b
    end
    if elapsed==665 then
        state.boundary_body=model.swap_to_mode(state.boundary_body,"fluid",tick)
        local player=state.gui_player
        checks("fluid-oxygen-retargets-gui",player.opened==state.boundary_body)
        local root=assert(player.gui.relative["ei-combustion-turbine-console"])
        checks("oxygen-fluid-no-service-hatch-tip",not root["main-container"]["status-flow"]["fluid-hotspot-tip-label"].visible)
    end
    if elapsed==675 and support.config.checkpoint then
        game.take_screenshot{player=state.gui_player,path="turbine-native/optional-fluid.png",resolution={1440,900},show_gui=true}
    end
    if elapsed==685 then
        local player=state.gui_player
        state.boundary_body=model.swap_to_mode(state.boundary_body,"fluid",tick,nil,false)
        checks("atmospheric-fluid-detached-panel",player.gui.screen["ei-combustion-turbine-console"]~=nil)
    end
    if elapsed==695 and support.config.checkpoint then
        game.take_screenshot{player=state.gui_player,path="turbine-native/atmospheric-fluid.png",resolution={1440,900},show_gui=true}
    end
    if elapsed==705 then
        model.close_gui(state.gui_player)
        for _,r in ipairs(state.platform_records) do state.records[#state.records+1]=r end
        for _,r in ipairs(state.records) do
            r.body.disabled_by_script=true
            record(r.body).generator.disabled_by_script=true
            r.saved=capture(r.body)
        end
        state.completed=true
        support.complete();return support.poll()
    end
end
return {step=function(model,tick)
    local ok,result=xpcall(function() return poll(model,tick) end,debug.traceback)
    if not ok then checks("fixture-exception",false,result);support.complete();return support.poll() end
    return result
end}
