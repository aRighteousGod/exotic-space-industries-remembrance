ei_graphics_6_path = '__exotic-space-industries-remembrance-graphics-6__/'
local art = require('main-graphics-data')
local main = require('main-graphics')
local baseline = main.create(require('baseline-graphics-data'),{}).creation_parameters()
local archived = require('baseline-launch')
for i,entry in ipairs(baseline) do
    assert(entry[1]==archived[i][1])
    for axis=1,2 do assert(math.abs(entry[2][axis]-archived[i][2][axis])<1e-10) end
end
local donor = assert(data.raw['ammo-turret']['minigun-turret-hd'])
local original = table.deepcopy(art)
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function normalize(value)
    if type(value)=='string' then return value:gsub('__exotic%-space%-industries%-remembrance%-graphics%-6__','__minigun-turret-HD__') end
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=normalize(v) end;return out
end
assert(equal(normalize(art.profiles.sd),art.profiles.hd),'Default layout differs from HD')
local groups={}
local indexed,full
for _, entry in ipairs{{'indexed',{}},{'full-color',{['minigun-turret-HD']='1.0.0'}}} do
    local factory=main.create(art,entry[2]);local turret=table.deepcopy(donor)
    factory.apply(turret)
    local repeated=table.deepcopy(turret);factory.apply(repeated);assert(equal(turret,repeated))
    assert(equal(turret.attack_parameters.projectile_creation_parameters,baseline))
    assert(equal(turret.attack_parameters.shell_particle,donor.attack_parameters.shell_particle))
    assert(turret.attack_parameters.projectile_center[1]==0 and turret.attack_parameters.projectile_center[2]==0)
    assert(turret.attack_parameters.projectile_creation_distance==2)
    assert(turret.attack_parameters.apply_projection_to_projectile_creation_position==nil)
    assert(turret.preparing_speed==1/12 and turret.folding_speed==1/18)
    local function inspect(value)
        if type(value)~='table' then return end
        if value.filename or value.filenames then assert(value.scale==0.5) end
        for _,v in pairs(value) do inspect(v) end
    end
    inspect(turret.graphics_set)
    for _,state in ipairs{'folded_animation','preparing_animation','prepared_animation','attacking_animation','folding_animation'} do inspect(turret[state]) end
    turret.name='mg-centering-'..entry[1];turret.minable=nil;turret.next_upgrade=nil
    data:extend{turret};groups[#groups+1]={density=entry[1],state='HD64',entity=turret.name}
    if entry[1]=='indexed' then indexed=turret else full=turret end
end
assert(equal(indexed.attack_parameters,full.attack_parameters))
assert(equal(original,art),'Factory mutated source metadata')
data:extend{
    {type='simple-entity-with-owner',name='mg-centering-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
        max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
        collision_box={{-.1,-.1},{.1,.1}},selection_box={{-.1,-.1},{.1,.1}},
        picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-centering-audit',data={groups=groups,all256_centered_launch_entries_unchanged=true,
        all_leaf_layouts_equal=true,repeated_apply_stable=true,source_metadata_unchanged=true,
        indexed_density=64,full_color_density=64,launch=baseline,combat_and_casings_equal=true}}
}
