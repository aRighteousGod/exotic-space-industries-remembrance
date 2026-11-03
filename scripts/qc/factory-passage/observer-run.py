"""Managed native observer proof and 160 isolated old/new crafter measurements."""
import argparse, atexit, hashlib, json, pathlib, re, shutil, statistics, subprocess, time

ROOT=pathlib.Path(__file__).resolve().parents[3]
WRAPPER=ROOT/'scripts/invoke-factory-passage-qc.ps1'
PROCESS=pathlib.Path(__file__).with_name('process.py')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def ps(context,phase,*args):
    subprocess.run(['powershell','-ExecutionPolicy','Bypass','-File',str(WRAPPER),'-Phase',phase,'-ContextPath',str(context),*map(str,args)],check=True)
def write_case(path,r,helper,count,fraction,budget,revision,visual=False,circuit_budget=1):
    r.update(performance=count,budget=budget,circuit_budget=circuit_budget,visual=visual,actors=visual,administration=False)
    path.write_text(json.dumps(r,indent=2),encoding='utf8')
    (helper/'fixture-config.lua').write_text('return {observers=true,mode="esir",enabled=true,performance='+str(count)+',circuit_percent='+str(fraction)+',budget='+str(budget)+',circuit_budget='+str(circuit_budget)+',revision="'+revision+'",visual='+str(visual).lower()+'}',encoding='utf8')
def run(context,r,label,save,receipt,ticks=6000,visual=False):
    marker=pathlib.Path(r['write_data'])/'script-output/factory-passage'/f'{receipt}.json'
    started=time.time()
    subprocess.run(['python',str(PROCESS),'--context',str(context),'--phase','Visual' if visual else 'Run','--save',str(save),'--label',label,'--ticks',str(ticks),'--receipt',receipt],check=True,stdout=subprocess.DEVNULL)
    assert marker.stat().st_mtime>=started,'Stale receipt'
    result=json.loads(marker.read_text(encoding='utf8'));assert result['passed'] and result['engine']=='2.1.24'
    target=pathlib.Path(r['evidence'])/f'{label}.json';shutil.copy2(marker,target)
    return result
