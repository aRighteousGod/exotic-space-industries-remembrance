-- Native-paid edge cases. No controller state or damage packets are fabricated.
local module={}
local upgrades={"axial-rupture","wound-memory","terminal-collapse","black-hole-testament"}
local function test(key,pass,detail) storage.results["edge-"..key]={pass=pass==true,detail=detail} end
local function target(actor,x,y,key,force)
 local e=storage.surface.create_entity{name="anisetron-inheritance-target",position={actor.x+x,actor.y+y},force=force or "enemy"}
 e.active=false
 storage.edge_targets[e.unit_number]={actor=actor,key=key};actor.targets[key]=e
 return e
end
function module.setup()
 storage.edges={};storage.edge_targets={}
 for i,spec in ipairs{
  {key="axial-caps",level=1},{key="testament-caps",level=4},{key="fixed-collapse",level=3},
  {key="short-idle",level=2},{key="expired-idle",level=2},{key="diplomacy",level=2},
  {key="research-snapshot",level=4,charges=2},{key="missed-eighth",level=4},
  {key="force-merge",level=4},
 } do
  spec.x=-840+((i-1)%8)*240;spec.y=420+math.floor((i-1)/8)*240
  storage.surface.request_to_generate_chunks({spec.x,spec.y},3);storage.surface.force_generate_chunk_requests()
  local force=game.create_force("inheritance-edge-"..spec.key);spec.force=force
  force.technologies["ei-singularity-lance"].researched=true
  for n=1,spec.level do force.technologies["ei-singularity-lance-"..upgrades[n]].researched=true end
  spec.source=storage.surface.create_entity{name="ei-anisetron",position={spec.x,spec.y},force=force,raise_built=true}
  spec.source.orientation=0;spec.source.torso_orientation=0
  spec.source.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  spec.targets={};spec.hits={};target(spec,0,-40,"primary")
  spec.source.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=spec.charges or 1}
  storage.edges[#storage.edges+1]=spec
 end
end
function module.damage(event)
 local record=storage.edge_targets and storage.edge_targets[event.entity.unit_number]
 if not record then return end
 local actor=record.actor;actor.first=actor.first or event.tick
 local rows=actor.hits[event.tick] or {};actor.hits[event.tick]=rows
 rows[#rows+1]={target=record.key,damage=event.original_damage_amount}
end
local function geometry(actor)
 for n=1,12 do target(actor,0,-41-n*1.5,"central"..n) end
 for n=1,8 do local d=7+n;target(actor,(n%2==0 and 1 or -1)*math.sin(math.pi/12)*d,-40-math.cos(math.pi/12)*d,"branch"..n) end
end
local function amount(actor,tick,key)
 local total=0;for _,hit in ipairs(actor.hits[tick] or {}) do if hit.target==(key or "primary") then total=total+hit.damage end end
 return total
end
function module.tick(tick)
 for _,a in ipairs(storage.edges or {}) do
  if a.first then
   local t=tick-a.first
   if a.key=="axial-caps" and t==1 then geometry(a)
   elseif a.key=="axial-caps" and t==13 then
    local central,branch,seen=0,0,{};local exact=true
    for _,h in ipairs(a.hits[a.first+12] or {}) do
     exact=exact and not seen[h.target];seen[h.target]=true
     if h.target:find("central") then central=central+1;exact=exact and h.damage==320
     elseif h.target:find("branch") then branch=branch+1;exact=exact and h.damage==160 end
    end
    test(a.key,exact and central==5 and branch==3,{central=central,branch=branch,hits=a.hits[a.first+12]});a.source.destroy{raise_destroy=true}
   elseif a.key=="testament-caps" and t==83 then geometry(a)
   elseif a.key=="testament-caps" and t==85 then
    local central,branch,seen=0,0,{};local exact=true
    for _,h in ipairs(a.hits[a.first+84] or {}) do
     exact=exact and not seen[h.target];seen[h.target]=true
     if h.target:find("central") then central=central+1;exact=exact and h.damage==320
     elseif h.target:find("branch") then branch=branch+1;exact=exact and h.damage==160 end
    end
    test(a.key,exact and central==10 and branch==6 and amount(a,a.first+84)==2560,{central=central,branch=branch,hits=a.hits[a.first+84]});a.source.destroy{raise_destroy=true}
   elseif a.key=="fixed-collapse" and t==1 then
    a.targets.primary.teleport({a.x+100,a.y-40});target(a,.5,-40,"core");target(a,3,-40,"shell");target(a,-3,-40,"friend",a.force)
    a.source.teleport({a.x+20,a.y});a.source.destroy{raise_destroy=true}
   elseif a.key=="fixed-collapse" and t==31 then
    test(a.key,amount(a,a.first+30,"core")==640 and amount(a,a.first+30,"shell")==384
     and amount(a,a.first+30,"friend")==0 and amount(a,a.first+30)==0,a.hits[a.first+30])
   elseif (a.key=="short-idle" and t==1220) or (a.key=="expired-idle" and t==1340) then
    a.source.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1}
    a.resupply=tick
   elseif a.resupply and not a.checked and tick>a.resupply+35 then
    local first,next_amount
    for hit_tick in pairs(a.hits) do if hit_tick>=a.resupply and (not first or hit_tick<first) then first=hit_tick;next_amount=amount(a,hit_tick) end end
    test(a.key,next_amount==(a.key=="short-idle" and 640 or 320),{first=first,damage=next_amount});a.checked=true
   elseif a.key=="diplomacy" and t==73 then
    a.force.set_cease_fire("enemy",true);a.force.set_cease_fire("enemy",false)
   elseif a.key=="diplomacy" and t==85 then
    local memory=remote.call("anisetron-inheritance-qc","memory",a.source.unit_number)
    test("same-tick-diplomacy-resets",amount(a,a.first+84)==320,a.hits[a.first+84])
    test("diplomacy-restores-wound-cue",memory and memory.mark and memory.stacks==1,memory)
   elseif a.key=="research-snapshot" and t==1 then
    for _,key in ipairs(upgrades) do a.force.technologies["ei-singularity-lance-"..key].researched=false end
    a.force.technologies["laser-weapons-damage-6"].researched=true
    remote.call("anisetron-inheritance-qc","rebuild")
   elseif a.key=="research-snapshot" and t==1201 then
    local paid=remote.call("anisetron-inheritance-qc","paid",a.source.unit_number)
    test("new-charge-new-research",paid and paid.level==0 and math.abs(paid.crown_damage-544)<.001,paid)
    test("old-charge-retains-testament",amount(a,a.first+84)==2560,a.hits[a.first+84])
   elseif a.key=="missed-eighth" and t==73 then a.targets.primary.teleport({a.x,a.y-180})
   elseif a.key=="missed-eighth" and t==85 then
    test("missed-eighth-no-packet",amount(a,a.first+84)==0,a.hits[a.first+84]);a.targets.primary.teleport({a.x,a.y-40})
   elseif a.key=="missed-eighth" and t==121 then
    local first,resumed
    for hit_tick in pairs(a.hits) do if hit_tick>=a.first+85 and (hit_tick-a.first)%12==0 and (not first or hit_tick<first) then first=hit_tick;resumed=amount(a,hit_tick) end end
    test("missed-testament-not-banked",resumed==320,{tick=first,damage=resumed})
   elseif a.key=="force-merge" and t==85 then
    game.merge_forces(a.force,game.forces.player)
   elseif a.key=="force-merge" and t==145 then
    test("force-merge-committed-collapse",amount(a,a.first+114)==1280,a.hits[a.first+114])
    test("force-merge-committed-echo",amount(a,a.first+144)==640,a.hits[a.first+144])
    test("force-merge-cancels-live-contacts",amount(a,a.first+96)==0,a.hits[a.first+96])
    test("force-merge-resets-live-memory",remote.call("anisetron-inheritance-qc","memory",a.source.unit_number)==nil)
   end
  end
 end
end
return module
