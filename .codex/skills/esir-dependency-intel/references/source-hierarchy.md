# Source Hierarchy

Use this order when answering dependency questions:

1. Repo source files are canonical for behavior.
2. [`.codex/esir/dependency-catalog.json`](../../../esir/dependency-catalog.json) is the checked-in fast map.
3. [`.codex/esir/runtime-modules.json`](../../../esir/runtime-modules.json), [`.codex/esir/prototype-index.json`](../../../esir/prototype-index.json), and [`.codex/esir/pack-manifest.json`](../../../esir/pack-manifest.json) provide structural cross-links.
4. `-ResolveInstalled` may inspect `%APPDATA%\Factorio\mods`, `output\tesla-run-mods`, and `.factorio-qc` roots, but that data is ephemeral and machine-local.

Stable checked-in layers:

- `declared_dependencies`: parsed from each checked-in pack `info.json`
- `touchpoints`: extracted from ESIR runtime/data-stage integration files plus shallow media-pack entries

Do not treat local installed mod presence as checked-in truth.
