"""Render staged acidthrower variants with the repository's Factorio preset."""
import importlib.util, json, math, os
from pathlib import Path
import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

repo = Path.cwd()
path = repo/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec = importlib.util.spec_from_file_location('esir_acid_preset', path)
preset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
original_place = preset.place_imported_objects
original_output_path = preset.set_file_output_path
original_driver = preset.add_unit_driver
original_render = preset.render_animation
staging = Path(os.environ.get('ESIR_ACID_STAGING_ROOT', str(repo/'output/meshy/acidthrower-turret')))
head_scale = float(os.environ.get('ESIR_ACID_HEAD_SCALE', '1'))
yaw_angles = json.loads(os.environ.get('ESIR_ACID_YAW_ANGLES', 'null'))

def output_path(node, folder):
    # Blender 5.1 exposes directory separately. An absolute directory also
    # supports staging on a different drive from the checked-in .blend preset.
    if hasattr(node, 'directory'):
        folder.mkdir(parents=True, exist_ok=True)
        node.directory = str(folder)
        node.file_name = ''
    else:
        original_output_path(node, folder)

def place(objects, args, slope_parent=None):
    if head_scale != 1:
        assert 0 < head_scale <= 1, 'Draft upper scale must be in (0,1].'
        description = json.loads((staging/'mechanical-split.json').read_text())
        pivot = Vector((0, 0, description['seam_z']))
        shrink = Matrix.Translation(pivot) @ Matrix.Scale(head_scale, 4) @ Matrix.Translation(-pivot)
        for obj in objects:
            if obj.type == 'MESH':
                obj.matrix_world = shrink @ obj.matrix_world
        bpy.context.view_layer.update()
    matrices = {obj.name: obj.matrix_world.copy() for obj in objects}
    original_place(objects, args, slope_parent)
    if os.environ.get('ESIR_ACID_ASSEMBLED') == '1':
        for obj in objects:
            if obj.name.startswith(('stationary_', 'fixed_')):
                obj.parent = None
                obj.matrix_world = matrices[obj.name]

def driver(args):
    original_driver(args)
    if yaw_angles is not None:
        assert len(yaw_angles) == args.frames
        rotator = bpy.data.objects['Rotation by Frames & Directions']
        # The preset can initially be on frame 64. A bounded conditional driver
        # handles that state without invalidating the driver before rendering.
        expression = ''.join(f'{-angle} if frame < {index+1.5} else ' for index,angle in enumerate(yaw_angles[:-1]))
        rotator.animation_data.drivers[0].driver.expression = 'radians('+expression+str(-yaw_angles[-1])+')'

def render(output_dir):
    if yaw_angles is not None:
        scene = bpy.context.scene
        rotator = bpy.data.objects['Rotation by Frames & Directions']
        poses=[]
        for index,angle in enumerate(yaw_angles,1):
            scene.frame_set(index)
            bpy.context.view_layer.update()
            actual = -math.degrees(rotator.rotation_euler.z)
            assert abs(actual-angle) < 0.001, (index,angle,actual,'Invalid preview yaw')
            poses.append({'frame':index,'expected_clockwise_yaw':angle,'actual_clockwise_yaw':actual})
        (output_dir/'verified-frame-poses.json').write_text(json.dumps(poses,indent=2))
    original_render(output_dir)

preset.place_imported_objects = place
preset.set_file_output_path = output_path
preset.add_unit_driver = driver
preset.render_animation = render
preset.main()
args = preset.parse_args()
geometry = Path(os.environ.get('ESIR_ACID_STAGING_ROOT', str(repo/'output/meshy/acidthrower-turret')))/'mechanical-split.json'
if geometry.exists():
    description = json.loads(geometry.read_text())
    scene = bpy.context.scene
    scene.frame_set(1)
    width, height = scene.render.resolution_x, scene.render.resolution_y
    points = {}
    for name, xyz in [('ground', [0,0,0]), ('bearing', [0,0,description['seam_z']]),
                      ('muzzle', description['muzzle_xyz'])]:
        if name == 'muzzle' and head_scale != 1:
            pivot = Vector((0,0,description['seam_z']))
            xyz = pivot + head_scale * (Vector(xyz)-pivot)
        view = world_to_camera_view(scene, scene.camera, Vector(xyz))
        points[name] = [view.x*width, (1-view.y)*height]
    output = Path(args.output_dir)
    (output/'render-anchors.json').write_text(json.dumps({'resolution':[width,height],
        'pixels_per_tile':args.tile_size,'frame_1_anchors':points,
        'upper_uniform_scale':head_scale,'scale_pivot':[0,0,description['seam_z']],
        'yaw_degrees_clockwise_from_north':yaw_angles},indent=2))
