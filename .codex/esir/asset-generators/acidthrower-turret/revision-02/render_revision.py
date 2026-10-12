"""Factorio preset render with independent base placement and restricted head yaw."""
import importlib.util, json, math, os
from pathlib import Path
import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
PIVOT=Vector((0,.55,.43))
path=Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec=importlib.util.spec_from_file_location('acid_revision_preset',path)
preset=importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
original_driver=preset.add_unit_driver
original_output=preset.set_file_output_path
original_render=preset.render_animation

def output_path(node,folder):
    if hasattr(node,'directory'):
        folder.mkdir(parents=True,exist_ok=True)
        node.directory=str(folder)
        node.file_name=''
    else:
        original_output(node,folder)

def place(objects,args,slope_parent=None):
    rotator=bpy.data.objects['Rotation by Frames & Directions']
    head=bpy.data.objects.new('AcidHeadYaw',None)
    bpy.context.scene.collection.objects.link(head)
    head.parent=rotator
    head.matrix_parent_inverse=Matrix.Identity(4)
    head.matrix_basis=Matrix.Translation(PIVOT)
    rest={obj.name:obj.matrix_world.copy() for obj in objects}
    for obj in objects:
        preset.unlink_from_all(obj)
        preset.link_to_collection(obj,'Normal')
        upper=obj.name.startswith(('acid_yaw_','acid_trim_yaw_'))
        obj.parent=head if upper else rotator
        obj.matrix_parent_inverse=Matrix.Identity(4)
        obj.matrix_basis=Matrix.Translation(-PIVOT)@rest[obj.name] if upper else rest[obj.name]

def driver(args):
    original_driver(args)
    head=bpy.data.objects['AcidHeadYaw']
    curve=head.driver_add('rotation_euler',2)
    curve.driver.type='SCRIPTED'
    if args.animation_frames==5:
        curve.driver.expression='radians(48 - 24 * ((frame - 1) % 5))'
    else:
        assert args.animation_frames==1
        curve.driver.expression='0'

def render(output_dir):
    args=preset.parse_args()
    scene=bpy.context.scene
    rotator=bpy.data.objects['Rotation by Frames & Directions']
    head=bpy.data.objects['AcidHeadYaw']
    model=json.loads((ROOT/'model-anchors.json').read_text()) if (ROOT/'model-anchors.json').exists() else {}
    muzzle=Vector(model.get('muzzle_xyz',[0,1.35,.85]))
    poses=[]
    for frame in range(1,args.frames+1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        base_expected=((frame-1)//args.animation_frames)*360/args.directions
        relative_expected=-48+24*((frame-1)%5) if args.animation_frames==5 else 0
        base_actual=-math.degrees(rotator.rotation_euler.z)
        relative_actual=-math.degrees(head.rotation_euler.z)
        assert abs(base_actual-base_expected)<.001,(frame,base_actual,base_expected)
        assert abs(relative_actual-relative_expected)<.001,(frame,relative_actual,relative_expected)
        assert abs(relative_actual)<=48.001
        expected_pivot=Matrix.Rotation(math.radians(-base_expected),4,'Z')@PIVOT
        actual_pivot=head.matrix_world.translation
        assert (actual_pivot-expected_pivot).length<1e-5,(frame,list(actual_pivot),list(expected_pivot))
        muzzle_world=head.matrix_world@(muzzle-PIVOT)
        screen={}
        for key,point in [('origin',Vector((0,0,0))),('bearing',actual_pivot),('muzzle',muzzle_world),
            ('left_pipe_mouth',rotator.matrix_world@Vector((-1,-1,.29))),
            ('right_pipe_mouth',rotator.matrix_world@Vector((1,-1,.29)))]:
            view=world_to_camera_view(scene,scene.camera,point)
            screen[key]=[view.x*scene.render.resolution_x,(1-view.y)*scene.render.resolution_y]
        poses.append({'frame':frame,'base_degrees':base_actual,'relative_head_degrees':relative_actual,
            'bearing_xyz':list(actual_pivot),'muzzle_xyz':list(muzzle_world),'screen_anchors':screen})
    (output_dir/'verified-frame-poses.json').write_text(json.dumps(poses,indent=2))
    original_render(output_dir)

preset.place_imported_objects=place
preset.add_unit_driver=driver
preset.set_file_output_path=output_path
preset.render_animation=render
preset.main()
