# ESIR Sidecar Playbook

Use these as light read-only sidecars when the main agent can keep moving without waiting.

## `event-lifecycle explorer`

Use for:

- deciding whether a runtime system can be pure event-driven or needs bounded scheduler work
- mapping the relevant lifecycle hooks for a feature: build, destroy, deconstruct, GUI, teleport, rotation, configuration change, and `on_object_destroyed`
- comparing a target module against `zzz-nonstandard-beacons`, `beacon-overload.lua`, `matter-stabilizer.lua`, `fluid-safety.lua`, or `orbital-combinator.lua`
- spotting steady-state scans that should move into repair, migration, or explicit refresh paths
- recommending when helper entities should be a derived proxy graph versus when plain storage and event hooks are enough

## `gui-pattern explorer`

Use for:

- deciding whether a runtime panel should use `player.gui.relative`, `player.gui.screen`, or `mod_gui`
- matching a new entity console to the right `defines.relative_gui_type.*` anchor
- comparing a target module against `black-hole.lua`, `fusion-reactor.lua`, `orbital-combinator.lua`, `orbital-logistics.lua`, `alien-system.lua`, or `em-trains/gui.lua`
- spotting stale-root, stale-entity, rebuild, or close-path gaps in runtime GUI code
- drafting concise guidance for titlebar, body, tags, fallback, and lifecycle conventions

## `runtime-map explorer`

Use for:

- direct `control.lua` load-surface mapping
- event/cadence inventory
- storage/gui/remote-interface scans
- header-metadata suggestions for runtime modules
- checking whether queued-control edits should use `lib/runtime-scheduler.lua` instead of custom tick/queue helpers
- spotting duplicated `event.tick` / `game.tick` plumbing or legacy fallback schedulers that should be consolidated

## `prototype-map explorer`

Use for:

- `data.lua` direct aggregator mapping
- prototype subtree ownership questions
- pack-to-pack asset dependency scans
- prototype header-metadata suggestions

## `portal-scout explorer`

Use for:

- Mod Portal metadata triage
- license/source-url sanity checks
- shortlist note drafting
- comparing candidate mods against current repo coverage

## `asset-pipeline explorer`

Use for:

- Firefox session artifact review
- prompt-to-asset role matching
- import-plan suggestions
- non-destructive image-format checks

## `regression explorer`

Use for:

- reading QC summaries or logs after a run
- grouping failures into runtime/data/assets/package buckets
- comparing a new run against prior artifacts under `.factorio-qc`

## `dependency-touchpoint explorer`

Use for:

- mapping which ESIR files touch a named dependency
- grouping runtime, prototype, planet, remote, and media touchpoints before the main agent edits anything
- spotting when one compatibility surface should move from one-off grep work into the checked-in dependency catalog

## `dependency-runtime explorer`

Use for:

- runtime/control dependency scans rooted in `control.lua` and `scripts/control`
- remote-call, remote-interface, and `script.active_mods` inventory work
- checking whether a dependency question is really runtime-facing or should be handed off to prototype analysis

## `dependency-prototype explorer`

Use for:

- data-stage dependency scans rooted in `scripts/data-updates` and `scripts/data-final-updates`
- cataloging guarded mod patches, `mods[...]` gates, and external prototype/library references
- separating general prototype integration from planet/content-specific compatibility

## `dependency-presence explorer`

Use for:

- optional local installed-mod presence checks under `%APPDATA%\Factorio\mods`, `output\tesla-run-mods`, and `.factorio-qc`
- confirming whether a named external mod is present locally and which key files it exposes
- validating that local presence stays query-time enrichment instead of leaking into checked-in manifests

Main-agent rule: sidecars analyze and summarize. The main agent still owns edits, wrapper invocations, and final integration.
