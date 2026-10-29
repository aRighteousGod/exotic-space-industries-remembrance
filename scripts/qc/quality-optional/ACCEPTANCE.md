# Optional Quality acceptance — 2026-10-29

Engine: **Factorio 2.1.23**. Main metadata: **ESIR 1.4.01**.
The accepted full-core dependency seed includes actual Space Age, Recycler,
RP steam pumps and Nonstandard Beacons Continued. Production Lua is frozen for
each run; private fixture exports do not replace the ESIR dispatcher.

| Scope | Result |
|---|---|
| Repository inventory | 13 shipping packs, including ignored/untracked companions; 550 Lua/JSON files scanned, 614 Quality matches across 100 files classified. See the README decision table and generated audit receipt. |
| Configuration/final data | All 64 combinations pass: 4 quality permissions × 4 productivity permissions × 2 effects modes × Quality present/absent. Each creates a fresh full-core save. |
| Upstream effect preservation | Both sentinel cases pass. Vanilla-like preserves an earlier mod's adjustment; ESIR applies the authored effect table. Recipe/research fingerprints remain equal across effects modes. |
| Native beacons | All 18 runtime cases pass, covering four real ESIR/NSBC bodies, native admission/transmission/penalties, mixed effects, independent family choices, both overload settings, and native upgrades with energy/module conservation. |
| Steam pump | Actual ESIR raised-build dispatcher primes the real dependency pump with 3 steam at 165°C in runtime storage 2; subsequent native operation consumes steam. Passes with Quality enabled and disabled. |
| Fresh no-Quality gameplay | Final 504-assertion run passes: Fueler, EM charging, matter crafting, crystal replacement, radar, ANISETRON, Emerald main cannon and orbital shards. |
| Actual Quality removal | 125 immediate selector/cache checks and 128 settled checks pass, including an open/rebuilt admin GUI, cancelled partial job, live/mined spider memory, live refit with ammunition conservation, nine platform caches in all three modes, publication/manifest rejection and induction filters. |
| Paid work and derived stats | Transition run passes 528 gameplay assertions. ANISETRON completes exactly 100 crown and 100 facade contacts, totaling 48,000 damage. Emerald retains and completes its paid wind-up. Normal/rare radar observations complete once without another debit; the surviving rare radar adopts normal capabilities afterward. |
| Installed-module ejection | Both families, each family independently, quality-only, productivity-only, and missing-policy legacy saves pass exact item-and-quality conservation and helper custody checks. A seventh case fills all 28 slots, including repeated module identities: all 24 forbidden modules return to the ground, and four speed modules remain installed. |
| Persistence | Native ordinary reloads pass with Quality enabled and disabled. Relaxation preserves installed modules and ground stacks. |
| Optional staging | Actual staging CLI preserves enabled/disabled core rows, pins, startup-settings bytes and archive identity; rejects a hard-Quality optional dependency in the disabled profile. |
| Locale and blueprints | All eight locales have matching 22-key policy sidecars and placeholders. Blueprint validation passes: 65 models, 211 owned sources, no findings. |

Current evidence is under `.factorio-qc/qo1` (64-case matrix) and
`.factorio-qc/qo2` (runtime, transitions, staging, audit and final acceptance).
The matrix's data-stage Lua still matches current source. Its later runtime fixes
are covered by the native runtime and transition snapshots, which match current
production source exactly. The matrix's unrelated Russian wording correction is
covered by the current locale checks.

Relevant preflight checks pass for Lua, Python, PowerShell, requires, locale,
assets, pack versions, module headers and blueprints. Overall preflight remains
failed solely on the pre-existing mojibake finding in
`scripts/qc/singularity-lance/angular-results.json`; this task does not modify it.
Final focused syntax checks also pass for all eight fixture Lua files and seven
new/modified Python runners.

Preservation review confirms that all 67 pre-existing tracked changes outside the
task-owned paths remain identical to the initial snapshot: 53 text patches and
14 full Git binary blob identities. Shared edited files retain their concurrent
hunks; no source assets, commits or staging selections are removed by this task.

The three task-owned runs are closed. Housekeeping declines its retention snapshot
because their staged mod folders contain junctions, so the registry retains them
as protected failed housekeeping records. The native acceptance receipts remain
passed and all evidence is preserved; no linked source folder was removed.

Absent Quality module tiers are explicitly skipped in no-Quality runtime rows;
dedicated higher-tier suites retain their original scope. Presentation evidence
checks inherited prototype fields. This record does not claim new manual visual,
audio, multiple-client multiplayer, all optional-mod gameplay, or generation-wait
timeout coverage.
