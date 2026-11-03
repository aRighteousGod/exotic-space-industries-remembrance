"""Owned hidden Factorio process with fresh receipts and measured process overlap."""
import argparse, ctypes, hashlib, json, os, pathlib, re, shutil, subprocess, time, zipfile
from ctypes import wintypes as w

class Entry(ctypes.Structure):
    _fields_=[('size',w.DWORD),('usage',w.DWORD),('pid',w.DWORD),('heap',ctypes.c_size_t),('module',w.DWORD),('threads',w.DWORD),('parent',w.DWORD),('priority',w.LONG),('flags',w.DWORD),('exe',w.WCHAR*260)]
class Memory(ctypes.Structure):
    _fields_=[('cb',w.DWORD),('faults',w.DWORD)]+[(n,ctypes.c_size_t) for n in ['peak_working','working','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile','private']]
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.CreateToolhelp32Snapshot.restype=w.HANDLE
k.Process32FirstW.argtypes=[w.HANDLE,ctypes.POINTER(Entry)]
k.Process32NextW.argtypes=[w.HANDLE,ctypes.POINTER(Entry)]
k.CloseHandle.argtypes=[w.HANDLE]
ps=ctypes.WinDLL('psapi')
ps.GetProcessMemoryInfo.argtypes=[w.HANDLE,ctypes.POINTER(Memory),w.DWORD]
def engines():
    handle=k.CreateToolhelp32Snapshot(2,0);entry=Entry();entry.size=ctypes.sizeof(entry);found=[]
    try:
        ok=k.Process32FirstW(handle,ctypes.byref(entry))
        while ok:
            if entry.exe.lower()=='factorio.exe':found.append(entry.pid)
            ok=k.Process32NextW(handle,ctypes.byref(entry))
    finally:k.CloseHandle(handle)
    return found

