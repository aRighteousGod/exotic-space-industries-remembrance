"""Private actual-owner runtime adapters; production event registration stays intact."""
import json
import re
from pathlib import Path
from adapters import read, write, replace, append_main, capture_init

PREFIX='''local support=require("__esir-qc-native-tests__.support")
local phase=support.phase()
local native_result,native_checks=nil,{}
local function record(name,value,detail)
 native_checks[#native_checks+1]={name=name,passed=not not value,detail=detail and tostring(detail)}
 assert(value,name)
end
'''

QUEUE='''local scheduler=require("lib/runtime-scheduler")
local function queue_checks(tick)
 local q=scheduler.ensure_queue()
 record("queue-empty",scheduler.queue_peek(q)==nil and scheduler.queue_length(q)==0)
 record("unique-admit",scheduler.queue_push_unique(q,"a")==true)
 record("unique-deduplicate",scheduler.queue_push_unique(q,"a")==false)
 scheduler.queue_push_unique(q,"b");scheduler.queue_push_unique(q,"c");q.queued.b=nil
 record("queued-first",scheduler.queue_pop_queued(q)=="a")
 record("queued-skips-tombstone",scheduler.queue_pop_queued(q)=="c")
 record("queued-empty",scheduler.queue_pop_queued(q)==nil and scheduler.queue_item_count(q)==0)
 record("unique-readmit",scheduler.queue_push_unique(q,"a")==true)
 scheduler.queue_push(q,"tail");record("peek-last",scheduler.queue_peek_last(q)=="tail")
 record("remove-preserves-tail",scheduler.queue_remove_value(q,"a") and scheduler.queue_pop(q)=="tail")
 scheduler.clear_queue(q);record("clear-membership",scheduler.queue_length(q)==0 and next(q.queued)==nil)
 local b={};scheduler.delayed_schedule(b,20,"later");scheduler.delayed_schedule(b,0,"zero")
 scheduler.delayed_schedule(b,10,"a");scheduler.delayed_schedule(b,10,"b")
 record("delayed-earliest-zero",scheduler.delayed_next_due_tick(b)==0)
 local due=scheduler.delayed_take_due_through(b,10)
 record("delayed-ordered-catchup",table.concat(due,",")=="zero,a,b" and scheduler.delayed_item_count(b)==1)
 record("delayed-exact-empty",#scheduler.delayed_take_due(b,19)==0)
 record("delayed-exact-final",scheduler.delayed_take_due(b,20)[1]=="later" and scheduler.delayed_next_due_tick(b)==false)
 scheduler.bump_counter("esir-native","observed",1,0)
 record("counter-zero",scheduler.ensure_module_state("esir-native").last_tick==0)
 scheduler.set_module_status("esir-native",{case="event-tick"},tick+10000)
 record("status-supplied-tick",scheduler.status_snapshot(nil,tick+10000).tick==tick+10000)
 local deadlines=scheduler.ensure_deadline_queue()
 scheduler.deadline_put(deadlines,9,60);scheduler.deadline_put(deadlines,3,60);scheduler.deadline_put(deadlines,5,100)
 record("deadline-future-idle",scheduler.deadline_pop_due(deadlines,59)==nil)
 record("deadline-numeric-tie",scheduler.deadline_pop_due(deadlines,60)==3)
 scheduler.deadline_put(deadlines,5,0)
 record("deadline-upsert-zero",scheduler.deadline_count(deadlines)==2 and scheduler.deadline_pop_due(deadlines,0)==5)
 record("deadline-remove",scheduler.deadline_remove(deadlines,9) and scheduler.deadline_count(deadlines)==0)
 record("deadline-empty",scheduler.deadline_peek(deadlines)==nil)
end
remote.add_interface("esir-native-tests",{step=function(tick)
 if native_result then return native_result end
 if not native_clock_done or not native_event_done then return {complete=false} end
 if phase=="candidate" then
  local s={queue=scheduler.ensure_queue(),buckets={},deadlines=scheduler.ensure_deadline_queue(),marker="native-queue-v1"}
  scheduler.deadline_put(s.deadlines,19,60);scheduler.deadline_put(s.deadlines,7,60)
  scheduler.queue_push_unique(s.queue,"persist-a");scheduler.queue_push_unique(s.queue,"persist-b")
  scheduler.delayed_schedule(s.buckets,123,"persist-due");storage.esir_native_scheduler=s
 else
  local s=assert(storage.esir_native_scheduler,"Missing serialized queue")
  record("persisted-queue-marker",s.marker=="native-queue-v1")
  record("persisted-unique-membership",s.queue.queued["persist-a"] and s.queue.queued["persist-b"])
  record("persisted-fifo",scheduler.queue_peek(s.queue)=="persist-a" and scheduler.queue_peek_last(s.queue)=="persist-b")
  record("persisted-delayed-bucket",scheduler.delayed_next_due_tick(s.buckets)==123 and scheduler.delayed_item_count(s.buckets)==1)
  record("persisted-deadline-order",scheduler.deadline_peek(s.deadlines)==7 and scheduler.deadline_count(s.deadlines)==2)
  record("persisted-deadline-index",s.deadlines.indices[7]==1 and s.deadlines.nodes[1].due==60)
 end
 queue_checks(tick);native_result={complete=true,checks=native_checks};return native_result
end})
'''


