-- Opt-in QC only. Observe real keyboard input; never write movement or vehicle state.
local function finish(reason)
 local trace=storage.trace
 if not trace then return end
 trace.reason=reason;trace.entity=nil
 helpers.write_file("anisetron-motion-trace.json",helpers.table_to_json(trace),false)
 local player=game.get_player(trace.player)
 if player then player.print("ANISETRON trace saved: script-output/anisetron-motion-trace.json") end
 storage.trace=nil;script.on_event(defines.events.on_tick,nil)
end
local function sample(event)
 local trace=storage.trace
 if not trace then return end
 local e=trace.entity;local p=game.get_player(trace.player)
 if not(e and e.valid and p) then finish("source unavailable");return end
 local legs={};for _,leg in ipairs(e.get_spider_legs()) do legs[#legs+1]={position=leg.position,active=leg.active} end
 local stickers={};for _,s in pairs(e.stickers or {}) do if s.valid then stickers[#stickers+1]={name=s.name,ttl=s.time_to_live} end end
 local driver=e.get_driver()
 trace.frames[#trace.frames+1]={tick=event.tick,position=e.position,speed=e.speed,active=e.active,
  health=e.health,surface=e.surface.index,orientation=e.orientation,torso=e.torso_orientation,
  walking=p.walking_state,riding=p.riding_state,driving=p.driving,
  driver=driver and driver.valid and driver.object_name or false,
  autopilot=e.autopilot_destination,modifiers=e.sticker_vehicle_modifiers,legs=legs,stickers=stickers}
 if #trace.frames>=trace.limit then finish("complete") end
end
local function begin(command)
 local p=command.player_index and game.get_player(command.player_index)
 if not(p and p.admin) then return end
 if command.parameter=="stop" then finish("stopped by administrator");return end
 if storage.trace then p.print("A trace is already recording. Use /anisetron-motion-trace stop to finish it.");return end
 local e=p.vehicle
 if not(e and e.valid and e.name=="ei-anisetron") then
  local nearest
  for _,candidate in pairs(p.surface.find_entities_filtered{name="ei-anisetron",position=p.position,radius=20}) do
   local distance=(candidate.position.x-p.position.x)^2+(candidate.position.y-p.position.y)^2
   if not nearest or distance<nearest then nearest=distance;e=candidate end
  end
 end
 if not(e and e.valid and e.name=="ei-anisetron") then p.print("Enter ANISETRON or stand within 20 tiles of it.");return end
 local equipment={};for _,item in pairs(e.grid and e.grid.equipment or {}) do
  equipment[#equipment+1]={name=item.name,position=item.position,quality=item.quality.name,energy=item.energy}
 end
 storage.trace={entity=e,player=p.index,unit_number=e.unit_number,start=command.tick,
  limit=math.max(60,math.min(12000,math.floor(tonumber(command.parameter) or 7200))),
  quality=e.quality.name,equipment=equipment,frames={}}
 script.on_event(defines.events.on_tick,sample)
 p.print("Recording ANISETRON for up to "..storage.trace.limit.." ticks. Drive normally; input and movement are not modified.")
end
commands.add_command("anisetron-motion-trace","Record nearby ANISETRON movement without controlling it. Optional length in ticks (60-12000); stop ends the trace.",begin)
script.on_load(function() if storage.trace then script.on_event(defines.events.on_tick,sample) end end)
return {begin=begin}
