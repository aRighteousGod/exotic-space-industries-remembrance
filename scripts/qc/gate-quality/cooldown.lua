-- Private gate fixture: supplied-clock boundaries, native inserters and saved cooldowns.
local function cooldown_start(q,event,check)
    local model=ei_gate
    local surface=q.container.surface
    local container=assert(surface.create_entity{name="ei-gate-container",position={-24,-24},force="player"})
    model.make_gate(container,event)
    local gate=assert(surface.find_entity("ei-gate",container.position))
    local g=storage.ei.gate.gate[gate.unit_number]
    local receiver=q.receivers[1]
    local destination=storage.ei.gate.receiver[receiver.unit_number]
    local source=container.get_inventory(defines.inventory.chest)
    g.manual_enabled=true;gate.energy=1e12
    model.set_manual_receiver(gate.unit_number,destination.effective_id,event)
    model.refresh_gate_live_state(gate,event)
    check(q,"ready input open",source.get_bar()==#source+1)
    source.insert{name="iron-plate",count=10}
    g.residue_progress=249
    model.apply_transfer_penalties(gate,g,destination,{burden=4,stress_delta=0,residue_delta=1},event)
    check(q,"penalties lock in same callback",source.get_bar()<=1)
    check(q,"residue placed before locking",source.get_item_count("ei-breach-residue")==1)
    check(q,"existing cargo preserved",source.get_item_count("iron-plate")==10)
    check(q,"locked cargo removable",source.remove{name="iron-plate",count=1}==1)
    source.clear()

    -- Isolate clock boundaries from the live scheduler without mutating game time.
    g.cooldown_until_tick=61
    for _,row in ipairs{{0,"1.1"},{1,"1.0"},{55,"0.1"},{60,"0.1"}} do
        local data=model.get_data(gate,{tick=row[1]})
        check(q,"countdown at tick "..row[1],data.runtime_status_mode=="cooling" and data.cooldown_remaining_text==row[2])
        model.update_input_lock(gate,g,{tick=row[1]})
        check(q,"locked at tick "..row[1],source.get_bar()<=1)
    end
    local a=model.get_data(gate,{tick=1})
    local b=model.get_data(gate,{tick=7})
    check(q,"countdown invalidates projection",a.gui_projection_signature~=b.gui_projection_signature)
    g.stress=80
    check(q,"cooling precedes critical",model.get_data(gate,{tick=60}).runtime_status_mode=="cooling")
    check(q,"expiry restores critical",model.get_data(gate,{tick=61}).runtime_status_mode=="critical")
    g.stress=0
    for _,tick in ipairs{61,70} do
        local data=model.get_data(gate,{tick=tick})
        check(q,"expired countdown absent "..tick,data.runtime_status_mode=="stable" and data.cooldown_remaining_text==nil)
        model.update_input_lock(gate,g,{tick=tick})
        check(q,"open after expiry "..tick,source.get_bar()==#source+1)
    end
    for _,reason in ipairs{"disabled","unpowered","unresolved"} do
        g.effective_enabled=reason~="disabled"
        gate.energy=reason=="unpowered" and 0 or 1e12
        g.effective_target_entity=reason~="unresolved" and receiver or nil
        model.update_input_lock(gate,g,{tick=61})
        check(q,"inactive after expiry "..reason,source.get_bar()<=1)
        g.cooldown_until_tick=event.tick+60
        check(q,"countdown survives "..reason,model.get_data(gate,event).runtime_status_mode=="cooling")
        g.cooldown_until_tick=61
    end
    g.effective_enabled=true;gate.energy=1e12;g.effective_target_entity=receiver
    destination.saturation=100
    model.update_input_lock(gate,g,{tick=61})
    check(q,"saturation alone permits buffering",source.get_bar()==#source+1)
    destination.saturation=0

    -- Real powered inserter, with cargo already in hand, attempts a partially filled slot.
    source[1].set_stack{name="iron-plate",count=10}
    local inserter=assert(surface.create_entity{name="fast-inserter",position={-30,-24},direction=defines.direction.west,force="player"})
    inserter.held_stack.set_stack{name="iron-plate",count=1}
    inserter.energy=1e6
    g.cooldown_until_tick=event.tick+240
    model.update_input_lock(gate,g,event)
    -- An older save could have a cooling gate with an open bar and matching old cache.
    source.set_bar(#source+1);g.last_input_bar=#source+1
    model.rebuild_runtime_state("cooldown-qc",event)
    check(q,"configuration repair closes legacy cooling input",source.get_bar()<=1)
    check(q,"configuration repair retains cooldown deadline",g.cooldown_until_tick==event.tick+240)
    q.cooldown={gate=gate,container=container,inserter=inserter,start=event.tick,deadline=g.cooldown_until_tick}
    local player=game.players[1]
    if player then
        player.teleport({-24,-16},surface);player.opened=container;model.open_gui(player,event)
        local gui=assert(model.get_gui_elements(player))
        -- Reproduce a saved console whose cached Runtime label still lives beside the camera.
        local old_root=gui.root
        local caption,tooltip=gui.runtime.caption,gui.runtime.tooltip
        gui.runtime.destroy()
        gui.runtime=old_root["main-container"]["control-flow"]["target-flow"].add{
            type="label",name="runtime-state",caption=caption,tooltip=tooltip}
        model.open_gui(player,event)
        gui=assert(model.get_gui_elements(player))
        check(q,"legacy runtime column rebuilt",not old_root.valid and gui.runtime.parent.name=="status-flow")
        local first=model.get_data(gate,event)
        model.update_gui(player,first,true,gate,gui)
        local next_data=model.get_data(gate,{tick=event.tick+6})
        model.update_gui(player,next_data,true,gate,gui)
        check(q,"native countdown caption refresh",gui.runtime.caption[2][2]==next_data.cooldown_remaining_text)
        model.close_gui(player);model.open_gui(player,event)
        check(q,"reopened countdown caption",model.get_gui_elements(player).runtime.caption[2][2]==first.cooldown_remaining_text)
        model.update_gui(player,model.get_data(gate,{tick=g.cooldown_until_tick}),true,gate)
        check(q,"native expired stable caption",model.get_gui_elements(player).runtime.caption[2][1]=="exotic-industries.gate-gui-runtime-stable")
        g.stress=80
        model.update_gui(player,model.get_data(gate,{tick=g.cooldown_until_tick}),true,gate)
        check(q,"native expired critical caption",model.get_gui_elements(player).runtime.caption[2][1]=="exotic-industries.gate-gui-runtime-critical")
        g.stress=0
        model.update_gui(player,first,true,gate)
    end
end

local function cooldown_restore(q,event,check)
    local s=assert(q.cooldown,"Missing saved cooldown fixture")
    local g=storage.ei.gate.gate[s.gate.unit_number]
    local inv=s.container.get_inventory(defines.inventory.chest)
    check(q,"saved cooldown deadline preserved",g.cooldown_until_tick==s.deadline and s.deadline>event.tick)
    check(q,"saved cooldown lock preserved",inv.get_bar()<=1)
    check(q,"saved cooldown cargo preserved",inv.get_item_count("iron-plate")==10)
    local data=ei_gate.get_data(s.gate,event)
    check(q,"saved countdown derives from deadline",data.cooldown_remaining_text==string.format("%.1f",math.ceil((s.deadline-event.tick)/6)/10))
end

local function cooldown_step(q,event,check)
    local s=q.cooldown
    if not s then return false end
    if s.finished then return true end
    local g=storage.ei.gate.gate[s.gate.unit_number]
    local source=s.container.get_inventory(defines.inventory.chest)
    local elapsed=event.tick-s.start
    s.inserter.energy=1e6
    if elapsed==30 then
        check(q,"real inserter targets sender",s.inserter.drop_target==s.container)
        local player=game.players[1]
        if player then
            player.teleport({-24,-16},s.container.surface)
            player.opened=s.container;ei_gate.open_gui(player,event)
            game.take_screenshot{player=player,surface=s.container.surface,position=s.container.position,
                resolution={1920,1080},show_gui=true,path="gate-cooldown/cooling.png"}
        end
    elseif elapsed==60 then
        local player=game.players[1]
        if player then
            player.opened=s.container;ei_gate.open_gui(player,event)
            -- Render the actual localized tooltip text in a bounded proof panel. This
            -- checks wrapping/readability without claiming native mouse-hover coverage.
            local gui=assert(ei_gate.get_gui_elements(player))
            local proof=player.gui.screen.add{type="frame",name="gate-tooltip-proof",direction="vertical",caption="Runtime tooltip (QC)"}
            proof.location={20,250}
            local label=proof.add{type="label",caption=gui.runtime.tooltip}
            label.style.single_line=false;label.style.maximal_width=480
            game.take_screenshot{player=player,surface=s.container.surface,position=s.container.position,
                resolution={1920,1080},show_gui=true,path="gate-cooldown/tooltip-text.png"}
        end
    elseif elapsed==65 then
        local player=game.players[1]
        if player and player.gui.screen["gate-tooltip-proof"] then player.gui.screen["gate-tooltip-proof"].destroy() end
    elseif elapsed==80 or elapsed==90 or elapsed==100 or elapsed==110 or elapsed==120 then
        local player=game.players[1]
        if player then
            player.opened=s.container;ei_gate.open_gui(player,event)
            -- Render controlled views without changing transport state. Hold automatic GUI
            -- projection until the screenshot is rendered; the normal gate service still runs.
            local saved_deadline,saved_stress=g.cooldown_until_tick,g.stress
            local remaining=({[80]=0,[90]=6000,[100]=5994,[110]=594,[120]=0})[elapsed]
            g.cooldown_until_tick=event.tick+remaining
            g.stress=elapsed==120 and 80 or 0
            local data=ei_gate.get_data(s.gate,event)
            g.cooldown_until_tick=saved_deadline;g.stress=saved_stress
            ei_gate.update_gui(player,data,true,s.gate)
            storage.ei.gate.open_gui_players[player.index]=nil
            local name=({[80]="stable",[90]="100-seconds",[100]="99-seconds",[110]="9-seconds",[120]="critical"})[elapsed]
            game.take_screenshot{player=player,surface=s.container.surface,position=s.container.position,
                resolution={1920,1080},show_gui=true,path="gate-cooldown/layout-"..name..".png"}
        end
    elseif elapsed==125 then
        local player=game.players[1]
        if player then player.opened=s.container;ei_gate.open_gui(player,event) end
    elseif elapsed==180 then
        check(q,"native inserter cannot fill partial stack during cooldown",source.get_item_count("iron-plate")==10 and s.inserter.held_stack.valid_for_read)
        check(q,"native cooldown bar still closed",source.get_bar()<=1)
        check(q,"native cargo can be removed",source.remove{name="iron-plate",count=1}==1)
        source[1].set_stack{name="iron-plate",count=10}
        -- A full receiver prevents another transfer/cooldown after expiry. Saturation decays
        -- during native service and cannot serve as a fixed negative control here.
        local target=q.receivers[1].get_inventory(defines.inventory.chest)
        for slot=1,#target do target[slot].set_stack{name="stone",count=prototypes.item.stone.stack_size} end
    elseif elapsed==420 then
        check(q,"native input reopens after expiry",source.get_bar()==#source+1)
        check(q,"same inserter deposits after expiry",source.get_item_count("iron-plate")==11 and not s.inserter.held_stack.valid_for_read)
        s.inserter.destroy()
        source.clear();source[1].set_stack{name="iron-plate",count=10}
        -- Preserve a long live cooldown through the checkpoint and both save-backed phases.
        g.cooldown_until_tick=event.tick+1800;s.deadline=g.cooldown_until_tick
        ei_gate.update_input_lock(s.gate,g,event)
        local player=game.players[1]
        if player then
            player.opened=s.container;ei_gate.open_gui(player,event)
            game.take_screenshot{player=player,surface=s.container.surface,position=s.container.position,
                resolution={1920,1080},show_gui=true,path="gate-cooldown/checkpoint.png"}
        end
        s.finished=true
    end
    return s.finished==true
end
