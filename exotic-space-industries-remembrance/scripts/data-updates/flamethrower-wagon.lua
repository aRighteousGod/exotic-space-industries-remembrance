--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

--fire extinguisher
if not mods["flamethrower-wagon"] then
    return
end

local ei_lib = require("lib/lib")

--flamethrower-wagon name of wagon entity and tech and recipe
--flamethrower-wagon-turret gets created in on_built
--default turret variables
--[[
turret.attack_parameters.range = 30
turret.attack_parameters.min_range = 2.5
turret.attack_parameters.turn_range = 1
--turret.attack_parameters.lead_target_for_projectile_speed = 0.225 * 1.5

turret.prepare_range = 50
turret.preparing_speed = 0.06
turret.rotation_speed = 0.0225
]]
--default recipe
--[[
    { type = "item", name = "fluid-wagon",         amount = 1 },
    { type = "item", name = "flamethrower-turret", amount = 2 },
    { type = "item", name = "engine-unit",         amount = 6 },
    { type = "item", name = "steel-plate",         amount = 10 },
]]