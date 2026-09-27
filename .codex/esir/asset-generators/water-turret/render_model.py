"""Water-turret routing around the shared Factorio preset renderer."""
import sys, importlib.util, os
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parent
REPO=Path.cwd()
path=REPO/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py'
spec=importlib.util.spec_from_file_location('esir_preset',path)
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
original_place=preset.place_imported_objects
def place(objects,args,slope_parent=None):
    matrices={o.name:o.matrix_world.copy() for o in objects}
    original_place(objects,args,slope_parent)
    for obj in objects:
        if obj.name.startswith('force_trim') and os.environ.get('ESIR_WATER_ICON')!='1':
            preset.unlink_from_all(obj);preset.link_to_collection(obj,'Colored')
    def layer_collection(root,name):
        if root.name==name:return root
        for child in root.children:
            found=layer_collection(child,name)
            if found:return found
    for layer in bpy.context.scene.view_layers:
        colored=layer_collection(layer.layer_collection,'Colored')
        if colored and layer.name in ('Object','Shadow'):
            colored.exclude=False;colored.holdout=False;colored.indirect_only=True
    if os.environ.get('ESIR_WATER_ASSEMBLED')=='1':
        for obj in objects:
            if obj.name.startswith(('stationary_','fixed_')):
                obj.parent=None;obj.matrix_world=matrices[obj.name]
preset.place_imported_objects=place
preset.main()
