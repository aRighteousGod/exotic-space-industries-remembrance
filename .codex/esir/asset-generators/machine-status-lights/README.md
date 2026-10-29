# Native status lens masks

`generate.py --output <registered-task-directory>/lens-art` derives 23 neutral
64x64 masks from the original red/green lens pixels on 20 production bodies.
Coordinates come from the shared Lua indicator registry. The source body and all
frames of its working animation are read without modification. The output
manifest records source and result hashes, pixel support and per-frame counts.

Connected bright red/green cores locate each lens. Castor uses a lower threshold
for its dark ribbed lenses. Nearby disconnected bright rims are included within
five source pixels, then antialiased fringes within three pixels; both require
red-to-green changes in the original animation to distinguish the lamp from
unchanged bronze casing. A one-pixel opaque neutral guard covers texture-filtered
edges so the original red cannot bleed through. Maximum source-channel brightness
preserves the lens shading. Clipping and missing base support fail generation.
Review the source/mask/green/yellow/orange contact sheet before promotion, then
inspect native normal/enlarged day/night borders and transition captures.

The advanced refinery is an explicit whole-screen exception: its nearest bright
connected display includes the old red corner and constant cyan quadrants. The
complete inset screen is centered at source pixel `(470, 555)`, with its cyan
antialiasing and the same one-pixel guard, leaving the bezel intact.

These assets ship in **Graphics 6** at
`exotic-space-industries-remembrance-graphics-6/graphics/status-lights/`, without an `ei-`
filename prefix. Copy only the 23 named mask PNGs; previews and manifests remain
in registered staging. No original sprite sheet is replaced or retired.

Each native working visualisation combines a status-tinted lens and light.
Normal blending covers the old colored lens pixels; `draw_as_glow` preserves
night visibility. Transparent no-power tint hides the addition and leaves the
original artwork intact. Native rendered acceptance is required after generation;
the offline recoloring preview does not establish in-game appearance.
