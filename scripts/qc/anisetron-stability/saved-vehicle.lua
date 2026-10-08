-- Load and drive the user's actual damaged vehicle in an isolated save copy.
local module={}
local function inspect(e)
 local legs={};for _,v in ipairs(e.get_spider_legs()) do legs[#legs+1]={position=v.position,active=v.active,health=v.health} end
 local stickers={};for _,s in pairs(e.stickers or {}) do stickers[#stickers+1]={name=s.name,ttl=s.time_to_live} end
 local equipment={};for _,q in pairs(e.grid and e.grid.equipment or {}) do equipment[#equipment+1]={name=q.name,position=q.position,energy=q.energy,quality=q.quality.name} end
 return {id=e.unit_number,position=e.position,surface=e.surface.name,health=e.health,max_health=e.max_health,
  active=e.active,speed=e.speed,orientation=e.orientation,torso=e.torso_orientation,legs=legs,stickers=stickers,
  modifiers=e.sticker_vehicle_modifiers,equipment=equipment,quality=e.quality.name,goal=e.autopilot_destination}
end
function module.install(options)
 script.on_event(defines.events.on_tick,function(event)
  if storage.complete then return end
  if not storage.start then
   storage.start=event.tick;storage.samples={};storage.stalls={};storage.zero=0
   local candidates={};local selected
   for _,s in pairs(game.surfaces) do for _,e in pairs(s.find_entities_filtered{name="ei-anisetron"}) do
    candidates[#candidates+1]=inspect(e)
    if not selected or e.health/e.max_health<selected.health/selected.max_health then selected=e end
   end end
   assert(selected,"ASS contains no ANISETRON")
   storage.entity=selected;storage.last=selected.position
   local p=assert(game.get_player(1));storage.player=p.index
   storage.initial={vehicles=candidates,selected=selected.unit_number,player={position=p.position,controller=p.controller_type}}
   helpers.write_file("anisetron-stability/ass-initial.json",helpers.table_to_json(storage.initial),false)
   p.teleport(selected.position,selected.surface)
   if not p.character then p.set_controller{type=defines.controllers.character,character=selected.surface.create_entity{name="character",position=selected.position,force=selected.force}} end
   selected.set_driver(p);selected.autopilot_destination=nil
  end
  local t=event.tick-storage.start;local e=storage.entity;local p=game.get_player(storage.player)
  if not e.valid then error("Actual ASS vehicle died during probe") end
  local direction=((options.direction_offset or 0)+math.floor(t/(options.sustained and 1800 or 300))%8)*2%16
  p.walking_state={walking=options.sustained or t%300<270,direction=direction}
  if options.sustained and e.health<100 then e.health=471 end
  local xy=e.position;local dx,dy=xy.x-storage.last.x,xy.y-storage.last.y;local d=math.sqrt(dx*dx+dy*dy)
  storage.zero=p.walking_state.walking and d<.00001 and storage.zero+1 or 0
  if storage.zero==60 then local row=inspect(e);row.tick=t;row.direction=direction;storage.stalls[#storage.stalls+1]=row end
  if t%10==0 then local row=inspect(e);row.tick=t;row.direction=direction;row.displacement=d;storage.samples[#storage.samples+1]=row end
  storage.last=xy
  if t==options.duration-1 then
   storage.complete=true
   helpers.write_file("anisetron-qc.json",helpers.table_to_json{profile="saved-vehicle",complete=true,
    count=1,all_pass=#storage.stalls==0,cases={manual_saved_vehicle={pass=#storage.stalls==0}},
    initial=storage.initial,stalls=storage.stalls,samples=storage.samples},false)
  end
 end)
end
return module
