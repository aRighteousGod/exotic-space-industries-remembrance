-- Appended only to staged ESIR. Exercises actual dispatcher branches while
-- substituting only the tested receivers during an initial 64-tick window.
do
 local a=ei_anisetron
 local l=ei_singularity_lance
 local v=require("scripts/control/anisetron-visuals")
 local cold_first
 if a.has_tick_work then
  local predicate=a.has_tick_work
  a.has_tick_work=function(event)
   if not cold_first then
    local work=predicate(event);local repeated=true
    for _=1,8 do repeated=repeated and predicate(event)==work end
    cold_first={work=work,repeated=repeated,tick=event.tick}
   end
   return predicate(event)
  end
 end
 local method=a.updater and "updater" or "update"
 local lm=l.updater and "updater" or "update"
 local original={a=a[method],ah=a.has_tick_work,l=l[lm],lh=l.has_tick_work,
  rail=ei_railgun_cooling.update,rail_count=ei_railgun_cooling.get_pending_work_count,
  tail=ei_hemocrystal_wall.has_tick_work}
 local rows={};local enabled=false
 local function note(tick,key)
  local row=rows[tick] or {tick=tick,step=tick%16+1,order={}};rows[tick]=row
  row.order[#row.order+1]=key;row[key]=(row[key] or 0)+1
 end
 remote.add_interface("anisetron-dispatch",{
  prepare_idle_save=function(tick)
   a.rebuild_visuals(tick)
   assert(not a.has_tick_work{tick=tick},"cold-save fixture must be idle")
  end,
  cold_load=function(tick)
   local root=storage.ei.runtime_scheduler.modules.anisetron
   return {first=cold_first,idle_now=not a.has_tick_work{tick=tick},
    revision=root.visuals.revision,empty=not next(root.active or {})
     and not next(root.visuals.queue.queued) and root.mobility.count==0}
  end,
  begin=function()
   enabled=true
   a.has_tick_work=function()return true end
   a[method]=function(event)note(event.tick,"anisetron")end
   l.has_tick_work=function()return true end
   l[lm]=function(first,event)note((event or first).tick,"lance");return 0 end
   ei_railgun_cooling.get_pending_work_count=function()return 1 end
   ei_railgun_cooling.update=function(event)note(event.tick,"goto-skip");return false end
   ei_hemocrystal_wall.has_tick_work=function(event)note(event.tick,"tail-predecessor");return original.tail(event)end
  end,
  finish=function()
   assert(enabled);enabled=false
   a[method],a.has_tick_work=original.a,original.ah;l[lm],l.has_tick_work=original.l,original.lh
   ei_railgun_cooling.update,ei_railgun_cooling.get_pending_work_count=original.rail,original.rail_count
   ei_hemocrystal_wall.has_tick_work=original.tail
   return rows
  end,
  predicates=function(tick)
   if not a.has_tick_work then return {baseline=true,cases={}} end
   v.rebuild(tick) -- Initialize the module-local startup preset before pure probes.
   local modules=storage.ei.runtime_scheduler.modules;local saved=modules.anisetron
   local cases={}
   local function probe(name,value,at,expected)
    modules.anisetron=value
    local before=helpers.table_to_json({state=value})
    for _=1,8 do assert(a.has_tick_work{tick=at}==expected,name) end
    assert(helpers.table_to_json({state=modules.anisetron})==before,name.." mutated state")
    cases[name]={pass=true}
   end
   local ok,err=pcall(function()
    probe("absent",nil,tick,false);probe("empty",{},tick,false)
    probe("active-queue",{active={[1]={queue={}}}},tick,true)
    probe("empty-owner-needs-cleanup",{active={[1]={}}},tick,true)
    probe("parked-not-due",{mobility={count=1,next_tick=tick+1}},tick,false)
    probe("parked-due",{mobility={count=1,next_tick=tick}},tick,true)
    probe("valid-tick-zero",{mobility={count=1,next_tick=0}},0,true)
    probe("empty-mobility",{mobility={count=0,next_tick=tick}},tick,false)
    probe("permanent-memory-idle",{lance={marks={},memories={[1]={}},next_due=false}},tick,false)
    probe("wound-without-owner",{lance={marks={[1]={}},next_due=false}},tick,true)
    probe("future-committed",{lance={marks={},next_due=tick+1}},tick,false)
    probe("due-without-source",{lance={marks={},next_due=tick}},tick,true)
    probe("overdue-without-source",{lance={marks={},next_due=tick-1}},tick,true)
    local function visual(fields)
     local x={revision=6,attached={},transients={},queue={queued={}}};for k,z in pairs(fields) do x[k]=z end
     return {visuals=x}
    end
    probe("empty-visuals",visual{},tick,false)
    probe("old-visual-revision",visual{revision=0},tick,true)
    probe("attached-between-passes",visual{attached={[1]={}}},tick,true)
    probe("transient-cleanup",visual{transients={{}}},tick,true)
    local fidelity=settings.startup["ei-anisetron-visual-fidelity"].value
    local intervals={off=0,lean=8,standard=4,cinematic=3,maximal=2,unbounded=1}
    local interval=intervals[fidelity]
    probe("sampling-admission",visual{queue={queued={[1]=true}}},0,interval>0)
    if interval>1 then probe("sampling-between-passes",visual{queue={queued={[1]=true}}},1,false) end
   end)
   modules.anisetron=saved
   assert(ok,err);return {cases=cases}
  end,
  snapshot=function(entity)
   local runtime=storage.ei.runtime_scheduler.modules.anisetron
   local owner=runtime.active and runtime.active[entity.unit_number];local b=owner and owner.burst
   local row={paid=runtime.counters and runtime.counters.paid,ammo=entity.get_inventory(defines.inventory.spider_ammo).get_contents()}
   if b then
    row.deadlines={b.start_tick,b.next_contact,b.end_tick};row.channels={}
    for name,c in pairs(b.channels or {}) do row.channels[name]={endpoint=c.endpoint,muzzle=c.muzzle_index,
     target=c.target and c.target.valid and c.target.unit_number or nil} end
   end
   return row
  end,
  legacy_service=function(limit,tick)return l.service_for_qc(limit,{tick=tick})end,
  adapter_packets=function(surface,tick)
   -- Synchronous admission probes, after the native shared-target trace ends.
   -- Use real production contact/collapse queues, never fabricated packet state.
   l.service_for_qc(0,{tick=tick+500})
   local force=game.create_force("anisetron-adapter")
   force.technologies["ei-singularity-lance"].researched=true
   for _,key in ipairs{"axial-rupture","wound-memory","terminal-collapse"} do
    force.technologies["ei-singularity-lance-"..key].researched=true
   end
   l.on_scripted_research_burst(force,tick)
   local result={}
   for i,limit in ipairs{0,1,100000} do
    local at=tick+1000+i*100
    local victim=surface.create_entity{name="anisetron-dispatch-target",position={110,90},force="enemy"}
    -- Native float health near 1e8 rounds 500-damage changes to 496.
    -- Keep the exact-accounting probe within unit-resolution health values.
    victim.active=false;victim.health=1000000;local health=victim.health;local sources={}
    for n=1,3 do
     local source=surface.create_entity{name="ei-singularity-lance",position={90,90},force=force,raise_built=true}
     source.active=false;sources[n]=source
     l.on_script_trigger_effect{effect_id="ei-singularity-lance-shot",source_entity=source,
      target_entity=victim,target_position=victim.position,tick=at}
    end
    assert(l.service_for_qc(limit,{tick=at+7})==0 and victim.health==health,"adapter future")
    local contacts=l.service_for_qc(limit,{tick=at+8})
    assert(contacts==3 and health-victim.health==1500,"adapter contacts "..limit.." count="..contacts.." damage="..(health-victim.health))
    assert(l.service_for_qc(limit,{tick=at+8})==0,"adapter repeated contact")
    local pulses=l.service_for_qc(limit,{tick=at+38})
    assert(pulses==3 and health-victim.health==4500,"adapter pulses "..limit.." count="..pulses.." damage="..(health-victim.health))
    assert(l.service_for_qc(limit,{tick=at+38})==0,"adapter repeated pulse")
    result[tostring(limit)]={contacts=contacts,pulses=pulses,damage=health-victim.health}
    for _,source in ipairs(sources) do source.destroy{raise_destroy=true} end
    victim.destroy()
   end
   assert(l.service_for_qc(0)==0,"adapter eventless empty boundary")
   return result
  end
 })
end
