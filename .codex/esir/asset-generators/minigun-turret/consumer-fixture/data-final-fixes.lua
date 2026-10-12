-- Isolated consumers use the actual shipping identifiers and pack paths.
local config = require('test-config')
local audit = {config=config, active_mods=table.deepcopy(mods), standalone=config.standalone}
local function mechanics(turret)
    local attack = table.deepcopy(turret.attack_parameters)
    for _,key in ipairs({'projectile_creation_parameters','projectile_center','projectile_creation_distance',
        'apply_projection_to_projectile_creation_position','shell_particle'}) do attack[key]=nil end
    return {attack=attack,energy_source=turret.energy_source,energy_usage=turret.energy_usage,energy_per_shot=turret.energy_per_shot,
        attacking_speed=turret.attacking_speed,rotation_speed=turret.rotation_speed,
        inventory_size=turret.inventory_size,collision_box=turret.collision_box,selection_box=turret.selection_box,
        circuit_connector=turret.circuit_connector}
end
local function visuals(turret)
    local result={}
    for _,key in ipairs({'base_picture','turret_base_has_direction','graphics_set','gun_animation_render_layer',
        'gun_animation_secondary_draw_order','folded_animation','preparing_animation','prepared_animation',
        'starting_attack_animation','attacking_animation','ending_attack_animation','folding_animation',
        'preparing_speed','preparing_speed_secondary','folding_speed','folding_speed_secondary'}) do
        result[key]={present=turret[key]~=nil,value=table.deepcopy(turret[key])}
    end
    return result
end
if config.standalone then
    assert(not mods['exotic-space-industries-remembrance'] and not mods['exotic-space-industries-remembrance-graphics-6'],
        'Standalone example accidentally depends on ESIR or G6')
    assert(not data.raw['ammo-turret']['example-minigun-turret'],'HD asset pack loaded a gameplay example by itself')
    audit.example_absent_before_private_require=true
    if config.scenario=='standalone-example' then
        require('__minigun-turret-HD__.examples.data')
        local graphics=require('__minigun-turret-HD__.lib.graphics').create{include_shadows=false}
        local art=require('__minigun-turret-HD__.lib.graphics-data')
        local actual=assert(data.raw['ammo-turret']['example-minigun-turret'])
        local expected=table.deepcopy(actual)
        graphics.apply(expected) -- Unregistered comparison; actual example stays untouched.
        audit.actual_visuals=visuals(actual);audit.expected_visuals=visuals(expected)
        audit.expected_creation_parameters=art.projectile_creation_parameters
        audit.expected_launch_contract=art.native_launch_contract
        audit.expected_icons=graphics.icons()
        audit.consumer_untouched=true
        local technology=table.deepcopy(data.raw.technology.military)
        technology.name='mg-consumer-example';technology.effects={{type='unlock-recipe',recipe='example-minigun-turret'}}
        local icon=graphics.icons().technology
        technology.icon,technology.icon_size,technology.icons,technology.icon_mipmaps=icon.icon,icon.icon_size,nil,nil
        data:extend{technology}
        audit.example_loaded_only_by_private_helper=true
    end
