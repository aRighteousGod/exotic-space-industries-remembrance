# Singularity Lance mechanics and maintenance

This reference describes the synchronized-sweep implementation for Factorio
**2.0.77**, runtime schema **14**. Maintainers and code assistants should read it
before modifying targeting, combat timing, Wound, visual effects, or migration.
The numerical authority is the shared
[lance configuration](../exotic-space-industries-remembrance/lib/singularity-lance-config.lua).
The tables here explain intent; they are not a second gameplay configuration.

## File and state ownership

Paths below are relative to `exotic-space-industries-remembrance/` unless noted.

| Concern | Owner |
| --- | --- |
| Damage, timing, upgrade numbers, localized parameters, fidelity presets | `lib/singularity-lance-config.lua` |
| Transactions, protection, force caches, registered lances, core cues | `scripts/control/singularity-lance.lua` |
| Exact effect dispatch, lifecycle routing, scheduled-work admission | `control.lua` |
| FIFO and delayed-bucket primitives | `lib/runtime-scheduler.lua` |
| Native turret/carrier, original beam, contact-light prototypes | `prototypes/alien-system/singularity-lance.lua` |
| Upgrade technologies and prismatic animation prototypes | `prototypes/alien-system/singularity-lance-upgrades.lua` |
| Final science sets | `scripts/data-final-updates/singularity-lance-science.lua` |
| Laser research bridge | `scripts/data-final-updates/singularity-lance-damage-category.lua` |
| Player-force mechanics page | `scripts/control/informatron.lua` |
| Seven locale sidecars | `locale/{en,fr,ja,pl,ru,zh-CN,zh-TW}/singularity-lance*.cfg` |
| Engine fixtures and reports | Repository-root [`scripts/qc/singularity-lance`](../scripts/qc/singularity-lance/README.md) |

Persistent state belongs to `storage.ei.singularity_lance`. The production module
registers no public remote interface, global damage/death listener, or independent
event loop. The test bridge is appended only to isolated fixture copies.

## Native firing and the paid transaction

Factorio selects the enemy, approves its native targeting bounds, determines
cadence, and consumes electrical energy. Its carrier emits the exact effect ID
`ei-singularity-lance-shot`. Each callback admits **one paid shot**, regardless of
later victims or kills. Do not replace native acquisition with an enemy search or
add a second energy check. A target dying or becoming protected does not refund
the shot or its Testament count.

Let **M** be the existing force ammunition-damage multiplier for category
`ei-singularity-lance`. The laser-damage 6/7 bridge still feeds this category;
there is no second infinite-research multiplier. Multiply the damage values below
by M, then allow ordinary laser resistances to process each separate packet.

| Relative tick | Authoritative event |
| --- | --- |
| 0 | Native energy payment; Testament count; snapshot coefficients; enqueue every applicable packet. |
| Before C | Active waypoint acquisition. The beam crossing an entity does not damage it. |
| C, normally 8–60 ticks after payment | Finalize contact and incision geometry, then primary, incision, and ordinary splash if applicable. Start the collapse warning. |
| C+30 | First collapse at the fixed contact point. Start Testament's echo warning. |
| C+60 | Testament's one echo at that same fixed point. |

All three deadlines are fixed at firing. Arrival does not enqueue fresh delayed
damage. Each lance maintains a FIFO of contact waypoints: later attacks cannot
redirect, cancel, merge, or postpone earlier paid contacts. Shared delayed buckets
preserve due order and insertion order within a due tick, including Wound order.

Balanced acquisition uses a nominal average **6 degrees per tick**, with an
**8-tick minimum** and **8-tick first acquisition**. Isolated turns of 60, 90, 120
and 180 degrees take 10, 15, 20 and 30 ticks. A turn up to 45 degrees takes eight.
These are angles around the raised crystal, not the turret's ground center.
Moving targets and engine position rounding can affect the measured angle.

The shared `acquisition` configuration owns rate, minimum, first-acquisition time,
maximum wait and easing; no visual preset or startup setting changes mechanics.
Times are integer ticks. `crystal_offset={x=0,y=-3.35}` is deterministic geometry
shared by timing and rendering. Keep it separate from optional decoration.

