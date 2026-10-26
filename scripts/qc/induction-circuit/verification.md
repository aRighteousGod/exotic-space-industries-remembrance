# Induction matrix circuit menu verification

Date: 2026-10-25 (local). Engine: Factorio 2.0.77, build 84539.
Main mod version remains 1.3.41. No deployment, commit, or push is part of this patch.

## Scope and defaults

The existing screen console retains its camera, energy display, reanalysis button,
and draggable titlebar. A right-hand circuit panel edits four authoritative settings:

| Measurement | Unit | Default signal | Default state |
| --- | --- | --- | --- |
| Stored energy | MJ | C | Disabled |
| Capacity | MJ | T | Disabled |
| Maximum transfer | MW | M | Disabled |
| Charge level | 0-100% | A | Disabled |

Settings are independent of wiring and power simulation. The existing 60-tick
staggered telemetry and 15-tick viewer refresh remain; explicit edits rebuild
filters immediately. All outputs default off; existing explicit settings remain
authoritative. Matrices without an enabled, selected output have no telemetry slot,
disable their proxy control behavior, and skip circuit measurement reads. The proxy retains hidden/blueprint-excluded status and gains
a fourth slot. Existing core death effects and helper presentation are inherited
unchanged; no entity art or death-presentation replacement is included.

## Structural and localization evidence

- Repository doctor resolved the installed 2.0.77 engine and matching API docs.
- Conceptual blueprint audit: 60 models, 183 owned sources, zero findings.
- Preflight passed Lua syntax, PowerShell syntax, module headers, missing-require
  checks, locale duplicates/missing keys, asset references, version consistency,
  runtime alerts, and conceptual blueprints.
- The full preflight remains non-green on existing encoding findings in
  `scripts/qc/singularity-lance/angular-results.json`,
  `temp/anisetron-tracking-fix/blueprint-final.json`, and
  `temp/storage-audit-c/evidence-link-update.json`, plus Python cache/path write
  failures. Cache-free compilation passed all 348 Python paths reported by that
  failed cache-backed check. Those unrelated files were not modified.
- Focused locale audit passes all 64 custom entries, eight descriptions, and eight
  Informatron explanations. It checks UTF-8, duplicate/empty feature keys, matching
  placeholders, C/T/M and A defaults, description timing, no English copies in
  non-English custom keys, and unchanged help rich-text tokens/newline escapes
  against the pre-edit baseline. Existing Japanese wording is retained outside
  the narrowly updated circuit explanation.
- Scoped `git diff --check` passes. The dirty worktree's unrelated changes remain.

Structural evidence and pre-edit copies:
`.factorio-qc/managed/bbf0b54fbc2b452f915a01202bc769d7`.

## Default-off follow-up

Run: `.factorio-qc/managed/im-a886eae4/n`, Factorio 2.0.77 build 84539.
The native runtime report passes **94 assertions**, including the original signal,
wire, transfer, topology, blueprint, clone, and GUI checks with outputs explicitly
enabled where required. New assertions establish:

- All four settings and native GUI checkboxes start off; C/T/M/A remain selected.
- Missing saved settings repair to all off, while existing explicit choices persist.
- A wired but disabled matrix performs zero circuit measurement reads, has no
  telemetry slot, and disables its output combinator with empty filters.
- Closed, idle matrices admit no tick work across all 60 schedule positions.
- Enabling the first output immediately publishes the unchanged reading and joins
  the schedule. Disabling the last output immediately clears filters, disables the
  combinator, leaves the schedule, and performs no circuit measurement reads.
- Enabled outputs with empty signal pickers remain inactive.
- A blueprint core with enabled settings joins the schedule before floor placement.

The graphical client created a real save checkpoint. Ordinary reload and
configuration-change reload both pass **98 cumulative assertions**: the 94 saved
cases plus four reload checks. These verify configured settings and GUI state,
removed-signal sanitation, and a dormant default-off matrix remaining disabled
and absent from the telemetry schedule. Current runtime and all eight locale
files match the tested profile byte for byte. The managed run is closed successfully.

Focused Lua syntax, module headers, conceptual blueprints (60 models, 183 sources,
zero findings), locale coverage/default-off wording, preserved help formatting,
and scoped diff checks pass. The all-eight-locale rendered evidence below predates
this follow-up; layout and tooltips are unchanged. The updated default-state prose
has static locale coverage, not a fresh rendered or native-speaker review.
No comparative UPS benchmark or multiplayer validation is claimed.

## Native data and runtime evidence before the default-off follow-up

Run: `.factorio-qc/managed/im-2c0a289d/n`.
`script-output/induction-circuit.json` reports **82 passing assertions**.

Coverage includes:

- Original C/T/M-on defaults; A opt-in; independent remap/disable/clear for all four
  outputs; zero, partial, half-rounding, full, over-capacity, and zero-capacity charge.
