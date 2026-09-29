"""Read matched schema13/14 evidence; never launch Factorio or alter old reports."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--root', type=Path, default=Path('.factorio-qc/cu/l'))
p.add_argument('--allow-incomplete', action='store_true')
a = p.parse_args()
main = Path('exotic-space-industries-remembrance')
out = Path('scripts/qc/singularity-lance')
scenes = ['no-lance', 'idle', 'direct', 'normal-power', 'dense', 'diagonal', 'research', 'wide-native', 'wide-burst']
report = {'complete':not a.allow_incomplete, 'engine': '2.0.77', 'schema': 14, 'seed': 410728, 'validation': {}, 'benchmarks': {},
          'profiles': {}, 'wrapper_checks': {}, 'limits': ['Manual gameplay review remains outstanding.',
          'Headless benchmarks exclude GPU/render cost; whole-engine timings include other mods and fixture work.',
          'Profiler phases are nested. Only shot + update-total represent total lance work.']}


def read(path):
    if not path.exists():
        if a.allow_incomplete:
            return None
        raise AssertionError(f'Missing {path}')
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def code(path):
    return '\n'.join(x for x in path.read_text('utf-8').splitlines() if not x.lstrip().startswith('--'))


def parity(folder):
    for relative in ['scripts/control/singularity-lance.lua', 'lib/singularity-lance-config.lua', 'lib/runtime-scheduler.lua']:
        assert code(folder / 'mods' / main / relative) == code(main / relative), (folder, relative)


def stats(values):
    return {'mean_ms': statistics.mean(values), 'p95_ms': sorted(values)[math.ceil(.95*len(values))-1], 'max_ms': max(values)}


for name in ['standard', 'lean', 'cinematic', 'maximal', 'unbounded', 'noscaling', 'flatten', 'both',
             'reload11', 'reload12', 'reload13', 'reload13-flight', 'reload13-turn', 'reload14', 'reload14-flight', 'reload14-wide']:
    folder = a.root / (('angular-verified-' if name.startswith('reload') else 'angular-final-') + name)
    body = read(folder / 'benchmark.log')
    if body is None:
        continue
    marker = 'LANCE_QC RELOAD_COMPLETE' if name.startswith('reload') else 'LANCE_QC ALL_COMPLETE'
    assert marker in body and 'LANCE_QC FAIL' not in body, folder
    parity(folder)
    report['validation'][name] = {'assertions': body.count('LANCE_QC PASS'),
                                'technology_rows': re.findall(r'LANCE_TECH ([^\n]+)', body)}

for scene in scenes:
    row = {}
    for version in ['before', 'after']:
        folder = a.root / f'angular-{version}-{scene}'
        body = read(folder / 'benchmark-stdout.txt')
        if body is None:
            continue
        samples = [float(x) for x in re.findall(r'avg: ([\d.]+) ms', body)]
        if a.allow_incomplete and len(samples) < 6:
            continue
        assert len(samples) == 6 and body.count('benchmark target population preserved') >= 6, folder
        assert 'LANCE_QC FAIL' not in body, folder
        cfg = (folder / 'mods/zzz-lance-upgrade-qc/test-config.lua').read_text('utf-8')
        assert 'ticks=600' in cfg and 'profile=false' in cfg and 'no_counters=true' in cfg, folder
        if version == 'after':
            parity(folder)
        row[version] = {'all_run_means_ms': samples, 'median_ms': statistics.median(samples[1:]),
                        'min_ms': min(samples[1:]), 'max_ms': max(samples[1:]),
                        'runtime_sha256': sha(folder / 'mods' / main / 'scripts/control/singularity-lance.lua')}
    if len(row) == 2:
        old, new = [a.root / f'angular-{v}-{scene}' for v in ['before', 'after']]
        for filename in ['control.lua', 'data-final-fixes.lua', 'settings-updates.lua']:
            assert sha(old / 'mods/zzz-lance-upgrade-qc' / filename) == sha(new / 'mods/zzz-lance-upgrade-qc' / filename)
        assert re.findall(r'LANCE_TECH ([^\n]+)', read(old/'benchmark.log')) == re.findall(r'LANCE_TECH ([^\n]+)', read(new/'benchmark.log'))
        row['median_change_percent'] = 100*(row['after']['median_ms']/row['before']['median_ms']-1)
        row['ticks_per_run'], row['discarded_warmup_runs'], row['measured_runs'] = 600, 1, 5
        report['benchmarks'][scene] = row

for label in scenes + ['before-direct', 'before-normal-power', 'before-wide-native', 'before-wide-burst']:
    folder = a.root / f'angular-profile-{label}'
    body = read(folder / 'benchmark.log')
    if body is None:
        continue
    if not label.startswith('before-'):
        parity(folder)
    stdout=read(folder/'benchmark-stdout.txt')
    assert len(re.findall(r'avg: ([\d.]+) ms',stdout))==1 and 'benchmark target population preserved' in stdout, folder
    phases = defaultdict(lambda: defaultdict(float))
    for phase, tick, ms in re.findall(r'SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms', body):
        if 120 <= int(tick) < 600:
            phases[phase][int(tick)] += float(ms)
    result = {phase: stats([ticks.get(t, 0) for t in range(120, 600)]) for phase, ticks in phases.items()}
    result['lance_total'] = stats([phases['shot'].get(t, 0)+phases['update-total'].get(t, 0) for t in range(120, 600)])
    snapshots = [json.loads(x.split('LANCE_BENCH SNAPSHOT ', 1)[1]) for x in body.splitlines() if 'LANCE_BENCH SNAPSHOT ' in x]
    assert snapshots and 'LANCE_QC FAIL' not in body, folder
    result['counters'] = snapshots[-1]['counters']
    result['pending_contacts'] = snapshots[-1].get('pending_contacts')
    if label in ['no-lance', 'idle', 'research']:
        for key in ['shots', 'penetration_queries', 'area_queries', 'wound_cues', 'status_refreshes', 'force_cache_refreshes', 'contact_target_reads', 'sweep_steps']:
            assert not result['counters'].get(key, 0), (label, key)
    if label in ['wide-native','wide-burst']:
        counters=result['counters']
        assert counters.get('angular_turns',0)>0 and counters.get('maximum_contact_latency',61)<=60, label
    if label=='wide-burst':
        assert result['counters'].get('compressed_turns',0)>0 and result['pending_contacts']<=240, label
    report['profiles'][label] = result

report['direct_investigation']={}
for scene in ['direct','no-lance']:
    row={}
    for version in ['before','after']:
        folder=a.root/f'angular-repeat-{version}-{scene}'
        path=folder/'benchmark-stdout.txt'
        if not path.exists(): continue
        body=read(path)
        samples=[float(x) for x in re.findall(r'avg: ([\d.]+) ms',body)]
        if a.allow_incomplete and len(samples)<6: continue
        assert len(samples)==6 and body.count('benchmark target population preserved')>=6, folder
        if version=='after': parity(folder)
        row[version]={'all_run_means_ms':samples,'median_ms':statistics.median(samples[1:]),'min_ms':min(samples[1:]),'max_ms':max(samples[1:])}
    if len(row)==2:
        row['median_change_percent']=100*(row['after']['median_ms']/row['before']['median_ms']-1)
        report['direct_investigation'][scene]=row
if not a.allow_incomplete and report['benchmarks'].get('direct',{}).get('median_change_percent',0)>5:
    assert len(report['direct_investigation'])==2,'Direct regression requires paired repeat and host control'

locales = {}
for lang in ['en', 'fr', 'ja', 'pl', 'ru', 'zh-CN', 'zh-TW']:
    rows = {}
    for filename in ['singularity-lance.cfg', 'singularity-lance-upgrades.cfg']:
        raw = (main/'locale'/lang/filename).read_bytes()
        assert not raw.startswith(b'\xef\xbb\xbf')
        body = raw.decode('utf-8'); assert '\ufffd' not in body
        section = ''
        for line in body.splitlines():
            if line.startswith('['): section = line
            elif '=' in line and not line.startswith(';'):
                key, value = line.split('=', 1); token = section+key
                assert token not in rows
                rows[token] = Counter(re.findall(r'__\d+__', value))
                if token == '[lance-upgrades]contact': assert rows[token] == Counter({'__1__':1,'__2__':1,'__3__':1,'__4__':1})
                if token == '[lance-upgrades]status': assert rows[token] == Counter({'__1__':1}) and '\\n' not in value
    locales[lang] = rows
assert all(v == locales['en'] for v in locales.values())
report['locale'] = {'languages':7, 'entries':sum(map(len,locales.values())), 'parity':'passed'}
body=read(Path('.factorio-qc/angular/final-prototypes.json'))
if body:
    report['live_final_prototypes']=json.loads(body)
    assert report['live_final_prototypes']['records']['native']=={'range':85,'cooldown':1,'energy_consumption':'125MJ',
        'buffer_capacity':'700MJ','input_flow_limit':'400MW','drain':'20MW'}
for task in ['preflight','qc-fast','qc-runtime','qc-assets']:
    body = read(Path('.factorio-qc/angular')/(task+'.json'))
    if body:
        data = json.loads(body)
        report['wrapper_checks'][task] = data
        assert data['overall_status'] != 'failed', task
report['source_sha256'] = {str(main/p):sha(main/p) for p in ['scripts/control/singularity-lance.lua','lib/singularity-lance-config.lua','lib/runtime-scheduler.lua']}
(out/'angular-results.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
lines = ['# Angular-sweep performance', '', 'Generated by `analyze-angular.py`; see [verification and limits](angular-verification.md).', '']
if not report['complete']:
    lines += ['**Partial performance report.** Only completed matched pairs appear below. Missing scenes and phase profiles are unmeasured, not zero-cost. Runtime validation results are recorded separately in `angular-results.json`.', '']
lines += ['| Scene | Before median ms | Before range | After median ms | After range | Change |', '| --- | ---: | ---: | ---: | ---: | ---: |']
for scene,row in report['benchmarks'].items():
    old,new=row['before'],row['after']
    lines.append(f"| {scene} | {old['median_ms']:.3f} | {old['min_ms']:.3f}–{old['max_ms']:.3f} | {new['median_ms']:.3f} | {new['min_ms']:.3f}–{new['max_ms']:.3f} | {row['median_change_percent']:+.2f}% |")
lines += ['', 'Profile phases are nested; total is shot + update-total, in ms/update.', '', '| Scene | Total mean | Total p95 | Sweep mean | Contact mean | Light mean |', '| --- | ---: | ---: | ---: | ---: | ---: |']
for scene,row in report['profiles'].items():
    values=[row['lance_total']['mean_ms'],row['lance_total']['p95_ms']]+[row.get(p,{}).get('mean_ms',0) for p in ['sweep','contact','contact-light']]
    lines.append('| '+scene+' | '+' | '.join(f'{x:.4f}' for x in values)+' |')
lines += ['', 'Angular admission counters are measured after warmup; latency is payment to reserved contact.', '',
          '| Scene | Ordinary turns | Compressed turns | Mean latency ticks | Max latency ticks | Reservation mean ms | Ordinary sweep mean ms | Compressed sweep mean ms |',
          '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
for scene,row in report['profiles'].items():
    counters=row['counters']; shots=counters.get('contacts_scheduled',0)
    if 'contact_latency_ticks' not in counters: continue
    latency=counters['contact_latency_ticks']/shots if shots else 0
    values=[row.get(p,{}).get('mean_ms',0) for p in ['turn-reservation','sweep-turn','sweep-compressed']]
    lines.append(f"| {scene} | {counters.get('ordinary_turns',0)} | {counters.get('compressed_turns',0)} | {latency:.2f} | {counters.get('maximum_contact_latency',0)} | "+' | '.join(f'{x:.4f}' for x in values)+' |')
if report['direct_investigation']:
    lines += ['', '| Paired repeat | Before median ms | After median ms | Change |', '| --- | ---: | ---: | ---: |']
    for scene,row in report['direct_investigation'].items():
        lines.append(f"| {scene} | {row['before']['median_ms']:.3f} | {row['after']['median_ms']:.3f} | {row['median_change_percent']:+.2f}% |")
(out/'angular-performance.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'assertions':sum(v['assertions'] for v in report['validation'].values()),'benchmarks':{k:round(v['median_change_percent'],2) for k,v in report['benchmarks'].items()},'profiles':len(report['profiles'])}))
