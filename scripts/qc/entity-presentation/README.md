# Native entity presentation QC

Run scripts/invoke-entity-presentation-qc.ps1 -BaselineDump <pre-patch-dump.json>
with a compatible dependency seed. Add -Visual for native scene-content captures.
The runner registers a short managed payload, synchronizes live source packs,
and isolates controls only in staged mods to match native scenes with no mods.

The data fixture checks all spider/fuel descendants, five early-copied operating
bodies and eight native scenes. It transports the exact generated scene code
through mod-data; the runtime fixture supplies an isolated surface and a camera
facade, then executes the unmodified init/update strings. Assertions and steady
headless checks cover more than the native robot lifetime. Graphical capture
readiness is separate from that tick count; -GraphicsTicks defaults to 900.
Captures use a clean checkerboard, the
authored camera and native sprites. They do not test Factoriopedia's window,
gradient or navigation.

-PreparedModDirectory can retry private QC staging without copying the graphics
again. The runner checks every live gameplay Lua file against that stage (except
the deliberately isolated root control.lua), refreshes the fixture, and applies
bounded retries for transient Windows archive locks. Keep the supplying managed
run protected until the retry finishes. The helper depends on all active mods so
its data assertions run after their final modifiers. Compact fixture snapshots
are not registered as full data.raw cache seeds.

check.py compares selected gameplay/death fields and previously populated hit/
sound fields with the supplied baseline dump. It is a focused regression fixture;
extend its expectations when adding entities. The baseline must be the matching
pre-presentation-change dump, independently of the death checker's special
historical expiry baseline.
