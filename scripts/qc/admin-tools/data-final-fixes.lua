-- Explicit helper planet avoids assumptions about optional-mod planet pollution.
local planet=table.deepcopy(data.raw.planet.nauvis)
planet.name="ei-admin-qc-no-pollutant"
planet.pollutant_type=nil
data:extend{planet}
