# Capture, batches and review

The current workflow starts with user-recorded footage. Preserve original videos,
associate them with feature IDs, and apply the shared style during conversion.
The existing renderer expects native screenshot manifests; adapt import when
footage arrives rather than claiming it already accepts video. The automatic pilot
effort is stopped and must not restart without a new request. Close the ESIR
rebuild activity window before every take and GUI capture, including when it
reappears during setup.

Resolve the exact engine and dependency selection from `.codex/esir/factorio-development.json` and use matching version-pinned docs. Follow the [managed storage contract](../../esir-dev/references/housekeeping.md): reuse canonical dependency ZIPs, share immutable source/media, and keep bridge-patched gameplay code and run settings private. Never change live mods, settings or seed saves. Graphical runs are sequential; never terminate unrelated Factorio processes.

The helper sets up scenes, invokes existing controls, captures screenshots and observes outcomes. Production `control.lua` owns simulation. Staged bridge functions may expose GUI handlers or read state. Never fake outcomes, shorten recipes, force phases, synthesize attacks, substitute test entities, or invent GUI readouts. Record setup supplies and off-screen fixture power honestly.

Prove connected player, advancing ticks, resolution, scale and expected GUI before capture. Run startup comparisons separately. Record effective settings and source ticks. Existing diagnostic scenes are examples, not automatically suitable public footage.

Capture fingerprints include gameplay content, graphics identity, helper code, scene and settings; identify stored inputs by content hashes rather than a cache location. Render fingerprints additionally include captions, tokens and compositor. Missing/stale artifacts must not resume as complete. Candidate outputs go to ignored `output/portal-media/`; reviewed media and compact receipts go to `portal/media/`. Capture and rendering are separate consumers: retain a pending-consumer lease for raw frames until rendering and validation finish. Then close the run, retaining final media, selected QA captures and compact reproduction evidence without copying whole capture trees.

Check claims, native behavior, first/last frames, loop transition, caption readability, timing, five pilots together and total bytes. Record editorial review separately from machine validation. Keep blocked entries visible; never claim full coverage while source areas remain unreviewed.

Assemble Markdown from one source, keeping the listing summary separate and <=500 characters. Include reviewed media only, with unfinished work in the local report rather than broken publication links. Verify hosted WebP playback in the actual Portal preview before publication; local HTML does not prove Portal compatibility. Existing externally referenced media remains until its consumers are reconciled.
