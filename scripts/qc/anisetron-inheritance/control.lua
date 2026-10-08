local config=require("test-config")
local has_options,options=pcall(require,"options")
if has_options and options.range then require("range").install();return end
if config.visual then require("visual").install();return end
local AMMO="ei-anisetron-crystal-charge"
local PREFIX="ei-singularity-lance"
local UPGRADES={"axial-rupture","wound-memory","terminal-collapse","black-hole-testament"}
local edges=require("edges")
local function check(name,pass,detail) storage.results[name]={pass=pass==true,detail=detail} end
local function setup(tick)
 storage.start=tick;storage.actors={};storage.by_source={};storage.by_target={};storage.results={}
 local surface=game.create_surface("anisetron-inheritance",{width=4096,height=2048,water=0,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
 surface.freeze_daytime=true;surface.daytime=.05;storage.surface=surface
 local specs={
  {key="base",level=0},{key="axial",level=1},{key="wound",level=2},{key="collapse",level=3},
  {key="testament",level=4},{key="both",level=4,near=true},{key="rare",level=4,ammo_quality="rare"},
  {key="research",level=4,research=true},{key="remove-first",level=3,remove=1},
  {key="remove-eighth",level=4,remove=8},{key="phase-two-charges",level=4,charges=2},
  {key="rear-only",level=4,rear=true},
 }
 for i,spec in ipairs(specs) do
  local pos={x=-840+((i-1)%8)*240,y=-300+math.floor((i-1)/8)*240}
  surface.request_to_generate_chunks(pos,3);surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities_filtered{position=pos,radius=110,type={"unit","unit-spawner","tree","simple-entity"}}) do e.destroy() end
  local force=game.create_force("anisetron-inheritance-"..spec.key)
  force.technologies[PREFIX].researched=true
  for level=1,spec.level do force.technologies[PREFIX.."-"..UPGRADES[level]].researched=true end
  if spec.research then force.technologies["laser-weapons-damage-6"].researched=true end
  local source=surface.create_entity{name="ei-anisetron",position=pos,force=force,raise_built=true}
  source.orientation=0;source.torso_orientation=0
  source.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
  local distance=spec.near and 16 or 40
  local target=surface.create_entity{name="anisetron-inheritance-target",position={pos.x,pos.y+(spec.rear and distance or -distance)},force="enemy"}
  target.active=false
  spec.source,spec.target,spec.force=source,target,force;spec.ledger={};spec.payments=0;spec.total=0;spec.packets=0
  spec.multiplier=prototypes.quality[spec.ammo_quality or "normal"].default_multiplier*(spec.research and 1.7 or 1)
  storage.actors[#storage.actors+1]=spec;storage.by_source[source.unit_number]=spec;storage.by_target[target.unit_number]=spec
  source.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=spec.charges or 1,quality=spec.ammo_quality or "normal"}
 end
 edges.setup()
end
script.on_event(defines.events.on_script_trigger_effect,function(event)
 if event.effect_id~="ei-anisetron-charge" then return end
 local source=event.source_entity;local actor=source and source.valid and storage.by_source and storage.by_source[source.unit_number]
 if actor then actor.payments=actor.payments+1 end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
 edges.damage(event)
 local actor=storage.by_target and storage.by_target[event.entity.unit_number]
 if not actor then return end
 actor.first=actor.first or event.tick
 local row=actor.ledger[event.tick] or {damage=0,packets=0}
 row.damage=row.damage+event.original_damage_amount;row.packets=row.packets+1;actor.ledger[event.tick]=row
 actor.total=actor.total+event.original_damage_amount;actor.packets=actor.packets+1
end)
local function verify(actor)
 local expected={};local total,packets=0,0
 local function add(tick,damage)
  local row=expected[tick] or {damage=0,packets=0};row.damage=row.damage+damage;row.packets=row.packets+1;expected[tick]=row
  total=total+damage;packets=packets+1
 end
 local limit=actor.remove or 100*(actor.charges or 1)
 for i=1,limit do
  local tick=(actor.first or 0)+(i-1)*12
  local empowered=actor.level==4 and i%8==0
  local wound=actor.level>=2 and 1+math.min(i-1,5)*.2 or 1
  add(tick,320*wound*(empowered and 4 or 1)*actor.multiplier)
  if actor.near then add(tick,160*actor.multiplier) end
  if actor.level>=3 then add(tick+30,(empowered and 1280 or 640)*actor.multiplier) end
  if empowered then add(tick+60,640*actor.multiplier) end
 end
 local exact=true;local mismatches={}
 for tick,row in pairs(expected) do
  local actual=actor.ledger[tick]
  if not actual or actual.packets~=row.packets or math.abs(actual.damage-row.damage)>.01 then
   exact=false;if #mismatches<8 then mismatches[#mismatches+1]={tick=tick,expected=row,actual=actual} end
  end
 end
 for tick in pairs(actor.ledger) do if not expected[tick] then exact=false end end
 check(actor.key.."-packet-ledger",exact,mismatches)
 check(actor.key.."-total",math.abs(actor.total-total)<.1,{actual=actor.total,expected=total})
 check(actor.key.."-packet-count",actor.packets==packets,{actual=actor.packets,expected=packets})
 check(actor.key.."-native-payment",actor.payments==(actor.charges or 1),actor.payments)
 if actor.source.valid then
  check(actor.key.."-exhaustion",not actor.source.get_inventory(defines.inventory.spider_ammo)[1].valid_for_read)
  check(actor.key.."-paid-drained",remote.call("anisetron-inheritance-qc","paid",actor.source.unit_number)==nil)
 end
end
local function report()
 for _,actor in ipairs(storage.actors) do verify(actor) end
 local snapshot=remote.call("anisetron-inheritance-qc","snapshot")
 check("committed-pulses-drained",snapshot.pending==0,snapshot)
 local all,count=true,0;for _,v in pairs(storage.results) do all=all and v.pass;count=count+1 end
 local accounting={};for _,a in ipairs(storage.actors) do accounting[a.key]={damage=a.total,packets=a.packets,payments=a.payments} end
 helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=count,complete=true,
  profile="lance-inheritance",fidelity=config.fidelity,cases=storage.results,accounting=accounting},false)
end
script.on_event(defines.events.on_tick,function(event)
 if not storage.start then setup(event.tick) end
 edges.tick(event.tick)
 for _,actor in ipairs(storage.actors) do
  if actor.remove and actor.first and actor.source.valid and event.tick==actor.first+(actor.remove-1)*12+1 then actor.source.destroy{raise_destroy=true} end
 end
 if event.tick-storage.start==2550 then report() end
 if config.save and event.tick-storage.start==150 then
  helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=true,count=1,complete=true,profile="inheritance-save-seed",cases={}},false)
  game.server_save("anisetron-transition")
 end
end)
