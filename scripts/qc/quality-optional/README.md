# Optional Quality acceptance (Factorio 2.1.23 / ESIR 1.4.01)

The production dependency is optional Quality with required Space Age and Recycler.
Core staging accepts `-Quality disabled`; optional-combination staging inherits that
selection instead of re-enabling Quality. Every disabled matrix row creates a fresh
save with the accepted full-core dependency seed. Dedicated higher-quality suites
remain explicit; this suite records absent content as skipped.

Register short task-owned paths through scripts/esir-housekeeping.ps1 first.
Windows Factorio's mod loader cannot reliably resolve the longest production paths
when staged beneath long managed-run names. The runner freezes the main pack,
hardlinks dependency archives and junctions unchanged media/companion packs.
It never edits a user save or shipping source.

```powershell
python -B scripts/qc/quality-optional/audit.py --output .factorio-qc/qo1/audit.json
python -B scripts/qc/quality-optional/run.py --run .factorio-qc/qo1 --workers 2
python -B scripts/qc/quality-optional/run.py --run .factorio-qc/qo2 --workers 1 --phase runtime
python -B scripts/qc/quality-optional/transition_run.py --run .factorio-qc/qo2 --phase donor
python -B scripts/qc/quality-optional/transition_run.py --run .factorio-qc/qo2 --worker u --phase normal --id no-quality-normal --without-quality
python -B scripts/qc/quality-optional/staging.py --run .factorio-qc/qo2/staging-contract
```

The matrix covers all 64 combinations: four quality permissions, four productivity
permissions, two effects modes, and Quality enabled/disabled. It asserts final
prototype permissions, ESIR or upstream effects, unchanged progression fingerprints,
slots/ranges/energy/upgrade declarations, NSBC helper ownership, and inherited
death/hit/sound/Factoriopedia fields. This establishes inherited presentation data,
not a new rendered or audio acceptance claim.

Runtime rows exercise native inventory admission and transmission through all four
real ESIR/NSBC beacons, negative penalties, mixed positive effects, both overload
settings, native upgrades, and the production steam-pump build dispatcher.
Receiver comparisons retain native four-decimal precision and the receiver's own
effect limits. Power sources receive their real fuel/coolant every tick; this keeps
the 30/60 MW alien sources supplied during each transmission sample.

The hidden native client creates a real player for the populated donor save.
Use its `_autosave-quality-donor.zip` as the immutable input for separate `eject`
rows with chosen permissions, and for `removed`. The latter disables Quality after
staging and exercises the actual configuration callback before any tick output:
admin drafts/jobs, live/mined spider memory, nine orbital platform caches in all
three modes, invalid manifest rows, induction filters, and normal gameplay owners.
Private bridges are appended only to the frozen main pack; production callbacks
are neither replaced nor mocked. `reload` checks a saved tightened factory again.
Use `--without-quality` when reloading a removed-Quality checkpoint. `relax` checks
that loosening permissions leaves the installed modules and ground stacks in place;
`legacy` creates the explicit older-save case without a stored beacon policy.
Workers `t` and `u` use separate frozen main packs and loopback server ports.
The reload runner restores the checkpoint's original fixture phase and settings,
then benchmarks the actual saved map. Changing `case.lua` to a new reload phase
would itself request configuration repair and would not test an ordinary reload.

The normal-operation fixture uses genuine native ammo payment for ANISETRON and
the Emerald main cannon, checks exact contact/damage ledgers, and captures paid
normal/rare radar observations before removal. The fixture's matter recipe is
unlocked through its real technology so native configuration repair preserves it.
The upstream-sentinel matrix option verifies that Vanilla-like mode retains an
earlier mod's quality-module effect adjustment while ESIR mode applies its exact
authored table. The staging check exercises the actual optional-combination CLI;
it makes no claim about optional-mod gameplay. The older optional smoke runner also
preserves disabled rows and binds reusable receipts to the core profile/settings.

## Repository-wide audit decisions

The audit enumerates all 13 actual root packs, including ignored/untracked
companions. Every matching Lua/JSON line receives one of the plan's classifications
in audit.json, together with current source hashes. Text-only references, locale,
tooling and historical evidence were reviewed separately as follows.

| Finding | Decision |
|---|---|
| Main metadata | Guard required: optional Quality; Space Age/Recycler stay required. Other twelve pack manifests do not require Quality. |
| Three quality-module effect tables | Guard required: Quality present, target exists, ESIR mode selected. Vanilla-like skips the overwrite and retains other mods' effects. |
| Quality-module recipes/prerequisites | Guard required: mutate existing target prototypes only. Existing recipe routing already skips absent recipes. |
| Air Scrubber variants | Guard required: supported Quality integration and generated prototype exists. Runtime skips variant world scan when absent. Ordinary scrubbers remain active. |
| Admin selector drafts | Guard required: validate native/string identifiers before picker assignment, downgrade unavailable draft tier only, synchronize open controls. |
| Admin world jobs | Guard required: cancel vanished requested quality/entity; preserve completed work and existing reporting. |
| Spider remembered ammunition | Guard required: sanitize live and mined-item metadata independently before refits, never mint or alter real cargo. |
| Orbital scanner/logistics | Guard required: full Quality-change repair before publication; reject invalid signals at normalization/publication/manifest boundaries. Never downgrade demand. |
| Induction selectors, admin item operations, existing-prototype iteration | Already safe: current prototype validation and configuration refresh retained. |
| Steam pump | Native quality behavior: normal level0 exists without Quality; preserve formula and runtime storage index2. |
| Crystal/Fueler/EM trains/matter/radar/combat/shell replacement | Native quality behavior: normal multipliers and surviving-object transfers remain active. Reuse lifecycle repair for derived caches and paid work. |
| Train inheritance, module effect identifiers, quality scaling fields | Native quality behavior: no blanket presence guards. |
| Fluid recipe buffers | Already safe: approved native2.1 sizing with Quality; authored legacy-capacity fallback without it. Costs/yields unchanged. |
| Historical commented quality unlocks | Already safe: nonexecuting examples; no unsupported runtime creation. |
| Core/optional QC staging | Guard required: explicit disabled Quality row after staging, inherited selection, reject optional hard-Quality requirements. |
| Generic native probe | Already safe after optional dependency: iterates actual prototypes. |
| Dedicated higher-quality fixtures | Intentionally Quality-specific tests. Preserve original profiles; absent tiers are explicitly skipped in this suite. |
| Dependency intelligence | External Quality asset/helper paths are scanned; catalog refreshed. |
| Live blueprints/helper guidance | Mandatory-Quality claims corrected; conditional buffer policy retained. |
| Historical upgrade/packaging receipts | Preserve as dated evidence of the configurations actually tested. |

All three settings, choices, descriptions and active-policy summaries ship in eight
locales. The focused audit checks key and placeholder parity; ordinary preflight
also checks locale references and duplicates. Baseline unrelated preflight findings
are reported separately from this feature's engine results.
