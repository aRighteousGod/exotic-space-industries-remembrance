-- Genuine engine captures on separate day/night surfaces; no screenshot lighting overrides.
local config=require("test-config")
local has_options,options=pcall(require,"options")
local module={}
local function setup(tick)
 storage.art={start=tick,scenes={},frames={},results={}}
 local force=game.create_force("anisetron-inheritance-art")
 for _,suffix in ipairs{"","-axial-rupture","-wound-memory","-terminal-collapse","-black-hole-testament"} do force.technologies["ei-singularity-lance"..suffix].researched=true end
 for _,light in ipairs{"day","night"} do
  local surface=game.create_surface("inheritance-art-"..light,{water=0,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
  surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities()) do e.destroy() end;surface.destroy_decoratives{}
  local tiles={};for x=-60,120 do for y=-60,80 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
  surface.always_day=false;surface.freeze_daytime=true;surface.daytime=light=="day" and 0 or .5
  local scene={surface=surface,light=light}
  scene.fire=surface.create_entity{name="ei-anisetron",position={0,0},force=force,raise_built=true}
  scene.fire.orientation=.5;scene.fire.torso_orientation=.5
  scene.fire.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  local target=surface.create_entity{name="anisetron-inheritance-target",position={0,14},force="enemy"};target.active=false;scene.front=target
  scene.rear=surface.create_entity{name="anisetron-inheritance-target",position={0,-20},force="enemy"};scene.rear.active=false
  for _,p in ipairs{{0,20},{0,25},{3,25},{-3,25}} do local e=surface.create_entity{name="anisetron-inheritance-target",position=p,force="enemy"};e.active=false end
  scene.fire.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1}
  scene.motion=surface.create_entity{name="ei-anisetron",position={75,0},force=force,raise_built=true}
  scene.motion.orientation=.5;scene.motion.torso_orientation=.5;scene.motion.autopilot_destination={75,40}
  surface.request_to_generate_chunks({200,0},2);surface.force_generate_chunk_requests()
  scene.split=surface.create_entity{name="ei-anisetron",position={200,0},force=force,raise_built=true}
  scene.split.orientation=.5;scene.split.torso_orientation=.5
  scene.split.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  for _,y in ipairs{-12,14} do local e=surface.create_entity{name="anisetron-inheritance-target",position={200,y},force="enemy"};e.active=false end
  scene.split.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=1}
  storage.art.scenes[#storage.art.scenes+1]=scene
 end
end
function module.install()
 script.on_event(defines.events.on_tick,function(event)
  if not storage.art then setup(event.tick) end
  local a=storage.art;local t=event.tick-a.start
  if has_options and options.strand_layer then remote.call("anisetron-inheritance-qc","strand_layer",options.strand_layer) end
  if t==180 then for _,s in ipairs(a.scenes) do s.motion.autopilot_destination={110,s.motion.position.y} end end
  if t==280 then for _,s in ipairs(a.scenes) do s.motion.autopilot_destination=nil end end
  if t==160 or t==300 then
   for _,s in ipairs(a.scenes) do
    local path=string.format("inheritance-art/split-%s/%03d.png",s.light,t==160 and 1 or 2)
    game.take_screenshot{surface=s.surface,position={200,-4},resolution={1024,1280},zoom=1,path=path,
     show_gui=false,show_entity_info=false,anti_alias=true,force_render=true}
    a.frames[#a.frames+1]={path=path,tick=event.tick,role="split",light=s.light,daytime=s.surface.daytime,
     position=s.split.position,orientation=s.split.torso_orientation,speed=s.split.speed,
     paid=remote.call("anisetron-inheritance-qc","paid",s.split.unit_number)}
   end
  end
  if t>=96 and t<=400 and (t-96)%8==0 then
   for _,s in ipairs(a.scenes) do
    local index=(t-96)/8+1
    for _,role in ipairs{"fire","motion"} do
     local e=s[role];local p=e.position
     local position=role=="fire" and {0,5} or {p.x,p.y-3}
     local path=string.format("inheritance-art/%s-%s/%03d.png",role,s.light,index)
     game.take_screenshot{surface=s.surface,position=position,resolution=role=="fire" and {1024,1024} or {768,768},zoom=1,
      path=path,show_gui=false,show_entity_info=false,anti_alias=true,force_render=true}
     a.frames[#a.frames+1]={path=path,tick=event.tick,role=role,light=s.light,daytime=s.surface.daytime,
      position=p,orientation=e.torso_orientation,speed=e.speed,paid=role=="fire" and remote.call("anisetron-inheritance-qc","paid",e.unit_number) or nil}
    end
   end
  end
  if t==410 then
   for _,s in ipairs(a.scenes) do
    local paid=remote.call("anisetron-inheritance-qc","paid",s.fire.unit_number)
    a.results[s.light.."-upgraded-native-charge"]={pass=paid and paid.version==3 and paid.level==4 or false,detail=paid}
   end
   local all=true;for _,v in pairs(a.results) do all=all and v.pass end
   helpers.write_file("inheritance-art/captures.json",helpers.table_to_json{frames=a.frames,fidelity=config.fidelity,zoom=1},false)
   helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=2,complete=true,profile="inheritance-art",fidelity=config.fidelity,cases=a.results},false)
  end
 end)
end
return module