def scheduler(repo,main,helper):
    exports=json.loads(read(repo/'scripts/qc/event-tick/exports.json'))
    for name,export in exports.items():
        path=main/('scripts/control/'+name+'.lua');text=read(path)
        index=text.rfind('return model');assert index>=0
        write(path,text[:index]+export+'\n'+text[index:])
    clock=read(repo/'scripts/qc/runtime-contracts/scheduler.lua')
    clock=replace(clock,'            checks[#checks + 1] = {name = name, pass = condition == true}',
        '            checks[#checks + 1] = {name = name, pass = condition == true}\n            record("controlled-clock-"..name,condition)')
    marker='        log("RUNTIME_CONTRACTS mode=scheduler COMPLETE checks=" .. #checks)'
    clock=replace(clock,marker,marker+'\n        native_clock_done=true')
    event=read(repo/'scripts/qc/event-tick/bridge.lua')
    event=replace(event,'    if event.tick ~= 1 then return end','    if native_event_done then return end')
    event=replace(event,'        checks = checks + 1','        checks = checks + 1\n        record("controlled-event-"..name,condition)')
    event=replace(event,'    log("EVENT_TICK ALL_COMPLETE checks=" .. checks)','    log("EVENT_TICK ALL_COMPLETE checks=" .. checks)\n    native_event_done=true')
    append_main(main,PREFIX+'local native_clock_done,native_event_done=false,false\n'+clock+'\n'+event+'\n'+QUEUE)
    return {'evidence':'Controlled clock/handler probes plus native entity and serialized queue contracts'}


def induction(repo,main,helper):
    source=repo/'scripts/qc/induction-circuit';body=read(source/'instrument.lua')
    start=body.index('    local loaded = false');end=body.index('    local function check',start)
    body=body[:start]+'''    local loaded=phase~="candidate"
    local configured=phase=="configuration"
'''+body[end:]
    body=replace(body,'        q.checks = q.checks + 1','        q.checks = q.checks + 1\n        native_checks[#native_checks+1]={name=label,passed=not not value}')
    body=body.replace('state and event.entity.valid','state and event.entity and event.entity.valid')
    body=replace(body,'        if not q then','        if loaded then assert(q,"Missing saved induction fixture") end\n        if not q then')
    marker='            helpers.write_file("induction-reload.json",helpers.table_to_json{all_pass=true,configured=configured,checks=q.checks},false)'
    body=replace(body,marker,marker+'\n            native_result={complete=true,checks=native_checks};return')
    marker='                    secondary_viewers=q.secondary_viewers,locale=player.locale},false)'
    body=replace(body,marker,marker+'\n                native_result={complete=true,checks=native_checks}')
    save='''        if q.complete and not q.saved and elapsed>=20 then
            q.saved=true
            game.auto_save("induction-circuit")
            log("INDUCTION_CIRCUIT_QC SAVE_REQUESTED")
        end'''
    body=replace(body,save,'        -- Common driver owns checkpoint production.')
    append_main(main,PREFIX+'remote.add_interface("esir-native-tests",{poll=function() return native_result or {complete=false} end})\n'+body)
    data=read(source/'data-final-fixes.lua').replace('mods["zzz-esir-induction-circuit-qc"]','mods["esir-qc-native-tests"]')
    write(helper/'data-final-fixes.lua',data)
    return {'evidence':'Native GUI elements/circuits and lifecycle; programmatic GUI callbacks and explicit mapping/capacity probes'}


