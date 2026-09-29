local test = require("test-config")
assert(settings.startup["ei-beacon-overload"].value == test.overload, "Actual overload startup setting")
require("__zzz-esir-beacon-profile-qc__/snapshot").verify()
local expected = {
    gentle = {0.7071067811865476, 0.5946035575013605, 0.5},
    vanilla = {0.5, 0.3535533905932738, 0.25},
    strict = {0.42044820762685725, 0.2726269331663144, 0.1767766952966369},
    harsh = {0.3535533905932738, 0.21022410381342863, 0.125},
    severe = {0.4, 0.2222222222222222, 0.11764705882352941},
    saturating = {0.25, 0.125, 0.0625},
}
local report = {profile = test.profile, overload = test.overload, beacons = {}}
for _, name in ipairs{"ei-copper-beacon", "ei-iron-beacon", "ei-alien-beacon", "ei-warp-beacon"} do
    local beacon = data.raw.beacon[name]
    if not test.overload then
        assert(#beacon.profile == 4096 and beacon.profile[1] == 1 and beacon.beacon_counter == "total", name .. " native contract")
        for i, n in ipairs{4, 8, 16} do
            assert(math.abs(beacon.profile[n] - expected[test.profile][i]) < 1e-12, name .. " sample " .. n)
        end
        for n = 2, 4096 do assert(beacon.profile[n] > 0 and beacon.profile[n] <= beacon.profile[n-1], "Non-monotonic profile") end
    else
        assert(beacon.profile == nil, name .. " enabled mode changed")
    end
    report.beacons[name] = {slots = beacon.module_slots, strength = beacon.distribution_effectivity,
        quality = beacon.distribution_effectivity_bonus_per_quality_level, range = beacon.supply_area_distance,
        count = beacon.profile and #beacon.profile, counter = beacon.beacon_counter,
        first = beacon.profile and beacon.profile[1], four = beacon.profile and beacon.profile[4],
        eight = beacon.profile and beacon.profile[8], sixteen = beacon.profile and beacon.profile[16],
        last = beacon.profile and beacon.profile[4096]}
end
log("BEACON_PROFILE_QC_DATA " .. serpent.line(report, {comment=false}))
