-- Isolated native-motion probe: no teleport, speed override, sticker or scripted propulsion.
local options=require("options")
local config=require("test-config")
if options.mode=="observer" then require("observer-test").install();return end
if options.mode=="ass" then require("saved-vehicle").install(options);return end
if config.visual then
 if options.mode=="effects" then require("visual-effects").install() else require("visual").install() end
 return
end
local function goal(record,heading)
 local p=record.entity.position;local a=heading*math.pi*2
 if record.manual then record.walking=true;record.direction=math.floor((heading%1)*16+.5)%16;return end
 record.entity.autopilot_destination={p.x+math.sin(a)*800,p.y-math.cos(a)*800}
end
local function setup(tick)
 storage.start=tick;storage.records={};storage.results={}
 local surface=game.create_surface("anisetron-stability",{width=8000,height=8000,water=0,
  cliff_settings={cliff_elevation_interval=0},autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
 if options.headings==1 then surface.request_to_generate_chunks({0,-850},45)
 else for x=-2100,2100,700 do for y=-2800,2800,700 do surface.request_to_generate_chunks({x,y},12) end end end
 surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities()) do e.destroy() end
 surface.destroy_decoratives{};surface.freeze_daytime=true;surface.daytime=.4
 local force=game.create_force("anisetron-stability")
 for _,p in ipairs(options.profiles) do for heading=0,options.headings-1 do
  local e=surface.create_entity{name=p.public and "ei-anisetron" or "anisetron-stability-"..p.id,position={0,(#storage.records-32)*18},force=force,raise_built=true}
  local h=heading/options.headings;e.orientation=h;e.torso_orientation=h
  local r={entity=e,key=p.id.."-h"..heading,profile=p.id,heading=h,last=e.position,stats={},stalls={},zero_run=0,samples={},manual=p.manual and heading==0,armed=p.armed,slow=p.slow}
  if p.equipped then
   e.grid.put{name="fusion-reactor-equipment",position={0,0}}.energy=100000000
   e.grid.put{name="exoskeleton-equipment",position={4,0}}.energy=100000000
  end
  if p.armed then
   e.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
   e.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=50}
   r.target=surface.create_entity{name="anisetron-stability-target",position={e.position.x+12,e.position.y},force="enemy"};r.target.active=false
  end
  storage.records[#storage.records+1]=r;goal(r,h)
  if options.fast_half then surface.create_entity{name="anisetron-trial-pace",position=e.position,target=e} end
 end end
 local player=assert(game.get_player(1));player.force=force;player.set_controller{type=defines.controllers.spectator}
 player.teleport({0,0},surface)
 for _,r in ipairs(storage.records) do if r.manual then
  player.teleport(r.entity.position,surface)
  player.set_controller{type=defines.controllers.character,character=surface.create_entity{name="character",position=r.entity.position,force=force}}
  r.entity.set_driver(player);storage.player=player.index
 end end
end
script.on_event(defines.events.on_tick,function(event)
 if storage.complete then return end
 if not storage.start then setup(event.tick) end
 local t=event.tick-storage.start
 -- Opt-in differential: compare native slowdown floors without changing gait.
 if options.floor_trial and t%2400==0 then
  remote.call("anisetron-stability-qc","minimum",options.floor_trial[math.floor(t/2400)+1] or .2)
 end
 for _,r in ipairs(storage.records) do
  local e=r.entity
  -- Repeated starts, shallow turns and reversals across every compass bearing.
  local long=options.long_cruise or 0
  local cycle=t<long and t or (t-long)%2400
  local sustained=t<long
  if cycle==0 then goal(r,r.heading) end
  if not sustained then
   if cycle==1200 then goal(r,r.heading+.125) end
   if cycle==1600 then goal(r,r.heading+.625) end
   if cycle==2000 then e.autopilot_destination=nil;r.walking=false end
   if cycle==2200 then goal(r,r.heading+.5) end
  elseif cycle%1800==0 then goal(r,r.heading) end
  if r.manual then game.get_player(storage.player).walking_state={walking=r.walking,direction=r.direction} end
  if r.armed and r.target.valid then r.target.teleport{e.position.x+12,e.position.y+10} end
  if r.slow and cycle>=400 and (sustained or cycle<1700) and t%30==0 then
   for _,name in ipairs{"acid-sticker-small","acid-sticker-medium","acid-sticker-big","acid-sticker-behemoth","tb-fire-sticker","cb-cold-sticker","eb-fire-sticker"} do
    e.surface.create_entity{name=name,position=e.position,target=e,force="enemy"}
   end
  end
  local phase=cycle<300 and "start" or sustained and "cruise" or cycle<1200 and "cruise" or cycle<2000 and "turn" or cycle<2200 and "stop" or "restart"
  local p=e.position;local dx,dy=p.x-r.last.x,p.y-r.last.y;local d=math.sqrt(dx*dx+dy*dy)
  local s=r.stats[phase] or {n=0,sum=0,sum2=0,distance=0,zeros=0,max_zero_run=0}
  s.n=s.n+1;s.sum=s.sum+e.speed;s.sum2=s.sum2+e.speed*e.speed;s.distance=s.distance+d
  local destination=e.autopilot_destination
  local far=destination and (destination.x-p.x)^2+(destination.y-p.y)^2>32^2
  local commanded=r.manual and r.walking or far
  r.zero_run=commanded and d<.00001 and r.zero_run+1 or 0
  if phase~="stop" then s.max_zero_run=math.max(s.max_zero_run,r.zero_run);if d<.00001 then s.zeros=s.zeros+1 end end
  r.stats[phase]=s;r.last=p
  if r.zero_run>=60 and commanded and not r.stall_open then
   local legs={};for _,leg in ipairs(e.get_spider_legs()) do legs[#legs+1]={position=leg.position,active=leg.active} end
   r.stalls[#r.stalls+1]={tick=t,position=p,speed=e.speed,active=e.active,modifiers=e.sticker_vehicle_modifiers,legs=legs,goal=e.autopilot_destination}
   r.stall_open=true
  end
  if r.zero_run==0 then r.stall_open=nil end
  if t%60==0 then r.samples[#r.samples+1]={tick=t,position=p,speed=e.speed,orientation=e.orientation,torso=e.torso_orientation,phase=phase} end
 end
 if t==options.duration-1 then
  local rows={};local all=true;for _,r in ipairs(storage.records) do
   local valid=r.entity.valid and #r.entity.get_spider_legs()==(config.ten_leg_trial and 10 or 4) and #r.stalls==0
   all=all and valid
   storage.results[r.key]={pass=valid,detail={stalls=#r.stalls}}
   r.entity=nil;r.target=nil;r.last=nil;rows[#rows+1]=r
  end
  storage.complete=true
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=#rows,complete=true,profile="stability-physics",cases=storage.results,records=rows},false)
 end
end)