- All eight native signal types; quality preservation; aggregation only for equal
  type/name/quality; missing signal/quality sanitation; integer clamps.
- Actual red and green network propagation, red-only/green-only networks,
  disconnected edits and reconnection, immediate stale-filter clearing, and
  reassignment without changing the measurement.
- Native settings paste with destination readings, ordinary-combinator paste,
  private-section restoration, and preservation of the source's shared group.
- Reanalysis, converter upgrade/downgrade, dormant-core repair/activation, native
  player floor mining/rejoin, merge survivor settings, and duplicate reconciliation.
- Real engine blueprint mapping/tag capture, native ghost revival, and actual
  construction-robot placement of a tagged core before its floor.
- Core-first/proxy-first cloning and actual area cloning with cable retention.
- Native GUI objects routed through the existing dispatcher, saved-root rebuild
  with position retention, core remapping, unrelated GUI opening, and open-core
  destruction cleanup.

The same staged sources passed a real GUI-save checkpoint, ordinary reload, and
configuration-change reload. Each reload adds three passing checks (85 total):
settings retained, the helper signal retained while present / cleared after its
prototype is removed, and GUI state restored. Native data assertions also pass for
the four-slot hidden proxy and the shared localized description on the item, all
17 real core tiers, and the selectable proxy.

## Rendered GUI and translations

The capture runner renders the actual panel and a separate sheet containing the
shipping tooltip text at 100% and 125% UI scale in en/de/fr/ja/pl/ru/zh-CN/zh-TW.
Each receipt records actual locale/scale and resolved native/custom strings.
All eight locales pass at both scales: **32 accepted images** (16 panels and 16
tooltip text sheets). Full windows, checkboxes, signal pickers, network status,
existing controls, accents/CJK glyphs, and explanatory text fit without clipping
or collisions. These images predate the default-off follow-up. The fixture
explicitly enables all four outputs for these captures; default-state behavior
is covered separately by runtime assertions. No layout or tooltip changes are
part of the default-off follow-up.

| Locale | Accepted 100% tag | Accepted 125% tag |
| --- | --- | --- |
| English | `en-100-9418ad` | `en-125-e5ac67` |
| German | `de-100-e00225` | `de-125-435623` |
| French | `fr-100-cc7897` | `fr-125-31cac8` |
| Japanese | `ja-100-5d346d` | `ja-125-0e24b8` |
| Polish | `pl-100-c4ac37` | `pl-125-c764d1` |
| Russian | `ru-100-0760ab` | `ru-125-2b0cb5` |
| Simplified Chinese | `zh-CN-100-98d96f` | `zh-CN-125-501377` |
| Traditional Chinese | `zh-TW-100-b9db43` | `zh-TW-125-4c4327` |

The first seven locales are in the native run above. Final Traditional Chinese
captures are in `.factorio-qc/managed/im-132772da/n`, after aligning three entries
with the existing circuit term 訊號. At that review point, the runtime code and other seven locales were
hash-identical to the native acceptance run; the final locale audit and exact
three-entry wording comparison pass. `final-static.json` and `visual-review.json`
in the protected structural-evidence directory record that final comparison.

Each run stores images in `script-output/matrix-captures` and native translation
receipts in `capture-receipts.json`. All 208 accepted translation requests resolved
without unknown keys. Early position-clipped trial images are superseded and are
not counted in the accepted set. The capture bridge now disables auto-centering
and places the review window explicitly.

## Manual interaction, multiplayer, and native-language limits

- Checkbox and picker changes use real GUI elements and the real dispatcher.
  Mouse-driven picker navigation, native tooltip hover placement, and drag handling
  are not claimed as manually exercised.
- The fixture contains one connected player (`secondary_viewers=0`). Registered
  viewer refresh is source-reviewed; simultaneous two-client synchronization is
  not established by this run.
- Translations are complete and reviewed for meaning, formatting, and terminology.
  Rendered review establishes font/layout behavior, not independent native-speaker
  certification for all seven non-English locales.
- A pre-existing scripted-tile-removal schema gap was exposed while extending the
  fixture: `script_raised_set_tiles` lacks `old_tile`, which the old removal handler
  expects. Native player mining/rejoining passes. The separate scripted-removal
  behavior is recorded in [revisit notes](../../../.codex/esir/REVISIT_NOTES.md).

## Reproduction

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-induction-circuit-qc.ps1 -SaveReload -CaptureLocales
python -B scripts/qc/induction-circuit/check-locales.py
python -B .codex/skills/esir-conceptual-blueprints/scripts/blueprint_audit.py --format json
```

The runner waits for other Factorio processes to close. It operates only in a
registered disposable profile; shipping mods, normal game saves, and running user
sessions are not modified or stopped.
