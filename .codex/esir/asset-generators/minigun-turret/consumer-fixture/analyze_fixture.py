"""Native consumer evidence; produces review templates, never visual approval."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
from PIL import Image

SD='exotic-space-industries-remembrance-graphics-6';HD='minigun-turret-HD';HELPER='zzz-esir-minigun-consumer'
VISUAL=['native_load','state_transitions','combined_shadow','item_recipe_icon','technology_icon']
EXPECTED={f'{profile}/{case}' for profile in ('sd','hd') for case in VISUAL}|{'hd_selection/enabled','hd_selection/disabled','mechanics/unchanged'}


def fs(path):
    text=os.path.abspath(path)
    return Path('\\\\?\\'+text if os.name=='nt' and not text.startswith('\\\\?\\') else text)


def sha(path):
    h=hashlib.sha256()
    with fs(path).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()


def read(path):return json.loads(fs(path).read_text(encoding='utf-8-sig'))


def canonical(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()


def ref(path):return {'path':str(Path(os.path.abspath(path))),'sha256':sha(path)}


def retain(source,target):
    source,target=fs(source),fs(target);target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists():
        if sha(source)!=sha(target):raise ValueError('Refusing changed retained bytes')
    else:os.link(source,target)
    if sha(source)!=sha(target):raise ValueError('Retained hash mismatch')


def pack_path(root,name):
    p=PurePosixPath(name)
    if not p.parts or p.is_absolute() or '..' in p.parts or '\\' in name or p.parts[0] not in (SD,HD):raise ValueError('Unsafe asset pack identity')
    path=fs(root).joinpath(*p.parts);cursor=path;boundary=fs(root)
    while cursor!=boundary:
        if cursor.is_symlink() or getattr(cursor.stat(),'st_file_attributes',0)&1024:raise ValueError('Reparse asset pack path')
        cursor=cursor.parent
    return path


def verify_plan(helper):
    plan=read(helper/'fixture-plan.json')
    if plan.get('schema')!='esir.minigun.consumer-plan.v1' or not plan.get('pack_inputs'):raise ValueError('Missing consumer plan/pack byte inventory')
    for name,digest in plan['pack_inputs'].items():
        if sha(pack_path(helper.parent,name))!=digest:raise ValueError('Staged pack input changed: '+name)
    if sha(helper/'consumer-graphics-data.lua')!=plan['consumer_data_sha256']:raise ValueError('Staged consumer metadata changed')
    config=plan['config'];mods=read(helper.parent/'mod-list.json')['mods'];enabled={row['name'] for row in mods if row['enabled']}
    if config['standalone']:
        if enabled!={'base',HD,HELPER}:raise ValueError('Standalone must enable only base, HD and private observer')
    else:
        if SD not in enabled or 'exotic-space-industries-remembrance' not in enabled:raise ValueError('Actual main/G6 must be enabled')
        if (HD in enabled)!=(config['scenario'] in ('enabled','incompatible')):raise ValueError('HD selection differs from scenario')
        if config['scenario']=='absent' and ((helper.parent/HD).exists() or any(row['name']==HD for row in mods)):
            raise ValueError('Absent test must actually omit the HD directory and mod-list entry')
    return plan


def case_rows(config,captures,native):
    profile=config['profile'];labels={row['label']:row for row in captures}
    if config['standalone']:
        return [{'id':config['scenario'],'captures':[labels['parked-eight-directions']['reference'],labels['native-inventory-crafting']['reference'],labels['native-research-window']['reference']],
            'observations':{'audit':native['audit'],'active_mods':native['active_mods']}}]
    selected={'native_load':['parked-eight-directions'],'combined_shadow':['combined-shadow-eight-directions'],
        'item_recipe_icon':['native-inventory-crafting','native-entity-window'],'technology_icon':['native-research-window']}
    rows=[]
    for kind in VISUAL:
        names=selected.get(kind,[row['label'] for row in captures if row['label'].startswith(('prepare-','fold-'))]+['running-eight-directions'])
        rows.append({'id':profile+'/'+kind,'captures':[labels[name]['reference'] for name in names],
            'observations':{'config':config,'native_audit':native['audit'],'native_observations':native['observations'],
                'capture_selection':'Native scheduled clip; actual visible state and readability require explicit review'}})
    rows.append({'id':'hd_selection/'+('enabled' if config['scenario']=='enabled' else 'disabled'),
        'captures':[labels['parked-eight-directions']['reference']],
        'observations':{'scenario':config['scenario'],'active_mods':native['active_mods'],'icons':native['audit']['icons']}})
    rows.append({'id':'mechanics/unchanged','captures':[labels['running-eight-directions']['reference']],
        'observations':{'before':native['audit']['before'],'after':native['audit']['after'],'ballistic':config['ballistic']}})
    return rows


def finalized_art_errors(audit,include_recipe=False):
    """Compare the untouched consumer with the independently constructed contract."""
    errors=[]
    if audit.get('consumer_untouched') is not True:errors.append('Final integration must audit untouched consumers')
    if not audit.get('actual_visuals') or audit['actual_visuals']!=audit.get('expected_visuals'):errors.append('Actual native visuals/state timing differ from finalized factory contract')
    launch=audit.get('launch',{})
    if not audit.get('expected_creation_parameters') or launch.get('projectile_creation_parameters')!=audit['expected_creation_parameters']:errors.append('Actual launch map differs from finalized contract')
    contract=audit.get('expected_launch_contract',{})
    required={'projectile_center','projectile_creation_distance','apply_projection_to_projectile_creation_position'}
    if set(contract)!=required:errors.append('Expected finalized launch contract missing or incomplete')
    for name,field in contract.items():
        if (type(field.get('present')) is not bool or (name in launch)!=field['present']
            or (field['present'] and ('value' not in field or launch.get(name)!=field['value']))):
            errors.append('Actual launch field differs: '+name)
    kinds=('item','ammo-turret','technology','recipe') if include_recipe else ('item','ammo-turret','technology')
    for kind in kinds:
        expected=audit.get('expected_icons',{}).get('technology' if kind=='technology' else 'item',{})
        actual=audit.get('icons',{}).get(kind,{})
        if (not expected.get('icon') or actual.get('icon')!=expected['icon']
            or actual.get('icon_size')!=expected.get('icon_size') or actual.get('icons')):
            errors.append('Actual icon differs from finalized contract: '+kind)
    return errors


def standalone_audit_errors(config,audit,active):
    errors=[]
    if set(active)!={'base',HD,HELPER} or audit.get('example_absent_before_private_require') is not True:errors.append('Standalone dependency/asset-only boundary failed')
    if config['scenario']=='standalone-example':
        if audit.get('example_loaded_only_by_private_helper') is not True or config.get('finalized') is not True:errors.append('Actual unloaded example was not exercised with finalized metadata')
        if audit.get('shadow_leaf_count')!=0:errors.append('Actual example include_shadows=false retained a shadow layer')
        if not audit.get('sprite_paths') or any(not path.startswith('__'+HD+'__/') for path in audit['sprite_paths']):errors.append('Actual example uses a donor or non-HD state/base sprite')
        errors.extend(finalized_art_errors(audit,include_recipe=True))
    return errors


def main_audit_errors(config,audit,active):
    errors=[]
    if bool(active.get(HD))!=(config['profile']=='hd') or audit['before']!=audit['after']:errors.append('Profile selection or preserved mechanics differs')
    prefix='__'+(HD if config['profile']=='hd' else SD)+'__/'
    if not audit.get('sprite_paths') or any(not path.startswith(prefix) for path in audit['sprite_paths']):errors.append('Actual native state/base sprites use another profile or donor family')
    if audit.get('shadow_leaf_count',0)<1:errors.append('Actual native combined-shadow family is missing')
    for kind,icon in audit['icons'].items():
        if kind=='recipe':
            if icon.get('icon') or icon.get('icons') or icon.get('main_product')!=config['entity_name']:errors.append('Actual recipe no longer inherits its selected main-product icon')
        elif not icon.get('icon','').startswith(prefix) or icon.get('icons'):errors.append('Native '+kind+' uses another icon family')
    if config.get('finalized'):
        if audit.get('consumer_untouched') is not True or audit.get('factory_options') not in ({},[]):errors.append('Final integration must audit untouched shipping consumers without fixture privileges')
        errors.extend(finalized_art_errors(audit))
        expected=audit.get('expected_combat_mechanics')
        actual={key:value for key,value in audit['before'].items() if key!='circuit_connector'}
        if (type(config.get('ballistic')) is not bool or audit.get('combat_doctrine')!=('on' if config.get('ballistic') else 'off')
            or not isinstance(expected,dict) or not expected or canonical(expected)!=audit.get('expected_combat_baseline_sha256')):
            errors.append('Approved pre-final combat baseline missing, altered or for another doctrine')
        elif actual!=expected:errors.append('Actual combat mechanics differ from approved pre-final doctrine baseline')
    return errors


def analyze(run,output):
    run=Path(os.path.abspath(run));output=Path(os.path.abspath(output));helper=run/'mods'/HELPER
    if output.exists():raise ValueError('Use a new output; historical evidence is immutable')
    plan=verify_plan(helper);config=plan['config'];execution=read(run/'consumer-execution.json')
    stage=read(run/'consumer-stage.json')
    for name,digest in stage['helper_hashes'].items():
        if Path(name).name!=name or sha(helper/name).lower()!=digest.lower():raise ValueError('Staged helper/config changed after Run: '+name)
    output.mkdir(parents=True);errors=[];references={}
    for name in ('consumer-stage.json','consumer-execution.json','create.log','create-error.log','graphics.log','graphics-error.log'):
        if (run/name).is_file():retain(run/name,output/name);references[name]=ref(output/name)
    for path in helper.iterdir():
        if path.is_file():retain(path,output/'helper'/path.name);references['helper/'+path.name]=ref(output/'helper'/path.name)
    for name in plan['pack_inputs']:
        retain(pack_path(run/'mods',name),output/'packs'/name);references['packs/'+name]=ref(output/'packs'/name)
    if execution['engine_version']!='2.0.77':errors.append('Wrong engine version')
    if config['expected_failure']:
        logs='\n'.join(fs(run/name).read_text(encoding='utf-8-sig',errors='replace') for name in ('create.log','create-error.log'))
        if execution['create_exit_code']==0 or config['expected_error'] not in logs or execution['graphics_exit_code'] is not None:
            errors.append('Incompatible HD did not fail only at the explicit factory major-version guard')
        rows=[];native=None
    else:
        if execution['create_exit_code']!=0 or execution['graphics_exit_code']!=0:errors.append('Native create/graphics execution failed')
        native_path=run/'script-output/minigun-consumer-report.json'
        if not native_path.is_file():errors.append('Native report missing');native=None;rows=[]
        else:
            native=read(native_path);retain(native_path,output/'native-report.json');references['native-report.json']=ref(output/'native-report.json')
            if native.get('done') is not True or native.get('engine_version')!='2.0.77' or native.get('config')!=config or native.get('lineage')!=config['lineage']:
                errors.append('Native report/configuration lineage mismatch')
            audit=native['audit'];active=native['active_mods']
            if config['standalone']:
                errors.extend(standalone_audit_errors(config,audit,active))
            else:
                errors.extend(main_audit_errors(config,audit,active))
            captures=[]
            for capture in native['captures']:
                name=capture['path'];p=PurePosixPath(name)
                if not name.startswith('minigun-consumer/') or p.is_absolute() or '..' in p.parts or '\\' in name:raise ValueError('Unsafe native screenshot path')
                source=run/'script-output'/Path(name);target=output/Path(name)
                retain(source,target)
                with Image.open(fs(target)) as image:
                    if image.size!=(1280,960):errors.append('Unexpected native capture geometry')
                bound=ref(target);references[name]=bound;captures.append({**capture,'reference':bound})
            labels=[row['label'] for row in captures]
            required={'parked-eight-directions','running-eight-directions','combined-shadow-eight-directions','native-inventory-crafting','native-entity-window','native-research-window'}|{'prepare-'+str(i) for i in range(39,101)}|{'fold-'+str(i) for i in range(159,361)}
            if len(labels)!=len(set(labels)) or set(labels)!=required:errors.append('Native UI/state capture inventory incomplete or duplicated')
            for capture in captures:
                if capture['label']=='native-inventory-crafting' and capture.get('inventory_window_open') is not True:errors.append('Actual native inventory/crafting window did not open')
                if capture['label']=='native-entity-window' and capture.get('opened_entity')!=config['entity_name']:errors.append('Actual native consumer entity window did not open')
            rows=case_rows(config,captures,native) if set(labels)==required else []
    for row in rows:row.update(automated_checks_passed=not errors,failures=list(errors))
    report={'schema':'esir.minigun.consumer-observations.v1','engine_version':'2.0.77','lineage':config['lineage'],
        'config':config,'automated_checks_passed':not errors,'failures':errors,'cases':rows,
        'source_native_reports':references,'production_approved':False}
    fs(output/'raw-observations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    summary={'schema':'esir.minigun.consumer-summary.v1','scenario':config['scenario'],'ballistic':config['ballistic'],
        'lineage':config['lineage'],'automated_checks_passed':not errors,'failures':errors,
        'raw_observations':ref(output/'raw-observations.json'),'native_visual_review_passed':False,'production_approved':False,
        'status':'failed' if errors else 'expected_native_rejection_passed' if config['expected_failure'] else 'pending_visual_review'}
    fs(output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    return summary


def aggregate(directories,output):
    if output.exists():raise ValueError('Use a fresh aggregate output')
    configs={};lineage=None;sources={}
    for directory in directories:
        summary=read(directory/'summary.json');record=read(directory/'raw-observations.json');key=(summary['scenario'],summary['ballistic'])
        if (summary.get('schema')!='esir.minigun.consumer-summary.v1' or record.get('schema')!='esir.minigun.consumer-observations.v1'
            or record.get('engine_version')!='2.0.77' or key!=(record['config']['scenario'],record['config']['ballistic'])):
            raise ValueError('Summary/native scenario, doctrine or schema differs')
        if key in configs:raise ValueError('Duplicate consumer scenario/doctrine')
        if summary['automated_checks_passed'] is not True or record['automated_checks_passed'] is not True or summary['failures'] or record['failures']:raise ValueError('Unpassed native consumer evidence')
        if sha(directory/'raw-observations.json')!=summary['raw_observations']['sha256']:raise ValueError('Changed native observations')
        if lineage is None:lineage=record['lineage']
        if lineage!=record['lineage'] or summary['lineage']!=lineage:raise ValueError('Different frozen candidate lineages')
        for name,reference in record['source_native_reports'].items():
            if sha(Path(reference['path']))!=reference['sha256']:raise ValueError('Changed native image, input, asset or log: '+name)
            sources[key[0]+'-'+str(key[1])+'/'+name]=reference
        sources[key[0]+'-'+str(key[1])+'/raw-observations']=ref(directory/'raw-observations.json')
        configs[key]=record
    required={(scenario,mode) for scenario in ('absent','disabled','enabled','incompatible') for mode in (False,True)}
    if set(configs)!=required:raise ValueError('Exactly HD absent/disabled/enabled/incompatible by both doctrines is required')
    rows=[]
    for name in sorted(EXPECTED):
        matches=[row for record in configs.values() for row in record['cases'] if row['id']==name]
        if not matches:raise ValueError('Missing visual case '+name)
        captures={capture['path']:capture for row in matches for capture in row['captures']}
        rows.append({'id':name,'automated_checks_passed':True,'failures':[],
            'observations':[row['observations'] for row in matches],'captures':list(captures.values())})
    raw={'schema':'esir.minigun.consumer-aggregate.v1','engine_version':'2.0.77','lineage':lineage,
        'automated_checks_passed':True,'failures':[],'cases':rows,'source_native_reports':sources}
    output.mkdir(parents=True);(output/'raw-visual-observations.json').write_text(json.dumps(raw,indent=2)+'\n')
    template={'schema':'esir.minigun.visual-acceptance.v1','lineage':lineage,'passed':False,'failures':[],
        'pending_review':['Inspect actual native UI and complete preparation/folding clips; fill explicit notes and approval'],'reviewer':'',
        'raw_reports':{'consumer':ref(output/'raw-visual-observations.json')},
        'cases':[{'id':row['id'],'raw_report':'consumer','passed':False,'notes':'','captures':row['captures']} for row in rows]}
    (output/'visual-review-template.json').write_text(json.dumps(template,indent=2)+'\n')
    return {'automated_checks_passed':True,'native_visual_review_passed':False,'case_count':13,'output':str(output)}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-plan',type=Path);p.add_argument('--run',type=Path);p.add_argument('--output',type=Path);p.add_argument('--aggregate',type=Path,nargs=8)
    a=p.parse_args()
    if a.verify_plan:verify_plan(a.verify_plan);print('Staged pack paths/bytes/profile selection verified');raise SystemExit(0)
    if not a.output:p.error('--output required')
    result=aggregate(a.aggregate,a.output) if a.aggregate else analyze(a.run,a.output)
    print(json.dumps(result,indent=2))
    raise SystemExit(2 if result.get('failures') else 0 if result.get('status')=='expected_native_rejection_passed' else 3)
