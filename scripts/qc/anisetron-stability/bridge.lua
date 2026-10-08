-- Observer only, appended to the staged ESIR control by the dedicated runner.
local stability_visuals=require("scripts/control/anisetron-visuals")
local stability_mobility=require("lib/anisetron-mobility-config")
remote.add_interface("anisetron-stability-qc",{
 minimum=function(value) stability_mobility.minimum_modifier=value end,
 snapshot=function(id)
  local root=storage.ei.runtime_scheduler.modules.anisetron
  local record=root.visuals and root.visuals.tracked[id]
  local result={strands={},moving=record and record.moving}
  for tip,handle in pairs(record and record.strands or {}) do
   if handle.valid then
    local t=handle.target
    result.strands[tip]={visible=handle.visible,offset=t.offset,position=t.position,orientation=handle.orientation,x_scale=handle.x_scale}
   end
  end
  local owner=root.active and root.active[id];local burst=owner and owner.burst
  result.contract=burst and burst.contract_version
  result.channels={}
  for key,c in pairs(burst and burst.channels or {}) do
   local beam=c.beam
   local valid=beam and beam.valid
   local s=valid and beam.get_beam_source();local t=valid and beam.get_beam_target()
   result.channels[key]={muzzle_index=c.muzzle_index,endpoint=c.endpoint,beam=valid or false,
    beam_name=valid and beam.name or nil,source_entity=s and s.entity and s.entity.unit_number,
    beam_target=t and t.position,source_offset=s and s.offset}
  end
  return result
 end,
})
