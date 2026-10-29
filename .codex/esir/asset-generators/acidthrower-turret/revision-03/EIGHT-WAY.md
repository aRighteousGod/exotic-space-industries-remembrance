# Eight-direction extension

The four cardinal sheets and three 256-direction head sheets are retained
byte-for-byte. New diagonal body/shadow/glow/owner sheets use NE, SE, SW, NW
at 45, 135, 225 and 315 degrees; 320px cells, scale 0.5, and at least eight
pixels of alpha margin. The inherited preset renders at 64 source pixels/tile.

The first custom silver pipe trial was rejected. The final model contains no
new pipe meshes. `graphics.lua` layers native `pipepictures()` straight sprites
under the diagonal body. Horizontal centers are west for NE/SE and east for
SW/NW; vertical centers are south for NE/NW and north for SE/SW. All centers are
one tile from the entity origin. These overlays do not inherit the body's
0.18-tile rearward shift. They retain native baked pipe shadows; the final
removable covers still belong to `pipecoverspictures()`.

The renderer now includes `initial_angle` when fitting rigid tank/bearing
centers and verifying frame angles. Ground Y compensation still follows
placement rotation, and tank/bearing local geometry remains unstretched.
The calibrated muzzle length and height remain unchanged.

The preserved source dossier is currently at machine-local
`D:/ESIR/CodexArtifacts/esir-acidthrower-20261009/revision-03`.
The earlier README's `D:/CodexArtifacts` locations are historical.

From the repository root, render and stage a new derivative:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/acidthrower-turret/revision-03/render-diagonal.ps1 `
  -SourceRoot D:/ESIR/CodexArtifacts/esir-acidthrower-20261009/revision-03 `
  -ArtifactRoot output/meshy/acidthrower-eight-way
```

`-Promote` copies only the four new diagonal sheets into Graphics 6 after
packing checks. Use a fresh artifact root for a fresh comparison. C: capacity
fallback for this task is `D:/ESIR/output/acidthrower-eight-way-20261028`.
No original source model is overwritten and no head rerender is needed.

Native acceptance and exact profile/cardinal parity are in
`scripts/qc/acid-eight-way/`. Native screenshots, rather than standalone
Blender previews, establish the joins between pipe overlays, body and covers.
The current runner is `scripts/invoke-acid-eight-way-qc.ps1`; its fixture README
documents the exact engine override, retained baseline inputs and individual
suites. Completed evidence is recorded in [EIGHT-WAY-ACCEPTANCE.md](EIGHT-WAY-ACCEPTANCE.md).
