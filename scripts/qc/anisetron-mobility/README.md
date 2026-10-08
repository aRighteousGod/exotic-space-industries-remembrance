# ANISETRON native mobility regression

This fixture exercises the shipping `anisetron-mobility` owner through ESIR's
central events. It adds no movement controller, movement override, or substitute
compensation sticker. Its bridge is appended only to the staged ESIR pack to
expose the shipping diagnostic and lifecycle-rebuild functions.

Use Factorio 2.0.77 and a copied player seed. The shared runner accepts the
fixture directory and explicit runtime lengths: 12000 native ticks or 9000
replay ticks. It stages the actual shipping source and the isolated bridge.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-mobility -RuntimeTicks 12000 `
  -RunName mobility-native -Fidelity off

powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-mobility `
  -RunName mobility-save -Fidelity off -Save `
  -SaveInput "$env:APPDATA/Factorio/saves/explode.zip"

powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-mobility -RuntimeTicks 9000 `
  -RunName mobility-replay -Fidelity off -Resume `
  -SaveInput .factorio-qc/anisetron/mobility-save/saves/anisetron-transition.zip
```

The save profile accelerates the server to 20x and saves at relative tick 3500,
with live native slows and compensation. In server mode the copied player is
disconnected, so that vehicle uses unmanned native autopilot. The ordinary
benchmark separately tests actual `player.walking_state` manual driving. Replay
continues the saved attack, rebuild, damage and cleanup sequence.

The scenario contains an unmodified ANISETRON control, six protected ANISETRON
cases, and a Gaian comparison. Twenty-four native enemies per wave include all
four standard spitter sizes plus installed Toxic, Cold and Explosive spitters.
Sources are healed after incoming damage so the fixture can observe sustained
movement over 6000 attack ticks instead of losing the test vehicle to attrition.
The direct seven-sticker control uses one native physical damage packet to
admit the shipping event-driven service; combat cases use real enemy hits.

Acceptance covers:

- Real native hits, remote/manual/turning/armed/equipped movement and no zero-speed
  displacement runs during the attack interval.
- Visual fidelity Off while the mechanical floor is active.
- Identical native poison damage on compensated ANISETRON and uncompensated
  Gaian controls, retaining original hostile effects.
- All seven original sticker objects and remaining lifetimes preserved across
  a mobility rebuild.
- Source removal, finite helper cleanup, natural slow expiry and return to zero
  affected records, without an ordinary-speed boost.

The safeguarded quantity is the native aggregate sticker speed modifier, with a
0.50 threshold and 1.25 geometric multiplier tiers. This is an approximately 50%
movement safeguard. Native stance and turning still produce instantaneous speed
variation; the fixture records speed, displacement, foot positions and modifiers
rather than pretending to enforce an exact tiles-per-tick clamp.

The October 7 stability follow-up reproduced multi-second manual and autopilot
reversal stalls despite the historical 20% modifier floor. The 50% candidate
passed all 40 long-travel cases. See `../anisetron-stability/verification.md` for
the current evidence and the separate, not-yet-reproduced no-sticker ASS report.

Historical failed fixtures are retained under `.factorio-qc/anisetron/stallfix-*`.
The unpatched real mixed-combat case (`stallfix-long-mixed-combat-1`) reproduced
4430 consecutive stopped ticks for manual driving and 4737 for remote driving.
Plain travel, native gun payments and individual standard acid stickers did not
reproduce the fault. Friction changes and faster-leg/shorter-stride experiments
did not supply an equivalent native fix. Those observations are diagnosis, not
current acceptance results.
