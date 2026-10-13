ei_graphics_6_path = '__exotic-space-industries-remembrance-graphics-6__/'
local art = require('metadata')
local graphics = require('graphics').create(art, {}, {})
local particle = table.deepcopy(data.raw['optimized-particle']['shell-particle'])
particle.name = 'mg-casing-marker'
particle.pictures = {filename='__core__/graphics/white-square.png', width=10, height=10,
    frame_count=1, scale=0.3, tint={1,0,1,1}}
particle.shadows = nil
particle.life_time = 240
particle.fade_away_duration = 60
particle.vertical_acceleration = 0
particle.movement_modifier_when_on_ground = 1
data:extend{particle}
local specs = {
    {label='false-zero', fields={}},
    {label='false-center-x', fields={center={1,0}}},
    {label='false-center-y', fields={center={0,1}}},
    {label='false-distance', fields={creation_distance=1}},
    {label='false-offset-right', fields={creation_distance=1,creation_distance_orientation=0.25}},
    {label='false-candidate', fields={creation_distance=0.9525754563,
        creation_distance_orientation=153.1659565/360,height=1.166726189}},
    {label='false-height', fields={height=1}},
    {label='receiver-candidate', fields={creation_distance=3.331004451991,
        creation_distance_orientation=0.482194244912,height=0.918880365094}},
}
for index, spec in ipairs(specs) do
    local turret = table.deepcopy(data.raw['ammo-turret']['gun-turret'])
    turret.name = 'mg-casing-probe-'..index
    turret.minable = nil
    turret.collision_box = {{-1.4,-1.4},{1.4,1.4}}
    turret.selection_box = {{-1.5,-1.5},{1.5,1.5}}
    turret.rotation_speed = 0.01
    turret.attacking_speed = 20
    turret.prepare_range = 35
    turret.shoot_in_prepare_state = false
    turret.energy_source = {type='electric',buffer_capacity='666kJ',drain='15kW',usage_priority='primary-input'}
    turret.energy_per_shot = '1kJ'
    turret.attack_parameters.cooldown = 240
    turret.attack_parameters.range = 32
    turret.attack_parameters.shell_particle = {name=particle.name,starting_frame_speed=0,
        direction=0,direction_deviation=0,speed=0,speed_deviation=0,height=0,
        center={0,0},creation_distance=0,creation_distance_orientation=0,use_source_position=false}
    for key,value in pairs(spec.fields) do turret.attack_parameters.shell_particle[key]=value end
    graphics.apply(turret)
    data:extend{turret}
    spec.name = turret.name
    spec.shell_particle = table.deepcopy(turret.attack_parameters.shell_particle)
end
data:extend{
    {type='simple-entity-with-owner',name='mg-casing-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
        max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
        collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},
        picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-casing-probe-data',data={specs=specs}},
}
