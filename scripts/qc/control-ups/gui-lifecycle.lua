-- Staging-only connected-player fixture; entity opening uses native event routing.
do
    local black, matrix = ei_black_hole, ei_induction_matrix
    local q, player
    local loaded = false
    local configured = false
    script.on_load(function()
        if __control_ups_load then __control_ups_load() end
        loaded = storage.control_ups_gui and storage.control_ups_gui.saved or false
    end)
    script.on_configuration_changed(function(event)
        assert(__control_ups_config)(event)
        configured = true
    end)
    local function trace(kind, extra)
        if q then q.trace[#q.trace+1]={kind=kind,tick=game.tick-q.start,detail=extra} end
    end
    for _,name in ipairs({"on_gui_opened","on_gui_closed"}) do
        local id=defines.events[name]
        local handler=script.get_event_handler(id)
        script.on_event(id,function(event)
            local target=event.entity or event.element
            trace(name,{gui_type=event.gui_type,name=target and target.valid and target.name or false})
            handler(event)
        end)
    end
    for _,entry in ipairs({{black,"black"},{matrix,"matrix"}}) do
        local module,name=entry[1],entry[2]
        local original=module.update_player_guis
        module.update_player_guis=function(...)
            trace(name.."-refresh")
            return original(...)
        end
    end
    local function roots()
        return player.gui.relative["ei-black-hole-console"],player.gui.screen["ei-induction-matrix-console"]
    end
    local function snapshot(label)
        local bh,im=roots()
        local row={label=label,connected=player.connected,connected_count=#game.connected_players,
            black=bh~=nil,matrix=im~=nil,opened=player.opened and player.opened.valid and player.opened.name or false}
        if bh and bh["main-container"] then
            local status=bh["main-container"]["status-flow"]
            local control=bh["main-container"]["control-flow"]
            row.black_data={mass=status.mass.caption,power=status.power.caption,
                injectors=status.injectors.value,extractors=status.extractors.value,
                stage=control.stage.value,progress=control["stage-progress"].value}
        end
        if im and im["main-container"] then
            local info=im["main-container"]["console-flow"]
            local bar=info["capacity-flow"]["stored-power-value"]
            row.matrix_data={id=im.tags.matrix_id==q.core_a_id and "A" or im.tags.matrix_id==q.core_b_id and "B" or "other",
                transfer=info["max-et-flow"]["max-et-value"].caption,caption=bar.caption,value=bar.value,
                camera=info["camera-frame"].camera.position}
        end
        trace("snapshot",row)
        return row
    end
    local function open(entity)
        assert(entity.valid)
        player.teleport({x=entity.position.x,y=entity.position.y-7},entity.surface)
        player.opened=entity
    end
    local function orphan(kind)
        if kind=="black" then
            player.gui.relative.add{type="frame",name="ei-black-hole-console",anchor={gui=defines.relative_gui_type.container_gui,name="ei-black-hole",position=defines.relative_gui_position.right}}
        else player.gui.screen.add{type="frame",name="ei-induction-matrix-console"} end
    end
    local function guard_profile(kind)
        local iterations=50000
        for repetition=1,6 do
            for _,entry in ipairs({{black,"black"},{matrix,"matrix"}}) do
                local module,name=entry[1],entry[2]
                -- Explicit off-cadence input for the GUI-only predicate cost.
                local event={tick=math.floor(game.tick/30)*30+1}
                local profiler=game.create_profiler()
                local positives=0
                for _=1,iterations do if module.has_tick_work(event) then positives=positives+1 end end
                profiler.stop()
                log({"","CONTROL_UPS_GUI_PROFILE ",kind," ",name," ",repetition," ",iterations," ",positives," ",profiler})
            end
        end
    end
    local function setup(tick)
        player.opened=nil
        black.close_gui(player);matrix.close_gui(player)
        local surface=game.create_surface("control-ups-gui",{width=160,height=160})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        local tiles={}
        for x=-64,64 do for y=-64,64 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        q={start=tick,surface=surface,trace={},entities={},player=player.index}
        storage.control_ups_gui=q
        local function make(label,name,x,y)
            q.entities[label]=assert(surface.create_entity{name=name,position={x,y},force=player.force,raise_built=true})
            return q.entities[label]
        end
        make("black_a","ei-black-hole",0,0);make("black_b","ei-black-hole",40,0)
        local ca=make("core_a","ei-induction-matrix-core-0",0,40)
        local cb=make("core_b","ei-induction-matrix-core-0",40,40)
        q.core_a_id=ca.unit_number;q.core_b_id=cb.unit_number
        q.entities.proxy_a=assert(storage.ei.induction_matrix.core[ca.unit_number].wire_proxy)
        q.entities.proxy_b=assert(storage.ei.induction_matrix.core[cb.unit_number].wire_proxy)
        snapshot("connected-setup")
    end
    local previous=script.get_event_handler(defines.events.on_tick)
    local waited=0
    script.on_event(defines.events.on_tick,function(event)
        player=game.connected_players[1]
        if not player then
            waited=waited+1
            assert(waited<120,"GUI fixture requires an actual connected player")
            previous(event);return
        end
        assert(player.connected)
        if not storage.control_ups_gui and event.tick%30~=0 then previous(event);return end
        if not storage.control_ups_gui then setup(event.tick) else q=storage.control_ups_gui end
        local r=event.tick-q.start
        if loaded and not q.reloaded then
            q.reloaded=true;q.reload_kind=configured and "configuration" or "ordinary"
            assert(r==332,"unexpected GUI save/reload tick: "..r)
            assert(ei_lib.entity_check(q.entities.black_a),"saved black hole reference lost")
            assert(storage.ei.black_hole[q.entities.black_a.unit_number],"black-hole registry missing after reload/repair")
            snapshot("reload-"..q.reload_kind)
        end
        local e=q.entities
        if r==1 then open(e.black_a);assert(select(1,roots()));snapshot("black-open-A") end
        if r==32 then open(e.black_b);snapshot("black-retarget-B") end
        if r==63 then player.opened=nil;assert(not select(1,roots()));snapshot("black-close") end
        if r==64 then open(e.black_b) end
        if r==65 then e.black_b.destroy{raise_destroy=true};snapshot("black-destroy") end
        if r==96 then assert(not select(1,roots()));open(e.proxy_a);assert(select(2,roots()));snapshot("matrix-open-A") end
        if r==127 then open(e.proxy_b);snapshot("matrix-retarget-B") end
        if r==158 then player.opened=nil;assert(not select(2,roots()));open(e.proxy_a);matrix.retag_matrix_guis(q.core_a_id,q.core_b_id);assert(select(2,roots()).tags.matrix_id==q.core_b_id);snapshot("matrix-retag-B") end
        if r==189 then player.opened=nil;open(e.proxy_b);e.core_b.destroy{raise_destroy=true};snapshot("matrix-core-destroy") end
        if r==220 then
            player.opened=nil;open(e.proxy_a)
            e.core_a.surface.set_tiles({
                {name="ei-induction-matrix-tile",position={-1,39}},
                {name="ei-induction-matrix-tile",position={0,39}},
                {name="ei-induction-matrix-tile",position={-1,40}},
                {name="ei-induction-matrix-tile",position={0,40}}})
            local repaired=matrix.rebuild_runtime_state("control-ups-gui")
            assert(repaired.rebuilt_matrices>=1 and e.core_a.valid and e.proxy_a.valid)
            assert(storage.ei.induction_matrix.core[q.core_a_id])
            assert(storage.ei.induction_matrix.proxy[e.proxy_a.unit_number]==q.core_a_id)
            snapshot("matrix-explicit-repair")
        end
        if r==251 then
            player.opened=nil;black.close_gui(player);matrix.close_gui(player)
            q.saved_black=storage.ei.black_hole;q.saved_matrix=storage.ei.induction_matrix
            storage.ei.black_hole={};storage.ei.induction_matrix={}
            guard_profile("no-root")
            orphan("black");guard_profile("black-orphan");black.close_gui(player)
            orphan("matrix");guard_profile("matrix-orphan");matrix.close_gui(player)
            local unrelated=player.gui.screen.add{type="frame",name="control-ups-unrelated"}
            guard_profile("unrelated-root");unrelated.destroy()
        end
        if r>=252 and not q.orphan_tick and event.tick%30==1 then
            q.orphan_tick=event.tick
            orphan("black");orphan("matrix");snapshot("orphans-created")
        end
        previous(event)
        if r<=250 and (event.tick%15==0 or r==2 or r==33) then snapshot("cadence") end
        if q.orphan_tick and not q.orphans_done then
            local bh,im=roots()
            local elapsed=event.tick-q.orphan_tick
            assert((im~=nil)==(elapsed<14),"matrix orphan closure tick changed")
            assert((bh~=nil)==(elapsed<29),"black orphan closure tick changed")
            snapshot("orphan-tick")
            if elapsed==29 then
                q.orphans_done=true
                storage.ei.black_hole=q.saved_black;storage.ei.induction_matrix=q.saved_matrix
                q.saved_black=nil;q.saved_matrix=nil
            end
        end
        if r==331 then
            assert(q.orphans_done)
            open(e.black_a);snapshot("pre-save-open")
            q.saved=true
            game.auto_save("control-ups-gui")
            log("CONTROL_UPS_GUI SAVE_REQUEST")
        end
        if r==375 then
            snapshot("final")
            helpers.write_file("control-ups-gui.json",helpers.table_to_json({complete=true,reload_kind=q.reload_kind,trace=q.trace}),false)
            log("CONTROL_UPS_GUI ALL_COMPLETE")
        end
    end)
end
