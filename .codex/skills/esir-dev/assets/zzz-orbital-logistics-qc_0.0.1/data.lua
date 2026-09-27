-- QC-only power coverage includes the runtime's hidden electric sensors.
local pole = table.deepcopy(data.raw["electric-pole"].substation)
pole.name = "esir-orbital-qc-pole"
pole.maximum_wire_distance = 64
pole.supply_area_distance = 64
pole.collision_mask = {layers = {}}
pole.minable = nil
local source = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name = "esir-orbital-qc-source"
source.collision_mask = {layers = {}}
source.energy_production = "1GW"
source.energy_usage = "0W"
source.energy_source = {type = "electric", usage_priority = "primary-output", buffer_capacity = "1GJ", output_flow_limit = "1GW"}
data:extend{pole, source}
