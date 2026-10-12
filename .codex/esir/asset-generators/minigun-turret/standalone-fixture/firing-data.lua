local reference=table.deepcopy(data.raw['ammo-turret']['minigun-turret-hd'])
reference.name='mg-rate-reference'
reference.attack_parameters.cooldown=0.25
local cooldown_probe=table.deepcopy(reference)
cooldown_probe.name='mg-rate-cooldown-probe'
cooldown_probe.attack_parameters.cooldown=1/0.9
local animation_probe=table.deepcopy(reference)
animation_probe.name='mg-rate-animation-probe'
animation_probe.attacking_speed=0.9
data:extend{reference,cooldown_probe,animation_probe,
    {type='simple-entity-with-owner',name='mg-consumer-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
        max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
        collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-consumer-audit',data={standalone=true,damage_multiplier=1,cooldown=1/0.9}}}
