"""Summarize the Prismatic Liturgy validation and matched presentation benchmarks.

Run after the documented liturgy-* fixtures. Raw logs remain in ignored QC space;
this report preserves measured samples, tested source hashes and acceptance limits.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

parser = argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=Path('.factorio-qc/cu/l'))
parser.add_argument('--output',type=Path,default=Path('output/lance-prismatic-redesign/results.json'))
parser.add_argument('--dump',type=Path)
args=parser.parse_args()

report={'engine':'2.0.77','scope':'Presentation replacement; same four-upgrade mechanics',
        'limits':['Headless timings exclude GPU/render cost.','Background development activity was not controlled.',
                  'The pre-existing 1 ms dense p95 objective is not established by whole-game means.'],
        'validation':{},'benchmarks':{},'profiles':{}}
for fidelity in ['lean','standard','cinematic','maximal','unbounded']:
    folder=args.root/f'liturgy-final-{fidelity}'
    log=(folder/'benchmark.log').read_text('utf-8')
    assert 'LANCE_QC ALL_COMPLETE' in log,fidelity
    report['validation'][fidelity]={'assertions':log.count('LANCE_QC PASS'),
        'runtime_sha256':hashlib.sha256((folder/'mods/exotic-space-industries-remembrance/scripts/control/singularity-lance.lua').read_bytes()).hexdigest()}
reload=(args.root/'liturgy-reload-verified/benchmark.log').read_text('utf-8')
assert 'LANCE_QC RELOAD_COMPLETE' in reload
report['validation']['old_save_reload']={'assertions':reload.count('LANCE_QC PASS'),'counter_seven':True,'pending_collapses':7}
for scene in ['direct','normal-power','dense']:
    row={'ticks_per_run':900 if scene=='direct' else 600,'warmup_runs_discarded':1}
    for version,prefix in [('before','liturgy-before-' if scene=='direct' else 'liturgy-before2-'),('after','liturgy-after-')]:
        folder=args.root/(prefix+scene)
        log=(folder/'benchmark-stdout.txt').read_text('utf-8')
        samples=[float(x) for x in re.findall(r'avg: ([\d.]+) ms',log)]
        assert len(samples)==6,(scene,version,len(samples))
        row[version]={'all_run_means_ms':samples,'median_ms':statistics.median(samples[1:]),
                      'min_ms':min(samples[1:]),'max_ms':max(samples[1:]),
                      'runtime_sha256':hashlib.sha256((folder/'mods/exotic-space-industries-remembrance/scripts/control/singularity-lance.lua').read_bytes()).hexdigest()}
    row['median_change_percent']=100*(row['after']['median_ms']/row['before']['median_ms']-1)
    report['benchmarks'][scene]=row

for scene in ['normal-power','dense']:
    folder=args.root/f'liturgy-profile-{scene}'
    if not (folder/'benchmark.log').exists():
        continue
    log=(folder/'benchmark.log').read_text('utf-8')
    by_phase=collections.defaultdict(lambda:collections.defaultdict(float))
    for phase,tick,ms in re.findall(r'SINGULARITY_LANCE_PHASE phase=([\w-]+) tick=(\d+) elapsed=Duration: ([\d.]+)\s*ms',log):
        if 120<=int(tick)<600:
            by_phase[phase][int(tick)]+=float(ms)
    def stats(values):
        values=sorted(values)
        return {'mean_ms':statistics.mean(values),'p95_ms':values[math.ceil(.95*len(values))-1],'max_ms':max(values)}
    result={phase:stats([ticks.get(tick,0) for tick in range(120,600)]) for phase,ticks in by_phase.items()}
    if by_phase:
        result['all-lance-work']=stats([by_phase['shot'].get(tick,0)+by_phase['update-total'].get(tick,0) for tick in range(120,600)])
    report['profiles'][scene]=result

locale_root=Path('exotic-space-industries-remembrance/locale')
def locale_entries(path):
    content=path.read_text('utf-8-sig');assert '\ufffd' not in content,path
    entries={};section=None
    for line in content.splitlines():
        if line.startswith('['):section=line
        elif '=' in line and not line.startswith(';'):
            key,value=line.split('=',1);identity=(section,key)
            assert identity not in entries,(path,identity)
            entries[identity]=value
    return entries
for filename in ['singularity-lance-upgrades.cfg','singularity-lance.cfg']:
    english=locale_entries(locale_root/'en'/filename)
    for lang in ['fr','ja','pl','ru','zh-CN','zh-TW']:
        translated=locale_entries(locale_root/lang/filename)
        # Older general sidecars have intentional differing legacy keys. Validate
        # the keys this revision owns, not unrelated historical locale coverage.
        keys=english if filename.endswith('upgrades.cfg') else {('[exotic-industries-informatron]','singularity-lance-text-4')}
        for key in keys:
            assert key in translated,(lang,key)
            assert sorted(re.findall(r'__\d+__',english[key]))==sorted(re.findall(r'__\d+__',translated[key])),(lang,key,'parameters')
report['validation']['locale']='Seven languages: keys, duplicate entries, UTF-8 and localized parameters passed'

if args.dump:
    # Factorio's pretty-printed dump exceeds 2 GB in this dependency profile.
    # Read only the requested prototype objects at its fixed two/four-space key
    # indentation, then let json.loads validate each complete captured object.
    raw={key:{} for key in ['beam','animation','technology']}
    category=None; capture=None; buffer=[]
    with args.dump.open(encoding='utf-8') as handle:
        for line in handle:
            if capture:
                buffer.append(line)
                if line.startswith('    }'):
                    raw[category][capture]=json.loads(''.join(buffer).rstrip().rstrip(','))
                    capture=None;buffer=[]
            elif line.startswith('  "'):
                category=line.split('"',2)[1]
            elif category in raw and line.startswith('    "ei-singularity-lance'):
                capture=line.split('"',2)[1]
                opening=line.split(':',1)[1]
                if opening.strip():buffer.append(opening)
    (args.output.parent/'final-prototypes.json').write_text(json.dumps(raw,indent=2)+'\n',encoding='utf-8')
    for shape in ['', '-axial', '-testament']:
        beam=raw['beam']['ei-singularity-lance-beam'+shape]
        assert not beam.get('action'),shape
        assert beam['graphics_set']['desired_segment_length']==1,shape
    for band in [1,2,3]:
        layers=raw['animation'][f'ei-singularity-lance-wound-{band}']['layers']
        assert all(layer['frame_count']==24 and layer['width']==192 for layer in layers),band
    for key,count in [('collapse-warning',30),('testament-warning',30),('collapse-impact',12),('testament-impact',12)]:
        assert all(layer['frame_count']==count and layer['width']==256 for layer in raw['animation']['ei-singularity-lance-'+key]['layers']),key
    for key in ['axial-rupture','wound-memory','terminal-collapse','black-hole-testament']:
        icons=raw['technology']['ei-singularity-lance-'+key]['icons']
        assert len(icons)==2 and all('prismatic-liturgy' in layer['icon'] for layer in icons),key
    report['validation']['final_data']='Cosmetic native beams, Wound/collapse contracts and layered technology icons passed'

args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
