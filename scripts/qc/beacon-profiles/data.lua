local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
machine.name = "esir-beacon-qc-machine"
machine.minable = nil
machine.next_upgrade = nil
machine.energy_source = {type = "void"}
machine.effect_receiver = {uses_beacon_effects = true, uses_module_effects = true, uses_surface_effects = false}
machine.allowed_effects = {"speed", "consumption", "pollution", "productivity", "quality"}
local module = table.deepcopy(data.raw.module["speed-module"])
module.name = "esir-beacon-qc-module"
module.effect = {speed = 0.8, consumption = 0.4, pollution = 0.2, productivity = 0.12, quality = 0.1}
local beacon = table.deepcopy(data.raw.beacon.beacon)
beacon.name = "esir-beacon-qc-third-party"
beacon.minable = nil
beacon.profile = {0.9, 0.61, 0.4}
beacon.beacon_counter = "same_type"
data:extend{machine, module, beacon}
