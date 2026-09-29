"""Summarize synchronized-sweep engine evidence; never launches Factorio.

Run after the final sweep2-verified/reload/after/profile series and original
sweep-before baseline described in sweep-verification.md. Raw logs stay ignored.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path('.factorio-qc/cu/l'))
parser.add_argument('--output', type=Path, default=Path('scripts/qc/singularity-lance/sweep-results.json'))
parser.add_argument('--allow-incomplete', action='store_true')
args = parser.parse_args()
main = Path('exotic-space-industries-remembrance')
CANDIDATE = 'sweep2'
report = {'engine': '2.0.77', 'schema': 13, 'seed': 410728,
          'timing_ticks': {'contact': 8, 'first': 38, 'echo': 68},
          'validation': {}, 'benchmarks': {}, 'profiles': {}, 'wrapper_checks': {},
          'limits': ['Gameplay and native tooltip appearance require manual review.',
                     'Headless timings omit GPU and rendering cost.',
                     'Whole-engine measurements include other mods and fixture overhead.',
                     'Phase profiles are nested: sum only shot and update-total for total lance work.']}


def read(path):
    if not path.exists():
        if args.allow_incomplete:
            return None
        raise AssertionError(f'Missing evidence: {path}')
    raw = path.read_bytes()
    body = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    if args.allow_incomplete and not body.strip():
        return None
    return body


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def code(path):
    return '\n'.join(line for line in path.read_text('utf-8').splitlines()
                     if not line.lstrip().startswith('--'))


def stats(values):
    return {'mean_ms': statistics.mean(values), 'median_ms': statistics.median(values),
            'p95_ms': sorted(values)[math.ceil(.95 * len(values))-1], 'max_ms': max(values)}


for name in ['standard', 'lean', 'cinematic', 'maximal', 'unbounded', 'noscaling', 'flatten', 'both']:
    folder = args.root / f'{CANDIDATE}-verified-{name}'
    body = read(folder / 'benchmark.log')
    if body is None:
        continue
    assert 'LANCE_QC ALL_COMPLETE' in body, folder
    runtime = Path('scripts/control/singularity-lance.lua')
    assert code(folder / 'mods' / main / runtime) == code(main / runtime), folder
    report['validation'][folder.name] = {'assertions': body.count('LANCE_QC PASS'),
        'runtime_sha256': sha(folder / 'mods' / main / runtime),
        'technology_rows': re.findall(r'LANCE_TECH ([^\n]+)', body)}

for name in ['11', '12', '13', '-flight']:
    folder = args.root / (CANDIDATE + '-reload' + name)
    body = read(folder / 'benchmark.log')
    if body is not None:
        assert 'LANCE_QC RELOAD_COMPLETE' in body, folder
        report['validation'][folder.name] = {'assertions': body.count('LANCE_QC PASS')}

for scene in ['no-lance', 'idle', 'direct', 'normal-power', 'dense', 'diagonal', 'research']:
    row = {'ticks_per_run': 600, 'discarded_warmup_runs': 1, 'measured_runs': 5}
    for version in ['before', 'after']:
        name = f'{"sweep" if version == "before" else CANDIDATE}-{version}-{scene}'
        if version == 'before' and scene == 'research':
            name += '-final'
        folder = args.root / name
        body = read(folder / 'benchmark-stdout.txt')
        if body is None:
            continue
        cfg = (folder / 'mods/zzz-lance-upgrade-qc/test-config.lua').read_text('utf-8')
        assert "mode='benchmark'" in cfg and 'ticks=600' in cfg and 'profile=false' in cfg, folder
        samples = [float(value) for value in re.findall(r'avg: ([\d.]+) ms', body)]
        if args.allow_incomplete and len(samples) < 6 and 'LANCE_QC FAIL' not in body:
            continue
        assert len(samples) == 6 and 'LANCE_QC FAIL' not in body, folder
        assert body.count('benchmark target population preserved') >= 6, folder
        if version == 'after':
            runtime = Path('scripts/control/singularity-lance.lua')
            assert code(folder / 'mods' / main / runtime) == code(main / runtime), folder
        row[version] = {'all_run_means_ms': samples, 'median_ms': statistics.median(samples[1:]),
                        'min_ms': min(samples[1:]), 'max_ms': max(samples[1:]),
                        'runtime_sha256': sha(folder / 'mods' / main / 'scripts/control/singularity-lance.lua')}
    if 'before' in row and 'after' in row:
        before_name = f'sweep-before-{scene}' + ('-final' if scene == 'research' else '')
        old = (args.root / before_name / 'benchmark.log').read_text('utf-8')
        new = (args.root / f'{CANDIDATE}-after-{scene}' / 'benchmark.log').read_text('utf-8')
        assert re.findall(r'LANCE_TECH ([^\n]+)', old) == re.findall(r'LANCE_TECH ([^\n]+)', new), scene
        row['technology_prices_science_prerequisites_unchanged'] = True
        row['median_change_percent'] = 100 * (row['after']['median_ms'] / row['before']['median_ms'] - 1)
        report['benchmarks'][scene] = row
    folder = args.root / f'{CANDIDATE}-profile-{scene}'
    body = read(folder / 'benchmark.log')
    if body is None:
        continue
    cfg = (folder / 'mods/zzz-lance-upgrade-qc/test-config.lua').read_text('utf-8')
    stdout = (folder / 'benchmark-stdout.txt').read_text('utf-8')
    assert 'ticks=600' in cfg and 'profile=true' in cfg and len(re.findall(r'avg: ([\d.]+) ms', stdout)) == 1, folder
    runtime = Path('scripts/control/singularity-lance.lua')
    assert code(folder / 'mods' / main / runtime) == code(main / runtime), folder
    phases = defaultdict(lambda: defaultdict(float))
    for phase, tick, ms in re.findall(r'SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms', body):
        if 120 <= int(tick) < 600:
            phases[phase][int(tick)] += float(ms)
    result = {phase: stats([ticks.get(tick, 0) for tick in range(120, 600)]) for phase, ticks in phases.items()}
    result['lance_total'] = stats([phases['shot'].get(tick, 0) + phases['update-total'].get(tick, 0)
                                 for tick in range(120, 600)])
    snapshots = [json.loads(line.split('LANCE_BENCH SNAPSHOT ', 1)[1])
                 for line in body.splitlines() if 'LANCE_BENCH SNAPSHOT ' in line]
    assert snapshots, scene
    result['counters'] = snapshots[-1]['counters']
    result['phase_window_ticks'] = [120, 599]
    result['counter_window_note'] = 'Counters reset at tick120 after that tick work; last snapshot is tick600.'
    if scene in ['no-lance', 'idle', 'research']:
        for key in ['shots', 'penetration_queries', 'area_queries', 'wound_cues', 'status_refreshes',
                    'force_cache_refreshes', 'contact_target_reads', 'sweep_steps']:
            assert not result['counters'].get(key, 0), (scene, key)
    report['profiles'][scene] = result

# Nearby repeated pairs investigate the direct-only regression above five percent.
# They retain the same warmup and five measured runs, plus a no-lance host control.
report['direct_investigation'] = {}
for scene in ['direct', 'no-lance']:
    row = {}
    for version in ['before', 'after']:
        folder = args.root / f'{CANDIDATE}-repeat-{version}-{scene}'
        body = read(folder / 'benchmark-stdout.txt')
        if body is None:
            continue
        samples = [float(value) for value in re.findall(r'avg: ([\d.]+) ms', body)]
        if args.allow_incomplete and len(samples) < 6:
            continue
        assert len(samples) == 6 and 'LANCE_QC FAIL' not in body, folder
        cfg = (folder / 'mods/zzz-lance-upgrade-qc/test-config.lua').read_text('utf-8')
        assert 'ticks=600' in cfg and 'profile=false' in cfg, folder
        assert body.count('benchmark target population preserved') >= 6, folder
        if version == 'after':
            runtime = Path('scripts/control/singularity-lance.lua')
            assert code(folder / 'mods' / main / runtime) == code(main / runtime), folder
        row[version] = {'all_run_means_ms': samples, 'median_ms': statistics.median(samples[1:]),
                        'min_ms': min(samples[1:]), 'max_ms': max(samples[1:])}
    if len(row) == 2:
        row['median_change_percent'] = 100 * (row['after']['median_ms'] / row['before']['median_ms'] - 1)
        report['direct_investigation'][scene] = row
folder = args.root / 'sweep-profile-before-direct'
body = read(folder / 'benchmark.log')
if body is not None:
    cfg = (folder / 'mods/zzz-lance-upgrade-qc/test-config.lua').read_text('utf-8')
    stdout = (folder / 'benchmark-stdout.txt').read_text('utf-8')
    assert 'ticks=600' in cfg and 'profile=true' in cfg and len(re.findall(r'avg: ([\d.]+) ms', stdout)) == 1, folder
    phases = defaultdict(lambda: defaultdict(float))
    for phase, tick, ms in re.findall(r'SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms', body):
        if 120 <= int(tick) < 600:
            phases[phase][int(tick)] += float(ms)
    report['direct_investigation']['baseline_lance_profile'] = stats([
        phases['shot'].get(tick, 0) + phases['update-total'].get(tick, 0) for tick in range(120, 600)])

locale_rows = {}
for lang in ['en', 'fr', 'ja', 'pl', 'ru', 'zh-CN', 'zh-TW']:
    rows = {}
    for filename in ['singularity-lance.cfg', 'singularity-lance-upgrades.cfg']:
        raw = (main / 'locale' / lang / filename).read_bytes()
        assert not raw.startswith(b'\xef\xbb\xbf')
        body = raw.decode('utf-8')
        assert '\ufffd' not in body
        section = ''
        for line in body.splitlines():
            if line.startswith('['):
                section = line
            elif '=' in line and not line.startswith(';'):
                key, value = line.split('=', 1)
                token = section + key
                assert token not in rows, (lang, token)
                rows[token] = Counter(re.findall(r'__\d+__', value))
                if token == '[lance-upgrades]status':
                    assert rows[token] == Counter({'__1__': 1}) and '\\n' not in value
    locale_rows[lang] = rows
assert all(rows == locale_rows['en'] for rows in locale_rows.values())
report['locale'] = {'languages': 7, 'entries': sum(map(len, locale_rows.values())), 'parity': 'passed'}
dispatch = (main / 'control.lua').read_text('utf-8')
assert dispatch.count('[ei_singularity_lance.script_trigger_effect_id] = ei_singularity_lance.on_script_trigger_effect') == 1
report['dispatch'] = 'One exact-ID lance owner; unrelated effects excluded before entering the module.'

for name in ['preflight-final', 'qc-fast', 'qc-assets', 'qc-runtime']:
    path = Path('.factorio-qc/sweep') / (name + '.json')
    body = read(path)
    if body is not None:
        result = json.loads(body)
        assert result['overall_status'] != 'failed', path
        report['wrapper_checks'][name] = {'status': result['overall_status'],
            'checks': [{'name': check.get('name'), 'status': check.get('status'),
                        'errors': check.get('errors', []), 'warning_count': len(check.get('warnings', []))}
                       for check in result.get('checks', result.get('summary', {}).get('results', []))]}

report['source_sha256'] = {str(path): sha(path) for path in [
    main / 'scripts/control/singularity-lance.lua', main / 'lib/singularity-lance-config.lua',
    main / 'prototypes/alien-system/singularity-lance.lua',
    Path('scripts/qc/singularity-lance/control.lua'), Path('scripts/qc/singularity-lance/sweep-cases.lua')]}
args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
lines = ['# Synchronized-sweep performance tables', '',
         'Generated by `analyze-sweep.py`; methods, warnings and manual limits are in',
         '[the verification report](sweep-verification.md). Whole-engine values are milliseconds per update.', '',
         '| Scene | Before median | Before five-run range | After median | After five-run range | Change |',
         '| --- | ---: | ---: | ---: | ---: | ---: |']
for scene, row in report['benchmarks'].items():
    old, new = row['before'], row['after']
    lines.append(f"| {scene} | {old['median_ms']:.3f} | {old['min_ms']:.3f}–{old['max_ms']:.3f} | "
                 f"{new['median_ms']:.3f} | {new['min_ms']:.3f}–{new['max_ms']:.3f} | {row['median_change_percent']:+.2f}% |")
lines += ['', 'Profile values below are candidate lance-script attribution, not whole-engine time.',
          'Phases are nested. Only `shot + update-total` is the total; do not add the other columns.', '',
          '| Scene | Total mean ms | Total p95 ms | Contact mean ms | Sweep mean ms | Contact light mean ms |',
          '| --- | ---: | ---: | ---: | ---: | ---: |']
for scene, row in report['profiles'].items():
    lines.append(f"| {scene} | {row['lance_total']['mean_ms']:.4f} | {row['lance_total']['p95_ms']:.4f} | "
                 + ' | '.join(f"{row.get(phase, {}).get('mean_ms', 0):.4f}" for phase in ['contact', 'sweep', 'contact-light']) + ' |')
lines += ['', '| Scene | Incision selection mean ms | Incision damage mean ms | First collapse mean ms | Echo mean ms | Core presentation mean ms | Decoration mean ms |',
          '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
for scene, row in report['profiles'].items():
    core = sum(row.get(phase, {}).get('mean_ms', 0) for phase in ['shot-core', 'impact-core'])
    values = [row.get(phase, {}).get('mean_ms', 0) for phase in ['incision-selection', 'incision-damage', 'collapse-first', 'collapse-echo']]
    values += [core, row.get('decoration', {}).get('mean_ms', 0)]
    lines.append('| ' + scene + ' | ' + ' | '.join(f'{value:.4f}' for value in values) + ' |')
if 'dense' in report['profiles']:
    p95 = report['profiles']['dense']['lance_total']['p95_ms']
    lines += ['', f'The dense 1 ms p95 objective is **{"met" if p95 <= 1 else "unmet"}**: measured {p95:.4f} ms.']
if report['direct_investigation']:
    lines += ['', '## Nearby paired repeats', '',
              '| Scene | Before median ms | After median ms | Change |', '| --- | ---: | ---: | ---: |']
    for scene in ['direct', 'no-lance']:
        row = report['direct_investigation'].get(scene)
        if row:
            lines.append(f"| {scene} | {row['before']['median_ms']:.3f} | {row['after']['median_ms']:.3f} | {row['median_change_percent']:+.2f}% |")
    old = report['direct_investigation'].get('baseline_lance_profile')
    new = report['profiles'].get('direct', {}).get('lance_total')
    if old and new:
        lines += ['', f"Direct lance-script attribution: baseline mean {old['mean_ms']:.4f} ms / p95 {old['p95_ms']:.4f} ms; "
                  f"candidate mean {new['mean_ms']:.4f} ms / p95 {new['p95_ms']:.4f} ms."]
args.output.with_name('sweep-performance.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(json.dumps({'assertions': sum(row['assertions'] for row in report['validation'].values()),
                  'benchmarks': {key: round(value['median_change_percent'], 2) for key, value in report['benchmarks'].items()},
                  'dense_p95_ms': report['profiles'].get('dense', {}).get('lance_total', {}).get('p95_ms'),
                  'locale': report['locale']}, indent=2))
