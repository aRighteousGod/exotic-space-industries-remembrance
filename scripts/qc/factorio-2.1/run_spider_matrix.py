"""Serial native vehicle checks with per-case immutable reports and source hashes.

Runs only existing isolated stages. Performance measures the established module
profiler after setup, not whole-map UPS, and makes no statistical speedup claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('functional', 'performance'), required=True)
    parser.add_argument('--run21', default='.factorio-qc/sv21')
    parser.add_argument('--run20', default='.factorio-qc/sm20')
    parser.add_argument('--player-save', default='.factorio-qc/fg21/client/saves/_autosave-fusion-client-reload.zip')
    parser.add_argument('--replay-performance', action='store_true', help='Reuse the first matrix saves and retain every profiler text')
    args = parser.parse_args()
    scripts = Path(__file__).parent
    cases = []
    if args.suite == 'functional':
        for native in (False, True):
            for mode in ('dispatch', 'canonical'):
                cases.append(dict(version='2.1', mode=mode, native=native))
        cases.append(dict(version='2.1', mode='full', native=True))
    else:
        for version in ('2.0', '2.1'):
            for native, vehicles in ((False, 100), (False, 500), (True, 500)):
                for combat in (False, True):
                    cases.append(dict(version=version, mode='performance', native=native,
                                      vehicles=vehicles, combat=combat))
    summary = []
    for case in cases:
        root = Path(args.run20 if case['version'] == '2.0' else args.run21)
        assert (root / 'mods').is_dir(), 'Stage the private run before executing the matrix'
        tag = case['mode'] + '-' + ('native' if case['native'] else 'smart')
        if case['mode'] == 'performance':
            tag += '-' + str(case['vehicles']) + ('-combat' if case['combat'] else '-idle')
        original_tag = tag + '-21upgrade-01'
        tag += '-21upgrade-' + ('02' if args.replay_performance else '01')
        stage = [sys.executable, '-X', 'utf8', '-B', str(scripts / 'stage_spider.py'),
                 '--run', str(root), '--version', case['version'], '--mode', case['mode'], '--refresh']
        if case['native']:
            stage.append('--native')
        if case['mode'] == 'performance':
            stage.extend(('--vehicles', str(case['vehicles'])))
            if case['combat']:
                stage.append('--combat')
        subprocess.run(stage, check=True)
        run = [sys.executable, '-X', 'utf8', '-B', str(scripts / 'run_staged.py'),
               '--run', str(root), '--tag', tag, '--ticks', '900' if case['mode'] == 'full' else '650',
               '--report', 'spider-vehicles-qc.json', '--timeout', '300']
        if case['version'] == '2.0':
            run.extend(('--engine', 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'))
        if args.suite == 'functional':
            run.extend(('--save', args.player_save))
        elif args.replay_performance:
            run.extend(('--save', str(root / (original_tag + '.zip'))))
        started = time.time()
        process = subprocess.run(run)
        receipt = json.loads((root / (tag + '.receipt.json')).read_text(encoding='utf-8'))
        if args.suite == 'performance' and receipt['passed']:
            profiles = []
            for path in (root / 'script-output').glob('spider-*profile*.txt'):
                assert path.stat().st_mtime >= started, 'Stale module profiler text'
                target = root / (tag + '.' + path.name)
                target.write_bytes(path.read_bytes())
                profiles.append(dict(path=str(target),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
            assert profiles, 'Expected fresh module profiler text'
            receipt['profiles'] = profiles
        summary.append(dict(case=case, receipt=receipt))
        name = args.suite + ('-replay' if args.replay_performance else '') + '-matrix.json'
        (Path(args.run21) / name).write_text(json.dumps(summary, indent=2), encoding='utf-8')
        if process.returncode:
            raise SystemExit(process.returncode)


if __name__ == '__main__':
    main()
