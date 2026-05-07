import argparse
import json
import sys
from pathlib import Path

import bpy


BODY_OBJECT_NAME = "ei-sawblade-turret-body"
BLADE_OBJECT_NAME = "ei-sawblade-turret-blade"


def parse_args():
    parser = argparse.ArgumentParser(description="Export Oathbreaker Saw render-role GLBs from the prepared split model.")
    parser.add_argument("--prepared", required=True, help="Prepared GLB containing named body and blade objects.")
    parser.add_argument("--out-dir", required=True, help="Directory for role-specific GLBs.")
    parser.add_argument("--manifest", help="Optional role export manifest path.")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_prepared(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    body = bpy.data.objects.get(BODY_OBJECT_NAME)
    blade = bpy.data.objects.get(BLADE_OBJECT_NAME)
    if body is None or blade is None:
        found = sorted(obj.name for obj in bpy.context.scene.objects if obj.type == "MESH")
        raise RuntimeError(f"Expected {BODY_OBJECT_NAME!r} and {BLADE_OBJECT_NAME!r}; found {found}")
    return body, blade


def export_selection(path, objects):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )


def main():
    args = parse_args()
    prepared = Path(args.prepared).expanduser().resolve()
    out_dir = Path(args.out_dir).expanduser().resolve()
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else out_dir / "role-exports.manifest.json"

    clear_scene()
    body, blade = import_prepared(prepared)

    outputs = {
        "full": out_dir / "ei-sawblade-turret-full.glb",
        "body": out_dir / "ei-sawblade-turret-body-only.glb",
        "blade": out_dir / "ei-sawblade-turret-blade-only.glb",
    }
    export_selection(outputs["full"], [body, blade])
    export_selection(outputs["body"], [body])
    export_selection(outputs["blade"], [blade])

    manifest = {
        "prepared": str(prepared),
        "objects": {
            "body": BODY_OBJECT_NAME,
            "blade": BLADE_OBJECT_NAME,
        },
        "outputs": {key: str(path) for key, path in outputs.items()},
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
