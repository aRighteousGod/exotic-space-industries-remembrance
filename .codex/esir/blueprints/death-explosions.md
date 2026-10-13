<a id="contract"></a>
# Native entity death profiles and inherited operational shells

The final data pass assigns particle-first deaths to ESIR machinery and curated
canonical dependency bodies. Family and footprint determine presentation. It
owns no runtime state, events, scans, or scheduler work.

## Implementation sources

- [death-explosions.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/death-explosions.lua)

## Ownership and flow

`family_assignments` wins over `family_prefixes`, then `family_from_heuristics`.
Owned names use `ei-`/`ei_`; unrelated prototypes require an exact or prefix
dependency inclusion. `generate_explosions` creates the family/footprint cores.
`apply_family` chooses an exact bespoke core, native train breakup with effects,
preserved authored death with supplements, or replacement of a generic core.
Appends retain existing `dying_trigger_effect`. Mine activation `action`, robot
attacks, loot, corpses, mining, and runtime ownership are outside these mutations.

<a id="operational-bodies"></a>
## Operational bodies and helper boundaries

`death_candidate` requires a selectable body with a positive selection/collision
box. Ordinary candidates must be visible and placeable. `operational_exact`
narrowly admits the fluid turbine, low/surged crystal shells, radar placement
chassis, canonical fleet bodies, and capsule-deployed Incinerator. Hidden power
sensors, GUI/boarding proxies, telemetry, cooling helpers, natural flora, and
cosmetic steam-wheel cars remain outside coverage.

Newer content uses signal radars and Prediction Snare mines, micro combustion
Incinerators, combustion fluid turbines, alien ANISETRON and crystal shells,
electric-logistics scouts, ballistic assault/rocket spiders, and chemical
flamethrowers. These reuse existing family effects without new death damage.
ANISETRON does not acquire the saucer's bespoke damaging collapse.

<a id="anisetron-visual"></a>
## ANISETRON Lance collapse sprite

`effects_for_exact` adds one `ei-anisetron-lance-death-visual` explosion alongside
ANISETRON's alien-huge core. The hidden visual copies only the Singularity Lance's
simultaneous base/glow animations and shrinking motion. It retains the original
48-frame timing, scale and shift; it contains no created effects, sound, smoke,
or light. The alien family remains the owner of the cathedral's death aftermath.
Neither the shared alien-huge core nor the Lance's bespoke death is modified.

Incinerator expiry uses the separate native `destroy_action`. The combustion
micro core is appended alongside its native falling debris and voices; lifetime,
attack behavior, and existing expiry effects are preserved.

<a id="inheritance"></a>
## Final-stage order and inheritance

[data-final-fixes.lua](../../../exotic-space-industries-remembrance/data-final-fixes.lua)
loads this module after source-body presentation, before spider `finalize()`
and `scripts/data-final-updates/flamethrower-fuels`. The canonical scout,
`assault_spidertron`, `spidertron`, and `flamethrower-turret` receive profiles before
their hidden gameplay, weapon-mode, and placement shells are copied. Descendants
inherit complete death fields. Spidertron Enhancements boarding proxies retain
their independent source's deaths rather than entering this policy.

The saucer, Lance, charger, Emerald tank, and nuclear locomotive retain exact
deaths. Nuclear criticality uses a native delayed active trigger; rolling stock
retains train breakup. The auric vat retains its exact effect-only supplement.

<a id="verification"></a>
## Verification and limits

Run Factorio 2.0.77 `qc-fast`, inspect death-audit lines, and check final data:

```powershell
python -B scripts/qc/death-explosions/check-data.py <dump.json> --output <report.json>
```

The checker validates the fixture's profiles, additive ANISETRON sprite, generated
spider/fuel shell inheritance, bespoke cores, and snare activation. An
`--inventory-only` run records a snapshot. The optional `--baseline` comparison
expects the historical snapshot before the Incinerator expiry supplement; it adds
that supplement to the old expiry before comparison. This is not a generic
comparison against an arbitrary pre-change/current snapshot. Source-core,
mine/robot payload, and helper/proxy preservation comparisons require that baseline.
These checks prove wiring for the tested mod/startup profile, not visual quality,
new entities outside the fixture, or all optional-mod mixes. Follow
[entity presentation guidance](../../skills/esir-entity-presentation/SKILL.md)
when adding or changing coverage.
