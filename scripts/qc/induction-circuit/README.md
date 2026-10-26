# Induction matrix circuit acceptance

Run `powershell -ExecutionPolicy Bypass -File scripts/invoke-induction-circuit-qc.ps1 -SaveReload -CaptureLocales`.
The runner stages live main sources with the existing control-UPS harness, records
source/dependency hashes, and uses a separate managed profile with Factorio 2.0.77.
The saved-player input is `.factorio-qc/wtr/player/fixture.zip`. The optional 2.1
minigun pack is excluded from this 2.0 acceptance profile. Shipping mods and saves
are not deployed or modified. The runner waits for existing Factorio processes to
close, then runs its engines sequentially. Omit `-CaptureLocales` for runtime and
save/reload acceptance without rendered captures.

The staging-only bridge uses native entity construction, GUI opening, blueprint
mapping/revival, and clone events. Checkbox/picker checks invoke the actual dispatcher
with native GUI elements; they do not simulate mouse interaction. Signal section
assertions cover units, defaults, percentage, all native signal types, quality,
aggregation, immediate edits, paste isolation, topology repair and core replacement.
All four outputs default off with C/T/M/A preselected. Idle-path assertions cover
disabled combinators, empty filters, absent telemetry slots, no measurement reads,
tick-work admission, and immediate resume/stop when changing the last active output.
The hidden graphical client writes a real GUI checkpoint; ordinary and forced
configuration reloads use the unchanged bridge. A saved helper signal remains
selected on ordinary reload and is safely cleared when the helper removes its
prototype during the configuration reload. Secondary viewers are exercised
only if the input save already contains another player; this is not multiplayer
synchronization evidence.

`python -B scripts/qc/induction-circuit/check-locales.py --baseline <pre-edit-root>`
checks all eight locales, required keys, duplicates, placeholders, defaults, UTF-8,
and unchanged Informatron rich text/newlines. Omit `--baseline` for coverage only.
Structural/engine assertions do not establish visual layout or native-language
approval; record rendered captures and their inspection separately.

Rendered acceptance starts a finite hidden graphics benchmark for each of the eight locales
at 100% and 125% UI scale. It requests native translations, verifies the actual
locale/scale, and captures the panel plus a separate sheet containing the exact
shipping tooltip text. The sheet verifies fonts, content, and wrapping, not mouse
hover placement. Captures and translation receipts live under the managed run's
`script-output/matrix-captures`; `capture-receipts.json` identifies the accepted
batch. `./scripts/invoke-induction-circuit-captures.ps1 -RunDirectory <run> -Locales en,de`
can rerender selected locales while the prepared dependency links remain present.

See [verification.md](verification.md) for the latest evidence and remaining manual
interaction, multiplayer, and native-language review limits.
