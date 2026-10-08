"""Preserve Meshy source faces/UVs; separate emission and owner roles for ESIR."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    source = Path(args.input).resolve()
    output = Path(args.output).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
    body.name = 'cathedral_architecture'
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = body.data
    original_faces = len(mesh.polygons)
    assert all(p.loop_total == 3 for p in mesh.polygons), 'Source must be triangulated'
    xyz = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get('co', xyz)
    xyz = xyz.reshape(-1, 3)
    lo, hi = xyz.min(axis=0), xyz.max(axis=0)
    origin = np.array([(lo[0]+hi[0])/2, (lo[1]+hi[1])/2, lo[2]])
    xyz -= origin
    width = max(np.ptp(xyz[:, 0]*math.cos(i*math.tau/64) - xyz[:, 1]*math.sin(i*math.tau/64)) for i in range(64))
    height = max(np.ptp((xyz[:, 0]*math.sin(i*math.tau/64) + xyz[:, 1]*math.cos(i*math.tau/64) + xyz[:, 2])/math.sqrt(2)) for i in range(64))
    scale = min(6/width, 8/height)
    xyz *= scale
    mesh.vertices.foreach_set('co', xyz.ravel())
    mesh.update()
    lo, hi = xyz.min(axis=0), xyz.max(axis=0)
    loop_vertices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get('vertex_index', loop_vertices)
    uv = np.empty(len(mesh.loops)*2, dtype=np.float32)
    mesh.uv_layers.active.data.foreach_get('uv', uv)
    uv = uv.reshape(-1, 3, 2).mean(axis=1)
    centers = xyz[loop_vertices.reshape(-1, 3)].mean(axis=1)
    source_material = mesh.materials[0]
    source_bsdf = next(n for n in source_material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    color_node = source_bsdf.inputs['Base Color'].links[0].from_node
    albedo = source.parent/'anisetron-max-detail_textures/base_color.png'
    if albedo.exists(): color_node.image = bpy.data.images.load(str(albedo), check_existing=True)
    texture = color_node.image
    # Scoring uses a compact copy; full-resolution source images remain untouched.
    scoring = texture.copy()
    scoring.scale(1024, 1024)
    pixels = np.empty(1024*1024*4, dtype=np.float32)
    scoring.pixels.foreach_get(pixels)
    pixels = pixels.reshape(1024, 1024, 4)
    rgb = pixels[np.clip((uv[:, 1]*1023).astype(int), 0, 1023), np.clip((uv[:, 0]*1023).astype(int), 0, 1023), :3]
    zratio = centers[:, 2]/hi[2]
    cool = (np.minimum(rgb[:, 1], rgb[:, 2])-rgb[:, 0]*1.15 > 0.025) & (rgb[:, 1] > 0.07)
    core_region = (np.abs(centers[:, 0]) < (hi[0]-lo[0])*.32) & ((zratio < .28) | ((zratio > .43) & (zratio < .92)))
    crystal = cool & core_region
    # One existing gold arch patch becomes the neutral owner crest.
    gold = (rgb[:, 0] > .12) & (rgb[:, 1] > rgb[:, 2]*1.12)
    crest_candidates = gold & (centers[:, 1] > hi[1]*.2) & ~crystal
    desired = np.array([hi[0]*.72, hi[1], hi[2]*.40])
    distances = np.square(centers-desired).sum(axis=1)
    distances[~crest_candidates] = np.inf
    crest_center = centers[np.argmin(distances)]
    crest = crest_candidates & (np.square(centers-crest_center).sum(axis=1) < .12**2)
    assert crystal.sum() > 50, f'No convincing crystal region: {crystal.sum()}'
    assert crest.sum() > 10, f'No facade crest region: {crest.sum()}'
    crystal_material = source_material.copy()
    crystal_material.name = 'cathedral_crystal_pbr'
    bsdf = next(n for n in crystal_material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    crystal_material.node_tree.links.new(bsdf.inputs['Base Color'].links[0].from_socket, bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = .65
    aov = crystal_material.node_tree.nodes.new('ShaderNodeOutputAOV')
    aov.name = 'anisetron_glow_mask'; aov.aov_name = 'anisetron_glow_mask'
    aov.inputs['Value'].default_value = 1
    owner = bpy.data.materials.new('force_trim_neutral')
    owner.use_nodes = True
    node = owner.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (.65, .65, .65, 1)
    node.inputs['Metallic'].default_value = .1
    node.inputs['Roughness'].default_value = .6
    mesh.materials.append(crystal_material)
    mesh.materials.append(owner)
    indices = np.zeros(original_faces, dtype=np.int32)
    indices[crystal] = 1
    indices[crest] = 2
    mesh.polygons.foreach_set('material_index', indices)
    bpy.data.images.remove(scoring)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')
    roles = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            continue
        names = {obj.data.materials[p.material_index].name for p in obj.data.polygons}
        if 'force_trim_neutral' in names:
            obj.name = 'force_trim_crest'; roles[obj.name] = 'owner-mask'
        elif 'cathedral_crystal_pbr' in names:
            obj.name = 'cathedral_crystals'; roles[obj.name] = 'crystal'
        else:
            obj.name = 'cathedral_architecture'; roles[obj.name] = 'architecture'
    preserved = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
    assert preserved == original_faces, 'Preparation changed source face count'
    # User's art-first revision: the existing lower front aperture is the muzzle.
    # No crown, roof opening, keel shortening or geometry addition is made.
    muzzle = [0, float(hi[1])*.92, float(hi[2])*.355]
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    metadata = {'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_faces': original_faces, 'preserved_source_faces': preserved, 'source_origin': origin.tolist(),
        'uniform_scale': float(scale), 'bounds_tiles': {'min': lo.tolist(), 'max': hi.tolist()},
        'roles': roles, 'crystal_faces': int(crystal.sum()), 'crest_faces': int(crest.sum()),
        'muzzle': muzzle, 'hover_height': 1.8,
        'selection': {'cyan_difference': .025, 'core_z': [0, .28, .43, .92], 'crest_center': crest_center.tolist(), 'crest_radius': .12},
        'front_axis': '+Y', 'initial_angle': 0, 'geometry_policy': 'All source faces and UVs preserved; no geometry added.'}
    output.with_suffix('.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print('ANISETRON_PREPARED ' + json.dumps(metadata))


if __name__ == '__main__':
    main()
