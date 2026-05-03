# Runtime GUI Patterns

Use these patterns as the ESIR house baseline. They are references, not copy-paste templates; keep local module behavior intact.

## Surface Decision

- `player.gui.relative`: entity-adjacent machine, chest, combinator, turret, or energy-interface console. Anchor to the matching vanilla GUI type and default to `defines.relative_gui_position.right`.
- `player.gui.screen`: modal confirm, intentionally detachable window, proxy/core dashboard, camera-heavy view, or explicit fallback when relative anchoring is unavailable.
- `mod_gui` and `player.gui.left`: persistent mod-level entry buttons or side panels not bound to a single opened entity.

## Relative Entity Console

Expected shape:

```lua
local GUI_NAME = "ei-example-console"

local function build_gui(player, entity)
    local old_root = player.gui.relative[GUI_NAME]
    if old_root then old_root.destroy() end

    local root = player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        direction = "vertical",
        anchor = {
            gui = defines.relative_gui_type.assembling_machine_gui,
            name = entity.name,
            position = defines.relative_gui_position.right
        },
        tags = {parent_gui = GUI_NAME, unit_number = entity.unit_number}
    }

    local titlebar = root.add{type = "flow", direction = "horizontal"}
    titlebar.add{type = "label", caption = {"exotic-industries.example-gui-title"}, style = "frame_title"}
    titlebar.add{type = "empty-widget", style = "ei_titlebar_nondraggable_spacer", ignored_by_interaction = true}
    titlebar.add{type = "sprite-button", sprite = "virtual-signal/informatron", style = "frame_action_button", tags = {parent_gui = GUI_NAME, action = "goto-informatron"}}

    local body = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}
    body.add{type = "frame", style = "ei_subheader_frame"}.add{type = "label", caption = {"exotic-industries.example-status-title"}, style = "subheader_caption_label"}
    local flow = body.add{type = "flow", name = "status-flow", direction = "vertical", style = "ei_inner_content_flow"}
    flow.add{type = "label", name = "state-label", caption = ""}

    return root
end
```

Use the nearest existing module as the real pattern:

- `fusion-reactor.lua`: clean relative console with control widgets and refresh/mutation separation.
- `black-hole.lua`: container-adjacent relative console with tag-driven titlebar actions.
- `orbital-combinator.lua`: relative-only combinator console with clear teardown.
- `gate.lua`: relative container console with more complex state and selection controls.
- `railgun-cooling.lua`: turret anchor example.

## Screen Windows

Use screen windows when the panel is not simply attached to one opened entity. Make the reason visible in code shape:

- Modal confirm: close on explicit button or GUI closed event.
- Detachable window: use a draggable spacer, remember location if the module already stores per-player GUI state, and include a close action.
- Fallback: record `gui_mode = "screen"` or equivalent in tags/state so refresh code does not confuse it with a relative root.

Canonical examples:

- `alien-system.lua`: screen confirm/informatron flow.
- `induction-matrix.lua`: screen exception for a proxy/core/camera-style system.
- `orbital-logistics.lua`: relative-first plus explicit screen fallback.
- `crystal-accumulator.lua`: advanced relative plus detachable screen flow.

## Persistent Mod Controls

Use `mod_gui.get_button_flow(player)` for a persistent entry button and `player.gui.left` or `mod_gui.get_frame_flow(player)` for persistent side/status panels. These should not represent one opened entity console.

Canonical example:

- `em-trains/gui.lua`: persistent mod button with a left-side panel.

## Style Vocabulary

- Titlebar: `frame_title`, `frame_action_button`, `ei_titlebar_nondraggable_spacer`, `ei_titlebar_draggable_spacer`.
- Containers: `inside_shallow_frame`, `ei_subheader_frame`, `ei_subheader_frame_with_top_border`.
- Content: `ei_inner_content_flow`, `ei_inner_content_flow_horizontal`, centered variants when the content is intentionally visual.
- Meters: `ei_status_progressbar`, `ei_status_progressbar_cyan`, `ei_status_progressbar_grey`, `ei_status_progressbar_purple`, `ei_status_progressbar_red`.
- Controls: `ei_relative_gui_slider`, `ei_slot_button_radio`, `ei_green_button`, `ei_button`, `ei_small_button`, `ei_small_green_button`, `ei_small_red_button`.

## Event Routing

`control.lua` dispatches clicks, values, text changes, and selection changes through `event.element.tags.parent_gui`. New GUI modules should:

- Assign `parent_gui` on every interactive child.
- Keep `action` names explicit and module-local.
- Guard `event`, `event.element`, `event.element.valid`, and tags in module handlers.
- Route GUI mutation through update helpers instead of duplicating label/progressbar writes in click handlers.
