<a id="contract"></a>
# Vulcanus auric fumarole lifecycle

<a id="admin-repair"></a>
## Admin repair

`repair_runtime_state` explicitly reconstructs active-band counts and rebuilds eligibility backfill on all eligible Vulcanus surfaces. The administrator-only `/rescan_auric_fumaroles` command does the same for the player's Vulcanus surface, or all eligible surfaces from the console. Existing active deposits, history and cooldown policy remain owned by the normal rescan implementation.

## Implementation sources

- [vulcanus-fumaroles.lua](../../../exotic-space-industries-remembrance/scripts/control/vulcanus-fumaroles.lua)
- [Vulcanus fumarole prototypes](../../../exotic-space-industries-remembrance/prototypes/planet-vulcanus/vulcanus-fumaroles.lua)

## Ownership and reference flow

`storage.ei.vulcanus_fumaroles` owns processed/history/cooldown chunks, generated/active distance-band counts, backfill and dormant queues, active deposits, breach-fire cleanup, and eligibility-version state. Chunk generation and resource depletion are the narrow world-entry events.

```mermaid
flowchart LR
  A["Generated chunk or bounded backfill"] --> B["Eligibility, distance band, and spacing"]
  B --> C["Active deposit or delayed dormant candidate"]
  C --> D["Dormant/recovery pulse or active audit"]
  D --> E["Spawn, retain, or close deposit"]
  E --> F["Afterglow, cooldown, and breach cleanup"]
```

<a id="tick-flow"></a>
## Tick flow and invariants

The dispatcher calls `updater(event)` only through the module's due gate. Backfill, dormant pulses, active audits, and fire cleanup retain separate cadences and budgets; initialization/eligibility probes may wake outside the regular 30-tick boundary. Event ticks feed chunk/depletion work and scheduled processing; bootstrap/status utilities retain context-free reads. Preserve the actual gate precedence when reasoning about simultaneous work.

<a id="lifecycle"></a>
## Lifecycle and cleanup

Init/configuration bootstrap existing generated chunks without treating them as new world generation. Automatic eligibility refresh is owned exclusively by `FUMAROLE_RUNTIME_VERSION` and `ELIGIBILITY_VERSION`: a runtime mismatch requests refresh; an eligibility mismatch additionally resets the derived dormant state. General mod updates, including ESIR version changes, do not invalidate matching module versions. Existing queued backfill or a saved pending refresh resumes without being restarted. Initial/missing-state bootstrap and deferred probes for absent Vulcanus remain supported.

`check_global` reconstructs active-band counts only on either version mismatch or a missing count root, capturing those conditions before normalization. Reconstruction derives band membership from chunk coordinates. Registration and tracked closure maintain counts thereafter; recurring sanity/status calls preserve the count table. A synthetic untracked depletion record still receives ordinary closure effects and cooldown, but cannot remove or decrement a tracked index entry. Repeated adoption preserves the existing record's amount, touched state, spawn tick and expiry without incrementing counts again.

Depletion closes the exact deposit record, records cooldown/history, and schedules presentation cleanup. Dormant candidate and active-deposit indices must remain consistent across closure, expiry, and rebuild; spacing and local saturation constrain spawns. Rule/schema changes that require existing terrain to be reconsidered must deliberately bump the appropriate module version; this gating correction itself does not bump either version.

<a id="map-controls"></a>
## New-game map controls

The data-stage fumarole owner registers `ei-auric-fumarole` as a native resource
control on Vulcanus. Runtime placement remains authoritative (`autoplace = nil`),
so vents are absent from the map preview. Runtime reads and normalizes the surface
control once per event/service pass; missing old-save values mean 1, and each
dimension is bounded to 0..6. Any zero disables all emergence and new dormant
admission, including breach effects; active deposit cleanup continues and saved
pending queues are retained.

