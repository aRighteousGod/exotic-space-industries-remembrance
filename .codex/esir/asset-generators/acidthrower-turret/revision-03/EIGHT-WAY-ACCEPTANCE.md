# Eight-direction acidthrower acceptance

Implemented on the ESIR 1.4.1 / Factorio 2.1.23 line, without a version bump.
The user's rejected silver pipe meshes were removed. The diagonal bodies use
native straight-pipe sprites beneath the chassis, with native removable covers.
All seven existing machine sheets and `models/acidthrower.glb` remain unchanged.

The retained run root is
`D:/ESIR/output/acidthrower-eight-way-20261028`. Its
`acceptance-summary.json` binds the final source and sprite hashes to the native
receipts. Pre-change source/final-data snapshots and the registered evidence run
are under `.factorio-qc/acid8-20261028` (run
`e3b45dd7bd744463837d1dcbf6fea3a6`). The original source dossier remains at
`D:/ESIR/CodexArtifacts/esir-acidthrower-20261009/revision-03`.

## Completed checks

| Coverage | Result and retained evidence |
| --- | --- |
| Final data | Original, 2x, 4x, 8x and 16x match the pre-change turret and 24 acid effect prototypes after removing only the approved directional fields; `parity-*.json` |
| Native fluid connections | All 32 facing/port-mask combinations, exact native connection and target coordinates, positive firing-buffer filling, mass conservation and pipe removal/reconnection |
| Aiming and acid use | All 72 facing/angle/range cases fire, damage and consume fluid; maximum source-position error 0.342283 native pixels; final sampled consumption at least 48 fluid units |
| Rotation/replacement | Sixteen clockwise/counterclockwise sequences match vanilla behavior; sixteen vanilla/acidthrower fast replacements preserve connected ports and both circuit wires |
| Player/blueprints/robots | Eight cursor placements, sixteen individually verified rotation/mirror transforms of eight turret ghosts, eight actual robot builds; `player/player.receipt.json` |
| Reload | All 144 wired constructed bodies retain position, direction, quality, health, fluid, circuit setting and wire targets; `player/reload.receipt.json`. The 32 fluid fixtures also reload successfully |
| Existing cardinal save | Four original four-way turrets load against the eight-way prototype with identities, positions, ports, health, quality and circuits preserved; `legacy/script-output/acid-eight-legacy-load.json`. Native fluid equilibration changes individual stores by less than 0.000003 units, within the 0.0001 comparison tolerance |
| Ordinary layouts | All eight placements pass native pipe-branch and through-segment transfer tests with nearby walls; sixteen day/night images in `layouts/layouts.images/layouts` |
| Render geometry | Four 320px cells at 45/135/225/315 degrees; source density 64px/tile, 64-sample Cycles, game scale 0.5. All layer alpha bounds leave at least 46px margin, exceeding the required 8px |
| Final visual capture | 997 high-quality native captures, all present and hash-verified; `day-state/visual/visual.receipt.json` |
| Entity presentation | Native death effect/debris/remnant renders, and the exact authored Factoriopedia init/preroll scene executes and renders |

The final complete visual run is **`day-state/visual`**. The earlier `visual`
run retains 701 accepted captures, while `accept/ports-high.images` retains the
initial sixteen connected/capped reviews. Prefer the complete run's receipt and
review artifacts when reproducing the final state matrix.

Representative visual review covered every diagonal pipe join, cap visibility,
wire/connector mount, both aiming-sector edges, midpoint aiming, bearing contact,
head/tank sorting, daylight/night startup and folding, active-only accents,
adjacent walls and pipe junctions. No new visual defect was found. This was
representative frame inspection, not manual inspection of all 997 captures.

## Review artifacts

Under `day-state/review`:

- `ports-native.png`, `ports-enlarged.png`, and `day-night.png`.
- `aim-N/NE/E/SE/S/SW/W/NW.webp`.
- `state-*.webp` and `state-day-*.webp` for darkness and daylight.
- `firing-*-markers.png`, `visible-outlet.json`, and `review.json`.

Orange markers show the fitted visible grey outlet; cyan markers show the last
native stream-creation source. The accepted central 32px ribbon still has
intermittent phase gaps. Visible liquid measurements and frame inspection are
retained separately from the sub-pixel native source test; no particles, cadence,
effect sprites, damage or runtime handlers were added to conceal those gaps.

The new diffuse/shadow/glow/owner sheets are four 1280x320 PNGs. `sprite-qa.json`
contains their SHA-256 hashes and per-frame alpha bounds. The preserved original
model hash is
`257f4beadb591807487fbfd1b70ff7f1b02c3e38c284068cbbee38c6ce3e4c17`.
The rejected trial is explicitly labelled `rejected-silver-pipes-geometry.json`
outside shipping folders.

## Validation boundaries and replay

ESIR preflight passes every check except the pre-existing encoding finding in
`scripts/qc/singularity-lance/angular-results.json`. The `qc-assets` media check
passes with no errors or warnings; its outer result repeats that same unrelated
encoding finding. Logs are retained as `preflight-final.json` and
`assets-final.json` in the registered C: evidence directory.

Legacy upgrade verification is native headless state evidence; cardinal render
preservation is established separately by unchanged PNGs, exact cardinal final
data and current native captures. Factoriopedia validation covers authored scene
content, not the full GUI. Sound fields are unchanged; audio playback was disabled.
The comparison preserves research/quality fields across every profile and tests
rare construction/reload; it does not repeat the historical sustained DPS matrix.

See `scripts/qc/acid-eight-way/README.md` and `EIGHT-WAY.md` for replay commands.
The runner validates fresh markers, copied dependencies, capture inventories and
image hashes. Use a fresh run root if private dependency source identity changes.
Renderer input files and historical production artifacts remain preserved.
