local source = data.raw["beacon"] and data.raw["beacon"]["beacon"]

if source then
  local function make_beacon(name, range)
    local beacon = table.deepcopy(source)
    beacon.name = name
    beacon.localised_name = {"entity-name.beacon"}
    beacon.localised_description = {"", "Beacon overload geometry QC helper beacon."}
    beacon.minable = nil
    beacon.next_upgrade = nil
    beacon.fast_replaceable_group = nil
    beacon.supply_area_distance = range
    data:extend({beacon})
  end

  make_beacon("zzz-bo-weighted-beacon", 3)
  make_beacon("zzz-bo-excluded-beacon", 3)
  make_beacon("zzz-bo-long-beacon", 12)
end
