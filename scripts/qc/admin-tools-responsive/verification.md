# Administration responsive verification

Factorio **2.0.77 build 84539** on Windows, 2026-09-29. The native client loaded
the connected-player seed `.factorio-qc/wtr/final-player/fixture.zip` (SHA-256
`C2A9A816858575A36E690B5BD82ACDBDC6EBD36120B08EE490DEC4BA31372CBF`). The archive
remains ignored; provide a compatible real-player save to replay elsewhere.

## Initial responsive layout acceptance

| Actual native viewport | UI scale | Checks | Evidence run |
|---|---:|---:|---|
| 1280 x 720 | 1.0 | 34/34 | `admin-responsive-720-1-d` |
| 1280 x 720 | 1.5 | 34/34 | `admin-responsive-720-15-c` |
| 1920 x 1080 | 1.25 | 34/34 | `admin-responsive-1080-125-a` |

All **102** assertions passed. Each run generated the 12 page screenshots under
`.factorio-qc/<run>/script-output/gui`; its `responsive.json` records the native
dimensions and scale. Reviewed planets, enemies and cameras at 720p/1.5;
research at 720p/1.0; diagnostics at 1080p/1.25. The bounded panels and camera
remained within the viewport, with native scrolling for overflowing content.

Identical source fingerprints in these three initial runs:

- GUI: `16f2766e19e528e367fc9e5e2d59bb7c90c89fe971cc5a621d413b62b39fd12c`
- Camera: `3f02e0c2f37f5705cb06ca1285111cd864d1b649ef8b7c1cd831ff2cb5824dcb`

These fingerprints identify the initial responsive implementation before the
subsequent structured diagnostics/launcher changes. The current fixture adds
diagnostics and launcher checks, so replaying it produces a larger check count.
No FPS/UPS conclusion is derived from these graphical fixtures.

## Structured diagnostics and launcher follow-up

The focused native run `admin-responsive-diagnostics-720-15-d` passed **47/47**
checks at actual 1280 x 720, UI scale 1.5. It added a 49-owner overview, a separate
persistent detail pane, selected-owner-only reads, unchanged-caption signatures,
inspection cancellation, long localized metric lists, the hidden launcher gate
and enemy-force/repair/Gaia target confirmations. Native overview/detail
screenshots were reviewed at this smallest preset. The shared target area stays
alive but is hidden on Diagnostics to make room for the owner view.

The final one-line addition requiring confirmation for Clear pollution followed
this focused run; the full ESIR integration fixture owns validation of that flag.
Mouse focus/dragging and actual scroll positions remain manual checks; native
element identity, draft text and camera zoom are automated assertions.

## Final integrated console replay

`admin-responsive-final-720-15-01` passed **47/47** native checks on Factorio
2.0.77 at actual **1280 x 720, UI scale 1.5**. This replay uses the final GUI
with the active world-job chooser, pollution presets, resource readout and travel
rows. All 12 pages built and remained within the viewport. Screenshots of Travel
and Modes, Items and Entities, and Fires/Ruptures/Pollution were reviewed; the
content uses the existing native scroll panes when taller than the available area.

Exact staged fingerprints:

- GUI: `8129248151A53BF42B1AA26970F16FB363A6AA39C3CB2FD487AD56F010C56C48`
- Camera: `B4DF04BB524E340ABB5D4632232E7E2D3A1D073BF4FF6687A7D8F317866E858E`

The run's manifest, native `responsive.json`, stdout and page screenshots remain
under `.factorio-qc/admin-responsive-final-720-15-01`. Its world/diagnostic services
are deterministic fixture providers: the new job chooser has an empty job list
in this lane. Real world-job behavior belongs to the separate full ESIR fixtures.
This is one final high-density preset, not a rerun of all three earlier viewport
presets against the final source. Mouse/focus/scroll-position limits above remain.

The first launch attempt failed in PowerShell argument binding before staging or
engine launch: `$PSScriptRoot` was unavailable in the default parameter expression.
The accepted run supplied `-RepoRoot` explicitly. The durable driver correction
resolves its default repository root in the script body instead.

## Enabled status row acceptance

The final enabled-status replay `admin-responsive-final-enabled-720-15-02`
completed on 2026-09-29 with **50/50** native checks at actual **1280 x 720,
UI scale 1.5**. Its evidence was recovered and checked on 2026-10-02. This run
uses the current shipping GUI with the seventh diagnostic header, `Enabled`.
The deterministic selected owner changes from enabled to disabled and back;
the same native label displays localized **On**, **Off**, then **On**. The
detail pane and enabled-row identities remain unchanged throughout.

