# Menu controls verification — 2026-10-24

Implemented the per-player Ecology launcher toggle, seasonal 48-unit title icon,
and unbound Administration/Ecology toggle controls. Main mod version remains
**1.3.41**. The native evidence uses Factorio **2.0.77** and isolated copied saves.

| Check | Result | Evidence |
| --- | --- | --- |
| Enabled menus and native save/reload | 46/46 passed (43 initial checks plus 3 reload checks) | `.factorio-qc/mc1/enabled-report.json`, `.factorio-qc/mc1/script-output/terrain-admin-qc.json` |
| Startup-disabled menu gates | 2/2 passed | `.factorio-qc/mc0/script-output/terrain-admin-qc.json` |
| Unbound, visible, independent custom-input prototypes | Passed with both startup profiles | `MENU_CONTROLS_QC unbound visible prototypes passed` in the mc1/mc0 client logs |
| Field report, UI scale 1 | 551/551 passed; 396/396 native English translations | `.factorio-qc/mf1/script-output/terrain-admin-qc.json` |
| Field report, UI scale 2 | 551/551 passed; 396/396 native English translations | `.factorio-qc/mf2/script-output/terrain-admin-qc.json` |
| Eight-locale coverage, tokens, encoding and duplicate checks | Passed | `python -X utf8 -B scripts/qc/terrain-evolution/audit-locales.py` |
| Blueprint ownership and links | 58 models, zero findings | Live-source `blueprint_audit.py` |
| Module headers, Lua syntax, requires, locale references, asset references and pack versions | Passed | `.factorio-qc/mc1/preflight.json` |
| Offline GUI lifecycle | 3/3 passed with mocked native boundaries | `scripts/qc/terrain-evolution/v2-gui.lua` |
| Python syntax without bytecode-cache writes | All 293 tracked Python files compiled in memory | Read-only `compile()` pass |
| Diff whitespace | Passed | `git diff --check` |

The focused menu fixture covers hidden-launcher reopening, toggle state, saved
preferences, retained admin page/drafts, non-admin denial, all four seasonal tree
sprites, unavailable-calendar fallback, the Alerts tab, configuration/rejoin
reconciliation and old-layout rebuilding. Rebuilding exposed synchronous
`on_gui_closed` re-entry when clearing `player.opened`; the final close path releases
the session reference first and passes the native regression and reload cases.

Each field-report run independently instrumented eight native refreshes. The
maximum observed work was **8 property writes and 30 binding inspections** per
instrumented refresh. The title sprite is included in setter instrumentation.
Closed-report checks passed with no report composition or public snapshots.
This is bounded GUI-work evidence, not a whole-engine performance measurement.

Inspected the native `nauvis-top.png` captures at scales 1 and 2 under
`.factorio-qc/mf1/script-output/ecology-field/en/` and
`.factorio-qc/mf2/script-output/ecology-field/en/`. The title icon, highlighted
visible-launcher toggle, tabs and close button fit without overlap. The focused
Alerts capture also shows the title with the launcher hidden. Its autosave overlay
does not obscure the title or toggle.

Full preflight remains failed for unrelated existing findings:

- Encoding: `scripts/qc/singularity-lance/angular-results.json`,
  `temp/anisetron-tracking-fix/blueprint-final.json`, and
  `temp/storage-audit-c/evidence-link-update.json`.
- Python bytecode-cache path failures for the acidthrower origin-calibration and
  singularity-lance death-implosion generators. The separate in-memory syntax pass
  succeeded for all tracked Python sources.

The five changed prototype/runtime owners in all four profiles matched the task
source when checked after native acceptance. The two custom-input annotations
were then qualified as `EventData.CustomInputEvent` to match the installed editor
types. A final comparison found separate concurrent alert-system edits: a new
catalog import, icon captions in Alerts, GUI layout version 4 and additional
alert-system wiring elsewhere. Those changes were preserved. The menu handlers,
title, launcher preference and reentrant close behavior remain intact; the native
results above cover the tested layout-3 snapshot, not runtime acceptance of the
subsequent alert refactor. Fixtures now accept newer layout versions while checking
the required title/toggle handles, so they do not demand a layout-version rollback.

These runs invoke registered handlers with native GUI/player objects. Physical
key assignment/presses, mouse dragging, native-language wording review and two
simultaneous multiplayer clients were not exercised. Stored-session isolation
does not establish multiplayer acceptance. See [reproduction instructions](README.md).

## Administration launcher normalization - 2026-10-25

Administration now highlights **Toggle launcher button** while its launcher is
shown, matching Ecology. Saved windows adopt the existing tagged control in
place; hiding the launcher retains the console, page, drafts, position and
auto-refresh preference. The main mod version remains 1.3.41.

- `admin-launcher.lua`: 11 actual-owner checks passed with native boundaries
  mocked, including legacy defaults, explicit Off, repeated reconciliation,
  stale-control recovery and retained session state.
- Existing `terrain-evolution/v2-gui.lua` checks passed, including offline
  lifecycle, in-place upgrades, per-player settings and the eight-write budget.
- Lua syntax checks passed for the changed GUI and both menu fixtures.
- Blueprint audit passed: 59 models, 179 owned sources, zero findings.
- Scoped diff whitespace check passed.

Full repo preflight passed Lua syntax, runtime alert contracts, PowerShell syntax,
requires, locale keys/duplicates, asset references, pack versions and module
headers. Its overall result remains failed because Python bytecode-cache writes
under `.codex` are denied and the three unrelated encoding findings listed above
remain. These failures do not involve the changed Administration GUI or fixtures.

The native menu fixture now checks Administration toggle highlights and saved
control adoption. It was not rerun: Factorio was already running, and that
session was left untouched. The older native results above do not validate this
change's rendered appearance, physical input or multiplayer behavior.
