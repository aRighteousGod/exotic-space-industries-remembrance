"""Reconcile tested candidate archives into a durable, explicitly unpublished report."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--stage',default='package-core-22')
    a=p.parse_args()
    candidates=json.loads((a.run/'audit/release-package-candidates.json').read_text())
    stage=a.run/a.stage
    selection=json.loads((stage/'release-selection.json').read_text())
    load=json.loads((stage/'packages-01.receipt.json').read_text())
    final=json.loads((stage/'packages-final-data.receipt.json').read_text())
    assert load['passed'] and final['passed']
    selection_hash=hashlib.sha256((stage/'release-selection.json').read_bytes()).hexdigest()
    assert selection_hash==load['archive_manifest_sha256']==final['archive_manifest_sha256']
    by_name={r['name']:r for r in selection['packages']}
    for row in candidates['packages']:
        tested=by_name[row['name']]
        assert tested['version']==row['version']
        row['archive']=tested['source']
        row['sha256']=tested['sha256']
        row['bytes']=Path(row['archive']).stat().st_size
        row['engine_tested']=True
        row['package_load_receipt']=a.stage+'/packages-01.receipt.json'
        row['final_data_receipt']=a.stage+'/packages-final-data.receipt.json'
    candidates.update(exact_engine='2.1.23',archive_manifest_sha256=selection_hash,
                      required_selection=selection['packages'],published=False,
                      release_accepted=False)
    (a.run/'audit/release-package-candidates.json').write_text(json.dumps(candidates,indent=2),encoding='utf-8')
    a.output.mkdir(parents=True,exist_ok=True)
    (a.output/'RELEASE_PACKAGES.json').write_text(json.dumps(candidates,indent=2),encoding='utf-8')
    text=['# ESIR 1.4.0 release candidates','',
          'Status: all 12 candidate ZIPs passed the combined exact Factorio 2.1.23 load,',
          'fresh-save and 600-tick smoke test. All 35 selected files were actual ZIPs.',
          'The archive-only final-data dump also passes all 24 crystal contracts and',
          'matches the accepted core26 compact gameplay inventory except for the',
          'explicitly approved native Quality recipe-buffer changes and removal of',
          'the Rocket silo personal-travel grant. Native planet discoveries grant',
          'personal travel instead. The complete buffer',
          'field inventory is retained beside the final-data receipt.',
          'The rebuilt main ZIP also verifies native quality inheritance on all',
          'five ESIR locomotive bodies, four cargo wagons and three fluid wagons.',
          'Native silo quality modifiers are 0.2/0.45/0.15, with phase-aligned',
          'pollution and plumes verified separately across all five qualities.',
          '**Nothing in this candidate set has been published.** The user owns',
          'uploads. Acceptance and limits are in [the upgrade synopsis](UPGRADE_SYNOPSIS.md).','',
          'Publication order: the two new dependency continuations and NSBC; six',
          'graphics packs and two soundtracks; then the main mod. Preserve the old',
          '2.0 releases. Versions were checked against public Portal metadata on',
          '2026-10-27 and exceed both published and previously staged versions.','',
          '| Package | Version | Bytes | SHA-256 |','|---|---|---:|---|']
    for row in candidates['packages']:
        text.append(f"| `{row['name']}` | {row['version']} | {row['bytes']:,} | `{row['sha256']}` |")
    text+=['','The full 35-package selection, archive paths and hashes are retained in',
           '[RELEASE_PACKAGES.json](RELEASE_PACKAGES.json). License/source provenance,',
           'required replacements, conflicts and optional dispositions are recorded in',
           '[the dependency matrix](DEPENDENCY_MATRIX.md) and its JSON companion.',
           'The deer continuation retains its mixed upstream licensing; it is not',
           'represented as an entirely GPLv3 asset package. NSBC retains its captured',
           'MIT provenance separately from PEREL and newer upstream code.','',
           'Evidence under the protected run:',
           f'- `{a.stage}/packages-01.receipt.json` — native ZIP-only smoke.',
           f'- `{a.stage}/packages-final-data.receipt.json` — native final data.',
           f'- `{a.stage}/compact/` — gameplay, crystal and rolling-stock quality audit.',
           f'- Archive selection SHA-256: `{selection_hash}`.',
           '- Compact gameplay inventory SHA-256:',
           f"  `{final['inventory_sha256']}`.",
           f"- Approved native buffer field changes: {final['approved_buffer_records']}.",'']
    (a.output/'RELEASE_PACKAGES.md').write_text('\n'.join(text),encoding='utf-8')
    print(json.dumps(dict(packages=len(candidates['packages']),selected=len(by_name),published=False)))


if __name__=='__main__':
    main()
