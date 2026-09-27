-- Injected into the disposable gameplay copy immediately before the new pass.
esir_thrower_qc_before = {}
for _, kind in ipairs{"fluid-turret", "stream", "fire", "sticker", "ammo", "gun"} do
    esir_thrower_qc_before[kind] = table.deepcopy(data.raw[kind])
end
local function equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
return {verify=function()
    -- Check ownership before later, independently owned compatibility passes.
    local config = require("__zzz-esir-thrower-qc__/test-config")
    local catalog = require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
    local allowed = {[catalog.base_turret]=true, ["ei-acidthrower-turret"]=true}
    local owned = {stream={}, fire={}, sticker={}}
    for _,fuel in ipairs(catalog.fuels) do
        allowed[fuel.turret] = true
        owned.stream["ei-flame-"..fuel.id.."-flamethrower-fire-stream"] = true
        owned.fire["ei-flame-"..fuel.id.."-turret-fire"] = true
        owned.sticker["ei-flame-"..fuel.id.."-turret-sticker"] = true
    end
    esir_thrower_qc_isolation_checks = 0
    for kind,prototypes in pairs(esir_thrower_qc_before) do
        for name,source in pairs(prototypes) do
            if config.profile=="original" or not (kind=="fluid-turret" and allowed[name]) and not (owned[kind] and owned[kind][name]) then
                assert(equal(source,data.raw[kind][name]), "THROWER_QC_DATA unchanged "..kind.."/"..name)
                esir_thrower_qc_isolation_checks = esir_thrower_qc_isolation_checks + 1
            end
        end
    end
end}
