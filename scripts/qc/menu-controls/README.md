# Menu controls acceptance

Current results and evidence limits: [verification](verification.md).

For focused Administration launcher behavior without starting Factorio:

```powershell
& .tools/lua-5.4.8/lua54.exe scripts/qc/menu-controls/admin-launcher.lua
```

This invokes the actual GUI owner with mocked native boundaries, checking toggle
highlight, show/hide, saved-control adoption and retained session state.

Use the installed Factorio 2.0.77 client and a disposable save with a real player.
Register each new output directory with `esir-housekeeping.ps1` before staging.
Keep the output path short: long native sprite paths can exceed Windows limits.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 `
  -HelperRoot scripts/qc/menu-controls -SeedMods .factorio-qc/egi1/mods `
  -SaveInput .factorio-qc/egi1/fixture.zip -PrepareOnly -OutputRoot .factorio-qc/mc1
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-admin.ps1 `
  -OutputRoot .factorio-qc/mc1
```

The helper checks visible unbound prototypes during final data, then invokes the
actual registered custom-input and GUI handlers with native player/GUI objects.
It covers hidden launcher access, administrator authorization, per-session state,
all seasonal title sprites, unavailable calendars, Alerts, old-layout rebuilding,
configuration/rejoin reconciliation, retained admin drafts and closed-window idle
work. Fixture world/player changes occur only in the copied save.

The enabled run saves `saves/_autosave-menu-controls.zip` with both launchers
hidden. Preserve its initial report, copy that checkpoint to the staged
`fixture.zip`, and run the client again to verify native persistence and reopening.
Use a separately registered output with `-Disabled` during preparation to check
both startup gates; both input prototypes must still exist and remain assignable.

Run the existing `terrain-evolution/run-field-report.ps1 -Quick` fixture at scales
1 and 2 for native property-write instrumentation, translated labels/tooltips,
current-view lifecycle coverage and rendered captures. That fixture also checks
the new title sprite writes against the existing eight-write allowance.

Reports are `script-output/terrain-admin-qc.json`. The focused menu capture is
`script-output/menu-controls/alerts-hidden.png`. These checks invoke handlers;
they do not prove physical key assignment/presses, mouse dragging, native wording
review, or two simultaneous multiplayer clients. Stored-session isolation is
distinct from multiplayer evidence.
