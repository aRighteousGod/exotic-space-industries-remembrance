"""Register native body pixels and diagnose attachments after a gait change.

Uses the existing reference17 evaluator. Composite rays can be unmeasurable;
height residuals infer bob from the following physics position and are diagnostic.
This does not certify all headings or change source pixels/runtime offsets.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True, help='Regression script-output directory')
parser.add_argument('--bundle', type=Path, required=True)
parser.add_argument('--curve', type=float, nargs=3, default=[-.34, .875, .083])
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / '.codex/esir/asset-generators/anisetron/reference17'))
from measure_twin_emitters import Evaluator, point

root = args.source / 'anisetron-regression'
metadata = root / 'captures.json'
trace_file = root / 'trace.json'
frames = json.loads(metadata.read_text(encoding='utf-8-sig'))['frames']
trace = json.loads(trace_file.read_text(encoding='utf-8-sig'))
lookup = {(row['actor'], row['tick']): row for row in trace}
evaluator = Evaluator(args.bundle)
results = []
for frame in frames:
    if not any(f'/{family}/' in frame['path'] for family in
               ('turning-dense', 'acceleration-dense', 'stopping-dense', 'trail-day', 'trail-night')):
        continue
    row = lookup[frame['actor'], frame['tick']]
    pose = dict(row, camera=frame['camera'], channel_view='all', owner={'burst': row['channels']})
    shot = args.source / frame['path']
    result = {'shot': frame['path'], 'tick': frame['tick'], 'actor': frame['actor'],
              'speed': row['speed'], 'moving': bool((row.get('motion') or {}).get('moving')),
              'emitters': {}}
    fit = None
    for emitter, channel in row['channels'].items():
        if not channel.get('beam') or not channel.get('endpoint'):
            continue
        try:
            measurement = evaluator.measure(shot, pose, emitter, {'channel_view': 'all'})
            result['emitters'][emitter] = measurement
            if measurement.get('status') == 'measured':
                fit = measurement
        except ValueError as error:
            result['emitters'][emitter] = {'status': 'unmeasurable', 'reason': str(error)}
    try:
        screen = np.asarray(Image.open(shot).convert('RGB'), dtype=np.float32) / 255
        zoom, centre, origin, ground, exact = evaluator.camera(pose, screen.shape)
        if fit is None:
            endpoints = {name: evaluator.endpoint(pose, name, centre, origin, zoom)[0]
                         for name, channel in row['channels'].items() if channel.get('endpoint')}
            registration = evaluator.register(screen, pose, zoom, ground, endpoints)
            fit = {'pivot_px': registration['pivot'].tolist(), 'body_index': registration['body_index'],
                   'correlation': registration['correlation']}
        following = lookup.get((frame['actor'], frame['tick'] + 1))
        if following:
            displacement = point(following['position']) - point(row['position'])
            physical_ground = ground + displacement * 32 * zoom
            inferred = (physical_ground[1] - fit['pivot_px'][1]) / (32 * zoom) - 1.8
            minimum, span, speed = args.curve
            configured = minimum + span * min(abs(row['speed']) / speed, 1)
            result['keel_height_diagnostic'] = {
                'correlation': fit['correlation'], 'body_index': fit['body_index'],
                'inferred_residual_lift_tiles': float(inferred),
                'configured_residual_lift_tiles': float(configured),
                'estimated_vertical_residual_px': float((inferred - configured) * 32 * zoom),
                'certified': False}
    except ValueError as error:
        result['keel_height_diagnostic'] = {'status': 'unmeasurable', 'reason': str(error)}
    results.append(result)

measured = [m for row in results for m in row['emitters'].values() if m.get('status') == 'measured']
report = {'scope': 'Composite motion diagnostic; incomplete isolated-heading coverage', 'certified': False,
          'limits': ['Nearly coincident core rays cannot be identified independently.',
                     'Body registration is measured; keel heave residual is inferred.',
                     'Native bob is not exposed. Individual strand origin is not measured.'],
          'curve': args.curve, 'frames': len(results), 'measured_emitters': len(measured),
          'measured_emitter_failures': sum(not m['pass'] for m in measured),
          'low_body_correlation': sum(m['correlation'] <= .95 for m in measured),
          'distance_over_two_pixels': sum(m['centerline_distance_px'] > 2 for m in measured),
          'direction_index_mismatches': sum(not m['runtime_index_matches_body'] for m in measured),
          'maximum_measured_core_distance_px': max((m['centerline_distance_px'] for m in measured), default=None),
          'hashes': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (metadata, trace_file)},
          'results': results}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: report[key] for key in ('frames', 'measured_emitters', 'measured_emitter_failures',
                                             'maximum_measured_core_distance_px', 'certified')}))
