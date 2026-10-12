"""Stage real G6/HD consumer paths from a frozen full atlas; never run Factorio."""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil

SD = 'exotic-space-industries-remembrance-graphics-6'
HD = 'minigun-turret-HD'
HELPER = 'zzz-esir-minigun-consumer'
SCENARIOS = ('absent', 'disabled', 'enabled', 'incompatible', 'standalone-unloaded', 'standalone-example')


def fs(path):
    value=os.path.abspath(path)
    if os.name=='nt' and not value.startswith('\\\\?\\'):
        value='\\\\?\\UNC\\'+value[2:] if value.startswith('\\\\') else '\\\\?\\'+value
    return Path(value)


def sha(path):
    digest = hashlib.sha256()
    with fs(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''): digest.update(chunk)
    return digest.hexdigest()


def read(path): return json.loads(fs(path).read_text(encoding='utf-8-sig'))


def load(path):
    spec = importlib.util.spec_from_file_location('consumer_emitter', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def safe_source(repo, path):
    path = Path(os.path.abspath(path))
    if not path.is_relative_to(repo): raise ValueError('Source outside repository: '+str(path))
    cursor = path
    while cursor != repo:
        if cursor.is_symlink() or getattr(cursor.stat(), 'st_file_attributes', 0) & 1024:
            raise ValueError('Reparse source is not accepted: '+str(cursor))
        cursor = cursor.parent
    return path


def inventory(mapping):
    result = {}
    for row in mapping['artifacts']:
        key = row['fixture_path']; path = PurePosixPath(row['path'])
        if (row['profile'] not in ('sd','hd') or row['pack'] != {'sd':SD,'hd':HD}[row['profile']]
            or path.is_absolute() or '..' in path.parts or '\\' in row['path']
            or not str(path).startswith('graphics/') or path.suffix != '.png'
            or key != row['profile']+'/'+row['path'] or key in result):
            raise ValueError('Invalid, mixed-pack or duplicate frozen artifact')
        result[key] = {field:row[field] for field in ('sha256','bytes','size')}
    if not result: raise ValueError('No frozen PNG artifacts')
    return result


def build(args):
    repo = args.repo.resolve(); output = args.output.resolve(); mods = output.parent
    if output.name != HELPER or not mods.is_relative_to(repo/'.factorio-qc/managed'):
        raise ValueError('Consumer helper must be a fresh managed QC payload')
    if (output/'fixture-plan.json').exists(): raise ValueError('Refusing an existing consumer stage')
    mapping = read(args.artifact_map); frozen = mapping['frozen_profile_contract']
    if (mapping.get('complete_direction_family') is not True or frozen['provenance']['direction_indices'] != list(range(256))
        or frozen['provenance']['source_sha256'] != '453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59'):
        raise ValueError('Consumer acceptance requires the exact full256 source family')
    emitter = load(repo/'.codex/esir/asset-generators/minigun-turret/emit_graphics_data.py')
    source_data = args.artifact_map.parent/mapping['graphics_data_filename']
    if sha(source_data) != mapping['graphics_data_sha256']: raise ValueError('Original emitted Lua changed')
    files = inventory(mapping); manifest = read(args.assets_manifest)
    if (manifest.get('schema') != 'esir.minigun.candidate-assets.v1' or manifest['files'] != files):
        raise ValueError('Native atlas manifest differs from frozen PNG inventory')
    if manifest['candidate_data_sha256'] != sha(source_data):
        raise ValueError('Use the unchanged draft artifact map that the firing manifest binds')
    standalone = args.scenario.startswith('standalone-')
    if args.scenario == 'standalone-unloaded':
        raise ValueError('Retired asset-only scenario; use invoke-narrow-check.ps1 for the current standalone turret')
    if standalone and args.mode != 'off': raise ValueError('Standalone has no ESIR doctrine setting')
    lineage = {'source_sha256':frozen['provenance']['source_sha256'],
        'compiled_metadata_sha256':mapping['compiled_metadata_sha256'],
        'candidate_data_sha256':manifest['candidate_data_sha256'],
        'mechanical_data_sha256':sha(args.mechanical_data),'anchors_sha256':sha(args.anchors),
        'atlas_inventory_sha256':canonical(files)}
    art = copy.deepcopy(frozen)
    final_receipt = None
    if args.finalized:
        final_receipt = read(args.finalized/'finalization-receipt.json')
        if (final_receipt.get('schema') != 'esir.minigun.finalization-receipt.v1'
            or final_receipt.get('ready_for_staged_integration') is not True
            or final_receipt['lineage'] != lineage): raise ValueError('Finalized metadata has another native lineage or is not ready')
        for name,record in final_receipt['outputs'].items():
            if Path(name).name!=name or sha(args.finalized/name)!=record['sha256']:
                raise ValueError('Finalized output changed: '+name)
        final_art = read(args.finalized/'graphics-data.json')
        if final_art['provenance'].get('muzzle_native_calibrated') is not True or not final_art.get('native_launch_contract'):
            raise ValueError('Finalized metadata lacks its measured native launch contract')
        if final_art['profiles'] != frozen['profiles'] or final_art['projectile_creation_parameters'] != frozen['projectile_creation_parameters']:
            raise ValueError('Finalizer changed frozen atlas/launch map')
        baselines=final_receipt.get('consumer_combat_baselines',{})
        if (baselines.get('schema')!='esir.minigun.consumer-combat-baselines.v1'
            or set(baselines.get('doctrines',{}))!={'off','on'}
            or final_art['provenance'].get('finalization_evidence',{}).get('consumer_combat_baselines')!=baselines):
            raise ValueError('Finalizer receipt/art must bind both approved pre-final combat baselines')
        references=[baselines['source_visual_acceptance'],baselines['source_observations']]
        for value in baselines['doctrines'].values():
            if set(value.get('source_native_reports',{}))!={'absent','disabled','enabled'} or canonical(value['snapshot'])!=value['snapshot_sha256']:
                raise ValueError('Incomplete or altered pre-final combat baseline')
            references.extend(value['source_native_reports'].values())
        for reference in references:
            if sha(Path(reference['path']))!=reference['sha256']:
                raise ValueError('Approved pre-final combat baseline source changed')
        if not standalone:
            integrated=repo/'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua'
            if sha(safe_source(repo,integrated))!=final_receipt['outputs']['graphics-data.lua']['sha256']:
                raise ValueError('Actual main source does not contain the exact finalized graphics-data.lua')
        art = final_art
    if args.scenario == 'standalone-example' and not args.finalized:
        raise ValueError('The actual unloaded example requires calibrated final metadata; do not flip draft flags')
    selected_packs = [HD] if standalone else [SD] + ([] if args.scenario=='absent' else [HD])
    copied = {}
    for pack in selected_packs:
        source = repo/pack; target = mods/pack
        if target.exists(): raise ValueError('Asset-pack destination already exists; never overwrite a source junction')
        for loader in ('data.lua','data-updates.lua','data-final-fixes.lua','control.lua','settings.lua','settings-updates.lua','settings-final-fixes.lua'):
            if pack==HD and loader in ('data.lua','data-final-fixes.lua'): continue
            if (source/loader).exists(): raise ValueError('Graphics pack unexpectedly auto-loads code: '+pack+'/'+loader)
        for path in source.rglob('*'):
            if path.is_file() and not path.relative_to(source).as_posix().startswith('graphics/'):
                safe_source(repo,path); destination=target/path.relative_to(source)
                destination.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,destination)
        info=read(target/'info.json')
        if info['name'] != pack or info['dependencies'] != (['base >= 2.0.77','? space-age >= 2.0.77'] if pack==HD else ['base >= 2.0.0']):
            raise ValueError('Pack dependency contract differs')
        if args.scenario=='incompatible' and pack==HD:
            info['version']='2.0.0'; (target/'info.json').write_text(json.dumps(info,indent=2)+'\n')
    for row in mapping['artifacts']:
        source = safe_source(repo,Path(row['source']))
        if sha(source)!=row['sha256'] or source.stat().st_size!=row['bytes']: raise ValueError('Frozen source PNG changed')
        if row['pack'] in selected_packs:
            target=mods/row['pack']/row['path']; target.parent.mkdir(parents=True,exist_ok=True)
            os.link(source,target) # Immutable same-volume assets; no megabyte copy multiplication.
            copied[str(target.relative_to(mods)).replace('\\','/')]=row['sha256']
    if HD in selected_packs:
        example = (args.finalized/'hd-example-graphics-data.lua') if args.finalized else args.artifact_map.parent/'hd-example-graphics-data.lua'
        if not args.finalized:
            support=[row for row in mapping.get('support_artifacts',[]) if row.get('pack')==HD and row.get('path')=='lib/graphics-data.lua']
            if len(support)!=1 or sha(example)!=support[0]['sha256'] or example.stat().st_size!=support[0]['bytes']:
                raise ValueError('Draft unloaded example metadata is not the exact emitted support artifact')
        target=mods/HD/'lib/graphics-data.lua'; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(example,target)
    output.mkdir(parents=True,exist_ok=True)
    (output/'consumer-graphics-data.lua').write_text('return '+emitter.lua(art)+'\n',encoding='utf-8')
    for path,name in ((args.mechanical_data,'candidate-mechanical-data.lua'),(args.anchors,'muzzle-anchors.json'),
                      (args.assets_manifest,'candidate-assets-manifest.json'),(args.artifact_map,'artifact-map.json')):
        shutil.copy2(path,output/name)
    dependencies=['base >= 2.0.77', HD+' >= 1.0.0'] if standalone else ['base >= 2.0.77','space-age','exotic-space-industries-remembrance']
    (output/'info.json').write_text(json.dumps({'name':HELPER,'version':'0.1.0','title':'Disposable minigun consumer QC','author':'ESIR QC','factorio_version':'2.0','dependencies':dependencies},indent=2)+'\n')
    config={'schema':1,'scenario':args.scenario,'ballistic':args.mode=='on','profile':'hd' if args.scenario in ('enabled','incompatible') or standalone else 'sd',
        'lineage':lineage,'finalized':bool(args.finalized),'standalone':standalone,'expected_failure':args.scenario=='incompatible',
        'expected_error':'ESIR minigun graphics: graphics-hd 2.0.0 is incompatible; expected major 1',
        'entity_name':'example-minigun-turret' if args.scenario=='standalone-example' else 'gun-turret' if standalone else 'ei-gatling-turret',
        'technology_name':'mg-consumer-example' if args.scenario=='standalone-example' else 'military' if standalone else 'ei-gatling-turret',
        'benchmark_ticks':660,'directions':list(range(0,256,32))}
    (output/'test-config.lua').write_text('return '+emitter.lua(config)+'\n')
    pack_inputs={}
    for pack in selected_packs:
        for path in (mods/pack).rglob('*'):
            if path.is_file(): pack_inputs[str(path.relative_to(mods)).replace('\\','/')]=sha(path)
    plan={'schema':'esir.minigun.consumer-plan.v1','config':config,'source_data_sha256':sha(source_data),
        'consumer_data_sha256':sha(output/'consumer-graphics-data.lua'),'artifact_map_sha256':sha(args.artifact_map),
        'pack_inputs':pack_inputs,'copied_pngs':copied,'status':'staged_only_no_native_acceptance'}
    (output/'fixture-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    return plan


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('repo','output','artifact-map','mechanical-data','anchors','assets-manifest'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--finalized',type=Path);p.add_argument('--scenario',choices=SCENARIOS,required=True);p.add_argument('--mode',choices=('on','off'),default='on')
    print(json.dumps(build(p.parse_args())['config'],indent=2))
