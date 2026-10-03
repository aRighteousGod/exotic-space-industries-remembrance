local world=require("scripts/control/admin/world")
local effects=require("scripts/control/fluid-rupture-effects")
local rupture_scheduler=require("scripts/control/flammable-rupture-scheduler")
local scheduler=require("lib/runtime-scheduler")
local loaded=false
local function report()
    helpers.write_file("admin-world-results.json",helpers.table_to_json(storage.qc),false)
end
local function check(value,name,detail)
    storage.qc.checks=storage.qc.checks+1
    if not value then
        storage.qc.failures[#storage.qc.failures+1]={name=name,detail=tostring(detail)}
        log("ADMIN_WORLD_FAIL "..name.." "..tostring(detail))
    end
end
local function action(actor,name,args,tick,wanted)
    local ok,message,id=world.execute(actor,name,args,tick)
    check(ok==(wanted~=false),name,message)
    return id,message
end
world.configure{
 enabled=function()return true end,
 state=function() storage.ei=storage.ei or {};storage.ei.admin_tools=storage.ei.admin_tools or {};return storage.ei.admin_tools end,
 notify=function(_,message)log(message)end,changed=function()end,
 resolve_surface=function(name)return game.surfaces[name]end,
 rupture_effects=effects
}
script.on_init(function()storage.qc={checks=0,failures={},phase="setup",chunk_events=0,chart_events=0}end)
script.on_load(function()loaded=true end)
script.on_event(defines.events.on_chunk_generated,function(e)
 world.on_chunk_generated(e)
 if storage.qc then storage.qc.chunk_events=storage.qc.chunk_events+1 end
end)
script.on_event(defines.events.on_chunk_charted,function(e)
 world.on_chunk_charted(e)
 if storage.qc then storage.qc.chart_events=storage.qc.chart_events+1 end
end)
script.on_event(defines.events.on_surface_created,world.on_surface_created)
script.on_event(defines.events.on_surface_deleted,world.on_surface_deleted)
script.on_event(defines.events.on_biter_base_built,world.on_biter_base_built)
script.on_event(defines.events.script_raised_destroy,function(event)
 local probe=storage.qc and storage.qc.destroy_probe
 if not probe or probe.converted then return end
 local other=event.entity==probe.first and probe.second or event.entity==probe.second and probe.first
 if other and other.valid then
  if probe.mode=="friend"then probe.force.set_friend(game.forces.player,true)
  else other.force=game.forces.player end
  probe.converted=other
 end
end)
local function setup(tick)
 storage.qc.started_tick=tick
 game.speed=64
 check(not world.has_tick_work(),"pure inactive gate")
 world.peek_summary()
 check(not (storage.ei and storage.ei.admin_tools),"peek avoids state initialization")
 storage.ei={admin_tools={}}
 local surface=game.create_surface("admin-world-qc",{water="none",autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
 storage.qc.surface=surface
 surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
 local tiles={}
 for x=-160,159 do for y=-160,159 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 surface.set_tiles(tiles)
 surface.freeze_daytime=true
 local player=game.get_player(1)
 assert(player,"Fixture requires a real saved player")
 player.admin=true;player.set_controller{type=defines.controllers.god};player.teleport({-140,-140},surface)
 local actors={player.index}
 storage.qc.actors=actors
 local actor=game.get_player(actors[1])
 action(actor,"chunks",{surface_index=surface.index,force_index=999999,mode="reveal",radius=0},tick,false)
 local probe_surface=game.create_surface("admin-world-destroy-probe",{water="none",autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
 probe_surface.request_to_generate_chunks({0,0},0);probe_surface.force_generate_chunk_requests()
 local probe={first=probe_surface.create_entity{name="small-biter",position={8,8},force="enemy"},
   second=probe_surface.create_entity{name="small-biter",position={12,8},force="enemy"}}
 assert(probe.first and probe.second,"Native destroy callback fixture setup failed")
 storage.qc.destroy_probe=probe
 local clear_id=action(actor,"clear_enemies",{surface_index=probe_surface.index},tick)
 for _=1,128 do
  world.updater(tick)
  if probe.converted or not storage.ei.admin_tools.world.jobs[clear_id]then break end
 end
 check(probe.converted and probe.converted.valid and probe.converted.force==actor.force,
   "destroy callback force transfer preserves later batch member")
 if storage.ei.admin_tools.world.jobs[clear_id]then world.execute(actor,"cancel_job",{job_id=clear_id},tick)end
 storage.qc.destroy_probe=nil
 local custom=game.create_force("admin-world-hostile-probe")
 local original_force=actor.force
 custom.set_friend(original_force,false);custom.set_cease_fire(original_force,false)
 original_force.set_friend(custom,false);original_force.set_cease_fire(custom,false)
 local custom_unit=probe_surface.create_entity{name="small-biter",position={20,8},force=custom}
 local friend_id=action(actor,"clear_enemies",{surface_index=probe_surface.index,force_index=custom.index},tick)
 custom.set_friend(original_force,true)
 world.updater(tick)
 check(not storage.ei.admin_tools.world.jobs[friend_id] and custom_unit.valid,"queued clear cancels when force becomes friendly")
 custom.set_friend(original_force,false)
 local player_id=action(actor,"clear_enemies",{surface_index=probe_surface.index,force_index=custom.index},tick)
 actor.force=custom
 world.updater(tick)
 check(not storage.ei.admin_tools.world.jobs[player_id] and custom_unit.valid,"queued clear cancels when force gains player")
 actor.force=original_force
 custom_unit.destroy()
 local friendship_probe={first=probe_surface.create_entity{name="small-biter",position={20,8},force=custom},
   second=probe_surface.create_entity{name="small-biter",position={24,8},force=custom},force=custom,mode="friend"}
 storage.qc.destroy_probe=friendship_probe
 local callback_id=action(actor,"clear_enemies",{surface_index=probe_surface.index,force_index=custom.index},tick)
 for _=1,128 do
  world.updater(tick)
  if friendship_probe.converted or not storage.ei.admin_tools.world.jobs[callback_id]then break end
 end
 check(friendship_probe.converted and friendship_probe.converted.valid
   and not storage.ei.admin_tools.world.jobs[callback_id],"destroy callback friendship change cancels current batch")
 storage.qc.destroy_probe=nil
 game.delete_surface(probe_surface)
 for _,size in ipairs{{64,64},{128,32}}do
  local id=action(actor,"chunks",{surface_index=surface.index,mode="reveal",
    area={left_top={x=0,y=0},right_bottom={x=size[1]*32,y=size[2]*32}}},tick)
  local job=id and storage.ei.admin_tools.world.jobs[id]
  local r=job and job.region
  check(r and (r.max_x-r.min_x+1)*(r.max_y-r.min_y+1)==4096,"rectangle admits exactly 4096 chunks",size[1].."x"..size[2])
  if id then action(actor,"cancel_job",{job_id=id},tick)end
 end
 action(actor,"chunks",{surface_index=surface.index,mode="reveal",
   area={left_top={x=0,y=0},right_bottom={x=65*32,y=64*32}}},tick,false)
 action(actor,"planet_spawning",{surface_index=surface.index,enabled=false},tick)
 check(surface.no_enemies_mode,"native no_enemies")
 action(actor,"planet_spawning",{surface_index=surface.index,enabled=true},tick)
 action(actor,"planet_peaceful",{surface_index=surface.index,enabled=true},tick)
 check(surface.peaceful_mode,"native peaceful")
 action(actor,"planet_evolution",{surface_index=surface.index,evolution=0},tick)
 check(game.forces.enemy.get_evolution_factor(surface)==0,"native zero evolution")
 action(actor,"planet_expansion",{surface_index=surface.index,enabled=false},tick)
 local base=surface.create_entity{name="biter-spawner",position={0,0},force="enemy"}
 world.on_biter_base_built{entity=base,tick=tick}
 check(not base.valid,"per-surface expansion veto")
 action(actor,"planet_daytime",{surface_index=surface.index,daytime=.4},tick)
 action(actor,"planet_freeze",{surface_index=surface.index,enabled=true},tick)
 check(surface.freeze_daytime and math.abs(surface.daytime-.4)<.0001,"native daytime")
 action(actor,"give_items",{item={name="iron-plate",quality="normal"},quantity=100},tick)
 local inventory=actor.get_inventory(defines.inventory.god_main)
 check(inventory and inventory.get_item_count("iron-plate")==100,"native god inventory")
 local tank=surface.create_entity{name="storage-tank",position={0,-30},force=actor.force}
 tank.set_fluid(1,{name="water",amount=20,temperature=95})
 action(actor,"fill_fluid",{entity=tank,fluid="water",amount=20},tick)
 local fluid=tank.get_fluid(1)
 check(fluid and math.abs(fluid.amount-40)<.001 and math.abs(fluid.temperature-95)<.001,"native addition preserves existing temperature",fluid and fluid.amount)
 action(actor,"fill_fluid",{entity=tank,fluid="crude-oil",amount=10},tick,false)
 local hot=surface.create_entity{name="storage-tank",position={15,-30},force=actor.force}
 hot.fluidbox.set_filter(1,{name="steam",minimum_temperature=165,maximum_temperature=1000})
 hot.set_fluid(1,{name="steam",amount=20,temperature=500})
 action(actor,"fill_fluid",{entity=hot,fluid="steam",amount=20},tick)
 local steam=hot.get_fluid(1)
 check(steam and steam.amount==40 and steam.temperature==500,"filtered hot storage preserves temperature")
 for y=-4,4,2 do surface.create_entity{name="straight-rail",position={60,y},direction=defines.direction.north,force=actor.force} end
 local wagon=surface.create_entity{name="fluid-wagon",position={60,0},direction=defines.direction.north,force=actor.force}
 assert(wagon and wagon.valid,"Native fluid wagon fixture creation failed")
 check(#wagon.fluidbox==0 and wagon.fluids_count==1,"native special fluid storage")
 wagon.set_fluid(1,{name="water",amount=20,temperature=95})
 action(actor,"fill_fluid",{entity=wagon,fluid="water",amount=20},tick)
 local special=wagon.get_fluid(1)
 check(special and special.amount==40 and special.temperature==95,"special storage preserves temperature")
 action(actor,"place_resources",{surface_index=surface.index,position={-50,-50},resource="iron-ore",amount=123,radius=2},tick)
 action(actor,"add_pollution",{surface_index=surface.index,area={left_top={0,0},right_bottom={64,64}},amount=100},tick)
 local id=action(actor,"place_entities",{surface_index=surface.index,position={-75,90},item={name="wooden-chest",quality="normal"},quantity=100},tick)
 -- Stress only the dispatcher with synthetic admitted jobs; each native operation
 -- retains the real saved player, force and surface. UI admission is tested separately.
 local root=storage.ei.admin_tools.world
 for index=2,8 do
  local clone={};for key,value in pairs(root.jobs[id])do clone[key]=value end
  root.next_id=root.next_id+1;clone.id=root.next_id;clone.position={x=-100+25*index,y=90}
  root.jobs[clone.id]=clone;root.active=root.active+1;scheduler.queue_push(root.queue,clone.id)
 end
 storage.qc.synthetic_admission_for_stress=true
 local before=0
 for _,job in pairs(storage.ei.admin_tools.world.jobs)do before=before+job.completed+job.failed end
 world.updater(tick)
 local after=0
 for _,job in pairs(storage.ei.admin_tools.world.jobs)do after=after+job.completed+job.failed end
 check(after-before<=25,"global creation admission <=25",after-before)
 check(after-before==25,"busy creation admission uses25",after-before)
 storage.qc.first_attempts=after-before
 local snapshot=world.peek_summary()
 check(snapshot.jobs[1].visited~=nil and snapshot.jobs[1].total~=nil,"bounded scalar job progress")
 storage.qc.phase="work"
end
local function hazards(tick)
 local surface=storage.qc.surface
 local actor=game.get_player(storage.qc.actors[1])
 action(actor,"start_fire",{surface_index=surface.index,position={-90,0},fire_family="oil",pattern=5},tick)
 action(actor,"rupture",{surface_index=surface.index,position={90,-90},rupture_family="gas",energy=20},tick)
 check(effects.admin_has_work(),"native queued rupture")
 local id=storage.ei.flammable_ruptures.admin_effect_job_id
 local job=storage.ei.flammable_ruptures.jobs[id]
 check(job and job.source_force_name=="neutral" and job.mode=="standard" and job.next_ring==1,"native rupture deferred and bounded")
 action(actor,"rupture",{surface_index=surface.index,position={90,-90},rupture_family="gas",energy=20},tick,false)
end
local function dense_limit(tick)
 local surface=storage.qc.surface
 local actor=game.get_player(storage.qc.actors[1])
 local entities={}
 for i=1,513 do entities[#entities+1]=surface.create_entity{name="admin-world-dense-target",position={100+(i%25)*.2,20+math.floor(i/25)*.2},force="neutral"}end
 local count=#surface.find_entities_filtered{position={100,20},radius=10}
 check(count>=513,"dense fixture population",count)
 local id,message=action(actor,"rupture",{surface_index=surface.index,position={100,20},rupture_family="oil",energy=500},tick,false)
 check(message:find("512")~=nil,"dense rupture reason propagated",message)
 for _,entity in ipairs(entities)do if entity.valid then entity.destroy()end end
end
local function chart_stress(tick)
 local surface=storage.qc.surface
 local root=storage.ei.admin_tools.world
 local actor=game.get_player(storage.qc.actors[1])
 local id=action(actor,"chunks",{surface_index=surface.index,position={-144,-144},mode="reveal",radius=0},tick)
 for i=2,40 do
  local clone={};for key,value in pairs(root.jobs[id])do clone[key]=value end
  root.next_id=root.next_id+1;clone.id=root.next_id
  local x,y=-5+(i-1)%10,-5+math.floor((i-1)/10)
  clone.region={min_x=x,max_x=x,min_y=y,max_y=y}
  root.jobs[clone.id]=clone;root.active=root.active+1;scheduler.queue_push(root.queue,clone.id)
 end
 for i=1,12 do world.updater(tick)end
 check(root.charting_count<=32,"global native chart pending <=32",root.charting_count)
 storage.qc.chart_pending_peak=root.charting_count
 local before=root.charting_count
 local ids={}
 for id,job in pairs(root.jobs)do if job.kind=="chunks"then ids[#ids+1]=id end end
 for _,id in ipairs(ids)do world.execute(game.get_player(storage.qc.actors[1]),"cancel_job",{job_id=id},tick)end
 check(root.charting_count==before,"cancel retains native chart slots")
end
local function generation(tick)
 local surface=storage.qc.surface
 local actor=game.get_player(storage.qc.actors[1])
 local id=action(actor,"chunks",{surface_index=surface.index,position={2048,2048},mode="generate",radius=0},tick)
 world.updater(tick)
 local root=storage.ei.admin_tools.world
 local before=root.generation_count
 check(before==1,"native generation submitted",before)
 action(actor,"cancel_job",{job_id=id},tick)
 check(root.generation_count==before,"cancel retains native generation slot")
 storage.qc.generated_target={x=64,y=64}
end
local function checkpoint(tick)
 local surface=storage.qc.surface
 local actor=game.get_player(storage.qc.actors[1])
 local ids={}
 for id in pairs(storage.ei.admin_tools.world.jobs)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do world.execute(actor,"cancel_job",{job_id=id},tick)end
 local id=action(actor,"chunks",{surface_index=surface.index,mode="all_generated"},tick)
 world.updater(tick)
 local job=storage.ei.admin_tools.world.jobs[id]
 check(job and job.iterator and job.iterator.valid,"native iterator active at checkpoint")
 storage.qc.iterator_job=id;storage.qc.checkpoint_tick=tick
 storage.qc.phase="checkpoint"
 report()
 game.server_save("admin-world-checkpoint")
 log("ADMIN_WORLD_CHECKPOINT")
end
script.on_event(defines.events.on_tick,function(event)
 local tick=event.tick
 local elapsed=storage.qc.started_tick and tick-storage.qc.started_tick or 0
 if storage.qc.phase=="setup"then setup(tick);return end
 if storage.qc.phase=="checkpoint"and not loaded then return end
 if loaded and storage.qc.phase=="checkpoint"then
  local job=storage.ei.admin_tools.world.jobs[storage.qc.iterator_job]
  check(job and job.iterator and job.iterator.valid,"saved chunk iterator restored")
  storage.qc.phase="reloaded";storage.qc.reload_tick=tick
  action(game.get_player(storage.qc.actors[1]),"clear_enemies",{surface_index=storage.qc.surface.index},tick)
 end
 if elapsed==10 then hazards(tick)end
 if elapsed==20 then
  action(game.get_player(storage.qc.actors[1]),"place_resources",{surface_index=storage.qc.surface.index,
    position={-50,-50},resource="iron-ore",amount=999,radius=0},tick)
 end
 if elapsed==25 then dense_limit(tick)end
 if elapsed==35 then chart_stress(tick)end
 if elapsed==40 then generation(tick)end
 if elapsed==45 then
  for _,kind in ipairs{'enemies','fires','resources','entities','items','fluids'}do
   local ok,catalog=pcall(world.get_catalog,kind)
   check(ok and #catalog>0,"native catalog "..kind,ok and #catalog or catalog)
  end
  action(game.get_player(storage.qc.actors[1]),"spawn_enemies",{surface_index=storage.qc.surface.index,position={-80,35},
    enemy_mix={{name="small-biter",count=4},{name="small-strafer-pentapod",count=2},{name="small-demolisher",count=1}},attack_position={-40,35}},tick)
 end
 if elapsed==50 then
  local units=storage.qc.surface.find_entities_filtered{force="enemy",type={"unit","spider-unit"}}
  local group;local members=0;local spiders=0;local same=true
  for _,entity in ipairs(units)do
   local parent=entity.commandable and entity.commandable.parent_group
   if not parent or (group and parent~=group)then same=false end
   group=group or parent;members=members+1
   if entity.type=="spider-unit"then spiders=spiders+1 end
  end
  check(same and group and members==6 and spiders==2,"native mixed biter/pentapod wave group",members)
 end
 if elapsed==52 then
  local actor=game.get_player(storage.qc.actors[1])
  local entries=world.get_catalog("advanced_enemies")
  local found=false;local safe=true
  for _,entry in ipairs(entries)do
   if entry.name=="gun-turret"then found=true end
   if entry.type=="segment"or entry.name=="dummy-spider-unit"then safe=false end
  end
  check(found and safe,"advanced catalog excludes segments/internal dummy")
  action(actor,"spawn_enemies",{surface_index=storage.qc.surface.index,position={-10,35},enemy_mix={{name="gun-turret",count=1}}},tick,false)
  action(actor,"spawn_enemies",{surface_index=storage.qc.surface.index,position={-10,35},advanced=true,enemy_mix={{name="gun-turret",count=1}}},tick)
 end
 if elapsed==65 then
  local surface=storage.qc.surface
  local resources=surface.find_entities_filtered{type="resource",name="iron-ore",area={{-55,-55},{-45,-45}}}
  check(#resources==13,"native circular resource patch",#resources)
  for _,entity in ipairs(resources)do check(entity.amount==123,"resource amount unchanged after overlapping patch")end
  check(surface.get_pollution({16,16})>0 and surface.get_pollution({48,48})>0,"area pollution reaches distinct chunks")
  local summary=world.peek_summary()
  check(summary.chart_pending==0 and summary.generation_pending<=16,"native chart events release slots; generation bounded")
  check(not effects.admin_has_work(),"rupture rings complete")
  storage.qc.resources=#resources
 end
 if elapsed==70 then checkpoint(tick);return end
 if world.has_tick_work()then world.updater(tick)end
 if elapsed==45 then
  local unit=storage.qc.surface.find_entities_filtered{force="enemy",name="small-biter",limit=1}[1]
  local group=unit and unit.commandable and unit.commandable.parent_group
  -- Native AI may complete an empty attack area on its next simulation update.
  check(group and group.command and group.command.type==defines.command.attack_area,"native grouped attack-area order")
 end
 if rupture_scheduler.has_tick_work(event)then rupture_scheduler.updater(event)end
 if storage.qc.phase=="reloaded"and storage.ei.admin_tools.world.active==0 then
  check(storage.ei.admin_tools.world.last_result.status=="finished","restored iterator job completes")
  check(storage.qc.surface.is_chunk_generated(storage.qc.generated_target),"canceled native generation eventually completes")
  check(world.peek_summary().generation_pending==0,"native generation events release slots")
  check(storage.qc.surface.count_entities_filtered{force="enemy",type="unit"}==0,"native clear ordinary enemies")
  check(storage.qc.surface.count_entities_filtered{force="enemy",type="ammo-turret"}==0,"native clear advanced hostile turret")
  check(#storage.qc.surface.get_segmented_units()==0,"native clear segmented units")
  storage.qc.phase="finished";storage.qc.all_pass=#storage.qc.failures==0
  report();log("ADMIN_WORLD_DONE "..tostring(storage.qc.all_pass))
 end
end)