Admission is constant-time. Use the queued tail's planned aim and due tick **P**;
when no contact is pending, use the last authoritative contact position for the
heading. Never derive timing from native beam handles or displayed endpoints.
For payment tick **T** and nominal duration **D=max(8,ceil(angle/6))**:

- Retarget: desired contact is `max(T+8, P+1, max(T,P)+D)`.
- Same target: desired contact is `max(T+8,P+1)`.
- Reserve `C=min(T+60,desired)`; omit P terms without a predecessor.
- Without a known bearing, use the configured first-acquisition duration.

Same target requires a valid non-null entity identity on the same force and
surface. Two positional shots do not qualify. Target movement cannot extend C.
Queued turns get full duration until the **60-tick payment-to-contact bound**
requires acceleration. One native paid shot per tick preserves strict order;
synthetic same-tick saturation can share a deadline, retaining insertion order
and separate damage calls. If a future tuning reduction leaves an older P beyond
the new cap, grandfather it and place subsequent work after it until drained.
If several contacts are serviced together, only presentation may coalesce.

Only the active waypoint's target is tracked during its transition. At contact,
read its current position if still valid on the original surface. If it died or
left, use its last observed position there, falling back to the firing aim. Never
select a replacement primary. Eligible secondary packets still resolve.

Snapshot the force, firing origin, effective range, multiplier, capabilities,
Wound coefficients, Testament identity, and secondary coefficients at firing.
Finalize contact position and rays **before damage callbacks**, then assign that
position to both linked collapse payloads. Research changes do not retroactively
alter those paid packets; later target movement can escape the fixed blasts.

## Baseline weapon

At contact the primary receives **500 × M** laser damage. Immediate ordinary
splash deals **125 × M**, radius **1.5**, to at most **8 additional hostile military
targets**. The original primary is excluded from its splash. Choose secondary
victims nearest the center, with deterministic ties.

Splash is guaranteed when eligible enemies exist. Neither its damage nor primary
damage depends on beam tracing, cosmetic fire, stickers, graphics presets, or
decorative budgets. These were deliberately decoupled from mechanical authority.
Restoring the sweep means moving presentation toward a fixed paid contact time,
not restoring damage along the traversed visual trace.

The normal-quality base range is **85 tiles**, extended through native quality
range. Current native power settings are **125 MJ per shot**, a **700 MJ buffer**,
**400 MW input**, and **20 MW drain**. With sufficient supply, net charging supports
`(400 - 20) / 125 = 3.04` shots per second, or **1,520 × M baseline direct DPS**.
The native one-tick attack cooldown permits much faster short buffered bursts;
it does not imply sustainable 60-shot-per-second firing. Variable contact latency
changes arrival time, not payment cadence or sustained throughput.

## Axial Rupture

The central incision is **2 tiles wide**, passes through contact, and extends up
to **24 tiles beyond it**. It deals **500 × M** to at most **5 additional enemies**.
Two branches start at contact and diverge **±15°**; each is **1 tile wide**, reaches
up to **18 tiles**, and deals **250 × M**. They share a total cap of **3 enemies**.

Compute all ray geometry once. Use one combined spatial query, then exact corridor
tests against target bounds, deduplication, and deterministic selection. Central
victims sort by nearest intersection along the ray; branch victims sort by
shortest travel from the fork across both branches. Apply caps after filtering.

Each secondary receives at most one incision packet per paid shot. Central-ray
eligibility takes precedence even when the central victim cap is exhausted: a
branch cannot substitute its weaker damage for a centrally eligible enemy. The
original primary is excluded from every incision ray.

All secondary rays are clipped to the snapshotted effective-range circle. Quality
extends that circle. Preserve native-approved direct attacks at large bounding-box
boundaries and against primaries that move farther during acquisition. Do not
extend secondary rays beyond the circle or reintroduce the obsolete fixed
85-tile main-beam clamp.

## Wound Memory

Consecutive successful primary contacts receive **0%, +20%, +40%, +60%, +80%, +100%**:
**500, 600, 700, 800, 900, 1,000 × M**. The first hit has no bonus; the sixth reaches +100%. At maximum,
further successful hits retain +100% and refresh expiry.

Only strictly positive primary damage advances or refreshes Wound. Zero damage
does neither. Incision, splash, collapse, and echo never build or receive it.
Retargeting or a gap of **120 contact ticks or more** resets the sequence. The
boundary is inclusive. The next hit restarts at the unmodified **500 × M**.

