"""Stage exact shipping scene strings and directional mining connectors privately."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

SCENES = {
    'mining-drill': ['ei-burner-quarry', 'ei-electric-quarry', 'ei-steam-oil-pumpjack',
        'ei-steam-miner', 'ei-steam-quarry', 'ei-deep-drill', 'ei-advanced-electric-mining-drill',
        'ei-advanced-deep-drill', 'ei-deep-pumpjack', 'ei-superior-electric-mining-drill'],
    'reactor': ['ei-burner-heater', 'ei-fluid-heater'],
    'generator': ['ei-big-turbine'],
    'burner-generator': ['ei-combustion-turbine'],
    'furnace': ['ei-cooler', 'ei-plasma-heater'],
    'assembling-machine': ['ei-fusion-reactor', 'ei-neutron-collector', 'ei-neutron-activator', 'ei-auric-inoculation-vat'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    scripts = Path(__file__).parent
    fixture = Path('scripts/qc/entity-presentation')
    subprocess.run([sys.executable, '-B', str(scripts / 'stage_fixture.py'), '--run', str(root),
                    '--fixture', str(fixture)], check=True)
    helper = root / 'mods/zzz-esir-entity-presentation-qc'
    data_path = helper / 'data-final-fixes.lua'
    data = data_path.read_text(encoding='utf-8')
    extra = '\n'.join('scene_specs[#scene_specs+1]={' + json.dumps(kind) + ',' + json.dumps(name) + '}'
                      for kind, names in SCENES.items() for name in names)
    data = data.replace('local body_specs = {', extra + '\nlocal body_specs = {', 1)
    data += '\n' + (scripts / 'presentation-drills-data.lua').read_text(encoding='utf-8')
    data_path.write_text(data, encoding='utf-8')
    control_path = helper / 'control.lua'
    control = control_path.read_text(encoding='utf-8')
    control = control.replace('script.on_init(function()', 'script.on_init(function()\n    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end', 1)
    control = control.replace('report.validation = "passed"', 'report.validation = "passed"; report.passed=true')
    control += '\n' + (scripts / 'presentation-drills.lua').read_text(encoding='utf-8')
    control_path.write_text(control, encoding='utf-8')
    (helper / 'test-config.lua').write_text('return {ticks=1200,visual=true}\n', encoding='utf-8')
    # Never let the historical isolation tool write through a source junction.
    # Break only this stage's junction object, retaining the target unmodified.
    for entry in (root / 'mods').iterdir():
        if entry.is_dir() and (entry / 'control.lua').exists() and entry.is_junction():
            destination = root / 'private-controls' / entry.name
            destination.parent.mkdir(exist_ok=True)
            original = entry.resolve()
            shutil.copytree(original, destination, ignore=shutil.ignore_patterns('.git', '.qc', 'dist', 'tests', '__pycache__'))
            assert entry.parent == root / 'mods' and entry.resolve() == original
            os.rmdir(entry)
            shutil.copytree(destination, entry)
    subprocess.run([sys.executable, '-B', str(fixture / 'isolate-runtime.py'), str(root / 'mods')], check=True)
    (root / 'presentation-stage.json').write_text(json.dumps(dict(extra_scenes=SCENES,
        helper_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in helper.glob('*.lua')}),indent=2),encoding='utf-8')


if __name__ == '__main__':
    main()
