# ANISETRON native ten-anchor gait trial

Use Factorio 2.0.77 with the shared runner and copied player seed. Clean physics
clones deliberately bypass the public ANISETRON paid/decoration/slow owners.
The public trial must separately pass native, mobility and attachment acceptance.
The best ten-leg gait passed mechanical checks but failed crystal-effect attachment
review. Shipping remains four legs. `-TenLegTrial` applies the retained calibrated
ten-leg prototype only to the staged helper, without a player movement setting.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-glide -RuntimeTicks 3600 `
  -RunName glide-initial -Fidelity off
python -B scripts/qc/anisetron-glide/analyze.py `
  --report .factorio-qc/anisetron/glide-initial/script-output/anisetron-qc.json `
  --output output/meshy/anisetron/reference17/ten-leg-trial/initial-comparison.json
```

The original four-anchor control is reconstructed explicitly from the saucer,
with .02/.02 leg response and the cathedral body. It does not inherit the newly
selected public ten-anchor engine. Ten anchors form two interleaved pentagons
within the original mount/ground bounds. The control and saucer have four legs.

`options.lua` defaults to eight headings, naked and one-exoskeleton cases,
3600 ticks, and ten-anchor overlap 0/.5/.75. `-FixtureOptions PATH` copies a
fixture-only Lua options table over that file. Response, overlap, stretch-force,
selection-distance and friction sweeps remain isolated from shipping prototypes.
`qualification-options.lua` retains the final eight-heading comparison and
`preview-options.lua` retains the selected public-vehicle clip configuration.
Raw per-tick position/speed/heading/relative-foot arrays are flushed in finite
120-tick JSONL batches. Native speed and quantized position remain distinct.

Ticks 300-899 measure warmed cruise; 900-1049 native braking; 1050-1349 restart;
1350/1700/2050 command 45/90/180-degree changes. A 30-tile endpoint approach
starts at 2400. The phase after 3100 also includes a restart at 3200 and must not
be reported as a pure stopping interval. No `stop_spider()`, teleport or writable
speed substitutes for native motion.

The best movement-only candidate is ten anchors, .02/.02 responsiveness,
stretch force .2 and zero overlap. Full eight-heading qualification is
`glide-qualify`; `qualification.json` records all sixteen naked/equipped cases.
The .5/.75 trials surged. A .05-overlap candidate had effectively equal cruise
variation but more reversal hesitation. Force .2 was measured, not inferred from
4/10 leg-count normalization. Selection distances, friction, bob and native
slow compensation retain their preceding values.
It was not promoted: unchanged speed-only decorative lift cannot follow the
ten-leg body's variable heave. A fixed offset cannot correct equal-speed samples
whose native vertical placement differs by almost one tile.

The public vehicle's clean native comparison captures use `visual=true`, one
heading and no equipment; run `-TenLegTrial -Visual -RuntimeTicks 2401` with
`-FixtureOptions scripts/qc/anisetron-glide/preview-options.lua`. Physics snapshots
still follow every tick; screenshots use native zoom 1 every three ticks, actual
frozen dusk and original engine RGB. `build_previews.py` pairs the old/new views
at real-time 20 fps and verifies each WebP is at most 10 MB. Off disables green
decoration for the matched gait comparison; separate Standard engine captures
review the actual beams and keel strands.

Current acceptance and complete replay commands are in
[verification.md](verification.md). Raw runs/options/captures remain ignored in
`.factorio-qc/anisetron` and `output/meshy/anisetron/reference17/ten-leg-trial`.
