"""Replay the exact-engine eight-way fixture and retain fresh native receipts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import hashlib

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run',type=Path,required=True)
    p.add_argument('--engine',type=Path,required=True)
    p.add_argument('--seed',type=Path,required=True)
    p.add_argument('--suite',choices=('all','visual','player','legacy','layouts','profiles','accept'),default='all')
    p.add_argument('--baseline-root',type=Path)
    p.add_argument('--profiles',nargs='+',choices=('original','2x','4x','8x','16x'),default=('original','2x','4x','8x','16x'))
    p.add_argument('--graphics-quality',choices=('high','medium'),default='high')
    a=p.parse_args();root=a.run.resolve();root.mkdir(parents=True,exist_ok=True)
    suite_receipt=root/('suite-'+a.suite+'.json')
    suite_receipt.write_text(json.dumps(dict(passed=False,state='running',suite=a.suite,started=time.time()),indent=2))
    env=dict(os.environ,SteamAppId='427520',SteamGameId='427520')
    def call(script,*args):
        subprocess.run([sys.executable,'-B',str(script),*map(str,args)],check=True,env=env,cwd=REPO)
    def stage(directory,phase,profile='original',create=False,execute=False):
        args=['--run',directory,'--engine',a.engine,'--seed',a.seed,'--phase',phase,'--profile',profile]
        if create:args+=['--create-only']
        if execute:args+=['--execute']
        call(HERE/'stage.py',*args)
    def client(directory,phase,marker,save=None,checkpoint=None):
        args=['--run',directory,'--engine',a.engine,'--save',save or directory/'fixture.zip',
              '--marker',marker+'.json','--phase',phase,'--graphics-quality',a.graphics_quality,'--timeout','480']
        if checkpoint:args+=['--checkpoint',checkpoint]
        call(HERE.parent/'factorio-2.1/native_client.py',*args)
    def reload(directory,save,marker):
        started=time.time();log=directory/(marker+'.benchmark.log')
        with log.open('w',encoding='utf-8') as output:
            subprocess.run([str(a.engine),'--config',str(directory/'config.ini'),'--mod-directory',str(directory/'mods'),
                '--disable-audio','--benchmark',str(save),'--benchmark-ticks','60','--benchmark-runs','1'],
                stdout=output,stderr=subprocess.STDOUT,check=True,env=env)
        result=directory/'script-output'/(marker+'.json')
        assert result.stat().st_mtime>=started
        data=json.loads(result.read_text());assert data['passed']
        data.update(engine_version='2.1.23',rendered_client=False,save_sha256=hashlib.file_digest(save.open('rb'),'sha256').hexdigest())
        (directory/(marker+'.receipt.json')).write_text(json.dumps(data,indent=2))
    if a.suite=='accept':stage(root/'accept','accept',execute=True)
    if a.suite in ('all','layouts'):
        d=root/'layouts';stage(d,'layouts',create=True);client(d,'layouts','ports')
    if a.suite in ('all','visual'):
        d=root/'visual';stage(d,'visual',create=True)
        client(d,'visual','acid-eight-native',checkpoint='_autosave-acid-eight-native.zip')
        reload(d,d/'client/saves/_autosave-acid-eight-native.zip','acid-eight-reload')
        call(HERE/'review.py','--run',d,'--output',root/'review')
    if a.suite in ('all','player'):
        d=root/'player';stage(d,'player',create=True)
        client(d,'player','acid-eight-player',checkpoint='_autosave-acid-eight-player.zip')
        reload(d,d/'client/saves/_autosave-acid-eight-player.zip','acid-eight-player-reload')
    if a.suite in ('all','legacy'):
        d=root/'legacy';stage(d,'legacy-seed',create=True)
        call(HERE.parent/'factorio-2.1/save_checkpoint.py','--engine',a.engine,'--run',d,'--save',d/'fixture.zip',
            '--checkpoint','_autosave-acid-eight-legacy-seed.zip','--phase','legacy-seed','--receipt','acid-eight-legacy-seed.json','--pass-key','passed','--port','34473')
        stage(d,'legacy-load')
        reload(d,d/'saves/_autosave-acid-eight-legacy-seed.zip','acid-eight-legacy-load')
    if a.suite in ('all','profiles'):
        assert a.baseline_root,'Provide the retained pre-change snapshots for exact profile parity'
        for profile in a.profiles:
            d=root/('final-'+profile);stage(d,'baseline',profile,execute=True)
            old=a.baseline_root/('probe' if profile=='original' else 'baseline-'+profile)/'script-output/final-data.json'
            call(HERE/'check.py','--baseline',old,'--current',d/'script-output/final-data.json',
                 '--hashes',a.baseline_root/'baseline/machine-hashes.json','--output',root/('parity-'+profile+'.json'))
    suite_receipt.write_text(json.dumps(dict(passed=True,state='complete',suite=a.suite,profiles=a.profiles,engine=str(a.engine),version='2.1.23'),indent=2))


if __name__=='__main__':main()
