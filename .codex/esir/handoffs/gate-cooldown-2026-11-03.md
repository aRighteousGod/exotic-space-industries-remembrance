# Gate cooldown input lock and countdown

Implemented on 2026-11-03 without changing the mod version. Existing uncommitted sender-quality/energy work was retained.

## Behavior

- Successful cargo transfers close automated input immediately after residue placement. The inactive-state lock also remains in effect.
- The existing bounded gate service reopens input after the cooldown deadline if the gate is otherwise armed. Existing cargo and native manual inventory access remain available.
- The existing Runtime line shows remaining game-time seconds, rounded upward to tenths. It returns to Stable/Critical at expiry. The countdown participates in the GUI projection signature and adds no saved timer state.
- All eight locales include the countdown and updated help/tooltips. French and both Chinese locales also received the previously missing Runtime status translations.

## Fresh verification

Exact engine: Factorio **2.1.24**, `gate-quality/default` (Quality enabled).

| Phase | Assertions | Result |
| --- | ---: | --- |
| Candidate | 259 | Passed |
| Graphical checkpoint | 259 | Passed |
| Ordinary reload | 52 | Passed |
| Configuration repair | 52 | Passed |

Coverage includes native inserter blocking against a partial stack and recovery after expiry, immediate locking after transfers, removable retained cargo, residue placement, inactive/saturated controls, legacy open-bar repair, countdown tick-zero/fractional/expiry boundaries, native GUI caption refresh/reopening, and saved cooldown identity. Existing quality/payment/upkeep/partial-transfer checks pass. The ordinary reload observer confirms no configuration change; configuration has its own observed repair phase.

Checkpoint SHA-256: `3b8623c51413df611cfbde2a34390f466490a32b816c342783e4397f133e66bd` (2,586,764 bytes). The scoped runner reported no source-fingerprint errors.

Reviewed English captures: `rendered/checkpoint.png` shows the countdown and barred inventory without clipping; `rendered/tooltip-text.png` shows the exact localized tooltip in a bounded native proof panel with readable wrapping. This is not mouse-hover coverage. `rendered/cooling.png` missed the open console and is not console-layout acceptance. Other locales have static key/placeholder coverage, not individual rendered acceptance. Multiplayer was not tested.

## Local evidence and housekeeping boundary

Native result and phase receipts are retained locally under `.factorio-qc/managed/f8211e0e9c4d4320ae9b5d1614a84667/`. Its `result.json` reports `overall_status=ok`. The outer scoped receipt is `.factorio-qc/managed/736abe1069744501972cdea59282bd85/result.json`.

The outer wrapper reports failure because managed release encountered a locked shared `Accumulator-V2_1.0.8.zip` dependency and preserved the run as `protected-error`. This does not negate the completed native assertions or rendered review. Task ownership is closed for the final native run; protected payloads must remain until normal housekeeping can safely release them. Do not bypass the lock or delete shared inputs.

Earlier attempts encountered registry contention and two corrected fixture problems: natural receiver-saturation decay restarted cooldown during the input-recovery test, and the travel fixture moved the player away before tooltip capture. The final fixture uses a full receiver as the recovery control and returns/reopens the player at the source for the GUI proof.

## Static checks and existing findings

- All 56 gate locale key checks and their placeholders pass across eight languages.
- Touched gameplay/fixture Lua parses; adapter Python syntax and scoped whitespace checks pass.
- All 16 existing scoped-QC workflow host tests pass.
- The full touched-file static pass reports two unrelated Japanese placeholder mismatches: `item-description.ei-combustion-turbine` and `exotic-industries-informatron.phase-shift-pipe-2`.
- The blueprint audit reports two unrelated ownership findings for `scripts/data-final-updates/beacon-profiles.lua`; none concern the gate model.

Reproduce focused behavior with `powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-targeted -ChangedPath exotic-space-industries-remembrance/scripts/control/gate.lua`. Let other ESIR QC jobs finish first to avoid shared registry contention.