Pending shots share a context for their ownership/research period. Evaluate it at
contact, not firing: two shots paid before either lands must still deal 500 then 600.
The first-hit policy is snapshotted at payment; older queued contacts without that
field retain their original first-hit bonus. Existing earned stacks stay intact.
Loss of Wound Memory, source removal, or ownership change detaches the live context.
Already-paid contacts retain the old shared table and finish in order, but cannot
repopulate cleared live meters or marks. A cosmetic rebuild must not detach an
unlanded context just because it currently has zero stacks.

Clear the visible mark when a new target is selected. Older pending contacts for
abandoned targets must not recreate it. Engine-followed rendering moves the mark
and native TTL expires it without a target-tracking loop. Bands are split at
hits 1–2, branching at 3–4, broken halo at 5. The final halo signifies that the
**next** successful primary contact is ready for +100%.

Damage callbacks can synchronously destroy entities or change ownership/research.
Revalidate after damage before rendering or publishing live state. A positive
damage result is not proof that the target is still a valid LuaEntity.

## Terminal Collapse

Collapse **replaces ordinary splash**. Contact starts a warning lasting **30 ticks**.
At contact+30, victims receive **1,000 × M inside radius 1.5**, otherwise
**600 × M within radius 4**. There are **10 secondary slots**, nearest center first.

The original primary has a reserved slot outside that cap, only when returned by
this pulse's current-position circular query. Core membership uses entity-center
distance; equality belongs to the core. A victim receives core **or** outer
damage, never both. Recheck protection immediately before each damage call.

The blast remains at contact. A primary that moves away can escape; a primary
that returns can qualify. Incision and collapse are distinct packets, so the
same secondary may receive both. Never follow the target after contact or move
the collapse to the overpenetration endpoint.

## Black-Hole Testament

Every **eighth paid shot** multiplies Wound-adjusted primary damage by **4**.
Count at firing even if its chosen target is later gone or protected. Increase
the central incision cap to **10** and shared branch cap to **6**; keep incision
damage, widths, and reaches unchanged.

Its first collapse, still contact+30, deals **2,000 × M inside radius 3**, otherwise
**1,200 × M within radius 6**, with **16 secondary slots** plus eligible primary.
Its single echo at contact+60 deals **1,000 × M**, radius **5**, with **12 secondary
slots** plus eligible primary. The echo is prepaid at firing; the first impact
only starts its already-queued warning phase.

A stationary fully wounded primary can receive **4,000 + 2,000 + 1,000 = 7,000 × M**
from one sequence. It receives no incision. A secondary may receive incision and
one packet from each pulse. Keep every shot and pulse as a separate damage call:
adding their amounts changes flat resistance, deaths, and Wound semantics.

## Protection, lifecycle, and UPS invariants

Every mechanical path rejects same-force and neutral targets. Friendship or
cease-fire in **either direction** protects an entity. Query-time filtering is
only an optimization; immediately recheck before damage, including delayed work.
Do not persist diplomacy answers across ticks. Cosmetic fire/sticker prototypes
must cause no damage, slow, or spreading fire that could bypass protection.

Source destruction removes its beams/registration but preserves paid damage.
Surface deletion or clearing cancels associated packets and exact FIFO entries;
it must not restart unrelated surviving sweeps. Force merges transfer queued
attribution. Ownership reconciliation resets live meters; old contexts may finish
without restoring them. Omit native source attribution if its force no longer
matches the paid force.

Factorio has no general event for arbitrary scripted `LuaEntity.force` assignment.
Reconcile such ownership changes on the next lance interaction; native mark TTL
bounds stale idle presentation. Do not introduce a global ownership poll to make
this cosmetic edge case immediate. Paid contexts still keep their original force,
while later shots register under the new owner's fresh meters.

Register builds, clones, revivals, and lazily discovered firing lances. New
placements and clones have empty meters. Object-destruction registrations perform
cleanup. Ordinary save/load preserves counters and contexts. Idle lances perform
no searches, Wound sweeps, or target reads. Unrelated effects never enter the
module; unrelated research never scans entities. Relevant research refreshes use
the registered-lance map. Initialization/configuration may perform discovery.

