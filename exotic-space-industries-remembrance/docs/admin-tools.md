# Administration tools

**Enable administration tools** (`ei-admin-tools-enabled`) defaults on in startup
settings. Use `/ei-admin` as an administrator, or `/ei-admin map-settings` to open
the map editor directly. Existing saves retain an explicitly disabled setting;
enable it in startup settings and restart to use the menu. Existing ESIR commands
continue to work while it is off.

Opening the console or becoming an administrator does not enable cheat mode,
invulnerability, or native god mode. These remain off until explicitly enabled
for the selected player. The status readout reports the current mode separately
from the **Enable** and **Disable** actions.

`/ei-admin diagnostics` opens a page directly. Other page names are `planets`,
`chunks`, `players`, `moderation`, `creation`, `fluids`, `enemies`, `effects`,
`research`, `repairs`, `map-settings`, and `cameras`. **Toggle launcher button** adds or removes
the administrator's persistent mod-gui shortcut. It is shown by default while the
toolkit is enabled; an explicitly hidden shortcut stays hidden across reloads.
The toggle is highlighted while the shortcut is shown, matching the Ecology menu.
Hiding the shortcut leaves the open console usable.
Existing administrators with no saved preference also receive the shortcut.
The Overseer's Seal identifies the launcher and appears beside the window title.
In **Settings → Controls**, assign **Toggle administration menu** to open or close
the console, including while its launcher is hidden. This control is unbound by
default and uses the same administrator and startup-setting checks as the menu.
The native launcher remains 40 by 40 GUI units, with a 32-unit sprite; the title
emblem is 48 by 48. Both use the same transparent high-resolution artwork and
scale with the interface. Dragging the title emblem also moves the window.

The public **Ecology** window has its own **Toggle launcher button** control below
the title, available on every tab. Its pressed state means the launcher is shown;
hiding it leaves the current window open and saves your choice across reloads.
Assign **Toggle ecology menu** in **Settings → Controls** to reopen or close it
with the launcher hidden. This control also starts unbound and requires ecology
to be enabled. The 48-unit tree beside the title follows the viewed surface's
season even on Alerts or with the launcher hidden; unavailable calendars use the
summer tree. Each player's launcher preference is independent.

The target panel selects a player, force and planet. Opening the console does not
create planets. Travel creates the requested destination through its native owner,
including Gaia. Use **Pick location**, **Pick rectangle**, **Pick entity**, or
explicit coordinates to prepare a target. The picker restores the previous view
before executing an action. Clear its cursor to cancel.

The window centers on its first opening, then retains its dragged position through
refreshes, feedback, page changes and reopening. Resolution/scale changes clamp
the saved position only as necessary to keep the window inside the display.

**Auto-refresh: Off/On** is optional and initially off. Select an interval of
1, 2, 5, 10, 30 or 60 simulation seconds. It refreshes only the visible page and
changed readouts, retaining controls and drafts. Closing cancels its scheduled
work; reopening resumes an explicitly enabled preference. Toolkit shutdown or
loss of administrator access turns it off. The interval follows game speed.

| Navigation | Controls |
| --- | --- |
| Planets & Environment | Native peaceful/spawning settings, per-planet new-base policy, global expansion, evolution, daylight, enemy and pollution clearing. |
| Map Settings | Drafted per-surface generation controls and enemy families, future-planet overrides, global evolution/expansion/pollution and Space Age rules. |
| Chunks | Reveal, generate, both, or reveal currently generated terrain; cancellable bounded work. |
| Travel & Modes | Go/send to any planet, manual travel, future spawn destination, cheat mode, character invulnerability, native god controller, and interaction restrictions. |
| Moderation | Kick, ban/unban, administrator status, timed jail and release. |
| Items & Entities | Quality-aware item grants and collision-checked empty vehicles/buildings. |
| Fluids & Resources | Compatible native fluid insertion and non-destructive resource patches. |
| Enemy Spawner | Native prototype selection, custom mixtures and optional attack destination. |
| Fires, Ruptures & Pollution | Real damaging fires/ruptures and the surface's native pollutant. |
| Research & Speed | Force-specific research controls and global simulation speed. |
| Diagnostics | Read-only owner overview, details and bounded explicit inspection. |
| Runtime Repairs | Preservation-aware owner repairs; separately confirmed Gaia reforge and victory notification reset. |
| Cameras | Detached windows following a player, the player's view, or a selected entity. |

