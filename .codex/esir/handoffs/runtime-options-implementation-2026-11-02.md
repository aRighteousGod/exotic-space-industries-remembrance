# Runtime options and Administration integration

Implementation: 2026-11-02, main mod version unchanged at 1.4.03.

## Delivered contract

The [runtime options model](../blueprints/runtime-options.md#contract) owns the
catalog, migration, transaction and editor contract. Administration → Options
(`/ei-admin options`) edits 113 native map settings:
29 converted runtime-only startup settings plus 84 existing runtime globals.
Factory Passage's three former Map Settings rows now live in Options → Performance.
Singularity Lance, ANISETRON and prototype-bound settings retain their startup scope.

All converted native IDs use `-runtime`. Hidden original startup definitions retain
existing-save input values. Existing maps import them once; fresh maps keep their
native Map choices. The saved marker prevents later configuration changes from
overwriting explicit map edits. The bridge is intentionally retained.

Apply validates all edited fields, checks their original baselines, writes in
deterministic order and verifies readback. Successful rollback suppresses ESIR's
intermediate owner callbacks. Partial rollback reconciles actual remaining values.
Native setting assignments raise synchronous events; no duplicate synthetic event
is dispatched. Administration shutdown runs after audit/feedback and other owners.

Live transitions preserve admitted jobs, paid effects, queues and deadlines under
their documented feature rules. Fluid exclusions use bounded removal and filtered
chunk discovery, retaining the native iterator for save/reload. No new tick
dispatcher or closed-menu polling was added.

All eight locales have the new page and updated native choice aliases, map-default
wording and applicable documentation. Existing native terminology is retained.

## Verification record

Exact execution profile: Factorio 2.1.24 and the checked-in standard dependency
lock. Functional and focused rendered acceptance are complete.

| Native run | Phases and assertions | Evidence run |
| --- | --- | --- |
| Default profile | Candidate 1,476; ordinary reload 89; configuration 87 | `b73c5965818640ef87571bd4e57605bf` |
| Controlled legacy values | Candidate 1,504; ordinary reload 89; configuration 87 | `4adcdeacc4f944ff8ca251d701bcb4df` |
| Final-source checkpoint continuation | Ordinary reload 89; configuration 87 | `99bd29898130433fbff23476adc49049` |
| Genuine preserved smoke save | Import 140; checkpoint producer 140; ordinary reload 168 | `aba61d8c3b664f7688e6234fa887f36b` |

The full six-case matrix passed 3,332 assertions. Subsequent final-source changes
deduplicated lifecycle tick capture and added the 48 missing EM enum locale keys;
the retained, hash-verified legacy checkpoint passed both continuation phases
against that final source. The saved native fluid iterator remained valid and
resumed without a configuration rebuild on ordinary reload.

The genuine old save was created under **2.1.23**, loaded with **2.1.24**. Its
immutable SHA256 is `741c319f535773cccbe3cc64e45a7c8a4d4b7b5edd2c973696afd87d156d4cad`.
All 29 startup values were independently decoded from those pinned save bytes and
matched both the native synchronized inputs and migrated runtime outputs. The real
configuration callback saw no prior marker. A later explicit edit survived a
migrated checkpoint and ordinary reload without another import. The original
save hash remained unchanged. This is a lightweight smoke save, not a populated
factory migration stress test.

- Structural blueprint audit: 67 models, 212 owned sources, zero findings.
- Host native-runner checks: 21 passing. The sandbox initially denied temporary
  directory access; the authorized elevated rerun passed unchanged checks.
- Focused native candidate before the fluid-world extension: 1,406 passing
  assertions, run `3670f3f4dc8447829d07a0c61c793dd6`.
- Offline controller/transition checks: 18 Options, 17 owner transitions, 41 fluid
  reconciliation, and 19 Factory Passage Options assertions.
- Updated alert fixtures: 230 icon-set, 1,736 shared-alert, 1,862 presentation and
  98 ecology assertions, with native boundaries mocked. Source/assets/native-call
  ownership audit passes.
- Final broad preflight passes syntax, locale duplicates/missing keys, references,
  versions, module headers, blueprints and runtime alerts. Its only failure is
  the unrelated existing encoding finding in
  `scripts/qc/singularity-lance/angular-results.json`.

Rendered run `c2a9d2ee76674ea0bb68a08567510142` passed English 1600×1000 at
100% UI scale, English 1280×720 at 150%, and Japanese 1600×1000 at 100%.
Each profile validates 113 controls, all five control types and 401 native
translations. All 24 retained PNG hashes match the receipts. The original smoke
save was not written, and its hash remained unchanged.

Visual review covered these eight representative captures: English standard
Administration and Performance; English compact Effects top and lower, Pollution
lower and Ecology presets; Japanese standard Effects and Pollution. Labels,
actions and controls remain readable, and compact content remains reachable by
scrolling. Long selected enum text uses native clipping within the dropdown.
Existing untranslated legacy administration wording is outside this conversion.
The other 16 captures are retained but were not individually visually reviewed.
The rendered receipt is `reports/capture-result.json` inside that run's
`evidence.zip`; PNGs remain in its three `*.images/options-captures/` directories.

Early failed runs are retained as diagnostic evidence. The settings-stage copy
helper import was fixed after native loading exposed it. Subsequent fluid fixture
failures concerned deferred surface deletion and Lua `assert` returning an extra
value. Cross-mod fixture storage access was also hardened during that investigation.
Those failed runs are not passing acceptance runs.

## Evidence locations and limits

Task baseline, private review patches, full wrapper results and supplemental
orchestrators are retained in the registered protected-evidence directory:

`.factorio-qc/managed/191f7f6b090e40fbb5a496821874a857`

Native child runs compact logs, reports and input fingerprints into their own
`evidence.zip` with an evidence index. Registered coverage is `test-suite: runtime-options`;
cases are candidate, ordinary reload and configuration, each
under default and controlled legacy-values profiles.

The controlled legacy profile checks 29 deliberately non-default inputs and must
remain distinct from authentic old-save lifecycle evidence. Programmatic native
GUI callbacks are distinct from rendered layout and physical mouse interaction.
Independent drafts do not establish two-client multiplayer/desync acceptance.
Physical mouse interaction, tooltip hover and populated-factory performance were
not tested. Rendered coverage is English/Japanese; all eight locales passed the
static key and native-choice coverage audit.

The initial worktree was already dirty. The final comparison retains all 6,704
baseline files: 6,606 are byte-identical and 98 have scoped implementation changes;
19 task files were added. No baseline file was removed. The seven existing Git
deletions were already present at baseline. Main `info.json` and the unrelated
encoding-finding file remain byte-identical. The full comparison is retained as
`closeout-workspace-manifest.json` in the protected task directory. No unrelated
files were reverted or staged. No commit, push, deployment, installation or
main-mod version bump is part of this task.
