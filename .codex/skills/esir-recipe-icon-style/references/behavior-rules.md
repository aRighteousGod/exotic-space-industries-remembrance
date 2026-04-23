# Behavior Rules

This skill does not just mirror icon composition. It also models the broader companion-mod behavior surface for sorting, visibility, and signal cleanup.

## Helper Baseline

Treat these helper functions from `prototypes/0-func-for-sorting.lua` and `prototypes/0-func-for-icon.lua` as the authoritative semantic names:

- `try_set_order`
- `try_set_subgroup`
- `try_set_full_order`
- `try_hide_factoriopeida`
- `try_redirect_factoriopeida`
- `try_hide_player_crafting`
- `try_show_factoriopeida`
- `try_show_player_crafting`
- `try_show_dual`
- `try_hide_signal`
- `try_purge_item`
- `try_set_icons`

When an audit entry references proposed behavior, use these names in notes instead of paraphrasing them loosely.

## Sorting Semantics

- `try_set_order` changes only prototype order.
- `try_set_subgroup` changes only subgroup when the subgroup exists.
- `try_set_full_order` is the normal "before and after" surface for review because it captures both subgroup and order together.
- Facility sorting, item sorting, and combat sorting are separate axes in the companion mod. Do not collapse them into one generic "sorted" label.

## Factoriopedia And Crafting Visibility

### `try_hide_factoriopeida`

- Marks the target as hidden in Factoriopedia.
- When the target is a recipe, it can also hide the signal entry depending on params or config state.

### `try_redirect_factoriopeida`

- Leaves the prototype present but redirects Factoriopedia to an alternative.
- When the target is a recipe, it can also hide the signal entry depending on params or config state.

### `try_hide_player_crafting`

- Hides the recipe from the player crafting menu.
- This is separate from Factoriopedia visibility and should be rendered as its own before or after field in reports.

### Restore helpers

- `try_show_factoriopeida` restores Factoriopedia visibility without necessarily changing player-crafting visibility.
- `try_show_player_crafting` restores the player-crafting entry without implying Factoriopedia visibility changes.
- `try_show_dual` restores both surfaces together and should be described that way in notes or review output.

## Signal Cleanup

### `try_hide_signal`

- Explicitly hides the recipe signal from the signal GUI.

### Same-name basic recipe heuristic

The companion mod also performs a more opinionated signal cleanup pass in `esir-42a-hiding-signals.lua`.

Best-effort baseline interpretation:

- focus on "basic" recipes
- compare the recipe name to the produced item or fluid name
- if the recipe icon matches the product icon, or the recipe never received a meaningful custom icon, the recipe signal is treated as redundant and hidden

Audit and report output should call this out as a heuristic, not a formal guarantee, unless the exact rule file has been inspected for the prototype family in question.

## Purging

### `try_purge_item`

- Used for non-recipe items or fluids that should be moved out of normal browsing flow
- moves fluids into `ivi-purged-fluids`
- moves other prototypes into `ivi-purged-items`
- preserves prior order information by converting the current full order into a stored order string first

Treat purging as a strong cleanup behavior. It should be visible in batch reports and never implied silently.

## Loader Dependency

Signal cleanup depends on icon replacement order.

Important sequence from `data-final-fixes.lua`:

1. icon pretreatment
2. recipe icon replacement
3. item icon replacement
4. sorting
5. dummy isotope recipe generation
6. hiding and redirect passes
7. signal hiding
8. purging

The key consequence is that signal cleanup runs after icon replacement. The companion helper `try_set_icons` also resets recipe `hide_from_signal_gui = false` when replacing recipe icons, so later signal cleanup must be evaluated against the final icon state instead of the original prototype definition.
