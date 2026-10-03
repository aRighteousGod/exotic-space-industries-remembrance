# Administration console acceptance — 2026-10-02

Implementation targets installed Factorio **2.0.77 build 84539**, with ESIR
**1.3.40**. `ei-admin-tools-enabled` remains disabled by default. Enable the
startup setting, restart and use `/ei-admin` as an administrator. See the shipped
[administration guide](../../../exotic-space-industries-remembrance/docs/admin-tools.md).

Opening or promotion does not enable cheat mode, invulnerability or native god
mode. Mode action buttons say Enable/Disable separately from actual On/Off
readouts. The window centers once and retains dragged position across refresh,
feedback, navigation, close/reopen and root recreation; display changes clamp
only as needed. Optional auto-refresh defaults off, with 1/2/5/10/30/60 simulation
second intervals. Closing cancels its timer, and destruction/demotion/shutdown
turns it off. Shared delayed buckets service at most eight visible page refreshes
per tick, reuse a world snapshot and reject stale timer/administrator ownership.
This cap bounds refresh calls, not all delayed ownership bookkeeping visits.

## Functional evidence

These suites overlap. Their counts are reported separately, not summed as unique
requirements. Exact source manifests and native logs accompany retained profiles.

| Scope | Result | Evidence |
| --- | --- | --- |
| Full ESIR integration, enabled | **365/365 assertions** | `.factorio-qc/admin-completion-legacy-toolbar/script-output/admin-qc.json` |
| Full ESIR integration, disabled | **14/14 assertions** | `.factorio-qc/admin-completion-window-auto-off/script-output/admin-qc.json` |
| Bounded world jobs, native effects and iterator save/load | **101/101 assertions** | [World acceptance](../admin-world/ACCEPTANCE.md) |
| Native player modes, inventory and cross-surface return | **54/54 checkpoints**; separate genuine offline lanes | [Player verification](../admin-tools-player/verification.md) |
| Enabled autosave loaded with toolkit disabled | **39/39 cumulative checks** | [Shutdown acceptance](../admin-shutdown/ACCEPTANCE.md) |
| Existing GUI owner lifecycle | **28/28 assertions**, all 19 owners represented | [GUI verification](GUI-VERIFICATION.md) |
| Player-built attribution and restriction dispatcher | **18/18 assertions**; seven permission checks in full suite | [Restriction verification](RESTRICTIONS.md) |
| Responsive native GUI | Final **65/65** at 1280×720 / 1.5; earlier **102/102** across three presets | [Responsive verification](../admin-tools-responsive/verification.md) |

The final integration replay includes native mode defaults and 16 added automatic
refresh assertions, plus three saved-preview toolbar upgrade checks. A valid
legacy root missing the new controls performs one actual structural rebuild,
retaining position and drafts with timed refresh off. The first timer replay
passed these new checks but failed a
later speed assertion because the fixture's real shutdown callback had correctly
restored game speed. Moving the shutdown/default probe before the speed mutation
fixed test isolation; no gameplay speed change was made for that mismatch.

The same full suite covers actual Gaia reforge/policy restoration, existing/new
planet peaceful defaults, native infinite research stopping after one level,
stale actor rejection, targeting/cursor-ghost recovery, all eight rupture variants
at 20/100/500 MJ, creation callbacks and repeated invocation of all **43 repair
providers**. Its focused **74/74** slice contains 54 active preservation checks,
eight pure diagnostics checks and 12 closed-GUI service checks. Broad repair
invocation is not proof of active-state preservation for every owner; see
[PRESERVATION.md](PRESERVATION.md) for the six directly exercised owners.

Genuine disconnected-server jail replays passed ten cumulative checks for each
clock: online time changed 3570→3569 ticks over 180 offline ticks (one transition
tick), while elapsed time changed 3570→3389. Exact stacks, quality, tags, nested
inventories, spoil deadlines and equipment survived native controller transfers.
The disabled autosave replay restored the original body across surfaces, exact
god inventory, destructibility and prior speed, cancelled uncommitted work and
retained completed native world edits. That 39-check autosave predates optional
auto-refresh; the final full suite separately tests its real shutdown callback.

