ei_graphics_6_path = '__exotic-space-industries-remembrance-graphics-6__/'
local art = require('main-graphics-data')
local main = require('main-graphics')
local donor = assert(data.raw['ammo-turret']['minigun-turret-hd'])
local delta = 6 / 32

local function leaves(value, out)
    if value.layers then
        for _, child in ipairs(value.layers) do leaves(child, out) end
    else out[#out+1] = value end
end
local function animations(turret)
    local out = {}
    for _, base in ipairs(turret.graphics_set.base_visualisation) do leaves(base.animation, out) end
    for _, field in ipairs({'folded_animation','preparing_animation','prepared_animation','attacking_animation','folding_animation'}) do
        leaves(turret[field], out)
    end
    return out
end
local function before(turret)
    for _, leaf in ipairs(animations(turret)) do leaf.shift[2] = leaf.shift[2] - delta end
    for _, entry in ipairs(turret.attack_parameters.projectile_creation_parameters) do entry[2][2] = entry[2][2] - delta end
end

local sd = table.deepcopy(donor)
main.create(art, {}).apply(sd)
local sd_repeated = table.deepcopy(sd)
main.create(art, {}).apply(sd_repeated)
local hd_repeated = table.deepcopy(donor)
require('__minigun-turret-HD__.lib.graphics').create{include_shadows=true}.apply(hd_repeated)
local groups = {}
for _, density in ipairs({'sd','hd'}) do
    local changed = table.deepcopy(density=='sd' and sd or donor)
    local old = table.deepcopy(changed)
    before(old)
    for _, item in ipairs{{'before',old},{'after',changed}} do
        item[2].name = 'mg-centering-'..density..'-'..item[1]
        item[2].minable = nil
        item[2].next_upgrade = nil
        data:extend{item[2]}
        groups[#groups+1] = {density=density,state=item[1],entity=item[2].name}
    end
    for i, entry in ipairs(changed.attack_parameters.projectile_creation_parameters) do
        local original = art.projectile_creation_parameters[i]
        assert(entry[1]==original[1] and entry[2][1]==original[2][1])
        assert(math.abs(entry[2][2]-original[2][2]-delta)<1e-12)
        assert(math.abs(entry[2][2]-old.attack_parameters.projectile_creation_parameters[i][2][2]-delta)<1e-12)
    end
    local a,b = animations(old),animations(changed)
    assert(#a==#b)
    for i, leaf in ipairs(a) do
        assert(leaf.shift[1]==b[i].shift[1] and math.abs(b[i].shift[2]-leaf.shift[2]-delta)<1e-12)
    end
end
assert(sd.attack_parameters.projectile_creation_parameters[1][2][2]==sd_repeated.attack_parameters.projectile_creation_parameters[1][2][2])
assert(donor.attack_parameters.projectile_creation_parameters[1][2][2]==hd_repeated.attack_parameters.projectile_creation_parameters[1][2][2])
assert(art.profiles.sd.base.shift[2]<0 and art.profiles.hd.base.shift[2]<0)
assert(donor.attack_parameters.projectile_center[1]==0 and donor.attack_parameters.projectile_center[2]==0)
assert(donor.attack_parameters.apply_projection_to_projectile_creation_position==nil)
data:extend{
    {type='simple-entity-with-owner',name='mg-centering-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
        max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
        collision_box={{-.1,-.1},{.1,.1}},selection_box={{-.1,-.1},{.1,.1}},
        picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-centering-audit',data={groups=groups,delta=delta,
        all256_launch_entries_translated=true,all_animation_and_shadow_leaves_translated=true,
        repeated_apply_stable=true,source_metadata_unchanged=true,
        base_shift_before=art.profiles.sd.base.shift,base_shift_after=sd.graphics_set.base_visualisation[1].animation.shift,
        selection_box=donor.selection_box,collision_box=donor.collision_box,
        launch=sd.attack_parameters.projectile_creation_parameters,
        shell_particle=donor.attack_parameters.shell_particle}}
}
