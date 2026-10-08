-- Test-only bridge appended to the staged main control; shipping exports no remote.
remote.add_interface("anisetron-inheritance-qc",{
 snapshot=function() return ei_anisetron.get_lance_qc_snapshot() end,
 visuals=function() return ei_anisetron.get_qc_snapshot() end,
 rebuild=function() ei_anisetron.rebuild_visuals(game.tick) end,
 strand_layer=function(layer)
  local root=storage.ei.runtime_scheduler.modules.anisetron
  for _,record in pairs(root.visuals and root.visuals.tracked or {}) do
   for _,handle in pairs(record.strands or {}) do if handle.valid then handle.render_layer=layer end end
  end
 end,
 memory=function(id)
  local root=storage.ei.runtime_scheduler.modules.anisetron.lance
  local record=root and root.memories[id]
  return record and {counter=record.counter,stacks=record.context.stacks,tick=record.context.tick,
   target=record.context.target and record.context.target.valid and record.context.target.unit_number,
   mark=record.mark and record.mark.valid or false,level=record.level}
 end,
 paid=function(id)
  local root=storage.ei.runtime_scheduler.modules.anisetron
  local owner=root and root.active and root.active[id];local burst=owner and owner.burst
  if not burst then return end
  return {version=burst.contract_version,crown_damage=burst.crown_damage,facade_damage=burst.facade_damage,
   crown_range=burst.crown_range,facade_range=burst.facade_range,start_tick=burst.start_tick,end_tick=burst.end_tick,
   level=burst.lance and burst.lance.level,phase=burst.lance and burst.lance.phase,pulse_index=burst.lance and burst.lance.pulse_index}
 end,
})