RESEARCH_RELOAD='''local native_snapshot
remote.add_interface("esir-native-tests",{poll=function()
 if native_result then return native_result end
 if phase=="candidate" then return {complete=false} end
 local saved=assert(storage.esir_native_research,"Missing persisted research acceptance")
 record("saved-native-flood",saved.scripted_events>1)
 for _,name in pairs(saved.targets) do record("saved-researched-"..name,game.forces.player.technologies[name].researched) end
 native_snapshot=remote.call("exotic-industries-qc","get_research_hitch_qc_snapshot")
 local burst=native_snapshot.scripted_research_burst
 record("saved-backlog-empty",burst.pending_force_count==0 and burst.next_due_tick==0)
 -- Immediate force flushes can leave cancelled entries in the delayed buckets.
 -- Ordinary load preserves those entries without admitting live research work.
 record("saved-cancelled-bucket-count",type(saved.due_bucket_count)=="number"
   and type(burst.due_bucket_count)=="number" and burst.due_bucket_count==saved.due_bucket_count)
 record("saved-cancelled-item-count",type(saved.due_bucket_items)=="number"
   and type(burst.due_bucket_items)=="number" and burst.due_bucket_items==saved.due_bucket_items)
 record("saved-live-em-chargers",native_snapshot.em_trains.charger_count>0)
 record("saved-live-em-trains",native_snapshot.em_trains.train_count>0)
 record("saved-tesla-cache",native_snapshot.tesla.force_cache_count>0)
 native_result={complete=true,checks=native_checks};return native_result
end})
'''


