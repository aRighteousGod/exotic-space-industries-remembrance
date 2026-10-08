local config=require("test-config")
local options=require("options")
local IFACE="anisetron-hover-qc"
local AMMO="ei-anisetron-crystal-charge"
local SLOWS={"acid-sticker-small","acid-sticker-medium","acid-sticker-big","acid-sticker-behemoth","tb-fire-sticker","cb-cold-sticker","eb-fire-sticker","demolisher-ash-sticker","small-acid-sticker-stomper","medium-acid-sticker-stomper","big-acid-sticker-stomper"}
local function check(name,pass,detail) storage.results[name]={pass=pass==true,detail=detail} end
local function near(a,b) return math.abs(a-b)<.001 end
local function paid(e) return remote.call(IFACE,"paid",e.unit_number) end
local function report()
 local all,n=true,0;for _,v in pairs(storage.results) do all=all and v.pass;n=n+1 end
 helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=n,complete=true,profile="hover-combat",fidelity=config.fidelity,cases=storage.results,movement=storage.motion_results,colors=storage.colors},false)
end
local function setup(tick)
 storage.start=tick;storage.results={};storage.actors={};storage.by_unit={};storage.movers={};storage.colors={}
 local surface=game.create_surface("anisetron-hover-combat",{width=2048,height=1024,water=0,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
 surface.request_to_generate_chunks({0,0},16);surface.force_generate_chunk_requests();storage.surface=surface
 for _,e in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","tree","simple-entity"}}) do e.destroy() end
 local specs={{key="base",level=5},{key="six",level=6},{key="seven",level=7},{key="eight",level=8},{key="rare",level=6,quality="rare"},{key="midburst",level=5,charges=2}}
 for i,spec in ipairs(specs) do
  local force=game.create_force("anisetron-laser-"..spec.key)
  for level=1,math.min(6,spec.level) do force.technologies["laser-weapons-damage-"..level].researched=true end
  if spec.level>=7 then force.technologies["laser-weapons-damage-7"].level=spec.level+1 end
  force.set_ammo_damage_modifier("bullet",.123) -- migration sentinel, unrelated to either laser category
  local modifier=force.get_ammo_damage_modifier("ei-anisetron-crystal")
  local expected=options.old_category and 0 or math.max(0,spec.level-5)*.7
  check(spec.key.."-native-research-modifier",near(modifier,expected),modifier)
  local e=surface.create_entity{name="ei-anisetron",position={-240+(i-1)*90,-100},force=force,raise_built=true}
  e.orientation=0;e.torso_orientation=0
  e.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  local enemy=surface.create_entity{name="anisetron-hover-qc-target",position={e.position.x,e.position.y-16},force="enemy"};enemy.active=false
  if config.visual then
   local rear=surface.create_entity{name="anisetron-hover-qc-target",position={e.position.x-13,e.position.y+6},force="enemy"};rear.active=false
  end
  local record={key=spec.key,entity=e,target=enemy,force=force,level=spec.level,quality=spec.quality or "normal",charges=spec.charges or 1,total=0,hits=0,payments=0,colors={}}
  storage.actors[#storage.actors+1]=record;storage.by_unit[e.unit_number]=record
  e.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=record.charges,quality=record.quality}
 end
 for i,key in ipairs{"clear","damaging-stack","silent-stack","silent-stack-equipped"} do
  local force=storage.actors[1].force
  local e=surface.create_entity{name="ei-anisetron",position={-150,i*50},force=force,raise_built=true}
  e.orientation=.25;e.torso_orientation=.25;e.autopilot_destination={900,e.position.y}
  if i==4 then
   for _,p in ipairs{{0,0},{4,0}} do local eq=e.grid.put{name="fusion-reactor-equipment",position=p};eq.energy=100000000 end
   for _,p in ipairs{{8,0},{10,0},{0,4},{2,4},{4,4},{6,4},{8,4},{10,4}} do local eq=e.grid.put{name="exoskeleton-equipment",position=p};eq.energy=100000000 end
  end
  storage.movers[#storage.movers+1]={key=key,entity=e,last=e.position,phases={}}
 end
end
script.on_event(defines.events.on_entity_damaged,function(event)
 local source=event.cause;local actor=source and source.valid and storage.by_unit and storage.by_unit[source.unit_number]
 if actor and event.entity==actor.target then
  actor.total=actor.total+event.final_damage_amount;actor.hits=actor.hits+1
  local record=paid(source)
  local expected_multiplier=options.old_category and 1 or 1+math.max(0,actor.level-5)*.7
  if actor.key=="midburst" and actor.payments==1 then expected_multiplier=1 end
  if config.loaded and actor.payments==1 then expected_multiplier=1 end
  local quality=prototypes.quality[actor.quality].default_multiplier
  local ok=near(event.original_damage_amount,320*quality*expected_multiplier) or near(event.original_damage_amount,160*quality*expected_multiplier)
  check(actor.key.."-exact-packets",ok and (not storage.results[actor.key.."-exact-packets"] or storage.results[actor.key.."-exact-packets"].pass),{amount=event.original_damage_amount,paid=record})
 end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
 if event.effect_id~="ei-anisetron-charge" then return end
 local source=event.source_entity or event.cause_entity;local actor=source and source.valid and storage.by_unit and storage.by_unit[source.unit_number]
 if actor then actor.payments=actor.payments+1 end
end)
script.on_event(defines.events.on_research_finished,function(event)
 if event.research.name=="laser-weapons-damage-6" then
  storage.research_event={by_script=event.by_script,tick=event.tick}
 end
end)
script.on_event(defines.events.on_tick,function(event)
 if config.save and storage.saved then return end
 if storage.done and not config.loaded then return end
 if not storage.start then setup(event.tick) end
 if config.loaded and not storage.reloaded then
  storage.reloaded=event.tick
  for _,a in ipairs(storage.actors) do
   check(a.key.."-restored-research-effects",near(a.force.get_ammo_damage_modifier("ei-anisetron-crystal"),a.force.get_ammo_damage_modifier("ei-singularity-lance")))
   -- Factorio reconciles force effects at the configuration boundary. Observe
   -- that native result; arbitrary script modifiers are not a load guarantee.
   a.loaded_bullet=a.force.get_ammo_damage_modifier("bullet")
   local current=paid(a.entity)
   check(a.key.."-old-paid-values-preserved",current and current.end_tick==a.saved.end_tick and current.crown_damage==a.saved.crown_damage and current.facade_damage==a.saved.facade_damage,current)
   if a.key~="midburst" then a.entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=1,quality=a.quality};a.charges=2 end
  end
  for _,a in ipairs(storage.actors) do a.force.set_ammo_damage_modifier("bullet",.123) end
  remote.call(IFACE,"rebuild")
  for _,a in ipairs(storage.actors) do
   check(a.key.."-feature-rebuild-preserves-custom-modifier",near(a.force.get_ammo_damage_modifier("bullet"),.123),{native_loaded=a.loaded_bullet,current=a.force.get_ammo_damage_modifier("bullet")})
  end
 end
 local t=event.tick-storage.start
 if t==100 then
  local a=storage.actors[6];a.saved=paid(a.entity)
  local research=a.force.technologies["laser-weapons-damage-6"]
  local lab=storage.surface.create_entity{name="anisetron-hover-qc-lab",position={a.entity.position.x+10,a.entity.position.y+10},force=a.force}
  for _,ingredient in ipairs(research.research_unit_ingredients) do lab.insert{name=ingredient.name,count=10} end
  a.force.add_research(research);a.force.research_progress=.999999;a.level=6
  local after=paid(a.entity)
  check("research-does-not-reprice-paid-burst",after.crown_damage==a.saved.crown_damage and after.facade_damage==a.saved.facade_damage and after.end_tick==a.saved.end_tick)
 end
 if t<1200 then
  for _,a in ipairs(storage.actors) do
   local p=paid(a.entity)
   for channel,v in pairs(p and p.channels or {}) do
    if v.color then
     storage.colors[tostring(v.color)]=true
     check(a.key.."-"..channel.."-native-palette",v.beam and v.beam:find("%-light%-"..v.color.."$")~=nil,v)
     if a.colors[channel] then check(a.key.."-"..channel.."-stable-color",a.colors[channel]==v.color) else a.colors[channel]=v.color end
    end
   end
  end
 end
 for i,r in ipairs(storage.movers) do
  local e=r.entity;e.health=e.max_health
  -- Supply a controlled full grid throughout the fixture. Initial equipment
  -- energy alone would expire and accidentally compare unpowered exoskeletons.
  if i==4 then for _,equipment in pairs(e.grid.equipment) do equipment.energy=100000000 end end
  if t>=400 and t<1600 and t%20==0 and i>1 then
   for _,name in ipairs(SLOWS) do e.surface.create_entity{name=name,position=e.position,target=e,force="enemy"} end
   if i==2 then e.damage(1,"enemy","physical") end
  end
  local p=e.position;local distance=math.sqrt((p.x-r.last.x)^2+(p.y-r.last.y)^2);r.last=p
  if t>250 then
   local phase=t<400 and "baseline" or t<1800 and "attack" or "recovery"
   local stats=r.phases[phase] or {count=0,distance=0,zero=0,run=0,max_zero=0}
   stats.count=stats.count+1;stats.distance=stats.distance+distance;stats.run=distance<.00001 and stats.run+1 or 0
   stats.zero=stats.zero+(distance<.00001 and 1 or 0);stats.max_zero=math.max(stats.max_zero,stats.run);r.phases[phase]=stats
  end
 end
 if config.visual and (t==160 or t==164) then
  storage.captures=storage.captures or {}
  for _,a in ipairs(storage.actors) do
   local path="anisetron-art/laser-"..a.key..(t==160 and "-day.png" or "-night.png")
   game.take_screenshot{surface=storage.surface,position={a.entity.position.x-4,a.entity.position.y-5},resolution={768,960},zoom=1,daytime=t==160 and 0 or .5,
    path=path,show_gui=false,show_entity_info=false,anti_alias=true,force_render=true}
   storage.captures[#storage.captures+1]={path=path,paid=paid(a.entity),daytime=t==160 and 0 or .5}
  end
  helpers.write_file("anisetron-art/hover-captures.json",helpers.table_to_json(storage.captures),false)
 end
 if config.save and t==300 then
  storage.saved=true
  for _,a in ipairs(storage.actors) do a.saved=paid(a.entity);a.saved_bullet=a.force.get_ammo_damage_modifier("bullet") end
  check("old-category-seed",options.old_category);report();game.server_save("anisetron-transition")
 elseif (not config.save and not config.visual and t==2450) or (config.visual and t==220) then
  if not config.visual then
   for _,a in ipairs(storage.actors) do
    local mult=options.old_category and 1 or 1+math.max(0,a.level-5)*.7
    local q=prototypes.quality[a.quality].default_multiplier
    local expected=48000*q*(a.key=="midburst" and (1+mult) or config.loaded and (1+mult) or mult)
    -- Native damage packets are float32; accumulated error stays below .01.
    check(a.key.."-paid-damage-total",math.abs(a.total-expected)<.01 and a.hits==a.charges*200,{damage=a.total,expected=expected,hits=a.hits})
    check(a.key.."-exhaustion",not a.entity.get_inventory(defines.inventory.spider_ammo)[1].valid_for_read and paid(a.entity)==nil)
   end
   storage.motion_results={}
   for _,r in ipairs(storage.movers) do
    check(r.key.."-no-sustained-stop",r.phases.attack.max_zero<=4,r.phases)
    check(r.key.."-recovery",r.phases.recovery.distance/r.phases.recovery.count>r.phases.baseline.distance/r.phases.baseline.count*.9)
    storage.motion_results[r.key]=r.phases
   end
   local snapshot=remote.call(IFACE,"mobility")
   if not config.loaded then
    local bare=storage.movers[1].phases.baseline
    local powered=storage.movers[4].phases.baseline
    check("equipped-movement-actually-powered",powered.distance/powered.count>1.5*bare.distance/bare.count,{bare=bare.distance/bare.count,powered=powered.distance/powered.count})
   end
   check("ordinary-native-research-completed",storage.research_event and storage.research_event.by_script==false,storage.research_event)
   check("healthy-registry-retained",snapshot.registered==10 and snapshot.affected==0 and snapshot.compensated==0,snapshot)
  end
  local colors=0;for _ in pairs(storage.colors) do colors=colors+1 end
  check("multiple-random-glow-colors",colors>=3,storage.colors)
  storage.done=true;report()
 end
end)
