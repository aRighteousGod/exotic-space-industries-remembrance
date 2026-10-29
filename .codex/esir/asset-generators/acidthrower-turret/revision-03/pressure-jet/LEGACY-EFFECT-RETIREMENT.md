# Legacy acidthrower retirement / 2026-10-12

Trace actual attack/action/runtime consumers before retiring declarations. The
current turret reaches its pressure stream, wet corrosion sticker, landing
splash and cosmetic flecks. Its old create-fire action was commented out.

Retired disconnected definitions:

- Fires: `ei-acid-flame`, `ei-fire-flame-small`, `ei-acid-flame-small`,
  `ei-acid-flame-on-tree`.
- Trivial smokes: `ei-acid-smoke`, `ei-acid-smoke-without-glow`,
  `ei-soft-acid-smoke`, `ei-acid-smoke-on-adding-fuel`.
- Unconnected streams: `ei-handheld-flamethrower-acid-stream` and
  `ei-tank-flamethrower-acid-stream`. No weapon, ammo, projectile, entity attack
  or production runtime handler consumes either.
- Their `acid-util.lua` builder and both require sites, dead smoke/fire helpers,
  unsupported sticker acid-spread fields and obsolete commented action edges.
- Graphics-3 `acid-flame-01.png` through `acid-flame-04.png`: 4,569,077 bytes.
  The three superseded original gun sheets add another 3,146,172 bytes.

Keep `spark.png`: current exotic-magazine and rocket effects directly consume
it, with 13 sticker owners in the inspected complete native dump. Retain
`ei-poison-sticker`, the optional corrosive-toxic rocket fallback. Current
turret stream/sticker identities and late profile aliases remain intact.

The 2026-10-28 graphics cleanup relocated that unchanged shared sprite to
Graphics-3 `graphics/effects/stickers/spark.png` and removed the now-empty
`graphics/entities/acid-turret/acid-flame` directory. Its consumers remain active.

Evidence before editing: current production Lua and dynamic selectors;
complete Oct-10 Factorio 2.0.77 final data (2,047,593,299 bytes); 3,430 active
external archive Lua members; and the 39-enabled-mod QC seed (26 external
archives, 301 Lua members). No external references to the retired names or
flame sheets were found. Installed StickerPrototype documentation supports
fire-spread fields, not the old acid-spread fields; the old target was also
misspelled. Ecology uses its own or vanilla tree fire.

The administrator's generic Advanced Fire catalogue could manually create any
fire. Retirement removes these old choices and drops manually created transient
instances on reload. Ordinary production gameplay has no incoming edge.

QC asserts all ten definitions are absent from fresh resolved data. Historical
green-flame comparison art is frozen inside the test helper only, recovered from
Git history outside shipping; it is not a reason to keep dead production assets.
The exact scoped candidate is exported and tested separately from the mixed
working tree before GitHub delivery. Current graphics and payload are compared
to the approved dispersion snapshot, with only obsolete ignored fields excluded.
