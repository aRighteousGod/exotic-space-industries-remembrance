"""Reconcile local release evidence without publishing or changing Git state."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--stage', default='package-core-24')
    parser.add_argument('--installation', type=Path, help='Optional verified real-folder installation run')
    args = parser.parse_args()
    run, output = args.run, args.output
    packages = read(output / 'RELEASE_PACKAGES.json')
    assert len(packages['packages']) == 12
    package_files = 0
    for row in packages['packages']:
        archive = Path(row['archive'])
        assert digest(archive) == row['sha256'], archive
        manifest_path = archive.with_suffix('.manifest.json')
        if not manifest_path.exists():
            assert row['name'] == 'zzz-nonstandard-beacons-continued'
            manifest_path = archive.parent / 'manifest.json'
        manifest = read(manifest_path)
        with zipfile.ZipFile(archive) as package:
            prefix = row['name'] + '_' + row['version'] + '/'
            assert len(package.namelist()) == len(manifest['files'])
            for item in manifest['files']:
                data = package.read(prefix + item['path'])
                assert hashlib.sha256(data).hexdigest() == item['sha256']
                if 'source' in manifest:
                    assert digest(Path(manifest['source']) / item['path']) == item['sha256'], item['path']
                package_files += 1
    ledger = read(run / 'audit/reviewed/api-differences.json')
    assert len(ledger['entries']) == 1757
    evidence_files = set()
    for row in ledger['entries']:
        assert row.get('disposition') and not any(word in row['disposition'] for word in ('pending', '-open'))
        assert row.get('evidence'), row['path']
        for evidence in row['evidence']:
            if 'receipt' in evidence:
                path = run / evidence['receipt']
                assert digest(path) == evidence['receipt_sha256'], path
                evidence_files.add(evidence['receipt'])
    sources = read(run / 'audit/reviewed/source-manifest.json')
    for path, checksum in sources.items():
        assert digest(Path(path)) == checksum, path
    defaults = read(run / 'audit/default-controls-final.json')
    assert defaults['application_version'] == '2.1.23' and len(defaults['rows']) == 143
    baseline = read(run / 'baseline/worktree-manifest.json')
    excluded = [row for row in baseline if row['path'].startswith('minigun-turret-HD')]
    assert len(excluded) == 211
    for row in excluded:
        assert digest(Path(row['path'])) == row['sha256'], row['path']
    receipts = [
        args.stage + '/packages-01.receipt.json',
        args.stage + '/packages-final-data.receipt.json',
        'rocket-quality-21/rendered-01.receipt.json',
        'rocket-quality-21/reload-during-01.receipt.json',
        'rocket-migration-21/migration-ignition-01.receipt.json',
        'rocket-migration-21/migration-ascent-01.checkpoint.json',
        'rocket-migration-21/second-load-01.receipt.json',
        'native-buffers-21/native-02.receipt.json',
        'native-buffers-21/reload-01.receipt.json',
        'crystal-wire-21/native-05.receipt.json',
        'crystal-wire-21/reload-02.receipt.json',
        'orbital-delivery-21/native-02.receipt.json',
        'orbital-client-21/client-05.receipt.json',
        'orbital-client-21/client-reload-01.receipt.json',
        'optional-combination-22/combination-02.receipt.json',
        'audit/rocket-quality-render-review.json',
    ]
    for relative in receipts:
        assert read(run / relative)['passed'], relative
        evidence_files.add(relative)
    # Check focused native owner evidence against final shipping bytes, even
    # when a fixture predates unrelated changes in a different subsystem.
    owner_evidence = {
        'rocket-quality-21/rendered-01.source-manifest.json': ['rocket-launch-pollution'],
        'orbital-delivery-21/native-02.source-manifest.json': ['orbital-logistics'],
        'crystal-wire-21/reload-02.source-manifest.json': ['crystal-accumulator'],
    }
    for relative, owners in owner_evidence.items():
        manifest = {key.replace('\\', '/'): value for key, value in read(run / relative).items()}
        for owner in owners:
            path = 'exotic-space-industries-remembrance/scripts/control/' + owner + '.lua'
            checksum = digest(Path(path))
            if owner == 'rocket-launch-pollution':
                # Reproduce only the exact observational hooks used by the
                # retained adapter; compare the resulting complete owner bytes.
                instrumented = Path(path).read_text(encoding='utf-8')
                instrumented = instrumented.replace('surface.create_trivial_smoke{', 'rocket_qc_smoke(surface){')
                instrumented = instrumented.replace('surface.pollute(launch.position, amount, LAUNCH_POLLUTION_SOURCE)',
                    'rocket_qc_pollute(surface, launch.position, amount, LAUNCH_POLLUTION_SOURCE, current_tick)')
                instrumented = instrumented.replace('return model', 'model._qc_retaliation = try_form_retaliation\nreturn model')
                # stage_rocket_quality uses Path.write_text with native newline
                # translation, so its recorded Windows file has CRLF bytes.
                checksum = hashlib.sha256(instrumented.replace('\n', os.linesep).encode('utf-8')).hexdigest()
            assert checksum == manifest[path], (relative, path)
    preflight = read(run / 'audit/preflight-final.json')
    failed = [row for row in preflight['checks'] if row['status'] == 'failed']
    assert len(failed) == 1 and failed[0]['name'] == 'encoding-health', failed
    assert len(failed[0]['errors']) == 1 and 'scripts/qc/singularity-lance/angular-results.json' in failed[0]['errors'][0].replace('\\', '/')
    matrix = read(output / 'DEPENDENCY_MATRIX.json')
    assert matrix['original_count'] == len(matrix['entries']) == 50
    assert set(matrix['excluded_conflicts']) == {'TerrainEvolution', 'TerrainEvolution2'}
    combination = read(run / 'optional-combination-22/release-selection.json')
    combined_names = set(combination['optional_roots'])
    matrix['combined_smoke'] = dict(passed=True, engine='2.1.23', tick=600,
        receipt='optional-combination-22/combination-02.receipt.json',
        receipt_sha256=digest(run / 'optional-combination-22/combination-02.receipt.json'),
        optional_roots=sorted(combined_names), required_closure=combination['required_closure'],
        packages=combination['packages'],
        limits='Startup, final-data crystals and 600 ticks only; optional progression and save migration remain unaccepted')
    for row in matrix['entries']:
        if row['selected'] in combined_names:
            row['combined_smoke'] = 'passed'
            row['combined_smoke_receipt'] = matrix['combined_smoke']['receipt']
    (output / 'DEPENDENCY_MATRIX.json').write_text(json.dumps(matrix, indent=2), encoding='utf-8')
    final = read(run / args.stage / 'packages-final-data.receipt.json')
    changes = read(run / args.stage / 'compact/approved-native-buffer-changes.json')
    assert len(changes) == final['approved_buffer_records'] == 1581
    assert final['native_platform_travel'] == dict(rocket_silo=False,
        planet_discovery_vulcanus=True, planet_discovery_gleba=True, planet_discovery_fulgora=True)
    installation = None
    if args.installation:
        live = args.installation
        install = read(live / 'installation.receipt.json')
        validation = read(live / 'installed-validation.receipt.json')
        settings = read(live / 'settings-conversion.receipt.json')
        selection = read(live / 'release-selection.json')
        assert install['passed'] and validation['passed'] and settings['passed']
        assert validation['enabled'] == selection['enabled_count'] == 95
        assert validation['archives'] == len(selection['packages']) == 90
        assert validation['settings_bytes_stable_after_conversion']
        for row in selection['packages']:
            assert digest(Path(install['mod_directory']) / Path(row['staged']).name) == row['sha256']
        for filename, checksum in selection['before'].items():
            assert digest(live / 'before' / filename) == checksum
        assert digest(Path(install['mod_directory']) / 'mod-list.json') == validation['mod_list_sha256']
        assert digest(Path(install['mod_directory']) / 'mod-settings.dat') == validation['settings_sha256']
        drill = read(live / 'drill-compatibility-03.fixture.json')
        assert drill['passed'] and len(drill['replacements']) == 4
        receipts_live = ['installation.receipt.json', 'installed-validation.receipt.json',
            'settings-conversion.receipt.json', 'release-selection.json',
            'selection-02.receipt.json', 'drill-compatibility-03.receipt.json',
            'drill-compatibility-03.fixture.json']
        installation = dict(mod_directory=install['mod_directory'], enabled=95, archives=90,
            existing_saves_touched=False, settings_preferences_preserved=True,
            evidence={str(live / name):digest(live / name) for name in receipts_live})
    synopsis = (output / 'UPGRADE_SYNOPSIS.md').read_text(encoding='utf-8')
    assert 'Status: local core release accepted' in synopsis
    assert 'Status: implementation in progress' not in synopsis
    # Keep an exact review artifact including pre-existing dirty work. No staging,
    # reset, commit or source cleanup is performed.
    for name, arguments in [('final-working.patch', ['diff', '--binary']),
                            ('final-status.bin', ['status', '--porcelain=v1', '-z'])]:
        result = subprocess.run(['git', *arguments], capture_output=True, check=True)
        (run / 'audit' / name).write_bytes(result.stdout)
    packages['release_accepted'] = True
    packages['acceptance_scope'] = 'Local core 2.1.23 release; user owns uploads; optional migration limits in dependency matrix'
    for target in (output / 'RELEASE_PACKAGES.json', run / 'audit/release-package-candidates.json'):
        target.write_text(json.dumps(packages, indent=2), encoding='utf-8')
    handoffs = {path.name: digest(path) for path in sorted(output.iterdir())
                if path.is_file() and path.name != 'RELEASE_RECONCILIATION.json'}
    result = dict(passed=True, exact_engine='2.1.23', published=False, committed=False,
        release_scope=packages['acceptance_scope'], package_count=12, verified_package_files=package_files,
        source_lua_files=len(sources), preserved_excluded_files=len(excluded), api_rows=1757,
        default_controls=143, optional_entries=50, inventory_sha256=final['inventory_sha256'],
        native_platform_travel=final['native_platform_travel'],
        native_buffer_fields=dict(Counter(row['kind'] for row in changes)),
        native_buffer_recipes=len({row['recipe'] for row in changes}),
        evidence={relative:digest(run / relative) for relative in sorted(evidence_files)},
        handoffs=handoffs, preflight_exception=failed[0]['errors'],
        live_installation=installation,
        final_diff_sha256=digest(run / 'audit/final-working.patch'),
        final_status_sha256=digest(run / 'audit/final-status.bin'),
        limits=['No publication', 'No audio listening', 'No physical mouse-input certification',
                'Multiplayer evidence is one native peer rejoin, not every subsystem or optional combination',
                'Performance evidence is representative focused workloads, not a full megabase',
                'Unsupported optional content saves remain on 2.0'])
    (output / 'RELEASE_RECONCILIATION.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({key:result[key] for key in ('passed','package_count','verified_package_files',
        'source_lua_files','preserved_excluded_files','api_rows','optional_entries','native_buffer_fields','native_buffer_recipes')}))


if __name__ == '__main__':
    main()
