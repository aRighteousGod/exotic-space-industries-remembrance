# Meld

`meld` is Factorio core's in-place recursive table patch helper. It is most useful in data/prototype code when an existing prototype or shared prototype fragment should receive a partial nested update.

## Import

```lua
local meld = require("__core__.lualib.meld")
```

Short-form `require("meld")` is common in vanilla prototype files, but explicit core paths are clearer in ESIR guidance and compatibility patches.

## Semantics

- `meld(target, source)` mutates `target` and returns the same `target`.
- Non-table values from `source` replace `target[k]`.
- Table values recursively merge into `target[k]` when `target[k]` is also a table.
- Table values are deep-copied into `target` when the destination is absent or not a table.
- Control markers allow delete, replace, transform, and append behavior that normal recursive merge cannot express.

## Control Markers

```lua
local patch = {
  flags = meld.append({"not-in-kill-statistics"}),
  obsolete_field = meld.delete(),
  nested = meld.overwrite({exact = "replacement"}),
  localised_description = meld.invoke(function(old)
    return old or {"entity-description.fallback"}
  end)
}

meld(data.raw["container"]["steel-chest"], patch)
```

- `meld.delete()` sets the target key to `nil`.
- `meld.overwrite(new)` deep-copies `new` into the target key instead of recursively merging it.
- `meld.invoke(fn)` replaces the target key with `fn(target[k])`.
- `meld.append(list)` ensures the target key is a table, then deep-copies each entry from `list` with `table.insert`.

Use `meld.append` with array-like lists. Do not rely on stable ordering for map-like tables passed to `append`.

## Choose The Right Tool

- Use `meld` for readable in-place prototype patches, especially nested tables, repeated patch shapes, or append/delete operations.
- Use `util.merge{a, b, c}` when the result should be a new table and the inputs should not be mutated.
- Use direct assignment for small obvious scalar changes.
- Use `ei_lib` when the change is ESIR policy or an existing ESIR helper already owns the behavior.

## Caveats

- `meld` is not a storage migration helper. Do not put control markers or functions from `meld.invoke` into `storage`.
- `meld` reuses the destination table. If another value intentionally aliases the same table, it observes the mutation.
- `meld.delete()` is the intentional way to remove keys; plain `nil` values are not representable inside a Lua table patch.
- Validate exact behavior against the installed `data/core/lualib/meld.lua` when upgrading Factorio.
