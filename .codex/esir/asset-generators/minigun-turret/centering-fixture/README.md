# Native placement-box comparison

From the repository root, invoke `invoke.ps1 -Dossier <fresh ignored minigun dossier>`.
The runner waits for an idle Factorio slot and uses an isolated 2.0.77 configuration.
It enables only base, Graphics6, Minigun Turret HD and the comparison helper.
It does not install mods or launch a controller in production gameplay.

The main SD graphics factory and its original metadata are copied verbatim into
the helper. HD uses the shipping standalone factory. Before/after clones preserve
combat properties and compare four cardinal headings. Actual 3x3 selection boxes
are drawn in green; captures cover parked, firing and stand-down at zoom2.
Data assertions check all256 translated launch entries, all animation/shadow
leaves, preserved metadata and repeated application without cumulative drift.

Run `analyze.py --dossier <the same dossier>` to retain the validation report and
compact comparison. Native opaque-body matching must measure12 screen pixels
south at zoom2 in both densities. PNG hashes are checked against the retained
casing delivery receipt. This historical receipt must remain available.

Inspect native firing attachment and casing ejection before accepting the report.
Complete/close only this run's housekeeping record after retaining validation and
images; unlink only its mod junction entries before snapshotting. No broad main
gameplay load or repeat of the original256-direction firing matrix is claimed.
