---
name: esir-runtime-gui
description: "Create, review, and standardize ESIR runtime GUI code. Use when Codex adds or refactors Factorio runtime GUI panels in `exotic-space-industries-remembrance/scripts/control`, chooses between `player.gui.relative`, `player.gui.screen`, `mod_gui`, or `player.gui.left`, audits GUI anchors, root names, `tags.parent_gui` routing, stale-root teardown, entity revalidation, close/update lifecycle, or brings older ESIR GUI modules into the house style."
---

# ESIR Runtime GUI

Use this skill before adding or refactoring ESIR runtime GUI. Keep it focused on GUI surface choice, layout vocabulary, event routing, and migration hygiene; use `esir-dev`, `factorio-lua-assumptions`, and `esir-lib-first` for broader runtime, Factorio Lua, or helper-surface decisions.

## Default Workflow

1. Classify the GUI surface:
   - Use `player.gui.relative` for entity-adjacent consoles opened beside a vanilla entity GUI.
   - Use `player.gui.screen` for modal confirms, intentionally detachable windows, proxy/core dashboards, or explicit fallback when a relative anchor is unsuitable.
   - Use `mod_gui` plus `player.gui.left` only for persistent mod-level buttons, status panels, or workflows not tied to one opened entity.
2. Match the existing ESIR style vocabulary before inventing controls:
   - Root frame with a stable `GUI_NAME` or equivalent root constant.
   - Titlebar with `frame_title`, `ei_titlebar_nondraggable_spacer` for relative panels, `ei_titlebar_draggable_spacer` for movable screen panels, and `frame_action_button` for close or informatron actions.
   - Body frame using `inside_shallow_frame`, section headers using `ei_subheader_frame` or `ei_subheader_frame_with_top_border`, and content flows using `ei_inner_content_flow` or its horizontal/centered variants.
3. Route events through tags:
   - Give interactive elements `tags = {parent_gui = GUI_NAME, action = "...", ...}`.
   - Carry entity/session identity in tags when rebuilds or screen fallbacks can outlive `player.opened`.
   - Keep `control.lua` as the dispatcher; module handlers should guard `event.element.valid` and `tags.parent_gui`.
4. Split lifecycle helpers:
   - Separate build/open, update/refresh, and close/destroy paths.
   - Destroy stale roots before rebuild and when the opened entity changes, closes, or becomes invalid.
   - Revalidate the target entity with `ei_lib.get_valid_entity` or `ei_lib.entity_check` before every runtime read or mutation.
5. Run the read-only audit when standardizing older GUI code:

```powershell
python .codex/skills/esir-runtime-gui/scripts/gui_pattern_audit.py --repo-root . --format markdown
python .codex/skills/esir-runtime-gui/scripts/gui_pattern_audit.py --repo-root . --module exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua --format json
```

## Read Next

- [references/runtime-gui-patterns.md](./references/runtime-gui-patterns.md): canonical ESIR GUI construction patterns and style names.
- [references/gui-standardization-checklist.md](./references/gui-standardization-checklist.md): migration checklist and older module callouts.
- [references/agent-options.md](./references/agent-options.md): read-only sidecar prompts and forward-test prompts.

## Working Rules

- Prefer relative-only for simple entity consoles. Add screen fallback only when the workflow genuinely needs detachment, modal behavior, proxy/core context, or anchor failure handling.
- Treat hybrid GUI modules as advanced patterns, not starter templates. `orbital-logistics.lua`, `crystal-accumulator.lua`, and `neutron-collector.lua` are useful when fallback behavior is intentional.
- Use `tags` for intent and context; avoid parsing captions, names, or localized strings to decide behavior.
- Preserve old root names only when needed for compatibility cleanup. Mark legacy aliases as debt in the audit or migration notes rather than copying them into new panels.
- If this skill changes the house GUI pattern, update the cross-reference in `esir-dev` and any affected reference file in the same patch.

## Resources

- `scripts/gui_pattern_audit.py`: read-only static inventory of GUI surfaces, anchors, root names, tags, handlers, close/update paths, and likely standardization warnings.
- `references/runtime-gui-patterns.md`: surface-specific construction patterns.
- `references/gui-standardization-checklist.md`: retrofit checklist for legacy or mixed GUI modules.
- `references/agent-options.md`: prompts for sidecar exploration and skill forward-testing.
