local proxy = data.raw["constant-combinator"]["ei-induction-matrix-core-circuit-interface"]
assert(proxy.item_slot_count == 4)
assert(proxy.hidden and proxy.max_health == 300)
assert(proxy.localised_description[1] == "item-description.ei-induction-matrix-core-circuit-interface")
assert(data.raw.item["ei-induction-matrix-core"].localised_description[1] == proxy.localised_description[1])
for tier=0,16 do
    assert(data.raw["electric-energy-interface"]["ei-induction-matrix-core-"..tier].localised_description[1] == proxy.localised_description[1])
end
assert(table.concat(proxy.flags, ","):find("not%-blueprintable"))
if mods["zzz-esir-induction-circuit-qc"] == "0.0.1" then
    local signal = table.deepcopy(data.raw["virtual-signal"]["signal-C"])
    signal.name = "matrix-qc-removed-signal"
    data:extend{signal}
end
log("INDUCTION_CIRCUIT_QC DATA_PASS")
