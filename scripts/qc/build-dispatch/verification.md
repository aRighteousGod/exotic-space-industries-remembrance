# Build-dispatch verification, 2026-11-01

The focused lifetime repair passes on Factorio **2.1.24**, using the selected
development profile and its dependency set. The native suite reports **887 passing
assertions**, followed by **12 passing reload/entry-point assertions**. These are
assertion counts, not 899 independent gameplay scenarios.

The starting main pack, including pending user work, was frozen before editing.
The final comparison confirms that only `control.lua` and the six intended owner
files differ within that pack. The seven current source hashes match the accepted
private fixture. Existing version, changelog and locale changes were preserved.
Owner contracts and the runtime-orchestration blueprint were reconciled separately.

## Reproduced failure and repaired behavior

The frozen baseline reaches the actual registered build dispatcher with a turbine
and fluid-mode tags. The original shell is destroyed, three later general receivers
receive that invalid handle, and dispatch fails with:

> LuaEntity API call when LuaEntity was invalid.

The candidate passes the surviving fluid turbine to general registration, retains
quality, records the final unit in the turbine registry, and delivers no invalid
handle to downstream general receivers. All six destructive owners now explicitly
return a survivor or nil. Consumed placements terminate immediately.

An additional native entity-only probe exposed the crystal build entry point's old
unconditional `.entity` access. Event extraction now distinguishes an event table
from native userdata. Both the turbine and crystal entity-only calls pass after
reload.

## Coverage and evidence boundaries

| Area | Executed evidence |
| --- | --- |
| Ingress and metadata | Nil, empty and invalid input; all five registered event handlers with controlled event identity, tags, consumed-items identity, player/robot/platform fields and tick zero; native `script.raise_script_built` separately. |
| Early mutation | Native radar placement, flamethrower ghost replacement/tags, ANISETRON voice deletion, scrubber replacement and synchronous notification reentrancy; observers/helper cleanup during a forced Spidertron transaction. |
| Owner outcomes | Unchanged relevant turbine/crystal/steam/Tesla and matrix placements; native turbine/crystal/steam/Tesla replacements; Gaia rejection/refund; matrix duplicate resolution. Constructor failure injection preserves the turbine original and consumes crystal/steam/Tesla originals. |
| Boundary loss | Injected nil consumption at each of six dispatcher handoffs; incoming matrix deletion inside flood-fill; invalidation at scrubber normalization return. These are fault-injection probes, not natural placement reproductions. |
| Registration | Final turbine and pipe registry membership; final valid entity delivered through general receivers; per-receiver once-only assertions on accepted build cases. |
| Steam priming | Native fluid slot 2, steam at 165 C, unchanged quality formula and clamp for normal/rare/legendary pumps. The upper clamp remains source-verified; these native qualities do not reach 100. |
| Clones | Crystal replacement synchronizes adapter aliases and original destination; source retained; matrix-proxy interception and water-power-helper cleanup; settings-paste tail identity/order retained. |
| Persistence | A real headless server save is loaded by the same current engine; seven stored native entities, turbine/pipe registries and both polymorphic owner entry points survive. |

Gaia conversion remains blocked by the existing rejection-before-swap rule; no new
conversion behavior is enabled or claimed as tested. Event metadata probes use
controlled payloads, not a complete player/robot/platform gameplay harness. The
server is used to produce a native save; this is not connected multiplayer,
rendered/manual, cross-mod listener compatibility or whole-factory UPS acceptance.

## Reduced work and overlap

| Placement | Receiver calls before / after | Shared validation helper calls before / after |
| --- | ---: | ---: |
| Chest | 32 / 31 | 40 / 38 |
| Pipe | 32 / 31 | 41 / 39 |
| Unchanged turbine | 32 / 31 | 45 / 42 |
| Unchanged crystal | 32 / 31 | 42 / 40 |
| Unchanged Tesla | 32 / 31 | 40 / 39 |

These are receiver-export and `ei_lib.entity_check` counters, not elapsed-time
measurements or counts of every native validity read. The tagged turbine changes
from an aborted 12-call route to a successful 31-call route; those counts cannot
support a performance comparison. See the [overlap map](overlap.md) for legitimate
secondary consumers, irrelevant fan-out and the implications for future routing.

## Repository checks

Final preflight passes Lua/Python/PowerShell syntax, blueprint coverage, module
headers, require/asset references and the other non-encoding checks. The runtime
contract advisory completes with its 187 `clock-review` inventory findings; this
patch adds no `game.tick` reads. Focused Lua syntax and `git diff --check` also pass.

Wrapper `qc-runtime` runs 600 ticks with no runtime errors and existing startup
warnings. The broad wrapper and preflight both remain failed because the existing
`scripts/qc/singularity-lance/angular-results.json` is flagged for mojibake. That
unrelated file was not changed.

## Retained receipts

- [Baseline evidence](../../../.factorio-qc/managed/6870e380743240c28230479f1e66a41c/evidence.zip): 9 expected-baseline assertions, native failure and comparable stable-path counts.
- [Final evidence](../../../.factorio-qc/managed/f22f3fed8c3149bd8cd4bb8d53206aa5/evidence.zip): candidate/reload reports, input hashes, comparison receipt, preflight and wrapper output.
- [Native reload save](../../../.factorio-qc/managed/f22f3fed8c3149bd8cd4bb8d53206aa5/reload.zip).
- [Wrapper engine evidence](../../../.factorio-qc/managed/97e04786b5d84a459e8a11203f2463b2/evidence.zip).

The [runner README](README.md) documents reproduction and managed closeout.
