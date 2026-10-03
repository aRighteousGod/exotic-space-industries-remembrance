-- Disposable native receivers: copied attack geometry, no shipping prototypes.
local target = {type="simple-entity-with-owner",name="ei-combat-doctrines-qc-target",
    icon="__base__/graphics/icons/wood.png",icon_size=64,max_health=1000000,resistances={},
    flags={"placeable-player","placeable-enemy"},is_military_target=true,
    collision_box={{-1,-4},{1,4}},selection_box={{-1,-4},{1,4}},
    picture={filename="__core__/graphics/empty.png",width=1,height=1}}
if require("test-config")["miss-scene"] then target.collision_box={{-1,-.25},{1,.25}};target.selection_box=target.collision_box end
data:extend{target}
local wide=table.deepcopy(target)
wide.name="ei-combat-doctrines-qc-range-target"
wide.collision_box={{-1,-80},{1,80}}
wide.selection_box=wide.collision_box
data:extend{wide}
local fragile=table.deepcopy(target)
fragile.name="ei-combat-doctrines-qc-fragile-target"
fragile.max_health=5
fragile.is_military_target=false
data:extend{fragile}
for _, category in ipairs{"bullet", "shotgun-shell"} do
    local turret=table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
    turret.name="ei-combat-doctrines-qc-"..category
    turret.attack_parameters=table.deepcopy(data.raw.gun[category == "bullet" and "submachine-gun" or "combat-shotgun"].attack_parameters)
    turret.attack_parameters.range=90
    turret.attack_parameters.turn_range=1
    turret.attack_parameters.cooldown=10000
    if require("test-config").mode=="performance" or require("test-config").mode=="rendering" then turret.attack_parameters.cooldown=6 end
    turret.attack_parameters.damage_modifier=1
    turret.minable=nil
    data:extend{turret}
end
if require("test-config").mode=="compatibility" then
    local wide=table.deepcopy(data.raw.ammo["shotgun-shell"])
    wide.name="ei-combat-doctrines-qc-wide-shotgun"
    local actions=wide.ammo_type.action
    for _,action in ipairs(actions.type and {actions} or actions) do
        if action.action_delivery and action.action_delivery.type=="projectile" then
            wide.ammo_type.action=table.deepcopy(action)
            wide.ammo_type.action.action_delivery.range_deviation=.6
            break
        end
    end
    local branches=table.deepcopy(data.raw.ammo["firearm-magazine"])
    branches.name="ei-combat-doctrines-qc-branches"
    local first,second=table.deepcopy(branches.ammo_type),table.deepcopy(branches.ammo_type)
    first.action={type="direct",action_delivery={type="instant",
        source_effects={{type="create-explosion",entity_name="explosion-gunshot"}},
        target_effects={{type="damage",damage={amount=5,type="physical"}}}}}
    second.action={type="area",radius=1,action_delivery={type="instant",
        target_effects={{type="damage",damage={amount=5,type="physical"}}}}}
    first.source_type="player";first.range_modifier=1.3
    second.source_type="turret"
    branches.ammo_type={first,second}
    local dual=table.deepcopy(data.raw.ammo["firearm-magazine"])
    dual.name="ei-combat-doctrines-qc-dual"
    dual.ammo_type=table.deepcopy(first)
    dual.ammo_type.source_type=nil
    local action=dual.ammo_type.action
    action.probability=.7;action.repeat_count=2
    action.action_delivery={table.deepcopy(action.action_delivery),table.deepcopy(action.action_delivery)}
    action.action_delivery[2].target_effects[1].damage.amount=3
    data:extend{wide,branches,dual}
end
