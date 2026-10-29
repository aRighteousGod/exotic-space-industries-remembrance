"""Stage two-client source-panel/replacement/rejoin acceptance against full ESIR."""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent; REPO=HERE.parents[2]; NSBC=REPO.parent/'nonstandard-beacons-continued'
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',required=True);a=p.parse_args()
root=Path(os.path.abspath(a.run));root.mkdir(parents=True,exist_ok=True)
fixture=root/'fixture';fixture.mkdir()
(fixture/'info.json').write_text(json.dumps({'name':'esir-qc-beacon-multiplayer','version':'1.0.0','factorio_version':'2.1',
 'title':'Full ESIR two-client beacon acceptance','author':'ESIR QC','dependencies':['exotic-space-industries-remembrance >= 1.4.0']}))
original=NSBC/'tests/multiplayer-control.lua';text=original.read_text(encoding='utf-8')
for before,after in [('nsbc-copper','ei-copper-beacon'),('nsbc-iron','ei-iron-beacon'),('nsbc-nitrogen','ei-liquid-nitrogen')]:text=text.replace(before,after)
text=text.replace('script.on_init(function()', 'script.on_init(function()\n  if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end')
text=text.replace('local player = game.connected_players[1]', '''local second = game.connected_players[2]
    second.selected = storage.beacon
    remote.call("nsbc-qc", "rotate", second.index, false, false)
    second.selected = nil
    storage.expected_direction = metadata().source.direction
    local player = game.connected_players[1]''')
text=text.replace('check(not storage.beacon.disabled_by_script, "both clients observe refuelled successor")', '''check(not storage.beacon.disabled_by_script, "both clients observe refuelled successor")
    check(metadata().source.direction == storage.expected_direction, "concurrent rotation and replacement preserve orientation")''')
(fixture/'control.lua').write_text(text,encoding='utf-8')
subprocess.run(['powershell','-ExecutionPolicy','Bypass','-File',str(HERE/'invoke-core.ps1'),'-Task','stage',
 '-RunRoot',str(root),'-FixtureRoot',str(fixture),'-DependencyRoot',str(REPO/'.factorio-qc/dependency-seeds/2.1-core')],check=True)
target=root/'mods/zzz-nonstandard-beacons-continued'
assert target.is_junction() and target.resolve()==NSBC.resolve()
os.rmdir(target)
shutil.copytree(NSBC,target,ignore=shutil.ignore_patterns('.git','.qc','dist','tests','__pycache__'))
with (target/'control.lua').open('a',encoding='utf-8') as stream:stream.write('\n'+(NSBC/'tests/hooks.lua').read_text(encoding='utf-8'))
(root/'stage.json').write_text(json.dumps({'source_fixture_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
 'two_real_clients':True,'physical_input':False,'private_rotation_adapter':True},indent=2))
