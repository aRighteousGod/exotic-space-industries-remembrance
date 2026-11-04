"""Focused 2.1.24 on/off/on acceptance using the shared managed staging layer.

The historical full profile/geometry suite is deliberately not relabelled current.
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / 'scripts/qc/native-tests'))
import runner
import source_inputs
import settings_file
from catalogue import validate_report


def main():
    baseline = source_inputs.snapshot(REPO)
    record = runner.managed('stage', {'engine': None, 'base_only': False, 'quality': 'enabled',
        'scenario': 'vanilla-beacon-profiles/on-off-on',
        'reproduction': 'python -B scripts/qc/beacon-profiles/native.py'})
    result = {'run_id': record['run_id'], 'engine_version': '2.1.24', 'overall_status': 'failed', 'phases': []}
    evidence = Path(record['evidence'])
    helper = Path(record['mutable']['esir-qc-native-tests'])
    main_mod = Path(record['mutable']['exotic-space-industries-remembrance'])
    write = Path(record['write_data'])
    try:
        runner.write_json(evidence/'source-inputs.json', baseline)
        selected = {m['name']: m['enabled'] for m in runner.read_json(Path(record['mods'])/'mod-list.json')['mods']}
        info = runner.read_json(helper/'info.json')
        info['dependencies'] = ['base = 2.1.24'] + ['? '+n for n, enabled in sorted(selected.items()) if enabled and n not in ('base',info['name'])]
        runner.write_json(helper/'info.json', info)
        for name in ('data.lua','settings-updates.lua','snapshot.lua','data-final-fixes.lua'):
            (helper/name).write_text((HERE/name).read_text(encoding='utf-8').replace('__zzz-esir-beacon-profile-qc__','__esir-qc-native-tests__'),encoding='utf-8')
        final = helper/'data-final-fixes.lua'
        final.write_text(final.read_text(encoding='utf-8').replace(
            'require("__esir-qc-native-tests__/snapshot").verify()',
            'local vanilla = data.raw.beacon.beacon\nassert(not test.overload or (#vanilla.profile == 1 and vanilla.profile[1] == 1), "Final vanilla profile")'),encoding='utf-8')
        shutil.copyfile(HERE/'native.lua',helper/'native-suite.lua')
        path = main_mod/'data-final-fixes.lua'
        text = path.read_text(encoding='utf-8')
        marker = 'require("scripts/data-final-updates/beacon-profiles")'
        assert text.count(marker)==1
        path.write_text(text.replace(marker,'require("__esir-qc-native-tests__/snapshot")\n'+marker+
            '\nrequire("__esir-qc-native-tests__/snapshot").verify()'),encoding='utf-8')
        common = ['--config',runner.native_path(record['config']),'--mod-directory',runner.native_path(record['mods']),
                  '--disable-audio','--disable-migration-window']
        capabilities=runner.run_process([record['engine'],'--help'],evidence/'capabilities.log',15)
        assert capabilities['exit_code']==0 and '--test-save' in Path(capabilities['log']).read_text(encoding='utf-8')
        server = write/'server-settings.json'
        runner.write_json(server, {'name':'Private beacon QC','description':'Managed beacon regression fixture',
            'visibility':{'public':False,'lan':False},
            'require_user_verification':False,'auto_pause':False,'autosave_interval':0})
        seed = Path(record['scratch'])/'seed.zip'
        checkpoint = write/'saves/native-checkpoint.zip'
        checkpoint.parent.mkdir(exist_ok=True)
        for index, enabled in enumerate((True,False,True)):
            phase = ('on','off','on-again')[index]
            (helper/'test-config.lua').write_text('return '+runner.lua({'profile':'strict','overload':enabled,'previous':index})+'\n',encoding='utf-8')
            context = {'run_id':record['run_id'],'suite':'vanilla-beacon-profiles','profile':phase,
                'phase':phase,'cases':[phase],'deadline_ticks':1200,'checkpoint':index<2,
                'input_hash':'pending','engine_version':'2.1.24','expected_mods':selected}
            (helper/'fixture-config.lua').write_text('return '+runner.lua(context)+'\n',encoding='utf-8')
            context['input_hash']=runner.source_hash({'main':main_mod,'helper':helper})[0]
            (helper/'fixture-config.lua').write_text('return '+runner.lua(context)+'\n',encoding='utf-8')
            frozen, files = runner.source_hash({'main':main_mod,'helper':helper})
            runner.write_json(evidence/(phase+'-inputs.json'),{'context':context,'frozen':frozen,'files':files})
            # The private bool setting is forced; deleting only this task's
            # generated settings file lets each phase attest its complete defaults.
            settings = Path(record['mods'])/'mod-settings.dat'
            if settings.exists(): settings.unlink()
            if index==0:
                created=runner.run_process([record['engine'],*common,'--create',seed],evidence/'create.log',600)
                assert created['exit_code']==0 and not created['fatal'] and not created['timed_out'],created
                runner.verify_engine_log(record,created['log'])
            if index<2:
                launch=['--start-server',seed,'--server-settings',server,'--bind','127.0.0.1','--port','34449']
                if checkpoint.exists(): checkpoint.unlink()
            else:
                launch=['--test-save',seed,'--test-arg',json.dumps(context,separators=(',',':')),'--test-ticks','1202']
            before=runner.phase_inputs(record,frozen)[1]
            process=runner.run_process([record['engine'],*common,*launch],evidence/(phase+'.log'),600,checkpoint if index<2 else None)
            runner.verify_engine_log(record,process['log'])
            report_path=write/'script-output'/('native-test-'+phase+'.json')
            report=runner.read_json(report_path) if report_path.exists() else None
            exit_code=0 if index<2 and process.get('checkpoint_verified') else process['exit_code']
            errors=validate_report(report,context,exit_code,fresh=report_path.exists() and report_path.stat().st_mtime>=process['started'],fatal=process['fatal'])
            if process['timed_out']: errors.append('timeout')
            if index<2 and not process.get('checkpoint_verified'): errors.append('checkpoint-not-verified')
            if runner.source_hash({'main':main_mod,'helper':helper})[0]!=frozen: errors.append('staged-source-changed')
            runner.validate_selection(record,before,context,process,evidence,phase)
            defaults=runner.read_json(write/'script-output/native-setting-defaults.json')
            settings_file.assert_defaults(settings.read_bytes(),defaults['defaults'])
            runner.managed('validate',{'run_id':record['run_id']})
            if source_inputs.snapshot(REPO)['sha256']!=baseline['sha256']: errors.append('live-source-changed')
            runner.write_json(evidence/(phase+'.json'),report)
            result['phases'].append({'phase':phase,'passed':not errors,'errors':errors,'process':process,
                'assertions':len(report.get('checks',[])) if report else 0})
            runner.write_json(evidence/'progress.json',result)
            assert not errors,errors
            if index<2:
                shutil.copyfile(checkpoint,seed)
                runner.write_json(evidence/(phase+'-checkpoint.json'),{'sha256':hashlib.sha256(seed.read_bytes()).hexdigest(),'bytes':seed.stat().st_size})
        result['overall_status']='ok'
    except Exception as error:
        result['error']=str(error)
    finally:
        runner.write_json(evidence/'result.json',result)
        try:
            closed=runner.managed('finish',{'run_id':record['run_id'],'overall_status':result['overall_status'],'result':result})
            result['housekeeping']={key:closed.get(key) for key in ('status','cleanup_status','payload_path')}
        except Exception as error:
            result['overall_status']='failed'
            result['housekeeping_error']=str(error)
            runner.write_json(evidence/'closeout-error.json',result)
        print(json.dumps(result))
    return int(result['overall_status']!='ok')


if __name__=='__main__':
    sys.exit(main())
