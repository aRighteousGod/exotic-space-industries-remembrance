"""Measure Graphics 6/HD baselines and project a hash-bound pilot's new payload.

This never reports a projected 256-direction payload as a measured final ZIP.
The 15 percent allowance applies only to the new minigun payload. Production
acceptance still requires complete actual archives and native visual evidence.
"""
from __future__ import annotations
import argparse, hashlib, json, math, zipfile
from pathlib import Path

PACKS = {'sd': 'exotic-space-industries-remembrance-graphics-6',
         'hd': 'minigun-turret-HD'}
PACK_VERSION = '1.0.0'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def optimized_index(reports):
    result = {}
    for report in reports:
        document = json.loads(report.read_text(encoding='utf-8-sig'))
        for row in document['files']:
            source, output = Path(row['source']), Path(row['output'])
            assert digest(source) == row['source_sha256']
            assert digest(output) == row['sha256']
            assert row['decoded_rgba_equal'] and row['color_chunks_equal']
            key = str(source.resolve())
            if key not in result or row['after_bytes'] < result[key]['after_bytes']:
                result[key] = row
            content_key = 'sha256:' + row['source_sha256']
            if content_key not in result or row['after_bytes'] < result[content_key]['after_bytes']:
                result[content_key] = row
    return result


def payload(root, profile_name, record, optimized, icon_record=None):
    rows = []
    for family, data in record['families'].items():
        factor = 1 if family == 'base' else 256 / record.get('direction_count', 8)
        for item in data['files']:
            source = root / profile_name / 'images' / item['name']
            assert digest(source) == item['sha256']
            opt = optimized.get(str(source.resolve())) or optimized.get('sha256:' + item['sha256'])
            rows.append({'family': family, 'source': str(source.resolve()),
                         'measured_pilot_bytes': opt['after_bytes'] if opt else item['bytes'],
                         'original_bytes': item['bytes'], 'optimized': bool(opt),
                         'projection_factor': factor})
    if icon_record:
        for kind, icon in icon_record.items():
            source = root / profile_name / icon['path']
            opt = optimized.get(str(source.resolve())) or optimized.get('sha256:' + digest(source))
            rows.append({'family': 'icon_' + kind, 'source': str(source.resolve()),
                         'measured_pilot_bytes': opt['after_bytes'] if opt else source.stat().st_size,
                         'original_bytes': source.stat().st_size, 'optimized': bool(opt),
                         'projection_factor': 1})
    return {'rows': rows,
            'measured_pilot_png_bytes': sum(r['measured_pilot_bytes'] for r in rows),
            'projected_256_png_bytes': math.ceil(sum(r['measured_pilot_bytes'] * r['projection_factor'] for r in rows))}


