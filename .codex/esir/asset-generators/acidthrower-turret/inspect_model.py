"""Read-only Blender geometry inspection for a downloaded acidthrower GLB."""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector

root = Path('output/meshy/acidthrower-turret').resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'source/attempt-01.glb'))
report = {'objects': [], 'images': []}
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    slices = []
    for index in range(24):
        bottom = low[2] + (high[2]-low[2])*index/24
        top = low[2] + (high[2]-low[2])*(index+1)/24
        selected = [p for p in points if bottom <= p.z < top]
        if selected:
            slices.append({'z': [bottom,top], 'count': len(selected),
                           'x': [min(p.x for p in selected),max(p.x for p in selected)],
                           'y': [min(p.y for p in selected),max(p.y for p in selected)]})
    report['objects'].append({'name': obj.name, 'vertices':len(points),
        'faces':len(obj.data.polygons), 'bounds':[low,high],
        'matrix':[list(row) for row in obj.matrix_world],
        'materials':[slot.material.name if slot.material else None for slot in obj.material_slots],
        'z_slices':slices})
for image in bpy.data.images:
    report['images'].append({'name':image.name,'size':list(image.size),'packed':bool(image.packed_file)})
(root/'source/geometry-inspection.json').write_text(json.dumps(report,indent=2))
print('ACID_INSPECT '+json.dumps(report))
