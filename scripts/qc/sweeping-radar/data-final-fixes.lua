local shell=table.deepcopy(data.raw.radar["ei-sweeping-radar"])
shell.name="ei-radar-qc-shell"
shell.next_upgrade=nil
shell.energy_usage="60W"
shell.energy_per_sector="1J"
shell.energy_per_nearby_scan="1J"
shell.max_distance_of_sector_revealed=4
shell.max_distance_of_nearby_sector_revealed=2
local source=table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name="ei-radar-qc-source"
source.energy_source={type="electric",usage_priority="primary-output",buffer_capacity="1GJ",output_flow_limit="1GW"}
source.energy_production="1GW"
source.energy_usage="0W"
data:extend({shell,source})
-- Fixture-only qualities prove interpolation and saturation without rescaling
-- standard quality bonuses when another mod provides a higher tier.
for _,entry in ipairs{{"ei-radar-qc-level4",4},{"ei-radar-qc-level9",9}} do
    local quality=table.deepcopy(data.raw.quality.legendary)
    quality.name=entry[1];quality.level=entry[2];quality.next=nil;quality.next_probability=0
    data:extend({quality})
end
