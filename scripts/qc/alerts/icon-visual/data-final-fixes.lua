local catalog=require('__exotic-space-industries-remembrance__/lib/alert-catalog')
assert(settings.startup['ei-terrain-evolution-enabled'].value==not require('options').disabled)
for _,entry in ipairs(catalog.entries) do
    local signal=data.raw['virtual-signal'][entry.icon_signal]
    assert(signal and signal.hidden and signal.icon_size==128,entry.id)
    assert(signal.icon=='__exotic-space-industries-remembrance-graphics-6__/graphics/gui/alerts/'..entry.id..'.png',entry.id)
end
log('ESIR_ICON_FINAL_DATA_PASS '..#catalog.entries..' ecology='..tostring(settings.startup['ei-terrain-evolution-enabled'].value))