Frequency multiplies immediate/dormant probabilities (capped at 1) and recovery
budgets. For pulse `p = floor(tick / 1800)` and rate `r = base * frequency`, the
attempt budget is `floor((p + 1) * r) - floor(p * r)`. This admits fractional work
without persistent credits or catch-up. Existing base budgets and pulse cadence
remain, capped at 36 recovery and 12 keepalive attempts per pulse. Ordinary dormant
checks stay capped at six; their probability, not their check budget, scales.

Size multiplies each distance-band target before rounding up. The keepalive floor
is `min(ceil(2 * size), total eligible target)`, after the existing five-minute
grace. Placement restrictions still apply. Richness multiplies the deterministic
40,000..80,000 base reserve, rounded to the nearest integer (minimum one when
enabled). Existing deposits retain amount, initial amount, tapped state and
expiry. No version bump or rescan is required: eligibility and stored state have
not changed. Diagnostics expose normalized `map_controls` and the effective floor.

Resource visuals and ambience retain sulfuric-geyser inheritance. Custom combat
death effects are inapplicable to this finite resource's scripted closure; its
existing afterglow/scars and pumpjack presentation remain owned by existing paths.

<a id="slag-recovery"></a>
## Ordinary slag recipes

This prototype file also owns slag crushing and the three crushed-slag
extraction recipes. Their balance, research and feedback constraints are in
[Ordinary slag recovery](slag-recovery.md#contract). They do not change Auric
washing, precipitation cores or fumarole lifecycle.

<a id="processing-productivity"></a>
## Processing productivity

`ei-productivity-auric-precipitation` is native infinite recipe-productivity research:
each level adds 0.1 to `ei-auric-slag-washing` only. It requires Auric precipitation
and Metallurgic science, uses the Computer age/space/Vulcanus science set, and takes
20 seconds per research unit. Its authored `100 * (1 + 0.15 * L)` cost follows the
existing productivity technologies; the normal final technology-scaling pass owns
the configured repeatable cost curve.

Washing accepts productivity modules. All productivity sources share its explicit
`maximum_productivity = 3` cap. Gold remains fully eligible; ordinary slag and dirty
water exclude their entire possible yield from bonus crafts with
`ignored_by_productivity = 12` and `50`. Base ingredients, output ranges and crafting
time remain unchanged. Condensation, core production and mining receive no new
bonus. At zero/ten/thirty research levels without other bonuses, washing averages
5/10/20 gold chunks per 100 auric slag. Further research remains available but cannot
raise output beyond the cap. The engine owns research effects and their persistence;
this feature adds no runtime receiver, migration, lifecycle invalidation or rescan.

<a id="verification"></a>
## Verification contract

For processing productivity, inspect merged final data with technology scaling on
and off; verify the exact research effect, gates, science set, infinite levels,
cost/time, module eligibility and product exclusions. Exercise native washing with
zero, 100%, 300%, above-cap and module-assisted bonuses, retaining base-craft waste
while increasing only gold. Check pre-feature save admission and researched-level
save/reload. Review the research screen separately from headless evidence and
distinguish locale-key/encoding checks from native-language acceptance.

The [control UPS fixture](../../../scripts/qc/control-ups/README.md) documents fumarole cadence decision probes. Test fresh chunks, pre-existing explored terrain, absent/reappearing Vulcanus, version refresh, blocked placement, depleted/expired deposits, simultaneous due work, reload, and eventual helper cleanup. Historical gate parity is not a claim about current long-run resource balance.

The [fumarole lifecycle fixture](../../../scripts/qc/auric-fumaroles/README.md) covers same-version configuration no-ops, migration admission, count reconstruction, tracked/untracked closure, repeated adoption, explicit repair, and native save/reload with pending backfill. Unrelated configuration changes must preserve queue order and rebuild-monitor progress.

<a id="rebuild-reporting"></a>
## Rebuild activity reporting

Finite backfill/rescan batches report admitted chunks and count entries as the existing processor pops them, including skipped chunks. Requested restart supersedes the previous generation. A missing required surface is an external wait; ordinary slow traversal stays running. Ongoing ecology and dormant revival remain excluded.
