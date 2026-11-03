"""Accept five independently measured, matched native pipe-network trials."""
import argparse, hashlib, json, pathlib, re, statistics

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--context',required=True);args=parser.parse_args()
    context=json.loads(pathlib.Path(args.context).read_text(encoding='utf-8-sig'))
    root=pathlib.Path(context['evidence']);labels=[];cases={}
    source=pathlib.Path(__file__).resolve().parents[3]/'exotic-space-industries-remembrance'
    production={name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in (
        'lib/factory-passage-config.lua','lib/runtime-scheduler.lua','prototypes/factory-passage.lua',
        'scripts/data-final-updates/factory-passage.lua','scripts/control/factory-passage.lua')}
    def read(name):return json.loads((root/(name+'.json')).read_text(encoding='utf-8-sig'))
    for count in (10000,100000):
        for mode in ('vanilla','esir'):
            for kind in ('idle','burst'):
                key=f'{count}-{mode}-{kind}';trials=[]
                ready=read(key+'-ready');assert ready['passed'] and ready['count']==count
                assert ready['status']['update_budget']==context['budget']
                assert ready['checkpoint_tick']==512 and ready['surface_seed']==137013
                expected=0 if mode=='vanilla' else (count//1000)*999+count-1000
                assert ready['status']['helpers']==expected
                for trial in range(1,6):
                    label=f'{key}-{trial}';receipt=read(label);monitor=read(label+'-monitor')
                    manifest={name.replace('\\','/'):sha for name,sha in read(label+'-sources').items()}
                    assert all(manifest['esir-factory-passage-qc/'+name]==sha for name,sha in production.items())
                    assert receipt['passed'] and receipt['engine']=='2.1.24' and receipt['mode']==mode and receipt['enabled']
                    assert receipt['checks'] and all(check['passed'] for check in receipt['checks'])
                    assert monitor['isolated'] and not monitor['other_factorio_pids']
                    assert monitor['save_sha256']==read(key+'-settle-monitor')['checkpoint_sha256']
                    status=receipt['status'];assert status['dirty']==status['pending']==status['watchers']==0
                    assert status['update_budget']==context['budget']
                    assert status['helpers']==expected and status['counters']['unsupported']==0 and status['counters']['max_processed']<=context['budget']
                    if kind=='burst':assert receipt['removed']==1000 and receipt['entities']==count
                    else:assert receipt['count']==count
                    log=(root/(label+'-run.log')).read_text(encoding='utf8')
                    values=re.findall(r'Performed (\d+) updates in ([0-9.]+) ms',log)
                    assert len(values)==1,(label,values)
                    ticks,total=values[0];assert int(ticks)==(1000 if kind=='burst' else 6000)
                    peaks=re.findall(r'max:\s*([0-9.]+)\s*ms',log);assert len(peaks)==1
                    trials.append(dict(average_ms=float(total)/int(ticks),maximum_tick_ms=float(peaks[0]),**monitor,**({k:receipt[k] for k in ('removal_ticks','construction_ticks')} if kind=='burst' else {})))
                    labels.append(label)
                cases[key]=dict(entities=count,mode=mode,kind=kind,helpers=expected,rebuild_ticks=ready['ticks'],rebuild_process=read(key+'-settle-monitor'),trials=trials,mean_ms=statistics.mean(t['average_ms'] for t in trials))
    comparisons=[];aggregate=[]
    for count in (10000,100000):
        baseline=cases[f'{count}-vanilla-idle'];candidate=cases[f'{count}-esir-idle']
        delta=candidate['mean_ms']-baseline['mean_ms'];limit=max(.1,baseline['mean_ms']*.05)
        aggregate.append(dict(entities=count,delta_ms=delta,allowed_ms=limit,passed=delta<=limit))
        for index,(b,c) in enumerate(zip(baseline['trials'],candidate['trials']),1):
            limit=max(.1,b['average_ms']*.05);delta=c['average_ms']-b['average_ms']
            comparisons.append(dict(entities=count,trial=index,delta_ms=delta,allowed_ms=limit,passed=delta<=limit))
    host_log=(root/'10000-vanilla-idle-1-run.log').read_text(encoding='utf8')
    host=dict(cpu=re.search(r'\[CPU: (.*?), \d+ cores',host_log).group(1),
              operating_system=re.search(r'Operating system: (.*)',host_log).group(1),
              engine=re.search(r'Factorio 2\.1\.24 \(.*?\)',host_log).group(0))
    result=dict(budget=context['budget'],passed=all(row['passed'] for row in comparisons+aggregate),engine='2.1.24',host=host,map_seed=137013,checkpoint_tick=512,production_sha256=production,idle_ticks=6000,burst_ticks=1000,required_labels=labels,cases=cases,comparisons=comparisons,aggregate=aggregate,
                scope='Base plus exact candidate source; five isolated processes per case; memory is whole-process peak, rebuild ticks include bounded queue drain; burst averages are reported separately from steady-state gate.')
    (root/'performance-acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps(dict(passed=result['passed'],means={key:value['mean_ms'] for key,value in cases.items()})))
    assert result['passed'],'Steady-state overhead exceeds the agreed limit'

if __name__=='__main__':main()
