# Administration tools

Enable **Enable administration tools** (`ei-admin-tools-enabled`) in startup
settings, restart the save, and use `/ei-admin` as an administrator. The setting
defaults off. Existing ESIR commands continue to work while it is off.

Opening the console or becoming an administrator does not enable cheat mode,
invulnerability, or native god mode. These remain off until explicitly enabled
for the selected player. The status readout reports the current mode separately
from the **Enable** and **Disable** actions.

`/ei-admin diagnostics` opens a page directly. Other page names are `planets`,
`chunks`, `players`, `moderation`, `creation`, `fluids`, `enemies`, `effects`,
`research`, `repairs`, and `cameras`. **Toggle launcher button** adds or removes
the administrator's persistent mod-gui shortcut; it is hidden initially.

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
