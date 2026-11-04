"""Focused host conformance: routing, exact selectors, verdicts and supervision."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import importlib.util
from types import SimpleNamespace
import unittest
import zipfile
from unittest.mock import patch

import catalogue
import runner
import qualify_suites
import source_inputs

REPO=runner.REPO


class SelectionTests(unittest.TestCase):
    def test_core_matrix_complete(self):
        rows=catalogue.plan(REPO)['rows']
        self.assertEqual(set(catalogue.CORE),{r['suite'] for r in rows})
        self.assertEqual(11,len(rows))
        boot=[r for r in rows if r['suite']=='research-bootstrap']
        self.assertEqual({(False,False),(False,True),(True,False),(True,True)},
                         {(r['profile']['no_triggers'],r['profile']['flatten']) for r in boot})
        self.assertEqual({'enabled','disabled'},{r['profile']['quality'] for r in rows if r['suite']=='mirroring'})
        self.assertEqual(['triggers-1-flatten-0'],[r['profile']['id'] for r in boot if 'reload' in r['cases']])

    def test_invalid_selectors(self):
        for args in ({'suites':['missing']},{'cases':['reload']},{'suites':['mirroring'],'cases':['missing']},
                     {'suites':['mirroring'],'profiles':['missing']},{'suites':['quality-optional']},
                     {'suites':['research-bootstrap'],'cases':['reload'],'profiles':['triggers-0-flatten-0']},
                     {'suites':['mirroring'],'changed_since':'HEAD'}):
            with self.subTest(args=args),self.assertRaises(ValueError):catalogue.plan(REPO,**args)

    def test_incomplete_core_catalogue_is_rejected(self):
        document=catalogue.load(REPO)
        for change in ('inactive','missing-reload','extended-reload','missing-profile'):
            broken=copy.deepcopy(document)
            target=next(s for s in broken['suites'] if s['id']==('mirroring' if change=='missing-profile' else 'build-dispatch'))
            if change=='inactive':target['eligibility']='needs-port'
            elif change=='missing-reload':target['cases']=[c for c in target['cases'] if c['id']!='reload']
            elif change=='extended-reload':target['cases'][1]['tier']='extended'
            else:target['profiles'].pop()
            with self.subTest(change=change),patch.object(catalogue,'read_json',return_value=broken),self.assertRaises(ValueError):catalogue.load(REPO)

    def test_docs_empty_execution_fails(self):
        self.assertEqual([],catalogue.plan(REPO,discovery=True,paths=['README.md'])['rows'])
        with self.assertRaises(ValueError):catalogue.plan(REPO,paths=['README.md'])

    def test_routing(self):
        for path in ('exotic-space-industries-remembrance/control.lua','exotic-space-industries-remembrance/lib/lib.lua',
                     'exotic-space-industries-remembrance/info.json'):
            with self.subTest(path=path):
                self.assertTrue(set(catalogue.CORE)<={r['suite'] for r in catalogue.plan(REPO,paths=[path])['rows']})
        route=catalogue.plan(REPO,paths=['scripts/qc/native-tests/runner.py'])
        self.assertIn('runner-conformance',{r['suite'] for r in route['rows']})
        self.assertIn('host-timeout',next(r for r in route['rows'] if r['suite']=='runner-conformance')['cases'])
        self.assertEqual(set(catalogue.CORE),{r['suite'] for r in catalogue.plan(REPO,paths=['.codex/esir/factorio-development.json'])['rows']})
        self.assertTrue(catalogue.plan(REPO,paths=['exotic-space-industries-remembrance/scripts/unknown.lua'])['coverage_gaps'])
        bootstrap=catalogue.plan(REPO,paths=['exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/planets/vulcanus.lua'])
        self.assertIn('research-bootstrap',{r['suite'] for r in bootstrap['rows']})
        self.assertTrue(catalogue.plan(REPO,paths=['exotic-space-industries-remembrance/prototypes/uncovered.lua'])['coverage_gaps'])
        passage=catalogue.plan(REPO,paths=['exotic-space-industries-remembrance/lib/factory-passage-config.lua'])
        self.assertEqual({'engine-smoke'},{r['suite'] for r in passage['rows']})
        self.assertTrue(any(g.get('suite')=='factory-passage' for g in passage['coverage_gaps']))
        self.assertIn('benchmark',passage['supplementary_evidence'])
        legacy = catalogue.plan(REPO, discovery=True, paths=['.codex/skills/esir-dev/assets/zzz-fluid-rupture-qc_0.0.1/control.lua'])
        self.assertEqual(set(), {row['suite'] for row in legacy['rows']})
        self.assertTrue(any(gap.get('suite') == 'fluid-ruptures' and gap['reason'] == 'needs-port'
                            for gap in legacy['coverage_gaps']))

    def test_inventory_and_model_links(self):
        doc=catalogue.load(REPO)
        self.assertEqual([],catalogue.audit_inventory(REPO,doc))
        self.assertEqual([],catalogue.audit_links(REPO,doc))
        self.assertTrue(all(s.get('acceptance') for s in doc['suites']))
        self.assertTrue(all(s.get('existing_workflow') for s in doc['suites'] if s['eligibility']!='active'))

    def test_dirty_rename_deletion_untracked_and_index_reversal(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-routing-') as root:
            root=Path(root)
            def git(*args):return subprocess.check_output(['git',*args],cwd=root,stderr=subprocess.DEVNULL)
            git('init');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
            for name in ('old.lua','deleted.lua','index.lua'):(root/name).write_text('initial')
            git('add','.');git('commit','-m','fixture')
            git('mv','old.lua','renamed.lua');(root/'deleted.lua').unlink()
            (root/'index.lua').write_text('staged');git('add','index.lua');(root/'index.lua').write_text('initial')
            (root/'untracked.lua').write_text('new')
            self.assertEqual({'old.lua','renamed.lua','deleted.lua','index.lua','untracked.lua'},set(catalogue.changed_paths(root)))


class VerdictTests(unittest.TestCase):
    def setUp(self):
        self.expected=dict(run_id='run',suite='suite',profile='default',phase='candidate',input_hash='hash',engine_version='2.1.24',cases=['candidate'])
        self.report={**self.expected,'complete':True,'passed':True,'checks':[{'name':'actual','passed':True}]}

    def test_success_and_all_identity_fields(self):
        self.assertEqual([],catalogue.validate_report(self.report,self.expected,0))
        for key in ('run_id','suite','profile','phase','input_hash','engine_version'):
            bad={**self.report,key:'wrong'}
            self.assertIn('identity:'+key,catalogue.validate_report(bad,self.expected,0))

    def test_missing_empty_incomplete_failed_stale_fatal(self):
        for report in (None,[],{},dict(self.report,checks=[]),dict(self.report,complete=False),
                       dict(self.report,passed=False),dict(self.report,cases=[]),dict(self.report,cases=['candidate','candidate']),
                       dict(self.report,checks=[{'name':'bad','passed':False}])):
            with self.subTest(report=report):self.assertTrue(catalogue.validate_report(report,self.expected,0))
        self.assertIn('stale-report',catalogue.validate_report(self.report,self.expected,0,fresh=False))
        self.assertIn('fatal-engine-log',catalogue.validate_report(self.report,self.expected,0,fatal=True))
        self.assertIn('engine-exit',catalogue.validate_report(self.report,self.expected,1))

    def test_negatives_cannot_accept_unrelated_failure(self):
        process={'exit_code':1,'fatal':False,'timed_out':False}
        for phase in ('missing-report','tick-limit'):
            self.assertFalse(runner.qualify_negative(phase,['engine-exit','missing-or-malformed-report'],None,process))
            self.assertFalse(runner.qualify_negative(phase,['missing-or-malformed-report'],None,{**process,'exit_code':0}))
            self.assertTrue(runner.qualify_negative(phase,['missing-or-malformed-report'],None,{**process,'exit_code':0},True))
        report={**self.report,'passed':False,'checks':[{'name':'deliberate-negative','passed':False}]}
        errors=['engine-exit','failed-report','failed-assertion']
        self.assertTrue(runner.qualify_negative('explicit-failure',errors,report,process,True))
        contaminated={**report,'checks':report['checks']+[{'name':'effective-mod-quality','passed':False}]}
        self.assertFalse(runner.qualify_negative('explicit-failure',errors,contaminated,process,True))
        self.assertFalse(runner.qualify_negative('explicit-failure',errors+['identity:run_id'],report,process))
        self.assertFalse(runner.qualify_negative('lua-error',errors,report,process))
        self.assertFalse(runner.qualify_negative('host-timeout',['host-timeout'],None,{**process,'timed_out':True},False))
        self.assertFalse(runner.qualify_negative('host-timeout',['host-timeout'],report,{**process,'timed_out':True},True))

    def test_changed_private_input_and_selection(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-input-') as root:
            root=Path(root);source=root/'source';source.mkdir();(source/'a.lua').write_text('return 1')
            first=runner.source_hash({'main':source})[0];(source/'a.lua').write_text('return 2')
            self.assertNotEqual(first,runner.source_hash({'main':source})[0])
            config=root/'config.ini';config.write_text('[path]\nread-data=a\nwrite-data=b\n')
            selection=root/'mod-list.json';selection.write_text('{"mods":[]}')
            record={'mods':str(root),'config':str(config)};first=runner.phase_inputs(record,'source')[0]
            selection.write_text('{"mods":[{"name":"quality","enabled":true}]}')
            self.assertNotEqual(first,runner.phase_inputs(record,'source')[0])
            first=runner.phase_inputs(record,'source')[0]
            (root/'mod-settings.dat').write_bytes(b'changed')
            self.assertNotEqual(first,runner.phase_inputs(record,'source')[0])
            first=runner.phase_inputs(record,'source')[0]
            config.write_text('[path]\nread-data=a\nwrite-data=b\n[graphics]\nfull-screen=false\n')
            self.assertEqual(first,runner.phase_inputs(record,'source')[0])
            config.write_text('[path]\nread-data=a\nwrite-data=changed\n')
            self.assertNotEqual(first,runner.phase_inputs(record,'source')[0])
            self.assertNotEqual(runner.phase_inputs(record,'source')[0],runner.phase_inputs(record,'changed-source')[0])

    def test_owned_child_timeout(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-timeout-') as root:
            result=runner.run_process([sys.executable,'-c','import time;time.sleep(30)'],Path(root)/'child.log',0.2)
            self.assertTrue(result['timed_out']);self.assertLess(result['elapsed_seconds'],15)

    def test_fatal_graphics_error_terminates_only_owned_child(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-fatal-') as root:
            result=runner.run_process([sys.executable,'-u','-c',
                'import time;print("Error AtlasBuilder.cpp: File missing");time.sleep(30)'],Path(root)/'child.log',20)
            self.assertTrue(result['fatal']);self.assertFalse(result['timed_out']);self.assertLess(result['elapsed_seconds'],15)

    def test_native_path_preserves_file_identity(self):
        path=REPO/'exotic-space-industries-remembrance-graphics-1/graphics/other/kirazy-semi-classic-mining-drill/tier_1/hr-electric-mining-drill-W-wet-window-background-front.png'
        self.assertTrue(Path(runner.native_path(path)).samefile(path))

    def test_engine_log_requires_exact_executable_and_data_root(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-engine-log-') as directory:
            root=Path(directory);(root/'data').mkdir();log=root/'engine.log'
            record={'engine':str(root/'bin/x64/factorio.exe')}
            good='Factorio 2.1.24 (build 87808)\nRead data path: '+str(root/'data')+'\nLoading mod base 2.1.24 (data.lua)'
            log.write_text(good);runner.verify_engine_log(record,log)
            for bad in (good.replace('2.1.24','2.0.77'),good.replace(str(root/'data'),str(root))):
                log.write_text(bad)
                with self.assertRaises(RuntimeError):runner.verify_engine_log(record,log)

    def test_other_engine_families_rejected_before_context_or_staging(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-engine-family-') as directory:
            root=Path(directory);(root/'data/base').mkdir(parents=True)
            for version in ('2.0.77','2.1.23','2.2.0'):
                (root/'data/base/info.json').write_text(json.dumps({'version':version}))
                # There is deliberately no executable: wrong base/profile must
                # fail before engine discovery, fallback or registration.
                with self.assertRaisesRegex(RuntimeError,'exact profile/base 2.1.24'):
                    runner.managed('stage',{'engine':str(root/'bin/x64/factorio.exe')})

    def test_staging_failure_is_a_failed_row(self):
        row=catalogue.plan(REPO,suites=['build-dispatch'])['rows'][0]
        with patch.object(runner,'managed',side_effect=RuntimeError('Missing required helper')):
            result=runner.execute_row(row)
        self.assertEqual('failed',result['overall_status']);self.assertIn('Missing required helper',result['error'])

    def test_suite_qualification_rejects_contaminated_failures(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-qualification-') as directory:
            root=Path(directory)
            def compact(report,log):
                entries=[]
                with zipfile.ZipFile(root/'evidence.zip','w') as archive:
                    for name,value in {'reports/candidate.json':json.dumps(report),'reports/candidate.log':log}.items():
                        if name.endswith('.json') and not report:continue
                        data=value.encode('utf-8');archive.writestr(name,data)
                        entries.append({'name':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
                index={'run_id':'qualification-test','workflow':'qc-test','status':'failed','entries':entries,
                    'archive_sha256':hashlib.sha256((root/'evidence.zip').read_bytes()).hexdigest()}
                (root/'evidence-index.json').write_text(json.dumps(index))
                return index
            for suite in catalogue.CORE:
                report={'passed':False,'checks':[{'name':'fixture-exception','passed':False,'detail':'personal-off-gate-low-power'}]}
                log='';errors=['engine-exit','failed-report','failed-assertion'];fatal=False;exit_code=1
                if suite=='build-dispatch':report['checks']=[{'name':'native-ticks','passed':False}]
                elif suite=='scheduler-event-tick':log='Error while running event: controlled-clock-counter-tick-0'
                elif suite=='research-events':log='Error while running event: scripted-order: tech-scripted,tesla-scripted\n'
                elif suite=='induction-circuit':log='Error while running event: INDUCTION_CIRCUIT_QC all four outputs default off'
                elif suite=='mirroring':report['checks']=[{'name':'assert-1','passed':False,'detail':'ei-advanced-chem-plant: eligibility'}]
                elif suite=='research-bootstrap':report={'passed':True,'checks':[{'name':'snapshot','passed':True}]};errors=[];exit_code=0
                if log:
                    log='Error RunTest.cpp:101: The mod caused a non-recoverable error.\n'+log
                    report={};errors=['engine-exit','missing-or-malformed-report','fatal-engine-log'];fatal=True
                compact(report,log)
                # Loose remnants must never supersede the authenticated archive.
                (root/'candidate.json').write_text('{}');(root/'candidate.log').write_text('unrelated error')
                result={'suite':suite,'run_id':'qualification-test','overall_status':'failed','injected_defect':'controlled','evidence':str(root),
                    'housekeeping':{'status':'failed','cleanup_status':'compacted'},
                    'error':'updates' if suite=='research-bootstrap' else 'Native phase failed',
                    'phases':[{'phase':'candidate','passed':False,'errors':errors,'process':{'exit_code':exit_code,'timed_out':False,'fatal':fatal}}]}
                self.assertTrue(qualify_suites.detected(result),suite)
                for contamination in ('runner-fixture-inputs-changed','staged-selection-changed','identity:run_id','stale-report','host-timeout'):
                    bad=copy.deepcopy(result);bad['phases'][0]['errors'].append(contamination)
                    self.assertFalse(qualify_suites.detected(bad),(suite,contamination))
                bad=copy.deepcopy(result);bad['phases'][0]['process']['timed_out']=True
                self.assertFalse(qualify_suites.detected(bad),suite)
                if log:
                    compact(report,log+'\nError AtlasBuilder.cpp: unrelated')
                    self.assertFalse(qualify_suites.detected(result),suite)
                for corruption in ('run_id','archive_sha256','entry_hash','missing-log','duplicate'):
                    index=compact(report,log)
                    if corruption in ('run_id','archive_sha256'):index[corruption]='wrong'
                    elif corruption=='entry_hash':index['entries'][0]['sha256']='wrong'
                    elif corruption=='missing-log':index['entries']=[e for e in index['entries'] if e['name']!='reports/candidate.log']
                    else:index['entries'].append(index['entries'][0])
                    (root/'evidence-index.json').write_text(json.dumps(index))
                    self.assertFalse(qualify_suites.detected(result),(suite,corruption))
                for malformed in ([1],{'checks':None},{'checks':[None]}):
                    compact(malformed,log)
                    self.assertFalse(qualify_suites.detected(result),(suite,malformed))
                if suite == 'research-bootstrap':
                    native_result = copy.deepcopy(result)
                    native_result['error'] = 'Native phase failed: candidate'
                    native_result['phases'][0]['errors'] = ['engine-exit', 'failed-report', 'failed-assertion']
                    native_result['phases'][0]['process']['exit_code'] = 1
                    native_report = {'passed': False, 'checks': [{'name': 'fixture-exception', 'passed': False,
                        'detail': '__esir-qc-native-tests__/native-suite.lua:9: Wrong native technology ingredients'}]}
                    compact(native_report, '')
                    self.assertTrue(qualify_suites.detected(native_result))
                    native_report['checks'][0]['detail'] = 'An unrelated fixture failure'
                    compact(native_report, '')
                    self.assertFalse(qualify_suites.detected(native_result))


class CommonInputTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Windows PowerShell bridge')
    def test_managed_bridge_resolves_native_hash_cmdlet(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-shell-') as directory:
            root = Path(directory)
            (root/'managed.ps1').write_text('''param($Action,$Request)
$ErrorActionPreference = 'Stop'
$hash = Get-FileHash -LiteralPath $Request -Algorithm SHA256
@{hash=$hash.Hash;module_path=$env:PSModulePath} | ConvertTo-Json -Compress
''')
            sentinel = str(root/'foreign-modules')
            with patch.object(runner, 'HERE', root), patch.dict(os.environ, {'PSModulePath': sentinel}):
                result = runner.managed('validate', {'probe': True})
            self.assertEqual(64, len(result['hash']))
            self.assertNotIn(sentinel, result['module_path'])

    def test_discovery_override_and_content_changes(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-common-') as directory:
            root=Path(directory);repo=root/'repo';repo.mkdir()
            profile=repo/'.codex/esir';profile.mkdir(parents=True)
            seed=repo/'seed';seed.mkdir();(seed/'mod-list.json').write_text('{}')
            def mod(path,name):
                path.mkdir();(path/'info.json').write_text(json.dumps({'name':name,'factorio_version':'2.1'}))
                (path/'control.lua').write_text('return 1')
            mod(repo/'walls','enhanced-walls-continued');mod(root/'sibling','enhanced-walls-continued')
            (profile/'factorio-development.json').write_text(json.dumps({'engine_version':'2.1.24','dependency_seed':'seed','enhanced_walls_source':'../sibling'}))
            initial=source_inputs.snapshot(repo)
            self.assertEqual(str(root/'sibling'),initial['effective_runtime_roots']['enhanced-walls-continued'])
            self.assertEqual(2,len(initial['roots']))
            (root/'sibling/control.lua').write_text('return 2')
            changed=source_inputs.snapshot(repo)
            self.assertIn('profile:enhanced_walls_source/control.lua',source_inputs.changes(initial,changed))
            (root/'sibling/control.lua').write_text('return 1')
            mod(repo/'added','added')
            self.assertIn('roots',source_inputs.changes(initial,source_inputs.snapshot(repo)))
            (seed/'mod-settings.dat').write_bytes(b'changed')
            self.assertIn('baseline_configuration',source_inputs.changes(initial,source_inputs.snapshot(repo)))

    def test_selection_rejects_between_row_drift_and_broad_mismatch(self):
        rows=[{'suite':'build-dispatch'},{'suite':'research-events'}]
        before={'sha256':'before','base_only':False,'files':{},'roots':[],'profile_sha256':'p','effective_runtime_roots':{},'baseline_configuration':{}}
        after={**before,'sha256':'after','files':{'mod/control.lua':'changed'}}
        with patch.object(source_inputs,'snapshot',side_effect=[before,before,after]),patch.object(runner,'execute_row',return_value={'overall_status':'ok'}) as execute:
            result=runner.execute_selection(rows)
            self.assertEqual(1,execute.call_count)
            self.assertEqual(['mod/control.lua'],result['source_errors'])
        with patch.object(source_inputs,'snapshot',return_value=before),patch.object(runner,'execute_row') as execute:
            with self.assertRaisesRegex(ValueError,'before staging'):runner.execute_selection(rows,expected_source_sha256='other')
            execute.assert_not_called()
        with patch.object(source_inputs,'snapshot',side_effect=[before,before,OSError('source disappeared')]),patch.object(runner,'execute_row',return_value={'overall_status':'ok'}):
            result=runner.execute_selection(rows)
            self.assertEqual(1,len(result['results']))
            self.assertIn('source disappeared',result['source_errors'][0])


class LegacyAdapterTests(unittest.TestCase):
    def test_quality_uses_context_without_precreating_worker(self):
        path=REPO/'scripts/qc/quality-optional/run.py'
        spec=importlib.util.spec_from_file_location('quality_adapter_test',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='native-quality-') as directory:
            root=Path(directory);worker=root/'worker';frozen=root/'frozen';frozen.mkdir()
            mods=root/'actual-mods';write=root/'actual-write';scratch=root/'actual-scratch'
            def launch(command,**kwargs):
                if 'stage' in command:
                    self.assertFalse(worker.exists())
                    self.assertIn('-MainSource',command);self.assertIn('-FixtureRoot',command)
                    worker.mkdir();mods.mkdir();write.mkdir();scratch.mkdir();(mods/'esir-qc-quality-optional').mkdir()
                    (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ('space-age','recycler',module.NAME,'quality')]}))
                    (worker/'context.json').write_text(json.dumps({'run_id':'test','source_mode':'private-mutable','options':{'main_source':str(frozen)},
                        'config':str(root/'actual.ini'),'mod_view_root':str(mods),'write_data_root':str(write),'scratch_root':str(scratch)}))
                elif '--create' in command:
                    self.assertEqual(str(root/'actual.ini'),command[command.index('--config')+1])
                    self.assertEqual(str(mods),command[command.index('--mod-directory')+1])
                    kwargs['stdout'].write('QUALITY_OPTIONAL_DATA_PASSED 1\n')
                return SimpleNamespace(returncode=0,stdout='',stderr='')
            with patch.object(module.subprocess,'run',side_effect=launch):
                helper=module.stage(worker,frozen,Path('engine'))
                self.assertEqual(mods/'esir-qc-quality-optional',helper)
                case={'id':'host','quality':False};module.configure(worker,case)
                self.assertFalse(next(m['enabled'] for m in json.loads((mods/'mod-list.json').read_text())['mods'] if m['name']=='quality'))
                self.assertTrue(module.execute(worker,Path('engine'),case,['--create',str(scratch/'save.zip')],'create')['passed'])
                self.assertEqual(write/'script-output',module.output_path(worker))
                self.assertEqual(helper,module.stage(worker,frozen,Path('engine')))
                self.assertFalse((worker/'mods').exists())


if __name__=='__main__':unittest.main(verbosity=2)
