"""Scope isolation, acceptance boundaries and failure propagation without an engine."""
import copy
import json
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

import catalogue
import runner
import workflows as flow
import settings_file

REPO = runner.REPO
MAIN = 'exotic-space-industries-remembrance/'


class ScopeTests(unittest.TestCase):
    def plan(self, level='quick', **kwargs):
        return flow.make_plan(REPO, level, **kwargs)

    def test_required_scope_and_exact_selectors(self):
        for args in ({}, {'suites':['induction-circuit'], 'paths':['AGENTS.md']},
                     {'paths':[]}, {'paths':['']}, {'paths':['../escape.lua']},
                     {'paths':['scripts/*.ps1']}, {'paths':['scripts']}, {'paths':['not-a-file.lua']},
                     {'suites':['unknown']}, {'suites':['mirroring'],'profiles':['wrong']},
                     {'suites':['mirroring'],'cases':['reload']},
                     {'suites':['mirroring'],'changed_since':'HEAD'}):
            with self.subTest(args=args), self.assertRaises(ValueError): self.plan(**args)

    def test_task_files_do_not_include_other_dirty_work(self):
        with patch.object(catalogue,'changed_paths',side_effect=AssertionError('must not inspect dirt')):
            result=self.plan(paths=[MAIN+'scripts/control/induction-matrix.lua'])
        self.assertEqual(['induction-circuit'],[r['suite'] for r in result['rows']])
        self.assertEqual([MAIN+'scripts/control/induction-matrix.lua'],result['changed_paths'])
        self.assertEqual(['candidate'],result['rows'][0]['cases'])
        self.assertEqual(1,result['expected_native_game_launches'])

    def test_quick_presets_and_complete_targeted_matrices(self):
        for suite,profile,count in (('induction-circuit','default',1),('research-bootstrap','triggers-1-flatten-0',4),('mirroring','quality-enabled',2)):
            quick=self.plan(suites=[suite]); targeted=self.plan('targeted',suites=[suite])
            self.assertEqual([profile],[r['profile']['id'] for r in quick['rows']])
            self.assertEqual(['candidate'],quick['rows'][0]['cases'])
            self.assertTrue(quick['omitted_requirements'])
            self.assertEqual(count,len(targeted['rows']))
            self.assertFalse(targeted['omitted_requirements'])
        subset=self.plan('targeted',suites=['mirroring'],cases=['candidate'],profiles=['quality-disabled'])
        self.assertEqual('subset',subset['acceptance_scope'])
        self.assertEqual(3,len(subset['omitted_requirements']))

    def test_docs_locale_and_catalogue_are_engine_free(self):
        for path in ('AGENTS.md',MAIN+'locale/en/runtime-options.cfg',catalogue.CATALOGUE):
            result=self.plan(paths=[path])
            self.assertFalse(result['rows']); self.assertFalse(result['additional_engine_work'])
        self.assertIn('native-host-tests',[c['id'] for c in self.plan(paths=[catalogue.CATALOGUE])['checks']])

    def test_narrow_helpers_and_infrastructure(self):
        scheduler=self.plan(paths=[MAIN+'lib/runtime-scheduler.lua'])
        self.assertEqual({'scheduler-event-tick'},{r['suite'] for r in scheduler['rows']})
        infra=self.plan('targeted',paths=['scripts/qc/native-tests/runner.py'])
        self.assertEqual({'build-dispatch','induction-circuit','runner-conformance'},{r['suite'] for r in infra['rows']})
        self.assertIn('host-timeout',next(r['cases'] for r in infra['rows'] if r['suite']=='runner-conformance'))
        quick=self.plan(paths=['scripts/qc/native-tests/runner.py'])
        self.assertTrue(all(r['cases']==['candidate'] for r in quick['rows']))
        tests=self.plan(paths=['scripts/qc/native-tests/test_runner.py'])
        self.assertFalse(tests['rows'])

    def test_unmigrated_coverage_is_not_broad_acceptance(self):
        result=self.plan(paths=[MAIN+'lib/factory-passage-config.lua'])
        self.assertEqual('warning',result['overall_status'])
        self.assertEqual(['engine-smoke'],[r['suite'] for r in result['rows']])
        self.assertTrue(result['coverage_gaps'])
        combined=self.plan(paths=[MAIN+'lib/factory-passage-config.lua',MAIN+'scripts/control/induction-matrix.lua'])
        self.assertEqual(['induction-circuit'],[r['suite'] for r in combined['rows']])
        self.assertTrue(combined['coverage_gaps'])

    def test_gaia_companion_runs_native_once(self):
        quick=self.plan(suites=['gaia-resources'])
        self.assertEqual(['native-tests'],[c['id'] for c in quick['checks'] if c['id']!='scoped-static'])
        target=self.plan('targeted',suites=['gaia-resources'])
        self.assertFalse(target['rows'])
        self.assertEqual(1,len([c for c in target['checks'] if c['id']=='gaia-acceptance']))
        self.assertFalse(target['omitted_requirements'])

    def test_explicit_and_extended_smoke_are_never_removed(self):
        for level in ('quick', 'targeted'):
            selected=self.plan(level,suites=['engine-smoke','induction-circuit'])
            self.assertEqual({'engine-smoke','induction-circuit'},{r['suite'] for r in selected['rows']})
        extended=catalogue.plan(REPO,tier='extended')
        self.assertIn('engine-smoke',{r['suite'] for r in extended['rows']})

    def test_fallback_smoke_requires_selected_equivalent_candidate(self):
        document=catalogue.load(REPO)
        bootstrap=next(s for s in document['suites'] if s['id']=='research-bootstrap')
        # Use the actual mapped bootstrap source; its startup overrides must not
        # replace the default-profile initialization check for an uncovered file.
        source=next(p for p in bootstrap['paths'] if (REPO/p).is_file())
        for level in ('quick','targeted'):
            selected=self.plan(level,paths=[MAIN+'lib/factory-passage-config.lua',source])
            self.assertIn('engine-smoke',{r['suite'] for r in selected['rows']})
        smoke={'suite':'engine-smoke','profile':{'id':'default','quality':'enabled'},
               'cases':['candidate'],'reasons':['initialization only: missing.lua']}
        other={'suite':'mirroring','profile':{'id':'quality-disabled','quality':'disabled'},
               'cases':['candidate'],'reasons':['mapped.lua']}
        self.assertEqual(2,len(catalogue.deduplicate_routed_smoke([smoke,other])))
        other['profile']={'id':'quality-enabled','quality':'enabled'}
        other['cases']=['reload']
        self.assertEqual(2,len(catalogue.deduplicate_routed_smoke([smoke,other])))
        other['cases']=['candidate']
        self.assertEqual([other],catalogue.deduplicate_routed_smoke([smoke,other]))

    def test_data_and_assets_are_targeted_only(self):
        path=MAIN+'scripts/data-updates/vanilla-updates/recipes.lua'
        quick=self.plan(paths=[path]); target=self.plan('targeted',paths=[path])
        self.assertNotIn('final-data',[c['id'] for c in quick['checks']])
        self.assertIn('final-data',[c['id'] for c in target['checks']])
        for result in (quick,target): self.assertNotIn('full',[c.get('mode') for c in result['checks']])

    def test_plan_only_has_no_engine_or_registration(self):
        with (patch.object(flow,'execute',side_effect=AssertionError('execution')),
              patch.object(flow,'bridge',side_effect=AssertionError('bridge')),
              patch.object(sys,'argv',['workflows.py','qc-quick','--suite','engine-smoke','--plan-only']),
              patch('builtins.print')):
            self.assertEqual(0,flow.main())

    def test_native_failure_or_missing_row_fails_scoped_aggregate(self):
        for rows in ([],[{'overall_status':'failed'}]):
            with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='scoped-verdict-') as root:
                owner={'id':'test','payload_path':str(root)}
                def bridge(action,data):
                    return owner if action=='register' else {'status':'success'}
                with (patch.object(flow,'bridge',side_effect=bridge),
                      patch.object(flow,'scoped_static',return_value={'overall_status':'ok'}),
                      patch.object(flow.source_inputs,'snapshot',return_value={'sha256':'same'}),
                      patch.object(runner,'execute_selection',return_value={'results':rows,'source_errors':[]})):
                    result=flow.execute(self.plan(suites=['engine-smoke']))
                self.assertEqual('failed',result['overall_status'])

    def test_all_active_presets_are_validated(self):
        document=catalogue.load(REPO)
        target=next(s for s in document['suites'] if s['eligibility']=='active')
        target.pop('quick')
        with patch.object(catalogue,'read_json',return_value=document),self.assertRaises(ValueError): catalogue.load(REPO)

    def test_changed_since_includes_both_rename_sides(self):
        names=[MAIN+'lib/alerts.lua',MAIN+'lib/alert-catalog.lua']
        with patch.object(catalogue,'changed_paths',return_value=names): result=self.plan(changed_since='HEAD~1')
        self.assertEqual(names,result['changed_paths'])
        self.assertEqual(['alert-preferences'],[r['suite'] for r in result['rows']])


