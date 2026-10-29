# Research science-template regression

Private Factorio 2.1.23 QC mod for the Vulcanus Computer Age template alias.
Keep it out of shipping packages and real mod selections. Use the pinned core
runner `scripts/qc/factorio-2.1/invoke-core.ps1` with this folder copied into an
isolated registered run. Required dependencies use the existing core selection.

`test-config.lua` selects `no_triggers` and `flatten`. The fixture hides and
forces both startup settings in the private run, then asserts their **actual**
data-stage values. `forced_value` is ineffective on visible boolean settings;
changing their defaults alone does not override saved `mod-settings.dat` values.
See the [official settings guide](https://wiki.factorio.com/Tutorial:Mod_settings#bool-setting).

For each of the four boolean combinations, run `-Task create`, then preserve
`script-output/research-bootstrap.json` under a distinct case filename. Snapshots
cover initial data, data-updates and final data; they capture research units,
prerequisites, effects, triggers, visibility, age templates and recipe
ingredients/results. The checker verifies:

- all shared age templates remain unchanged;
- tier-2 acid neutralisation retains its own Metallurgic science cost;
- the science-cost/trigger mode actually selected reaches final data;
- each same-identity science unlock and its prerequisite ancestry avoids
  consuming that science pack;
- against the reproduced baseline, the only captured technology changes are
  removal of unintended Metallurgic science costs, with captured recipes equal.

```powershell
python -B scripts/qc/factorio-2.1/research-bootstrap/check.py <four-snapshots> --before <before.json> --output <checks.json>
```

The unfixed baseline must fail the template assertion (negative control).
Science packs whose technology uses a different identity are outside the
automatic ancestry check; this is not an exhaustive production-reachability
solver or a full progression playthrough.

For native coverage, set `runtime="lab"`, `no_triggers=true`, `flatten=false`
and load the preserved pre-fix test save. The separate QC mod completes
prerequisites on a private force, accelerates laboratory speed, and inserts
40 of each of the four ESIR age packs into a real Big Lab. No Metallurgic
packs are supplied. The real technology must consume ten of each, emit an
ordinary `by_script=false` completion and unlock its recipe. No technology
or lab prototype is simplified. The private speed modifier only shortens QC.

`-Task benchmark -Ticks 1100` checks execution. For a real saved checkpoint,
use `scripts/qc/factorio-2.1/save_checkpoint.py` with checkpoint
`research-bootstrap-fixed.zip`, receipt `research-bootstrap-native.json` and
`--pass-key passed`. The isolated loopback server saves researched state,
lab contents and tier-2 acid neutralisation at 37.5% research progress.
Set `runtime="reload"` and benchmark that checkpoint; compare `actual` and
`expected` in `research-bootstrap-reload.json` for exact equality.

The fixture's own control script observes completion without replacing ESIR's
dispatcher. It adds no player-facing command, runtime work or setting to ESIR.
Native headless evidence does not certify the GUI, multiplayer clients, unknown
optional combinations or the reporting player's unavailable save.
