-- Appended only to the isolated ESIR copy. Exercise its lifecycle without
-- unrelated cooling proxy creation; real beacon fluids/fuel are supplied by QC.
remote.add_interface("esir-beacon-profile-qc", {
    built = function(entity) ei_beacon_overload.on_built_entity(entity) end,
    snapshot = function(unit) return ei_beacon_overload.get_qc_snapshot(unit) end,
})
