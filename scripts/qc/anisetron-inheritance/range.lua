-- Cardinal/diagonal native manual and automatic boundary matrix, from one copied player.
local module={}
local options=require("options")
local function check(key,pass,detail) storage.range.results[key]={pass=pass==true,detail=detail} end
local function location(actor,margin)
 local a,b=actor.source.bounding_box,actor.target.bounding_box
 local hx=(a.right_bottom.x-a.left_top.x+b.right_bottom.x-b.left_top.x)/2
 local hy=(a.right_bottom.y-a.left_top.y+b.right_bottom.y-b.left_top.y)/2
 local ux,uy=math.sin(actor.heading*math.pi/4),-math.cos(actor.heading*math.pi/4)
 local reach=85*actor.source.quality.range_multiplier+margin
 local lo,hi=0,200
 for _=1,50 do
  local mid=(lo+hi)/2;local dx,dy=math.max(0,math.abs(ux*mid)-hx),math.max(0,math.abs(uy*mid)-hy)
  if dx*dx+dy*dy>reach*reach then hi=mid else lo=mid end
 end
 return {x=actor.source.position.x+ux*(lo+hi)/2,y=actor.source.position.y+uy*(lo+hi)/2}
end
local function start(tick)
 local state=storage.range;state.index=state.index+1
 local actor=state.cases[state.index]
 if not actor then
  local all,count=true,0;for _,v in pairs(state.results) do all=all and v.pass;count=count+1 end
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=count,complete=true,profile="inheritance-native-range",cases=state.results},false)
  state.done=true;return
 end
 state.actor=actor;actor.start=tick;actor.payments=0;actor.packets=0;actor.exact=true
 actor.source=state.surface.create_entity{name="ei-anisetron",position={actor.offset or 0,actor.offset or 0},force=state.force,quality=actor.vehicle,raise_built=true}
 actor.source.orientation=actor.heading/8;actor.source.torso_orientation=actor.heading/8
 actor.source.vehicle_automatic_targeting_parameters={auto_target_without_gunner=not actor.manual,auto_target_with_gunner=not actor.manual}
 actor.target=state.surface.create_entity{name=actor.structure and "anisetron-inheritance-large-structure" or actor.large and "anisetron-inheritance-large-target" or "anisetron-inheritance-target",position={0,-150},force="enemy"}
 actor.target.active=false;actor.target.teleport(location(actor,actor.cold and -.25 or .25))
 actor.source.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1,quality=actor.ammo}
 if actor.manual then state.player.teleport({0,0},state.surface);actor.source.set_driver(state.player);actor.source.driver_is_gunner=true end
end
local function setup(tick)
 local state={index=0,cases={},results={}};storage.range=state
 state.surface=game.create_surface("inheritance-range",{width=512,height=512,water=0,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
 state.surface.request_to_generate_chunks({0,0},6);state.surface.force_generate_chunk_requests()
 for _,e in pairs(state.surface.find_entities()) do e.destroy() end
 local tiles={};for x=-170,170 do for y=-170,170 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end;state.surface.set_tiles(tiles)
 state.force=game.create_force("inheritance-range-force")
 state.player=assert(game.players[1],"Copied player seed required")
 state.player.driving=false;state.player.force=state.force;state.player.teleport({0,0},state.surface)
 if not state.player.character then state.player.set_controller{type=defines.controllers.god};state.player.create_character() end
 state.player.set_controller{type=defines.controllers.character,character=state.player.character}
 state.player.get_inventory(defines.inventory.character_ammo).clear();state.player.get_inventory(defines.inventory.character_guns).clear()
 for _,manual in ipairs{false,true} do for _,large in ipairs{false,true} do
  for _,vehicle in ipairs{"normal","rare"} do for _,ammo in ipairs{"normal","rare"} do for heading=0,7 do
   state.cases[#state.cases+1]={manual=manual,large=large,vehicle=vehicle,ammo=ammo,heading=heading,
    key=(manual and "manual" or "auto").."-"..(large and "large" or "small").."-"..vehicle.."-"..ammo.."-"..heading}
  end end end
 end end
 if options.probe then
  state.cases={}
  for _,offset in ipairs{0,16,32} do for _,kind in ipairs{"warm","cold","structure"} do
   state.cases[#state.cases+1]={manual=false,large=true,vehicle="normal",ammo="normal",heading=1,
    offset=offset,cold=kind=="cold",structure=kind=="structure",key=kind.."-offset-"..offset}
  end end
 end
 start(tick)
end
function module.install()
 script.on_event(defines.events.on_script_trigger_effect,function(event)
  local a=storage.range and storage.range.actor
  if a and event.effect_id=="ei-anisetron-charge" and event.source_entity==a.source then a.payments=a.payments+1 end
 end)
 script.on_event(defines.events.on_entity_damaged,function(event)
  local a=storage.range and storage.range.actor
  if a and event.entity==a.target then a.packets=a.packets+1;a.exact=a.exact and math.abs(event.original_damage_amount-320*prototypes.quality[a.ammo].default_multiplier)<.01 end
 end)
 script.on_event(defines.events.on_tick,function(event)
  if not storage.range then setup(event.tick) end
  local s=storage.range;if s.done then return end
  local a=s.actor;local t=event.tick-a.start
  if a.manual then s.player.shooting_state={state=defines.shooting.shooting_enemies,position=a.target.position} end
  if t==39 and not a.cold then check(a.key.."-outside",a.payments==0 and a.packets==0,{payments=a.payments,packets=a.packets})
  elseif t==40 then a.target.teleport(location(a,-.25))
  elseif t==(options.probe and 245 or 95) then
   local paid=remote.call("anisetron-inheritance-qc","paid",a.source.unit_number)
   check(a.key.."-inside",a.payments==1 and a.packets>0 and a.exact,{payments=a.payments,packets=a.packets,exact=a.exact,
    source=a.source.position,target=a.target.position,source_box=a.source.bounding_box,target_box=a.target.bounding_box,orientation=a.source.torso_orientation})
   check(a.key.."-snapshot",paid and paid.version==3 and paid.crown_range==85*a.source.quality.range_multiplier and paid.facade_range==30,paid)
   s.player.shooting_state={state=defines.shooting.not_shooting,position={0,0}};s.player.driving=false
   a.source.destroy{raise_destroy=true};a.target.destroy();start(event.tick)
  end
 end)
end
return module
