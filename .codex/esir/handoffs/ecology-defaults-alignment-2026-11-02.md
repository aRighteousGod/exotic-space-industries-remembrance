# Ecology defaults and Administration alignment

Implementation date: 2026-11-02. Main mod version remains 1.4.03.

## Delivered behavior

The existing ecology schema continues to default every feature and all six planet
switches to On, with Contained wildfire, Restrained intensity and Lean processing.
Factory Passage circuit scanning now defaults to Off. Its main and additional
scanner budgets remain 256 and 1, and the scanner cooldown remains 60 ticks.
Existing saved choices and explicit surface overrides remain authoritative; no
reset migration was added. Personal alert preferences are unchanged.

Administration Options continues to read native settings. Terrain & Ecology now
stores only actual edits as new drafts. Untouched controls follow effective values
on refresh without replacing their widgets. Apply uses the displayed value when
there is no draft, then clears the field draft after success. Inherit clears that
field; Reset clears only the selected surface's overrides and drafts. Existing
legacy drafts are conservatively retained. Inheritance follows current map values.

Scanner descriptions and Informatron guidance explain default Off in all eight
locales. Documentation and the Factory Passage model use Options → Performance.
The terrain/calendar owner was not changed: Fulgora's ecological phase is separate
from its independent daylight controller.

## Verification

Native acceptance passed on exact Factorio 2.1.24 with the checked-in development
profile and unchanged inputs across the full six-case matrix: **3,770 assertions**.

| Profile | Candidate | Ordinary reload | Configuration | Managed run |
| --- | ---: | ---: | ---: | --- |
| Default | 1,687 | 93 | 91 | `e2824299d6164835a3f88cfa99436988` |
| Controlled legacy values | 1,715 | 93 | 91 | `a3ac953c4274451f90bf769697cf4139` |

Graphical checkpoint producers independently passed 1,687 and 1,715 assertions
before their completed, verified saves were used. These are not included in the
3,770 total. Default-profile checkpoints retain scanner On, and legacy-profile
checkpoints retain scanner Off. Both retain global degradation Off, a recovery
surface override Off, and a pending tree-regrowth draft Off through actual reload
and configuration callbacks. A prior focused candidate also passed 1,687 checks
in `c6f4c673583c4c75a3a8026b01361f3f`. Successful runs are compacted.

Focused English/Japanese rendered acceptance passed in
`f62bc878e6a443aeac533792a86475a7`: both profiles at 1600 x 1000 and UI scale 1,
with 16 hash-verified native captures and 401 resolved translations per profile.
Eight representative images were visually reviewed: Performance, ecology processes,
the editor after a global change, and the editor with an unapplied draft, in each
language. Scanner Off, enabled features, readable controls, and effective-versus-
draft values passed. The other eight captures have native and hash validation but
were not individually visually reviewed. Compact display sizes were not tested.

These renders use a disposable copy of the smoke-save world with a fixture that
normalizes ecology settings to native defaults and clears Nauvis overrides. Both
profiles already had the expected native settings, so no normalization setting
writes were needed. The original save remained byte-identical. The render run is
compacted; retained PNGs and its archived `reports/capture-result.json` are the
render evidence. Saved-choice persistence is established by the separate native
reload/configuration matrix above, rather than these default-scene captures.

Offline scanner checks passed 373,824 assertions, passage Options checks passed 19,
and ecology V2 checks passed 20 scheduler/state plus 6 report checks. The ecology
locale audit passed in all eight locales after supplying its process-local Lua
module path. Lua/Python syntax and whitespace checks passed for touched sources.
Final broad preflight passes all checks except two blueprint findings for the
unrelated `scripts/data-final-updates/dollies.lua`: unowned source and missing
reciprocal owner declaration. That source is byte-identical to the task baseline.

The first native candidate exposed fixture assumptions: historical Fulgora phase
expectations, a GUI observer on a different surface from its player, and deferred
scanner-surface deletion contaminating the following fluid fixture. These were
corrected in test code. Failed/incomplete attempts are not acceptance evidence.
The first native run `eaed9c032632454fb645507d948cfe71` remains protected after a
managed release encountered a locked package. Early sandbox temporary-directory
denial and a registry-lock collision were staging failures, not gameplay results.

## Evidence and limits

Task baseline, wrapper results and private rendered orchestrator:
`.factorio-qc/managed/2ab84a22f2924641a17d523df9b70e03`.
Child native runs retain exact inputs and receipts in compact evidence archives;
protected cleanup failures remain explicitly tracked rather than forcibly removed.

The final source manifest compares all 6,741 baseline files: this task changed 21
existing files and added this handoff plus two runtime-options fixtures. No baseline
files are missing. One independently created QC-gap progress handoff is recorded
and left untouched. Main-mod metadata and the unrelated dollies source retain their
baseline hashes. The original smoke save and all 16 retained image hashes were
verified again at closeout.

Native GUI callbacks are programmatic. Rendered layout checks are separate from
physical input, multiplayer/desync and performance evidence. No deployment,
commit, push or version bump is part of this task.
