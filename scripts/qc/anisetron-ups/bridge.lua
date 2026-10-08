-- Staged-only attribution and semantic probe; never shipped in the mod.
do
 local modules={anisetron=require("scripts/control/anisetron"),visuals=require("scripts/control/anisetron-visuals"),
  mobility=require("scripts/control/anisetron-mobility")}
 local enabled,phase=false,nil
 local mobility_original=modules.mobility.update
 local mobility_paused=false
 local rows={}
 for name,owner in pairs(modules) do
  -- Frozen pre-standardization code uses update; only the public event entry
  -- changes name. Child clock-only methods retain their existing signatures.
  local method=name=="anisetron" and owner.updater and "updater" or "update"
  local original=owner[method]
  local row={name=name};rows[#rows+1]=row
  owner[method]=function(...)
   if name=="mobility" and mobility_paused then return end
   if not enabled then return original(...) end
   row.profiler.restart();original(...);row.profiler.stop();row.calls=row.calls+1
  end
 end
 remote.add_interface("anisetron-ups",{
  pause_mobility=function() mobility_paused=true end,
  resume_mobility=function() mobility_paused=false end,
  service_mobility=function(tick) mobility_original(tick) end,
  mobility_state=function()
   local s=storage.ei.runtime_scheduler.modules.anisetron.mobility
   local result={count=s.count,next_tick=s.next_tick,due=s.due,records={}}
   for id,r in pairs(s.tracked) do result.records[id]={next_tick=r.next_tick,raw_modifier=r.raw_modifier,tier=r.tier} end
   return result
  end,
  profile=function(label)
   if enabled then
    log("ANISETRON_UPS_WINDOW "..phase.." ticks="..(game.tick-enabled))
    for _,row in ipairs(rows) do log({"","ANISETRON_UPS ",phase," ",row.name," calls=",row.calls," ",row.profiler}) end
   end
   phase=label;enabled=label and game.tick or false
   if enabled then for _,row in ipairs(rows) do row.calls=0;row.profiler=game.create_profiler(true) end end
  end,
  exercise=function(kind,entity,tick)
   local runtime=storage.ei.runtime_scheduler.modules.anisetron
   local record=runtime.visuals and runtime.visuals.tracked[entity.unit_number]
   if kind=="lost-handle" then
    local h=record and record.strands[2];if h and h.valid then h.destroy() end
   elseif kind=="old-cache" and record then
    record.applied_index,record.applied_angle,record.applied_length,record.applied_lift=nil,nil,nil,nil
   elseif kind=="rebuild" then modules.anisetron.rebuild_visuals(tick) end
  end,
  snapshot=function(entities)
   local runtime=storage.ei.runtime_scheduler.modules.anisetron
   local result={vehicles={},counters=runtime.counters,visuals=modules.anisetron.get_qc_snapshot()}
   -- Omit opaque render IDs while checking every observable strand property.
   for _,e in ipairs(entities) do
    local record=runtime.visuals and runtime.visuals.tracked[e.unit_number]
    local row={id=e.unit_number,position=e.position,speed=e.speed,torso=e.torso_orientation,
     modifiers=e.sticker_vehicle_modifiers,ammo=e.get_inventory(defines.inventory.spider_ammo).get_contents(),strands={}}
    for tip,h in pairs(record and record.strands or {}) do if h.valid then
     row.strands[tip]={visible=h.visible,orientation=h.orientation,x_scale=h.x_scale,y_scale=h.y_scale,
      offset=h.target.offset,ttl=h.time_to_live}
    end end
    local owner=runtime.active and runtime.active[e.unit_number];local b=owner and owner.burst
    if b then
     row.burst={version=b.contract_version,start=b.start_tick,finish=b.end_tick,next_contact=b.next_contact,channels={}}
     for name,c in pairs(b.channels or {}) do
      row.burst.channels[name]={target=c.target and c.target.valid and c.target.unit_number or nil,
       endpoint=c.endpoint,angle=c.aim_angle,acquired=c.acquired,muzzle=c.muzzle_index,
       beam=c.beam and c.beam.valid or false}
     end
    end
    if record and record.motion_light and record.motion_light.valid then
     row.motion_light={offset=record.motion_light.target.offset,ttl=record.motion_light.time_to_live}
    end
    result.vehicles[#result.vehicles+1]=row
   end
   return result
  end
 })
end