else
    local art=require('consumer-graphics-data')
    local mechanical=require('candidate-mechanical-data')
    local turret=assert(data.raw['ammo-turret']['ei-gatling-turret'])
    audit.before=mechanics(turret)
    -- Visual review precedes finalization. Drafts stay explicit full256 fixtures;
    -- finalized metadata must pass the actual production construction guards.
    local options=config.finalized and {} or {fixture=true,direction_count=256}
    local graphics=require('__exotic-space-industries-remembrance__/prototypes/electricity-age/gatling-turret/graphics').create(art,mods,options)
    audit.factory_options=options
    local icons=graphics.icons()
    if config.finalized then
        -- Read the shipping consumer after all main passes. Applying anything to
        -- it here would conceal the very integration errors this run must find.
        local expected=table.deepcopy(turret)
        graphics.apply(expected) -- Unregistered comparison object only.
        audit.actual_visuals=visuals(turret);audit.expected_visuals=visuals(expected)
        audit.expected_creation_parameters=graphics.creation_parameters()
        audit.expected_launch_contract=art.native_launch_contract
        audit.expected_icons=icons
        local baselines=assert(art.provenance.finalization_evidence.consumer_combat_baselines,
            'Finalized consumer lacks approved pre-final combat baselines')
        audit.combat_doctrine=config.ballistic and 'on' or 'off'
        local baseline=assert(baselines.doctrines[audit.combat_doctrine],
            'This doctrine has no approved pre-final combat baseline')
        audit.expected_combat_mechanics=baseline.snapshot
        audit.expected_combat_baseline_sha256=baseline.snapshot_sha256
        audit.consumer_untouched=true
    else
        graphics.apply(turret)
        turret.attack_parameters.projectile_creation_parameters=graphics.creation_parameters()
        if art.native_launch_contract then
            for name,field in pairs(art.native_launch_contract) do
                if field.present then turret.attack_parameters[name]=table.deepcopy(field.value) else turret.attack_parameters[name]=nil end
            end
        else
            for _,key in ipairs({'projectile_center','apply_projection_to_projectile_creation_position'}) do
                if mechanical[key]~=nil then turret.attack_parameters[key]=table.deepcopy(mechanical[key]) end
            end
        end
        if mechanical.shell_particle then turret.attack_parameters.shell_particle=table.deepcopy(mechanical.shell_particle) end
        -- The recipe retains actual main_product inheritance; no explicit icon
        -- is inserted by the observer, even before finalization.
        for _,entry in ipairs({turret,data.raw.item['ei-gatling-turret']}) do
            entry.icon,entry.icon_size,entry.icons,entry.icon_mipmaps=icons.item.icon,icons.item.icon_size,nil,nil
        end
        local technology=data.raw.technology['ei-gatling-turret']
        technology.icon,technology.icon_size,technology.icons,technology.icon_mipmaps=icons.technology.icon,icons.technology.icon_size,nil,nil
        audit.consumer_untouched=false
    end
    -- Connector placement remains user-owned; the candidate must preserve it.
    audit.after=mechanics(turret)
end
local turret=assert(data.raw['ammo-turret'][config.entity_name])
audit.icons={}
for _,kind in ipairs({'item','recipe','ammo-turret'}) do
    local prototype=assert(data.raw[kind][config.entity_name])
    audit.icons[kind]={icon=prototype.icon,icon_size=prototype.icon_size,icons=prototype.icons,main_product=prototype.main_product}
end
local technology=data.raw.technology[config.technology_name]
audit.icons.technology={icon=technology.icon,icon_size=technology.icon_size,icons=technology.icons}
audit.frames={preparing=turret.preparing_animation,folding=turret.folding_animation,prepared=turret.prepared_animation}
audit.graphics_set=turret.graphics_set
audit.launch=table.deepcopy(turret.attack_parameters)
audit.sprite_paths={};audit.shadow_leaf_count=0
local seen={}
local function sprites(value)
    if type(value)~='table' then return end
    if value.filename and not seen[value.filename] then seen[value.filename]=true;audit.sprite_paths[#audit.sprite_paths+1]=value.filename end
    if value.filenames then for _,path in ipairs(value.filenames) do
        if not seen[path] then seen[path]=true;audit.sprite_paths[#audit.sprite_paths+1]=path end
    end end
    if value.draw_as_shadow then audit.shadow_leaf_count=audit.shadow_leaf_count+1 end
    for _,child in pairs(value) do if type(child)=='table' then sprites(child) end end
end
for _,key in ipairs({'folded_animation','preparing_animation','prepared_animation','starting_attack_animation',
    'attacking_animation','ending_attack_animation','folding_animation','graphics_set'}) do sprites(turret[key]) end
table.sort(audit.sprite_paths)
data:extend{{type='simple-entity-with-owner',name='mg-consumer-target',icon='__base__/graphics/icons/wood.png',icon_size=64,
    max_health=1000000000,flags={'placeable-player','placeable-enemy'},is_military_target=true,
    collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},picture={filename='__core__/graphics/empty.png',width=1,height=1}},
    {type='mod-data',name='mg-consumer-audit',data=audit}}