Destructive actions show the actual target before confirmation. Commands and
queued work check administrator access again at execution. Mutations are written
to the Factorio log with their actor and target. `/ei-admin-repair <module-id>`
and `/ei-admin-repair-<module-id>` invoke the same registered repair as its button;
the server console can use these commands. Existing aliases remain available.

## Map Settings

Use `/ei-admin map-settings`, select the intended planet, and choose **Selected
surface / planet** or **Global rules**. Generation controls affect future chunks;
family birth policies and global rules take effect immediately. Existing terrain,
creatures and pollution remain. Clearing them is a separate action.

Each administrator has a separate draft. Sliders and numeric fields stay in sync;
**Apply changes** validates the complete edit and reports the native read-back.
**Reload current values** and **Discard changes** replace the selected draft.
Navigation and refresh retain unapplied edits. If another administrator changes
the same field, Apply rejects the conflict; unrelated settings are preserved.
Generation values allow zero/Off or 1/6 through 6. Imported values outside that
range remain unchanged until edited. Enemy On restores remembered positive values;
unknown values use the planet default, including Gaia electric size 5.

For an uncreated planet, the displayed prototype defaults are references, not
claims about saved new-game selections. Check **Override** for each intended field.
Untouched fields inherit the actual native creation settings. Applying overrides
does not create the surface. Overrides survive save/reload, surface recreation,
Gaia fallback/reforge and disabling the administration toolkit.

**Advanced** exposes the generation seed and global technology-price multiplier.
Other controls cover applicable resources, terrain/cliffs, starting area, peaceful
mode, natural enemies, ESIR new-base policy, current evolution, global evolution,
expansion, pollution, asteroid rate and spoil time. Evolution is percent, expansion
cooldowns are game minutes, and terrain scale is inverse native frequency. Space
platforms and raw generation internals are outside this editor.

The twelve enemy rows are ordinary/Explosive/Cold/Arachnid/Toxic/Armoured on Nauvis,
Explosive/Demolishers on Vulcanus, Electric on Fulgora and Gaia, Pentapods on Gleba,
and Cold on Aquilo. Off blocks future generation and births on that surface.
Global no-enemies takes precedence; peaceful mode keeps its native meaning.
Explicit administrator summons remain available; their offspring follow policy.
Gleba Off retains ordinary egg rafts and eggs. On restores only rafts disabled and
recorded by this version. Existing disabled rafts remain untouched. The Armoured
row works only when Armoured Biters' separate nests startup option is enabled.
ESIR leaves that option selectable. With separate nests disabled, vanilla nests
can produce snappers and the ordinary enemy-base control governs those births;
the Armoured row has no effect. Changing nest mode never backfills existing chunks.
Population settings are separate from ESIR combat difficulty.

On Factorio 2.0.77, default enemy placement is unchanged. Adjusting a Nauvis
family's frequency or size away from 100% uses a stable family-specific placement
seed to keep neighboring sliders independent. Its nest positions can change;
returning both sliders to 100% restores the original placement in future chunks.
This engine workaround will be reviewed when ESIR moves to Factorio 2.1.

## Player modes and jail

Invulnerability preserves the character and equipment by owning its destructible
flag; it does not protect a vehicle. Native god mode parks the original protected
body. Returning transfers exact god-inventory stacks, spills overflow where safe,
and retains any failed remainder for recovery. It does not clone body inventory.

Jail preserves inventory, location, permissions and toolkit modes. Its **online
game time** clock pauses on disconnect; **elapsed game time** continues while the
simulation runs. Both follow game speed. The prisoner HUD shows the reason and
remaining sentence. Release uses a safe original location or the force spawn.
Administrators must be demoted before being kicked, banned or jailed. The menu
rejects self-moderation and self-demotion; jailed players must be released before
promotion. Native kick/ban controls are unavailable in single-player.

Interaction restrictions concern player-built entities and Factorio's **last
user**, which can change when a player edits settings. Natural resources, trees,
rocks and unattributed map/script entities remain usable. The first activation
performs a bounded attribution scan; area tools and undo/redo pause until it
finishes. Direct selected/entity-GUI interactions and tracked area orders are
guarded. This is not a complete multiplayer anti-grief boundary: indirect/AoE
damage, other mods, historical undo/redo and native edits without an immediate
event have limits. Use native server moderation for hostile players. The separate
runtime setting applies the restriction to future new players; existing players
are changed only explicitly.