def baseline(root, output):
    info_hash = digest(root / 'info.json')
    info = json.loads((root / 'info.json').read_text(encoding='utf-8-sig'))
    assert info['name'] == root.name and info['name'] in PACKS.values(), 'Unexpected baseline pack name'
    assert info['version'] == PACK_VERSION, 'Unexpected baseline pack version'
    prefix = info['name'] + '_' + info['version']
    archive = output / (prefix + '-existing-content-only.zip')
    rows = []
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9, allowZip64=False) as z:
        for source in sorted(root.rglob('*')):
            if not source.is_file():
                continue
            assert not source.is_symlink()
            before = digest(source)
            entry = zipfile.ZipInfo(prefix + '/' + source.relative_to(root).as_posix(),
                                    date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry._compresslevel = 9
            entry.external_attr = 0o100644 << 16
            with source.open('rb') as src, z.open(entry, 'w') as dst:
                for chunk in iter(lambda: src.read(1024 * 1024), b''):
                    dst.write(chunk)
            assert digest(source) == before
            rows.append({'path': source.relative_to(root).as_posix(), 'sha256': before,
                         'bytes': source.stat().st_size})
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
    assert digest(root / 'info.json') == info_hash, 'Pack metadata changed while measuring its baseline'
    return {'pack': info['name'], 'version': info['version'],
            'archive': str(archive.resolve()), 'zip_bytes': archive.stat().st_size,
            'sha256': digest(archive), 'zip_integrity_passed': True, 'files': rows,
            'scope': 'current existing ' + info['name'] + ' only; no new minigun assets'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--compiled', type=Path, required=True)
    parser.add_argument('--optimization', type=Path, nargs='+', required=True)
    parser.add_argument('--shadow-candidates', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo, output = args.repo.resolve(), args.output.resolve()
    assert output.is_relative_to(repo) and output.parts[len(repo.parts)] in ('output', '.factorio-qc', 'temp')
    assert not output.exists() or not any(output.iterdir()), 'Choose a fresh output directory; prior reports are retained'
    output.mkdir(parents=True, exist_ok=True)
    compiled = json.loads((args.compiled / 'metadata.json').read_text(encoding='utf-8-sig'))
    optimized = optimized_index(args.optimization)
    baselines = {profile: baseline(repo / pack, output) for profile, pack in PACKS.items()}
    report = {'schema': 'esir.minigun.pilot-budget.v3', 'generator_sha256': digest(Path(__file__)),
              'compiled_metadata_sha256': digest(args.compiled / 'metadata.json'),
              'compiled_root': str(args.compiled.resolve()),
              'optimization_inputs': [{'path': str(path.resolve()), 'sha256': digest(path)} for path in args.optimization],
              'status': 'pilot_projection_not_final_archive_measurement',
              'actual_direction_count': len(compiled['direction_indices']), 'target_direction_count': 256,
              'archive_cap_bytes': 256_000_000, 'new_payload_allowance_fraction': .15,
              'pack_baselines': baselines,
              'allocation': 'All SD minigun colors, complete shadows and icons in Graphics 6; all HD payload in one HD archive',
              'profiles': {}, 'separated_shadow_candidates': {}}
    for name, profile in compiled['profiles'].items():
        data = payload(args.compiled, name, profile, optimized, profile['icons'])
        colors = sum(r['measured_pilot_bytes'] * r['projection_factor'] for r in data['rows'] if r['family'] != 'shadow')
        projected = data['projected_256_png_bytes']
        data['projected_colors_and_icons_bytes'] = math.ceil(colors)
        data['projected_with_allowance_bytes'] = math.ceil(projected * 1.15)
        data['pack'] = PACKS[name]
        data['baseline_zip_bytes'] = baselines[name]['zip_bytes']
        data['projected_whole_bytes'] = baselines[name]['zip_bytes'] + projected
        data['preliminary_gate_bytes'] = baselines[name]['zip_bytes'] + data['projected_with_allowance_bytes']
        data['preliminary_gate_passed'] = data['preliminary_gate_bytes'] < report['archive_cap_bytes']
        report['profiles'][name] = data
    if args.shadow_candidates:
        shadows = json.loads((args.shadow_candidates / 'metadata.json').read_text(encoding='utf-8-sig'))
        report['shadow_metadata_sha256'] = digest(args.shadow_candidates / 'metadata.json')
        for name, profile in shadows['profiles'].items():
            profile['direction_count'] = len(compiled['direction_indices'])
            data = payload(args.shadow_candidates, name, profile, optimized)
            data['native_eligible'] = False
            data['projected_colors_plus_separated_shadows_bytes'] = (
                report['profiles'][name]['projected_colors_and_icons_bytes'] + data['projected_256_png_bytes'])
            total = math.ceil(data['projected_colors_plus_separated_shadows_bytes'] * 1.15)
            data['pack'] = PACKS[name]
            data['baseline_zip_bytes'] = baselines[name]['zip_bytes']
            data['preliminary_gate_bytes'] = total + baselines[name]['zip_bytes']
            data['preliminary_gate_passed'] = data['preliminary_gate_bytes'] < report['archive_cap_bytes']
            report['separated_shadow_candidates'][name] = data
    report['limitations'] = [
        'Pilot PNGs and the actual existing-content Graphics 6 and HD baseline ZIPs were measured, including both info.json files.',
        'Linear 8-to-256 projection is neither a measured full archive nor a mathematical lower bound.',
        'Projected PNG bytes are a payload proxy, not ZIP bytes: new ZIP entry headers, filenames and compression interaction are not measured here.',
        'The 15 percent allowance applies only to projected new payload; it is a preliminary margin, not a mathematical bound on ZIP overhead.',
        'Full-direction crops, ownership masks and PNG compression may change.',
        'Separated shadow candidates require a passed native reconstruction report.',
        'Final production ZIPs must count all icons, metadata, filenames and current pack content.']
    (output / 'pilot-budget.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'pack_baseline_zip_bytes': {PACKS[name]: value['zip_bytes'] for name, value in baselines.items()},
                      'profiles': {name: {k: v for k, v in p.items() if k not in ('rows',)} for name, p in report['profiles'].items()},
                      'separated_shadow_candidates': {name: {k: v for k, v in p.items() if k not in ('rows',)} for name, p in report['separated_shadow_candidates'].items()}}))


if __name__ == '__main__':
    main()
