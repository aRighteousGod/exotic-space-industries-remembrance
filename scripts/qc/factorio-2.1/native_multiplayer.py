"""Run one loopback server and an actual graphical peer, disconnect, then rejoin.

Uses a fresh local username and no installed account profile or token. Neither
server visibility nor account verification is enabled. Only owned children stop.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import zipfile


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',required=True)
    parser.add_argument('--save',required=True)
    parser.add_argument('--port',type=int,default=34437)
    parser.add_argument('--tag',default='multiplayer')
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    engine=Path('.factorio-qc/f21/bin/x64/factorio.exe').absolute()
    client=root/'peer';client.mkdir(exist_ok=True)
    (client/'player-data.json').write_text(json.dumps({'service-username':'ESIR_Upgrade_QC'}),encoding='utf-8')
    config=root/'peer.ini'
    config.write_text(f'[path]\nread-data={(engine.parents[2]/"data").as_posix()}\nwrite-data={client.as_posix()}\n'
        '[general]\ncheck-updates=false\nlocale=en\n[graphics]\nfull-screen=false\n'
        'halt-rendering-when-minimized=false\nmax-sprite-loading-threads=2\nvideo-memory-usage=low\ncache-sprite-atlas=false\n'
        '[interface]\nui-scale-mode=manual-pixels\ncustom-ui-scale=1\n',encoding='utf-8')
    settings=root/'server-settings.json'
    settings.write_text(json.dumps({'name':'Private ESIR upgrade multiplayer QC','description':'Disposable loopback acceptance fixture',
        'visibility':{'public':False,'lan':False},
        'require_user_verification':False,'auto_pause':False,'autosave_interval':0}),encoding='utf-8')
    hashes={}
    for directory in (root/'mods').iterdir():
        if directory.is_dir() and (directory/'info.json').is_file():
            for path in [directory/'info.json',*directory.rglob('*.lua')]:
                hashes[str(path.relative_to(root/'mods'))]=hashlib.sha256(path.read_bytes()).hexdigest()
    manifest=root/(args.tag+'.source-manifest.json')
    manifest.write_text(json.dumps(hashes,indent=2),encoding='utf-8')
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    started=time.time();peer=None;server=None
    output=root/(args.tag+'.server.log')
    result={'passed':False,'server_bind':'127.0.0.1','actual_graphical_peer':True,'simultaneous_peers':1,'phases':[],
        'source_manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}
    def wait_for(predicate,deadline,paths):
        while time.time()<deadline:
            for process in (server,peer):
                if process and process.poll() is not None: raise RuntimeError('Owned Factorio process exited unexpectedly')
            for path in paths:
                text=path.read_text(encoding='utf-8',errors='replace') if path.exists() and path.stat().st_mtime>=started else ''
                if any(s in text for s in ('non-recoverable error','Error while running','Desync','desynchronization')):
                    raise RuntimeError(text[-4000:])
            value=predicate()
            if value:return value
            time.sleep(.25)
        raise TimeoutError('Multiplayer fixture did not reach its next checkpoint')
    try:
        with output.open('w',encoding='utf-8') as log:
            server=subprocess.Popen([str(engine),'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),
                '--disable-audio','--start-server',os.path.abspath(args.save),'--server-settings',str(settings),
                '--bind','127.0.0.1','--port',str(args.port)],stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            wait_for(lambda:'Hosting game at' in output.read_text(encoding='utf-8',errors='replace'),time.time()+120,[output])
            for phase in (1,2):
                peer_log=root/f'{args.tag}-peer-{phase}.log'
                phase_start=time.time()
                with peer_log.open('w',encoding='utf-8') as log_peer:
                    peer=subprocess.Popen([str(engine),'--config',str(config),'--mod-directory',str(root/'mods'),
                        '--disable-audio','--window-size','1600x1000','--mp-connect',f'127.0.0.1:{args.port}'],
                        stdout=log_peer,stderr=subprocess.STDOUT,startupinfo=startup)
                    marker=f'multiplayer-phase-{phase}.json'
                    server_marker=root/'script-output'/marker;peer_marker=client/'script-output'/marker
                    def reports_ready():
                        if not all(p.exists() and p.stat().st_mtime>=phase_start for p in (server_marker,peer_marker)):return False
                        a,b=[json.loads(p.read_text(encoding='utf-8')) for p in (server_marker,peer_marker)]
                        assert a['passed'] and b['passed'] and a==b,'Server/client state reports disagree'
                        return a
                    report=wait_for(reports_ready,time.time()+420,[output,peer_log,client/'factorio-current.log'])
                    result['phases'].append({'phase':phase,'checks':len(report['checks']),'tick':report['tick'],
                        'connected_ticks':report['connected_ticks'],'server_peer_reports_equal':True,
                        'report_sha256':hashlib.sha256(server_marker.read_bytes()).hexdigest()})
                    peer.terminate();peer.wait(timeout=15);peer=None
                if phase==1:
                    left=root/'script-output/multiplayer-left.json'
                    wait_for(lambda:left.exists() and left.stat().st_mtime>=phase_start,time.time()+90,[output])
            checkpoint=root/'saves/_autosave-multiplayer-accepted.zip'
            def saved():
                if not checkpoint.exists() or checkpoint.stat().st_mtime<started:return False
                try:
                    with zipfile.ZipFile(checkpoint) as archive:return archive.testzip() is None
                except (OSError,zipfile.BadZipFile):return False
            wait_for(saved,time.time()+30,[output])
            result.update(passed=True,checkpoint_sha256=hashlib.sha256(checkpoint.read_bytes()).hexdigest())
    except Exception as error:
        result['error']=str(error)
        raise
    finally:
        for process in (peer,server):
            if process and process.poll() is None:process.terminate();process.wait(timeout=15)
        result['elapsed_seconds']=round(time.time()-started,3)
        (root/(args.tag+'.receipt.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result))


if __name__=='__main__':main()
