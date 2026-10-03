# Admin player native engine fixture

This isolated companion mod runs the shipping admin player module and shared libraries with vanilla Base, Space Age, Quality and Elevated Rails. It checks native Factorio controller, inventory, surface, permission and player lifecycle behavior independently of ESIR progression. Use a disposable save containing a real player.

Run from the repository root:

~~~powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-player-qc.ps1 -RunName connected -SaveInput <disposable-connected-player-save.zip>
~~~

The default benchmark lane asserts actual connected-player membership from the seed. It covers remote physical travel; native god entry/return; original body/inventory ownership; quality, nested tags, cursor, equipped armor, equipment energy, blueprints, nested item inventories and spoil deadlines; full-inventory native spills; destroyed-body recovery; independent invulnerability; system-disable restoration; restrictive jail permissions, expiry, group/location/mode restoration; and spawn readiness/configuration/death/respawn.

The controlled leave/join hook pair in this lane isolates the online timer calculation. The separate client/server lanes below test genuine disconnected player state and real persisted LuaObjects.

## Genuine offline jail lanes

Create an actual client autosave with a jailed player:

~~~powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-player-qc.ps1 -RunName online-save -SaveInput <disposable-connected-player-save.zip> -Mode client -Suite save-jail -TimerMode online
~~~

Then load its own snapshot on an unlisted non-pausing server. Freeze the staged player source and libraries to the save-side versions:

~~~powershell
$savedRun = '.factorio-qc/admin-players/online-save'
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-player-qc.ps1 -RunName online-load -SaveInput "$savedRun/saves/_autosave-admin-player-jail.zip" -PlayerSource "$savedRun/mods/esir-admin-player-qc/players.lua" -LibraryDirectory "$savedRun/mods/esir-admin-player-qc/lib" -FixtureDirectory "$savedRun/mods/esir-admin-player-qc" -Mode server -Suite save-jail -TimerMode online -ServerPort 34327
~~~

Repeat with fresh elapsed-save/elapsed-load names and TimerMode elapsed. The online sentence must remain constant while disconnected (within the single engine transition tick). The elapsed sentence must decrease with server ticks.

## Offline god inventory and typed ban target

Create a client snapshot using Suite save-god. Its save is named _autosave-admin-player-god.zip. Load that save with Mode server and Suite save-god. This verifies an explicit ban name overrides the GUI's accompanying dropdown player index, exercises native ban/unban on an invented fixture name, confirms offline god inventory access, removes the offline fixture player through the native API, and checks exact tagged/nested stacks survive pre-remove escrow.

Removed-player inventory may remain in script escrow when the original parked body is invalid. The fixture treats retention as preservation; it does not claim a GUI for recovering that exceptional inventory.

## Isolation and acceptance

Every run requires a fresh RunName and stages beneath .factorio-qc/admin-players. It records source/save/staged-file hashes, private configuration, stdout/stderr, result.log and script-output/admin-player-qc.json. The driver checks both the engine log and stdout because benchmark errors can appear only in stdout during shutdown. It accepts a completed fixture marker, or a ZIP-validated genuine client autosave for save lanes.

The client runs hidden and is stopped only after its own save/fixture marker. The server is unlisted and uses the supplied dedicated port; choose another port for concurrent servers. The driver only stops the process it launched. Neither the input save nor installed user mods/configuration are overwritten.

This lane proves native engine behavior. Full ESIR event ordering, admin menu layout, mouse interaction, ordinary multiplayer administration and whole-mod performance require their separate integration lanes. See verification.md for the recorded 2.0.77 results.
