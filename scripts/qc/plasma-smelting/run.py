"""Run isolated native furnace acceptance against preserved baseline and live source."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import zipfile

repo, run, alias = (Path(p).resolve() for p in sys.argv[1:4])
phase = sys.argv[4]
phase_started = time.time()
assert run.is_relative_to(repo / '.factorio-qc/managed')
mods = run / 'mods'
pack = mods / 'exotic-space-industries-remembrance'
helper = mods / 'zzz-plasma-smelting-qc'
engine = Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio')
exe = engine / 'bin/x64/factorio.exe'
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0

def long_path(path):
    return Path('\\\\?\\' + str(path.resolve())) if os.name == 'nt' else path

def copy_tree(source, target):
    shutil.copytree(long_path(source), long_path(target), dirs_exist_ok=True)

def write_json(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf-8')

if phase == 'Prepare':
    mods.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(repo / 'scripts/qc/auric-productivity/stage-assets.py'), str(repo), str(mods)], check=True)
    copy_tree(repo / 'exotic-space-industries-remembrance', pack)
    helper.mkdir(exist_ok=True)
    selection = json.loads((repo / '.factorio-qc/fmqc/mods-live/mod-list.json').read_text(encoding='utf-8-sig'))
    for mod in selection['mods']:
        if 'qc' in mod['name'] or 'benchmark' in mod['name'] or mod['name'] == 'extinguisher':
            mod['enabled'] = False
    selection['mods'] = [m for m in selection['mods'] if m['name'] != helper.name]
    selection['mods'].append({'name': helper.name, 'enabled': True})
    write_json(mods / 'mod-list.json', selection)
    (run / 'config.ini').write_text(f'[path]\nread-data={engine / "data"}\nwrite-data={run}\n[other]\ncheck-updates=false\n', encoding='utf-8')
    print('Prepared', run)
    sys.exit(0)

# Use the short junction string passed by PowerShell, not Path.resolve()'s target.
alias = Path(sys.argv[3])
source = run / 'baseline/exotic-space-industries-remembrance' if phase == 'Baseline' else repo / 'exotic-space-industries-remembrance'
copy_tree(source, pack)
for file in (repo / 'scripts/qc/plasma-smelting').glob('*.lua'):
    shutil.copyfile(file, helper / file.name)
write_json(helper / 'info.json', {'name': helper.name, 'version': {'Baseline': '0.0.1', 'Candidate': '0.0.2', 'Save': '0.0.2', 'Reload': '0.0.3'}[phase], 'title': 'Plasma smelting acceptance fixture', 'author': 'ESIR QC', 'factorio_version': '2.0', 'dependencies': ['exotic-space-industries-remembrance']})
(helper / 'test-config.lua').write_text('return {baseline=' + str(phase == 'Baseline').lower() + ', reload=' + str(phase == 'Reload').lower() + '}\n', encoding='utf-8')
base = [str(exe), '--config', str(run / 'config.ini'), '--mod-directory', str(alias), '--disable-audio', '--disable-migration-window']

def execute(tag, arguments, checkpoint=None):
    started = time.time()
    stdout = run / f'{tag}.stdout.txt'
    with stdout.open('w', encoding='utf-8') as out, (run / f'{tag}.stderr.txt').open('w', encoding='utf-8') as err:
        process = subprocess.Popen(base + arguments, stdout=out, stderr=err, creationflags=flags)
        print(tag, 'pid', process.pid, flush=True)
        try:
            while process.poll() is None:
                if time.time() - started > 300:
                    raise RuntimeError(f'{tag}: timeout')
                text = stdout.read_text(encoding='utf-8', errors='replace')
                if 'Error while running' in text or 'Error Util.cpp' in text:
                    raise RuntimeError(f'{tag}: engine error; see {stdout}')
                if checkpoint and checkpoint.exists() and checkpoint.stat().st_mtime >= started and 'Saving finished' in text:
                    with zipfile.ZipFile(checkpoint) as archive:
                        assert archive.testzip() is None
                    break
                time.sleep(0.3)
            else:
                if process.returncode != 0:
                    raise RuntimeError(f'{tag}: exit {process.returncode}; see {stdout}')
                if checkpoint:
                    raise RuntimeError(f'{tag}: exited without checkpoint')
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=15)
    shutil.copyfile(run / 'factorio-current.log', run / f'{tag}.factorio.log')

created = run / 'created.zip'
baseline = run / 'saves/plasma-baseline.zip'
checkpoint = run / 'saves/plasma-checkpoint.zip'
if phase in ('Baseline', 'Save'):
    (run / 'saves').mkdir(exist_ok=True)
    if phase == 'Baseline':
        execute('Create', ['--create', str(created)])
    server = json.loads((engine / 'data/server-settings.example.json').read_text(encoding='utf-8-sig'))
    server.update(name='Disposable plasma smelting fixture', visibility={'public': False, 'lan': False}, require_user_verification=False, auto_pause=False)
    write_json(run / 'server-settings.json', server)
    execute(phase, ['--start-server', str(created if phase == 'Baseline' else baseline), '--server-settings', str(run / 'server-settings.json'), '--bind', '127.0.0.1:34420'], baseline if phase == 'Baseline' else checkpoint)
else:
    execute(phase, ['--benchmark', str(checkpoint if phase == 'Reload' else baseline), '--benchmark-ticks', '180' if phase == 'Reload' else '16500', '--benchmark-runs', '1'])
report = run / 'script-output' / {'Baseline': 'plasma-baseline.json', 'Candidate': 'plasma-runtime.json', 'Save': 'plasma-runtime.json', 'Reload': 'plasma-reload.json'}[phase]
assert report.stat().st_mtime >= phase_started, f'Stale report: {report}'
result = json.loads(report.read_text(encoding='utf-8-sig'))
assert result['passed'], result
shutil.copyfile(report, run / f'{phase}-report.json')
print(phase, 'passed:', result.get('checks'), 'checks', flush=True)
