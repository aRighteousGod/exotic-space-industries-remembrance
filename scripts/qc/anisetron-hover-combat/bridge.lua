-- Appended only to the staged production owner, never exposed by shipping ESIR.
local hover_mobility=require("scripts/control/anisetron-mobility")
remote.add_interface("anisetron-hover-qc",{
 mobility=hover_mobility.get_qc_snapshot,
 rebuild=function() ei_anisetron.rebuild_visuals(game.tick) end,
 paid=function(id)
  local root=storage.ei and storage.ei.runtime_scheduler and storage.ei.runtime_scheduler.modules.anisetron
  local owner=root and root.active and root.active[id]
  if not owner then return nil end
  local burst=owner.burst
  local result={}
  if burst then
   result.crown_damage=burst.crown_damage;result.facade_damage=burst.facade_damage
   result.research_multiplier=burst.research_multiplier;result.end_tick=burst.end_tick;result.start_tick=burst.start_tick
   result.channels={}
   for key,channel in pairs(burst.channels or {}) do
    result.channels[key]={color=channel.beam_light_index,beam=channel.beam and channel.beam.valid and channel.beam.name or nil}
   end
  end
  return result
 end,
})
