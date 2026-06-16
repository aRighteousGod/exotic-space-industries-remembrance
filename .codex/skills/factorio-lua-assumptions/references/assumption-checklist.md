# Factorio Lua Assumption Checklist

Use this checklist before importing a generic Lua pattern into Factorio mod code.

## Source Order

1. Official Factorio Lua API and auxiliary docs.
2. Official Factorio wiki scripting pages.
3. Lua 5.2 manual for baseline language behavior.
4. ESIR local conventions after Factorio behavior is clear.

The Lua baseline was rechecked against the official Factorio 2.0.77 Libraries and functions page: Factorio still documents Lua 5.2.1 plus Factorio-specific deterministic changes and additions.

## High-Risk Deltas

- Factorio is based on Lua 5.2.1, with Factorio-specific additions and deterministic changes. Do not assume Lua 5.1, LuaJIT, or Lua 5.4 behavior unless Factorio documents it.
- Startup/prototype stages and runtime/control stage are separate worlds. Startup stages share a Lua state while building prototypes; runtime gets a separate per-mod Lua state while a map is being played.
- `data.raw` and `data:extend()` are startup/prototype-stage concepts. Runtime code reads prototypes through runtime APIs such as `prototypes`, and mutable recipe/technology state is force-specific.
- Plain locals, globals, and module upvalues are not persisted. Persist mutable runtime state in `storage`.
- `storage` is not restored during top-level `control.lua` execution and must not be written in `on_load`. Use `on_init`, migrations, and `on_configuration_changed` for persistent-state setup and repair.
- Do not store functions in `storage`. If persisted tables need metatables, register them with `script.register_metatable`.
- Factorio allows storing many `LuaObject` references in `storage`, but they are live engine references. Recheck `.valid` after possible world-state changes, and prefer stable ids such as `unit_number` for durable indexing.
- `LuaCustomTable` is table-like, not a plain table. Iterate with `pairs()` and do not store it in `storage`.
- Standard Lua facilities are restricted. Do not assume `io`, `os`, `coroutine`, `dofile`, or `loadfile` exist. Factorio provides its own `package` behavior and a limited `debug` surface.
- Factorio `require()` is not normal package search. Absolute paths start at the mod root, `..` is disabled, core `lualib` modules can be required directly, and other mods use `__mod-name__.file`.
- Do not call `require()` from event listeners, console commands, or `remote.call()`. Load modules at file load time and route through existing dispatchers.
- `pairs()` and `next()` are deterministic in Factorio. Do not rewrite working Factorio code purely because generic Lua table order is unspecified.
- `math.random()` is deterministic in Factorio and `math.randomseed()` is a no-op. Use `game.create_random_generator()` or `LuaRandomGenerator` when independent seeded random streams are needed.
- Runtime work is lifecycle/event driven. Use `script.on_init`, `script.on_load`, `script.on_configuration_changed`, migrations, event registration, and `remote.add_interface()` instead of assuming a normal long-running Lua main loop.

## ESIR-Specific Overlay

- Before adding a shared-looking helper, inspect `exotic-space-industries-remembrance/lib/lib.lua` and prefer `ei_lib`.
- Before adding runtime queue, delayed bucket, tick, or telemetry plumbing, inspect `exotic-space-industries-remembrance/lib/runtime-scheduler.lua`.
- Inside event callbacks, prefer `event.tick` and pass it down call chains instead of reading `game.tick` again.
- Keep `control.lua` as the top-level dispatcher. Feature modules may own local state and cadence, but should not grow parallel top-level scheduling surfaces.

## Official Source Pointers

- Factorio Libraries and functions: `https://lua-api.factorio.com/latest/auxiliary/libraries.html`
- Factorio Data lifecycle: `https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html`
- Factorio Storage: `https://lua-api.factorio.com/latest/auxiliary/storage.html`
- Factorio Mod structure: `https://lua-api.factorio.com/latest/auxiliary/mod-structure.html`
- Factorio LuaBootstrap: `https://lua-api.factorio.com/latest/classes/LuaBootstrap.html`
- Factorio LuaRemote: `https://lua-api.factorio.com/latest/classes/LuaRemote.html`
- Factorio LuaRandomGenerator: `https://lua-api.factorio.com/latest/classes/LuaRandomGenerator.html`
- Factorio data.raw wiki: `https://wiki.factorio.com/Data.raw`
- Lua 5.2 manual: `https://www.lua.org/manual/5.2/manual.html`
