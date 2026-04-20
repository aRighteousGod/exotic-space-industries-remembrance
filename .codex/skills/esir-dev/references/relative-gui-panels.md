# Relative GUI Panels

Use this reference when adding or refactoring ESIR runtime GUI in `scripts/control`.

## Default split

- Prefer `player.gui.relative` for entity-adjacent consoles that should open beside a machine, combinator, chest, or other vanilla entity window.
- Use `player.gui.screen` for modal confirms, detached windows, or explicit fallback behavior when a relative anchor is unavailable or unsuitable.
- Use `mod_gui` for persistent mod-level controls, status panels, or entry buttons that are not tied to one opened entity.

## House pattern for relative panels

- Give the root a stable `GUI_NAME` or literal root name and destroy an existing root before rebuild.
- Anchor against the matching `defines.relative_gui_type.*` for the entity you are extending and prefer `defines.relative_gui_position.right`.
- Build a titlebar plus `inside_shallow_frame` body instead of mixing controls directly into the root.
- Use `tags` for intent and context. Prefer explicit `action`, `parent_gui`, and entity identity fields over parsing captions or names back out of the UI.
- Keep build, refresh, and close paths separate. A module should be able to rebuild cleanly when the root is missing, stale, or mode-switched.
- Revalidate the target entity before every runtime read or write. A surviving GUI root does not mean the bound entity is still valid.
- Close the panel when the opened entity changes, the bound entity is destroyed, or `on_gui_closed` says the surface is gone.

## Canonical examples

### `player.gui.relative`

- [`exotic-space-industries-remembrance/scripts/control/black-hole.lua`](../../../exotic-space-industries-remembrance/scripts/control/black-hole.lua): container-adjacent console with a straightforward relative build, tag-driven titlebar actions, and a good stale-entity close path in `update_player_guis`.
- [`exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua`](../../../exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua): assembling-machine relative console with a clean split between GUI refresh and entity mutation. Good reference for control widgets that feed back into recipe or mode changes.
- [`exotic-space-industries-remembrance/scripts/control/orbital-combinator.lua`](../../../exotic-space-industries-remembrance/scripts/control/orbital-combinator.lua): clean relative-only lifecycle with stable rebuild and teardown on GUI close or entity destruction. Use when the panel is truly an attached entity console and does not need a detached mode.
- [`exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua`](../../../exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua): advanced relative-first pattern with explicit screen fallback, stored GUI mode, preserved detached window position, centralized root lookup, and rebuild-tolerant refresh logic.

### `player.gui.screen`

- [`exotic-space-industries-remembrance/scripts/control/alien-system.lua`](../../../exotic-space-industries-remembrance/scripts/control/alien-system.lua): confirm and informatron-oriented flow that belongs on the screen layer rather than as an entity-adjacent side panel.

### `mod_gui`

- [`exotic-space-industries-remembrance/scripts/control/em-trains/gui.lua`](../../../exotic-space-industries-remembrance/scripts/control/em-trains/gui.lua): persistent mod button and left-side panel. Use this shape for long-lived mod controls, not for one-entity consoles.

## Anchor guidance

- `black-hole.lua` uses `defines.relative_gui_type.container_gui` because the console attaches to a container-style entity.
- `fusion-reactor.lua` uses `defines.relative_gui_type.assembling_machine_gui` because it extends an assembling-machine style window.
- `orbital-combinator.lua` and `orbital-logistics.lua` use `defines.relative_gui_type.constant_combinator_gui` because they extend combinator consoles.

Match the anchor to the vanilla GUI family the player already opened. If the chosen anchor can fail in practice or the workflow has a detached mode, follow the orbital-logistics pattern and make the fallback explicit.

## What to avoid

- Do not default to `player.gui.screen` for an entity console just because it feels easier to build.
- Do not assume a cached root or cached entity is still valid after rebuild, close, or entity destruction.
- Do not hide behavior in caption parsing when `tags` can carry the action and context directly.
- Do not add a detached fallback unless the workflow genuinely benefits from one. Relative-only is cleaner when the panel is always tied to the opened entity.

## Agent hint

When a GUI patch needs fast pattern mining, spawn a `gui-pattern explorer` to compare the target module against the canonical examples above and summarize which surface, anchor, and lifecycle match the new work best.