def main():
    p=argparse.ArgumentParser();p.add_argument('--context',required=True);p.add_argument('--phase',required=True);p.add_argument('--save',required=True);p.add_argument('--label',required=True);p.add_argument('--ticks',type=int,default=110);p.add_argument('--runs',type=int,default=1);p.add_argument('--receipt',default='functional');a=p.parse_args()
    r=json.loads(pathlib.Path(a.context).read_text(encoding='utf-8-sig'));evidence=pathlib.Path(r['evidence']);visual=a.phase=='Visual'
    if visual:
        config=pathlib.Path(r['config']);content=config.read_text(encoding='utf-8-sig')
        for section,options in (('interface',(('ui-scale-mode','manual-pixels'),('custom-ui-scale','1'))),('graphics',(('full-screen','false'),))):
            heading='['+section+']'
            if heading not in content:content+='\n'+heading+'\n'
            for name,value in options:
                pattern=r'(?m)^\s*;?\s*'+re.escape(name)+r'\s*=.*$'
                if re.search(pattern,content):content=re.sub(pattern,name+'='+value,content)
                else:content=content.replace(heading,heading+'\n'+name+'='+value,1)
        config.write_text(content,encoding='utf8')
    # Native Windows asset reads can exceed MAX_PATH through managed junctions.
    # The short alias names the same verified view without moving any source.
    short=ctypes.create_unicode_buffer(32768)
    assert k.GetShortPathNameW(str(pathlib.Path(r['mods']).resolve()),short,len(short))
    args=[r['engine'],'--config',r['config'],'--mod-directory',short.value,'--disable-audio','--disable-migration-window']
    if visual:
        if r.get('actors') or r.get('administration'):args+=['--load-game',str(pathlib.Path(a.save).resolve())]
        else:args+=['--benchmark-graphics',str(pathlib.Path(a.save).resolve()),'--benchmark-ticks','240','--benchmark-runs','1']
        args+=['--window-size','1280x720','--graphics-quality','medium']
    else:
        args+=['--benchmark',a.save,'--benchmark-ticks',str(a.ticks),'--benchmark-runs',str(a.runs)]
        if not r['performance']:args+=['--benchmark-verbose','all']
    hashes={}
    for mod in pathlib.Path(r['mods']).iterdir():
        if mod.is_dir():
            for path in [mod/'info.json',*mod.rglob('*.lua')]:
                if path.is_file():hashes[str(path.relative_to(r['mods']))]=hashlib.sha256(path.read_bytes()).hexdigest()
    (evidence/(a.label+'-sources.json')).write_text(json.dumps(hashes,indent=2),encoding='utf8')
    env=os.environ.copy();env['SteamAppId']='427520';env['SteamGameId']='427520'
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    started=time.time();overlap=set();peak_working=0;peak_private=0;result=None
    marker=pathlib.Path(r['write_data'])/'script-output/factory-passage'/(a.receipt+'.json')
    with (evidence/(a.label+'-run.log')).open('w',encoding='utf8') as log:
        process=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT,env=env,startupinfo=startup)
        try:
            while process.poll() is None:
                if visual:
                    current=(evidence/(a.label+'-run.log')).read_text(encoding='utf8',errors='replace')
                    if any(marker in current for marker in ('Error AtlasBuilder.cpp:','non-recoverable error','Error while running event','Error when running interface function')):raise RuntimeError(current[-4000:])
                overlap.update(pid for pid in engines() if pid!=process.pid)
                m=Memory();m.cb=ctypes.sizeof(m)
                if ps.GetProcessMemoryInfo(w.HANDLE(int(process._handle)),ctypes.byref(m),m.cb):peak_working=max(peak_working,m.peak_working);peak_private=max(peak_private,m.private)
                if visual and marker.exists() and marker.stat().st_mtime>=started:
                    candidate=json.loads(marker.read_text(encoding='utf8'));assert candidate['passed']
                    ready=True
                    if r.get('administration'):
                        saves=list((pathlib.Path(r['write_data'])/'saves').glob('*factory-passage-administration*.zip'))
                        ready=False
                        for checkpoint in saves:
                            if checkpoint.stat().st_mtime<marker.stat().st_mtime:continue
                            try:
                                with zipfile.ZipFile(checkpoint) as archive:valid_zip=archive.testzip() is None
                            except (OSError,zipfile.BadZipFile):continue
                            if valid_zip and 'Saving finished' in current:
                                (evidence/(a.label+'-checkpoint.json')).write_text(json.dumps(dict(path=str(checkpoint),sha256=hashlib.sha256(checkpoint.read_bytes()).hexdigest())),encoding='utf8')
                                ready=True
                                break
                    if ready:result=candidate;time.sleep(2);break
                if time.time()-started>600:raise TimeoutError('Factorio fixture exceeded 600 seconds')
                time.sleep(.2)
            if not visual:assert process.returncode==0,process.returncode
            elif result is None:raise RuntimeError('Graphical process exited without a fresh accepted receipt')
        finally:
            if process.poll() is None:
                process.terminate()
                try:process.wait(timeout=15)
                except subprocess.TimeoutExpired:process.kill();process.wait(timeout=15)
    monitor=dict(elapsed_seconds=time.time()-started,peak_working_set_bytes=peak_working,peak_private_bytes=peak_private,
                 private_sample_interval_seconds=.2,save_sha256=hashlib.sha256(pathlib.Path(a.save).read_bytes()).hexdigest(),
                 other_factorio_pids=sorted(overlap),isolated=not overlap)
    (evidence/(a.label+'-monitor.json')).write_text(json.dumps(monitor,indent=2),encoding='utf8')
    if r['performance']>0:assert not overlap,'Concurrent Factorio invalidated performance timing'
    if visual:
        inventory=[]
        if r.get('administration'):
            assert sorted(f['scene'] for f in result.get('frames',[]))==['active-rebuild','map-settings','waiting-rebuild']
        for frame in result.get('frames',[]):
            path=pathlib.Path(r['write_data'])/'script-output'/frame['path']
            assert path.is_file() and path.stat().st_mtime>=started,str(path)
            retained=pathlib.Path(r['write_data'])/'captures'/a.label/path.name
            retained.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,retained)
            inventory.append(dict(absolute_path=str(retained),sha256=hashlib.sha256(retained.read_bytes()).hexdigest(),**frame))
        (evidence/(a.label+'-frames.json')).write_text(json.dumps(inventory,indent=2),encoding='utf8')
    print(json.dumps(monitor))
if __name__=='__main__':main()
