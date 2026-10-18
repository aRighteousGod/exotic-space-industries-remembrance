# V2 implementation verification — 2026-10-15

Factorio **2.0.77**, build 84539. Resolved dependencies: Arachnids **1.2.0**,
Armoured Biters **2.0.2**, Toxic Biters **2.0.6**, Explosive Biters **2.3.4**,
Cold Biters **2.2.1**, Electric Flying Enemies **0.1.9**. This implementation is
uncommitted worktree content; unrelated existing/concurrent changes were retained.

The user revised the Armoured contract: `ab-enable-nest` remains selectable.
The separate Armoured slider only controls separate nests. Shared ordinary nests
retain snappers, whose future births follow the ordinary enemy-base policy.

## V2 passed evidence

- **156 native generation cases / 1,982 assertions**, two seeds and 9,409 sampled
  positions per case. All six planets' default probabilities, generated nest/worm
  positions and demolisher territories match frozen v1 exactly. All six Nauvis
  families pass Off, individual zero, low/high and extreme sliders. Every pair at
  high frequency and three all-family combinations match their independent
  single-family results. All 156 native exchange strings round-trip.
- Factorio 2.0.77 initially coupled positive sliders sharing spot-noise seeds.
  Seed-preserving expression/coordinate/basement wrappers did not resolve it.
  The user approved native seeds at 1/1 and stable distinct seeds for adjusted
  Nauvis families. The passing matrix includes this workaround. Blob seeds,
  native masks and starting exclusions are unchanged. Revisit on Factorio 2.1;
  see [the model](../../../.codex/esir/blueprints/planet-enemies.md#seed-compatibility).
- **670 runtime assertions** pass with a saved connected player. Coverage includes
  all twelve controls, hostile births, silent removal, old-creature retention,
  actual Toxic infected gun/laser/artillery/radar callbacks, Arachnid's registered
  terrain-replacement callback, permissions, native editor construction/events,
  Apply/Reload/Discard, invalid drafts, same-field conflicts, unrelated concurrent
  changes, pending-to-live/replaced targets, positive tuple memory, zero richness,
  summon exemptions and 64-record owned-raft restoration.
- **72 persistence/global-field assertions** pass after a real server checkpoint
  and reload: an in-progress **2,600-raft** restoration queue, unsubmitted admin
  draft and sparse uncreated Aquilo overrides survive. The queue respects 64 per
  tick and completes. Aquilo's explicit first creation receives its overrides.
  Gaia staging receives overrides before generation, then its ready callback
  picks up an override revision submitted while reforge is in progress. All
  22 global editor fields accept native writes/readback and restoration.
- **8 shared-snapper assertions** pass with `ab-enable-nest=false`: the setting
  remains selectable, ordinary nests retain snappers, the Armoured row does not
  suppress shared births, the editor describes this, ordinary Off blocks future
  snapper births, and existing snappers remain.
  A further **16 final-data comparison assertions** establish exact native shared
  roster/weights: the five dedicated-nest snapper entries are appended unchanged
  to the four ordinary biter entries, and the dedicated nest is absent. All other
  fields remain identical to the separate-nest profile.
- Resolved final-data review covers **199 bodies**, including **20 Arachnids**,
  **196 unique nonsegmented birth notifications**, **33 autoplace records**,
  **14 spawn-result tables**, twelve controls and Gaia size **5**. Combat, loot,
  death effects, sounds and Factoriopedia fields remain unchanged. The final
  seed patch changes exactly six spot-seed expressions and three Nauvis aliases;
  all original native/dependency noise definitions remain intact.
- **98 v1 regression/reload assertions** pass on the final source after a real
  checkpoint during a **2,600-creature** removal burst. Queued invalidation-safe
  LuaEntity references survive reload, remain inactive and drain within the
  128-record tick budget. Egg spoilage, raft destruction/egg drops, robot vault
  mining, hostile vault callbacks and actual Gaia replacement still pass.
  The ordinary connected-player regression run separately passed 100 assertions,
  including real player vault mining; headless server setup skips that action.

Evidence is in the registered `.factorio-qc/v2-e` run:

- `gb`: frozen v1 defaults; `gfinal`: 120 default/individual cases;
  `gmix`: 36 mixed cases. `generation-final.json` combines their nonoverlapping
  records; `generation-final-checks.json` contains all 1,982 checks.
- `rfinal/script-output/planet-enemies-v2.json` and `planet-enemies-final-data.json`.
- `pfinal`: native checkpoint, reload log and `enemy-v2-persistence.json`.
- `sfinal`: shared-mode report and complete final-data snapshot.
- `v1r`: 100 passing v1 runtime regression assertions on the expanded policy;
  `v1final`: final-source removal checkpoint, reload log and 98-check report.

The protected v1 source baseline is registered under
`.factorio-qc/managed/aabde7891a54450fb7cd31a6d580bce3/baseline-source`.

## V2 evidence boundaries

- **No actual visual new-game or administration-menu acceptance is claimed.**
  Computer Use's native pipe was unavailable (`os error 2`). An isolated graphical
  profile was prepared at `D:/ESIR/enemy-v2-menu-20261015`, but no menu interaction
  or screenshot was obtained. Native GUI construction/dispatcher tests do not
  prove mouse/focus behavior, clipping, UI-scale layout or every resolution.
- Concurrent edits are tested through stale snapshots and native GUI drafts;
  there was no two-client multiplayer session. Scripted replacements/births are
  covered, but this is not a long autonomous expansion or combat soak.
- Broad preflight was rerun and still fails in the unrelated long-path scratch
  fixture under `output/minigun-firing-offline-tests`, before the intended checks.
  The blueprint audit reports only the three existing missing primary markers in
  `minigun-turret-HD`; no finding targets these feature models or sources.
- English fallback descriptions ship; native-reviewed translations remain open.
  Imported custom probability expressions are deliberately preserved and may
  bypass native seed isolation. Generated terrain and old enemies are untouched.

# Historical v1 verification — 2026-10-14

Engine: Factorio **2.0.77**, build 84539. Resolved enemy dependencies:
Explosive biters **2.3.4**, Cold biters **2.2.1**, Electric flying enemies **0.1.9**.
Baseline is the task's frozen pre-change worktree, including its pre-existing
uncommitted work. This feature remains uncommitted in the working tree.

## Passed engine evidence

- **138 generation cases / 454 assertions**, using seeds 1000 and 421337 and
  9,409 native tile-property samples per case. Default nest/worm positions,
  placement noise and native demolisher territory partitions/occupants match
  the baseline exactly. Positive frequency/size values change placement;
  Off and individual zero values suppress the selected family. Gleba Off
  retains exactly the default raft probabilities and generated raft positions.
- Demolisher low-frequency cells are a deterministic subset of the normal
  partition. Radius changes and extreme clamps evaluate within native bounds.
  Explosive/demolisher and Gaia/Fulgora controls remain independent.
- Six separate native Nauvis isolation checks pass. Switching the Vulcanus
  explosive or Aquilo cold control Off preserves all **319** sampled nests/worms
  at seed 1000 and **383** at seed 421337, including exact names and positions.
- **138 control exchange-string round trips** preserve frequency, size and
  richness values. Final data contains six enemy-category controls with enabled
  checkboxes; Gaia's native electric size remains **5**.
- **803 combined generation/final-data assertions** pass. All **115 affected
  bodies** preserve selected combat, loot, death effects, sounds, Factoriopedia
  fields and existing created effects. The added birth notification is unique;
  segmented demolishers use their native creation event without a head effect.
- **94 runtime assertions** pass. They exercise units, worms, nests and spider
  units; actual vault destruction and player/robot mining; a custom hostile-force
  guardian; inactive rafts with egg drops; actual egg spoilage and raft death
  offspring; retained existing enemies; and invalidated surface references.
- **92 reload assertions** pass with a real headless-server checkpoint made
  during a **2,600-creature** removal burst. Pending LuaEntity references remain
  valid and inactive after loading; the 128-record tick budget drains safely.
  Factorio defers server saving across tick boundaries, so a smaller burst can
  finish before the checkpoint is written.
- Gaia's actual reforge state machine replaces the surface while preserving
  zero enemy controls, seed, peaceful/no-enemies flags and customized cliffs.
  The fallback settings builder and legacy electric-control translation are
  exercised separately; existing generated terrain/enemies are not scanned.

Evidence is retained under these task-owned staging directories:

- `.factorio-qc/cu/g/planet-enemies-baseline-20261014`: baseline data dump and
  native generation report.
- `.factorio-qc/cu/g/planet-enemies-impl-20261014`: `acceptance.json`,
  `generation-checks.json`, `runtime-final.json`, `runtime-reload.json`, native
  checkpoint and per-run engine logs. The `script-output` directory contains
  detailed generation/final-data reports.

The runtime scenarios cover newly created spawner bodies through the shared
birth hook. They do not constitute a long-running autonomous expansion soak or
a connected multiplayer-client test.

## Remaining verification boundaries

- The **actual new-game menu was not visually verified**. The desktop helper
  found the isolated Factorio window, but activation/capture failed, including
  a `FrameArrived` timeout after recovery. Prototype records and exchange strings
  establish control wiring; they do not establish visual layout or mouse input.
- The normal `preflight` and `qc-fast` wrapper were attempted but stopped on an
  existing long-path scratch fixture under `output/minigun-firing-offline-tests`.
  The isolated engine tests above bypassed that unrelated traversal failure.
- The standalone blueprint audit reports only three existing missing primary
  markers in the separate `minigun-turret-HD` pack. No findings target this
  feature's models or source. Scoped `git diff --check` passes.
- New descriptions currently use English fallback. Native-reviewed translations
  are recorded in `.codex/esir/REVISIT_NOTES.md`.
