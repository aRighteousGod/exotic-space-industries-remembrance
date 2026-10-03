# Native administration GUI replay

This isolated graphical fixture imports the current administration GUI, shared
camera window and common ESIR helpers. It uses native base/Space Age/Quality
prototypes and a small deterministic coordinator/registry substitute. It verifies
native layout and GUI API behavior without requiring all ESIR graphics packs.
Use the full administration fixture for integrated owner behavior.

Run from the repository root with an existing save containing a real player:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-responsive-qc.ps1 -RunName 720-100 -SaveInput path/to/player-save.zip -Resolution 1280x720 -Scale 1
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-responsive-qc.ps1 -RunName 720-150 -SaveInput path/to/player-save.zip -Resolution 1280x720 -Scale 1.5
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-responsive-qc.ps1 -RunName 1080-125 -SaveInput path/to/player-save.zip -Resolution 1920x1080 -Scale 1.25
```

Use a fresh run name each time. `-GuiSource`, `-CameraSource`, `-LocaleSource` and
`-FixtureDirectory` permit exact draft replay without editing shipping files.
`-RepoRoot` is available when invoking the driver outside the repository.

The driver starts a hidden native client using the installed Factorio executable.
Windows display scaling can multiply `--window-size`, so the driver uses a
per-thread DPI-aware Win32 call to resize only its own newly launched hidden
process window to the requested physical client area. It changes no global
display configuration or other application's windows. The driver rejects a run
unless `LuaPlayer.display_resolution` and `display_scale` match the preset.

Outputs stay in ignored `.factorio-qc/admin-responsive-<RunName>`:

- `manifest.json`: input save hash and staged source hashes.
- `script-output/responsive.json`: actual native dimensions/scale and assertions.
- `script-output/gui/<page>.png`: screenshots of all 12 pages; diagnostics also
  captures the selected-owner detail pane.
- `factorio-current.log`, `stdout.txt`, `stderr.txt`: native engine evidence.

The fixture exits editor mode only within this isolated replay so its native
palette does not cover the administration console. It does not save changes back
to the supplied archive. A brand-new `--create` save is insufficient: Factorio
does not offer a runtime API for creating a genuine player in this harness.

Assertions cover all page builds, fixed frame bounds, retained input/page/camera
identity and draft text, native filters/catalogs, exact action arguments, hidden
launcher inactivity, structured diagnostics and inspection cancellation. The
diagnostic fixture contains 49 owners and a long scalar list to exercise the
native LocalisedString parameter limit. Manual mouse focus, dragging and scroll
position are visual/manual checks; element identity is an automated assertion.

Do not interpret these graphical checks as whole-factory UPS measurements or
full ESIR owner integration coverage. See [verification.md](verification.md) for
the accepted initial evidence and its exact source fingerprints.
