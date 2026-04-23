# ESIR Preset Map

The companion mod exposes many narrow startup settings. This skill should speak in ESIR-first presets, then map those presets back to the local companion vocabulary and rule files.

## Icon Presets

### `icons-lite`

Use when the goal is recipe differentiation with minimal surface disruption.

- Companion settings:
  - `icon-visibility-esir-replace-facilities-icons = minimum|standard`
  - `icon-visibility-esir-replace-items-icons = minimum`
  - `icon-visibility-esir-replace-weapons-icons = partially`
  - optional `icon-visibility-esir-add-fuel-overlay = inserter|all`
  - optional `icon-visibility-esir-add-isotope-overlay = overlay-nuclear`
- Primary rule families:
  - `esir-21*`
  - `esir-22*`
  - selected `esir-23*`
- House interpretation:
  - prefer overlays, corner markers, and small recipe disambiguators
  - avoid treating broad background replacement as the baseline

### `icons-full`

Use when the goal is to mirror the companion mod's full readability grammar for recipes, items, and combat where ESIR already has art support.

- Companion settings:
  - `icon-visibility-esir-replace-facilities-icons = standard`
  - `icon-visibility-esir-replace-items-icons = standard`
  - `icon-visibility-esir-replace-weapons-icons = all`
  - `icon-visibility-esir-add-fuel-overlay = all`
  - `icon-visibility-esir-add-isotope-overlay = overlay-nuclear|both-all`
  - optional `icon-visibility-esir-add-backgroud = true`
- Primary rule families:
  - `esir-21*`
  - `esir-22*`
  - `esir-23*`
  - `esir-24*`
  - `esir-25*`
- House interpretation:
  - allow dummy isotope boards and broader family treatment
  - still prefer exact provenance notes over implicit "full parity" claims

## Sorting Presets

### `sort-core`

Use when the user wants cleaner subgroup and order behavior without recreating every centralization variant.

- Companion settings:
  - `icon-visibility-esir-enable-sorting-facilities = default|separated`
  - `icon-visibility-esir-enable-sorting-items = non-data`
  - `icon-visibility-esir-enable-sorting-weapons = handheld-first|turret-first`
- Primary rule families:
  - `esir-30a`
  - `esir-31a`
  - selected `esir-31b`
  - `esir-32*`
  - `esir-33a`
  - `esir-33c`
  - `esir-34a`
- House interpretation:
  - keep the main taxonomy readable
  - avoid assuming the most aggressive facility centralization is desirable

### `sort-expanded`

Use when the user explicitly wants companion-style subgroup reshaping and deeper combat or facility centralization.

- Companion settings:
  - `icon-visibility-esir-enable-sorting-facilities = intensive`
  - `icon-visibility-esir-enable-sorting-items = full`
  - `icon-visibility-esir-enable-sorting-weapons = by-ammo`
- Primary rule families:
  - `esir-30a`
  - `esir-31a`
  - `esir-31e`
  - full `esir-32*`
  - `esir-33a`
  - `esir-33b`
  - `esir-34a`
- House interpretation:
  - stronger subgroup reshaping
  - combat ordering by ammo family instead of by platform type

## Visibility Presets

### `hide-min`

Use when the user wants only the most obvious cleanup and duplicate suppression.

- Companion setting:
  - `icon-visibility-esir-enable-hiding = minimum`
- Primary rule families:
  - `esir-40a`
  - `esir-41a`
- House interpretation:
  - hide the things the companion mod always treats as clutter
  - keep uncertain recipes visible until proven redundant

### `hide-std`

Use when the user wants the companion mod's default visibility posture.

- Companion setting:
  - `icon-visibility-esir-enable-hiding = standard`
- Primary rule families:
  - `esir-40a`
  - `esir-41a`
  - `esir-41b`
  - `esir-41c`
- House interpretation:
  - minimum cleanup plus removed, unimplemented, and standard clutter buckets
  - this is the best general baseline for before/after review

### `hide-extra`

Use when the user explicitly wants the broader suppression set.

- Companion setting:
  - `icon-visibility-esir-enable-hiding = extra`
- Primary rule families:
  - `esir-40a`
  - `esir-41a`
  - `esir-41b`
  - `esir-41c`
  - `esir-41d`
  - `esir-41e`
- House interpretation:
  - include metalworks and vanilla fusion cleanup buckets
  - require clearer review notes because this preset changes visibility more aggressively

## Signal And Purge Presets

### `signals-clean`

Use when same-name recipe signals should be hidden after icon replacement has made the product identity obvious.

- Companion setting:
  - `icon-visibility-esir-hide-signals = true`
- Primary rule family:
  - `esir-42a`
- Important dependency:
  - this pass only makes sense after icon replacement settles the final recipe icon state

### `purge-nonbasic`

Use when non-recipe items or fluids should be moved into purged buckets for cleanup-oriented browsing.

- Companion setting:
  - `icon-visibility-esir-enable-purging = true`
- Primary rule family:
  - `esir-43a`
- House interpretation:
  - treat this as a strong review choice, not a silent default

## Mapping Notes

- A single manifest entry may carry more than one preset tag. For example, a recipe can be `icons-lite`, `sort-core`, and `signals-clean` at the same time.
- The skill should report the ESIR-first preset tags first, then include the underlying companion setting or rule-family evidence in notes.
- When a companion feature exists but does not fit any preset cleanly, tag it `needs-rule-design` in the baseline diff instead of forcing it into the nearest preset.
