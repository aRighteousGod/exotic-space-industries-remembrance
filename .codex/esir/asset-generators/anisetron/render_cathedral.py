"""Named model groups, isolated emission/owner mask and all-yaw preset fitting."""
import importlib.util
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

REPO=Path.cwd()
shared=REPO/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec=importlib.util.spec_from_file_location('anisetron_preset',shared)
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
original_import=preset.import_model
original_place=preset.place_imported_objects
original_preflight=preset.preflight_report

def import_model(path):
    if path.suffix.lower()!='.blend':return original_import(path)
    with bpy.data.libraries.load(str(path),link=False) as (source,target):
        target.objects=[name for name in source.objects if name.startswith(('cathedral_','force_trim_'))]
    objects=[]
    for obj in target.objects:
        if obj:bpy.context.scene.collection.objects.link(obj);objects.append(obj)
    return objects

def collection(root,name):
    if root.name==name:return root
    for child in root.children:
        found=collection(child,name)
        if found:return found

def place(objects,args,slope_parent=None):
    original_place(objects,args,slope_parent)
    for obj in objects:
        if obj.name.startswith('force_trim_'):
            preset.unlink_from_all(obj);preset.link_to_collection(obj,'Colored')
        if any(mat and ('crystal' in mat.name.lower() or 'facet' in mat.name.lower())
               for mat in obj.data.materials):obj.lightgroup='Lights'
    for layer in bpy.context.scene.view_layers:
        colored=collection(layer.layer_collection,'Colored')
        if colored and layer.name in ('Object','Shadow'):
            colored.exclude=False;colored.holdout=False;colored.indirect_only=True

def preflight(args,**kwargs):
    scene=bpy.context.scene;reports=[]
    for frame in range(1,args.directions+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        report=original_preflight(args,**kwargs)
        # Fitting the full centered image needs origin-to-edge extents, not width alone.
        bounds=preset.camera_plane_bounds(kwargs['imported'],scene.camera)
        if bounds:
            # Camera projection includes translation; use normalized image positions.
            worst=0.0
            for obj in kwargs['imported']:
                for corner in obj.bound_box:
                    p=world_to_camera_view(scene,scene.camera,obj.matrix_world@Vector(corner))
                    worst=max(worst,abs(p.x-.5),abs(p.y-.5))
            required=scene.camera.data.ortho_scale*worst/(.5-args.preflight_margin)
            report['framing']['minimum_ortho_scale']=max(required,report['framing']['minimum_ortho_scale'])
            report['framing']['framing_risk']=required>scene.camera.data.ortho_scale
        reports.append(report)
    result=max(reports,key=lambda r:r['framing']['minimum_ortho_scale'])
    result['anisetron_heading_count']=len(reports);result['anisetron_crown_pixels']=[]
    rotator=bpy.data.objects.get('Rotation by Frames & Directions')
    width,height=scene.render.resolution_x,scene.render.resolution_y
    for frame in range(1,args.directions+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        p=world_to_camera_view(scene,scene.camera,rotator.matrix_world@Vector((0,0,3.97)))
        pivot=world_to_camera_view(scene,scene.camera,rotator.matrix_world@Vector((0,0,0)))
        result['anisetron_crown_pixels'].append({'direction':frame-1,'crown':[p.x*width,(1-p.y)*height],
                                               'pivot':[pivot.x*width,(1-pivot.y)*height]})
    scene.frame_set(1);return result

preset.import_model=import_model;preset.place_imported_objects=place;preset.preflight_report=preflight
preset.main()
