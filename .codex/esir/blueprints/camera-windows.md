<a id="contract"></a>
# Shared camera windows

## Implementation sources

- [camera-window.lua](../../../exotic-space-industries-remembrance/lib/camera-window.lua)

## Public interface

`ei_lib.camera_window` exports the shared owner; convenience functions are
`camera_open(player, options, tick)`, `camera_close(viewer_index, owner, id)` and
`camera_close_owner(owner, viewer_index?)`. Options select a player, entity or
fixed surface/position, caller namespace, stable window id, title and zoom.
Access control belongs to the caller: administration uses the `admin` namespace
and closes only its own windows when access is revoked.

## Storage and scheduling

`storage.ei_camera_windows` persists window/viewer/target indexes, object-destruction
registrations and delayed fallback updates. Native camera entity attachment
handles moving physical players and entities. Remote/god views without a usable
entity schedule updates only for an open visible window. Unchanged displayed
properties are not written. Close removes the session; stale due entries drain
without creating new work. Player lifecycle and object destruction events
invalidate only matching cameras.

## Lifecycle and presentation

Windows use a native movable screen frame with zoom and close controls, bounded
by display resolution and GUI scale. Each viewer may open up to four windows.
Player tracking can follow physical location or the player's current view.
Disconnected/destroyed targets display an explicit unavailable state.
The library registers no events; control.lua forwards GUI, player, destruction
and due-work callbacks.

`on_display_changed(event)` handles native resolution and UI-scale changes for
the matching viewer. It resizes and clamps existing frames and camera elements
without replacing them, preserving native attachment and zoom. Width and height
both constrain the window; this adds no periodic display work.

Friend Cam 0.1.0 (MIT) was reviewed as a reference for window composition and
zoom interaction. Its source was downloaded from the Factorio Mod Portal with
user authorization; this implementation independently uses ESIR's scheduler,
persistent ownership and native entity attachment.

## Verification

Check physical and remote player following, entity death, cross-surface movement,
disconnect/reconnect, independent namespaces, zoom bounds, scale changes and
closed-window zero display work in Factorio 2.0.77.
