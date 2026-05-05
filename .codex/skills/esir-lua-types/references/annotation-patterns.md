# Annotation Patterns

Use these as compact examples, not templates to paste everywhere. Favor the smallest annotation that materially improves completion, hover text, or diagnostics.

## Runtime State Tables

```lua
---@class AuricVatState
---@field entity LuaEntity
---@field unit_number uint
---@field phase string
---@field due_tick uint|nil
---@field vigor number
---@field contamination number

---@type table<uint, AuricVatState>
local vats = storage.ei.auric_inoculation_vat.vats
```

Prefer unit numbers for identity. Stored `LuaEntity` values are still staleable; revalidate them before every later dereference.

## Module Exports

```lua
---@class AuricVatModule
---@field on_init fun()
---@field on_configuration_changed fun(event: ConfigurationChangedData)
---@field on_gui_click fun(event: EventData.on_gui_click)

---@type AuricVatModule
local model = {}
```

Use this when a module table is exported and dispatcher code or agents need reliable hover information.

## Option Tables

```lua
---@class AuricVatOpenOptions
---@field force_screen_fallback boolean|nil
---@field refresh_only boolean|nil
---@field reason string|nil

---@param player LuaPlayer
---@param entity LuaEntity
---@param options AuricVatOpenOptions|nil
local function open_console(player, entity, options)
    options = options or {}
end
```

Name option tables once they carry two or more meaningful fields, especially when the same table crosses helper boundaries.

## GUI Event Handlers

```lua
---@class AuricVatGuiTags
---@field parent_gui string
---@field action "open"|"close"|"refresh"|"cycle"
---@field unit_number uint|nil

---@param event EventData.on_gui_click
local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end

    ---@type AuricVatGuiTags|nil
    local tags = element.tags
end
```

Annotate event payloads and tag shapes at routing boundaries. Do not parse captions or localized strings for behavior.

## Scheduler Payloads

```lua
---@class AuricVatWakePayload
---@field unit_number uint
---@field reason "phase"|"ui"|"repair"
---@field due_tick uint

---@type AuricVatWakePayload
local payload = {unit_number = unit_number, reason = "phase", due_tick = tick}
```

Prefer typed records for queue payloads with mixed fields. If a queue stores LuaObjects, document that consumers must revalidate them on dequeue.

## Storage Roots

```lua
---@class AuricVatStorage
---@field vats table<uint, AuricVatState>
---@field pending_wakes table<uint, AuricVatWakePayload>
---@field gui_sessions table<uint, uint>

---@return AuricVatStorage
local function ensure_storage()
    storage.ei = storage.ei or {}
    storage.ei.auric_inoculation_vat = storage.ei.auric_inoculation_vat or {}
    return storage.ei.auric_inoculation_vat
end
```

Annotate the storage root when a module owns persistent records. This gives better editor signal than typing each local read separately.

## Prototype Tables

```lua
---@type data.AssemblingMachinePrototype
local vat_entity = {
    type = "assembling-machine",
    name = "ei-auric-inoculation-vat",
}

---@type data.RecipePrototype[]
local phase_recipes = {}

data:extend({vat_entity})
data:extend(phase_recipes)
```

Use `data.*` prototype types when known. If the exact prototype type is uncertain, prefer a broader known type or check official docs rather than inventing a name.

For mixed prototype arrays, use the narrowest honest union:

```lua
---@type (data.ItemPrototype|data.RecipePrototype|data.TechnologyPrototype)[]
local prototypes = {}
```

## LuaObject Validity

```lua
---@param entity LuaEntity|nil
---@return LuaEntity|nil
local function normalize_entity(entity)
    return ei_lib.get_valid_entity(entity)
end
```

LuaLS types describe intended shape, not runtime validity. ESIR runtime code still needs `ei_lib.entity_check`, `ei_lib.get_valid_entity`, or another local validity guard before reading LuaObject fields.

## Noisy Annotation Smells

- Annotating every local primitive in a short obvious function.
- Adding `any` where the existing code already makes the shape clear.
- Creating a `---@class` for a table used once with two obvious fields.
- Claiming a value is non-nil when the code still handles nil.
- Using a broad `table` annotation where a small named option or payload class would improve completion.
- Annotating around dead code instead of deleting or simplifying it when deletion is in scope.
