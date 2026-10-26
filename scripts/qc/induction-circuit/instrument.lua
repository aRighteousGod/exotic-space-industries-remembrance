-- Staging-only fixture. Native build/open/clone/revive events use the real dispatcher.
do
    local matrix = ei_induction_matrix
    local q, player
    local loaded = false
    local configured = false
    script.on_load(function()
        if __control_ups_load then __control_ups_load() end
        loaded = storage.induction_circuit_qc ~= nil
    end)
    script.on_configuration_changed(function(event)
        assert(__control_ups_config)(event)
        configured = true
    end)
    local function check(value, label)
        q.checks = q.checks + 1
        assert(value, "INDUCTION_CIRCUIT_QC " .. label)
        q.cases[#q.cases + 1] = label
    end
    local function record(core)
        return assert(storage.ei.induction_matrix.core[core.unit_number])
    end
    local function signals(core)
        local out = {}
        local control = record(core).wire_proxy.get_control_behavior()
        for _, section in pairs(control.sections) do
            for _, filter in pairs(section.filters) do
                if filter.value then out[filter.value.name .. ":" .. (filter.value.quality or "normal")] = filter.min end
            end
        end
        return out
    end
    local function value(core, name, quality)
        return signals(core)[name .. ":" .. (quality or "normal")] or 0
    end
    local function settings(core) return matrix.copy_circuit_settings(record(core).circuit_settings) end
    local function set(core, config) matrix.set_circuit_settings(core.unit_number, config) end
    local function enabled_settings()
        local config = matrix.copy_circuit_settings()
        config.charge.enabled = true; config.capacity.enabled = true; config.max_io.enabled = true
        return config
    end
    local function scheduled(core)
        local slot = storage.ei.induction_matrix.wire_update_slots[core.unit_number % 60]
        return slot and slot[core.unit_number] == true or false
    end
    local function floor_at(x, y)
        local tiles = {}
        for tx = x-1,x+4 do for ty = y-1,y+4 do
            tiles[#tiles+1] = {name="ei-induction-matrix-tile",position={tx,ty}}
        end end
        q.surface.set_tiles(tiles)
    end
    local function make(x, y, floor)
        if floor then floor_at(x,y) end
        local core = assert(q.surface.create_entity{name="ei-induction-matrix-core-0",position={x,y},force=player.force,raise_built=true})
        if floor then
            local proxy = record(core).wire_proxy
            q.surface.create_entity{name="ei-induction-matrix-basic-coil",position={x+2.5,y+0.5},force=player.force,raise_built=true}
            matrix.update_dirty{tick=game.tick}
            core = matrix.get_core_entity(matrix.get_matrix_id(proxy))
        end
        return core
    end
    local function open(core)
        player.teleport({core.position.x,core.position.y-5},q.surface)
        player.opened = record(core).wire_proxy
        return assert(matrix.get_gui(player))
    end
    local function run_cases()
        local a, b = q.a, q.b
        local config = settings(a)
        check(not config.charge.enabled and not config.capacity.enabled and not config.max_io.enabled and not config.percent.enabled,"all four outputs default off")
        check(config.charge.signal.name=="signal-C" and config.capacity.signal.name=="signal-T"
            and config.max_io.signal.name=="signal-M" and config.percent.signal.name=="signal-A","C T M A remain preselected")
        record(b).circuit_settings=nil
        matrix.rebuild_gui_viewers()
        local legacy=settings(b)
        check(not legacy.charge.enabled and not legacy.capacity.enabled and not legacy.max_io.enabled and not legacy.percent.enabled,"missing saved settings migrate off")
        local defaults=open(a)
        local unchecked=true
        for _,key in ipairs{"charge","capacity","max_io","percent"} do
            unchecked=unchecked and not defaults.content.circuit.outputs[key]["output-enabled"].state
        end
        check(unchecked,"new GUI has all four checkboxes off")
        matrix.close_gui(player)
        check(matrix.get_matrix_capacity(a.unit_number)==25,"real coil gives 25 MJ")
        a.energy = 12375000
        local proxy=record(a).wire_proxy
        local peer=q.surface.create_entity{name="constant-combinator",position={-3,0},force=player.force}
        for _,color in ipairs{"red","green"} do
            local id=defines.wire_connector_id["circuit_"..color]
            assert(proxy.get_wire_connector(id,true).connect_to(peer.get_wire_connector(id,true)))
        end
        matrix.update_dirty{tick=game.tick}
        matrix.update_render_queue(game.tick+3600)
        local reads=0
        local getters={"get_matrix_current_stored_power","get_matrix_capacity","get_matrix_max_IO"}
        local originals={}
        for _,key in ipairs(getters) do
            local original=matrix[key];originals[key]=original
            matrix[key]=function(...) reads=reads+1;return original(...) end
        end
        matrix.update_wire_proxy_signals(a.unit_number,true)
        local idle=true
        for tick=game.tick,game.tick+59 do
            matrix.update_wire_outputs{tick=tick}
            idle=idle and not matrix.has_tick_work{tick=tick}
        end
        check(reads==0,"disabled wired matrix skips all telemetry measurements")
        check(not scheduled(a) and not scheduled(b) and idle,"closed idle matrices have no telemetry slots or tick work")
        check(not proxy.get_control_behavior().enabled and next(signals(a))==nil,"default proxy disabled with empty filters")
        config.charge.enabled=true;set(a,config)
        check(proxy.get_control_behavior().enabled and value(a,"signal-C")==12,"first enable immediately publishes unchanged energy")
        matrix.update_wire_outputs{tick=game.tick}
        check(scheduled(a) and matrix.has_tick_work{tick=a.unit_number%60},"enabled output joins telemetry schedule")
        config.charge.enabled=false;reads=0;set(a,config)
        check(reads==0 and not proxy.get_control_behavior().enabled and next(signals(a))==nil,"last disable clears filters without reading energy")
        matrix.update_wire_outputs{tick=game.tick}
        check(not scheduled(a),"last disable leaves telemetry schedule")
        for _,key in ipairs{"charge","capacity","max_io","percent"} do config[key].enabled=true;config[key].signal=nil end
        set(a,config);matrix.update_wire_outputs{tick=game.tick}
        check(reads==0 and not scheduled(a) and not proxy.get_control_behavior().enabled,"enabled empty pickers remain inactive")
        for key,original in pairs(originals) do matrix[key]=original end
        peer.destroy()
        config=enabled_settings();set(a,config)
        check(value(a,"signal-C")==12 and value(a,"signal-T")==25 and value(a,"signal-M")==1 and value(a,"signal-A")==0,"enabled preset outputs and units")
        config.percent.enabled = true; set(a,config)
        check(value(a,"signal-A")==50,"percentage uses unrounded energy")
        for _, fraction in ipairs{0,0.01,0.25,0.5,1} do
            a.energy = fraction*25000000
            matrix.update_wire_proxy_signals(a.unit_number,true)
            check(value(a,"signal-A")==math.floor(fraction*100+0.5),"percentage "..fraction)
        end
        a.energy = 10000000
        for index,key in ipairs{"charge","capacity","max_io","percent"} do
            config[key].signal = {type="virtual",name="signal-"..index,quality="normal"}
            set(a,config)
            check(value(a,"signal-"..index)>0,"remap "..key)
            config[key].enabled = false; set(a,config)
            check(value(a,"signal-"..index)==0 and settings(a)[key].signal.name=="signal-"..index,"disable retains "..key)
            config[key].enabled = true; config[key].signal = nil; set(a,config)
            check(settings(a)[key].signal==nil,"clear "..key)
            config[key].signal = {type="virtual",name="signal-X",quality="normal"}
        end
        set(a,config)
        check(value(a,"signal-X")==76,"duplicate assignments sum 10+25+1+40")
        check(matrix.to_wire_signal_value(1e20)==2147483647,"integer upper clamp")
        check(matrix.to_wire_signal_value(-1e20)==-2147483647,"integer lower clamp")
        local kinds={item="iron-plate",fluid="water",virtual="signal-V",entity="ei-induction-matrix-core-0",recipe="ei-induction-matrix-core",
            ["space-location"]="nauvis",["asteroid-chunk"]="metallic-asteroid-chunk",quality="normal"}
        for kind,name in pairs(kinds) do
            config.charge.signal={type=kind,name=name,quality="normal"};set(a,config)
            check(value(a,name)==10,"native signal type "..kind)
        end
        config.charge.signal={type="item",name="iron-plate",quality="uncommon"};set(a,config)
        check(value(a,"iron-plate","uncommon")==10,"quality preserved")
        config.capacity.signal={type="item",name="iron-plate",quality="normal"}
        config.percent.signal={type="item",name="iron-plate",quality="uncommon"};set(a,config)
        check(value(a,"iron-plate","normal")==25 and value(a,"iron-plate","uncommon")==50,
            "same item aggregates only within matching quality")
        config.charge.signal={type="virtual",name="missing-qc-signal"};set(a,config)
        check(settings(a).charge.signal==nil,"removed signal sanitized")
        config.charge.signal={type="item",name="iron-plate",quality="missing-qc-quality"};set(a,config)
        check(settings(a).charge.signal==nil,"removed quality sanitized")
        config=enabled_settings();config.percent.enabled=true;set(a,config)
        local proxy=record(a).wire_proxy
        q.peer=q.surface.create_entity{name="constant-combinator",position={-3,0},force=player.force}
        for _,color in ipairs{"red","green"} do
            local id=defines.wire_connector_id["circuit_"..color]
            check(proxy.get_wire_connector(id,true).connect_to(q.peer.get_wire_connector(id,true)),"connect "..color)
        end
        local root=open(a)
        check(player.connected and #game.connected_players>0,"actual connected player")
        check(root.content.circuit.outputs.percent["output-enabled"].state,"percentage GUI state")
        local picker=root.content.circuit.outputs.charge["output-signal"]
        picker.elem_value={type="virtual",name="signal-Z"}
        script.get_event_handler(defines.events.on_gui_elem_changed){element=picker,player_index=player.index,tick=game.tick}
        check(value(a,"signal-Z")==10 and value(a,"signal-C")==0,"picker dispatcher immediate output")
        local toggle=root.content.circuit.outputs.percent["output-enabled"]
        toggle.state=false
        script.get_event_handler(defines.events.on_gui_checked_state_changed){element=toggle,player_index=player.index,tick=game.tick}
        check(value(a,"signal-A")==0,"checkbox dispatcher immediate output")
        local tags=root.tags;tags.circuit_gui_version=nil;root.tags=tags;root.location={50,70}
        matrix.update_gui(player);root=matrix.get_gui(player)
        check(root.tags.circuit_gui_version==1 and not root.auto_center and root.location.x==50 and root.location.y==70,"legacy root rebuilt at saved position")
        b.energy=5000000
        record(b).wire_proxy.copy_settings(proxy,player)
        check(value(b,"signal-Z")==5 and settings(b).charge.signal.name=="signal-Z","paste uses destination energy")
        local native=q.peer.get_or_create_control_behavior();local group=native.add_section("matrix-qc-shared")
        group.set_slot(1,{value={type="virtual",name="signal-E",quality="normal",comparator="="},min=999})
        group.multiplier=5;group.active=false;native.add_section("matrix-qc-extra")
        record(b).wire_proxy.copy_settings(q.peer,player)
        local restored=record(b).wire_proxy.get_control_behavior()
        check(restored.sections_count==1 and restored.get_section(1).group=="" and restored.get_section(1).active and restored.get_section(1).multiplier==1,"native paste reset private section")
        check(group.get_slot(1).min==999 and group.group=="matrix-qc-shared","source shared group untouched")
        check(value(b,"signal-Z")==5 and value(b,"signal-E")==0,"ordinary paste retains matrix settings")
        local saved=settings(a)
        matrix.force_visual_update(a.unit_number,{tick=game.tick});matrix.update_dirty{tick=game.tick}
        check(settings(a).charge.signal.name==saved.charge.signal.name,"reanalyze preserves settings")
        local restore = {}
        for y=-1,4 do
            assert(player.mine_tile(q.surface.get_tile(1,y)),"Native matrix tile mining failed")
            restore[#restore+1]={name="ei-induction-matrix-tile",position={1,y}}
        end
        matrix.update_dirty{tick=game.tick}
        q.a=matrix.get_core_entity(matrix.get_matrix_id(proxy));a=q.a
        check(settings(a).charge.signal.name==saved.charge.signal.name and matrix.get_matrix_capacity(a.unit_number)==0,
            "native floor split preserves settings")
        q.surface.set_tiles(restore,false,false,false,true);matrix.update_dirty{tick=game.tick}
        q.a=matrix.get_core_entity(matrix.get_matrix_id(proxy));a=q.a
        check(settings(a).charge.signal.name==saved.charge.signal.name and matrix.get_matrix_capacity(a.unit_number)==25,
            "native floor rejoin preserves settings")
        a.energy=10000000
        q.converter=q.surface.create_entity{name="ei-induction-matrix-basic-converter",position={2,3},force=player.force,raise_built=true}
        matrix.update_dirty{tick=game.tick}
        q.a=matrix.get_core_entity(matrix.get_matrix_id(proxy));a=q.a
        check(a.name=="ei-induction-matrix-core-1" and settings(a).charge.signal.name=="signal-Z","converter upgrade settings")
        check(matrix.get_gui(player).tags.circuit_gui_version==1,"retag preserves GUI schema")
        q.converter.destroy{raise_destroy=true};matrix.update_dirty{tick=game.tick}
        q.a=matrix.get_core_entity(matrix.get_matrix_id(proxy));a=q.a
        check(a.name=="ei-induction-matrix-core-0" and settings(a).charge.signal.name=="signal-Z","converter downgrade settings")
        q.dormant=make(40,0,false);set(q.dormant,saved)
        matrix.rebuild_runtime_state("circuit-qc")
        check(settings(q.dormant).charge.signal.name=="signal-Z" and record(q.dormant).wire_proxy.valid,"dormant settings survive repair")
        local empty=settings(q.dormant);empty.percent.enabled=true;set(q.dormant,empty)
        check(value(q.dormant,"signal-A")==0,"zero-capacity percent")
        floor_at(40,0);matrix.update_core(q.dormant.unit_number,{tick=game.tick})
        check(settings(q.dormant).charge.signal.name=="signal-Z","floor completion retains settings")
        player.cursor_stack.set_stack{name="blueprint"}
        local blueprint=player.cursor_stack
        local mapping=blueprint.create_blueprint{surface=q.surface,force=player.force,area={{-1,-1},{1,1}},always_include_tiles=false}
        local count=0
        for _,entity in pairs(mapping) do if matrix.core[entity.name] then count=count+1 end end
        check(count==1,"native blueprint captures unselectable core")
        script.get_event_handler(defines.events.on_player_setup_blueprint){player_index=player.index,stack=blueprint,
            mapping={get=function() return mapping end},tick=game.tick}
        local tagged
        for _,entry in pairs(blueprint.get_blueprint_entities()) do if entry.tags and entry.tags.ei_induction_matrix then tagged=entry.tags.ei_induction_matrix end end
        check(tagged and tagged.charge.signal.name=="signal-Z","blueprint stores versioned settings")
        local ghosts=blueprint.build_blueprint{surface=q.surface,force=player.force,position={60,0},by_player=player,
            build_mode=defines.build_mode.forced}
        matrix.update_wire_outputs{tick=game.tick} -- Flush prior membership changes before native revival.
        local revived
        for _,ghost in pairs(ghosts) do
            if ghost.valid and ghost.type=="entity-ghost" and matrix.core[ghost.ghost_name] then
                local pos=ghost.position;ghost.revive{raise_revive=true}
                for _,entity in pairs(q.surface.find_entities_filtered{position=pos,type="electric-energy-interface"}) do
                    if matrix.core[entity.name] then revived=entity end
                end
            end
        end
        check(revived and settings(revived).charge.signal.name=="signal-Z","blueprint revival before floor restores settings")
        matrix.update_wire_outputs{tick=game.tick}
        check(scheduled(revived),"blueprint enabled dormant core joins telemetry schedule")
        local robot_ground={}
        for x=14,34 do for y=-36,-24 do robot_ground[#robot_ground+1]={name="grass-1",position={x,y}} end end
        q.surface.set_tiles(robot_ground)
        q.port=assert(q.surface.create_entity{name="ei-advanced-port",position={20,-30},force=player.force})
        q.port.energy=1000000000
        q.port.get_inventory(defines.inventory.roboport_robot).insert{name="ei-construction-bot",count=2}
        local provider=assert(q.surface.create_entity{name="passive-provider-chest",position={26,-30},force=player.force})
        provider.insert{name="ei-induction-matrix-core",count=1}
        blueprint.build_blueprint{surface=q.surface,force=player.force,position={30,-30},by_player=player,
            build_mode=defines.build_mode.forced}
        player.clear_cursor()
        q.clone_a=a.clone{position={80,0},surface=q.surface,force=player.force}
        local provisional=record(q.clone_a).wire_proxy
        local helper=proxy.clone{position={80,0},surface=q.surface,force=player.force}
        check(record(q.clone_a).wire_proxy==helper and not provisional.valid,"core-first clone adopts helper")
        check(settings(q.clone_a).charge.signal.name=="signal-Z","core clone settings")
        local first=proxy.clone{position={100,0},surface=q.surface,force=player.force}
        check(not first.get_control_behavior().enabled,"proxy-first clone initially muted")
        q.clone_b=a.clone{position={100,0},surface=q.surface,force=player.force}
        check(record(q.clone_b).wire_proxy==first and first.get_control_behavior().enabled,"proxy-first clone adopted")
        check(#q.surface.find_entities_filtered{position={100,0},name="ei-induction-matrix-core-circuit-interface"}==1,"one cloned proxy")
        check(settings(q.clone_b).charge.signal.name=="signal-Z","proxy-first clone settings")
        local left=make(70,-30,true)
        local right_floor={}
        for x=77,78 do for y=-31,-30 do right_floor[#right_floor+1]={name="ei-induction-matrix-tile",position={x,y}} end end
        q.surface.set_tiles(right_floor,false,false,false,true)
        local right=assert(q.surface.create_entity{name="ei-induction-matrix-core-0",position={78,-30},force=player.force,raise_built=true})
        local right_proxy=record(right).wire_proxy
        matrix.update_dirty{tick=game.tick};right=matrix.get_core_entity(matrix.get_matrix_id(right_proxy))
        local left_config=matrix.copy_circuit_settings();left_config.charge.signal.name="signal-L";set(left,left_config)
        local right_config=matrix.copy_circuit_settings();right_config.charge.signal.name="signal-R";set(right,right_config)
        local expected={[left.unit_number]="signal-L",[right.unit_number]="signal-R"}
        q.surface.set_tiles({{name="ei-induction-matrix-tile",position={75,-30}},
            {name="ei-induction-matrix-tile",position={76,-30}}},false,false,false,true)
        matrix.update_dirty{tick=game.tick}
        check(left.valid~=right.valid,"native matrix merge keeps one core")
        local survivor=left.valid and left or right
        check(settings(survivor).charge.signal.name==expected[survivor.unit_number]
            and matrix.get_matrix_capacity(survivor.unit_number)==25,"native merge retains survivor settings")
        check(matrix.get_matrix_id(record(survivor).wire_proxy)==survivor.unit_number,"merged proxy maps to survivor")
        config=settings(a);config.capacity.signal={type="virtual",name="signal-Y"};set(a,config)
        q.secondary_viewers=0
        for _,second in pairs(game.players) do
            if second.index~=player.index then
                matrix.open_gui(second,a.unit_number);matrix.update_player_guis()
                check((matrix.get_gui(second)~=nil)==second.connected,"secondary viewer membership")
                if second.connected then q.secondary_viewers=q.secondary_viewers+1 end
            end
        end
        player.opened=q.peer;matrix.update_player_guis()
        check(not matrix.get_gui(player),"unrelated entity closes matrix")
        open(q.clone_a);q.clone_a.destroy{raise_destroy=true};matrix.update_player_guis()
        check(not matrix.get_gui(player),"destroyed core closes GUI")
        open(a)
        config=enabled_settings();config.percent.enabled=true;set(a,config)
        a.energy=12500000;matrix.update_wire_proxy_signals(a.unit_number,true)
        local capacity=record(a).stats.capacity
        record(a).stats.capacity=1;matrix.update_wire_proxy_signals(a.unit_number,true)
        check(value(a,"signal-A")==100,"over-capacity percentage clamps")
        record(a).stats.capacity=capacity;matrix.update_wire_proxy_signals(a.unit_number,true)
        q.setup_done=true
    end
    local previous_robot=script.get_event_handler(defines.events.on_robot_built_entity)
    script.on_event(defines.events.on_robot_built_entity,function(event)
        previous_robot(event)
        local state=storage.induction_circuit_qc
        if state and event.entity.valid and event.entity.surface==state.surface and matrix.core[event.entity.name]
        and event.entity.position.y < -20 then
            state.robot_core=event.entity
            state.robot_tag=event.tags and event.tags.ei_induction_matrix
        end
    end)
    local previous=script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick,function(event)
        player=game.connected_players[1]
        if not player then previous(event);return end
        q=storage.induction_circuit_qc
        if not q then
            q={start=event.tick,checks=0,cases={}};storage.induction_circuit_qc=q
            q.surface=game.create_surface("matrix-circuit-qc",{width=256,height=128})
            q.surface.request_to_generate_chunks({64,0},5);q.surface.force_generate_chunk_requests()
            for _,entity in pairs(q.surface.find_entities()) do entity.destroy() end
            local tiles={};for x=-16,120 do for y=-16,20 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
            q.surface.set_tiles(tiles);q.surface.always_day=true
            q.a=make(0,0,true);q.b=make(20,0,true)
        end
        previous(event)
        if loaded then
            loaded=false
            check(settings(q.a).percent.enabled and settings(q.a).charge.signal.name=="signal-C","saved settings "..(configured and "configuration" or "ordinary"))
            local idle=settings(q.idle_save)
            check(not idle.charge.enabled and not idle.capacity.enabled and not idle.max_io.enabled and not idle.percent.enabled
                and not record(q.idle_save).wire_proxy.get_control_behavior().enabled and not scheduled(q.idle_save),
                "saved dormant matrix remains off and unscheduled")
            local removed=settings(q.b).charge.signal
            local absent=prototypes.virtual_signal["matrix-qc-removed-signal"]==nil
            check(absent and removed==nil or not absent and removed and removed.name=="matrix-qc-removed-signal",
                "removed prototype "..(absent and "sanitized" or "retained before removal"))
            open(q.a)
            check(matrix.get_gui(player).content.circuit.outputs.percent["output-enabled"].state,"saved GUI restored")
            log("INDUCTION_CIRCUIT_QC RELOAD_PASS "..(configured and "configuration" or "ordinary"))
            helpers.write_file("induction-reload.json",helpers.table_to_json{all_pass=true,configured=configured,checks=q.checks},false)
        end
        if not q.complete and event.tick-q.start==2 then run_cases() end
        local elapsed=event.tick-q.start
        if q.port and q.port.valid then q.port.energy=1000000000 end
        if q.robot_core and not q.robot_checked then
            check(q.robot_tag and q.robot_tag.charge.signal.name=="signal-Z"
                and settings(q.robot_core).charge.signal.name=="signal-Z","native robot blueprint restores dormant settings")
            floor_at(q.robot_core.position.x,q.robot_core.position.y)
            matrix.update_core(q.robot_core.unit_number,event)
            check(settings(q.robot_core).charge.signal.name=="signal-Z","robot core before floor retains settings")
            q.robot_checked=true
        end
        assert(elapsed < 900 or q.complete,"INDUCTION_CIRCUIT_QC robot placement timed out")
        if q.setup_done and not q.complete then
            local proxy=record(q.a).wire_proxy
            local red,green=defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green
            local signal={type="virtual",name="signal-C",quality="normal"}
            if elapsed==4 then
                check(q.peer.get_signal(signal,red)==value(q.a,"signal-C") and q.peer.get_signal(signal,green)==value(q.a,"signal-C"),"native red and green propagation")
                proxy.get_wire_connector(green,false).disconnect_all()
            elseif elapsed==6 then
                check(q.peer.get_signal(signal,red)>0 and q.peer.get_signal(signal,green)==0,"red-only network")
                proxy.get_wire_connector(red,false).disconnect_all()
                local config=settings(q.a);config.charge.signal={type="virtual",name="signal-Z",quality="normal"};set(q.a,config)
                check(value(q.a,"signal-C")==0 and value(q.a,"signal-Z")>0,"disconnected edit clears obsolete filters")
            elseif elapsed==8 then
                proxy.get_wire_connector(green,true).connect_to(q.peer.get_wire_connector(green,true))
            elseif elapsed==10 then
                check(q.peer.get_signal({type="virtual",name="signal-Z"},green)==value(q.a,"signal-Z"),"green-only reconnect publishes current assignment")
                q.surface.clone_area{source_area={{-5,-3},{5,5}},destination_area={{105,25},{115,33}},destination_surface=q.surface,
                    clone_tiles=true,clone_entities=true,clone_decoratives=false,clear_destination_entities=true,clear_destination_decoratives=true}
            elseif elapsed==12 then
                local proxies=q.surface.find_entities_filtered{position={110,28},name="ei-induction-matrix-core-circuit-interface"}
                check(#proxies==1,"area clone has one proxy")
                local copy=proxies[1]
                local cloned=matrix.get_core_entity(matrix.get_matrix_id(copy))
                check(cloned and settings(cloned).charge.signal.name=="signal-Z","native area clone settings")
                check(copy.get_wire_connector(green,false).real_connection_count>0,"native area clone preserves cable")
            elseif elapsed==14 then
                local duplicate=q.surface.create_entity{name="ei-induction-matrix-core-0",position={3,3},force=player.force}
                matrix.force_visual_update(q.a.unit_number,{tick=event.tick});matrix.update_dirty(event)
                check(q.a.valid and not duplicate.valid and settings(q.a).charge.signal.name=="signal-Z","duplicate resolution keeps selected survivor settings")
                proxy.get_wire_connector(red,true).connect_to(q.peer.get_wire_connector(red,true))
                local config=enabled_settings();config.percent.enabled=true;set(q.a,config)
                q.a.energy=12500000;matrix.update_wire_proxy_signals(q.a.unit_number,true)
                open(q.a)
            elseif elapsed==16 then
                q.idle_save=make(90,-10,false)
                local missing=settings(q.b)
                missing.charge.signal={type="virtual",name="matrix-qc-removed-signal",quality="normal"};set(q.b,missing)
                check(settings(q.b).charge.signal.name=="matrix-qc-removed-signal","saved mod signal selected")
                q.saved_config=settings(q.a);q.base_complete=true
            end
            if q.base_complete and q.robot_checked then
                q.complete=true
                log("INDUCTION_CIRCUIT_QC COMPLETE "..q.checks)
                helpers.write_file("induction-circuit.json",helpers.table_to_json{all_pass=true,checks=q.checks,cases=q.cases,
                    secondary_viewers=q.secondary_viewers,locale=player.locale},false)
            end
        end
        if q.complete and not q.saved and elapsed>=20 then
            q.saved=true
            game.auto_save("induction-circuit")
            log("INDUCTION_CIRCUIT_QC SAVE_REQUESTED")
        end
    end)
end
