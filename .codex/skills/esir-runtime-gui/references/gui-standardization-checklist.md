# GUI Standardization Checklist

Use this when bringing an older ESIR GUI into the current runtime style.

## First Pass

- Identify the GUI surface: relative, screen, left, center, `mod_gui`, or hybrid.
- List root names and confirm there is one stable primary `GUI_NAME` per panel.
- Match every interactive element to `tags.parent_gui` and an explicit `action`.
- Find the dispatcher path in `control.lua` and confirm the module exports the required handler.
- Check for separate build/open, update/refresh, and close/destroy helpers.
- Confirm stale roots are destroyed before rebuild and on GUI close, entity close, entity destruction, or player leave when relevant.
- Confirm entity reads and writes revalidate the entity before use, especially after stored tags, unit numbers, or screen fallback state.

## Layout Pass

- Move loose root children into an `inside_shallow_frame` body unless the module has a strong vanilla-style reason not to.
- Use `ei_subheader_frame` for the first section and `ei_subheader_frame_with_top_border` for later sections.
- Use `ei_inner_content_flow` variants for section bodies.
- Use titlebar spacers consistently: nondraggable for relative panels, draggable for movable screen panels.
- Prefer existing progressbar, slider, slot-button, and button styles from `prototypes/styles.lua`.

## Surface Corrections

- Convert screen-only entity consoles to `player.gui.relative` when the panel is simply extending the opened entity GUI.
- Keep `player.gui.screen` when the panel is modal, detached, camera-heavy, proxy/core-driven, or intentionally survives outside the entity window.
- Keep `mod_gui` only for persistent mod-level controls or status strips.
- When relative and screen roots coexist, make the mode explicit in tags or per-player state and centralize root lookup.

## Known Module Callouts

- `induction-matrix.lua`: screen-only entity-opened console. Treat as an intentional screen exception because it resolves proxy/core state and includes camera/dashboard behavior.
- `crystal-accumulator.lua`: advanced hybrid with relative console, detachable screen, and legacy/suppressed strip paths. Use for fallback design, not for a simple starter pattern.
- `neutron-collector.lua`: relative-first with screen fallback. Keep fallback explicit and verify stale session cleanup.
- `railgun-cooling.lua`: correct relative turret anchor, but compact one-line construction is less readable than house style when touched.
- `fueler/fueler.lua`: relative console with legacy typo-root cleanup (`ei_fueler-console`). Preserve compatibility only as cleanup debt, not as a pattern.
- `em-trains/gui.lua`: valid persistent `mod_gui` case; older tag names should be normalized if the panel is refactored.

## Audit Script Hints

Run the read-only scanner before and after a migration:

```powershell
python .codex/skills/esir-runtime-gui/scripts/gui_pattern_audit.py --repo-root . --format markdown
python .codex/skills/esir-runtime-gui/scripts/gui_pattern_audit.py --repo-root . --module exotic-space-industries-remembrance/scripts/control/railgun-cooling.lua --format markdown
```

The script reports likely issues, not final truth. Use the module behavior and Factorio GUI lifecycle as the authority when a warning is about an intentional exception.
