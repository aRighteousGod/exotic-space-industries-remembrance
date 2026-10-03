local module = {}
function module.ballistics()
    data.combat_doctrines_qc=module
    module.before={}
    for _, kind in ipairs{"ammo","gun","ammo-turret","combat-robot","projectile","tree","simple-entity"} do
        module.before[kind]=table.deepcopy(data.raw[kind])
    end
end
function module.radiance()
    local shared=data.combat_doctrines_qc
    shared.visual={}
    for _, kind in ipairs{"fire","sticker","stream","explosion","projectile","rocket-silo","rocket-silo-rocket","fluid-turret"} do
        shared.visual[kind]=table.deepcopy(data.raw[kind])
    end
end
return module
