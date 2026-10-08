-- A native poison sticker gives an exact damage comparison independent of paths.
data:extend{{type="sticker",name="anisetron-stallfix-dot",hidden=true,flags={"not-on-map"},
    duration_in_ticks=60,damage_interval=1,damage_per_tick={amount=1,type="poison"},
    target_movement_modifier=1,vehicle_speed_modifier=1,vehicle_friction_modifier=1}}
local config=require("__exotic-space-industries-remembrance__/lib/anisetron-mobility-config")
assert(config.minimum_modifier==.50)
for _,name in ipairs(config.names) do
    local sticker=assert(data.raw.sticker[name])
    assert(sticker.duration_in_ticks==12 and not sticker.damage_per_tick and not sticker.animation)
end
