-- Executed inside the staged ESIR control context, never shipping source.
local common,targeting
local model={}
function model.configure(state_owner,target_owner)common=state_owner;targeting=target_owner end
local function snapshot()
 storage.ei.admin_shutdown_qc=storage.ei.admin_shutdown_qc or {checks={}}
 return storage.ei.admin_shutdown_qc
end
local function check(q,name,ok,detail)
 q.checks[#q.checks+1]={name=name,ok=not not ok,detail=detail}
end
local function action(q,owner,p,name,args,tick)
 local ok,why=owner.execute(p,name,args,tick)
 check(q,"admit "..name,ok,why)
 assert(ok,why)
end
local function find_stack(p,name,quality,identity)
 local inventory=p.get_main_inventory()
 if not inventory then return end
 for i=1,#inventory do
  local stack=inventory[i]
  if stack.valid_for_read and stack.name==name and stack.quality.name==quality
   and (not identity or stack.tags.identity==identity)then return stack end
 end
end
local function result(q,phase,tick)
 local pass=true;for _,entry in ipairs(q.checks)do if not entry.ok then pass=false end end
 return {phase=phase,all_pass=pass,checks=q.checks,recovery=q.recovery,version=script.active_mods.base,tick=tick}
end
function model.before_configuration(tick)
 local q=storage.ei and storage.ei.admin_shutdown_qc
 if not q or q.phase~="prepared" or common.enabled()then return end
 local root=common.peek()
 q.before_cleanup={tick=tick,active=root.world.active,mode=root.modes[q.player_index]~=nil,
  selection=root.pending_selection[q.player_index]~=nil,ui=q.admin_root.valid,
  camera=q.camera_root.valid,speed=game.speed,automation=next(root.instant_research)~=nil}
end
function model.step(owner,enabled,tick)
 local q=snapshot()
 if enabled then
  if q.phase=="prepared" then return result(q,"prepared",tick) end
  if not q.phase then
   local p=game.connected_players[1]
   if not (p and p.connected)then return result(q,"waiting_player",tick)end
   if p.controller_type==defines.controllers.remote then p.exit_remote_view()end
   if not p.character then p.set_controller{type=defines.controllers.god};p.create_character()end
   assert(p.character,"Native fixture character creation failed")
   p.admin=true;p.cheat_mode=false;p.character.destructible=true;game.speed=1
   q.player_index=p.index;q.body=p.character;q.body_unit=p.character.unit_number
   q.cheat_before=p.cheat_mode;q.destructible_before=p.character.destructible;q.speed_before=game.speed
   q.surface=game.create_surface("admin-shutdown-probe",{water="none",autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
   q.surface.request_to_generate_chunks({0,0},3);q.surface.force_generate_chunk_requests()
   local tiles={};for x=-96,95 do for y=-96,95 do tiles[#tiles+1]={name="grass-1",position={x,y}}end end
   q.surface.set_tiles(tiles);assert(p.teleport({0,0},q.surface))
   local body_inventory=p.get_main_inventory()
   assert(body_inventory.insert{name="admin-shutdown-qc-tag",count=1}==1)
   local body_tag=find_stack(p,"admin-shutdown-qc-tag","normal")
   body_tag.tags={identity="body-owned",nested={value=217}}
   action(q,owner,p,"planet_peaceful",{surface_index=q.surface.index,enabled=true},tick)
   action(q,owner,p,"place_entities",{surface_index=q.surface.index,position={16,16},place_item={name="wooden-chest",quality="normal"},quantity=1},tick)
   q.phase="building";q.started=tick
   return result(q,"building",tick)
  end
  if tick-q.started<5 then return result(q,"building",tick) end
  local p=game.get_player(q.player_index)
  local built=q.surface.find_entities_filtered{name="wooden-chest",position={16,16},radius=3,limit=1}[1]
  assert(built and built.valid,"Completed coordinator placement was not found")
  q.completed_entity=built;q.completed_unit=built.unit_number
  action(q,owner,p,"cheat",{player_index=p.index,enabled=true},tick)
  action(q,owner,p,"invulnerable",{player_index=p.index,enabled=true},tick)
  action(q,owner,p,"god",{player_index=p.index,enabled=true},tick)
  local god=p.get_inventory(defines.inventory.god_main)
  assert(god and #god>=3,"Native god inventory missing")
  assert(god[1].set_stack{name="admin-shutdown-qc-tag",count=1,quality="rare"})
  god[1].tags={identity="god-owned",nested={value=419}}
  assert(god[2].set_stack{name="admin-shutdown-qc-box",count=1})
  assert(god[2].get_inventory(defines.inventory.item_main).insert{name="steel-plate",count=13,quality="rare"}==13)
  assert(p.cursor_stack.set_stack{name="admin-shutdown-qc-tag",count=1,quality="legendary"})
  p.cursor_stack.tags={identity="cursor-owned",nested={value=613}}
  action(q,owner,p,"speed",{speed=2},tick)
  action(q,owner,p,"instant_research",{force_index=p.force.index,enabled=true},tick)
  action(q,owner,p,"place_entities",{surface_index=q.surface.index,position={-50,0},place_item={name="wooden-chest",quality="normal"},quantity=100},tick)
  action(q,owner,p,"chunks",{surface_index=q.surface.index,position={8192,8192},mode="generate",radius=31},tick)
  owner.open(p,"creation",tick)
  action(q,owner,p,"camera-player",{player_index=p.index,follow_view=false},tick)
  local root=common.peek();q.admin_root=root.sessions[p.index].root
  local cameras=storage.ei_camera_windows
  for _,entry in pairs(cameras and cameras.windows or {})do if entry.owner=="admin" and entry.viewer==p.index then q.camera_root=entry.root;break end end
  root.sessions[p.index].drafts.planet="nauvis"
  local selected,why=targeting.begin(p,"area",root.sessions[p.index],tick)
  check(q,"native targeting admitted",selected,why);assert(selected,why)
  check(q,"saved toolkit enabled",common.enabled())
  check(q,"saved admin and camera roots",q.admin_root.valid and q.camera_root and q.camera_root.valid)
  check(q,"saved owned modes",root.modes[p.index] and root.modes[p.index].god and p.cheat_mode and not q.body.destructible)
  check(q,"saved pending jobs",root.world.active>=2)
  check(q,"saved targeting state",root.pending_selection[p.index]~=nil and p.controller_type==defines.controllers.remote)
  check(q,"saved instant research",root.instant_research[p.force.index]~=nil)
  check(q,"saved speed override",game.speed==2 and root.speed_before==q.speed_before)
  q.phase="prepared";q.prepared_tick=tick
  return result(q,"prepared",tick)
 end
 assert(q.phase=="prepared" or q.phase=="disabled_done","Reload did not preserve the enabled fixture state")
 if q.phase=="disabled_done"then return result(q,"disabled_done",tick)end
 q.disabled_started=q.disabled_started or tick
 local p=game.get_player(q.player_index)
 local root=common.peek()
 local elapsed=tick-q.disabled_started
 local mode=root.modes[q.player_index]
 if elapsed==0 or elapsed==30 or elapsed==60 or elapsed==120 or elapsed==180 or elapsed==600
  or (not mode and not q.recovered_snapshot)then
  q.recovery=q.recovery or {}
  q.recovery[#q.recovery+1]={tick=tick,elapsed=elapsed,connected=p.connected,controller=p.controller_type,
   physical=p.physical_controller_type,body_unit=p.character and p.character.unit_number,
   physical_surface=p.physical_surface.index,saved_body_unit=q.body.valid and q.body.unit_number,
   saved_body_surface=q.body.valid and q.body.surface.index,
   god_body_unit=mode and mode.god and mode.god.character and mode.god.character.valid and mode.god.character.unit_number,
   saved_body_valid=q.body.valid,saved_body_destructible=q.body.valid and q.body.destructible,
   mode=mode~=nil,cleanup=mode and mode.cleanup_pending,god=mode and mode.god~=nil,
   god_return_pending=mode and mode.god_return_pending,escrow_slots=mode and mode.escrow and mode.escrow.valid and #mode.escrow,
   next_due=root.players.next_due_tick,due=root.players.due_by_player[p.index],retries=root.players.retry_attempts and root.players.retry_attempts[p.index]}
  if not mode then q.recovered_snapshot=true end
 end
 if elapsed<30 then return result(q,"waiting_cleanup",tick)end
 if mode and elapsed<720 then return result(q,"waiting_recovery",tick)end
 local before=q.before_cleanup
 check(q,"actual saved state observed before coordinator cleanup",before and before.active>=2
  and before.mode and before.selection and before.ui and before.camera and before.speed==2 and before.automation)
 check(q,"disabled startup setting",not common.enabled())
 check(q,"native player reconnected",p and p.valid and p.connected)
 check(q,"original native body restored",p.character==q.body and q.body.valid and q.body.unit_number==q.body_unit)
 check(q,"character controller restored",p.physical_controller_type==defines.controllers.character and p.controller_type~=defines.controllers.remote)
 check(q,"original body destructibility restored",q.body.destructible==q.destructible_before)
 check(q,"original cheat mode restored",p.cheat_mode==q.cheat_before)
 check(q,"speed restored",game.speed==q.speed_before and root.speed_before==nil)
 check(q,"admin root destroyed",not q.admin_root.valid)
 check(q,"camera root destroyed",not q.camera_root.valid)
 check(q,"targeting state cleared",next(root.pending_selection)==nil)
 check(q,"selector cursor cleared",not(p.cursor_stack.valid_for_read and p.cursor_stack.name=="ei-admin-location-selector"))
 check(q,"owned mode cleanup complete",root.modes[p.index]==nil)
 check(q,"queued work cancelled",root.world.active==0 and next(root.world.jobs)==nil and root.world.generation_count==0 and root.world.charting_count==0)
 check(q,"automation stopped",next(root.instant_research)==nil and next(root.research_due)==nil)
 check(q,"completed native edit preserved",q.completed_entity.valid and q.completed_entity.unit_number==q.completed_unit and q.surface.peaceful_mode)
 local body=find_stack(p,"admin-shutdown-qc-tag","normal","body-owned")
 local god=find_stack(p,"admin-shutdown-qc-tag","rare","god-owned")
 local cursor=find_stack(p,"admin-shutdown-qc-tag","legendary","cursor-owned")
 local box=find_stack(p,"admin-shutdown-qc-box","normal")
 local inventory=p.get_main_inventory()
 check(q,"exact native fixture stack counts",inventory.get_item_count{name="admin-shutdown-qc-tag",quality="normal"}==1
  and inventory.get_item_count{name="admin-shutdown-qc-tag",quality="rare"}==1
  and inventory.get_item_count{name="admin-shutdown-qc-tag",quality="legendary"}==1
  and inventory.get_item_count{name="admin-shutdown-qc-box",quality="normal"}==1)
 check(q,"body exact tags retained",body and body.count==1 and body.tags.nested.value==217)
 check(q,"god exact tags and quality returned",god and god.count==1 and god.tags.nested.value==419)
 check(q,"cursor exact tags and quality returned",cursor and cursor.count==1 and cursor.tags.nested.value==613)
 check(q,"nested item inventory returned",box and box.count==1 and box.get_inventory(defines.inventory.item_main).get_item_count{name="steel-plate",quality="rare"}==13)
 q.phase="disabled_done"
 return result(q,"disabled_done",tick)
end
return model