def research(repo,main,helper):
    world=read(repo/'.codex/skills/esir-dev/assets/zzz-scripted-research-qc_0.0.1/control.lua')
    world=re.sub(r'script.on_configuration_changed\(function\(\)(.*?)\nend\)',r'local function native_configuration_changed()\1\nend',world,flags=re.S)
    write(helper/'native-suite.lua',capture_init(world)+'\nreturn {init=native_init,configuration_changed=native_configuration_changed}\n')
    body=read(repo/'scripts/qc/runtime-contracts/research.lua')
    body=body.replace('{ei_spider_vehicles, "spider"}','{ei_spider_vehicles, "spider", 3}')
    body=body.replace('{ei_singularity_lance, "lance", 2},','{ei_singularity_lance, "lance", 2}, {ei_anisetron, "anisetron", 2},')
    body=body.replace('{em_trains, "em"}','{em_trains, "em", 2}')
    body=body.replace('"lance-scripted", "radar-scripted"','"lance-scripted", "anisetron-scripted", "radar-scripted"')
    body=body.replace('"informatron-normal", "em-normal"','"informatron-normal", "anisetron-normal", "em-normal"')
    marker='        log("RUNTIME_CONTRACTS mode=research COMPLETE")'
    body=replace(body,marker,marker+'''
        local accepted_burst=assert(remote.call("exotic-industries-qc","get_research_hitch_qc_snapshot").scripted_research_burst)
        check("controlled-logical-backlog-empty",accepted_burst.pending_force_count==0 and accepted_burst.next_due_tick==0)
        check("controlled-due-bucket-diagnostics",type(accepted_burst.due_bucket_items)=="number"
          and type(accepted_burst.due_bucket_count)=="number")
        for _,row in ipairs(checks) do native_checks[#native_checks+1]={name=row.name,passed=row.pass,detail=row.detail} end
        storage.esir_native_research={targets=targets,scripted_events=scripted_events,
          due_bucket_count=accepted_burst.due_bucket_count,due_bucket_items=accepted_burst.due_bucket_items}
        native_result={complete=true,checks=native_checks}''')
    marker='                finish(true)'
    body=replace(body,marker,'''                local other=game.forces["esir-native-research-other"] or game.create_force("esir-native-research-other")
                queue_scripted_research_burst{research=force.technologies[targets.em],by_script=true,tick=event.tick}
                queue_scripted_research_burst{research=other.technologies[targets.em],by_script=true,tick=event.tick}
                local pending=storage.ei.scripted_research_burst.pending_by_force
                check("controlled-two-force-pending",pending[force.index]~=nil and pending[other.index]~=nil)
                flush_scripted_research_burst_for_force(force.index,event.tick)
                check("controlled-force-flush-isolation",pending[force.index]==nil and pending[other.index]~=nil)
                flush_scripted_research_burst_for_force(other.index,event.tick)
                check("controlled-forces-drained",next(pending)==nil)
                local order={}
                local saved_burst,saved_normal=ei_tech_scaling.on_scripted_research_burst,ei_tech_scaling.on_research_finished
                ei_tech_scaling.on_scripted_research_burst=function(...) order[#order+1]="burst";return saved_burst(...) end
                ei_tech_scaling.on_research_finished=function(...) order[#order+1]="normal";return saved_normal(...) end
                queue_scripted_research_burst{research=force.technologies[targets.em],by_script=true,tick=event.tick}
                previous_research{name=defines.events.on_research_finished,research=force.technologies[targets.em],by_script=false,tick=event.tick}
                ei_tech_scaling.on_scripted_research_burst,ei_tech_scaling.on_research_finished=saved_burst,saved_normal
                check("controlled-pending-flush-before-normal",table.concat(order,",")=="burst,normal")
                check("controlled-normal-flush-drained",next(pending)==nil)
                finish(true)''')
    append_main(main,PREFIX+RESEARCH_RELOAD+'\nif phase=="candidate" then\n'+body+'\nend\n')
    return {'evidence':'Native scripted flood/ordinary research plus controlled queue/flush force isolation'}


