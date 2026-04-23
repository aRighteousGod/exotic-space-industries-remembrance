# Local Companion Baseline

This skill uses the locally installed `recipe-icons-improvement-for-esir` mod as the primary baseline, with the latest local zip or unpacked folder preferred over screenshots or memory.

Last observed local baseline during implementation: version `1.1.14`, dated `21. 04. 2026`.

## Icon Layer

Primary files:

- `settings.lua`
- `prototypes/0-config.lua`
- `prototypes/0-func-for-icon.lua`
- `prototypes/esir-21*`
- `prototypes/esir-22*`
- `prototypes/esir-23*`
- `prototypes/esir-24*`
- `prototypes/esir-25*`

Primary helper semantics:

- `try_get_single_icon`
- `try_get_single_icon_if`
- `pass_icon_if`
- `make_icon_outline`
- `make_corner_outline`
- `try_set_icons`
- `try_set_icons_if`
- `copy_item_icon_to_picture`

Baseline visual grammar:

- overlay-driven recipe differentiation
- isotope numerals and isotope boards
- fuel, vent, filter, and logistics markers
- recipe family markers for nuclear, petrochemical, alien, combat, and facility clusters
- optional background plates and white-board style icon backings

Important operational detail:

- `try_set_icons` resets recipe `hide_from_signal_gui = false` during icon replacement, so later signal cleanup must be judged against the replaced icon state rather than the original prototype state.

## Sorting Layer

Primary files:

- `prototypes/0-config.lua`
- `prototypes/0-func-for-sorting.lua`
- `prototypes/esir-30a-sorting-maingroup.lua`
- `prototypes/esir-31*`
- `prototypes/esir-32*`
- `prototypes/esir-33*`
- `prototypes/esir-34a-sorting-barrelings.lua`

Primary helper semantics:

- `try_get_full_order`
- `try_set_order`
- `try_set_subgroup`
- `try_set_full_order`
- `try_set_group`
- `try_set_main_product`

Baseline sorting behavior:

- facility sorting is distinct from item sorting and weapon sorting
- facility centralization has multiple levels, including stronger `31e` behavior
- combat sorting can switch between platform-type order and ammo-family order
- barrel ordering follows fluid ordering after broader sorting passes settle
- dummy isotope recipe boards are inserted after sorting and before hiding

## Behavior Layer

Primary files:

- `prototypes/0-func-for-sorting.lua`
- `prototypes/esir-40a-hiding-control-always.lua`
- `prototypes/esir-41a-hiding-minimum.lua`
- `prototypes/esir-41b-hiding-removed-and-unimplemented.lua`
- `prototypes/esir-41c-hiding-misc-for-standard.lua`
- `prototypes/esir-41d-hiding-metalworks.lua`
- `prototypes/esir-41e-hiding-vanilla-fusion-etc.lua`
- `prototypes/esir-42a-hiding-signals.lua`
- `prototypes/esir-43a-hiding-purge-non-recipe.lua`

Primary helper semantics:

- `try_hide_factoriopeida`
- `try_redirect_factoriopeida`
- `try_hide_player_crafting`
- `try_show_factoriopeida`
- `try_show_player_crafting`
- `try_show_dual`
- `try_hide_signal`
- `try_purge_item`
- `try_hide_all`

Baseline behavior surface:

- Factoriopedia hiding and redirection are separate operations
- restore helpers can re-show Factoriopedia, player crafting, or both after broader hide passes
- player-crafting visibility is a separate axis from Factoriopedia visibility
- signal cleanup has both an automatic same-name basic recipe heuristic and hardcoded exceptions
- purging is a deliberate cleanup layer that moves non-recipe items and fluids into dedicated purged buckets
- the Gate family is composite and touches multiple prototype types, not just one item

Critical loader dependency from `data-final-fixes.lua`:

1. icon pretreatment
2. recipe icon replacement
3. item icon replacement
4. sorting
5. dummy isotope recipes
6. hiding and redirect passes
7. signal hiding
8. purging

That order matters. Signal cleanup is only meaningful after icon replacement, and the companion mod explicitly documents that dependency in loader comments.

## Rejected Or Deferred Layer

Keep these visible, but do not treat them as default v1 behavior:

- the historical merging system is still present in comments and rejected by the current loader order
- backward-compatible setting quirks such as `icon-visibility-esir-add-backgroud`, legacy `full` handling for item icons, and the hidden `overlay-all` isotope path still exist in code
- some historical compatibility rules still appear in the companion source even when the current QC dump no longer shows those prototypes

The skill should report these edges honestly instead of pretending the companion mod is a perfectly tidy one-surface spec.