Use `event.tick` through event-owned paths; capture `game.tick` only for eventless
entry points. Keep constant-time pending counts and next-due admission. Mechanics
run before decorative budgets and are never dropped for performance. Detailed
telemetry is disabled by default.

The existing dispatcher step 13 is opportunistic. Preserve the every-tick fallback
and serviced-this-tick guard: relying only on the rotating scheduler slot breaks
exact contact deadlines. `pending` counts contacts plus first-collapse and echo
packets, not victims or only collapses. `pending_contacts` and `sweep_count` expose
the mechanical acquisition queue and active visual transitions separately.

Both production calls use `updater(event)`, guarded by `has_tick_work(event)`.
The removed step-13 pending-count/limit calculation never capped paid delivery;
all due packets and active sweeps retain their existing service. Diagnostic
pending-count exports remain. Staged QC calls use
`service_for_qc(legacy_limit, event)`, which ignores the compatibility limit,
forwards the event and returns the actual processed packet count.

## Presentation and lighting

Keep at most **one main native beam and three incision extensions per lance**.
Move live same-material beams with endpoint setters, preserving animation.
Recreate on expiry/material change. Native duration covers acquisition plus hold;
beam TTL mutation is unsupported. First acquisition grows from the crystal;
later acquisition starts at the previous displayed endpoint, falling back to the
last authoritative contact after cosmetic cleanup. Rotate around the actual
crystal on the shortest angular arc and interpolate length independently. Exact
180-degree ties rotate clockwise. Unwrap moving goal bearings against the prior
goal so crossing the angle boundary does not abruptly reverse the arc. Smoothstep
`3u²−2u³` eases both angle and length: peak angular speed is about 1.5 times the
nominal average, before burst compression or target movement. Same-target firing
stays visually locked during acquisition, including when the enemy moves; the
paid damage still waits for contact. A lock requires the same target, force, and
surface as the previous presented contact.

The crystal source offset is `(0,-3.35)`. Forks meet at the ground contact point;
never apply crystal height to branches. Retract old extensions during transition
and reveal new forks at contact. Preserve each material's opening animation,
original impact bloom, saturated flowing patterns, tapered tails, and lighting.

Beam middle/end terrain light randomly selects the artwork's **cyan, cobalt,
magenta, violet, orange or gold**, at **25%** of the prior preset strength. Each
native beam segment keeps its chosen color until natural expiry or a material
change; endpoint movement never rebuilds it merely to change color. Branches can
choose different colors. The crystal-side tail retains warm violet **RGB(.72,.35,1)**.
Masks and preset scaling are unchanged. A saved, independent cosmetic random
generator selects variants without consuming gameplay RNG or adding a tick loop.

Contact creates a **5-tick** flash and afterglow matching the main beam's chosen
endpoint color, using the hit-fire preset's size/intensity/duration
(**14 ticks Lean; 30 Standard**). Legacy cyan prototypes remain for saved effects
and old beam handles until they expire. These
are transparent finite native light effects with native fade-out, not damaging
fire. Keep one flash and one afterglow per presentation context, replacing old
handles at the next contact.

This restoration reuses the approved beam artwork and light masks. It needs no
new raster sheets or companion graphics-pack version change. To repair alignment
or lighting, inspect endpoint geometry and supported native light layers before
regenerating the established Prismatic Liturgy art.

Incision geometry, Wound bands, collapse core/outer boundaries, Testament's dark
disk, and echo cross remain in Lean. Reduce optional sparks, crowns, extra glow,
and scars first. Rendering budgets never change damage or hide a defining cue.

## Research and player information

| Upgrade | Required direct prerequisites | Final science set |
| --- | --- | --- |
| Axial | Lance | Exactly the lance's finalized ingredients: Dark, Steam, Electricity, Computer, Alien Computer, Advanced Computer, Space |
| Wound | Axial + Quantum Age | Canonical quantum-age: preceding seven plus Quantum |
| Collapse | Wound + Exotic Age | Canonical exotic-age: Dark, Steam, Electricity, Computer, Alien Computer, Advanced Computer, Quantum, Fusion Quantum, Exotic |
| Testament | Collapse + Black Hole | Canonical black-hole-exotic-age: Exotic set plus Black-Hole Exotic |

