# Native owner repair preservation

The final connected-player fixture ran on Factorio **2.0.77 build 84539** on
2026-10-02. Its focused slice passed **74/74 assertions**: 54 active repair
preservation checks, eight pure diagnostics checks and 12 closed-GUI service
checks. The earlier 2026-09-29 slice contained 46 preservation checks.
Each owner below was repaired twice in the same event after capturing its active
state, so ordinary simulation updates could not hide a destructive repair.

| Owner | Native setup and preserved state |
| --- | --- |
| EM trains | A real rare locomotive outside charger coverage held an active grace deadline and native burner reserve. Two repairs retained its deadline, fuel identity/quality and stored energy; the next owner update retained propulsion outside coverage. |
| Fusion reactor | A real assembler with four populated fluid buffers. Repair retained its record, manual/effective fuel selections, control source, recipe, crafting progress and native fluid contents. |
| Crystal accumulator | A real charged accumulator with instability, energy history, a future cooldown and frozen state. Repair retained record identity, scalar state, native energy and deadline. |
| Railgun cooling | A real turret and coolant proxy processed the owner shot hook, producing five units of heat debt and a pending recovery deadline. Both repairs retained that debt, hot/cold fluid names, amounts and temperatures, the proxy and recovery time. |
| Emerald Apocalypse | A real tank held a committed delayed charge, separate trunk reserve, drift, cooldown, doctrine and shield pulse queue. Repairs retained the paid charge profile and bucket, native ammunition/reserve counts, future deadline, drift and pulse queue. |
| Environmental rupture | The native positional adapter admitted a 20 MJ job. Both repairs retained the same job and ring objects, ring buckets, next ring, deadline and pending count. |

The railgun and Emerald probes enter through their real owner script-effect
boundaries. The Emerald fixture explicitly consumes one native ammunition item
before its hook, matching the engine boundary at which the gun has already paid.
This validates repair preservation of a committed charge; it does not claim that
the fixture fired the native weapon. Fusion selection normalization starts from a
valid normalized record rather than treating newly derived metadata as lost state.

The broader fixture also invokes all **43 registered repair providers twice**.
Those successful calls check coverage and idempotent invocation; only the six
owners above have these focused active-state assertions.

Run with a disposable real-player save:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-tools-qc.ps1 -RunName preserve -PlayerSave .factorio-qc/wtr/final-player/fixture.zip -Ticks 180
```

The driver stages live sources and dependencies in the ignored
`.factorio-qc/admin-preserve` directory. The native report is
`script-output/admin-qc.json`; the focused sequence starts at
`fusion native input/output buffers populated` and ends at
`preservation fixture completed`. Additional GUI, research or lifecycle checks
in that report have separate outcomes. These are headless behavior checks, not
visual review or a whole-factory performance measurement.

The final integration report is
`.factorio-qc/admin-completion-20261002b/script-output/admin-qc.json` (334/334
checks overall). Its focused slice starts at `neutron closed GUI retains empty
bucket identity` and ends at `preservation fixture completed`.

The later window/default-mode/auto-refresh replay is
`.factorio-qc/admin-completion-window-auto-2/script-output/admin-qc.json`
(362/362 overall). It retains the same 74-check preservation/diagnostics/closed-GUI
slice. The additional assertions concern console defaults and lifecycle, not
new active repair setups.

The final saved-toolbar upgrade replay is
`.factorio-qc/admin-completion-legacy-toolbar/script-output/admin-qc.json`
(365/365 overall). It retains that same 74-check slice; its three additional
checks verify one explicit-open structural upgrade with retained position and
drafts, without enabling automatic refresh.

The diagnostics probes verify crystal/Emerald scheduler publication keys, real
Emerald charge/pulse deadlines and paid-charge inspection collections. Fixture
cache slots are restored exactly after each read-only probe. Neutron and matter
GUI service tests verify empty-bucket identity, unchanged GUI-only timestamps,
one-time stale scheduling cleanup and no initialization of missing GUI state.

The first final replay failed three EM assertions because the fixture compared
native `LuaBurner.currently_burning` (an item/quality pair) to a bare item
prototype. The corrected fixture compares the native pair and energy value;
no gameplay source correction was required for that mismatch. The earned grace
deadline preservation adapter remains the actual repair change.
