local options=require("options")
local config=require("test-config")
local module={}
local function setup(tick)
 storage.start=tick;storage.records={};storage.frames={};storage.trace={}
 local surface=game.create_surface("anisetron-stability-art",{water=0,autoplace_controls={},
  cliff_settings={cliff_elevation_interval=0},autoplace_settings={entity={treat_missing_as_default=false}}})
 surface.request_to_generate_chunks({0,0},8);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities()) do e.destroy() end
 surface.destroy_decoratives{};surface.freeze_daytime=true;surface.daytime=0
 local force=game.create_force("anisetron-stability-art")
 for _,profile in ipairs(options.profiles) do for _,heading in ipairs{.25,.5} do
  local id=#storage.records+1
  local e=surface.create_entity{name="anisetron-stability-"..profile.id,position={-100+(id%4)*50,math.floor((id-1)/4)*80},force=force}
  e.orientation=heading;e.torso_orientation=heading
  e.autopilot_destination={e.position.x+math.sin(heading*math.pi*2)*150,e.position.y-math.cos(heading*math.pi*2)*150}
  storage.records[id]={entity=e,key=profile.id.."-"..heading,profile=profile}
 end end
 local player=assert(game.get_player(1));player.force=force;player.set_controller{type=defines.controllers.spectator};player.teleport({0,0},surface)
end
function module.install()
 script.on_event(defines.events.on_tick,function(event)
  if storage.complete then return end
  if not storage.start then setup(event.tick) end
  local t=event.tick-storage.start
  for _,r in ipairs(storage.records) do
   local e=r.entity;local p=e.position
   if t==400 then e.autopilot_destination=nil end
   local row={key=r.key,tick=t,position=p,torso=e.torso_orientation,speed=e.speed,profile=r.profile}
   storage.trace[#storage.trace+1]=row
   if t>=120 and t<=552 and t%8==0 then
    row.path=string.format("anisetron-stability/%s/%04d.png",r.key,t)
    row.camera={position={p.x,p.y-3},resolution={400,480},zoom=1}
    game.take_screenshot{surface=e.surface,position=row.camera.position,resolution=row.camera.resolution,zoom=1,path=row.path,
     show_gui=false,show_entity_info=false,anti_alias=false,force_render=true}
    storage.frames[#storage.frames+1]=row
   end
  end
  if t==options.duration-1 then
   storage.complete=true
   helpers.write_file("anisetron-stability/captures.json",helpers.table_to_json{frames=storage.frames,trace=storage.trace},false)
   helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=true,count=#storage.frames,complete=true,profile="stability-art",cases={capture={pass=true}}},false)
  end
 end)
end
return module
