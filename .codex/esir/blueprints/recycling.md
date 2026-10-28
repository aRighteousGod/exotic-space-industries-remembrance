# Recycling ownership and Factorio 2.1 parity

<a id="contract"></a>
## Contract

Recycler supplies the native recipe shape, graphics and technology unlocks.
ESIR retains its established reverse-versus-self eligibility, generation-stage
durations and final authored outputs. Quality effects remain 0.03/0.045/0.06.
No runtime scheduler or persistent state belongs to this data-stage policy.

## Implementation sources

- [Recycling policy](../../../exotic-space-industries-remembrance/lib/recycling-policy.lua)
- [Final recipe ownership](../../../exotic-space-industries-remembrance/scripts/data-final-updates/recycling.lua)

## Lifecycle and invariants

At the end of ESIR `data.lua`, the policy temporarily opts excluded recipes out
of the first native generation and records only durations. Items retain their
25% self-recycling fallback. At the start of ESIR `data-updates.lua`, it restores
those generation-stage durations and removes its own temporary opt-outs before
ESIR rewrites recipes. Existing authored `auto_recycle = false` remains intact.

Final regeneration calls the native helper with ESIR's eligibility predicate.
Only a successful replacement of the target recipe receives the winning source's
`(energy_required or 0.5) / 16` duration. This preserves multiple-route winner
semantics, including neutron-container production in the neutron activator.
Explicit self regeneration uses the same-name source duration at that point.

The old singleton chemistry, smelting, organic and crushing categories remain
excluded. Metallurgy and cryogenics retain the old named machine exceptions.
The former chemistry-or-cryogenics union excludes everything except battery;
other former unions remain eligible. A category list must not be rejected merely
because one member belonged to an excluded singleton category. Empty barrels,
science-pack names, tungsten carbide, superconductor and biolab retain exclusions.

The native 2.1 pistol opt-out and hazard-concrete redirections are cleared before
generation to preserve the established outputs. New unrelated recipe identities
retain their native authored data. Final ESIR overrides for scrap, crystals,
processing units, crushed items and neutron containers remain authoritative.

Recycler now adds unlock effects and disables generated recipes until research.
Final cleanup removes missing/duplicate unlocks in place because the native helper
retains a reference to the effects table. ESIR's 1.4.0 runtime migration enables
only current recycling unlocks for forces that already researched recycling.
Optional technologies, including Cerys nuclear-scrap recycling, can hold the same
retired unlocks. The final owner records exactly which recipes it removes and
prunes those unlock effects from all technologies. This does not suppress unrelated
missing-recipe errors or change any surviving recipe's unlock, cost or output.

## Verification and limits

Compare preserved 2.0.77 final data with the exact 2.1.23 merged selection,
normalizing product field names and fractional integer representation. Check
eligibility, results, duration, quality and research reachability separately.
Static policy review does not prove native probability behavior or migration.
The upgrade synopsis records actual run receipts and any remaining differences.
