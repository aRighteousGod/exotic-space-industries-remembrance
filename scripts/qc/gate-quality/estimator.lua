-- Private estimator proof; appended to the managed owner, never shipped.
local estimate_calc=require("lib/gate-calculations")
local estimate_projection=require("lib/gate-projection")
local estimate_ui=require("scripts/control/gate-estimator")
local function estimator_element(root,action,key)
    local t=root.tags or {}
    if t.action==action and (key==nil or t.key==key) then return root end
    for _,child in pairs(root.children) do local found=estimator_element(child,action,key);if found then return found end end
end
local function estimator_gui_checks(q,event,check,player,viewer)
    local original=table.deepcopy(viewer.draft)
    local function change(action,key,value,name)
        local element=assert(estimator_element(viewer.gui.root,action,key))
        if action=="planet" then element.elem_value=value
        elseif action=="value" then element.text=value
        else element.selected_index=value end
        estimate_ui.on_event{element=element,player_index=player.index,tick=event.tick,name=name}
    end
    local selection=defines.events.on_gui_selection_state_changed
    local elem=defines.events.on_gui_elem_changed
    local edit=defines.events.on_gui_text_changed
    change("planet","from","nauvis",elem);change("planet","to","vulcanus",elem)
    local scenario=assert(estimate_ui.scenario(viewer))
    check(q,"estimator planet distance locks",not viewer.gui.fields.distance.slider.enabled and scenario.distance>0)
    change("planet","to","nauvis",elem)
    check(q,"estimator identical planets local",estimate_ui.scenario(viewer).multiplier==0.15)
    change("planet","to",nil,elem)
    check(q,"estimator clearing planet unlocks",viewer.gui.fields.distance.slider.enabled)
    change("value","batch","",edit);change("value","stress","",edit)
    change("value","batch","1",edit)
    check(q,"estimator validates every input",not viewer.gui.run.enabled)
    change("value","stress","30",edit)
    check(q,"estimator valid input recovers",viewer.gui.run.enabled)
    change("rate-unit",nil,2,selection);change("value","rate","120",edit)
    check(q,"estimator minute rate conversion",viewer.draft.rate==2)
    change("power-unit",nil,2,selection);change("value","power","2",edit)
    check(q,"estimator GW conversion",viewer.draft.power==2000)
    change("value","rate","",edit);change("rate-unit",nil,1,selection)
    check(q,"estimator unit change repairs rate input",viewer.gui.run.enabled and viewer.gui.fields.rate.value.text=="2")
    change("value","power","",edit);change("power-unit",nil,1,selection)
    check(q,"estimator unit change repairs power input",viewer.gui.run.enabled and viewer.gui.fields.power.value.text=="2000")
    viewer.baseline=estimate_ui.scenario(viewer)
    viewer.baseline.item="removed-estimator-qc-item"
    estimate_ui.refresh(player,viewer)
    check(q,"estimator removed baseline cannot run",not viewer.gui.run.enabled and viewer.gui.pin.enabled)
    estimate_ui.run(player,viewer)
    check(q,"estimator invalid baseline queues no work",not storage.ei_gate_estimator.jobs[player.index])
    viewer.baseline=nil
    for _,name in ipairs(viewer.qualities) do
        check(q,"estimator selectable quality "..name,name=="normal" or not prototypes.quality[name].hidden)
    end
    estimate_ui.run(player,viewer)
    check(q,"estimator explicit run admits work",storage.ei_gate_estimator.jobs[player.index]~=nil)
    change("value","stress","31",edit)
    check(q,"estimator edit cancels projection",not storage.ei_gate_estimator.jobs[player.index] and viewer.stale)
    viewer.draft.batch=prototypes.item[viewer.draft.item].stack_size+1
    estimate_ui.build(player,viewer)
    check(q,"estimator saved batch respects current prototype",viewer.draft.batch==prototypes.item[viewer.draft.item].stack_size)
    viewer.draft=original;viewer.per_minute=false;viewer.power_gw=false
    estimate_ui.build(player,viewer)
