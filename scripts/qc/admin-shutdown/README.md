# Full coordinator shutdown fixture

Run separately from an exclusive benchmark or another graphical QC client.
Shipping source is never edited. Staging copies current ESIR into fresh enabled
and disabled profiles and reuses complete visual assets from `admin-v720`.

With a disposable connected-player save and a complete visual mod pack:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-shutdown-qc.ps1 `
  -Mode all -RunName shutdown `
  -SaveInput .factorio-qc/wtr/final-player/fixture.zip `
  -AssetMods .factorio-qc/admin-v720/mods
```

`-Mode stage` only prepares files; `-Mode save` launches the enabled hidden native
client, and `-Mode reload` launches a fresh disabled hidden native client from its
ZIP-validated autosave. The default input is the disposable connected-player seed
`.factorio-qc/wtr/final-player/fixture.zip`. Neither the seed nor live profiles are
changed. The driver copies no player-data/account files or credentials and only
stops the exact process it launched.

The helper has the same ID in both profiles. Its hidden bool setting forces admin
tools on, then off, ensuring the saved startup setting cannot silently stay on.
The full normal coordinator performs shutdown through its configuration callback.
A fixture-only wrapper first records actual loaded queues/modes/UI/targeting so
the test cannot pass merely because those jobs drained before the autosave.

The enabled phase waits for the real player to connect and creates a native
fixture character if the seed has none. It then creates a completed chest/policy
edit, an owned god controller,
cheat/invulnerability, tagged and quality-bearing native stacks, a nested item
inventory, speed 2, instant research automation, pending entity/chunk jobs, an
admin root/camera and an active selector. It uses `game.auto_save` in a real client.
The disabled reload checks the original body and properties, exact items, speed,
GUI/cursor/job/automation cleanup, and preservation of the completed world edit.
The probe observes pending mode recovery for at most 720 simulation ticks, without
forcing owner callbacks or changing recovery state. Scalar samples distinguish a
delayed native controller transition from a persistent attachment failure.
Jail is deliberately outside this fixture; its shutdown has a separate native
player fixture. This is single-player lifecycle verification, not multiplayer
or whole-factory performance evidence.

Results, logs, source hashes and both private profiles stay under
`.factorio-qc/asd/<RunName>` (short paths avoid Windows asset-copy limits).

[Native acceptance](ACCEPTANCE.md) records the enabled save, disabled reload and
cross-surface attachment regression found by this fixture.
