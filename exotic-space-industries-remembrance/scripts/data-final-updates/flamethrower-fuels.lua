-- Clone after ESIR's final turret/technology passes; internal forms always exist,
-- including with adaptation disabled, so saves can be restored without entity loss.
local catalog=require("lib/flamethrower-fuels")
local original=data.raw["fluid-turret"][catalog.base_turret]
original.attack_parameters.fluids={}
for _,fuel in ipairs(catalog.fuels) do
    original.attack_parameters.fluids[#original.attack_parameters.fluids+1]={type=fuel.fluid,damage_modifier=fuel.damage}
end
for _,fuel in ipairs(catalog.fuels) do
    local turret=table.deepcopy(original)
    turret.name=fuel.turret
    turret.localised_name={"entity-name.flamethrower-turret"}
    turret.localised_description={"entity-description.ei-flamethrower-fuel",{"fluid-name."..fuel.fluid},tostring(2*fuel.lifetime),tostring(30*fuel.lifetime)}
    turret.hidden=true
    turret.hidden_in_factoriopedia=true
    turret.factoriopedia_alternative=catalog.base_turret
    turret.placeable_by={item=catalog.base_turret,count=1}
    turret.minable=table.deepcopy(original.minable)
    turret.next_upgrade=nil
    turret.attack_parameters.ammo_type.action.action_delivery.stream="ei-flame-"..fuel.id.."-flamethrower-fire-stream"
    data:extend{turret}
end
for _,technology in pairs(data.raw.technology) do
    local additions={}
    for _,effect in pairs(technology.effects or {}) do
        if effect.type=="turret-attack" and effect.turret_id==catalog.base_turret then
            for _,fuel in ipairs(catalog.fuels) do
                additions[#additions+1]={type="turret-attack",turret_id=fuel.turret,modifier=effect.modifier}
            end
        end
    end
    for _,effect in ipairs(additions) do table.insert(technology.effects,effect) end
end
