-- Required only in the staged ESIR copy, immediately before its profile pass.
local before = table.deepcopy(data.raw.beacon)
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
return {verify = function()
    local test = require("__zzz-esir-beacon-profile-qc__/test-config")
    local names = {["ei-copper-beacon"]=true, ["ei-iron-beacon"]=true, ["ei-alien-beacon"]=true, ["ei-warp-beacon"]=true}
    local count = 0
    for name, original in pairs(before) do
        local current = table.deepcopy(data.raw.beacon[name])
        if names[name] then
            current.localised_description = original.localised_description
            if not test.overload then
                current.profile = original.profile
                current.beacon_counter = original.beacon_counter
            end
        end
        assert(equal(original, current), "Unexpected beacon mutation: " .. name)
        count = count + 1
    end
    log("BEACON_PROFILE_QC_ISOLATION " .. count)
end}
