-- Actual paid emitters and native-motion trails, across compass headings.
local config=require("test-config")
local options=require("options")
local module={}
local function offset(p,h,d)
 local a=h*math.pi*2;return {x=p.x+math.sin(a)*d,y=p.y-math.cos(a)*d}
end
local function target(surface,p)
 local e=surface.create_entity{name="anisetron-stability-target",position=p,force="enemy"};e.active=false;return e
end
local function setup(tick)
 storage.start=tick;storage.records={};storage.frames={};storage.trace={};storage.results={}
 local force=game.create_force("anisetron-stability-art")
 for _,light in ipairs{"day","night"} do
  local surface=game.create_surface("anisetron-stability-art-"..light,{water=0,
   cliff_settings={cliff_elevation_interval=0},autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
  surface.request_to_generate_chunks({0,0},15);surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities()) do e.destroy() end;surface.destroy_decoratives{}
  surface.freeze_daytime=true;surface.daytime=light=="day" and 0 or .5
  for heading=0,7 do for _,role in ipairs{"beam","motion"} do
   local h=heading/8;local p={x=(heading%4)*120-180,y=math.floor(heading/4)*200-150+(role=="motion" and 90 or 0)}
   local e=surface.create_entity{name="ei-anisetron",position=p,force=force,raise_built=true};e.orientation=h;e.torso_orientation=h
   e.vehicle_automatic_targeting_parameters={auto_target_without_gunner=role=="beam",auto_target_with_gunner=role=="beam"}
   local r={entity=e,key=role.."-"..light.."-h"..heading,heading=h,light=light,role=role}
   storage.records[#storage.records+1]=r
   if role=="beam" then
    r.rear=target(surface,offset(p,h,-10))
    e.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1}
    if options.moving_emitters then e.autopilot_destination=offset(p,h,120) end
   else e.autopilot_destination=offset(p,h,120) end
  end end
 end
 local player=assert(game.get_player(1));player.force=force;player.set_controller{type=defines.controllers.spectator}
 player.teleport({0,0},storage.records[1].entity.surface)
end
local function snapshot(r,t)
 local e=r.entity;local p=e.position
 local status=remote.call("anisetron-stability-qc","snapshot",e.unit_number)
 return {key=r.key,tick=t,position=p,torso=e.torso_orientation,speed=e.speed,role=r.role,light=r.light,
  owner={burst=status.channels},strands=status.strands,moving=status.moving,
  targets=r.front and {front=r.front.position,rear=r.rear.position} or nil}
end
function module.install()
 script.on_event(defines.events.on_tick,function(event)
  if storage.complete then return end
  if not storage.start then setup(event.tick) end
  local t=event.tick-storage.start
  for _,r in ipairs(storage.records) do
   local e=r.entity
   if t==20 and r.role=="beam" then r.front=target(e.surface,offset(e.position,r.heading,13)) end
   if options.moving_emitters and r.role=="beam" then
    r.rear.teleport(offset(e.position,e.torso_orientation,-10))
    if r.front then r.front.teleport(offset(e.position,e.torso_orientation,13)) end
    if t==300 then e.autopilot_destination=offset(e.position,r.heading+.25,120) end
    if t==420 then e.autopilot_destination=nil end
   end
   if t==420 and r.role=="motion" then e.autopilot_destination=nil end
   local row=snapshot(r,t);storage.trace[#storage.trace+1]=row
   local capture=r.role=="motion" and not options.moving_emitters and t>=180 and t<=600 and t%12==0
    or r.role=="beam" and (t==120 or t==240 or t==480 or options.moving_emitters and
     (t==301 or t==308 or t==320 or t==336 or t==356 or t==376 or t==400 or t==420 or t==440))
   if capture then
    row.path=string.format("anisetron-stability/%s/%04d.png",r.key,t)
    local p=e.position
    row.camera={position={p.x,p.y-(r.role=="beam" and 2 or 3)},resolution=r.role=="beam" and {1024,1280} or {512,512},zoom=1}
    game.take_screenshot{surface=e.surface,position=row.camera.position,resolution=row.camera.resolution,zoom=1,path=row.path,
     show_gui=false,show_entity_info=false,anti_alias=false,force_render=true}
    storage.frames[#storage.frames+1]=row
   end
  end
  if t==610 then
   local all=true
   for _,r in ipairs(storage.records) do
    local s=remote.call("anisetron-stability-qc","snapshot",r.entity.unit_number)
    local pass=r.role=="beam" and s.channels.crown and s.channels.crown.beam and s.channels.facade and s.channels.facade.beam
     or r.role=="motion" and not s.moving
    storage.results[r.key]={pass=pass==true};all=all and pass
   end
   storage.complete=true
   helpers.write_file("anisetron-stability/captures.json",helpers.table_to_json{frames=storage.frames,trace=storage.trace,fidelity=config.fidelity},false)
   helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=#storage.frames,complete=true,profile="stability-art",cases=storage.results},false)
  end
 end)
end
return module
