#!/usr/bin/env python3
"""Dump the local rolling-stock template structure for ESIR train rendering."""

from __future__ import annotations

import json
from pathlib import Path

import bpy


def animation_record(obj: bpy.types.Object) -> dict[str, object]:
    record: dict[str, object] = {"action": None, "fcurves": [], "drivers": []}
    animation_data = obj.animation_data
    if not animation_data:
        return record
    action = animation_data.action
    if action:
        record["action"] = action.name
        fcurves = []
        for fcurve in getattr(action, "fcurves", []):
            fcurves.append(
                {
                    "data_path": fcurve.data_path,
                    "array_index": fcurve.array_index,
                    "keyframes": [
                        [round(point.co[0], 4), round(point.co[1], 6)]
                        for point in fcurve.keyframe_points
                    ],
                }
            )
        record["fcurves"] = fcurves
    drivers = []
    for driver in animation_data.drivers:
        drivers.append(
            {
                "data_path": driver.data_path,
                "array_index": driver.array_index,
                "expression": driver.driver.expression,
            }
        )
    record["drivers"] = drivers
    return record


def main() -> None:
    scene = bpy.context.scene
    data: dict[str, object] = {
        "scene": scene.name,
        "frame_start": scene.frame_start,
        "frame_end": scene.frame_end,
        "render_engine": scene.render.engine,
        "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        "film_transparent": bool(scene.render.film_transparent),
        "view_settings": {
            "view_transform": scene.view_settings.view_transform,
            "look": scene.view_settings.look,
            "exposure": scene.view_settings.exposure,
            "gamma": scene.view_settings.gamma,
        },
        "camera": scene.camera.name if scene.camera else None,
        "collections": [],
        "objects": [],
    }
    for collection in bpy.data.collections:
        data["collections"].append(
            {
                "name": collection.name,
                "objects": [obj.name for obj in collection.objects],
            }
        )
    for obj in bpy.data.objects:
        data["objects"].append(
            {
                "name": obj.name,
                "type": obj.type,
                "parent": obj.parent.name if obj.parent else None,
                "children": [child.name for child in obj.children],
                "location": [round(value, 6) for value in obj.location],
                "rotation_euler": [round(value, 6) for value in obj.rotation_euler],
                "scale": [round(value, 6) for value in obj.scale],
                "dimensions": [round(value, 6) for value in obj.dimensions],
                "data": obj.data.name if getattr(obj, "data", None) else None,
                "animation": animation_record(obj),
            }
        )

    output = Path("output/meshy/nuclear-trains/template-inspection")
    output.mkdir(parents=True, exist_ok=True)
    target = output / "rolling_stock_template_inspection.json"
    target.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"template_inspection={target}")
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
