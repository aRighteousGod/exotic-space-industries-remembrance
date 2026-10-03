# Native player-built restriction verification

The connected-player Factorio2.0.77 fixture passed **18/18** checks both before and after the main dispatcher integration. Compact evidence: `restrictions-native-results.json`. The integrated replay uses `.factorio-qc/cu/g/admin-restrictions-integrated/native-stdout.txt` and `script-output/restrictions-native.json`; the earlier owner-only run remains under `.factorio-qc/cu/g/admin-restrictions-native/`, final `native-fourth-stdout.txt`.

The staged-only bridge is `restrictions-native.lua`. It appends to ESIR control and uses one actual connected player from `.factorio-qc/wtr/final-player/fixture.zip`. It creates an isolated finite surface,160 legacy attributed chests, an unknown map/script instance, a natural tree and known build records. It narrows the attribution census to that fixture surface so its completion time is independent of the seed factory. The startup admin setting is enabled only in the staged fixture.

Verified native behavior:

- Pending attribution temporarily gates native area/undo inputs and reports pending status.
- The census processes at most64 entity records and queries at most one generated chunk per tick, draining prior query results first. Finite-map void coordinates are skipped with a bounded64-step traversal.
- Surviving legacy `last_user` attribution is captured; a map/script instance with no attribution stays unknown. Real build events retain provenance when the old user is absent.
- Foreign deconstruction marks are cancelled; cancellation of an existing foreign order restores it. The original last_user is restored.
- A new foreign upgrade is cancelled. Replacing an existing upgrade restores the previous target/quality. Cancelling an existing upgrade restores it.
- Own and natural deconstruction orders remain native and usable after census completion.
- Combat/item/wiring input is blocked on a protected selection, then allowed again on the natural tree under the inherited permission policy.
- A denied native water-turret GUI closes before the feature dispatcher can recreate its companion panel.
- An active stationary selection watcher notices a last-user change and adjusts native permissions.
- Removing the final restriction removes all attribution/watch work.
- Invalid direct LuaEntity handles retain `object_name="LuaEntity"`, supporting correct manual diagnostic counts.

An independent native event-order probe established that all four mark/cancel events already expose the acting player as `last_user`; checking only that post-action value is insufficient. Prior attribution is therefore cached before area actions. Probe evidence remains at `.factorio-qc/cu/g/admin-restriction-order/script-output/restriction-order.json`.

The original18-check run invoked the owner directly before the main dispatcher adapters were integrated. The durable bridge detects the integrated adapters and delegates scheduled work to the main dispatcher when present. Its later integrated replay also passed18/18, including budget checks around the real dispatcher, area-order restoration and the native GUI-open early return. A separate full admin fixture covers the other dispatcher actions. Re-run after material changes rather than treating these saved results as proof of every later snapshot.

Limitations are part of the policy contract:

- The save contains one real player. Foreign tests represent a proven real build whose earlier player is absent; they are not simultaneous multiplayer tests.
- Native last_user identifies the last settings editor, not the original builder. Placeable prototypes alone do not prove player construction.
- The active selected/native-opened handle watcher is bounded, so other-player edits can leave a short stale attribution window. Factorio has no universal event for every native settings change.
- Direct selection/native GUI and tracked area orders do not provide a complete security boundary against AoE/projectile collateral, queued remote commands, indirect circuit actions, historical undo or another mod's scripted mutations. See `UNDO-LIMITS.md` for exact2.0.77 history API constraints.
- Query allocation for one dense chunk is native work; the64-record bound applies to Lua processing, not the size of that native array.
- Buildable objects without a unit_number have no per-unit area cache, though live selected/GUI checks can still use native attribution.

Use the same `invoke-control-ups-qc.ps1 -PrepareOnly` staging flow as GUI verification, with `-BridgePath scripts/qc/admin-tools/restrictions-native.lua`, the compatible full mod seed and an actual connected-player save. Enable the admin startup setting only in staged settings, run180 ticks, and require a fresh18-check `all_pass=true` report. Preserve all failed attempts. Do not treat these setup-heavy functional timings as UPS measurements.

## Native permission ownership follow-up

The full integration run `admin-acceptance-final8` passed seven added permission
checks in `restriction-permissions.lua`. A custom inherited group survives overlay
creation, deletion/recreation and restriction removal; its mining denial remains
active. A distinct later external group becomes the inherited policy and returns
when the restriction is removed.

Native membership assignments synchronously raise removal/addition callbacks.
The owner now guards its own assignment so an intermediate no-group state cannot
overwrite the saved policy. Native deletion assigns members to Default (id 0);
that fallback also preserves the saved policy. The fixture explicitly forwards
the deletion payload after scripted destruction and records native group IDs.
Earlier failing full runs `acceptance-final6` and `acceptance-final7` are retained.
This focused follow-up does not replace the separate 18-check attribution suite.