def main():
    p=argparse.ArgumentParser();p.add_argument('--context',required=True,type=pathlib.Path);p.add_argument('--baseline',type=pathlib.Path)
    p.add_argument('--benchmark',action='store_true');p.add_argument('--visual',action='store_true');a=p.parse_args()
    r=json.loads(a.context.read_text(encoding='utf-8-sig'));evidence=pathlib.Path(r['evidence'])
    helper=next(m.resolve() for m in pathlib.Path(r['mods']).iterdir() if m.is_dir() and m.name.startswith(r['helper']))
    # Resolve the managed view, then require the storage service's explicit
    # mutable-source allowlist rather than guessing from a directory name.
    command=". ./scripts/esir-qc-storage.ps1; Invoke-EsirQcStorage -RepoRoot $PWD.Path -Action mutable-sources -Data @{run_id='"+r['run_id']+"'} | ConvertTo-Json -Depth 5"
    mutable=json.loads(subprocess.check_output(['powershell','-NoProfile','-Command',command],cwd=ROOT,encoding='utf-8-sig'))
    assert helper==pathlib.Path(mutable['names'][r['helper']]).resolve(),'Expected private mutable source'
    owner=helper/'scripts/control/factory-passage.lua';candidate=owner.read_bytes();candidate_hash=sha(owner)
    assert candidate_hash==sha(ROOT/'exotic-space-industries-remembrance/scripts/control/factory-passage.lua'),'Staged candidate differs from delivered owner'
    atexit.register(owner.write_bytes,candidate)
    shared={str(p.relative_to(helper)):sha(p) for p in helper.rglob('*.lua') if str(p.relative_to(helper)).replace('\\','/') not in ('fixture-config.lua','scripts/control/factory-passage.lua')}
    if not a.benchmark:
        write_case(a.context,r,helper,0,0,256,'candidate',a.visual)
        ps(a.context,'Create','-Label','observer')
        save=pathlib.Path(r['write_data'])/'observer.zip'
        result=run(a.context,r,'observer-functional',save,'observer-functional',230,a.visual)
        (evidence/'observer-acceptance.json').write_text(json.dumps(dict(passed=True,production_sha256=candidate_hash,checks=result['checks'],required_labels=['observer-functional']),indent=2),encoding='utf8')
        print(json.dumps(dict(passed=True,checks=len(result['checks']),evidence=str(evidence))))
        return
    assert a.baseline and a.baseline.is_file()
    baseline=a.baseline.read_bytes();assert baseline!=candidate
    shutil.copy2(a.baseline,evidence/'baseline-factory-passage.lua')
    cases={};labels=[];pairs=[]
    for count in (1000,10000):
      for fraction in (0,10):
       for budget, circuit_budget in ((b,c) for b in (256,1024) for c in (1,1024)):
        saves={};ready={}
        for revision,source in (('baseline',baseline),('candidate',candidate)):
            owner.write_bytes(source);write_case(a.context,r,helper,count,fraction,budget,revision,circuit_budget=circuit_budget)
            label=f'observers-{count}-{fraction}-{budget}-{circuit_budget}-{revision}'
            ps(a.context,'Create','-Label',label)
            ps(a.context,'Settle','-Label',label)
            saves[revision]=pathlib.Path(r['write_data'])/f'{label}-settled.zip'
            ready[revision]=json.loads((evidence/f'{label}-ready.json').read_text(encoding='utf-8-sig'))
            cases[label]=dict(revision=revision,count=count,fraction=fraction,budget=budget,circuit_budget=circuit_budget,trials=[],checkpoint_sha256=sha(saves[revision]),ready=ready[revision])
        assert ready['baseline']['status']['helpers']==ready['candidate']['status']['helpers'],'Matched geometry mismatch'
        for revision in saves:
            assert ready[revision]['status']['update_budget']==budget,'Native budget mismatch'
        for trial in range(5):
            timings={}
            for revision in (('baseline','candidate') if trial%2==0 else ('candidate','baseline')):
                owner.write_bytes(baseline if revision=='baseline' else candidate)
                write_case(a.context,r,helper,count,fraction,budget,revision,circuit_budget=circuit_budget)
                key=f'observers-{count}-{fraction}-{budget}-{circuit_budget}-{revision}';label=f'{key}-{trial+1}'
                result=run(a.context,r,label,saves[revision],'performance-idle')
                assert (result['revision'],result['count'],result['circuit_percent'])==(revision,count,fraction)
                assert result['checks'] and all(c['passed'] for c in result['checks'])
                log=(evidence/f'{label}-run.log').read_text(encoding='utf8')
                match=re.search(r'Performed (\d+) updates in ([\d.]+) ms',log);assert match
                updates=int(match[1]);assert updates==6000
                ms=float(match[2])/updates;monitor=json.loads((evidence/f'{label}-monitor.json').read_text())
                sources={k.replace('\\','/'):v for k,v in json.loads((evidence/f'{label}-sources.json').read_text()).items()}
                expected=hashlib.sha256(baseline).hexdigest() if revision=='baseline' else candidate_hash
                assert sources[r['helper']+'/scripts/control/factory-passage.lua']==expected,'Owner snapshot mismatch'
                assert sources[r['helper']+'/observer-suite.lua']==sha(helper/'observer-suite.lua'),'Fixture snapshot mismatch'
                for relative,digest in shared.items():
                    assert sources[r['helper']+'/'+relative.replace('\\','/')]==digest,'Shared fixture input changed'
                assert monitor['save_sha256']==cases[key]['checkpoint_sha256'],'Checkpoint identity mismatch'
                assert result['status']['update_budget']==budget and result['status']['counters']['max_processed']<=budget,'Native budget cap mismatch'
                assert monitor['isolated'];labels.append(label);timings[revision]=ms
                profile=re.search(r'passage-profiler-ms-per-tick=Duration:\s*([\d.]+)ms',log);assert profile,'Missing isolated passage profiler'
                cases[key]['trials'].append(dict(label=label,ms_per_tick=ms,script_ms_per_tick=float(profile[1]),watcher_attempts=result['watcher_attempts'],circuit_attempts=result['circuit_attempts'],helper_count=result['status']['helpers'],latency=result['latency'],monitor=monitor))
                print(json.dumps(dict(trial=label,ms_per_tick=ms,watchers=result['status']['watchers'])),flush=True)
            delta=timings['candidate']-timings['baseline'];limit=max(.1,.05*timings['baseline'])
            pairs.append(dict(count=count,fraction=fraction,budget=budget,circuit_budget=circuit_budget,trial=trial+1,delta_ms=delta,limit_ms=limit,passed=delta<=limit))
    owner.write_bytes(candidate)
    for c in cases.values():c['mean_ms']=statistics.mean(t['ms_per_tick'] for t in c['trials'])
    result=dict(passed=all(p['passed'] for p in pairs),engine='2.1.24',baseline_sha256=hashlib.sha256(baseline).hexdigest(),candidate_sha256=candidate_hash,
        measured_runs=len(labels),cases=cases,comparisons=pairs,required_labels=labels)
    (evidence/'observer-performance-acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    assert result['passed'],'Steady-state regression exceeds acceptance allowance'
    print(json.dumps(dict(passed=True,runs=len(labels))))
if __name__=='__main__':main()
