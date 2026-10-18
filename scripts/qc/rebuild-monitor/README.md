# Rebuild activity monitor QC

Target: installed Factorio **2.0.77**. Fixtures use isolated managed staging and a
real connected-player seed. They never change the live mod list, user saves or
Steam identity. The full-pack lane uses the existing installed dependency seed.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-rebuild-monitor-qc.ps1 -Full
powershell -ExecutionPolicy Bypass -File scripts/invoke-rebuild-monitor-qc.ps1 -Visual -Scale 1 -Ticks 700
powershell -ExecutionPolicy Bypass -File scripts/invoke-rebuild-monitor-qc.ps1 -Visual -Scale 1.5 -Ticks 700
powershell -ExecutionPolicy Bypass -File scripts/invoke-rebuild-monitor-qc.ps1 -Reload -Scale 1
```

Run graphical lanes sequentially. The driver uses low graphics memory settings,
resizes only its own client to 1280x720, and verifies the reported viewport and
scale. `-Reload` saves and reloads once with the frame open and once dismissed.
Its checkpoint pauses only the fixture state machine, not gameplay. Failed runs
remain registered for diagnosis; completed task runs use normal managed retention.

## Coverage

- `core.lua`: pure empty snapshots, tick zero, detached records, simultaneous
  activity, superseded IDs, stale updates, ETA sampling/reset/expiry, external
  waits and resumption, synchronous results, and the 32-result history ring.
- `virtual.lua`: 16 fake viewers, the eight-viewer service limit, late joining,
  the 120-tick deadline across queue slices, independent dismissal, new jobs in
  the same episode, completion while closed and idle admission. This is logic
  coverage, **not native multiplayer evidence**.
- Native GUI: launcher, delayed opening, background clicks, close/reopen,
  dragged location, clipping, five simultaneous rows with scrolling, native
  machine GUI and cursor preservation, unknown totals, blocked work, independent
  Diagnostics refresh and persisted activity/dismissal/location.
- `instrument.lua`: actual beacon discovery/recounts, fumarole batches, Tesla
  replacement, disabled flamethrower restoration, Gaia reforge, EM rollout and
  removal, spider replacement/removal, water seed ingestion after discovery,
  radar mixed/entirely blocked cohorts, attribution census completion/cancellation,
  and deferred synchronous orbital rescan. Gameplay processors run through the
  existing central dispatcher; the fixture never adds a production scheduling lane.

The full fixture waits 6000 ticks because the real seed includes thousands of
chunk iterator entries. Beacon discovery must remain indeterminate even when its
ready chunk queue is empty. Water checks peak indexed fire count before fires
naturally expire. Fumarole setup invokes its existing configuration bootstrap
after creating Vulcanus. EM setup settles its existing first-registration repair
before admitting the research generation; it checks exact terminal IDs.

## Evidence and limits

See [verification.md](verification.md) for the implementation run results and
unrelated repository findings.

Reports are `script-output/rebuild-qc.json`; screenshots are under
`script-output/rebuild-monitor/`. Native profiler output is explicit QC evidence
in `rebuild-profiling.txt`, in this order: 100,000 empty callbacks, 100,000 idle
admission calls, 100,000 scalar reports, and 10,000 ten-job snapshots. Those
microbenchmarks do not establish a whole-save UPS change. Production ETA never
reads profiler output.

Native one-player save/load and simulated multiple-viewer scheduling are separate
claims. Genuine two-client multiplayer and keyboard-focus input injection are
not automated here. The API exposes `focus()` but no focus reader; the monitor
contains no focus call or assignment to `player.opened`.

Use the existing admin responsive and scripted-research fixtures alongside this
lane. The admin fixture supplies an inert ecology adapter for its unrelated page
and checks activity-only refresh. Its drag point remains inside the console's
native clamp. Broad repository preflight/runtime staging can fail independently
of these fixtures; preserve those findings in the task report.
