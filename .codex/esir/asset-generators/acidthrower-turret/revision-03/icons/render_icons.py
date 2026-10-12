"""Render complete revision03 model for icons; preserve reviewed model and sprites."""
import importlib.util
from pathlib import Path

import bpy
from mathutils import Matrix

spec = importlib.util.spec_from_file_location(
    "acid_icon_preset",
    Path.cwd() / ".codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py",
)
preset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preset)
old_output = preset.set_file_output_path


def output(node, folder):
    folder.mkdir(parents=True, exist_ok=True)
    if hasattr(node, "directory"):
        node.directory = str(folder)
        node.file_name = ""
    else:
        old_output(node, folder)


def place(objects, args, slope_parent=None):
    rotator = bpy.data.objects["Rotation by Frames & Directions"]
    for obj in objects:
        rest = obj.matrix_world.copy()
        preset.unlink_from_all(obj)
        preset.link_to_collection(obj, "Normal")
        obj.parent = rotator
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = rest


preset.set_file_output_path = output
preset.place_imported_objects = place
preset.main()
