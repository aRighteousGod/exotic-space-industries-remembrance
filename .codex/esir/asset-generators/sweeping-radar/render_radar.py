"""Render prepared radar groups through the shared Factorio preset."""
import importlib.util
import argparse
import hashlib
import json
import struct
import sys
import time
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

# Radar-only options stay outside the shared preset's argument surface.
options=argparse.ArgumentParser(add_help=False)
options.add_argument('--radar-master',action='store_true')
options.add_argument('--radar-start',type=int,default=1)
options.add_argument('--radar-end',type=int)
argument_start=sys.argv.index('--')+1
radar_args,shared_args=options.parse_known_args(sys.argv[argument_start:])
sys.argv=sys.argv[:argument_start]+shared_args

path=Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec=importlib.util.spec_from_file_location('esir_factorio_preset',path)
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
original_import=preset.import_model
original_place=preset.place_imported_objects
original_render=preset.render_animation

def import_model(path):
    print('Radar render: importing prepared objects', flush=True)
    if path.suffix.lower()!='.blend':return original_import(path)
    with bpy.data.libraries.load(str(path),link=False) as (source,target):
        target.objects=[name for name in source.objects if name.startswith(('fixed_','rotor_'))]
    for obj in target.objects:
        if obj:bpy.context.scene.collection.objects.link(obj)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    matrices={obj.name:obj.matrix_world.copy() for obj in target.objects if obj}
    result=[]
    for obj in target.objects:
        if obj and obj.type=='MESH':
            obj.parent=None;obj.matrix_world=matrices[obj.name]
            if obj.animation_data:obj.animation_data_clear()
            result.append(obj)
    for obj in target.objects:
        if obj and obj.type=='EMPTY':bpy.data.objects.remove(obj,do_unlink=True)
    print('Radar render: prepared objects imported', flush=True)
    return result

def place(objects,args,slope_parent=None):
    print('Radar render: placing fixed and rotating groups', flush=True)
    matrices={obj.name:obj.matrix_world.copy() for obj in objects}
    original_place(objects,args,slope_parent)
    for obj in objects:
        if obj.name.startswith('fixed_'):
            obj.parent=None;obj.matrix_world=matrices[obj.name]
        if obj.name in ('rotor_upper_assembly','rotor_red_core_indicator') and hasattr(obj,'lightgroup'):
            # The preset compositor extracts emission through its Lights pass.
            obj.lightgroup='Lights'
    print('Radar render: groups placed', flush=True)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def write_checkpoint(path,record):
    temporary=path.with_suffix('.tmp')
    temporary.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    temporary.replace(path)


def render_master(output_dir):
    """Keep original per-pass PNGs and checkpoint each complete heading."""
    if not radar_args.radar_master:
        return original_render(output_dir)
    args=preset.parse_args()
    scene=bpy.context.scene
    count=args.frames
    assert count==args.directions and args.animation_frames==1
    first,last=radar_args.radar_start,radar_args.radar_end or count
    assert 1<=first<=last<=count
    folders=[preset.PASS_DEFS[p]['folder'] for p in preset.parse_passes(args.passes)]
    width,height=scene.render.resolution_x,scene.render.resolution_y
    anchor=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
    contract=dict(schema=1,source_sha256=sha(args.input),preset_sha256=sha(args.preset_blend),
        renderer_sha256=sha(__file__),shared_renderer_sha256=sha(path),blender=bpy.app.version_string,
        master_count=count,initial_angle=args.initial_angle,clockwise=True,
        direction_step_degrees=360/count,scale=0.5,resolution=[width,height],
        source_anchor_pixels=[anchor.x*width,(1-anchor.y)*height],
        samples=scene.cycles.samples,denoising=scene.cycles.use_denoising,
        ortho_scale=scene.camera.data.ortho_scale,passes=folders,
        source_description='Assembled body with stationary wired base and rotating upper assembly')
    checkpoint=output_dir/'radar-master-manifest.json'
    if checkpoint.exists():
        record=json.loads(checkpoint.read_text(encoding='utf-8'))
        assert record['contract']==contract, 'Master settings changed; use a new output directory'
    else:
        assert not any(output_dir.glob('*/[0-9][0-9][0-9][0-9].png')), 'Untracked frames in new master directory'
        record=dict(contract=contract,frames={},complete=False)
        write_checkpoint(checkpoint,record)
    scene.frame_set(1)
    fixed={o.name:o.matrix_world.copy() for o in scene.objects if o.name.startswith('fixed_')}
    started=time.monotonic();rendered=0
    for frame in range(first,last+1):
        filename=f'{frame:04d}.png'
        previous=record['frames'].get(str(frame))
        if previous:
            for folder in folders:
                assert sha(output_dir/folder/filename)==previous['passes'][folder]['sha256'], 'Retained master changed'
            continue
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        assert all(max(abs(o.matrix_world[r][c]-fixed[o.name][r][c]) for r in range(4) for c in range(4))<1e-6
                   for o in scene.objects if o.name in fixed), 'Fixed base moved'
        # An animation render writes the preset's File Output compositor nodes.
        # A single-frame animation range keeps its numbered pass filenames.
        scene.frame_start=frame;scene.frame_end=frame
        bpy.ops.render.render(animation=True)
        entry=dict(index=frame-1,angle_degrees=(frame-1)*360/count,
                   source_yaw_degrees=-args.initial_angle-(frame-1)*360/count,passes={})
        for folder in folders:
            target=output_dir/folder/filename
            header=target.read_bytes()[:24]
            assert header[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',header[16:24])==(width,height)
            entry['passes'][folder]=dict(path=f'{folder}/{filename}',bytes=target.stat().st_size,sha256=sha(target))
        record['frames'][str(frame)]=entry
        record['complete']=len(record['frames'])==count
        write_checkpoint(checkpoint,record)
        rendered+=1
        print(f'RADAR_MASTER frame={frame}/{count} retained={len(record["frames"])} seconds={time.monotonic()-started:.1f}',flush=True)
    print(f'RADAR_MASTER_DONE complete={record["complete"]} retained={len(record["frames"])}',flush=True)
    scene.frame_start=1;scene.frame_end=count

preset.import_model=import_model
preset.place_imported_objects=place
preset.render_animation=render_master
preset.main()
