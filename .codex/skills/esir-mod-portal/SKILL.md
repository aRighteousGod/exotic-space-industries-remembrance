---
name: esir-mod-portal
description: Build and maintain ESIR Mod Portal copy, a complete player-facing feature catalogue, and consistent native-gameplay WebP demonstrations in resumable batches. Use for portal presentation and feature showcases, not gameplay asset generation or publishing.
---

# ESIR Mod Portal

Explain ESIR as a Factorio player would explain it to another player. This public-facing workflow uses plain language even where general repo guidance calls for lore. Keep actual feature names, explain unfamiliar names immediately, and show player action, result, and purpose.

Read [style](references/style.md) before preparing copy/media and [workflow](references/workflow.md) before a batch.

Current direction: the user records footage manually; Codex handles editing,
consistent captions and WebP conversion when footage is available. The automatic
pilot effort was stopped on 2026-10-19. Do not resume automatic capture unless
requested. Read `portal/batches/001-pilots.STATUS.md` for the handoff. Always close
the ESIR rebuild activity window before every take and GUI capture, and again if
it reappears.

`portal/features.json` owns the queue; `portal/coverage.json` maps source areas to features or remaining review. Current code and native observations outrank old manifests. Cover the whole experience, including inherited EI/ESI systems. Attribute integrated dependency content. Group related recipes/tiers; do not turn internal helper prototypes into public features or infer originality from `ei-` names.

`portal/content.json` owns page copy/category order; `portal/style.json` owns visual tokens. Batch specs live in `portal/batches/`. `portal/MOD_PORTAL.md` is assembled output, not another editable source.

Use `scripts/invoke-esir-dev.ps1 -Task portal-<operation> -Path portal/batches/001-pilots.json`, with `plan`, `capture`, `render`, `validate`, or `page`.

For another batch, select five pending features in the requested category and write scene/timeline specs. Reuse the same styles and tools. Record unresolved source areas and blocked captures honestly. Reuse only current fingerprint-matching artifacts. A source-verified feature is not automatically capture-verified or visually reviewed.

Keep all feature graphics on the Portal itself. Produce detailed 10–20 second demos by default, plus still posters. Report page weight; do not silently shorten demos or move the catalogue elsewhere.

This skill prepares local content. It does not authorize uploads, publishing, version changes or gameplay edits.
