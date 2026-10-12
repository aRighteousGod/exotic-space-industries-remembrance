"""Prove clearance between sampled poses using a conservative motion envelope."""
import json
import math
import os
from pathlib import Path
import bpy
from mathutils import Vector

root = Path(os.environ.get('ESIR_ACID_REVISION_ROOT', 'D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
bpy.ops.wm.open_mainfile(filepath=str(root / 'prepared/acidthrower-revision02.blend'))
qa = json.loads((root / 'geometry-qa.json').read_text())
anchors = json.loads((root / 'model-anchors.json').read_text())
pivot = Vector(anchors['bearing_xyz'])
points = [obj.matrix_world @ vert.co for name in anchors['upper_objects']
          for obj in [bpy.data.objects[name]] for vert in obj.data.vertices]
radius = max(math.hypot(point.x - pivot.x, point.y - pivot.y) for point in points)
# Every continuous angle is within 1.5 degrees of one sampled 3-degree pose.
# Chord length bounds each vertex's XY displacement; Z is invariant under yaw.
pad = 2 * radius * math.sin(math.radians(1.5) / 2) + 1e-6
fixed = {}
for name in anchors['base_objects']:
    if name.startswith('acid_fixed_bearing_'):
        continue  # Intentional engaged bearing surfaces.
    obj = bpy.data.objects[name]
    vertices = [obj.matrix_world @ vert.co for vert in obj.data.vertices]
    fixed[name] = ([min(point[i] for point in vertices) for i in range(3)],
                   [max(point[i] for point in vertices) for i in range(3)])
checks = []
for pose in qa['head_clearance_poses']:
    low, high = [list(bounds) for bounds in pose['upper_bounds']]
    for axis in (0, 1):
        low[axis] -= pad
        high[axis] += pad
    assert low[0] >= -1 and high[0] <= 1 and low[1] >= -1.5 and high[1] <= 1.5
    gaps = {}
    for name, (fixed_low, fixed_high) in fixed.items():
        gap = max(max(fixed_low[i] - high[i], low[i] - fixed_high[i]) for i in range(3))
        assert gap > 0, (pose['head_yaw_degrees'], name, gap)
        gaps[name] = gap
    checks.append({'nearest_pose_degrees': pose['head_yaw_degrees'],
                   'minimum_separating_axis_gap': min(gaps.values())})
report = {'passed': True, 'continuous_arc_degrees': [-48, 48],
          'proof': '33 sampled AABBs enlarged in XY by the maximum vertex chord travel to a nearest sample; Z unchanged.',
          'maximum_vertex_pivot_radius': radius, 'nearest_sample_max_angle_degrees': 1.5,
          'xy_envelope_padding': pad, 'intentional_overlap_excluded': 'acid_fixed_bearing_*',
          'fixed_components_checked': len(fixed), 'footprint_continuously_contained': True,
          'checks': checks}
(root / 'continuous-clearance-qa.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'checks'}, indent=2))
