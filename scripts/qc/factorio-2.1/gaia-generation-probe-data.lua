-- Private diagnostic clones only. Production spawners are not modified.
local rows={}
for _,name in ipairs{'flying-electric-unit-spawner','walker-electric-unit-spawner'} do
    local original=data.raw['unit-spawner'][name]
    local row={}
    for _,field in ipairs{'name','order','autoplace','collision_box','collision_mask','selection_box',
        'max_count_of_owned_units','max_count_of_owned_defensive_units','max_friends_around_to_spawn',
        'max_defensive_friends_around_to_spawn','spawning_radius','spawning_spacing','spawning_cooldown',
        'result_units','absorptions_per_second','max_health'} do row[field]=table.deepcopy(original[field]) end
    rows[name]=row
    local clone=table.deepcopy(original)
    clone.name='esir-qc-empty-'..name
    clone.autoplace.default_enabled=false
    clone.max_count_of_owned_units=0
    clone.max_count_of_owned_defensive_units=0
    clone.max_friends_around_to_spawn=0
    clone.max_defensive_friends_around_to_spawn=0
    data:extend{clone}
end
data:extend{{type='mod-data',name='esir-qc-gaia-spawner-prototypes',data=rows}}
