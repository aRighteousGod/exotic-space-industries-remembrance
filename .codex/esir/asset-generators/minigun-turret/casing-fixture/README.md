# Native casing fixture

From the repository root, run `invoke-probe.ps1` or `invoke-final.ps1` with a new
`-Attempt`. Both wait for fifteen seconds of idle engine time and launch only
their isolated Factorio 2.0.77 configuration. They do not install mods. Select
`standalone`, `esir-sd` or `esir-hd`; main supports `-Ballistic off/on`.

The default output is the retained casing-ejection-001 dossier. `-Dossier` can
select a fresh ignored dossier. Final main cases accept `-MainSource` for an
isolated source snapshot. The recorded acceptance used the committed001559f
main snapshot plus the casing prototype, complete installed Graphics1–5 ZIPs
and committed Graphics6, while unrelated source assets were moving.

Use `analyze_probe.py --attempt <attempt> --dossier <dossier>` or
`analyze_final.py --case <case>-<off/on>-<attempt> --dossier <dossier>` after the
engine runner. Zero-spread stationary magenta markers establish origin behavior;
normal artwork validates the production ejection. A single magenta particle
tracks flight without changing the production particle. Native ammunition use
provides the steady-window shot count. Test helpers never ship in either ZIP.

Complete and close the task-owned housekeeping records after retaining reports
and image evidence. Preserve failed diagnostics until the failure is summarized.
See [the casing contract](../CASING-EJECTION.md) and the dossier acceptance receipt
for exact source, package and visual evidence.

Final delivery is `packages-complete/`: current thin main, complete current
Graphics6 and HD. Install the main and Graphics6 ZIPs together. These package
snapshots differ from the isolated native test source described above; unrelated
asset relocation has not received a new whole-mod validation in this fixture.
