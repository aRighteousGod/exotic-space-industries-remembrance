"""Two isolated native clients, shared observer state, and disconnect cleanup."""
import argparse, hashlib, json, os, pathlib, runpy, shutil, subprocess, time
support=runpy.run_path(str(pathlib.Path(__file__).with_name('observer-run.py')))
ROOT,ps=support['ROOT'],support['ps']

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--context',required=True,type=pathlib.Path);a=parser.parse_args()
    r=json.loads(a.context.read_text(encoding='utf8'));evidence=pathlib.Path(r['evidence']);write=pathlib.Path(r['write_data'])
    helper=pathlib.Path(r['mods'])/r['helper'];control=helper/'control.lua';original=control.read_bytes()
    result={'passed':False,'engine':'2.1.24','simultaneous_clients':2,'actions':'programmatic native GUI opens and recipe changes'}
    children=[];logs=[];started=time.time()
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    env=os.environ.copy();env['SteamAppId']='427520';env['SteamGameId']='427520'
    def spawn(args,name):
        logpath=evidence/(name+'.log');stream=logpath.open('w',encoding='utf8');logs.append((logpath,stream))
        p=subprocess.Popen([r['engine'],*args],stdout=stream,stderr=subprocess.STDOUT,env=env,startupinfo=startup);children.append(p);return p
    def wait(predicate,seconds=180):
        deadline=time.time()+seconds
        while time.time()<deadline:
            for p in children:
                if p.poll() is not None:raise RuntimeError('Owned native process exited unexpectedly')
            for path,_ in logs:
                text=path.read_text(encoding='utf8',errors='replace')
                if any(x in text for x in ('Error while running','non-recoverable error','desynchronization','Desync','MultiplayerManager failed:')):raise RuntimeError(text[-4000:])
            value=predicate()
            if value:return value
            time.sleep(.25)
        raise TimeoutError('Two-client observer fixture did not reach checkpoint')
    def reports(name,roots):
        paths=[p/'script-output/factory-passage'/f'{name}.json' for p in roots]
        if not all(p.exists() and p.stat().st_mtime>=started for p in paths):return False
        values=[json.loads(p.read_text()) for p in paths]
        assert values[0]['passed'] and all(x==values[0] for x in values),'Peer reports disagree'
        shutil.copy2(paths[0],evidence/f'{name}.json');return values[0]
    try:
        shutil.copy2(pathlib.Path(__file__).with_suffix('.lua'),helper/'observer-multiplayer.lua')
        control.write_text('require("observer-multiplayer")\n',encoding='utf8')
        ps(a.context,'Create','-Label','observer-multiplayer')
        source={str(p.relative_to(helper)):hashlib.sha256(p.read_bytes()).hexdigest() for p in helper.rglob('*.lua')}
        (evidence/'observer-multiplayer-sources.json').write_text(json.dumps(source,indent=2))
        settings=evidence/'observer-multiplayer-server.json'
        settings.write_text(json.dumps(dict(name='Private ESIR observer QC',description='Two local test clients',visibility=dict(public=False,lan=False),require_user_verification=False,auto_pause=False,autosave_interval=0)))
        common=['--mod-directory',r['mods'],'--disable-audio','--disable-migration-window']
        server=spawn(['--config',r['config'],*common,'--start-server',str(write/'observer-multiplayer.zip'),'--server-settings',str(settings),'--bind','127.0.0.1','--port','34439'],'observer-multiplayer-server')
        wait(lambda:'Hosting game at' in logs[0][0].read_text(errors='replace'))
        peers=[];roots=[]
        for i in (1,2):
            directory=write/f'observer-peer-{i}';directory.mkdir(exist_ok=True);roots.append(directory)
            (directory/'player-data.json').write_text(json.dumps({'service-username':f'ESIR.Observer.QC.{i}'}))
            config=directory/'config.ini';data=pathlib.Path(r['engine']).parents[2]/'data'
            config.write_text(f'[path]\nread-data={data.as_posix()}\nwrite-data={directory.as_posix()}\n[general]\ncheck-updates=false\nlocale=en\n[graphics]\nfull-screen=false\nmax-sprite-loading-threads=2\nvideo-memory-usage=low\ncache-sprite-atlas=false\nhalt-rendering-when-minimized=false\n')
            peers.append(spawn(['--config',str(config),*common,'--window-size','800x600','--mp-connect','127.0.0.1:34439'],f'observer-multiplayer-peer-{i}'))
        both=wait(lambda:reports('observer-multiplayer-both',[write,*roots]),300)
        peers[0].terminate();peers[0].wait(timeout=15);children.remove(peers[0])
        left=wait(lambda:reports('observer-multiplayer-left',[write,roots[1]]),120)
        result.update(passed=True,required_labels=['observer-multiplayer-both','observer-multiplayer-left'],matching_server_client_reports=True,
            both_connected=both['connected'],after_disconnect=left['connected'],checks=len(left['checks']))
    except Exception as error:
        result['error']=str(error)
        raise
    finally:
        for p in children:
            if p.poll() is None:p.terminate();p.wait(timeout=15)
        for _,stream in logs:stream.close()
        control.write_bytes(original);result['elapsed_seconds']=time.time()-started
        (evidence/'observer-multiplayer-acceptance.json').write_text(json.dumps(result,indent=2))
        print(json.dumps(result))
if __name__=='__main__':main()
