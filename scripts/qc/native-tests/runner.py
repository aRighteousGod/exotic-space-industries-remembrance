"""Sequential exact-engine functional tests with managed staging and fresh evidence."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import zipfile
import source_inputs

from catalogue import CORE, load, plan, read_json, validate_report, audit_inventory, audit_links

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
FATAL_MARKERS=('non-recoverable error','error while running','failed to load mods','exception at tick',
               'error modmanager','error servermultiplayer','error atlasbuilder','error util.cpp')


def harness_inputs():
    roots=['scripts/qc/'+name for name in ('native-tests','gaia-resources','runtime-options','orbital-logistics','build-dispatch','runtime-contracts','event-tick','induction-circuit','mirroring','factorio-2.1/research-bootstrap')]
    roots+=['.codex/skills/esir-dev/assets/zzz-scripted-research-qc_0.0.1']
    paths={p for root in roots for p in (REPO/root).rglob('*') if p.is_file() and p.suffix in ('.py','.ps1','.lua','.json')}
    paths.update(REPO/name for name in ('.codex/esir/test-suites.json','.codex/esir/factorio-development.json',
        'scripts/esir-dev-lib.ps1','scripts/esir-housekeeping.ps1','scripts/esir-qc-version-staging.ps1','scripts/esir_qc_storage.py',
        'scripts/esir-qc-storage.ps1','scripts/esir-dependency-lib.ps1','scripts/esir-qc-acceptance.ps1',
        'scripts/invoke-esir-dev.ps1','scripts/invoke-esir-qc-delegate.ps1',
        '.codex/esir/preserved-encoding.json','.codex/skills/esir-dev/assets/gaia-resource-qc.json'))
    return {p.relative_to(REPO).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


# Imported modules can remain cached across rows. Never label changed on-disk
# adapters as the code already running in this Python process.
START_HARNESS=harness_inputs()
HARNESS_HASH=hashlib.sha256(json.dumps(START_HARNESS,sort_keys=True).encode()).hexdigest()


def native_path(path):
    """Use the existing Windows alias; do not relocate managed files or sources.

    Factorio's sprite loader still hits MAX_PATH through a long mod-view path.
    Host fingerprints and ownership records retain their canonical paths.
    """
    path=Path(path).resolve()
    if os.name!='nt': return str(path)
    import ctypes
    buffer=ctypes.create_unicode_buffer(32768)
    length=ctypes.windll.kernel32.GetShortPathNameW(str(path),buffer,len(buffer))
    if not length or length>=len(buffer): raise RuntimeError('Cannot resolve native path: '+str(path))
    if not Path(buffer.value).samefile(path): raise RuntimeError('Native alias changed file identity: '+str(path))
    return buffer.value


def write_json(path, value):
    Path(path).write_text(json.dumps(value,indent=2,ensure_ascii=False),encoding='utf-8')


def managed(action, data):
    # Small control messages only; bulky output is registered before creation.
    request_root=REPO/'temp';request_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='esir-native-request-',dir=request_root) as directory:
        request=Path(directory)/'request.json';write_json(request,data)
        command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(HERE/'managed.ps1'),'-Action',action,'-Request',str(request)]
        # Python can inherit PowerShell 7's module paths. Windows PowerShell
        # must rebuild its own defaults so its built-in cmdlets load correctly.
        environment = {name: value for name, value in os.environ.items()
                       if name.lower() != 'psmodulepath'}
        result=subprocess.run(command,cwd=REPO,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace')
        if result.returncode: raise RuntimeError(result.stderr[-5000:]+result.stdout[-2000:])
        lines=[line for line in result.stdout.splitlines() if line.startswith('{')]
        if not lines: raise RuntimeError('Managed adapter returned no record: '+result.stdout[-1000:])
        return json.loads(lines[-1])


def run_process(command, output, timeout, checkpoint=None):
    output=Path(output);started=time.time();timed_out=False;verified=False;terminated=False
    with output.open('w',encoding='utf-8') as stream:
        environment=os.environ.copy()
        if '--load-game' in command: environment.update(SteamAppId='427520',SteamGameId='427520')
        startup=None
        if os.name=='nt':
            startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
        process=subprocess.Popen([str(x) for x in command],stdout=stream,stderr=subprocess.STDOUT,env=environment,
            startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        try:
            while process.poll() is None:
                text=output.read_text(encoding='utf-8',errors='replace')
                if any(marker in text.lower() for marker in FATAL_MARKERS): break
                if checkpoint and Path(checkpoint).exists() and Path(checkpoint).stat().st_mtime>=started:
                    if 'Saving finished' in text:
                        try:
                            with zipfile.ZipFile(checkpoint) as archive: verified=archive.testzip() is None
                        except (OSError,zipfile.BadZipFile): pass
                        if verified: break
                if time.time()-started>=timeout: timed_out=True;break
                time.sleep(0.1)
        finally:
            if process.poll() is None:
                terminated=True
                process.terminate()
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired: process.kill();process.wait(timeout=10)
    text=output.read_text(encoding='utf-8',errors='replace')
    fatal=any(marker in text.lower() for marker in FATAL_MARKERS)
    return {'exit_code':0 if verified else process.returncode,'timed_out':timed_out,'fatal':fatal,
            'actual_exit_code':process.returncode,'owned_termination':terminated,
            'started':started,'elapsed_seconds':round(time.time()-started,3),'checkpoint_verified':verified,'log':str(output),'command':[str(x) for x in command]}


def source_hash(paths):
    entries={}
    for label,root in paths.items():
        if not root: continue
        for path in sorted(Path(root).rglob('*')):
            if path.is_file() and path.suffix.lower() in ('.lua','.json','.cfg'):
                entries[label+'/'+path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    return hashlib.sha256(json.dumps(entries,sort_keys=True).encode()).hexdigest(),entries


def phase_inputs(record, source_digest):
    inputs={'source_digest':source_digest,'harness_digest':record.get('harness_hash')}
    for name in ('mod-list.json','mod-settings.dat'):
        path=Path(record['mods'])/name
        if name=='mod-list.json' and path.exists():
            mods=read_json(path)['mods']
            if len({m['name'] for m in mods})!=len(mods) or any(type(m.get('enabled')) is not bool for m in mods):
                raise ValueError('Invalid/duplicate mod selection')
            # Engine sorts the list and drops absent disabled mods on first load.
            # The effective enabled set must remain exact; runtime checks also
            # assert every explicitly disabled mod stayed absent.
            inputs[name]=sorted(m['name'] for m in mods if m['enabled'])
        else: inputs[name]=hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
    # Factorio rewrites UI/default options on exit; only the path contract is
    # runner-owned. Full prelaunch config is retained separately as evidence.
    import configparser
    config=configparser.ConfigParser();config.read(record['config'],encoding='utf-8-sig')
    inputs['paths']=dict(config['path'])
    return hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest(),inputs


def validate_selection(record, before, expected, process, evidence, label):
    after=phase_inputs(record,before['source_digest'])[1]
    if before==after: return
    changes={key for key in set(before)|set(after) if before.get(key)!=after.get(key)}
    if changes!={'mod-settings.dat'} or before['mod-settings.dat'] is not None or after['mod-settings.dat'] is None:
        raise ValueError('Staged selection changed: '+', '.join(sorted(changes)))
    path=Path(record['write_data'])/'script-output/native-setting-defaults.json'
    if not path.is_file() or path.stat().st_mtime<process['started']:
        raise ValueError('Missing fresh default-settings attestation')
    report=read_json(path)
    for key in ('run_id','suite','profile','phase','input_hash','engine_version'):
        if report.get(key)!=expected[key]: raise ValueError('Default-settings identity mismatch: '+key)
    import settings_file
    settings_file.assert_defaults((Path(record['mods'])/'mod-settings.dat').read_bytes(),report['defaults'])
    write_json(evidence/(label+'-settings-normalization.json'),{'before':before,'after':after,'attestation':report})


def verify_engine_log(record, log):
    text=Path(log).read_text(encoding='utf-8',errors='replace')
    match=re.search(r'Read data path: ([^\r\n]+)',text)
    expected=Path(record['engine']).resolve().parents[2]/'data'
    if not match or not Path(match[1].strip()).samefile(expected): raise RuntimeError('Engine loaded unexpected base data: '+str(log))
    if not re.search(r'Factorio 2\.1\.24 \(build',text) or 'Loading mod base 2.1.24 (data.lua)' not in text:
        raise RuntimeError('Executable/base log does not match exact 2.1.24: '+str(log))


def conformance(helper):
    (helper/'native-suite.lua').write_text('''local support=require("support")
local first=true
local phase=support.phase()
return {poll=function(tick)
 if phase~="candidate" and phase~="reload" then
  helpers.write_file("native-negative-entered.json",helpers.table_to_json{run_id=support.config.run_id,phase=phase,input_hash=support.config.input_hash},false)
 end
 if phase=="host-timeout" then while true do end end
 if phase=="missing-report" then script.finish_test(true);return end
 if phase=="tick-limit" then return end
 if phase=="lua-error" then error("Intentional native conformance exception") end
 if not first then return end;first=false
 if phase=="explicit-failure" then return {complete=true,checks={{name="deliberate-negative",passed=false}}} end
 local player=game.connected_players[1]
 local checks={{name="native-player-present",passed=player~=nil},{name="engine-version",passed=script.active_mods.base=="2.1.24"}}
 if player then
  local gui=player.gui.screen.add{type="frame",name="esir_native_probe"}
  checks[#checks+1]={name="native-gui-element",passed=gui.valid};gui.destroy()
 end
 if phase=="reload" then checks[#checks+1]={name="saved-fixture-state",passed=storage.native_marker=="persisted"}
 else storage.native_marker="persisted" end
 return {complete=true,checks=checks}
end}
''',encoding='utf-8')


def execute_row(row, engine=None, qualification=None):
    suite=row['suite'];profile=row['profile'];case_ids=row['cases']
    print(f"Native tests: {suite}/{profile['id']} ({', '.join(case_ids)})",file=sys.stderr,flush=True)
    try:
        if harness_inputs()!=START_HARNESS: raise RuntimeError('Runner/fixture inputs changed since this process started; rerun the selection')
        record=managed('stage',{'engine':engine,'base_only':suite=='runner-conformance','quality':profile['quality'],
            'scenario':suite+'/'+profile['id'],'reproduction':f'invoke-esir-dev -Task qc-test -Suite {suite} -TestProfile {profile["id"]}'})
    except Exception as error:
        return {'suite':suite,'profile':profile['id'],'overall_status':'failed','error':str(error),'stage':'registration/staging'}
    result={'suite':suite,'profile':profile['id'],'run_id':record['run_id'],'phases':[],'overall_status':'failed','evidence':record['evidence']}
    evidence=Path(record['evidence']);write=Path(record['write_data']);helper=Path(record['mutable']['esir-qc-native-tests'])
    record['harness_hash']=HARNESS_HASH
    main=Path(record['mutable']['exotic-space-industries-remembrance']) if suite!='runner-conformance' else None
    try:
        write_json(evidence/'harness-inputs.json',{'sha256':HARNESS_HASH,'files':START_HARNESS})
        help_result=run_process([record['engine'],'--help'],evidence/'capabilities.log',15)
        help_text=Path(help_result['log']).read_text(encoding='utf-8',errors='replace')
        if help_result['exit_code'] or not all(flag in help_text for flag in ('--test-scenario','--test-save','--test-ticks','--test-arg')):
            raise RuntimeError('Exact engine lacks required native testing CLI capabilities')
        metadata={}
        selected_mods={r['name']:r['enabled'] for r in read_json(Path(record['mods'])/'mod-list.json')['mods']}
        # Capture after every explicitly selected content dependency. Presence on
        # disk never introduces dependencies or adds a matrix row.
        info=read_json(helper/'info.json')
        info['dependencies']=['base = 2.1.24']+['? '+name for name,enabled in sorted(selected_mods.items()) if enabled and name not in ('base',info['name'])]
        write_json(helper/'info.json',info)
        if suite=='runner-conformance': conformance(helper)
        else:
            from adapters import stage
            metadata=stage(REPO,main,helper,suite,profile)
        if qualification:
            # Explicit qualification mutates only the private copy, before its
            # identity is frozen. Normal qc-test/qc-full never supply this hook.
            result['injected_defect']=qualification(main,helper,suite)
            metadata['injected_defect']=result['injected_defect']
        initial={'run_id':record['run_id'],'suite':suite,'profile':profile['id'],'phase':'candidate',
            'cases':['candidate'],'deadline_ticks':row['deadline_ticks'],'checkpoint':True,'input_hash':'pending','engine_version':'2.1.24'}
        initial['expected_mods']=selected_mods
        initial['parameters']=metadata.get('parameters',{})
        # Runtime identity is not a source/config change between candidate and reload.
        (helper/'fixture-config.lua').write_text('return '+lua(initial)+'\n',encoding='utf-8')
        digest,inputs=source_hash({'main':main,'helper':helper})
        initial['input_hash']=digest
        # Fingerprint excludes its own embedded digest; the exact final files are
        # frozen below and checked again after every engine invocation.
        (helper/'fixture-config.lua').write_text('return '+lua(initial)+'\n',encoding='utf-8')
        frozen,final_inputs=source_hash({'main':main,'helper':helper})
        write_json(evidence/'inputs.json',{'identity_hash':digest,'frozen_hash':frozen,'files':final_inputs,'adapter':metadata,'profile':profile})
        common=['--config',native_path(record['config']),'--mod-directory',native_path(record['mods']),'--disable-audio','--disable-migration-window']
        seed=Path(record['scratch'])/'native-seed.zip'
        selection_hash,_=phase_inputs(record,'selection')
        checkpoint=write/'saves/native-checkpoint.zip'
        for phase in case_ids:
            if source_hash({'main':main,'helper':helper})[0]!=frozen: raise RuntimeError('Staged source changed between phases')
            if phase_inputs(record,'selection')[0]!=selection_hash: raise RuntimeError('Staged selection changed between phases')
            # Fresh scenarios need no save. Create exactly once, immediately
            # before the first save-backed phase or its checkpoint producer.
            if phase!='candidate' and not seed.exists():
                before_create=phase_inputs(record,'selection')[1]
                created=run_process([record['engine'],*common,'--create',seed],evidence/'create.log',row['timeout_seconds'])
                result['seed_creation']=created
                if created['exit_code'] or created['fatal'] or created['timed_out']: raise RuntimeError('Seed creation failed: '+created['log'])
                verify_engine_log(record,created['log'])
                if harness_inputs()!=START_HARNESS: raise RuntimeError('Runner/fixture inputs changed during seed creation')
                validate_selection(record,before_create,initial,created,evidence,'seed')
                selection_hash=phase_inputs(record,'selection')[0]
            if phase in ('reload','configuration') and not checkpoint.exists():
                settings=write/'server-settings.json'
                write_json(settings,{'name':'Private ESIR native QC','description':'Managed fixture','visibility':{'public':False,'lan':False},
                    'require_user_verification':False,'auto_pause':False,'autosave_interval':0})
                (write/'saves').mkdir(exist_ok=True)
                # Player suites need a genuine connected player during checkpoint
                # creation. Their graphical backend is explicit in the receipt.
                graphical=row['checkpoint_executor']=='graphical'
                if graphical:
                    checkpoint=write/'saves/_autosave-native-checkpoint.zip'
                    launch=['--load-game',seed,'--window-size','1280x720','--graphics-quality','medium','--video-memory-usage','low']
                else: launch=['--start-server',seed,'--server-settings',settings,'--bind','127.0.0.1','--port','34439']
                checkpoint_report=write/'script-output/native-test-candidate.json'
                if checkpoint_report.exists(): checkpoint_report.unlink()
                saved=run_process([record['engine'],*common,*launch],evidence/'checkpoint.log',row['timeout_seconds'],checkpoint)
                result['checkpoint']=saved
                if metadata.get('rendered_output'):
                    rendered=write/'script-output'/metadata['rendered_output']
                    if rendered.is_dir():
                        shutil.copytree(rendered,evidence/'rendered',dirs_exist_ok=True)
                if not saved['checkpoint_verified']: raise RuntimeError('Fresh checkpoint not completed: '+saved['log'])
                verify_engine_log(record,saved['log'])
                checkpoint_errors=validate_report(read_json(checkpoint_report) if checkpoint_report.exists() else None,initial,
                    saved['exit_code'],fresh=checkpoint_report.exists() and checkpoint_report.stat().st_mtime>=saved['started'],fatal=saved['fatal'])
                if checkpoint_errors: raise RuntimeError('Invalid checkpoint assertions: '+', '.join(checkpoint_errors))
                if metadata.get('native_lab') and (evidence/'candidate-bootstrap-state.json').exists():
                    accepted=read_json(write/'script-output/research-bootstrap-native.json')['accepted']
                    if accepted!=read_json(evidence/'candidate-bootstrap-state.json'): raise RuntimeError('Bootstrap checkpoint differs from independent candidate state')
                    write_json(evidence/'checkpoint-bootstrap-state.json',accepted)
                if source_hash({'main':main,'helper':helper})[0]!=frozen: raise RuntimeError('Checkpoint changed staged source')
                if phase_inputs(record,'selection')[0]!=selection_hash: raise RuntimeError('Checkpoint changed staged selection')
                if harness_inputs()!=START_HARNESS: raise RuntimeError('Runner/fixture inputs changed during checkpoint')
                managed('validate',{'run_id':record['run_id']})
                write_json(evidence/'checkpoint-assertions.json',read_json(checkpoint_report))
                write_json(evidence/'checkpoint.json',{'sha256':hashlib.sha256(checkpoint.read_bytes()).hexdigest(),'bytes':checkpoint.stat().st_size,'executor':'graphical' if graphical else 'server'})
            if phase=='configuration':
                info=read_json(helper/'info.json');info['version']='0.0.2';write_json(helper/'info.json',info)
                frozen,final_inputs=source_hash({'main':main,'helper':helper})
                write_json(evidence/'configuration-inputs.json',final_inputs)
            envelope={**initial,'phase':phase,'cases':[phase],'checkpoint':False}
            phase_hash,phase_selection=phase_inputs(record,frozen)
            envelope['input_hash']=phase_hash
            write_json(evidence/(phase+'-inputs.json'),phase_selection)
            (evidence/(phase+'-config.ini')).write_bytes(Path(record['config']).read_bytes())
            report_path=write/'script-output'/f'native-test-{phase}.json'
            if report_path.exists(): raise RuntimeError('Refuse pre-existing phase report')
            target=checkpoint if phase in ('reload','configuration') else seed
            launch=['--test-save',target]
            if phase=='candidate': launch=['--test-scenario','esir-qc-native-tests/native']
            budget=1 if phase=='tick-limit' else row['deadline_ticks']+2
            timeout=15 if phase=='host-timeout' else row['timeout_seconds']
            process=run_process([record['engine'],*common,*launch,'--test-arg',json.dumps(envelope,separators=(',',':')),'--test-ticks',str(budget)],evidence/(phase+'.log'),timeout)
            verify_engine_log(record,process['log'])
            report=read_json(report_path) if report_path.exists() else None
            errors=validate_report(report,envelope,process['exit_code'],fresh=report_path.exists() and report_path.stat().st_mtime>=process['started'],fatal=process['fatal'])
            if process['timed_out']: errors.append('host-timeout')
            if source_hash({'main':main,'helper':helper})[0]!=frozen: errors.append('staged-inputs-changed')
            try:
                validate_selection(record,phase_selection,envelope,process,evidence,phase)
                selection_hash=phase_inputs(record,'selection')[0]
            except (ValueError,KeyError,OSError) as error:
                errors.append('staged-selection-changed')
                write_json(evidence/(phase+'-selection-error.json'),{'error':str(error),'before':phase_selection,'after':phase_inputs(record,frozen)[1]})
            if harness_inputs()!=START_HARNESS: errors.append('runner-fixture-inputs-changed')
            if report: write_json(evidence/(phase+'.json'),report)
            negative=phase in ('explicit-failure','lua-error','missing-report','tick-limit','host-timeout')
            phase_result=None
            if not negative:
                phase_result={'phase':phase,'passed':False,'errors':errors,'assertions':len(report.get('checks',[])) if report else 0,'process':process}
                result['phases'].append(phase_result)
            managed('validate',{'run_id':record['run_id']})
            if not errors and suite!='runner-conformance':
                from adapters import postcheck
                extra=postcheck(REPO,write/'script-output',metadata,phase)
                if extra: write_json(evidence/(phase+'-postchecks.json'),extra)
                if any(not c['passed'] for c in extra): errors.append('postcheck-failure')
                if metadata.get('native_lab'):
                    state=read_json(write/'script-output'/('research-bootstrap-native.json' if phase=='candidate' else 'research-bootstrap-reload.json'))['accepted' if phase=='candidate' else 'actual']
                    candidate=evidence/'candidate-bootstrap-state.json'
                    if phase=='candidate': write_json(candidate,state)
                    elif candidate.exists() and state!=read_json(candidate): errors.append('bootstrap-independent-candidate-state-mismatch')
            if harness_inputs()!=START_HARNESS and 'runner-fixture-inputs-changed' not in errors: errors.append('runner-fixture-inputs-changed')
            if negative:
                marker=write/'script-output/native-negative-entered.json'
                entered=marker.exists() and marker.stat().st_mtime>=process['started'] and read_json(marker)=={k:envelope[k] for k in ('run_id','phase','input_hash')}
                if entered: write_json(evidence/(phase+'-entered.json'),read_json(marker))
                qualified=qualify_negative(phase,errors,report,process,entered)
                result['phases'].append({'phase':phase,'negative_control':True,'observed_errors':errors,'passed':qualified,'process':process})
                if not qualified: raise RuntimeError('Negative control did not fail as expected: '+phase)
            else:
                phase_result['passed']=not errors
                if errors: raise RuntimeError('Native phase failed: '+phase+' '+', '.join(errors))
        if harness_inputs()!=START_HARNESS: raise RuntimeError('Runner/fixture inputs changed before row completion')
        result['overall_status']='ok'
    except Exception as error:
        result['error']=str(error)
    finally:
        try: write_json(evidence/'result.json',result)
        except Exception as error:
            result['overall_status']='failed';result['evidence_error']=str(error)
        try:
            closed=managed('finish',{'run_id':record['run_id'],'overall_status':result['overall_status'],'result':result})
            result['housekeeping']={'status':closed.get('status'),'cleanup_status':closed.get('cleanup_status'),'payload_path':closed.get('payload_path')}
            if closed.get('cleanup_status')=='protected-error': result['overall_status']='failed'
        except Exception as error:
            result['overall_status']='failed';result['housekeeping_error']=str(error)
        try: write_json(evidence/'final-result.json',result)
        except Exception as error:
            result['overall_status']='failed';result['final_receipt_error']=str(error)
    return result


def lua(value):
    if value is None:return 'nil'
    if value is True:return 'true'
    if value is False:return 'false'
    if isinstance(value,(int,float)):return str(value)
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'


def qualify_negative(phase, errors, report, process, marker_fresh=False):
    allowed={'engine-exit','failed-report','failed-assertion','missing-or-malformed-report','host-timeout'}
    if set(errors)-allowed or process['fatal'] or not marker_fresh: return False
    if phase in ('missing-report','tick-limit'):
        return report is None and process['exit_code']==0 and not process['timed_out']
    if phase=='host-timeout': return process['timed_out'] and report is None
    if not report or process['exit_code']!=1 or process['timed_out']: return False
    failed=[c for c in report.get('checks',[]) if c.get('passed') is not True]
    if len(failed)!=1: return False
    if phase=='explicit-failure': return failed[0].get('name')=='deliberate-negative' and failed[0].get('passed') is False
    return failed[0].get('name')=='fixture-exception' and failed[0].get('passed') is False and 'Intentional native conformance exception' in failed[0].get('detail','')


def execute_selection(rows,engine=None,expected_source_sha256=None,qualification=None):
    baseline=source_inputs.snapshot(REPO,base_only=all(r['suite']=='runner-conformance' for r in rows))
    if expected_source_sha256 and baseline['sha256']!=expected_source_sha256:
        raise ValueError('Broad/native source fingerprint mismatch before staging')
    results=[];source_errors=[]
    for row in rows:
        try:current=source_inputs.snapshot(REPO,base_only=baseline['base_only'])
        except (OSError,ValueError,KeyError,TypeError) as error:
            source_errors=['source-snapshot-error: '+str(error)];break
        if current['sha256']!=baseline['sha256']:
            source_errors=source_inputs.changes(baseline,current);break
        results.append(execute_row(row,engine,qualification=qualification))
        try:current=source_inputs.snapshot(REPO,base_only=baseline['base_only'])
        except (OSError,ValueError,KeyError,TypeError) as error:
            source_errors=['source-snapshot-error: '+str(error)];break
        if current['sha256']!=baseline['sha256']:
            source_errors=source_inputs.changes(baseline,current);break
    return {'results':results,'source_fingerprint':baseline,'source_errors':source_errors}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task',choices=['test-list','test-plan','qc-test'])
    parser.add_argument('--repo',type=Path,default=REPO)
    for name in ('suite','case','profile'):parser.add_argument('--'+name,action='append',default=[])
    parser.add_argument('--tier',choices=['core','extended'],default='core')
    parser.add_argument('--changed-since');parser.add_argument('--engine')
    parser.add_argument('--changed-path',action='append',default=None)
    parser.add_argument('--expected-source-sha256',help=argparse.SUPPRESS)
    args=parser.parse_args()
    try:
        if args.task=='qc-test' and args.repo.resolve()!=REPO: raise ValueError('Execution is repository-owned; --repo is discovery-only')
        document=load(args.repo)
        absent=audit_inventory(args.repo,document)
        if absent:raise ValueError('Uncatalogued fixtures: '+', '.join(absent))
        broken=audit_links(args.repo,document)
        if broken:raise ValueError('Broken model references: '+', '.join(broken))
        if args.task=='test-list':
            if args.case or args.profile or args.changed_since or args.changed_path: raise ValueError('test-list supports suite filters; use test-plan for case/profile/change selection')
            unknown=set(args.suite)-{s['id'] for s in document['suites']}
            if unknown:raise ValueError('Unknown suites: '+', '.join(sorted(unknown)))
            if args.suite:document={**document,'suites':[s for s in document['suites'] if s['id'] in args.suite]}
            result={'task':args.task,'overall_status':'ok',**document}
        else:
            paths=args.changed_path
            if paths is not None:
                from workflows import normalize_paths
                paths=normalize_paths(args.repo,paths)
            selection=plan(args.repo,args.suite,args.case,args.profile,args.tier,args.changed_since,discovery=args.task=='test-plan',paths=paths)
            if args.task=='test-plan':result=selection
            else:
                execution=execute_selection(selection['rows'],args.engine,args.expected_source_sha256)
                failed=execution['source_errors'] or len(execution['results'])!=len(selection['rows']) or any(r['overall_status']=='failed' for r in execution['results'])
                result={'task':'qc-test','overall_status':'failed' if failed else selection['overall_status'],
                        'selection':selection,**execution}
        print(json.dumps(result,ensure_ascii=False))
        return int(result['overall_status']=='failed')
    except Exception as error:
        print(json.dumps({'task':args.task,'overall_status':'failed','error':str(error)}));return 1


if __name__=='__main__':sys.exit(main())
