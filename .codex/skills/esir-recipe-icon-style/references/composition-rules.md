# Composition Rules

These rules define how the skill should reason about ESIR recipe icon composition when it proposes or reviews companion-style changes.

## Baseline Intent

- Prioritize quick in-game recognition over decorative density.
- Prefer overlays, corner markers, and family-role badges over replacing the whole visual language.
- Treat the local companion mod as the primary reference for recipe differentiation patterns.
- Keep ESIR's existing icon language recognizable. This skill is meant to help restyle coherently, not erase local identity.

## Preferred Construction Surface

### Prefer `ei_lib.make_icons(...)` for common two-layer recipes

Use `ei_lib.make_icons(...)` when:

- the recipe is mainly "base icon plus one clear overlay"
- the composition already fits ESIR conventions
- the proposed icon can stay symmetric and compact

### Prefer explicit `icons = {}` when the recipe needs three or more meaningful layers

Use explicit layer tables when:

- the recipe needs multiple overlays with different shifts or scales
- the icon uses corner markers plus a central overlay
- the recipe needs a deliberate asymmetric composition
- the preview pipeline needs to preserve several distinct layers

## Overlay Families

Use the companion mod's families as the baseline vocabulary:

- isotope overlays
- isotope boards
- fuel overlays
- facility-role overlays
- logistics and filter overlays
- weapon or ammo family markers
- small companion ingredient or product markers

Do not invent a new family when an existing one already explains the composition.

## Placement Rules

- Prefer top-right or bottom-right for small semantic badges such as isotope numerals or filter markers.
- Keep the center readable. If an overlay blocks the silhouette of the base icon, resize or move it before adding another layer.
- If an outline is needed for readability, treat it as support for a real semantic layer, not the semantic layer itself.
- Avoid stacking two unrelated badges in the same corner when one can move without harming recognition.

## Background Rules

- Background plates exist in the companion mod, but they are optional in this skill's house style.
- Do not propose a background layer by default when a small overlay already disambiguates the recipe.
- If a background plate is part of the intended behavior, document it explicitly in notes and keep it visible in the report as a deliberate choice, not a silent assumption.

## Review Expectations

- A recipe marked `manual-review-needed` should stay that way until the base icon, overlay family, and intended behavior all agree.
- If a recipe cannot be flattened exactly outside the game, prefer a placeholder slot with honest notes over a misleading "finished" preview.
- When several recipes share a family, keep the overlay grammar consistent across the batch.
