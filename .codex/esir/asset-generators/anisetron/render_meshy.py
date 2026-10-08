"""Meshy role routing, pure surface glow, lifted shadows and native emitter anchors."""
import importlib.util
import json
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

shared = Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec = importlib.util.spec_from_file_location('anisetron_preset', shared)
preset = importlib.util.module_from_spec(spec); spec.loader.exec_module(preset)
original_place = preset.place_imported_objects
original_preflight = preset.preflight_report
original_setup = preset.setup_scene
metadata = {}
casters = []


def import_model(path):
    global metadata
    metadata = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        target.objects = list(metadata['roles'])
    objects = []
    for obj in target.objects:
        if obj:
            bpy.context.scene.collection.objects.link(obj); objects.append(obj)
    return objects


def layer_collection(root, name):
    if root.name == name: return root
    for child in root.children:
        found = layer_collection(child, name)
        if found: return found


def place(objects, args, slope_parent=None):
    original_place(objects, args, slope_parent)
    shadows = bpy.data.collections.new('Anisetron Shadow Casters')
    bpy.context.scene.collection.children.link(shadows)
    for obj in objects:
        role = metadata['roles'][obj.name]
        if role == 'owner-mask':
            preset.unlink_from_all(obj); preset.link_to_collection(obj, 'Colored')
        if role in ('crystal', 'crown'): obj.lightgroup = 'Lights'
        caster = obj.copy()
        caster.name = obj.name + '_shadow_caster'
        caster.location.z += metadata['hover_height']
        shadows.objects.link(caster)
        casters.append(caster)
    for layer in bpy.context.scene.view_layers:
        shadow = layer_collection(layer.layer_collection, shadows.name)
        shadow.exclude = layer.name != 'Shadow'
        shadow.indirect_only = layer.name == 'Shadow'
        for name in ('Normal', 'Colored'):
            coll = layer_collection(layer.layer_collection, name)
            if layer.name == 'Shadow': coll.exclude = True
            elif name == 'Colored' and layer.name == 'Object':
                coll.exclude = False; coll.indirect_only = True


def setup(args, selected_passes, output_dir):
    result = original_setup(args, selected_passes, output_dir)
    scene = bpy.context.scene
    scene.view_layers['Object'].use_pass_emit = True
    layer = scene.view_layers['Object']
    if not any(a.name == 'anisetron_glow_mask' for a in layer.aovs):
        aov = layer.aovs.add(); aov.name = 'anisetron_glow_mask'; aov.type = 'VALUE'
    tree = preset.compositor_tree(scene)
    render = next(n for n in tree.nodes if n.type == 'R_LAYERS' and n.layer == 'Object')
    output = next(n for n in tree.nodes if (n.label or n.name) == 'Light with Alpha')
    # Preset light-group output contains reflected irradiance. This asset's glow
    # is the surface emission pass, with black pixels made transparent explicitly.
    alpha = tree.nodes.new('ShaderNodeMath'); alpha.operation = 'MINIMUM'
    setter = tree.nodes.new('CompositorNodeSetAlpha')
    tree.links.new(render.outputs['anisetron_glow_mask'], alpha.inputs[0])
    tree.links.new(render.outputs['Alpha'], alpha.inputs[1])
    tree.links.new(render.outputs['Emission'], setter.inputs['Image'])
    tree.links.new(alpha.outputs[0], setter.inputs['Alpha'])
    tree.links.new(setter.outputs[0], output.inputs[0])
    return result


def preflight(args, **kwargs):
    scene = bpy.context.scene; reports = []
    meshes = kwargs['imported']
    for frame in range(1, args.directions+1):
        scene.frame_set(frame); bpy.context.view_layer.update()
        report = original_preflight(args, **kwargs)
        worst = 0
        for obj in meshes + casters:
            for corner in obj.bound_box:
                world = obj.matrix_world @ Vector(corner)
                points = [world]
                if obj in casters:
                    # Shadow Lamp=(-32,0,48); its direction is fixed in world space.
                    points.append(Vector((world.x + world.z*32/48, world.y, 0)))
                for point in points:
                    p = world_to_camera_view(scene, scene.camera, point)
                    worst = max(worst, abs(p.x-.5), abs(p.y-.5))
        required = scene.camera.data.ortho_scale*worst/(.5-args.preflight_margin)
        report['framing']['minimum_ortho_scale'] = max(required, report['framing']['minimum_ortho_scale'])
        report['framing']['framing_risk'] = required > scene.camera.data.ortho_scale
        reports.append(report)
    result = max(reports, key=lambda r:r['framing']['minimum_ortho_scale'])
    result['anisetron_preparation'] = metadata
    result['anisetron_muzzle_pixels'] = []
    rotator = bpy.data.objects['Rotation by Frames & Directions']
    for frame in range(1, args.directions+1):
        scene.frame_set(frame); bpy.context.view_layer.update()
        p = world_to_camera_view(scene, scene.camera, rotator.matrix_world @ Vector(metadata['muzzle']))
        pivot = world_to_camera_view(scene, scene.camera, rotator.matrix_world @ Vector((0,0,0)))
        result['anisetron_muzzle_pixels'].append({'direction': frame-1,
            'muzzle': [p.x*args.resolution, (1-p.y)*args.resolution],
            'pivot': [pivot.x*args.resolution, (1-pivot.y)*args.resolution]})
    result['anisetron_sprite_scale'] = 32*scene.camera.data.ortho_scale/args.resolution
    scene.frame_set(1)
    return result


preset.import_model = import_model
preset.place_imported_objects = place
preset.setup_scene = setup
preset.preflight_report = preflight
preset.main()
