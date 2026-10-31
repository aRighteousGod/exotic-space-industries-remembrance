# Managed QC storage checks

Run the isolated storage invariants from the repository root:

```powershell
python -B -m unittest discover -s scripts/qc/storage -p 'test*.py' -v
powershell -ExecutionPolicy Bypass -File scripts/qc/storage/check-skill-workflow.ps1
powershell -ExecutionPolicy Bypass -File scripts/qc/storage/check-core-adapter.ps1
powershell -ExecutionPolicy Bypass -File scripts/qc/housekeeping/check-compact.ps1
python -B scripts/qc/storage/check-overflow.py
```

For current-profile acceptance, after preparing its exact dependency seed, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qc/housekeeping/check-engine.ps1
powershell -ExecutionPolicy Bypass -File scripts/qc/storage/check-current-profile.ps1
```

The native check resolves the profile's exact engine (currently 2.1.24) and runs
its tiny fixture twice. The profile check stages the real locked selection twice,
checks distinct file identities and allocated bytes, and closes both owned runs.
It leaves compact evidence and current-profile package references, with no dumps
or mod views. Neither command deploys mods or rewrites historical evidence.

The Python suites create small disposable repositories under `output` or system TEMP, remove
their owned links before teardown, and never import real dependency packages.
Capacity and migration tests use a synthetic overflow directory; they do not
move the live canonical store. The independent PowerShell workflow checks the
documented housekeeping integration and allocated bytes for two simultaneous views.
The overflow check creates a new system-temporary C: repository and a unique
`D:/ESIR/qc` namespace, exercises both mutable fixture isolation adapters, then
removes those exact owned roots. It requires write access to C: temporary storage
and D:, and never adopts an existing overflow namespace.

The storage implementation is `scripts/esir_qc_storage.py`, callable using
`dispatch(repo, action, data)` or its JSON-stdin CLI. PowerShell callers use
`Invoke-EsirQcStorage` from `scripts/esir-qc-storage.ps1`.

| Action | Contract |
|---|---|
| `import` | `path`, optional locked metadata/hash, and optional `profile` or `run_id` reference attached atomically. `consume` additionally requires the explicit caller-owned `temporary_root`. |
| `profile` | Replace a named profile's exact package hashes; an empty list releases that profile's inputs. |
| `open` | New `run_id`, `workflow`, `evidence_root`, and declared `source_mode`; optional `estimate_bytes`. An identical open is idempotent. |
| `stage` | Select `packages`, `sources`, optional `mod_list` and `settings_path`; returns the final roots, which may change after first-import overflow. |
| `validate` | Verify canonical package bytes and the original source fingerprints. Intended private fixture edits do not count as source drift. |
| `mutable-sources` | Resolve declared private source names to verified plain backing paths. Across C:/D:, this verifies the owned source-volume backing and its mod-view junction before fixture code writes. |
| `release` | Validate inputs, save a compact private-code/settings reproducer, and remove only the owned mod view. Scratch remains available to later consumers. |
| `close` | Bundle reports, promote explicitly selected scratch files from `retain`, then retire scratch and collect unused packages. External selected files are referenced without duplication. |
| `pin` | Add/remove a run's reasoned pin with `reason` and `pinned`; pinned runs cannot compact. |
| `collect` | Read-only candidate inventory unless `apply: true`; profiles, open runs and pins retain packages. |
| `status` | Inspect the store, or one `run_id`; inspecting a missing store does not create it. |
| `configure` | Set nonnegative integer `reserve_bytes` and `default_estimate_bytes`; roots and ownership are not user-overridable through this action. |

Normal code should use the shared ESIR lifecycle rather than call these actions
independently. The detailed contract lives in the ESIR development skill's
`references/housekeeping.md`.

An editor, antivirus tool or live engine can hold a file open. Cleanup reports
the Windows sharing error and preserves the owned output. A closeout interrupted
by a locked scratch file can resume after the lock clears: the helper verifies
the published bundle, index and original scratch inventory before removal.
Changed evidence, unknown files or an interrupted store migration remain
protected for explicit review; do not bypass ownership checks to force cleanup.
