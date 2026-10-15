-- Private staged bridge. Both profiles have identical code and dependency sets.
local factory_terrain=require("scripts/control/terrain-evolution")
local factory_config=require("lib/terrain-evolution-config")
remote.add_interface("ei-ecology-factory-qc",{prepare=function(enabled,tick)
    for _,row in ipairs(factory_config.schema) do settings.global[row.setting_name]={value=row.default} end
    settings.global["ei-terrain-active"]={value=enabled}
    factory_terrain.initialize(tick,"configuration")
    local root=storage.ei.terrain_evolution
    for _,entry in pairs(root.surfaces) do factory_terrain.reset_overrides(entry.surface,tick) end
    assert(root.config.active==enabled,"Factory profile master switch differs from requested comparison")
    assert(enabled or root.enabled_surfaces==0,"Disabled factory profile has an eligible ecology surface")
    local surfaces={}
    for _,surface in pairs(game.surfaces) do
        surfaces[#surfaces+1]={name=surface.name,planet=surface.planet and surface.planet.name,
            entities=surface.count_entities_filtered{force="player"},pollution=surface.pollutant_type and surface.pollutant_type.name}
    end
    return {enabled=root.config.active,integration=root.config.enabled,enabled_surfaces=root.enabled_surfaces,
        performance=root.config.performance,intensity=root.config.intensity,
        periodic_mining=root.config.periodic_mining_scars,seasonal_daylight=root.config.seasonal_daylight,surfaces=surfaces}
end})
