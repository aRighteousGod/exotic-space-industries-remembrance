local profiles=require("profiles")
local saucer=data.raw["spider-vehicle"]["ei-gaian-saucer"]
local cathedral=data.raw["spider-vehicle"]["ei-anisetron"]
for _,profile in ipairs(profiles) do
    local vehicle=table.deepcopy(profile.saucer and saucer or cathedral)
    vehicle.name="anisetron-glide-"..profile.id
    vehicle.minable=nil;vehicle.placeable_by=nil;vehicle.guns={}
    if profile.friction then vehicle.friction_force=profile.friction end
    vehicle.spider_engine=table.deepcopy(saucer.spider_engine)
    vehicle.spider_engine.walking_group_overlap=profile.overlap or 0
    local leg=table.deepcopy(data.raw["spider-leg"]["ei-gaian-saucer-leg"])
    leg.name=vehicle.name.."-leg"
    if profile.response then leg.initial_movement_speed=profile.response;leg.movement_acceleration=profile.response end
    if profile.force_scalar then leg.stretch_force_scalar=profile.force_scalar end
    if profile.selection_scale then
        leg.base_position_selection_distance=leg.base_position_selection_distance*profile.selection_scale
        leg.movement_based_position_selection_distance=leg.movement_based_position_selection_distance*profile.selection_scale
    end
    if profile.count==10 then
        vehicle.spider_engine.legs={}
        for i=0,9 do
            local angle=-math.pi*.4+i*math.pi*.2
            local x,y=math.cos(angle),math.sin(angle)/math.sin(math.pi*.4)
            vehicle.spider_engine.legs[i+1]={leg=leg.name,walking_group=i%2+1,
                mount_position={x*.65,-.05+y*.5},ground_position={x*2.7125,-.0775+y*2.325}}
        end
    else
        for _,anchor in ipairs(vehicle.spider_engine.legs) do anchor.leg=leg.name end
    end
    data:extend{leg,vehicle}
end
