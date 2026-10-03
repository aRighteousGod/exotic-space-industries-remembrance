# Admin player native verification - 2026-09-29

Installed engine: Factorio 2.0.77 (build 84539, Steam win64, Space Age). All accepted runs loaded the isolated companion fixture with vanilla expansion mods and the actual admin player source/shared libraries. Shipping source was never edited by this sidecar.

Input connected-player seed: .factorio-qc/wtr/final-player/fixture.zip, 2,464,256 bytes, SHA-256 C2A9A816858575A36E690B5BD82ACDBDC6EBD36120B08EE490DEC4BA31372CBF. Benchmark membership was one genuinely connected LuaPlayer. Hidden-client save lanes produced ZIP-validated actual engine autosaves; server reloads asserted connected=false.

| Accepted run under .factorio-qc/admin-players | Recorded checkpoints | Result |
| --- | ---: | --- |
| native09 | 33 | Remote physical travel, exact god inventory round trip, full-inventory native spill, original property/body preservation, destroyed-body recovery, disabled cleanup, jail and spawn/respawn checks passed. |
| offline-online-load01 | 5 | Genuine saved online jail remained at 3569 ticks after 180 observed offline ticks, versus 3570 in the client save; only the engine's load/disconnect transition consumed one tick. |
| offline-elapsed-load01 | 5 | Genuine elapsed jail decreased from 3570 to 3389 ticks across the same offline interval plus transition. |
| offline-god-load02 | 9 | Explicit typed unknown-name ban overrode the saved-admin dropdown index; native unban passed; offline god inventory was accessible; exact tags and nested contents survived native offline-player removal in retained escrow. |

Each run's script-output/admin-player-qc.json contains ordered checkpoint details; result.log/stdout.txt preserve engine evidence. The final native09/offline-god-load02 player source SHA-256 is 4B230B69E945CBEB799405FDE7156EC64150B05A45115AD254D6C483F27D6C62. Other accepted source hashes are recorded in their manifests; they predate the independent ban-target correction.

The exact-stack checks preserve rare/epic quality, nested custom tags, cursor-held tags, armor equipment energy, blueprint contents/label, nested item inventories, exact spoil_tick and original equipped armor/body contents. The full-inventory case forces the normal bounded spill path and verifies the tagged stack on the ground.

Two implementation issues were exposed or confirmed:

1. native02 failed configuration-reschedules-pending-spawn: rebuilding due buckets discarded connected pending-spawn-only records. The small recovery patch schedules those existing records after configuration rebuild; native09 passes.
2. An explicit ban name could be replaced by the GUI's always-present player_index. The targeted correction gives a nonempty typed ban name precedence. offline-god-load02 proves the fix on a real server; unban was already name-first.

Native on-left events provided the online-jail save/load accounting fence. No speculative on_load scan or continuous player polling was added.

The all suite's deliberate leave/join hook pair checks timer arithmetic with controlled ticks. The separate genuine offline-server lanes establish native disconnected behavior. After native offline-player removal, the parked body's entity reference was invalid; the module retained exact unreturned god stacks in script escrow. This is preservation evidence, not a claim that the current menu exposes recovery for removed indices.

Validation bounds: this fixture does not load ESIR prototypes/dispatcher, assess menu visuals/mouse behavior, benchmark UPS, exercise a second human multiplayer client, or validate live kick/ban of real users. It uses an invented name for server moderation. Full ESIR integration remains the main agent's lane. Fixture Lua and driver PowerShell syntax also passed local parsing.

## Jail HUD and lifecycle follow-up

The original results above remain tied to their recorded source snapshots. The
following separate runs validate the later jail HUD, native walking permission,
independent character protection, permission/surface recovery and release fallback.
These functional runs started after the exclusive populated benchmark finished;
their timings are not UPS evidence.

| Run under `.factorio-qc/admin-players` | Recorded checkpoints | Result |
| --- | ---: | --- |
| `jail-final-all-03` | 52 | Complete suite passed with the native Default-group correction in a draft module. |
| `jail-final-all-04` | 52 | Complete suite passed against the integrated shipping module. |
| `jail-final-online-load-02` | 10 | Actual client save/server reload: online sentence remained at 3569 ticks after 180 offline ticks, versus 3570 at save time. |
| `jail-final-elapsed-load-01` | 10 | Actual client save/server reload: elapsed sentence decreased from 3570 to 3389 ticks across 180 offline ticks plus the transition tick. |

The integrated `all-04` player-source SHA-256 is
`8242371181262F0EB4A990281C636F292463F4FF1D912F03B98F38A50E5A3A10`.
`all-03` and the online client/server pair used immutable source SHA-256
`24672076F8F1E1BA2F25BC812DA0959A4346C82B3108BE573E4BA05B168594AA`;
the integrated difference is the `group_deleted` LuaLS annotation only. The elapsed
client/server pair uses the integrated `824237...A3A10` source unchanged. Each
manifest retains the exact fixture/library/source/save hashes. Server checkpoint
totals include the successful save-side checkpoints persisted in the archive.

The 52-check suite retains the earlier controller/inventory/spawn coverage and
adds saved reason/duration, sub-minute rejection, native movement/chat versus
build/GUI permissions, HUD element/signature retention, next displayed second,
old/new character destructibility, group deletion and live permission edits,
native jail-surface deletion, missing-origin force-spawn return, original
indestructibility, external permission group preservation and disabled cleanup.
The one-minute sentence is real validated input; the short expiry assertion
advances the player service's supplied tick explicitly. It does not claim that
the native simulation ran a full minute. Real disconnected accounting comes
from the separate client/server lanes.

Failed runs are retained. `jail-final-all-01` and `all-02` exposed native group
deletion assigning **Default, id 0**, rather than nil. The corrected owner records
that deletion fallback before restoring the saved group; it leaves a distinct
external group intact. `jail-final-online-load-01` stopped during staging because
the recursive copy encountered its precreated library directory. Adding `-Force`
to the isolated fixture copy fixed replay; that failed run launched no engine.

`jail-final-online-save-01/script-output/jail-hud.png` was generated by the native
hidden client and visually reviewed. Its adjacent `jail-hud.json` proves an actual
1280 x 720 viewport at UI scale 1.5. The reason wraps within the left panel, the
online clock basis and game-speed note are readable, and the remaining time fits.
This is a prisoner HUD visual check, not admin-menu mouse/focus/scroll acceptance.
The input save remains unchanged; the resulting autosave was used for the genuine
offline replay. `-CaptureHud` reproduces this optional client path and checks the
actual viewport before accepting it.

## Cross-surface god return regression

`god-surface-final-all-01` passed **54 recorded checkpoints** against integrated
player-source SHA-256
`E19AA268289B00E17254D6BEB56243AE4051704145A13C62F0B6EC3A9207C5C5`. The two added assertions first travel the god
controller to a different surface while leaving the protected original body
behind, then disable god mode and require reattachment to that exact body/surface.
The existing exact quality/tag/cursor/equipment/blueprint/nested-inventory/spoil
checks run immediately afterward and pass unchanged.

The motivating full-ESIR enabled-save/disabled-load fixture exposed Factorio's
native controller attachment rule: the saved character and current controller
must be on the same surface. Its valid body and exact escrow survived the failed
attempts. The correction teleports the owned god controller to the saved body's
surface inside the existing guarded return, revalidates the body after callbacks,
then attaches it. No body or inventory is cloned. Full save/load shutdown results
and retained failing evidence belong to the separate shutdown fixture report;
this 54-check run proves the ordinary cross-surface God Off path.