ALERTS='''local alerts=require("lib/alerts")
local catalog=require("lib/alert-catalog")
local setting_handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
local start_tick
local function native_count(player,entity)
 local count=0
 for _,types in pairs(player.get_alerts{type=defines.alert_type.custom,entity=entity}) do
  for _,rows in pairs(types) do count=count+#rows end
 end
 return count
end
local function setting(player,name,value,tick)
 player.mod_settings[name]={value=value}
 setting_handler{name=defines.events.on_runtime_mod_setting_changed,player_index=player.index,setting_type="runtime-per-user",setting=name,tick=tick}
end
remote.add_interface("esir-native-tests",{step=function(tick)
 if native_result then return native_result end
 local player=game.connected_players[1];if not player then return {complete=false} end
 local gate_setting=catalog.by_id["gate-low-power"].setting_name
 local fluid_setting=catalog.by_id["fluid-rupture"].setting_name
 if phase~="candidate" then
  local s=assert(storage.esir_native_alerts,"Missing persisted alert fixture")
  record("saved-marker",s.marker=="native-alerts-v1")
  record("saved-personal-off",player.mod_settings[gate_setting].value==false and not alerts.player_allows(player,"gate-low-power"))
  record("saved-cleanup",not s.old_anchor.valid and alerts.channel_state("operational").by_id[s.incident_id]==nil)
  native_result={complete=true,checks=native_checks};return native_result
 end
 start_tick=start_tick or tick;local elapsed=tick-start_tick
 local s=storage.esir_native_alerts
 if elapsed==0 then
  for _,entry in ipairs(catalog.entries) do
   record("native-setting-icon-"..entry.id,player.mod_settings[entry.setting_name]~=nil and prototypes.virtual_signal[entry.icon_signal]~=nil)
   record("shipped-default-"..entry.id,prototypes.mod_setting[entry.setting_name].default_value==entry.default_enabled)
   if entry.master then setting(player,entry.master,true,tick) end
   setting(player,entry.setting_name,false,tick);record("personal-off-"..entry.id,not alerts.player_allows(player,entry.id))
   setting(player,entry.setting_name,true,tick)
   if entry.master then
    setting(player,entry.master,false,tick);record("master-off-"..entry.id,not alerts.player_allows(player,entry.id));setting(player,entry.master,true,tick)
   end
   record("personal-on-"..entry.id,alerts.player_allows(player,entry.id))
  end
  -- Factorio exposes no create_player API. Isolate preference ownership with
  -- controlled player boundaries; actual multiple-client delivery is separate.
  local other={index=999999,valid=true,connected=false,force=player.force,mod_settings={[gate_setting]={value=true}}}
  local master=catalog.by_id["gate-low-power"].master
  if master then other.mod_settings[master]={value=true} end
  local prefs=alerts.refresh_player("operational",other);prefs.isolation_marker="other-player"
  setting(player,gate_setting,false,tick)
  record("controlled-player-preference-isolation",alerts.player_allows(other,"gate-low-power") and not alerts.player_allows(player,"gate-low-power"))
  record("controlled-player-state-isolation",alerts.channel_state("operational").players[999999].isolation_marker=="other-player")
  alerts.on_player_removed{player_index=999999};setting(player,gate_setting,true,tick)
  local surface=game.create_surface("esir-native-alerts",{width=64,height=64})
  surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
  player.teleport({0,0},surface)
  local chest=assert(surface.create_entity{name="steel-chest",position={4,0},force=player.force})
  s={surface=surface,chest=chest};storage.esir_native_alerts=s
  alerts.set_condition("operational",chest.unit_number,"gate-low-power",true,{entity=chest,message={"ei-alerts.name-gate-low-power"}},tick)
 elseif elapsed==10 then
  record("native-condition-delivered",native_count(player,s.chest)==1);setting(player,gate_setting,false,tick)
 elseif elapsed==20 then
  record("off-clears-delivery",native_count(player,s.chest)==0)
  alerts.set_condition("operational",s.chest.unit_number,"gate-low-power",true,{entity=s.chest},tick)
 elseif elapsed==30 then
  record("source-cannot-override-off",native_count(player,s.chest)==0);setting(player,gate_setting,true,tick)
 elseif elapsed==180 then
  record("reenable-live-condition",native_count(player,s.chest)==1)
  alerts.set_condition("operational",s.chest.unit_number,"gate-low-power",false,{entity=s.chest},tick)
  local second=assert(s.surface.create_entity{name="steel-chest",position={8,0},force=player.force})
  alerts.record_incident("operational","fluid-rupture",{entity=second,message={"ei-alerts.name-fluid-rupture"}},tick)
  local channel=alerts.channel_state("operational");s.incident_id=channel.next_id;second.destroy()
 elseif elapsed==200 then
  record("condition-cleanup",native_count(player,s.chest)==0)
  local incident=assert(alerts.channel_state("operational").by_id[s.incident_id]);s.old_anchor=incident.anchor
  record("destroyed-source-anchor",s.old_anchor and s.old_anchor.valid and native_count(player,s.old_anchor)==1)
  setting(player,fluid_setting,false,tick)
 elseif elapsed==220 then
  record("incident-off-clears",native_count(player,s.old_anchor)==0);setting(player,fluid_setting,true,tick)
 elseif elapsed==360 then
  record("no-incident-replay",native_count(player,s.old_anchor)==0)
  alerts.channel_state("operational").by_id[s.incident_id].cancelled=true
  local invalid=assert(s.surface.create_entity{name="steel-chest",position={12,0},force=player.force})
  alerts.set_condition("operational",invalid.unit_number,"gate-low-power",true,{entity=invalid},tick)
  s.invalid_condition=alerts.channel_state("operational").next_id;invalid.destroy()
 elseif elapsed==400 then
  local channel=alerts.channel_state("operational")
  record("incident-retired",channel.by_id[s.incident_id]==nil and not s.old_anchor.valid)
  record("bounded-cleanup",channel.last_service.steps<=32)
  record("invalid-condition-source-retired",channel.by_id[s.invalid_condition]==nil)
  setting(player,gate_setting,false,tick);s.marker="native-alerts-v1"
  native_result={complete=true,checks=native_checks};return native_result
 end
 return {complete=false}
end})
'''


