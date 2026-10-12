# Native delta-blend hypothesis fixture

This is a synthetic diagnostic, not a new art representation or production
approval. It reuses the isolated native-color runner and disposable helper name;
each Stage call receives its own managed payload. Stage never launches Factorio.

<a id="contract"></a>
## Contract

The generator creates textured known-color opaque underlay U and target T.
Inside a six-pixel opaque collar it solves integer coefficients:

```text
M = round(255 * min(T,U) / U), with M=255 when U=0
D = T - round(U*M/255)
```

All D channels are nonnegative. Ordinary source-over R owns the collar.
M uses `blend_mode="multiplicative-with-alpha"`, `premul_alpha=false`, and
either `draw_as_glow=false` or `true`; D uses `blend_mode="additive"` and no
glow/light flag. M's transparent RGB is white identity, deliberately meaningful
to its unpremultiplied interpolation. Generated PNG encoding is lossless.

This differs explicitly from the accepted normal premultiplied source-over-only
contract. A passing synthetic result would authorize only investigation of real
art packing and a new native art gate. It changes no frame counts, archive
limits, production files, runtime behavior or approved shading requirements.

Installed Factorio 2.0.77 documentation is authoritative:

- [BlendMode](https://lua-api.factorio.com/2.0.77/types/BlendMode.html) documents
  the multiply/add equations and warns that mipmap generation does not preserve
  `premul_alpha=false` semantics.
- [SpriteParameters.draw_as_glow](https://lua-api.factorio.com/2.0.77/types/SpriteParameters.html#draw_as_glow)
  draws a normal pass and a light pass. It is not assumed to be a one-pass unlit
  multiplier. Night failure, double application, emitted light or contamination
  of other sprites blocks this representation.

No `draw_as_light=true` variant is included: the installed description does not
establish the requested one-pass semantics, so this fixture makes no assumption
about rendering coefficients into a lightmap.

## Native matrix and lifecycle

81 pairs: base-only, state-only and base-under/state-overlay surfaces; ordinary
and glow multipliers; daytimes 0/0.4/0.5; zoom 1/1.5; 0/0.5 native-pixel offsets;
six identity-coefficient cases and three duplicate-reference controls. Reference
and candidate occupy exactly the same coordinates in sequential captures.
Each capture follows three settling ticks. A normal foreground sprite and a glow
FX stripe cross the tested card and must remain unchanged. The background also
must remain unchanged outside the card.

The helper's `control.lua` is its sole dispatcher. It owns a bounded sequence in
storage, accepts event ticks and stops at the declared finish tick. The existing
main turret is cloned for native base/state surfaces; no production prototype
or ESIR runtime module is modified. There are no bullets, lights, generators,
enemies or continuously running feature controllers.

Uncompressed native math allows at most 2 RGB codes and 0.25 RMS overall, with
zero error on background, normal foreground, glow FX, identity coefficients and
duplicate controls. Captured prototype names and world positions must match the
planned candidate/reference pair. Warm/blue reference-cell confidence rejects a
blank or missing card even if both screenshots happen to be identical.
Both hypothesis variants receive independent verdicts. One may fail while the
other passes, but source art and archive eligibility remain false regardless.

The analyzer retains screenshots, heatmaps, input hashes and individual cases.
Its result is evidence of actual native behavior only after the root agent runs
the staged payload through the existing launcher.