end
local function estimator_native_comparison(q,event,check)
    local surface=q.container.surface
    local container=assert(surface.create_entity{name="ei-gate-container",position={-24,24},force="player"})
    ei_gate.make_gate(container,event)
    local gate=assert(surface.find_entity("ei-gate",container.position))
    local receiver=assert(surface.create_entity{name="ei-gate-receiver",position={-8,24},force="player"})
    ei_gate.register_receiver(receiver,event)
    local g=storage.ei.gate.gate[gate.unit_number]
    local r=storage.ei.gate.receiver[receiver.unit_number]
    g.manual_enabled=true
    ei_gate.set_manual_receiver(gate.unit_number,r.effective_id,event)
    local input=container.get_inventory(defines.inventory.chest)
    local output=receiver.get_inventory(defines.inventory.chest)
    for case,values in ipairs{{"iron-plate",0,1e12,1e9,30},{"iron-plate",100,99e9,1e9,300},{"cargo-landing-pad",0,100e9,0,600}} do
        input.clear();output.clear()
        local item,saturation,energy,power,rate=table.unpack(values)
        gate.energy=energy;g.stress=23;g.last_energy_tick=0;g.cooldown_until_tick=case==2 and 90 or 0
        g.residue_progress=0;r.residue_progress=0;r.saturation=saturation;r.last_penalty_tick=0
        ei_gate.refresh_gate_live_state(gate,{tick=0});ei_gate.update_input_lock(gate,g,{tick=0})
        local s={item=item,weight=ei_gate.mass_weights[item] or 1,batch=10,stack_size=prototypes.item[item].stack_size,
            slots=#input,multiplier=0.15,quality_multiplier=1,energy=energy,capacity=gate.electric_buffer_size,
            input_limit=gate.input_flow_limit,power=power,rate=rate,stress=23,saturation=saturation,
            cooldown=g.cooldown_until_tick,service=16,horizon=16}
        local sim=estimate_projection.new(s)
        local upstream,delivered=0,0
        for tick=1,960 do
            gate.energy=math.min(s.capacity,gate.energy+math.min(power/60,s.input_limit))
            upstream=upstream+rate/60
            if input.get_bar()>1 then
                local count=math.min(math.floor(upstream+1e-9),s.batch)
                if count>0 then upstream=upstream-input.insert{name=item,count=count} end
            end
            if tick%16==0 then
                ei_gate.decay_receiver_penalties(r,16)
                ei_gate.update_energy(gate.unit_number,gate,{tick=tick})
                ei_gate.check_for_teleport(gate.unit_number,gate,{tick=tick})
            end
            input.remove{name="ei-breach-residue",count=1000000}
            delivered=delivered+output.get_item_count(item);output.clear()
            estimate_projection.advance(sim,1)
        end
        check(q,"projection native delivered "..case,sim.delivered==delivered)
        check(q,"projection native cargo "..case,sim.cargo==input.get_item_count(item))
        check(q,"projection native backlog "..case,math.abs(sim.upstream-upstream)<0.00001)
        check(q,"projection native energy "..case,math.abs(sim.energy-gate.energy)<1)
        check(q,"projection native stress "..case,math.abs(sim.stress-g.stress)<1e-9)
        check(q,"projection native saturation "..case,math.abs(sim.saturation-r.saturation)<1e-9)
        check(q,"projection native cooldown "..case,math.max(0,sim.deadline-960)==math.max(0,g.cooldown_until_tick-960))
    end
    ei_gate.destroy_gate(gate,container,event)
    receiver.destroy()