def stage_runtime(repo,main,helper,suite,profile):
    if suite=='gate-quality':
        body=read(repo/'scripts/qc/factorio-2.1/gate-native.lua')
        body=replace(body,'        assert(condition,label)','        assert(condition,label)\n        record(label,condition)')
        body=replace(body,'        if game.is_multiplayer() then game.auto_save("gate-"..phase) end','        native_result={complete=true,checks=native_checks}')
        body=replace(body,'            if q then','            if phase~="candidate" then assert(q,"Missing saved gate fixture") end\n            if q then')
        body=replace(body,'                q.control=surface.create_entity', '                quality_checks(q,event,check)\n                cooldown_start(q,event,check)\n                q.control=surface.create_entity')
        body=replace(body,'                q.reload_at=event.tick+600','                cooldown_restore(q,event,check)\n                q.reload_at=event.tick+600')
        body=replace(body,'        if checked_reload then','        local cooldown_ready=cooldown_step(q,event,check)\n        if checked_reload then')
        body=replace(body,'        elseif elapsed==10 then','        elseif elapsed>=430 and cooldown_ready and not q.passed then')
        append_main(main,PREFIX+read(repo/'scripts/qc/gate-quality/checks.lua')+'\n'+read(repo/'scripts/qc/gate-quality/cooldown.lua')+'\n'+body+'''
remote.add_interface("esir-native-tests",{step=function()
 return native_result or {complete=false}
end})
''')
        return {'evidence':'Native gate transfers, quality energy, upkeep, cooldown input/countdown and serialized sender state',
                'rendered_output':'gate-cooldown'}
    if suite=='engine-smoke':
        write(helper/'native-suite.lua','''local initialized=false
return {init=function() initialized=true end,poll=function(tick)
 return {complete=true,checks={
  {name="fixture-on-init",passed=initialized},
  {name="selected-main-loaded",passed=script.active_mods["exotic-space-industries-remembrance"]~=nil},
  {name="native-tick-dispatch",passed=type(tick)=="number" and tick>=0},
  {name="native-world-initialized",passed=game.forces.player~=nil and game.surfaces[1]~=nil}
 }}
end}
''')
        return {'evidence':'Native selected-stack load and initialization only'}
    if suite in ('combustion-turbine-native-proof','combustion-turbine'):
        import importlib.util
        spec=importlib.util.spec_from_file_location('esir_turbine_adapter',repo/'scripts/qc/combustion-turbine/adapter.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module.stage(repo,main,helper,profile)
    if suite=='orbital-logistics':
        import importlib.util
        spec=importlib.util.spec_from_file_location('esir_orbital_adapter',repo/'scripts/qc/orbital-logistics/adapter.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module.stage(repo,main,helper,profile)
    if suite=='gaia-resources':
        import gaia_resources
        return gaia_resources.stage(repo,main,helper,profile)
    if suite=='runtime-options':
        import importlib.util
        spec=importlib.util.spec_from_file_location('esir_runtime_options_adapter',repo/'scripts/qc/runtime-options/adapter.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module.stage(repo,main,helper,profile)
    if suite=='scheduler-event-tick':return scheduler(repo,main,helper)
    if suite=='induction-circuit':return induction(repo,main,helper)
    if suite=='research-events':return research(repo,main,helper)
    if suite=='alert-preferences':
        append_main(main,PREFIX+ALERTS)
        return {'evidence':'Native preference/delivery/cleanup with programmatic actual setting dispatcher'}
    raise ValueError('No runtime adapter for '+suite)
