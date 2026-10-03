# Native admin world acceptance — 2026-09-29

Factorio **2.0.77 build 84539**, Windows headless server plus benchmark reload.
The isolated fixture completed **101 checks with no failures**. The saved real
player seed SHA-256 was
`C2A9A816858575A36E690B5BD82ACDBDC6EBD36120B08EE490DEC4BA31372CBF`.

| Area | Observed result |
| --- | --- |
| Creation scheduler | Saturated admitted jobs consumed exactly 25 creation attempts in one update. |
| Native chart ownership | Pending owned requests reached exactly 32. Cancellation retained submitted slots; native events released them. |
| Native terrain requests | Cancellation retained a submitted generation slot. The chunk completed after reload and its slot cleared. |
| Iterator persistence | An active LuaChunkIterator saved at tick 1696 restored valid at 1697 and completed the all-generated reveal. |
| Policy | Native no-enemies, peaceful, daytime/freeze and zero evolution applied. Expansion veto removed the new base on the selected surface. |
| Items and fluids | Real god inventory received items. Compatible additions preserved the existing temperature: water remained 95 degrees in both a tank and a native fluid wagon, and filtered hot steam remained 500 degrees. Incompatible fluid was rejected. |
| Resources and pollution | Radius 2 created 13 resource nodes with exact amounts. A subsequent overlapping patch skipped the existing deposit without changing its amount. Area pollution reached distinct selected chunks. |
| Enemy catalog and placement | A wave created four biters, two Gleba pentapods and one demolisher. The six commandable units shared one native group with the requested attack-area command. Advanced mode admitted a hostile gun turret; default mode rejected it. Advanced catalog excluded internal segments and dummy spider. |
| Rectangle admission | A 64 by 64 square and 128 by 32 rectangle each admitted exactly 4,096 chunks; 65 by 64 was rejected. |
| Target identity | An invalid explicit force was rejected. When a real destroy callback transferred another batch member to the player force, the transferred entity survived. A queued clear cancelled when the selected force became friendly or gained a player, including friendship changed by a destroy callback inside the current batch. |
| Enemy removal | Force-scoped clear removed ordinary enemies, an advanced hostile turret and the native whole segmented unit. |
| Fire catalog | Hidden native fire prototypes remained available in the environmental fire picker. |
| Ruptures | A 20 MJ environmental rupture queued its first ring, used neutral attribution and standard ceilings despite unbounded configuration, and blocked a second active admin rupture. Admission rejected more than 512 native nearby targets with a specific reason before queuing. |
| Progress and auditing | Job progress exposed scalar totals/visits. Completion log records carried real actor index, force, surface, counts and status. |

Observed source snapshot SHA-256:

- World: `CD4A230DB92D7FE105EBAE8E90390AB6B691B8AA25F1DAA8820997A935CF7289`
- Rupture effects: `07D73C27F29A65E4BFE51B938984C8CE18D5F251C37DD9352C7577CAD4FC2662`

This run used the live shipping world/effects sources, including native wave
groups, compatible-fluid temperature preservation and skipping existing deposits.
The driver restages source for subsequent runs and records new hashes. Native
dispatcher saturation used synthetic admitted-job copies with a
real player, force and surface. Connected GUI behavior, many-player authorization,
full ESIR graphics and whole-factory performance are separate checks.

Evidence from the run lives in the ignored
`.factorio-qc/admin-world/server.log`, `reload.log`,
`source-hashes.json`, and `script-output/admin-world-results.json`.
