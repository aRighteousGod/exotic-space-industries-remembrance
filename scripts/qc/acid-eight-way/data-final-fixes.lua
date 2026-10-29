-- QC-only final-data receipt and native geometry probe; no shipped runtime work.
local config = require("test-config")
local turret = data.raw["fluid-turret"]["ei-acidthrower-turret"]
local delivery = turret.attack_parameters.ammo_type.action.action_delivery
if config.phase=="legacy-seed" then
    for i=#turret.flags,1,-1 do if turret.flags[i]=="building-direction-8-way" then table.remove(turret.flags,i) end end
    for _,port in ipairs(turret.fluid_box.pipe_connections) do port.alt_direction=nil;port.alt_position=nil end
    local connectors={};for i=1,8,2 do connectors[#connectors+1]=turret.circuit_connector[i] end;turret.circuit_connector=connectors
    for _,facing in ipairs{"north_east","south_east","south_west","north_west"} do
        for _,state in ipairs{"folded","preparing","prepared","attacking","ending_attack","folding"} do turret[state.."_animation"][facing]=nil end
        for _,v in ipairs(turret.graphics_set.base_visualisation) do v.animation[facing]=nil end
        turret.attack_parameters.gun_center_shift[facing]=nil
    end
end
local effects = {}
for kind, prototypes in pairs(data.raw) do
    if kind == "stream" or kind == "sticker" or kind == "trivial-smoke" or kind == "explosion" then
        for name, prototype in pairs(prototypes) do
            if name:find("acid", 1, true) then effects[kind.."/"..name] = table.deepcopy(prototype) end
        end
    end
end
data:extend{{type="mod-data", name="acid-eight-final", data={
    turret=table.deepcopy(turret), effects=effects, profile=settings.startup["ei-thrower-performance-profile"].value,
    stream=table.deepcopy(data.raw.stream[delivery.stream]),
}}}
if config.phase == "probe" then
    local probe = table.deepcopy(turret)
    probe.name = "acid-eight-probe"
    probe.minable=nil; probe.placeable_by=nil; probe.next_upgrade=nil
    local already_eight_way=false
    for _,flag in ipairs(probe.flags) do if flag=="building-direction-8-way" then already_eight_way=true end end
    if not already_eight_way then probe.flags[#probe.flags+1]="building-direction-8-way" end
    probe.fluid_box.pipe_connections[1].alt_direction=defines.direction.west
    probe.fluid_box.pipe_connections[1].alt_position={-1,0}
    probe.fluid_box.pipe_connections[2].alt_direction=defines.direction.south
    probe.fluid_box.pipe_connections[2].alt_position={0,1}
    probe.circuit_connector=table.deepcopy(data.raw["fluid-turret"]["flamethrower-turret"].circuit_connector)
    data:extend{probe}
end
if config.phase == "accept" or config.phase == "visual" then
    assert(#turret.circuit_connector==8)
    -- Instrument the canonical body only after retaining its unmodified data.
    assert(not delivery.source_effects)
    delivery.source_effects={{type="script",effect_id="acid-eight-launch"}}
    local target=table.deepcopy(data.raw.unit["behemoth-biter"])
    target.name="acid-eight-target";target.minable=nil;target.next_upgrade=nil;target.placeable_by=nil
    target.max_health=1000000;target.resistances={};target.healing_per_tick=0
    target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
    target.dying_explosion=nil;target.corpse=nil;target.damaged_trigger_effect=nil
    target.collision_box={{-.02,-.02},{.02,.02}}
    data:extend{target}
end
