-- Isolated native API fixture. Mirrors the disabled visible shell only.
local radar=table.deepcopy(data.raw.radar.radar)
local animation=table.deepcopy(radar.pictures)
for _,layer in pairs(animation.layers) do
    layer.frame_count=layer.direction_count
    layer.direction_count=nil
    layer.apply_projection=nil
end
radar.name="radar-art-qc"
radar.minable=nil
radar.energy_source={type="void"}
radar.energy_usage="1W"
radar.energy_per_sector="1GJ"
radar.energy_per_nearby_scan="1GJ"
radar.max_distance_of_sector_revealed=0
radar.max_distance_of_nearby_sector_revealed=0
radar.connects_to_other_radars=false
radar.rotation_speed=0
radar.pictures={filename="__core__/graphics/empty.png",width=1,height=1,direction_count=1}
data:extend({radar,{type="animation",name="radar-art-head",layers=animation.layers}})
