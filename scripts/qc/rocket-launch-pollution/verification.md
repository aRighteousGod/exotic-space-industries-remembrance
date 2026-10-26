# Rocket launch pollution verification — 2026-10-25

Engine: installed Factorio **2.0.77**. Main mod version remains **1.3.41**.

Accepted evidence bundle: `.factorio-qc/managed/rp-accept-048ba310`, containing
the four native reports/logs, static-check results, and graphical captures.

## Native runtime and serialization

Final fixture: `.factorio-qc/managed/rp-b7c20899/n`.
`native-report.json` and `reload-before-report.json`, `reload-during-report.json`,
and `reload-after-report.json` all pass **29 scenarios** and **260,736 accumulated
assertions** apiece. The count includes repeated per-tick invariants, not distinct
test cases. Actual native pollution calls and source statistics agree within the
fixture's 0.002 floating-point tolerance; no separate statistics flow is recorded.

For the 10,000-pollution baseline:

| Observation | Standard | Fast prototype | Slow prototype |
| --- | ---: | ---: | ---: |
| Ordered tick | 890 | 890 | 890 |
| Ignition and first emission | 1011 | 892 | 1011 |
| Last emission | 1831 | 1634 | 1831 |
| Native completion event | 2052 | 1634 | 3523 |
| Final launch total | 10,000 | 10,000 | 10,000 |

The immediate first share is 12.315270936. At ignition +100 ticks, every visual
style has emitted 1,243.842364532. Subsequent scheduled targets follow the exact
cumulative formula on ten-tick boundaries. The 812-tick reference profile reaches
its final scheduled payment at +820 because of that stride. Early confirmation
settles the unpaid balance: the fast case settles 874.384236453. A slow launch
survives the previous cleanup deadline and cannot exceed its budget.

The standard native silo leaves `rocket_flying` at tick 1823, **812 ticks after
ignition**, but the rocket remains valid through silo closure and confirms at
2052. Consequently silo closure cannot be used as a completion/cancellation signal.

| Interruption | Pollution retained |
| --- | ---: |
| Rocket or silo destroyed before ignition | 0 |
| Silo destroyed at ignition +40 | 504.926108374 |
| Rocket destroyed as flight starts | 5,307.881773399 |
| Silo destroyed after native flight phase | 9,987.684729064 |
| Silo destroyed during confirmed pad tail | 200,000 |

All interruption cases stop subsequent particles and pollution. The engine can
still confirm a rocket after its silo dies; canceled records suppress that later
top-up. Already-created particles are allowed to fade.

Real concurrent launches on one surface and two sequential launches from one silo
each produce 20,000. All four visual styles have identical pollution profiles.
Zero cap makes no pollution calls; the existing threshold/hybrid curve totals
remain 12,000/15,000. Legacy queue, bucket and pending records, late adoption,
missing-silo confirmation, genuine missing-record fallback, lost-index recovery,
admin repair and orphan-smoke retirement pass. Impossible retaliation passes on
ordinary surfaces and remains suppressed on peaceful/no-enemies surfaces.

The overlapping-order identity test injects a mismatched replacement while a real
rocket is airborne. It verifies preserved detached accounting and rejects the
replacement before emission. It does **not** claim two native airborne rockets
from one silo: forcing early reconstruction violates a 2.0.77 engine assertion.
The normal concurrent and repeated cases use real native events.

Checkpoint saves come from a private local server and are replayed to completion.
This proves serialization/accounting behavior, not multiplayer peer/desync testing.

## Graphical inspection

The separate graphical capture uses `.factorio-qc/managed/rp-02f5fa8d/n` and the
same final gameplay behavior. Its fixture predates only the last two assertion
refinements (genuine missing-state fallback and orphan-smoke retirement).
Ignition frames at ages 0, 1, 30, 150 and 570 show native glow/exhaust developing
during engine start and ascent. Engine brightness ramps up from the first native
ignition tick; the first frames are correspondingly subtle.

The user inspected the native graph and confirmed that emissions appeared and
were released gradually. The subsequently retained `rocket-visual/graph.png`
shows the **Pollution** tab at **1m**, the rocket-part icon, a 10k production total,
and the gradual rise/plateau/fall of the displayed rate. Its accompanying native
statistics total is 10,000.000049591, within normal floating-point tolerance.
The localized source name is verified by the prototype assertion; the retained
image does not show the hover tooltip. Desktop capture automation timed out, so
the user selected the tab and the game's own screenshot supplied the evidence.

## Static checks and limits

Focused Lua parsing and whitespace checks pass. Current repo preflight passes
Lua/PowerShell syntax, required references, locale checks, assets, version
consistency, headers and conceptual blueprints (59 models, 180 owned sources,
zero findings). Python compilation initially hit protected cache paths; rerunning
that same check with `PYTHONPYCACHEPREFIX` in a writable temp directory passes.

Three unrelated encoding findings remain:

- `scripts/qc/singularity-lance/angular-results.json`: suspected mojibake.
- `temp/anisetron-tracking-fix/blueprint-final.json`: UTF-16LE BOM.
- `temp/storage-audit-c/evidence-link-update.json`: UTF-16LE BOM.

These results do not claim performance benchmarking, unrestricted compatibility
with external launch-speed mods, or native-language review of every translation.
