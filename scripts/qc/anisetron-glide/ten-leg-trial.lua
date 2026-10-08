-- Staged-helper-only public trial. Not loaded by the shipping mod.
local module={}
function module.apply()
    local leg=data.raw['spider-leg']['ei-anisetron-leg']
    leg.initial_movement_speed=.02;leg.movement_acceleration=.02;leg.stretch_force_scalar=.2
    local vehicle=data.raw['spider-vehicle']['ei-anisetron']
    vehicle.spider_engine={walking_group_overlap=0,legs={}}
    for i=0,9 do
        local angle=-math.pi*.4+i*math.pi*.2
        local x,y=math.cos(angle),math.sin(angle)/math.sin(math.pi*.4)
        vehicle.spider_engine.legs[i+1]={leg=leg.name,walking_group=i%2+1,
            mount_position={x*.65,-.05+y*.5},ground_position={x*2.7125,-.0775+y*2.325}}
    end
end
return module
