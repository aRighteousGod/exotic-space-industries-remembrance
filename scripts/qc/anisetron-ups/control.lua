-- Fixed native fleet workload. Observations/profilers are opt-in and isolated
-- from any uninstrumented whole-engine claim. No production prototype changes.
local options=require("options")
if options.mobility then require("mobility-probe");return end
local function setup(tick)
 storage.start=tick;storage.entities={};storage.targets={};storage.samples={};storage.damage={}
 local surface=game.create_surface("anisetron-ups",{width=1024,height=options.fleet*192+512,water=0,
  cliff_settings={cliff_elevation_interval=0},autoplace_controls={},
  autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
 for i=1,options.fleet do surface.request_to_generate_chunks({0,(i-(options.fleet+1)/2)*192},5) end
 surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities()) do e.destroy() end
 surface.freeze_daytime=true;surface.daytime=.45
 local force=game.create_force("anisetron-ups")
 for i=1,options.fleet do
  local y=(i-(options.fleet+1)/2)*192
  local e=surface.create_entity{name="ei-anisetron",position={0,y},force=force,raise_built=true}
  e.orientation=.25;e.torso_orientation=.25
  e.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  storage.entities[i]=e
 end
end
local function profile(label) if options.profile then remote.call("anisetron-ups","profile",label) end end
script.on_event(defines.events.on_entity_damaged,function(event)
 if options.observe and event.entity.name=="anisetron-ups-target" then
  storage.damage[#storage.damage+1]={tick=event.tick-storage.start,id=event.entity.unit_number,damage=event.final_damage_amount}
 end
end)
script.on_event(defines.events.on_tick,function(event)
 if storage.complete then return end
 if not storage.start then setup(event.tick) end
 local t=event.tick-storage.start
 if t==300 then profile("idle") end
 if t==1200 then
  profile(nil)
  for _,e in ipairs(storage.entities) do e.autopilot_destination={250,e.position.y} end
 end
 if t==1500 then profile("moving") end
 if t==2400 then
  profile(nil)
  for _,e in ipairs(storage.entities) do e.autopilot_destination=nil end
 end
 if t==2550 then
  for i,e in ipairs(storage.entities) do
   e.orientation=.25;e.torso_orientation=.25
   e.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=4}
   local p=e.position
   local target=e.surface.create_entity{name="anisetron-ups-target",position={p.x+20,p.y},force="enemy"}
   target.active=false;storage.targets[i]=target
  end
 end
 if t==2850 then profile("firing") end
 if t==3750 then
  profile(nil)
  for _,e in ipairs(storage.entities) do e.autopilot_destination={-120,e.position.y} end
 end
 if t==4050 then profile("moving-firing") end
 if t>=3750 and t<4950 then
  for i,e in ipairs(storage.entities) do storage.targets[i].teleport{e.position.x-20,e.position.y} end
 end
 if t==4950 then
  profile(nil)
  for _,e in ipairs(storage.entities) do e.autopilot_destination=nil end
 end
 if options.edges then
  if t==1850 then remote.call("anisetron-ups","exercise","lost-handle",storage.entities[1],event.tick) end
  if t==1860 then remote.call("anisetron-ups","exercise","old-cache",storage.entities[1],event.tick) end
  if t==1950 then
   local e=storage.entities[1];local p=e.position;e.teleport({p.x+3,p.y+3},e.surface,true)
  end
  if t==4200 then remote.call("anisetron-ups","exercise","rebuild",storage.entities[1],event.tick) end
 end
 local dense=options.edges and ((t>=1840 and t<=2010) or (t>=3740 and t<=3960) or (t>=4190 and t<=4290))
 if options.observe and (t%30==0 or dense) then
  local row=remote.call("anisetron-ups","snapshot",storage.entities)
  row.tick=t;row.health={};for i,e in ipairs(storage.targets) do row.health[i]=e.health end
  storage.samples[#storage.samples+1]=row
 end
 if t==options.duration-1 then
  storage.complete=true
  local report={all_pass=true,complete=true,count=1,profile="ups",cases={completed={pass=true}},fleet=options.fleet,
   samples=storage.samples,damage=storage.damage}
  helpers.write_file("anisetron-qc.json",helpers.table_to_json(report),false)
  log("ANISETRON_UPS COMPLETE")
 end
end)
