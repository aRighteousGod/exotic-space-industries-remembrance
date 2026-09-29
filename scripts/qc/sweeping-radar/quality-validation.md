# Heavy radar power and Balanced quality validation

Validated on Factorio **2.0.77 build 84539**, ESIR **1.3.40**, 2026-09-29.
[quality-results.json](quality-results.json) contains the passing functional
reports, final prototype inspection and hashes of both current and staged source.
Reproduction commands and fixture semantics are in [README.md](README.md).

Performance benchmarks and profiling were **skipped at the user's request**.
The finite-tick engine runner executes functional assertions only. Historical
timings in [validation.md](validation.md) predate this balance change and do not
measure its performance.

## Implemented values

| Property | Sweeping | Phased-array |
|---|---:|---:|
| Native standby | 1 MW | 2 MW |
| Base observation energy | 8 MJ | 5 MJ |
| Input ceiling | 64 MW | 128 MW |
| Normal-quality buffer | 16 MJ | 10 MJ |
| Base requested capacity | 2/s | 8/s |
| Normal/unresearched full-rate demand | 17 MW | 42 MW |
| Fully researched Legendary radius | 28 chunks | 36 chunks |
| Fully researched Legendary requested capacity | 6/s | 24/s |
| Fully researched Legendary observation energy | 4.48 MJ | 2.8 MJ |
| Fully researched Legendary full-rate demand | 27.88 MW | 69.2 MW |

Demand figures assume that the requested observations are actually admitted.
Standby continues while paused or armed. Shared work budgets, contact limits,
queue bounds and selected manual geometry are unchanged.

## Functional evidence

- **194 quality checks passed**, covering 42 chassis/quality/research cases:
  both chassis; five native qualities plus modded levels 4 and 9; no research,
  capacity-only research and all radar research. Additional arithmetic checks
  cover negative, fractional and above-Legendary levels. The fixtures verify
  fixed anchor interpolation, range flooring, saturation, native health, fixed
  Normal-quality helpers and electrical charging headroom.
- Power checks measure native standby exactly once, one accepted observation
  debit, starvation invalidation, recovery without catch-up, empty repairs,
  retained manual radii, and both research notification paths. Ordinary research
  is delivered to the production receiver through the isolated QC bridge;
  scripted research uses the actual scripted-burst path.
- Real player cursor builds upgrade and downgrade quality, proving changed
  entity identity, settings retention and preservation of a partially filled
  3 MJ buffer. Robot transaction tests cover quality/chassis changes, capacity
  capping, invalid 36/35 geometry after downgrade and recovery after upgrading.
  The player build area is explicitly land and Legendary is unlocked for its
  fixture force.
- Fixed-bearing and perimeter Watch scans detect a target 1,136 tiles away,
  exclude the target outside 36 chunks and submit no terrain generation.
  Global stage-operation caps and the 32-job limit are asserted throughout.
- **62 broader acceptance checks passed**, covering all five modes, circuit
  overrides, reporting policies, contacts/expiry/hostility, geometry boundaries,
  blueprints, clones, player and robot upgrade paths, force changes, teleportation,
  helper teardown, surface removal, freezing and GUI lifecycle.
- The shell/wiring gate passed at all seven installed fixture qualities. Native
  scanning remains disabled; red input and green output remain isolated.
- A paid 128-candidate batch captured after 64 aggregation records resumes in
  order through ordinary reload and forced configuration change, completing the
  observation without another debit. The new Normal Phased-array payment is 5 MJ.
- Four unpaid generation waiters preserve queue order and deadline on reload.
  The oldest waiter receives the next grant and pays exactly 5 MJ once.
- Old-power save migration verifies the checkpoint really uses 4/2 MJ buffers
  and the pre-quality capabilities. Loading current code preserves the stored
  joules and changes capacities to 16/10 MJ and standby to 1/2 MW through bounded
  control service. The first snapshots retain 996,666.67/995,000 J from their
  1 MJ checkpoints; no energy is granted by capacity expansion.

## Fixes found by verification

Electric-energy interfaces serialize their electrical properties. Updating their
prototype alone left old saves using the old capacity and standby. A cached
`power_revision` now causes one bounded helper replacement, transferring only
existing joules. Fresh/copy/repair helpers remain empty. The final quality fixture
also covers a delayed destruction notification from an older helper: it must not
clear or orphan the replacement helper.

A changed effective capability signature invalidates unfinished work without a
refund or a second charge. Ordinary reload and an unchanged configuration retain
paid progress. The old-balance migration fixture tests paused buffers; it does not
claim that a paid old-price job completes across a capability-changing rebalance.

## Prototype, locale and presentation review

Final `data.raw` inspection passed: exact power limits, zero additional drain,
zero output flow, disabled shell scanning, recipes, finite research, final
prerequisites/science, productivity exclusion and recycling. Standard radar is
unchanged. All seven shipped locales pass 95-key parity, placeholder, duplicate
and UTF-8 checks. Radar modules contain no `game.tick` reads; event call chains
continue to receive ticks from the dispatcher.

English engine screenshots were inspected for Full, Sector, Perimeter, Pulse,
Fixed and remote view. The Legendary readout shows 36 chunks, 24/s maximum,
2.8 MJ/observation, 2 MW standby, 128 MW input, 10 MJ storage and 69.2 MW at
requested full speed. Requested and achieved rates remain separate. Saved open
screens acquire the new readout without losing unapplied control edits.
The graphics fixture uses matching companion archives to avoid the Windows
deep-staging sprite-path failure. This is a rendered/handler-driven GUI review,
not physical mouse/keyboard interaction or native-speaker locale approval.

The conceptual-model audit passed. Final repository preflight passed Lua, Python
and PowerShell syntax, requires, locale keys/duplicates, asset references and
pack versions. Its overall status remains failed solely because of suspected
mojibake in the unrelated `scripts/qc/singularity-lance/angular-results.json`;
existing module-header warnings also remain. That file was left untouched.
The first run's Python cache-path failures were eliminated by using an extended
Windows path for `PYTHONPYCACHEPREFIX`; all 55 initially blocked files also
compiled read-only. No unrelated worktree content was changed to make the radar
result appear clean.
No multiplayer synchronization claim or new performance guarantee is made.
