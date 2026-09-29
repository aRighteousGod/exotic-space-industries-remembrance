"""Audit Full Hybrid evidence after the documented current-source QC runs.

No engine process is launched. Raw logs remain ignored; the compact JSON report
retains repeat measurements, phase attribution, source hashes and manual limits.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import mmap
from pathlib import Path
import re
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path('.factorio-qc/cu/l'))
parser.add_argument('--output', type=Path, default=Path('scripts/qc/singularity-lance/hybrid-results.json'))
parser.add_argument('--allow-incomplete', action='store_true')
args = parser.parse_args()
main = Path('exotic-space-industries-remembrance')
report = {'engine': '2.0.77', 'runtime_schema': 12, 'map_seed': 410728,
          'limits': ['Gameplay visual acceptance is manual.', 'Headless timings omit GPU/render cost.',
                     'Whole-engine means include other enabled mods and fixture overhead.',
                     'Profile phases are nested; only shot plus update-total form the lance total.'],
          'validation': {}, 'benchmarks': {}, 'profiles': {}}


def require_file(path):
    if path.exists():
        return True
    if not args.allow_incomplete:
        raise AssertionError(f'missing evidence: {path}')
    return False


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime_code(path):
    return '\n'.join(line for line in path.read_text('utf-8').splitlines() if not line.startswith('---@'))


def stats(values):
    ordered = sorted(values)
    return {'mean_ms': statistics.mean(values), 'median_ms': statistics.median(values),
            'p95_ms': ordered[math.ceil(.95 * len(ordered)) - 1], 'max_ms': max(values)}


report['wrapper_checks'] = {}
for filename in ['preflight-origin-material.json', 'qc-fast.json', 'qc-assets-origin-material.json']:
    path = Path('.factorio-qc/hybrid') / filename
    if require_file(path):
        result = json.loads(path.read_text('utf-8-sig'))
        checks = result.get('checks', result.get('summary', {}).get('results', []))
        errors = [error for check in checks for error in check.get('errors', [])]
        warnings = [warning for check in checks for warning in check.get('warnings', [])]
        assert not errors, (filename, errors)
        # Keep raw console text in its source artifact. The Windows wrapper can
        # mis-decode Unicode log symbols; summaries need only status and counts.
        report['wrapper_checks'][filename] = {'status': result['overall_status'],
            'errors': errors, 'warning_count': len(warnings)}


for suffix in ['2-lean', '2-standard', '2-cinematic', '2-maximal', '2-unbounded',
               '-noscaling', '-flatten', '-noscalingflatten']:
    folder = args.root / ('hybrid-final' + suffix)
    log = folder / 'benchmark.log'
    if not require_file(log):
        continue
    body = log.read_text('utf-8')
    assert 'LANCE_QC ALL_COMPLETE' in body, folder
    assert runtime_code(folder / 'mods' / main / 'scripts/control/singularity-lance.lua') == runtime_code(main / 'scripts/control/singularity-lance.lua'), folder
    report['validation'][folder.name] = {'assertions': body.count('LANCE_QC PASS'),
        'runtime_sha256': sha(folder / 'mods' / main / 'scripts/control/singularity-lance.lua'),
        'technology_rows': re.findall(r'LANCE_TECH ([^\n]+)', body),
        'overload_results': re.findall(r'LANCE_QC PASS visual overload (?:first|total) damage[^\n]+', body)}
for name in ['hybrid-reload11-01', 'hybrid-reload12']:
    log = args.root / name / 'benchmark.log'
    if require_file(log):
        body = log.read_text('utf-8')
        assert 'LANCE_QC RELOAD_COMPLETE' in body, name
        report['validation'][name] = {'assertions': body.count('LANCE_QC PASS')}

# Dedicated source openings change only native animation selection.
# Keep it explicit: the serial benchmark series used the preceding frozen art
# selection, with identical runtime, frame dimensions, counts and segment bounds.
prototype = Path('prototypes/alien-system/singularity-lance-upgrades.lua')
report['source_opening'] = {
    'benchmark_prototype_sha256': sha(Path('.factorio-qc/hybrid/after-source') / prototype),
    'final_prototype_sha256': sha(main / prototype),
    'benchmark_limit': 'Dedicated opening animations added after benchmark freeze; identical runtime and frame dimensions, no new entities or layers; 7.5 MiB additional RGBA atlas data.',
    'runs': {},
}
for fidelity in ['lean', 'standard']:
    folder = args.root / ('hybrid-origin-material-' + fidelity)
    log = folder / 'benchmark.log'
    if require_file(log):
        body = log.read_text('utf-8')
        assert 'LANCE_QC ALL_COMPLETE' in body, folder
        assert sha(folder / 'mods' / main / prototype) == sha(main / prototype), folder
        assert body.count('matching source material, original bloom and native terrain lighting') == 6
        report['source_opening']['runs'][fidelity] = {'assertions': body.count('LANCE_QC PASS'),
            'visual_prototypes': 6}

scenes = ['no-lance', 'idle', 'direct', 'normal-power', 'dense', 'diagonal', 'research']
for scene in scenes:
    row = {'ticks_per_run': 600, 'discarded_full_warmup_runs': 1, 'measured_runs': 5}
    for version in ['before', 'after']:
        folder = args.root / f'hybrid-bench-{version}-{scene}'
        log = folder / 'benchmark-stdout.txt'
        if not require_file(log):
            continue
        body = log.read_text('utf-8')
        samples = [float(value) for value in re.findall(r'avg: ([\d.]+) ms', body)]
        assert len(samples) == 6, (folder, samples)
        assert 'LANCE_QC FAIL' not in body
        # The no-lance pair predates the final-tick population assertion; its
        # identical frozen helpers create no targets. Every populated pair has it.
        if scene != 'no-lance':
            assert body.count('benchmark target population preserved') >= 6
        row[version] = {'all_run_means_ms': samples, 'median_ms': statistics.median(samples[1:]),
            'min_ms': min(samples[1:]), 'max_ms': max(samples[1:]),
            'runtime_sha256': sha(folder / 'mods' / main / 'scripts/control/singularity-lance.lua')}
    if 'before' in row and 'after' in row:
        before_log = (args.root / f'hybrid-bench-before-{scene}/benchmark.log').read_text('utf-8')
        after_log = (args.root / f'hybrid-bench-after-{scene}/benchmark.log').read_text('utf-8')
        assert re.findall(r'LANCE_TECH ([^\n]+)', before_log) == re.findall(r'LANCE_TECH ([^\n]+)', after_log), scene
        row['technology_prices_science_prerequisites_unchanged'] = True
        row['median_change_percent'] = 100 * (row['after']['median_ms'] / row['before']['median_ms'] - 1)
        report['benchmarks'][scene] = row
    folder = args.root / f'hybrid-profile-{scene}'
    log = folder / 'benchmark.log'
    if not require_file(log):
        continue
    body = log.read_text('utf-8')
    phases = defaultdict(lambda: defaultdict(float))
    for phase, tick, ms in re.findall(r'SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms', body):
        if 120 <= int(tick) < 600:
            phases[phase][int(tick)] += float(ms)
    result = {phase: stats([ticks.get(tick, 0) for tick in range(120, 600)]) for phase, ticks in phases.items()}
    result['lance_total'] = stats([phases['shot'].get(tick, 0) + phases['update-total'].get(tick, 0) for tick in range(120, 600)])
    snapshots = [json.loads(line.split('LANCE_BENCH SNAPSHOT ', 1)[1]) for line in body.splitlines() if 'LANCE_BENCH SNAPSHOT ' in line]
    assert snapshots, scene
    result['counters'] = snapshots[-1]['counters']
    if scene in ['idle', 'no-lance', 'research']:
        for key in ['shots', 'penetration_queries', 'area_queries', 'wound_cues', 'status_refreshes', 'force_cache_refreshes']:
            assert not result['counters'].get(key, 0), (scene, key)
    report['profiles'][scene] = result

# Locale parity includes repeated parameters, not just unique placeholder sets.
locale_rows = {}
for language in ['en', 'fr', 'ja', 'pl', 'ru', 'zh-CN', 'zh-TW']:
    rows = {}
    for filename in ['singularity-lance.cfg', 'singularity-lance-upgrades.cfg']:
        raw = (main / 'locale' / language / filename).read_bytes()
        assert not raw.startswith(b'\xef\xbb\xbf')
        content = raw.decode('utf-8')
        assert '\ufffd' not in content
        section = ''
        for line in content.splitlines():
            if line.startswith('['):
                section = line
            elif '=' in line and not line.startswith(';'):
                key, value = line.split('=', 1)
                token = section + key
                assert token not in rows, (language, token)
                rows[token] = Counter(re.findall(r'__\d+__', value))
    locale_rows[language] = rows
assert all(rows == locale_rows['en'] for rows in locale_rows.values())
report['locale'] = {'languages': 7, 'entries': sum(map(len, locale_rows.values())), 'parity': 'passed'}

art_dir = main / 'graphics/singularity-lance-upgrades/prismatic-liturgy'
legacy_dir = Path('.factorio-qc/hybrid/before-source/graphics/singularity-lance-upgrades/prismatic-liturgy')
assert all(sha(path) == sha(art_dir / path.name) for path in legacy_dir.glob('*.png'))
manifest_path = Path('.codex/esir/asset-generators/singularity-lance/prismatic-redesign/hybrid-manifest.json')
manifest = json.loads(manifest_path.read_text('utf-8'))
config_source = (main / 'lib/singularity-lance-config.lua').read_text('utf-8')
for kind in ['collapse', 'testament']:
    section = re.search(r'singularity_lance_config\.' + kind + r' = \{([^}]+)', config_source).group(1)
    fields = dict((key, float(value)) for key, value in re.findall(r'(\w+)\s*=\s*([\d.]+)', section))
    # Testament's nested echo also contains radius: restrict to its first pulse.
    if kind == 'testament':
        section = section.split('echo =')[0]
        fields = dict((key, float(value)) for key, value in re.findall(r'(\w+)\s*=\s*([\d.]+)', section))
    for part in ['warning', 'impact']:
        sequence = manifest['sequences'][kind + '-concentrated-' + part]
        assert sequence['outer_radius'] == fields['radius']
        assert sequence['core_ratio'] == fields['core_radius'] / fields['radius']
for sequence in manifest['sequences'].values():
    for layer in sequence['layers']:
        assert sha(art_dir / layer['file']) == layer['sha256']
report['art'] = {'legacy_pngs_unchanged': len(list(legacy_dir.glob('*.png'))),
                 'new_pngs': 8, 'new_frames': 84, 'added_rgba_atlas_mib': manifest['rgba_atlas_bytes'] / 1024**2}
origin_path = manifest_path.with_name('origin-manifest.json')
origin = json.loads(origin_path.read_text('utf-8'))
for sequence in origin['sequences'].values():
    for layer in sequence['layers']:
        assert sha(art_dir / layer['file']) == layer['sha256']
report['origin_art'] = {'new_pngs': 4, 'new_frames': 32,
    'added_rgba_atlas_mib': origin['rgba_atlas_bytes'] / 1024**2,
    'frame_size': origin['frame_size'], 'animation_speed': origin['animation_speed']}
report['art']['new_pngs'] += 4
report['art']['new_frames'] += 32
report['art']['added_rgba_atlas_mib'] += report['origin_art']['added_rgba_atlas_mib']

# Extract small prototype records without loading the two-gigabyte data dump.
dump = args.root / 'hybrid-data-first/script-output/data-raw-dump.json'
if require_file(dump):
    records = {}
    with dump.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as mapped:
        decoder = json.JSONDecoder()
        for key in ['axial-rupture', 'wound-memory', 'terminal-collapse', 'black-hole-testament']:
            name = 'ei-singularity-lance-' + key
            match = re.search(rb'"' + name.encode() + rb'"\s*:\s*\{', mapped)
            assert match, name
            start = mapped.find(b'{', match.start())
            record = decoder.raw_decode(mapped[start:start + 131072].decode('utf-8', errors='ignore'))[0]
            assert record['type'] == 'technology'
            records[name] = {'prerequisites': record['prerequisites'], 'unit': record['unit'], 'effects': record['effects']}
    report['final_data_raw'] = records

dirty = json.loads(Path('.factorio-qc/hybrid/before-dirty.json').read_text('utf-8-sig'))
unrelated = [entry for entry in dirty if 'singularity-lance' not in entry['path']]
assert all(sha(Path(entry['path'])).upper() == entry['hash'] for entry in unrelated)
report['unrelated_dirty_files_preserved'] = len(unrelated)
report['source_hashes'] = {str(path): sha(path) for path in [main / 'lib/singularity-lance-config.lua',
    main / 'scripts/control/singularity-lance.lua', main / 'scripts/control/informatron.lua',
    main / 'prototypes/alien-system/singularity-lance-upgrades.lua', Path('scripts/qc/singularity-lance/control.lua')]}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'validation_runs': len(report['validation']), 'benchmark_scenes': len(report['benchmarks']),
                  'profile_scenes': len(report['profiles']), 'output': str(args.output)}, indent=2))
