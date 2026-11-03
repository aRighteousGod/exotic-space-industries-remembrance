"""Read-only common gameplay/configuration identity across broad and native rows.

Media remains subject to each managed run's full storage validation. This common
guard prevents code, locale, profile or source-precedence changes between runs.
Private per-case helpers/settings are intentionally outside this baseline.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

EXCLUDED={'.git','.factorio-qc','.qc','__pycache__','dist','tests','node_modules'}
OVERRIDES={'nsbc_source':'zzz-nonstandard-beacons-continued',
           'enhanced_walls_source':'enhanced-walls-continued','doeworks_source':'doeworks-deer-continued'}


def digest(data):return hashlib.sha256(data).hexdigest()


def snapshot(repo,base_only=False):
    repo=Path(repo).resolve()
    profile_path=repo/'.codex/esir/factorio-development.json'
    profile=json.loads(profile_path.read_text(encoding='utf-8-sig'))
    roots=[];effective={};files={}
    def add_root(path,key,role,expected=None):
        path=path.resolve();info=json.loads((path/'info.json').read_text(encoding='utf-8-sig'))
        if expected and (info['name']!=expected or info['factorio_version']!='2.1'):
            raise ValueError('Source override identity mismatch: '+key)
        roots.append({'key':key,'name':info['name'],'path':str(path),'role':role})
        if info.get('factorio_version')=='2.1':effective[info['name']]=str(path)
        for directory,dirs,names in os.walk(path,followlinks=False):
            dirs[:]=sorted(d for d in dirs if d not in EXCLUDED)
            for name in [*dirs,*names]:
                item=Path(directory)/name
                if item.is_symlink() or (hasattr(item,'is_junction') and item.is_junction()):
                    raise ValueError('Unexpected source link: '+str(item))
            for name in sorted(names):
                item=Path(directory)/name
                if item.suffix.lower() in ('.lua','.json','.cfg'):
                    files[key+'/'+item.relative_to(path).as_posix()]=digest(item.read_bytes())
    if not base_only:
        for path in sorted(repo.iterdir()):
            if path.is_dir() and (path/'info.json').is_file():add_root(path,'local:'+path.name,'local')
        for field,name in OVERRIDES.items():
            if profile.get(field):add_root(repo/profile[field],'profile:'+field,'override',name)
    configuration={}
    seed=repo/profile['dependency_seed']
    for name in ('dependency-lock-2.1.json','mod-list.json','mod-settings.dat'):
        path=seed/name
        configuration[name]=digest(path.read_bytes()) if path.exists() else None
    result={'schema_version':1,'engine_version':profile['engine_version'],'base_only':base_only,
        'profile_sha256':digest(profile_path.read_bytes()),'roots':roots,
        'effective_runtime_roots':effective,'files':files,'baseline_configuration':configuration}
    result['sha256']=digest(json.dumps(result,sort_keys=True).encode('utf-8'))
    return result


def changes(before,after):
    keys=set(before['files'])|set(after['files'])
    paths=sorted(k for k in keys if before['files'].get(k)!=after['files'].get(k))
    for key in ('profile_sha256','roots','effective_runtime_roots','baseline_configuration'):
        if before[key]!=after[key]:paths.append(key)
    return paths


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[3])
    args=parser.parse_args();print(json.dumps(snapshot(args.repo)))
