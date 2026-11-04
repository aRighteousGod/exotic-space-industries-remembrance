# Gate console layout: 2026-11-03

## Change

The countdown previously participated in the automatically sized destination/camera row. Runtime now appears below Stress in Status, in a fixed 480-by-40 logical-pixel label with wrapping enabled. Stable, Critical and Cooling reserve the same space. The destination controls and camera no longer resize when the caption changes. Existing cached consoles with Runtime in the old target column rebuild through the existing GUI lifecycle.

Countdown behavior, locale wording, transfer behavior and mod version are unchanged by this follow-up. Earlier uncommitted gate quality/energy and cooldown work remains intact.

## Verification

- Scoped Lua syntax and whitespace checks passed.
- Focused quick `gate-quality` validation on Factorio 2.1.24 passed 260 candidate assertions. Native run: `f1d5b0f7ad9249c89fde4554c83ca3db`.
- Focused targeted validation on Factorio 2.1.24 passed 260 candidate assertions, 260 graphical-checkpoint assertions, 52 reload assertions and 52 configuration assertions. Native run: `dce2d07727514450b4f19c6e306b1463`.
- Added a native assertion that an already cached console using the old Runtime location is rebuilt successfully.
- Both runs completed evidence compaction successfully.
- The blueprint audit still reports two unrelated beacon-profiles ownership findings; no gate findings. No broad/full QC was run.

## Rendered evidence

The targeted run retained 1920-by-1080 English captures for Stable, Cooling with 100.0, 99.9 and 9.9 seconds remaining, and Critical under `.factorio-qc/managed/dce2d07727514450b4f19c6e306b1463/rendered/layout-*.png`. Stable, 100.0-second and Critical captures were visually inspected: Runtime is readable without clipping and the controls stay aligned.

Pixel comparisons against Stable were identical in all four other captures for the console header `[842,116,1222,170]`, destination controls `[851,340,1033,519]`, console left edge `[841,170,845,520]`, console bottom edge `[842,522,1222,530]`, and camera right edge `[1203,345,1206,508]`. Coordinates are Pillow crop boxes in screenshot pixels. This establishes unchanged placement for the relevant controls and frame across the tested captions. A wider camera-top sample differed because it includes the animated camera image; a native-inventory-title sample differed in Critical because a rebuild activity popup overlaps it. These are not full-screen equality assertions.

Other locales and alternate UI scales were not rendered in this follow-up; locale strings were not changed. Native GUI assertions and rendered review are separate evidence.

Detailed native receipts are in each run's `final-result.json` and `evidence.zip`; the targeted archive includes `reports/checkpoint-assertions.json`. These checks cover the prior cooldown, quality, energy, residue and persistence fixtures as well as the layout lifecycle assertion.
