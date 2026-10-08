"""Inspect an original Meshy chapel through the Factorio preset without material edits."""
import hashlib
import importlib.util
import math
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

shared = Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec = importlib.util.spec_from_file_location('anisetron_inspection_preset',shared)
preset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
original_import = preset.import_model
original_place = preset.place_imported_objects
original_preflight = preset.preflight_report
metadata, casters = {}, []

def import_model(path):
    global metadata
    imported = original_import(path)
    meshes = [obj for obj in imported if obj.type == 'MESH']
    assert meshes and all(len(obj.data.polygons)>0 for obj in meshes), 'Empty source mesh'
    original_counts = [(len(obj.data.vertices),len(obj.data.polygons)) for obj in meshes]
    coordinates = []
    for obj in meshes:
        # Preserve world geometry before removing imported parent hierarchies.
        if obj.data.users>1:
            obj.data = obj.data.copy()
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        obj.data.transform(world)
        xyz = np.empty(len(obj.data.vertices)*3,dtype=np.float32)
        obj.data.vertices.foreach_get('co',xyz)
        coordinates.append(xyz.reshape(-1,3))
    all_xyz = np.concatenate(coordinates)
    lo,hi = all_xyz.min(0),all_xyz.max(0)
    origin = np.array([(lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]])
    all_xyz -= origin
    width = max(np.ptp(all_xyz[:,0]*math.cos(i*math.tau/64)-all_xyz[:,1]*math.sin(i*math.tau/64)) for i in range(64))
    height = max(np.ptp((all_xyz[:,0]*math.sin(i*math.tau/64)+all_xyz[:,1]*math.cos(i*math.tau/64)+all_xyz[:,2])/math.sqrt(2)) for i in range(64))
    scale = min(6/width,8/height)
    for obj,xyz in zip(meshes,coordinates):
        xyz = (xyz-origin)*scale
        obj.data.vertices.foreach_set('co',xyz.ravel())
        obj.data.update()
    for obj in imported:
        if obj not in meshes:
            bpy.data.objects.remove(obj,do_unlink=True)
    assert original_counts == [(len(obj.data.vertices),len(obj.data.polygons)) for obj in meshes]
    textures = []
    for material in {mat for obj in meshes for mat in obj.data.materials if mat}:
        for node in material.node_tree.nodes if material.use_nodes else []:
            if node.type == 'TEX_IMAGE' and node.image:
                textures.append({'material':material.name,'image':node.image.name,
                    'size':list(node.image.size),'colorspace':node.image.colorspace_settings.name})
    metadata = {'source':str(path),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'mesh_count':len(meshes),'vertices':sum(c[0] for c in original_counts),
        'faces':sum(c[1] for c in original_counts),'textures':textures,
        'source_origin':origin.tolist(),'uniform_scale':float(scale),
        'projected_tiles':{'width':float(width*scale),'height':float(height*scale)},
        'hover_shadow_height':1.8,'muzzle_status':'Not calibrated; model inspection only',
        'geometry_policy':'All source vertices/faces/UVs and PBR materials retained; uniform framing only.'}
    return meshes

def layer_collection(root,name):
    if root.name == name:
        return root
    for child in root.children:
        found = layer_collection(child,name)
        if found:
            return found

def place(objects,args,slope_parent=None):
    original_place(objects,args,slope_parent)
    shadows = bpy.data.collections.new('ANISETRON Inspection Shadow Casters')
    bpy.context.scene.collection.children.link(shadows)
    for obj in objects:
        caster = obj.copy()
        caster.name = obj.name+'_hover_shadow'
        caster.location.z += 1.8
        shadows.objects.link(caster)
        casters.append(caster)
    for layer in bpy.context.scene.view_layers:
        shadow = layer_collection(layer.layer_collection,shadows.name)
        shadow.exclude = layer.name != 'Shadow'
        shadow.indirect_only = layer.name == 'Shadow'
        if layer.name == 'Shadow':
            for name in ('Normal','Colored'):
                layer_collection(layer.layer_collection,name).exclude = True

def preflight(args,**kwargs):
    scene = bpy.context.scene
    reports = []
    for frame in range(1,args.directions+1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        report = original_preflight(args,**kwargs)
        worst = 0
        for obj in kwargs['imported']+casters:
            for corner in obj.bound_box:
                world = obj.matrix_world@Vector(corner)
                points = [world]
                if obj in casters:
                    points.append(Vector((world.x+world.z*32/48,world.y,0)))
                for point in points:
                    p = world_to_camera_view(scene,scene.camera,point)
                    worst = max(worst,abs(p.x-.5),abs(p.y-.5))
        required = scene.camera.data.ortho_scale*worst/(.5-args.preflight_margin)
        report['framing']['minimum_ortho_scale'] = max(required,report['framing']['minimum_ortho_scale'])
        report['framing']['framing_risk'] = required>scene.camera.data.ortho_scale
        reports.append(report)
    result = max(reports,key=lambda report:report['framing']['minimum_ortho_scale'])
    result['anisetron_inspection'] = metadata
    scene.frame_set(1)
    return result

preset.import_model = import_model
preset.place_imported_objects = place
preset.preflight_report = preflight
preset.main()
