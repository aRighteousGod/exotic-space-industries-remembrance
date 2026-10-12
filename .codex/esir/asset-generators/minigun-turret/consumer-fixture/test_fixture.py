"""Offline synthetic contract tests only; no Factorio or native acceptance."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import unittest
import uuid

ROOT=Path(__file__).resolve().parent
REPO=next(path for path in ROOT.parents if (path/'scripts/invoke-esir-dev.ps1').is_file())
TEST_OUTPUT=REPO/'output/minigun-implementation/consumer-unit-tests'


def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result


analyzer=module('analyze_fixture');builder=module('build_fixture')


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value),encoding='utf-8')


class Contracts(unittest.TestCase):
    def setUp(self):
        # TemporaryDirectory uses mode0700, whose ACL is unusable by this
        # Windows sandbox token. Ordinary owned workspace directories inherit
        # the correct ACL. Nothing outside this unique test root is touched.
        TEST_OUTPUT.mkdir(parents=True,exist_ok=True)
        self.root=TEST_OUTPUT/('unit-'+uuid.uuid4().hex[:8]);self.root.mkdir()

    def tearDown(self):
        path=self.root.resolve()
        assert path.parent==TEST_OUTPUT and path.name.startswith('unit-') and not path.is_symlink()
        shutil.rmtree(path)

    def artifact(self):
        return {'artifacts':[{'profile':'sd','pack':builder.SD,'path':'graphics/x.png',
            'fixture_path':'sd/graphics/x.png','sha256':'a'*64,'bytes':10,'size':[1,1]}]}

    def test_inventory_rejects_old_pack(self):
        value=self.artifact();value['artifacts'][0]['pack']='exotic-space-industries-remembrance-graphics-5'
        with self.assertRaisesRegex(ValueError,'mixed-pack'):builder.inventory(value)

    def test_inventory_rejects_traversal(self):
        value=self.artifact();value['artifacts'][0]['path']='graphics/../x.png'
        with self.assertRaises(ValueError):builder.inventory(value)

    def test_inventory_rejects_duplicate(self):
        value=self.artifact();value['artifacts']*=2
        with self.assertRaises(ValueError):builder.inventory(value)

    def staged_plan(self,scenario='enabled'):
        helper=self.root/'mods'/analyzer.HELPER;helper.mkdir(parents=True)
        asset=helper.parent/analyzer.SD/'graphics/x.png';asset.parent.mkdir(parents=True);asset.write_bytes(b'unit-only-not-an-image')
        art=helper/'consumer-graphics-data.lua';art.write_text('return {}\n')
        plan={'schema':'esir.minigun.consumer-plan.v1','consumer_data_sha256':analyzer.sha(art),
            'pack_inputs':{analyzer.SD+'/graphics/x.png':analyzer.sha(asset)},
            'config':{'standalone':False,'scenario':scenario}}
        write(helper/'fixture-plan.json',plan)
        mods=[{'name':name,'enabled':True} for name in ('base',analyzer.SD,'exotic-space-industries-remembrance',analyzer.HELPER)]
        if scenario=='enabled':mods.append({'name':analyzer.HD,'enabled':True})
        write(helper.parent/'mod-list.json',{'mods':mods})
        return helper,asset

    def test_plan_detects_changed_pack_bytes(self):
        helper,asset=self.staged_plan();analyzer.verify_plan(helper);asset.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'pack input changed'):analyzer.verify_plan(helper)

    def test_plan_detects_profile_switch(self):
        helper,_=self.staged_plan();mods=analyzer.read(helper.parent/'mod-list.json')
        mods['mods'][-1]['enabled']=False;write(helper.parent/'mod-list.json',mods)
        with self.assertRaisesRegex(ValueError,'HD selection'):analyzer.verify_plan(helper)

    def test_absent_means_no_installed_folder(self):
        helper,_=self.staged_plan('absent');(helper.parent/analyzer.HD).mkdir()
        with self.assertRaisesRegex(ValueError,'Absent test'):analyzer.verify_plan(helper)

    def test_empty_pack_path_rejected(self):
        with self.assertRaises(ValueError):analyzer.pack_path(self.root,'')

    def native_audit(self):
        prefix='__'+analyzer.HD+'__/'
        icon={'icon':prefix+'graphics/item.png','icon_size':128}
        tech={'icon':prefix+'graphics/tech.png','icon_size':256}
        config={'profile':'hd','finalized':True,'entity_name':'ei-gatling-turret','ballistic':True}
        snapshot={'attack':{'cooldown':20,'range':30},'energy_per_shot':'1kJ'}
        audit={'before':copy.deepcopy(snapshot),'after':copy.deepcopy(snapshot),'sprite_paths':[prefix+'graphics/body.png'],
            'shadow_leaf_count':5,'icons':{'item':dict(icon),'ammo-turret':dict(icon),'technology':dict(tech),
                'recipe':{'main_product':'ei-gatling-turret'}},'consumer_untouched':True,'factory_options':{},
            'actual_visuals':{'unit_only':1},'expected_visuals':{'unit_only':1},
            'launch':{'projectile_creation_parameters':['unit-only']},'expected_creation_parameters':['unit-only'],
            'expected_launch_contract':{name:{'present':False} for name in ('projectile_center','projectile_creation_distance','apply_projection_to_projectile_creation_position')},
            'expected_icons':{'item':icon,'technology':tech},'combat_doctrine':'on',
            'expected_combat_mechanics':snapshot,'expected_combat_baseline_sha256':analyzer.canonical(snapshot)}
        return config,audit,{analyzer.HD:'1.0.0'}

    def test_recipe_inherits_without_observer_icon(self):
        args=self.native_audit();self.assertEqual(analyzer.main_audit_errors(*args),[])
        args[1]['icons']['recipe']['icon']=args[1]['icons']['item']['icon']
        self.assertTrue(any('inherits' in s for s in analyzer.main_audit_errors(*args)))

    def test_final_helper_cannot_reapply_shipping_graphics(self):
        args=self.native_audit();args[1]['consumer_untouched']=False
        self.assertTrue(any('untouched' in s for s in analyzer.main_audit_errors(*args)))

    def test_final_shipping_visual_difference_rejected(self):
        args=self.native_audit();args[1]['actual_visuals']={'unit_only':2}
        self.assertTrue(any('visuals/state timing' in s for s in analyzer.main_audit_errors(*args)))

    def test_final_shipping_launch_absence_is_exact(self):
        args=self.native_audit();args[1]['launch']['projectile_center']=[0,0]
        self.assertTrue(any('launch field' in s for s in analyzer.main_audit_errors(*args)))

    def test_final_shipping_exact_icon_size_required(self):
        args=self.native_audit();args[1]['icons']['technology']['icon_size']=128
        self.assertTrue(any('icon differs' in s for s in analyzer.main_audit_errors(*args)))

    def test_unchanged_but_wrong_cooldown_rejected(self):
        config,audit,active=self.native_audit()
        for name in ('before','after'):audit[name]['attack']['cooldown']=19
        self.assertTrue(any('combat mechanics differ' in s for s in analyzer.main_audit_errors(config,audit,active)))

    def test_unchanged_but_wrong_range_rejected(self):
        config,audit,active=self.native_audit()
        for name in ('before','after'):audit[name]['attack']['range']=31
        self.assertTrue(any('combat mechanics differ' in s for s in analyzer.main_audit_errors(config,audit,active)))

    def test_wrong_doctrine_baseline_rejected(self):
        args=self.native_audit();args[1]['combat_doctrine']='off'
        self.assertTrue(any('another doctrine' in s for s in analyzer.main_audit_errors(*args)))

    def test_changed_baseline_hash_rejected(self):
        args=self.native_audit();args[1]['expected_combat_mechanics']['attack']['range']=31
        self.assertTrue(any('altered' in s for s in analyzer.main_audit_errors(*args)))

    def test_connector_remains_user_owned(self):
        args=self.native_audit()
        for name in ('before','after'):args[1][name]['circuit_connector']={'user_owned':'new-placement'}
        self.assertEqual(analyzer.main_audit_errors(*args),[])

    def standalone_audit(self):
        _,audit,_=self.native_audit()
        config={'scenario':'standalone-example','finalized':True}
        audit.update(example_absent_before_private_require=True,example_loaded_only_by_private_helper=True,shadow_leaf_count=0)
        audit['icons']['recipe']=dict(audit['icons']['item'])
        return config,audit,{'base':'2.0.77',analyzer.HD:'1.0.0',analyzer.HELPER:'0.1.0'}

    def test_standalone_exact_contract_passes(self):
        self.assertEqual(analyzer.standalone_audit_errors(*self.standalone_audit()),[])

    def test_standalone_wrong_map_rejected(self):
        args=self.standalone_audit();args[1]['launch']['projectile_creation_parameters']=['wrong-origin']
        self.assertTrue(any('launch map' in s for s in analyzer.standalone_audit_errors(*args)))

    def test_standalone_wrong_native_origin_rejected(self):
        args=self.standalone_audit();args[1]['launch']['projectile_center']=[0,1]
        self.assertTrue(any('launch field' in s for s in analyzer.standalone_audit_errors(*args)))

    def test_standalone_wrong_icon_rejected(self):
        args=self.standalone_audit();args[1]['icons']['recipe']['icon']='__base__/graphics/icons/gun-turret.png'
        self.assertTrue(any('icon differs' in s for s in analyzer.standalone_audit_errors(*args)))

    def test_standalone_wrong_hd_profile_rejected(self):
        args=self.standalone_audit();args[1]['sprite_paths']=['__'+analyzer.SD+'__/graphics/body.png']
        self.assertTrue(any('non-HD' in s for s in analyzer.standalone_audit_errors(*args)))

    def test_standalone_wrong_state_rejected(self):
        args=self.standalone_audit();args[1]['actual_visuals']={'unit_only':2}
        self.assertTrue(any('visuals/state timing' in s for s in analyzer.standalone_audit_errors(*args)))

    def aggregate_inputs(self):
        inputs=[]
        for scenario in ('absent','disabled','enabled','incompatible'):
            for mode in (False,True):
                directory=self.root/(scenario+'-'+str(mode));directory.mkdir()
                capture=directory/'unit-placeholder.txt';capture.write_text('UNIT TEST: no native pixels or approval')
                reference=analyzer.ref(capture)
                profile='hd' if scenario=='enabled' else 'sd'
                ids=[] if scenario=='incompatible' else [profile+'/'+kind for kind in analyzer.VISUAL]+['mechanics/unchanged','hd_selection/'+('enabled' if scenario=='enabled' else 'disabled')]
                record={'schema':'esir.minigun.consumer-observations.v1','engine_version':'2.0.77','lineage':{'unit_only':True},
                    'config':{'scenario':scenario,'ballistic':mode},'automated_checks_passed':True,'failures':[],
                    'source_native_reports':{'unit-only':reference},'cases':[{'id':name,'automated_checks_passed':True,
                        'failures':[],'observations':{'unit_only':True},'captures':[reference]} for name in ids]}
                write(directory/'raw-observations.json',record)
                summary={'schema':'esir.minigun.consumer-summary.v1','scenario':scenario,'ballistic':mode,
                    'lineage':record['lineage'],'automated_checks_passed':True,'failures':[],
                    'raw_observations':analyzer.ref(directory/'raw-observations.json')}
                write(directory/'summary.json',summary);inputs.append(directory)
        return inputs

    def test_aggregate_never_approves_visuals(self):
        inputs=self.aggregate_inputs();out=self.root/'aggregate'
        result=analyzer.aggregate(inputs,out);review=analyzer.read(out/'visual-review-template.json')
        self.assertEqual(result['case_count'],13)
        self.assertFalse(result['native_visual_review_passed']);self.assertFalse(review['passed'])
        self.assertTrue(review['pending_review']);self.assertTrue(all(row['passed'] is False for row in review['cases']))

    def test_aggregate_rejects_missing_doctrine(self):
        inputs=self.aggregate_inputs()
        with self.assertRaisesRegex(ValueError,'both doctrines'):analyzer.aggregate(inputs[:-1],self.root/'aggregate')

    def test_aggregate_rejects_stale_capture(self):
        inputs=self.aggregate_inputs();(inputs[0]/'unit-placeholder.txt').write_text('mutated')
        with self.assertRaisesRegex(ValueError,'Changed native image'):analyzer.aggregate(inputs,self.root/'aggregate')

    def test_aggregate_rejects_switch_summary(self):
        inputs=self.aggregate_inputs();path=inputs[0]/'summary.json';value=analyzer.read(path);value['scenario']='enabled';write(path,value)
        with self.assertRaisesRegex(ValueError,'scenario, doctrine'):analyzer.aggregate(inputs,self.root/'aggregate')


if __name__=='__main__':unittest.main(verbosity=2)
