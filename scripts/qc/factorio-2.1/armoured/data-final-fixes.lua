-- Assert the actual merged expansion and grouping contracts in both nest modes.
local nest = settings.startup["ab-enable-nest"].value
assert((data.raw["unit-spawner"]["armoured-biter-spawner"] ~= nil) == nest, "Armoured nest mode mismatch")
local names={"small", "medium", "big", "behemoth", "leviathan"}
local spawner=data.raw["unit-spawner"][nest and "armoured-biter-spawner" or "biter-spawner"]
local spawned={}
for _, row in pairs(spawner.result_units) do spawned[row.unit or row[1]]=true end
for _, tier in ipairs(names) do
    local name=tier .. "-armoured-biter"
    local unit=assert(data.raw.unit[name],name)
    assert(spawned[name],"Missing Armoured spawn route " .. name)
    assert(unit.buildable_entities and #unit.buildable_entities>0,"Missing expansion targets " .. name)
    for _, target in ipairs(unit.buildable_entities) do
        local identity=type(target)=="string" and target or target.name
        assert(data.raw["unit-spawner"][identity] or data.raw.turret[identity],"Missing expansion identity " .. tostring(identity))
        if nest then assert(identity=="armoured-biter-spawner","Separate nest expansion escaped family")
        else assert(identity~="armoured-biter-spawner","Disabled nest remains an expansion target") end
    end
    local expected
    if tier=="leviathan" then
        expected=2*data.raw.unit["behemoth-biter"].ai_settings.size_in_group-data.raw.unit["big-biter"].ai_settings.size_in_group
    else expected=data.raw.unit[tier .. "-biter"].ai_settings.size_in_group end
    assert(unit.ai_settings.size_in_group==expected,"Vanilla group scaling mismatch " .. name)
end
log("ESIR ARMOURED FINAL DATA PASS nest=" .. tostring(nest) .. " tiers=5 expansion/group/spawn-routes")
