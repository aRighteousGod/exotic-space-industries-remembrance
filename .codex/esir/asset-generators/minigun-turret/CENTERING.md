# Minigun placement-box centering

Both production graphics factories apply `entity_shift_y = 6/32` once to copied
sprite/shadow leaves and every copied launch-map Y coordinate. The original
atlas metadata is unchanged. No rerender, PNG edit, icon change, collision-box
change, native transition change or runtime controller is required.

The visible base alpha-bounds midpoint was about 5.5 SD pixels north. Its new
midpoint is about 0.5 pixel south of box center. The actual contact footprint is
nearly centered already: canonical base XY center `(0.0100228,0.0739113)` projects
to `(0.0100228,-0.0522632)` screen tiles. This adjustment centers the visible base;
it does not attempt to center the entire elevated gun silhouette at every yaw.

The physical foundation remains inside the existing 3x3 selection box and
2.8x2.8 collision box. Colors, all shadows, muzzle flashes, projectile origin and
receiver casing outlet move together. Preserve the calibrated casing parameters
and native launch-field presence, including the absent projection flag.

Retained evidence and exact package receipts live under
`output/minigun-implementation/centering-001/`. Its native fixture compares SD/HD
before and after at four cardinal headings, including parked, actual firing and
stand-down. Data-stage assertions cover all256 launch entries, every native
animation/shadow leaf, untouched source metadata and repeated-apply stability.
The main SD factory is copied verbatim into the isolated fixture; the standalone
HD prototype uses the shipping public factory. No unrelated main gameplay load
or full firing-matrix repeat is claimed.

`centering-fixture/` contains the reproducible helper and runner. These are QC
files, not shipping gameplay prototypes. Use a new ignored dossier/run for future
comparisons and close only the corresponding housekeeping record after retaining
the report and images.
