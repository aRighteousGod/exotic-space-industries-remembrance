--==============================================================================
-- ESIR FILE MAP
-- owns: one-time birth notifications for supported suppression targets
-- loaded_by: data-final-fixes.lua after final fire variants
-- cadence: data stage only
--==============================================================================
-- blueprint: .codex/esir/blueprints/firefighting-and-water-turret.md#contract
local config=require("lib/firefighting-config")
local flames=require("lib/flamethrower-fuels")

for name,fire in pairs(data.raw.fire) do
    if config.thermal_fires[name] or flames.ground_fires[name] then
        local notification={type="direct",action_delivery={type="instant",
            target_effects={{type="script",effect_id=config.created_effect}}}}
        local existing=fire.created_effect
        if not existing then fire.created_effect=notification
        elseif existing.type then fire.created_effect={existing,notification}
        else existing[#existing+1]=notification end
    end
end
