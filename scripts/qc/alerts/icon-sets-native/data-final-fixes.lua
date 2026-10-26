local catalog=require("__exotic-space-industries-remembrance__/lib/alert-catalog")
local sets=require("__exotic-space-industries-remembrance__/lib/alert-icon-sets")
local count=0
for _,id in ipairs(sets.builtin_ids) do
    for _,entry in ipairs(catalog.entries) do
        local signal=assert(data.raw["virtual-signal"][sets.signal_name(id,entry.id)])
        local directory=id=="original" and "" or id.."/"
        assert(signal.hidden and signal.icon_size==128)
        assert(signal.icon=="__exotic-space-industries-remembrance__/graphics/gui/alerts/"..directory..entry.id..".png")
        count=count+1
    end
end
assert(count==108,"all four builtin families must be complete")
if mods["esir-icon-sets-provider-qc"] then
    local provider="esir-icon-sets-provider-qc__partial"
    for _,entry in ipairs(catalog.entries) do
        local signal=assert(data.raw["virtual-signal"][sets.signal_name(provider,entry.id)])
        if entry.id=="gate-low-power" then assert(#signal.icons==2 and signal.icons[2].shift[1]==8)
        else assert(signal.icon==data.raw["virtual-signal"][sets.signal_name("svg",entry.id)].icon) end
    end
end
log("ESIR_ICON_SETS_FINAL_DATA_PASS builtin="..count.." ecology="..tostring(settings.startup["ei-terrain-evolution-enabled"].value))