class SettingsNormalization(unittest.TestCase):
    @staticmethod
    def binary(values):
        def string(value):
            value=value.encode('utf-8')
            return b'\0'+(bytes([len(value)]) if len(value)<255 else b'\xff'+struct.pack('<I',len(value)))+value
        def tree(value):
            if isinstance(value,bool): return b'\1\0'+bytes([value])
            if isinstance(value,str): return b'\3\0'+string(value)
            if isinstance(value,(int,float)): return b'\2\0'+struct.pack('<d',value)
            return b'\5\0'+struct.pack('<I',len(value))+b''.join(string(k)+tree(v) for k,v in value.items())
        return struct.pack('<4H',2,1,24,1)+b'\0'+tree(values)

    def setUp(self):
        self.defaults={'startup':{'flag':False,'name':'日本語'},'runtime-global':{'count':3},'runtime-per-user':{}}
        self.values={group:{k:{'value':v} for k,v in values.items()} for group,values in self.defaults.items()}

    def test_actual_values_and_malformed_settings(self):
        data=self.binary(self.values)
        self.assertEqual(self.values,settings_file.assert_defaults(data,self.defaults))
        for bad in (data[:-1],data+b'!',b'\0'*9,self.binary({'startup':{}})):
            with self.assertRaises(ValueError):settings_file.assert_defaults(bad,self.defaults)
        for change in ('changed','missing','extra','bool-type'):
            values=copy.deepcopy(self.values)
            if change=='changed':values['runtime-global']['count']['value']=4
            elif change=='missing':values['startup'].pop('flag')
            elif change=='extra':values['startup']['unexpected']={'value':False}
            else:values['startup']['flag']['value']=0
            with self.subTest(change=change),self.assertRaises(ValueError):settings_file.assert_defaults(self.binary(values),self.defaults)

    def test_normalization_requires_fresh_identity_and_default_inventory(self):
        with tempfile.TemporaryDirectory(dir=REPO/'temp',prefix='settings-contract-') as root:
            root=Path(root);(root/'script-output').mkdir()
            config=root/'config.ini';config.write_text('[path]\nread-data=a\nwrite-data=b\n')
            (root/'mod-list.json').write_text('{"mods":[{"name":"base","enabled":true},{"name":"absent","enabled":false}]}')
            record={'mods':str(root),'config':str(config),'write_data':str(root)}
            before=runner.phase_inputs(record,'source')[1]
            # Reordering/pruning inactive mods is equivalent; adding active mods is not.
            (root/'mod-list.json').write_text('{"mods":[{"enabled":true,"name":"base"}]}')
            self.assertEqual(before,runner.phase_inputs(record,'source')[1])
            expected={k:k for k in ('run_id','suite','profile','phase','input_hash','engine_version')}
            report={**expected,'defaults':self.defaults}; path=root/'script-output/native-setting-defaults.json'
            path.write_text(json.dumps(report));(root/'mod-settings.dat').write_bytes(self.binary(self.values))
            runner.validate_selection(record,before,expected,{'started':0},root,'pass')
            with self.assertRaises(ValueError):runner.validate_selection(record,before,expected,{'started':path.stat().st_mtime+1},root,'stale')
            path.write_text(json.dumps({**report,'run_id':'wrong'}))
            with self.assertRaises(ValueError):runner.validate_selection(record,before,expected,{'started':0},root,'wrong')
            existing=runner.phase_inputs(record,'source')[1]
            (root/'mod-settings.dat').write_bytes(b'changed')
            with self.assertRaises(ValueError):runner.validate_selection(record,existing,expected,{'started':0},root,'changed')
            (root/'mod-list.json').write_text('{"mods":[{"name":"extra","enabled":true}]}')
            with self.assertRaises(ValueError):runner.validate_selection(record,before,expected,{'started':0},root,'selection')


if __name__=='__main__': unittest.main()
