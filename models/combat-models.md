# Combat model sources

Archived on 2026-10-12 from the models used by the current local asset pipelines.
The original GLBs retain their embedded textures and source geometry. The prepared
Blender scenes preserve the final render inputs, including mechanical separation,
material changes and added internal minigun parts.

| Asset | Original source | Prepared render model |
| --- | --- | --- |
| Oathbreaker Saw | [oathbreaker-saw.glb](oathbreaker-saw.glb) | Reproducible from the existing sawblade-turret generators |
| ANISETRON reference 17 | [anisetron.glb](anisetron.glb) | [anisetron.blend](anisetron.blend), [preparation metadata](anisetron-preparation.json) |
| Minigun turret prototype 2 | [minigun-turret.glb](minigun-turret.glb) | [minigun-turret.blend](minigun-turret.blend) |
| Acidthrower revision 03 | [acidthrower.glb](acidthrower.glb) | The supplied original source, preserved as requested |

The Oathbreaker source was already committed. Its bytes match the final source
named in the sawblade-turret dossier, so no duplicate or replacement was needed.
The acidthrower file is the original revision-03 input already placed in `models/`;
it is distinct from the later prepared `assembled.glb` used for rendering.

The five newly archived GLB/Blender files use Git LFS. After cloning, install Git
LFS and run `git lfs pull` to retrieve the actual model data. Existing Oathbreaker
history and other model history are retained without migration.

ANISETRON's Blender file is the exact `prepared-v2/anisetron17.blend` used for its
128-direction render. Its crystals, architecture and owner crest remain separate.
For the existing renderer, restore the scene and preparation JSON under their
original sibling names, `anisetron17.blend` and `anisetron17.json`.

The minigun Blender file is the exact `minigun-render-scene.blend` consumed by the
final separated renderer. It contains the fixed base, yawing upper, independent
rotor, bearing liner and rotor root hub. Its saved drivers precede the final
28-pose exposure setup; the local `render_separated.py` and `separated_contract.py`
apply that setup when rendering. This archive preserves the input scene unchanged.

File sizes, SHA-256 hashes, original paths and provenance are recorded in
[combat-models.json](combat-models.json). All four GLBs have valid GLB 2.0 headers
and embedded image/buffer data. Both copied Blender scenes opened in Blender 5.1.1
with packed textures and no linked libraries. Copies were verified byte-for-byte
against their sources. This model archive does not alter gameplay or shipping art.