Exact staged fingerprints:

- GUI: `692A1C65F6B03BB825DD07F7A0332F8BFDFD773D76A6613FAF9AEADC5322EAB6`
- Camera: `B4DF04BB524E340ABB5D4632232E7E2D3A1D073BF4FF6687A7D8F317866E858E`
- Fixture: `2B574185BE5103A4A65013671CBEEA1C9464ED4B648A874FE593233EAC914AF1`

The accepted manifest, result JSON, completion log and 13 page/detail screenshots
remain in `.factorio-qc/admin-responsive-final-enabled-720-15-02`. The native
detail screenshot was reviewed: the status label, owner role, initialization
state, schema, snapshot ticks and repair result are readable at this preset.
All 12 pages again pass the native frame-bound checks.

The promoted fixture adds type annotations around its owner/provider records;
these comments were added after the accepted run and do not change the exercised
Lua statements. The mocked registry/world scope and manual mouse/focus/scroll
limits described above still apply. This graphical replay establishes native GUI
behavior and readability; it supplies no client rendering or whole-engine UPS
measurement.

## Final window position and optional auto-refresh acceptance

On 2026-10-02, `admin-responsive-final-position-auto-720-15-01` passed **65/65**
native checks on Factorio 2.0.77 at actual **1280 x 720, UI scale 1.5**. The
fixture adds eight checks covering explicit mode action labels, unchanged native
player modes when opening controls, and a manually assigned window location
through Refresh, result feedback, navigation, close/reopen, invalid-root
recreation and an unchanged display callback. The saved reason draft survives
recreation. Seven further checks cover the two-row automatic-refresh toolbar:
default Off/no timer, all six intervals and the five-second default, enabling
at 300 ticks, rescheduling at 60 and 3,600 ticks, retaining the window position,
and removing timer ownership when disabled. Editing the interval while Off
leaves no scheduled work.

Exact staged fingerprints:

- GUI: `73647E1DDAC1F1EA9D0985D5CD6625AA159349CBD81169429099C5AE8E6CD151`
- Camera: `B4DF04BB524E340ABB5D4632232E7E2D3A1D073BF4FF6687A7D8F317866E858E`
- Fixture: `3A1FAB66D041F29EEF149A8B5DD248F86BD74CB64FDBC2FF5BE408921D658EF0`

All 12 pages remain bounded; the frame is 829 x 456 logical pixels and its
navigation/content use native scrolling. Reviewed Travel and Modes, Diagnostics
detail, and Research and Speed screenshots. The automatic-refresh Off state and
five-second selector are readable. The player readout displays cheat,
invulnerability, god controller, restriction and jail as Off in this seed, and
research actions explicitly say Enable/Disable instant research. The fixture
assigns the native location directly; it does not automate a physical mouse drag.

Manifest, result JSON, completion log and 13 page/detail screenshots remain under
`.factorio-qc/admin-responsive-final-position-auto-720-15-01`. This lane verifies
native controls and their scheduled ownership. Full coordinator service,
permission revalidation, shutdown and per-tick refresh budgeting belong to the
separate integrated administration fixture. The fixture-provider scope and
manual focus/scroll limitations above still apply. This final source was reviewed
at the smallest preset; it does not revalidate every earlier resolution or
establish a rendering/UPS performance claim.

## Saved-preview toolbar upgrade follow-up

The final current-source replay
`admin-responsive-final-legacy-position-auto-720-15-01` also passed **65/65**
checks at actual **1280 x 720, UI scale 1.5** on 2026-10-02. Its GUI fingerprint
is `AE1D695B478CB0444A22E9056C6B0F1A30C366DF49DBCC005FDC1BDDC6136283`;
camera and fixture fingerprints remain unchanged from the previous run.
Travel and Modes and Diagnostics detail screenshots were reviewed again with
the same readable two-row toolbar, explicit Off states and bounded scrolling.

This GUI adds an explicit-open structural upgrade for an old saved console root
that lacks the new auto-refresh controls. The complete native integration replay
`admin-completion-legacy-toolbar` supplies the **365/365** integrated result,
including three saved-preview upgrade assertions. This responsive lane supplies
the viewport/control regression checks against those current GUI bytes; it does
not replace that integrated legacy-session test. Both results retain their own
source manifests and logs.
