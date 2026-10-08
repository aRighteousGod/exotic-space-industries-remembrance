-- Appended only to the staged ESIR pack. Exercise the actual shipping owner.
local mobility_qc = require("scripts/control/anisetron-mobility")
remote.add_interface("anisetron-mobility-qc", {
    snapshot = mobility_qc.get_qc_snapshot,
    rebuild = mobility_qc.rebuild,
})
