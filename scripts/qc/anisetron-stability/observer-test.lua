local observer=require("live-observer")
return {install=function()
 script.on_nth_tick(120,function(event)
  if storage.complete then return end
  if not storage.observer_start then
   local p=assert(game.get_player(1));p.admin=true
   local e=p.surface.create_entity{name="ei-anisetron",position=p.position,force=p.force,raise_built=true}
   storage.observer_entity=e;storage.observer_position=e.position
   local walking=p.walking_state
   observer.begin{player_index=p.index,tick=event.tick,parameter="60"}
   assert(storage.trace and storage.trace.limit==60)
   assert(p.walking_state.walking==walking.walking and p.walking_state.direction==walking.direction)
   storage.observer_start=event.tick
  else
   local e=storage.observer_entity;local before=storage.observer_position
   local pass=storage.trace==nil and e.position.x==before.x and e.position.y==before.y and e.speed==0
   storage.complete=true
   helpers.write_file("anisetron-qc.json",helpers.table_to_json{profile="observer-smoke",complete=true,count=1,
    all_pass=pass,cases={bounded_observer_no_motion={pass=pass}}},false)
  end
 end)
end}
