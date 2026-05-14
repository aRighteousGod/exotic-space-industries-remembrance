from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector


FOOT_COMPONENT_CENTERS = [
    {"id": "rear-left", "center": [1.6717, 0.38073, 0.159543], "radius_scale": 1.0},
    {"id": "rear-right", "center": [1.704031, -0.317819, 0.156016], "radius_scale": 1.0},
    {"id": "front-left", "center": [-0.412712, 0.914198, 0.201659], "radius_scale": 0.92},
    {"id": "front-right", "center": [-0.324276, -0.969039, 0.14449], "radius_scale": 0.92},
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Project Emerald Apocalypse hover-foot component centers into 64 Factorio render directions."
    )
    parser.add_argument("--preset-blend", default="factorioRenderingPreset_v4.blend")
    parser.add_argument(
        "--render-manifest",
        default="output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/factorio-preset-render-manifest.json",
    )
    parser.add_argument("--out-json", default="output/meshy/emerald-apocalypse-hover-tank/hover-emitter-offsets.json")
    parser.add_argument(
        "--out-lua",
        default="exotic-space-industries-remembrance/lib/emerald-apocalypse-hover-tank-hover-offsets.lua",
    )
    parser.add_argument("--sprite-scale", type=float, default=0.35)
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def normalized_point(center: list[float], manifest: dict) -> Vector:
    normalization = manifest["normalization"]
    bounds = normalization["bounds_before"]
    low = Vector(bounds["min"])
    high = Vector(bounds["max"])
    origin = (low + high) * 0.5
    scale = float(normalization["scale_factor"])
    return (Vector(center) - origin) * scale


def pixel_to_tile(pixel_x: float, pixel_y: float, resolution: int, sprite_scale: float) -> dict[str, float]:
    return {
        "x": round((pixel_x - (resolution * 0.5)) * sprite_scale / 32.0, 4),
        "y": round((pixel_y - (resolution * 0.5)) * sprite_scale / 32.0, 4),
    }


def project_ortho(camera: bpy.types.Object, world: Vector, resolution: int, ortho_scale: float) -> tuple[float, float]:
    camera_local = camera.matrix_world.inverted() @ world
    pixel_x = resolution * (0.5 + (camera_local.x / ortho_scale))
    pixel_y = resolution * (0.5 - (camera_local.y / ortho_scale))
    return pixel_x, pixel_y


def main() -> None:
    args = parse_args()
    preset = Path(args.preset_blend).resolve()
    render_manifest_path = Path(args.render_manifest).resolve()
    manifest = load_manifest(render_manifest_path)
    resolution = int(manifest["scene"]["resolution"][0])
    directions = int(manifest["directions"])
    animation_frames = int(manifest["animation_frames"])
    initial_angle = float(manifest["initial_angle"])
    ortho_scale = float(manifest["ortho_scale"])

    bpy.ops.wm.open_mainfile(filepath=str(preset))
    scene = bpy.context.scene
    scene["frames"] = animation_frames
    scene["dir"] = directions
    scene["factorio_animationFrames"] = animation_frames
    scene["factorio_directions"] = directions
    scene["factorio_oScale"] = ortho_scale
    scene["factorio_tilesize"] = int(manifest["tile_size"])
    camera = scene.camera
    if camera is None or camera.type != "CAMERA":
        raise RuntimeError("Preset camera is missing.")
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100

    rotator = bpy.data.objects.get("Rotation by Frames & Directions")
    if rotator is None:
        raise RuntimeError("Preset rotator 'Rotation by Frames & Directions' is missing.")
    if rotator.animation_data:
        for driver in list(rotator.animation_data.drivers):
            rotator.driver_remove(driver.data_path, driver.array_index)

    normalized_feet = [
        {
            "id": foot["id"],
            "radius_scale": foot["radius_scale"],
            "point": normalized_point(foot["center"], manifest),
        }
        for foot in FOOT_COMPONENT_CENTERS
    ]

    frames = []
    for frame_index in range(directions):
        yaw = math.radians(-initial_angle - (frame_index // animation_frames) * 360.0 / directions)
        rotator.rotation_euler = Euler((0.0, 0.0, yaw), "XYZ")
        bpy.context.view_layer.update()

        offsets = []
        for foot in normalized_feet:
            world = rotator.matrix_world @ foot["point"]
            pixel_x, pixel_y = project_ortho(camera, world, resolution, ortho_scale)
            offset = pixel_to_tile(pixel_x, pixel_y, resolution, args.sprite_scale)
            offsets.append(
                {
                    "id": foot["id"],
                    "pixel": [round(pixel_x, 2), round(pixel_y, 2)],
                    "x": offset["x"],
                    "y": offset["y"],
                    "radius_scale": foot["radius_scale"],
                }
            )
        frames.append({"frame": frame_index + 1, "yaw_degrees": round(math.degrees(yaw), 4), "emitters": offsets})

    payload = {
        "asset": "emerald-apocalypse-hover-tank",
        "source_render_manifest": str(render_manifest_path),
        "preset_blend": str(preset),
        "directions": directions,
        "resolution": resolution,
        "sprite_scale": args.sprite_scale,
        "foot_component_centers": FOOT_COMPONENT_CENTERS,
        "frames": frames,
    }

    out_json = Path(args.out_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    out_lua = Path(args.out_lua)
    out_lua.parent.mkdir(parents=True, exist_ok=True)
    with out_lua.open("w", encoding="utf-8") as handle:
        handle.write("--==============================================================================\n")
        handle.write("-- ESIR FILE MAP\n")
        handle.write("-- owns: generated Emerald Apocalypse hover tank 64-direction hover foot offsets\n")
        handle.write("-- loaded_by: scripts/control/emerald-apocalypse-hover-tank.lua\n")
        handle.write("-- cadence: runtime module load\n")
        handle.write("-- forwarded_events: none\n")
        handle.write("-- storage_roots: none\n")
        handle.write("-- gui_ids: none\n")
        handle.write("-- remote_interfaces: none\n")
        handle.write("-- rebuild_on: approved hover tank render framing or hover foot component picks change\n")
        handle.write("--==============================================================================\n")
        handle.write("\n")
        handle.write("-- Generated by generate_hover_emitter_offsets.py from the approved final render manifest.\n")
        handle.write("-- Do not hand-edit values; regenerate after changing the hover tank render framing or foot picks.\n")
        handle.write("local HOVER_EMITTER_OFFSETS_BY_DIRECTION = {\n")
        for frame in frames:
            handle.write("    {\n")
            for emitter in frame["emitters"]:
                handle.write(
                    "        {x = %.4f, y = %.4f, radius_scale = %.2f},\n"
                    % (emitter["x"], emitter["y"], emitter["radius_scale"])
                )
            handle.write("    },\n")
        handle.write("}\n")
        handle.write("\nreturn HOVER_EMITTER_OFFSETS_BY_DIRECTION\n")


if __name__ == "__main__":
    main()
