-- Appended only to a private full ESIR copy; delegates to the original injection.
local passage=require("scripts/control/factory-passage")
local fusion=require("scripts/control/fusion-reactor")
local vat=require("scripts/control/auric-inoculation-vat")
local collector=require("scripts/control/neutron-collector")
local scheduler=require("lib/runtime-scheduler")
local admin=require("scripts/control/admin-tools")
local gui=require("scripts/control/admin/gui")
local module={}
local function root() return storage.ei.observer_writer_qc end
local function check(value,name)
    local q=root();q.checks[#q.checks+1]={name=name,passed=not not value};assert(value,"Observer writer QC: "..name)
end
local function recipe(entity) local r=entity.get_recipe();return r and r.name end
function module.configure(original)
    for name,owner in pairs{fusion=fusion,vat=vat,collector=collector} do
        owner.set_recipe_change_handler(function(entity,tick)
            original(entity,tick)
            local q=root()
            if q then
                q.callbacks[#q.callbacks+1]={owner=name,case=q.case,unit=entity.unit_number,recipe=recipe(entity),tick=tick,
                    queued=storage.ei.factory_passage.dirty.queued[entity.unit_number] or false}
                check(tick==game.tick,"callback preserves supplied native tick")
            end
        end)
    end
    local previous=script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick,function(e) previous(e);module.tick(e) end)
end
local function written(entity,case,fluid)
    for _,row in ipairs(root().callbacks) do
        if row.unit==entity.unit_number and row.case==case then check(not fluid or row.queued,"fluid writer queues deferred passage reconciliation: "..case);return end
    end
    error("No recipe callback for "..case)
