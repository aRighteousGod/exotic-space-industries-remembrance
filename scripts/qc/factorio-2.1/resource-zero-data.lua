-- Private candidate: allow a saved zero-frequency resource to compile before Lua.
local resource_noise=data.raw['noise-function'].resource_autoplace_all_patches
resource_noise.local_expressions.starting_area_spot_quantity=
    'starting_amount / starting_patches_split / if(frequency_multiplier == 0, 1, frequency_multiplier)'
resource_noise.local_functions.regular_spot_quantity_base_at.expression=
    '1000000 / base_spots_per_km2 / if(frequency_multiplier == 0, 1, frequency_multiplier) * regular_density_at(distance)'
resource_noise.expression='if(frequency_multiplier == 0, 0, '..resource_noise.expression..')'
data:extend{{type='mod-data',name='esir-qc-resource-zero-safe',data={guarded=true}}}