## GUI and performance evidence

Native closed-panel assertions observed zero EM registry-summary calls and zero
black-hole/matrix snapshot queries. One open dirty EM viewer built one summary;
a second updater with no dirtiness built none. Water/spider roots and unchanged
radar rendering objects retained identity. Neutron/matter closed services retain
empty scheduling bucket identity, do not advance GUI timestamps, clear stale
scheduling once and do not initialize absent GUI state. The source audit covers
all 19 interactive GUI owners and Informatron providers.

The earlier uninstrumented populated comparison and its frozen source limits are
recorded in [POPULATED-BENCHMARK.md](POPULATED-BENCHMARK.md). It did not demonstrate
a consistent whole-factory UPS improvement. The subsequent eight-process,
warm-up-discarded three-pair comparison is in
[POPULATED-FINAL-BENCHMARK.md](POPULATED-FINAL-BENCHMARK.md): baseline median
14.665449 ms/tick, candidate 14.465136 ms/tick (1.366% lower), but two of three
pairs favored the baseline and ranges overlap. No consistent whole-engine gain
is established. The toolkit was off with no open panels. The saved-toolbar upgrade
postdates timed GUI bytes; a verified single-file delta and fresh current-source
scope document that its explicit-open path is inactive in this workload.
Functional fixture setup/timings are excluded from performance conclusions.
GUI query/identity evidence, whole-engine update time and client rendering remain
separate measurements; no FPS improvement is claimed.

## Static checks and scope limits

ESIR preflight passed Lua/PowerShell syntax, require references, all 107 runtime
source classifications/backlinks, locale duplicate/missing keys, asset references
and pack-version consistency. Its wrapper remains non-green: the latest run with
a writable Python cache prefix reports 65 bytecode-cache path-creation errors,
plus the unrelated existing encoding finding in
`scripts/qc/singularity-lance/angular-results.json`. These cache failures are not
Python syntax errors; a separate read-only compile of all 111 Python sources
passed. Two existing module-header warnings remain. Current static evidence is
`output/admin-implementation/preflight-final-cache-20261002.txt`.

Earlier ESIR fast data-stage and runtime engine lanes completed without engine
errors. Their wrappers retain the same unrelated encoding failure and existing
missing-prototype/recipe warnings; this report does not call them clean passes.

Native connected fixtures use one actual player. A two-client LAN attempt was
prevented by the installed Steam build binding both clients to the same identity;
two simultaneous viewers remain source-reviewed rather than accepted in-engine.
Kick/ban APIs used an invented name; no real user was moderated. Native element
identity, draft text, dimensions, saved position and camera zoom are asserted.
Actual mouse focus/dragging and manual scrolling are not automated coverage.

Player-built last-user restrictions preserve natural and unattributed map/script
entities. Indirect/AoE effects, other mods, historical undo/redo and native edits
without immediate events have explicit limits in [UNDO-LIMITS.md](UNDO-LIMITS.md).
This is not a complete multiplayer anti-grief boundary.

The separate [biter-map investigation](BITER-MAP.md) identifies Fire Lights'
startup flag ownership and proves that changing it does not remove a native
M-map layer button. Latest installed settings already have the hide-units option
off. The chart layer panel's zoom-dependent visibility was reproduced; a
historical separate biter control's provider remains unidentified.

The local `modding_tools_2.0.6` archive and authorized MIT-licensed
[Friend Cam](https://mods.factorio.com/mod/friend-cam) 0.1.0 archive were reviewed.
The shared `ei_lib` camera uses native attachment and owner-scoped lifecycle,
without copying the reference's all-player polling loop. Reference downloads and
engine scratch stay in ignored staging. No live profile/save, commit or deployment
was changed by these fixtures.