The deeper sets omit Space as an ingredient but retain its prerequisite progress.
Operating a black hole is unnecessary. Capabilities require preceding upgrades;
an isolated researched flag cannot bypass the chain. Declare before ordinary
processing; reconcile packs after inheritance and before automatic cost
normalization; restore mandatory links after flattening; validate without a
second pricing pass. This sweep change does not alter costs or research identity.

Handle normal/scripted research, reversal, force resets, effect resets, and
merges. Update statuses only when effective values change, plus configuration
refreshes needed to repair stored labels.

For a force-current baseline DPS of 3648, the native diode row reads only
**Base direct DPS: 3.65k**. It is
force-current baseline primary DPS, excluding all conditional Wound/Testament and
secondary damage. Use bounded k/M/G formatting and scientific fallback. Do not
restore names, damage ranges, meters, separators, icons, or newlines to that row:
the native custom-status API provides no wrapping/height controls. There is no
general runtime `LuaEntity.custom_description` workaround.

Static item/entity/Factoriopedia rows explain research-unlocked effects with
shared localized parameters. Informatron supplies exact current values, research
state, mechanics and visual legends on open/refresh. Maintain all seven sidecars
and accepted Japanese terminology. Preserve existing lore. Its final line and
separator need separate graphical inspection; shortening status alone cannot
prove native tooltip clipping is fully repaired.

## Migration, tests, and evidence boundaries

Schema 11 advances in place to 12, then 12 to 13, then 13 to 14, with explicit
intermediate version assignments. Preserve registrations, counters,
Wound timestamps, and outstanding paid work. Old collapses keep their original
positions, due ticks, damage, primary eligibility, and echo behavior. Only new
schema-13-and-later shots use contact-relative timing. Existing schema-13 contacts
keep their original deadlines and legacy Cartesian interpolation. New schema-14
shots snapshot angular policy/pivot; migration does not add that policy to old
contacts. Repair cached FIFO tails for registered and detached paid records;
derive logical aim only from the mechanically published last contact. Never route
schema-11/12/13 saves through the older state-replacement migration.

Schema-14 saves serialize logical aim, queue-tail reservation, angular transition,
FIFO order, context sharing, native beam handles, and
linked pulses. Test both counter seven and a paid eighth shot saved before contact.
Reload must not repay, recount, duplicate, reorder, or resnapshot a transaction.

Coverage includes angle-derived contact and +30/+60 timing, the legacy 8/38/68
deadlines, every quadrant/angle wrap, 90/180-degree arcs, different radii, moving
goals, burst compression, cosmetic rebuilds, moving/dead/transferred targets, Wound zero damage
and exact expiry, research/ownership/diplomacy changes, source/surface removal,
force merges, core/outer exclusivity, corridor ties/large/rotated/quality bounds,
actual old saves, all fidelities and overload, native beam/light bounds, compact
numbers, locale parity, and zero idle/unrelated work.

Benchmark matched no-lance, idle, direct-only, normal-power, dense, diagonal and
research-flood scenes, plus native-power and artificial-burst wide retargets:
discard one complete warmup run, then measure five runs.
Artificial 60 Hz injection is not normal-power combat. Report contact, sweep, light,
incision, first-collapse, echo, and decoration separately. Nested profile phases
cannot be summed as independent work. The historical dense 1 ms p95 objective was
unmet; report measured limits honestly. Headless benchmarks omit GPU/render cost.

The user performs graphical acceptance manually: normal zoom, day/night,
Lean/Standard, crystal opening/alignment, smooth sweeps, compressed bursts,
connected forks, contact/damage agreement, full warnings, prismatic middle/end lighting,
96-lance readability, moving enemies/worms/spawners, and tooltip/lore/diode layout
at ordinary/enlarged UI scales. Engine tests alone do not certify appearance.

## ANISETRON inheritance

`lib/singularity-lance-payload.lua` and `lib/singularity-lance-art.lua` expose the
shared packet and material factories. The turret retains its existing payment,
state, timing and baseline splash. ANISETRON uses those factories under its own
native ammunition controller: crown-only upgrades, proportional secondary damage,
paid research/quality snapshots and independently budgeted presentation. Shared
helpers own no persistent state or event registration. See the
[cathedral contract](../.codex/esir/blueprints/anisetron.md#inheritance) and its
[native regression fixture](../scripts/qc/anisetron-inheritance/README.md).
