# ESIR Sidecar Playbook

Use these as light read-only sidecars when the main agent can keep moving without waiting.

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

Main-agent rule: sidecars analyze and summarize. The main agent still owns edits, wrapper invocations, and final integration.