end
local function estimator_checks(q,event,check)
    estimator_native_comparison(q,event,check)
    for _,burden in ipairs{0,1,25,100,10000} do
        check(q,"estimator burden energy "..burden,estimate_calc.energy(burden)==ei_gate.energy_from_burden(burden))
        for _,distance in ipairs{0.15,2.5,3,8} do
            local quote=estimate_calc.quote(burden,1,distance,1/1.4)
            check(q,"estimator independent toll "..burden.."/"..distance,
                quote.energy_j==math.floor((burden^1.2)*100*1e6*distance/(1.4)))
        end
    end
    local scenario={item="iron-plate",weight=1,batch=10,stack_size=100,slots=30,multiplier=0.15,
        quality_multiplier=1,energy=1e12,capacity=3.2e12,input_limit=430e9/60,power=1e9,
        rate=30,stress=0,saturation=0,cooldown=0,service=16,horizon=60}
    local a=estimate_projection.new(table.deepcopy(scenario))
    local b=estimate_projection.new(table.deepcopy(scenario))
    estimate_projection.advance(a,3600)
    while not estimate_projection.advance(b,37) do end
    check(q,"estimator resumable determinism",serpent.line(a,{sortkeys=true})==serpent.line(b,{sortkeys=true}))
    check(q,"estimator cargo conservation",math.abs(a.offered-a.delivered-a.cargo-a.upstream)<0.00001)
    check(q,"estimator energy conservation",math.abs(scenario.energy+a.charged_j-a.transfer_j-a.upkeep_j-a.energy)<scenario.capacity*1e-12)
    check(q,"estimator eager supply and upstream backlog",a.delivered>0 and a.upstream>0 and a.waits.cooldown>0)
    check(q,"estimator sample bound",#a.bins<=240)
    scenario.rate=0;scenario.power=0;scenario.energy=0
    local empty=estimate_projection.new(scenario);estimate_projection.advance(empty,3600)
    check(q,"estimator zero supply and power",empty.delivered==0 and empty.energy==0 and empty.upkeep_j==0)
end

local function estimator_restore(q,event,check)
    local root=storage.ei_gate_estimator
    if q.estimator_saved then
        local viewer=root and root.players[q.estimator_saved.player]
        check(q,"estimator saved draft and baseline",viewer and serpent.line({viewer.draft,viewer.baseline},{sortkeys=true})==q.estimator_saved.value)
        check(q,"estimator reload cancels jobs",not estimate_ui.has_tick_work())
        check(q,"estimator open window rebuilt after load",viewer.open and viewer.gui and viewer.gui.root.valid)
        check(q,"estimator old projections invalidated",viewer.stale and viewer.results==nil)
    end
end

local function estimator_step(q,event,check)
    local elapsed=event.tick-q.start
    local player=game.players[1]
    if not player then return end
    if elapsed==200 then
        local before=q.gate.energy
        local contents=serpent.line(q.container.get_inventory(defines.inventory.chest).get_contents(),{sortkeys=true})
        player.opened=q.container;ei_gate.open_gui(player,event)
        local opened=player.opened
        local launch=assert(ei_gate.get_gui_elements(player)).estimator
        script.get_event_handler(defines.events.on_gui_click){element=launch,player_index=player.index,
            tick=event.tick,name=defines.events.on_gui_click,button=defines.mouse_button_type.left}
        local viewer=storage.ei_gate_estimator.players[player.index]
        check(q,"estimator console launch dispatch",viewer and viewer.open and viewer.gui.root.valid)
        check(q,"estimator detached does not steal opened",player.opened==opened)
        check(q,"estimator snapshot does not mutate gate",before==q.gate.energy and contents==serpent.line(q.container.get_inventory(defines.inventory.chest).get_contents(),{sortkeys=true}))
        estimator_gui_checks(q,event,check,player,viewer)
        viewer.baseline=estimate_ui.scenario(viewer)
        viewer.draft.rate=20;viewer.draft.batch=20;viewer.draft.energy=1000;viewer.draft.stress=30
        estimate_ui.build(player,viewer);estimate_ui.run(player,viewer)
    elseif elapsed==245 then
        local viewer=storage.ei_gate_estimator.players[player.index]
        check(q,"estimator queued projection completes",viewer.results and #viewer.results==2 and not viewer.stale)
        check(q,"estimator rendering private",#viewer.renders>0 and viewer.renders[1].players[1].index==player.index)
        viewer.gui.root.auto_center=true
        log("ESTIMATOR_RENDER "..helpers.table_to_json{resolution=player.display_resolution,scale=player.display_scale,
            camera_zoom=viewer.gui.cameras[1].zoom})
        game.take_screenshot{player=player,resolution=player.display_resolution,show_gui=true,path="gate-cooldown/estimator-calculation.png"}
    elseif elapsed==255 then
        local viewer=storage.ei_gate_estimator.players[player.index]
        viewer.gui.tabs.selected_tab_index=2
        game.take_screenshot{player=player,resolution=player.display_resolution,show_gui=true,path="gate-cooldown/estimator-projections.png"}
    elseif elapsed==265 then
        local viewer=storage.ei_gate_estimator.players[player.index]
        viewer.tab=2;viewer.metrics={3,5};estimate_ui.build(player,viewer)
        game.take_screenshot{player=player,resolution=player.display_resolution,show_gui=true,path="gate-cooldown/estimator-cooldown-queue.png"}
    elseif elapsed==270 then
        local viewer=storage.ei_gate_estimator.players[player.index]
        viewer.gui.tabs.tabs[2].content.scroll_to_bottom()
        game.take_screenshot{player=player,resolution=player.display_resolution,show_gui=true,path="gate-cooldown/estimator-summary.png"}
    elseif elapsed==275 then
        local viewer=storage.ei_gate_estimator.players[player.index]
        local baseline=serpent.line(viewer.baseline,{sortkeys=true})
        estimate_ui.close(player.index)
        check(q,"estimator close releases renders and jobs",#viewer.renders==0 and not estimate_ui.has_tick_work())
        estimate_ui.open(player,q.gate.unit_number,event.tick)
        check(q,"estimator baseline survives reopen",baseline==serpent.line(viewer.baseline,{sortkeys=true}))
        estimate_ui.close(player.index)
    elseif elapsed==285 then
        estimate_ui.open(player,q.gate.unit_number,event.tick)
        local viewer=storage.ei_gate_estimator.players[player.index]
        local proof=player.gui.screen.add{type="frame",name="estimator-tooltip-proof",direction="vertical",caption="Estimator tooltips (QC)"}
        proof.location={300,120}
        for _,tooltip in ipairs{viewer.gui.fields.batch.value.tooltip,viewer.gui.hardware.tooltip,
            viewer.gui.calculations[4].tooltip,{"gate-estimator.help-assumptions"}} do
            local label=proof.add{type="label",caption=tooltip}
            label.style.single_line=false;label.style.maximal_width=600
            proof.add{type="line"}
        end
        game.take_screenshot{player=player,resolution=player.display_resolution,show_gui=true,path="gate-cooldown/estimator-tooltips.png"}
    elseif elapsed==295 then
        player.gui.screen["estimator-tooltip-proof"].destroy()
        estimate_ui.close(player.index)
    elseif elapsed==425 then
        -- Serialize an open window and unfinished projection, not only an idle draft.
        estimate_ui.open(player,q.gate.unit_number,event.tick)
        local viewer=storage.ei_gate_estimator.players[player.index]
        viewer.draft.horizon=3600;estimate_ui.build(player,viewer);estimate_ui.run(player,viewer)
        check(q,"estimator checkpoint has unfinished work",storage.ei_gate_estimator.jobs[player.index]~=nil)
        q.estimator_saved={player=player.index,value=serpent.line({viewer.draft,viewer.baseline},{sortkeys=true})}
    end
end
