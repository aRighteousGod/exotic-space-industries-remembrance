# Factorio2.0.77 undo boundary

Read from the installed-version official machine API cache `.factorio-lua-docs-cache/2.0.77/runtime-api.json` on2026-09-29.

- `on_undo_item_added` is absent from the complete events array.
- The undo/redo events are `on_undo_applied` and `on_redo_applied`. Both describe an action already triggered and provide its resulting `UndoRedoAction[]`; neither is a cancellable pre-action event.
- `LuaUndoRedoStack.get_undo_item(index)` and `get_redo_item(index)` expose the action arrays. `remove_undo_action(item_index,action_index)` and its redo equivalent can selectively remove an action.
- Entity actions provide a `BlueprintEntity` specification, generally name/position/quality plus **optional** `surface_index`. They do not expose a LuaEntity handle or unit_number. `BlueprintEntity.entity_number` is explicitly the entity identifier within a blueprint, not a live unit number.
- Wire actions provide two `BlueprintWireEnd` values with a blueprint entity specification and **optional** surface index.

Resolving a supplied surface/name/position against the current world can screen a subset of existing actions. It cannot establish a unique current target for every action whose surface is absent, nor preserve original object identity across movement/replacement. More critically, there is no event at which every newly added native history action can be screened before its first use; after-enable ownership edits can invalidate prior screening.

A bounded selective initial cleanup would reduce exposure for resolvable existing targets. It must be presented as partial coverage. It is not a complete replacement for permission denial, and permanently denying all undo/redo would violate the requested natural/own-entity scope. The restriction draft therefore gates undo/redo only during initial attribution and states historical undo as an unprotected native path.

Official references:

- https://lua-api.factorio.com/2.0.77/classes/LuaUndoRedoStack.html
- https://lua-api.factorio.com/2.0.77/concepts/UndoRedoAction.html
- https://lua-api.factorio.com/2.0.77/concepts/BlueprintWireEnd.html
- https://lua-api.factorio.com/2.0.77/events.html#on_undo_applied
- https://lua-api.factorio.com/2.0.77/events.html#on_redo_applied
