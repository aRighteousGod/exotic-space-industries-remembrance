-- Runs in both enabled and disabled ecology profiles, after the gameplay finalizers.
local catalog=require('__exotic-space-industries-remembrance__/lib/alert-catalog')
assert(settings.startup['ei-terrain-evolution-enabled'].value==not require('options').disabled,'wrong ecology startup profile')
for _,entry in ipairs(catalog.entries) do
    local signal=data.raw['virtual-signal'][entry.icon_signal]
    assert(signal and signal.hidden and signal.icon_size==128,'missing hidden alert signal '..entry.id)
    assert(signal.icon=='__exotic-space-industries-remembrance__/graphics/gui/alerts/'..entry.id..'.png','incorrect alert asset pack '..entry.id)
end
assert(data.raw['simple-entity-with-owner']['ei-alert-anchor'],'shared marker missing')
assert(data.raw['simple-entity-with-owner']['ei-ecology-alert-anchor'],'legacy marker must survive ecology startup disablement')
log('ESIR_ALERT_CATALOG_FINAL_DATA_PASS '..#catalog.entries..' ecology='..tostring(settings.startup['ei-terrain-evolution-enabled'].value))