## World work and shutdown

Chunk radius is 0–31; rectangles may contain up to 4,096 chunks. Reveal-only never
generates terrain. Submitted native requests can complete after cancellation.
The console shares limits across administrators: 25 ordinary creation attempts
per tick, one demolisher, 64 terrain visits, four chart submissions, 32 owned
pending charts and 16 owned pending generation requests. Generation submits at
most once per 30 ticks and times out after 3,600 ticks.

Resource patches skip existing deposits, trees, cliffs and blocked positions.
Fluid insertion preserves an existing fluid's temperature and respects native
capacity/filter constraints; automatic handling is available for special native
storage. These actions retain ESIR's ordinary fluid-safety consequences.
Enemy spawning by an administrator remains available when natural spawning is off.
Only one administration rupture can be pending at a time. Secondary fires can
spread beyond the displayed direct-damage radius.

**New planets start peaceful** affects only newly created planetary surfaces
while the toolkit is enabled. Explicit saved planet policies take precedence,
including after Gaia reforge. Existing planets are unchanged by this default.

Disabling the startup switch removes toolkit windows/cursors, stops automation
and future job submissions, releases jail sentences, and restores owned player
modes and the prior game speed. Offline restoration waits for the player. Completed
world edits, native planet settings, research, spawned entities, bans and granted
administrator status remain. Already-triggered world effects finish normally.

## Shared camera API

The reusable mechanism belongs to `ei_lib`, independently of the admin switch:

```lua
local window, error = ei_lib.camera_open(player, {
    owner = "my-feature",
    id = "subject",
    entity = entity,
    zoom = 0.5,
}, event.tick)

ei_lib.camera_close(player.index, "my-feature", "subject")
ei_lib.camera_close_owner("my-feature")
```

Use `player_index` instead of `entity` to follow a player, and `follow_view=true`
to follow that player's view. The caller owns access policy. Native entity
attachment follows movement without a Lua position loop; only visible cameras
that require a remote/god view fallback schedule position reads. The shared
dispatcher already routes camera lifecycle and display-size events. Closing one
owner's windows leaves other features' cameras intact.

## Rebuild activity

All players receive a top-left rebuild button whenever ESIR has queued or active reconstruction. It names the active modules and toggles a small draggable window. The window opens automatically after two simulation seconds; closing it suppresses automatic reopening for that activity episode. Position and dismissal survive saving. It leaves machine windows, the console, cursor and keyboard focus intact. This public monitor works with admin tools disabled.

Each row shows its module, phase, processed work, a progress bar when the total is known, and an approximate remaining duration in **game time**. Lower UPS increases real waiting time. Discovery and changing work may show “Estimating…” or “Discovering…”. An explicitly externally blocked job disappears from public activity until it resumes.

Diagnostics adds **Rebuild activity** and **Recent rebuilds**, filtered by the selected owner. These show the trigger, detailed scope, counts, elapsed game time, estimate or waiting reason, and the last 32 terminal results. Synchronous repair callbacks are identified explicitly because their blocking duration cannot be measured by simulation ticks. An accepted repair request is separate from completion of deferred reconstruction. Only the activity section refreshes automatically; the existing general auto-refresh preference and admin gates are preserved.

Reporting covers beacon topology, fumarole backfill, Tesla variants, EM research rollout and requested rail audit, spider refits, water fire-index seeds and ingestion, radar reconstruction, Gaia reforge, disabled flamethrower restoration and the attribution census. Ecology publishes at most four finite operations: migration, bootstrap, revalidation and maintenance. Its bootstrap fixes surface membership at admission and stops each traversal at iterator exhaustion or 100,000 yielded visits; reaching the limit does not certify full coverage. Ordinary ecology observations, recovery and mining requests remain in Ecology Advanced, alongside paused maintenance details. Ordinary charging, firefighting, radar scans, combat, placement maintenance, world-edit jobs and inspections remain outside this monitor. It adds no pause, cancel, restart, scheduling or CPU-profiling controls.
