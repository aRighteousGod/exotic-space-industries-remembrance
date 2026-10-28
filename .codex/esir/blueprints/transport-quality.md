# Native quality scaling across ESIR train tiers

<a id="contract"></a>
## Contract

The user explicitly approved native 2.1 quality scaling for all ESIR locomotives
and wagons. Authored normal-quality power, fuel eligibility, fuel bonuses, weight,
braking, friction and capacities remain unchanged. All tiers inherit the matching
native body's quality flags, including early copies and the steam placement body.

## Implementation sources

- [Native transport quality inheritance](../../../exotic-space-industries-remembrance/scripts/data-final-updates/transport-quality-policy.lua)

## Policy and ownership

The standard quality power factors remain native 1/1.2/1.4/1.6/2. Every authored
locomotive inherits the native quality speed flag, giving speed-ceiling factors
1/1.03/1.06/1.09/1.15. Every cargo wagon inherits the native inventory flag; every
fluid wagon inherits the native capacity flag. This occurs in final data because
Quality enables those flags after some ESIR source bodies have already been copied.

The pass copies flags from the corresponding native prototype, so optional mods'
changes to those canonical flags are also inherited. It never rewrites quality
definitions or freezes quality multipliers. Unrelated optional rolling stock is
outside its bounded list. No production runtime loop or helper is added.

## Migration

All prototype and item identities remain unchanged. Existing 2.0 trains, wagon
inventories, fluids, schedules, circuit state and the EM charging registry need no
new conversion for this data policy. Higher-quality wagons gain native capacity;
items and fluids already held must remain intact. Earlier preservation-only test
candidates are retained diagnostics and are superseded by this approved policy.

## Verification

Use paired 2.0.77 and 2.1.23 native schedules for five canonical locomotives at
normal, rare and legendary quality. Compare normal-quality sampled speed and
position, including automatic station braking, with identical fuels; record the
approved higher-quality differences. Query all five cargo tiers at every standard
quality, including fluid capacity and every locomotive speed ceiling. The private
bridge and retained negative fixture attempts
are in `scripts/qc/factorio-2.1/quality-trains.lua`; acceptance is recorded in the
[upgrade synopsis](../handoffs/factorio-2.1/UPGRADE_SYNOPSIS.md).

Module-effect precision, rocket animation speed, physical driving input and EM
charger service behavior are separate checks, not implied by this rail fixture.
