-- Gate only this owner's automatic calls in the staged bridge. Manual calls use
-- real event ticks and real public vehicles; shipping event admission stays live.
local function check(name,value)
 storage.cases[name]={pass=value==true};assert(value,name)
end
local function state() return remote.call("anisetron-ups","mobility_state") end
local function service(tick) remote.call("anisetron-ups","service_mobility",tick) end
script.on_event(defines.events.on_tick,function(event)
 if storage.complete then return end
 if not storage.start then
  storage.start=event.tick;storage.cases={};storage.states={}
  remote.call("anisetron-ups","pause_mobility")
  local s=game.create_surface("anisetron-ups-mobility",{water=0,autoplace_controls={}})
  s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
  for _,e in pairs(s.find_entities()) do e.destroy() end
  storage.a=s.create_entity{name="ei-anisetron",position={0,0},force="player",raise_built=true}
  storage.b=s.create_entity{name="ei-anisetron",position={20,0},force="player",raise_built=true}
  storage.a_id=storage.a.unit_number;storage.b_id=storage.b.unit_number
 end
 local t=event.tick-storage.start;local start=storage.start
 local a,b=storage.a_id,storage.b_id
 if t==1 then
  service(event.tick);local s=state()
  check("ordinary-four-tick-deadline",s.next_tick==start+5 and #s.due[start+5]==2)
 elseif t==2 then
  local health=storage.a.health
  storage.a.damage(1,game.forces.enemy,"physical");storage.a.damage(1,game.forces.enemy,"physical")
  local s=state()
  check("real-native-damage-admission",storage.a.health<health)
  check("duplicate-hits-one-urgent-ticket",s.next_tick==start+3 and #s.due[start+3]==1 and #s.due[start+5]==2)
 elseif t==3 then
  service(event.tick);local s=state()
  check("earliest-retained-stale-ticket",s.records[a].next_tick==start+7 and s.next_tick==start+5)
 elseif t==4 then
  storage.a.damage(1,game.forces.enemy,"physical");local s=state()
  check("mixed-cohort-and-stale-duplicate",#s.due[start+5]==3)
 elseif t==5 then
  service(event.tick);local s=state()
  check("exact-cohort-services-each-source-once",#s.due[start+9]==2
   and s.records[a].next_tick==start+9 and s.records[b].next_tick==start+9)
  check("future-stale-minimum-retained",s.next_tick==start+7)
 elseif t==6 then
  service(event.tick);local s=state()
  check("early-call-leaves-deadlines",s.next_tick==start+7 and #s.due[start+9]==2)
 elseif t==10 then
  service(event.tick);local s=state()
  check("overdue-drains-all-old-buckets",not s.due[start+7] and not s.due[start+9])
  check("overdue-services-each-source-once",#s.due[start+14]==2
   and s.records[a].next_tick==start+14 and s.records[b].next_tick==start+14)
 elseif t==11 then
  storage.a.destroy{raise_destroy=true};local s=state()
  check("single-removal-retains-other-source",s.count==1 and not s.records[a] and s.records[b]~=nil)
 elseif t==12 then
  storage.b.destroy{raise_destroy=true};local s=state()
  check("last-removal-clears-pending-work",s.count==0 and not next(s.due) and not s.next_tick)
 elseif t==13 then
  service(event.tick);local s=state()
  check("empty-update-stays-empty",s.count==0 and not next(s.due) and not next(s.records))
  remote.call("anisetron-ups","resume_mobility")
  storage.complete=true;local n=0;for _ in pairs(storage.cases) do n=n+1 end
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{
   all_pass=true,complete=true,count=n,profile="ups-mobility",cases=storage.cases,states=storage.states},false)
 end
 storage.states[#storage.states+1]={tick=t,state=state()}
end)
