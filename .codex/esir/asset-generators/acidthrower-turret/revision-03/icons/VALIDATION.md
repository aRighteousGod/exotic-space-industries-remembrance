# Revision03 icon acceptance

2026-10-10: applied to the local worktree. The two existing graphics3 icon files
were replaced in place; no old icons, backup PNGs or preview files were added to
shipping folders. The fluid-turret, item and technology icon sizes were updated
in `prototypes/steam-age/acid-turret/acid.lua`.

## Passed

- Blender 5.1.1 rendered four complete-model views through the existing Factorio
  preset at 640x640, Cycles CUDA, 64 samples. Framing preflight passed. Frame 2
  (135 degrees) was selected and inspected at technology/item/native UI sizes.
- Shipping item icon is RGBA, 224x128, with 128/64/32 square levels. Its 128px
  level has clear transparent borders. Tiny Lanczos fringes at the 64/32px
  borders have maximum alpha 4/2, so opaque geometry is not clipped.
- Shipping technology icon is RGBA, 256x256; its model alpha bounds are
  `(10,30)-(246,226)`.
- `icon-qa.json` records final PNG hashes and dimensions. The two new Python
  generators compile successfully without writing bytecode caches.
- The established `Invoke-FactorioFastQC` harness used a new isolated D: root,
  pinned installed dependency archives, and live source-pack copies. Factorio
  2.0.77 completed `--dump-data` with exit zero and no engine errors.
- Fresh `data-raw-dump.json` is 2,047,593,299 bytes. Selective final-data inspection
  confirmed item and fluid-turret `icon_size=128`, the technology's first icon
  layer with `icon_size=256`, and the exact updated canonical graphics3 paths.
  The recipe retains its sole turret item result and no independent icon, so
  it follows the item image. See `final-icon-qa.json`.
- Repository asset references, Lua syntax and PowerShell syntax passed. The
  source diff passes `git diff --check`.

## Wider checks and scope

Fast QC overall status is `warning`, with no errors: Python bytecode cache
permissions and pre-existing compatibility diagnostics remain visible in its
summary. The broader repo preflight is not clean. It reported three unrelated
minigun conceptual-blueprint findings, Python cache permission failures and the
existing Singularity Lance / Anisetron encoding findings. Those files were not
changed as part of the icon update.

Remaining PBR, mechanical clearance, head rotation, glow-state and machine
spritesheet checks were skipped at the user's explicit request. The icon render
uses the current assembled model; it is not a Meshy regeneration or a new machine
spritesheet render. No gameplay, model, machine-sprite or pressure-jet edits were
made by this icon task. No commit, push, package deployment or live-save mutation
was performed.

Heavy render/QC output remains under the external D: artifact directory. It is
report-only under automatic housekeeping. The task-owned source/replay staging
run is registered and closed; durable generators and compact QA reports are in
the existing repository art dossier.
