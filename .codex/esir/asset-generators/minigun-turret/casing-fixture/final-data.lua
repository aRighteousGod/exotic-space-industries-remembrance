local config=require('test-config')
local turret=assert(data.raw['ammo-turret'][config.entity])
local attack=turret.attack_parameters
local particle=assert(data.raw['optimized-particle'][attack.shell_particle.name])
local launch=table.deepcopy(attack.projectile_creation_parameters)
assert(#launch==256)
assert(particle.life_time==240 and particle.fade_away_duration==60)
assert(particle.movement_modifier_when_on_ground==0.6)
assert(data.raw['optimized-particle']['shell-particle'].life_time==600)
assert(attack.shell_particle.use_source_position==false)
assert(attack.cooldown==(config.standalone and 1/0.9 or 0.25))
assert((attack.damage_modifier or 1)==1)
assert(turret.attacking_speed==20 and turret.preparing_speed==1/12 and turret.folding_speed==1/18)
local particle_baseline=table.deepcopy(data.raw['optimized-particle']['shell-particle'])
local normalized=table.deepcopy(particle)
normalized.name=particle_baseline.name
normalized.life_time=particle_baseline.life_time
normalized.fade_away_duration=particle_baseline.fade_away_duration
normalized.movement_modifier_when_on_ground=particle_baseline.movement_modifier_when_on_ground
-- Marker copies are fixture-only: observe the same native trajectory, one shot.
local marker=table.deepcopy(particle)
marker.name='mg-casing-flight-marker'
marker.pictures={filename='__core__/graphics/white-square.png',width=10,height=10,
    frame_count=1,scale=0.2,tint={1,0,1,1}}
marker.shadows=nil
local single=table.deepcopy(turret)
single.name='mg-casing-single';single.minable=nil
single.attack_parameters.cooldown=240
single.attack_parameters.shell_particle=table.deepcopy(attack.shell_particle)
single.attack_parameters.shell_particle.name=marker.name
single.attack_parameters.shell_particle.direction_deviation=0
single.attack_parameters.shell_particle.speed_deviation=0
single.attack_parameters.shell_particle.starting_frame_speed=0
single.attack_parameters.shell_particle.starting_frame_speed_deviation=0
data:extend{marker,single,
    {type='simple-entity-with-owner',name='mg-casing-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
        max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
        collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},
        picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-casing-final-audit',data={shell_particle=table.deepcopy(attack.shell_particle),
        particle={life_time=particle.life_time,fade_away_duration=particle.fade_away_duration,
            movement_modifier_when_on_ground=particle.movement_modifier_when_on_ground,
            vertical_acceleration=particle.vertical_acceleration},
        vanilla_particle=particle_baseline,private_particle_normalized=normalized,
        launch=launch,launch_fields={projectile_center=attack.projectile_center,
            projectile_creation_distance=attack.projectile_creation_distance,
            apply_projection_to_projectile_creation_position=attack.apply_projection_to_projectile_creation_position},
        cooldown=attack.cooldown,damage_modifier=attack.damage_modifier or 1,
        range=attack.range,min_range=attack.min_range,rotation_speed=turret.rotation_speed,
        attacking_speed=turret.attacking_speed,preparing_speed=turret.preparing_speed,folding_speed=turret.folding_speed,
        mods=mods}},
}