end
local function build(s,name,x,y) return assert(s.create_entity{name=name,position={x,y},force="player",snap_to_grid=false}) end
local function pipe(s,x,y) local p=build(s,"pipe",x,y);passage.refresh_entity(p,game.tick,true);return p end
local function setup(player)
    storage.ei.observer_writer_qc={started=game.tick,checks={},callbacks={},case="setup"}
    local q=root();local s=game.create_surface("observer-writers",{width=320,height=128,water="none"})
    s.set_property("pressure",2000);s.request_to_generate_chunks({60,0},6);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities()) do e.destroy() end
    local tiles={};for x=-16,145 do for y=-16,16 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;s.set_tiles(tiles)
    tiles={};for n=0,23 do tiles[#tiles+1]={name="wetland-light-green-slime",position={86+n%10,-8+math.floor(n/10)}} end;s.set_tiles(tiles)
    q.surface=s.index;player.teleport({15,15},s);player.opened=nil
    q.fusion=build(s,"ei-fusion-reactor",0,0);pipe(s,6,0)
    q.case="fusion-build";fusion.on_built_entity(q.fusion,{tick=game.tick});written(q.fusion,q.case,true)
    q.second=build(s,"ei-fusion-reactor",40,0);pipe(s,46,0)
    q.case="fusion-rebuild";fusion.rebuild_runtime_state(q.case,game.tick);written(q.second,q.case,true)
    local entry=storage.ei.fusion_reactor.reactors_by_unit[q.fusion.unit_number]
    entry.manual_selection={fuel_1="ei-heated-deuterium",fuel_2="ei-heated-tritium",temperature="low",injection_rate="high"};entry.control_source="manual"
    q.case="fusion-manual";fusion.update(1000,{tick=game.tick});written(q.fusion,q.case,true)
    check(recipe(q.fusion)=="ei-fusion-F1__ei-heated-deuterium-F2__ei-heated-tritium-TM__low-FM__high","manual selection changes actual fusion recipe")
    local count=#q.callbacks;fusion.update(1000,{tick=game.tick});check(#q.callbacks==count,"unchanged fusion selection sends no notification")
    q.source=build(s,"constant-combinator",-7,0)
    q.source.get_or_create_control_behavior().add_section().set_slot(1,{value={type="virtual",name="ei-fusion-set-injection",quality="normal"},min=1})
    assert(q.source.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(q.fusion.get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.player))
    q.vat=build(s,"ei-auric-inoculation-vat",80,0);pipe(s,83,-1)
    q.case="vat-register";vat.on_built_entity{entity=q.vat,tick=game.tick}
    local runtime=storage.ei.auric_inoculation_vat;local record=runtime.vats_by_unit[q.vat.unit_number]
    check(record.claim_valid and record.basin_size==24 and record.band_key=="b1","native vat has valid 24-tile basin")
    record.phase="bloom";runtime.due_tick_by_unit[record.unit_number]=game.tick
    if scheduler.queue_push_unique(runtime.ready_queue,record.unit_number) then runtime.ready_queue_count=runtime.ready_queue_count+1 end
    q.case="vat-phase";vat.update(1,{tick=game.tick});written(q.vat,q.case,true)
    check(recipe(q.vat)=="ei-auric-vat-bloom","vat phase changes native recipe")
    q.collector=build(s,"ei-neutron-collector",120,20)
    q.case="collector";collector.update_neutron_collector(q.collector,nil,false,{tick=game.tick});written(q.collector,q.case,false)
    check(recipe(q.collector)=="ei-neutron-collector-idle" and not storage.ei.factory_passage.endpoints[q.collector.unit_number],"collector write notifies but fluid-less body creates no endpoint")
end
function module.tick(e)
    local player=game.connected_players[1];if not player then return end
    if not root() then setup(player);return end
    local q=root();if q.finished then return end
    local age=e.tick-q.started
    if age==10 then
        local entry=storage.ei.fusion_reactor.reactors_by_unit[q.fusion.unit_number]
        entry.control_source="circuit";q.case="fusion-circuit";fusion.update(1000,e);written(q.fusion,q.case,true)
        check(entry.effective_selection.injection_rate=="low","native signal drives ESIR scripted recipe selection")
    elseif age==20 then
        check(passage.status().watchers==0,"scripted fluid writers need no permanent observers")
        check(passage.status().dirty==0 and passage.status().pending==0,"explicit recipe notifications drain")
        local s=game.surfaces[q.surface];local c=build(s,"ei-passage-qc-crafter",120.5,.5);c.set_recipe("ei-passage-qc-fluid-recipe")
        c.get_or_create_control_behavior().circuit_set_recipe=true;pipe(s,119.5,-1.5)
    elseif age==30 then
        check(passage.status().circuit_watchers==1,"administration fixture has one native circuit observer")
        player.admin=true;admin.open(player,"diagnostics",e.tick)
        local session=storage.ei.admin_tools.sessions[player.index];session.module_id="factory-passage";session.root.location={x=100,y=10};gui.refresh(player.index,e.tick)
    elseif age==33 then
        local session=storage.ei.admin_tools.sessions[player.index]
        session.diagnostics.detail.scroll_to_element(session.diagnostics.values.fields,"top-third")
    elseif age==36 then
        local path="factory-passage/observer-administration.png"
        game.take_screenshot{player=player,resolution={1440,1080},path=path,show_gui=true,force_render=true}
        q.frames={{path=path,scene="observer-administration",tick=e.tick}}
    elseif age==38 then
        local session=storage.ei.admin_tools.sessions[player.index]
        session.diagnostics.detail.scroll_to_bottom()
    elseif age==41 then
        local path="factory-passage/observer-scanner-counts.png"
        game.take_screenshot{player=player,resolution={1440,1080},path=path,show_gui=true,force_render=true}
        q.frames[#q.frames+1]={path=path,scene="scanner-counts",tick=e.tick}
    elseif age==45 then
        admin.open(player,"options",e.tick)
        local session=storage.ei.admin_tools.sessions[player.index]
        for index,group in pairs(session.options.group_ids) do
            if group=="performance" then session.options.category.selected_index=index end
        end
        admin.on_gui_change{player_index=player.index,element=session.options.category,tick=e.tick}
        check(session.options.rows["ei-factory-passage-circuit-scanner-enabled"].value.state
            ==settings.global["ei-factory-passage-circuit-scanner-enabled"].value,"rendered scanner toggle uses native value")
        check(session.options.rows["ei-factory-passage-circuit-scan-budget"].value.text=="1","rendered scanner budget defaults to one")
    elseif age==48 then
        local pane=storage.ei.admin_tools.sessions[player.index].options.body.parent
        while pane and pane.type~="scroll-pane" do pane=pane.parent end
        pane.scroll_to_bottom()
    elseif age==52 then
        local path="factory-passage/observer-scanner-settings.png"
        game.take_screenshot{player=player,resolution={1440,1080},path=path,show_gui=true,force_render=true}
        q.frames[#q.frames+1]={path=path,scene="scanner-settings",tick=e.tick}
    elseif age==56 then
        q.finished=true
        helpers.write_file("factory-passage/observer-writers.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,
            checks=q.checks,callbacks=q.callbacks,status=passage.status(),frames=q.frames},false)
    end
end
return module
