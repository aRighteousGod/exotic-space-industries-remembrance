local config=require("test-config")
local reloaded=false
script.on_load(function()reloaded=true end)
local function check(name,pass)storage.cases[name]={pass=pass==true};assert(pass,name)end
script.on_event(defines.events.on_entity_damaged,function(event)
 if not storage.ledger or event.entity.name~="anisetron-dispatch-target" then return end
 local source=event.cause and event.cause.valid and event.cause.name or "none"
 storage.ledger[#storage.ledger+1]={tick=event.tick-storage.start,source=source,
  target=event.entity.unit_number,damage=event.original_damage_amount}
 storage.sources[source]=true
end)
script.on_event(defines.events.on_tick,function(event)
 if config.loaded or (reloaded and storage.cold_saved) then
  if storage.cold_checked then return end
  assert(storage.cold_saved,"Requires the idle initialization save")
  storage.cases={}
  local r=remote.call("anisetron-dispatch","cold_load",event.tick)
  log("ANISETRON_COLD_LOAD "..helpers.table_to_json(r))
  check("cold-current-empty-state",r.empty and r.revision==6)
  check("cold-predicate-admits-service",r.first.work and r.first.tick==event.tick)
  check("cold-repeated-predicate-stays-eligible",r.first.repeated)
  check("cold-service-initializes-once",r.idle_now)
  storage.cold_checked=true
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=true,complete=true,count=4,
   profile="dispatch-cold-load",cases=storage.cases,result=r},false)
  return
 elseif config.save then
  if storage.cold_saved then return end
  remote.call("anisetron-dispatch","prepare_idle_save",event.tick)
  storage.cold_saved=true
  reloaded=false
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=true,complete=true,count=1,
   profile="dispatch-cold-save",cases={idle={pass=true}}},false)
  game.server_save("anisetron-transition")
  return
 end
 if storage.complete then return end
 if not storage.start then
  storage.start=event.tick;storage.cases={};storage.ledger={};storage.sources={};storage.samples={}
  remote.call("anisetron-dispatch","begin")
 end
 local t=event.tick-storage.start
 if t==64 then
  local rows=remote.call("anisetron-dispatch","finish");local n=0;local phases={}
  for _,row in pairs(rows) do
   n=n+1;phases[row.step]=true
   check("single-service-"..n,row.anisetron==1 and row.lance==1)
   check("tail-order-"..n,row.order[#row.order]=="anisetron" and row.order[#row.order-1]=="tail-predecessor")
   if row.step==11 then check("goto-skip-"..n,row["goto-skip"]==1) end
  end
  check("all-64-ticks",n==64);for i=1,16 do check("phase-"..i,phases[i])end
  storage.dispatch=rows
  local probes=remote.call("anisetron-dispatch","predicates",event.tick)
  for name,result in pairs(probes.cases) do storage.cases["predicate-"..name]=result end
  storage.baseline=probes.baseline
  local s=game.create_surface("anisetron-dispatch",{width=256,height=256,water=0,autoplace_controls={}})
  s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
  for _,e in pairs(s.find_entities()) do e.destroy() end
  local f=game.create_force("anisetron-dispatch")
  storage.craft=s.create_entity{name="ei-anisetron",position={8,0},force=f,raise_built=true}
  storage.craft.orientation=0;storage.craft.torso_orientation=0
  storage.craft.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  storage.craft.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1}
  storage.lance=s.create_entity{name="ei-singularity-lance",position={-8,0},force=f,raise_built=true}
  storage.first=s.create_entity{name="anisetron-dispatch-target",position={0,-20},force="enemy"}
  storage.first.active=false;storage.first.health=1000
  storage.second=s.create_entity{name="anisetron-dispatch-target",position={0,-24},force="enemy"};storage.second.active=false
 end
 if storage.lance then storage.lance.energy=700000000 end
 if t>64 and t%12==0 then storage.samples[#storage.samples+1]=remote.call("anisetron-dispatch","snapshot",storage.craft) end
 if t==500 then
  check("both-weapons-delivered",storage.sources["ei-anisetron"] and storage.sources["ei-singularity-lance"])
  check("shared-target-removed",not storage.first.valid)
  for _,limit in ipairs{0,1,100000} do
   local count=remote.call("anisetron-dispatch","legacy_service",limit,event.tick)
   check("legacy-limit-"..limit,type(count)=="number")
  end
  storage.lance.active=false
  local adapter=remote.call("anisetron-dispatch","adapter_packets",storage.craft.surface,event.tick)
  for limit,row in pairs(adapter) do check("legacy-paid-limit-"..limit,row.contacts==3 and row.pulses==3 and row.damage==4500) end
  storage.complete=true;local count=0;for _ in pairs(storage.cases) do count=count+1 end
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=true,complete=true,count=count,profile="dispatch",
   cases=storage.cases,baseline=storage.baseline,dispatch=storage.dispatch,ledger=storage.ledger,samples=storage.samples,adapter=adapter},false)
 end
end)
