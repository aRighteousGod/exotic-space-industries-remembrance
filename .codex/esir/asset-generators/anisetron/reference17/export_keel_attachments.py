"""Export eight original crystal tips and occlusion without rendering any sheets."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

BASE = Path('output/meshy/anisetron/reference17')
TIPS = [
    ('keel_left', 445181, (0.342438996, -0.794227004, 0.306410015)),
    ('keel_center', 273994, (-0.000001000, -0.947820008, 0.320268989)),
    ('keel_right', 101651, (-0.343668014, -0.793519020, 0.306650996)),
    ('keel_side_left', 526065, (0.457902998, -0.784919977, 0.047910001)),
    ('keel_side_right', 20681, (-0.459618002, -0.786695004, 0.046374999)),
    ('keel_rear_left', 527196, (0.461044997, -0.785453022, -0.330394000)),
    ('keel_rear_center', 274070, (0.000018000, -0.831968009, -0.326844007)),
    ('keel_rear_right', 19123, (-0.464065999, -0.777047992, -0.328819007)),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def prepared(point):
    x, y, z = point
    origin = (-0.00019401311874389648, -0.00025400519371032715, -0.9478200078010559)
    scale = 4.939079761505127
    return (-(x-origin[0])*scale, -(-z-origin[1])*scale, (y-origin[2])*scale)

def project(point, index):
    x, y, z = point
    angle = math.tau*index/128
    rx = x*math.cos(angle)+y*math.sin(angle)
    ry = -x*math.sin(angle)+y*math.cos(angle)
    return [index/128, [rx, -(ry+z)/math.sqrt(2)]]

def find_anchors(value):
    if isinstance(value, dict):
        if 'anisetron_anchor_pixels' in value:
            return value['anisetron_anchor_pixels']
        for child in value.values():
            found = find_anchors(child)
            if found is not None:
                return found
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    scene = BASE/'prepared-v2/anisetron17.blend'
    metadata_path = scene.with_suffix('.json')
    manifest_path = BASE/'prepared-v2/full128/factorio-preset-render-manifest.json'
    metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    bpy.ops.wm.open_mainfile(filepath=str(scene.resolve()))
    vertices, polygons = [], []
    for name in metadata['roles']:
        obj = bpy.data.objects[name]
        if obj.type != 'MESH':
            continue
        base = len(vertices)
        vertices.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        polygons.extend(tuple(base+i for i in polygon.vertices) for polygon in obj.data.polygons)
    bvh = BVHTree.FromPolygons(vertices, polygons, all_triangles=True)
    points = {name: prepared(point) for name, _, point in TIPS}
    for name, _, _ in TIPS[:3]:
        assert max(abs(a-b) for a,b in zip(points[name], metadata['anchors'][name])) < .000002
        points[name] = metadata['anchors'][name]
    lookup, visible, hits, clearance = {}, {}, {}, {}
    for name, point in points.items():
        lookup[name] = [project(point, i) for i in range(128)]
        visible[name], hits[name], clearance[name] = [], [], []
        for i in range(128):
            angle = math.tau*i/128
            direction = Vector((math.sin(angle), -math.cos(angle), 1)).normalized()
            # Ignore incident tip triangles for visibility only; roots do not move.
            start = Vector(point)+direction*.08
            location, _, _, distance = bvh.ray_cast(start, direction, 30)
            visible[name].append(location is None)
            hits[name].append(None if location is None else distance+.08)
            # Screen-plane trail samples at the root's depth prevent a visible
            # far-side tip from projecting its longer filament across the hull.
            horizontal = Vector((math.cos(angle), math.sin(angle), 0))
            downward = Vector((math.sin(angle), -math.cos(angle), -1)).normalized()
            row = []
            for heading in range(32):
                a = math.tau*heading/32
                along = horizontal*math.cos(a)+downward*math.sin(a)
                across = -horizontal*math.sin(a)+downward*math.cos(a)
                clear = 0
                if location is None:
                    for step in range(1, 15):
                        length = step*.1
                        blocked = any(bvh.ray_cast(Vector(point)+along*length+across*width+direction*.08,
                                                  direction, 30)[0] is not None for width in (-.05, 0, .05))
                        if blocked:
                            break
                        clear = length
                row.append(round(clear, 2))
            clearance[name].append(row)
    center = tuple(sum(point[j] for point in points.values())/8 for j in range(3))
    lookup['keel_base_center'] = [project(center, i) for i in range(128)]
    old = find_anchors(manifest)
    assert old is not None
    error = max(abs(project(metadata['anchors'][name], i)[1][j] -
                    (row['anchor'][j]-row['pivot'][j])*1.25/32)
                for name, rows in old.items() for i, row in enumerate(rows) for j in range(2))
    assert error < .000003, error
    existing = Path('exotic-space-industries-remembrance/lib/anisetron-graphics.lua').read_text(encoding='utf-8')
    existing = existing.split('-- Eight-tip attachment extension.')[0].rstrip()
    existing = existing.replace('return {direction_count', 'local graphics = {direction_count', 1)
    lines = [existing, '-- Eight-tip attachment extension. Original render rows above remain unchanged.']
    for name in list(points)[3:]+['keel_base_center']:
        lines.append('anchors.'+name+' = {')
        for orientation, offset in lookup[name]:
            lines.append('    {%.9f, {%.9f, %.9f}},' % (orientation, *offset))
        lines.append('}')
    lines.append('graphics.keel_tips = {'+', '.join('anchors.'+name for name in points)+'}')
    lines.append('graphics.keel_names = {'+', '.join('"'+name+'"' for name in points)+'}')
    lines.append('graphics.keel_visibility = {')
    for name in points:
        lines.append('    {'+', '.join('true' if value else 'false' for value in visible[name])+'},')
    lines.extend(['}', 'graphics.keel_trail_clearance = {'])
    for name in points:
        lines.append('    {')
        for row in clearance[name]:
            lines.append('        {'+', '.join(str(value) for value in row)+'},')
        lines.append('    },')
    lines.extend(['}', 'graphics.keel_base_center = anchors.keel_base_center', 'return graphics', ''])
    args.output.mkdir(parents=True, exist_ok=True)
    lua = args.output/'anisetron-graphics.lua'
    lua.write_text('\n'.join(lines), encoding='utf-8')
    report = {'source_hashes': {str(path): sha(path) for path in
              [BASE/'anisetron17-max-detail.glb', scene, metadata_path, manifest_path]},
              'original_vertices': TIPS, 'prepared_points': points, 'lookup': lookup,
              'visibility': visible, 'nearest_occluder_distance': hits,
              'trail_clearance': clearance, 'trail_direction_count': 32,
              'trail_sample_step_tiles': .1, 'trail_half_width_tiles': .05,
              'self_hit_tolerance_tiles': .08, 'old_projection_max_error_tiles': error,
              'visible_counts': {name: sum(values) for name, values in visible.items()},
              'lua_sha256': sha(lua), 'direction_count': 128, 'sheets_changed': False}
    (args.output/'attachments.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'visible_counts': report['visible_counts'], 'projection_error': error, 'output': str(lua)}))

if __name__ == '__main__':
    main()
