#!/usr/bin/env python3
"""Spec-driven ESIR asset pipeline orchestrator."""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import html
import json
import os
import shlex
import subprocess
import sys
import statistics
from copy import deepcopy
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat
except ImportError:  # pragma: no cover - reported at runtime.
    Image = None  # type: ignore[assignment]
    ImageChops = None  # type: ignore[assignment]
    ImageDraw = None  # type: ignore[assignment]
    ImageFilter = None  # type: ignore[assignment]
    ImageStat = None  # type: ignore[assignment]


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[4]
SKILLS_ROOT = REPO_ROOT / ".codex" / "skills"
MESHY_SCRIPT = SKILLS_ROOT / "meshy-api" / "scripts" / "meshy_rest.py"
STATIC_RENDER_SCRIPT = SKILLS_ROOT / "meshy-blender-spritesheet" / "scripts" / "render_spritesheet.py"
PRESET_RENDER_SCRIPT = SKILLS_ROOT / "meshy-blender-spritesheet" / "scripts" / "render_factorio_preset.py"
PROCEDURAL_RENDER_SCRIPT = SKILLS_ROOT / "blender-procedural-animation" / "scripts" / "procedural_animation_sheet.py"
EXPORT_SCRIPT = SKILLS_ROOT / "esir-factorio-asset-export" / "scripts" / "export_factorio_asset.py"
DEFAULT_BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")
ALL_STEPS = ["meshy", "render_static", "render_procedural", "render_preset", "export", "promotion", "qa"]
DEFAULT_ALL_STEPS = ["meshy", "render_static", "render_procedural", "render_preset", "export", "qa"]


class PipelineError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run or plan a reproducible ESIR asset pipeline.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    sample = subparsers.add_parser("sample", help="Write a maximum-option sample spec.")
    sample.add_argument("--asset-name", required=True)
    sample.add_argument("--output", required=True)
    sample.add_argument("--kind", default="machine")
    sample.add_argument("--force", action="store_true")

    plan = subparsers.add_parser("plan", help="Print the resolved plan without executing commands.")
    plan.add_argument("--spec", required=True)
    plan.add_argument("--steps", default="all", help="Comma-separated steps or all.")
    plan.add_argument("--dossier", help="Optional dossier path.")

    run = subparsers.add_parser("run", help="Run selected pipeline steps.")
    run.add_argument("--spec", required=True)
    run.add_argument("--steps", default="all", help="Comma-separated steps or all.")
    run.add_argument("--dry-run", action="store_true", help="Print and record commands without executing.")
    run.add_argument("--continue-on-error", action="store_true")
    run.add_argument("--dossier", help="Optional dossier path.")

    qa = subparsers.add_parser("qa", help="Run only QA checks from a spec.")
    qa.add_argument("--spec", required=True)
    qa.add_argument("--dossier", help="Optional dossier path.")

    estimate = subparsers.add_parser("estimate", help="Estimate render weight without running Blender.")
    estimate.add_argument("--spec", required=True)
    estimate.add_argument("--steps", default="all", help="Accepted for consistency; render estimates use enabled render sections.")

    batch = subparsers.add_parser("batch", help="Run or plan variants listed in one spec.")
    batch.add_argument("--spec", required=True)
    batch.add_argument("--steps", default="all", help="Comma-separated steps or all.")
    batch.add_argument("--dry-run", action="store_true")
    batch.add_argument("--continue-on-error", action="store_true")
    batch.add_argument("--summary", help="Optional batch summary JSON path.")

    registry = subparsers.add_parser("registry", help="Render or update the staged asset registry review queue.")
    registry.add_argument("--path", default="output/meshy/asset-index.json")
    registry.add_argument("--html", help="Optional HTML browser output path.")
    registry.add_argument("--set-status", nargs=2, metavar=("ENTRY", "STATUS"), help="Set manual.status for one registry entry key/path.")
    registry.add_argument("--notes", help="Manual notes to store with --set-status.")
    registry.add_argument("--tag", action="append", default=[], help="Manual tag to append with --set-status.")

    return parser.parse_args()


def load_spec(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise PipelineError(f"Spec not found: {path}")
    raw = path.read_text(encoding="utf-8-sig")
    if path.suffix.lower() == ".json":
        value = json.loads(raw)
    elif path.suffix.lower() in {".yaml", ".yml"}:
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise PipelineError("YAML specs require PyYAML. Use JSON or install PyYAML.") from exc
        value = yaml.safe_load(raw)
    else:
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise PipelineError("Unknown spec extension. Use .json, or .yaml when PyYAML is installed.") from exc
    if not isinstance(value, dict):
        raise PipelineError("Spec root must be an object.")
    return value


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def sample_spec(asset_name: str, kind: str) -> dict[str, Any]:
    output_root = f"output/meshy/{asset_name}"
    return {
        "asset_name": asset_name,
        "kind": kind,
        "output_root": output_root,
        "model_path": f"{output_root}/model.glb",
        "model_glob": f"{output_root}/meshy-task/*.glb",
        "blender": {
            "exe": str(DEFAULT_BLENDER),
        },
        "factorio_render_preset": {
            "blend": "factorioRenderingPreset_v4.blend",
            "render_bundle": "Render.zip",
            "notes": "Use render_preset for the local .blend, render_* factorio_preset_defaults for scripted drafts, or export.mode=render-bundle to stage preset output.",
        },
        "meshy": {
            "enabled": False,
            "workflow": "text-3d-preview",
            "prompt": "black sigil industrial threshold machine, readable Factorio silhouette",
            "negative_prompt": "tiny text, soft blob, unreadable silhouette, flimsy details",
            "art_style": "realistic",
            "target_format": "glb",
            "should_remesh": True,
            "target_polycount": 50000,
            "poll": True,
            "download": True,
            "output_dir": "{output_root}/meshy-task",
        },
        "render_static": {
            "enabled": True,
            "input": "{model_path}",
            "test_cube": True,
            "output_sheet": "{output_root}/renders/{asset_name}-static.png",
            "directions": 8,
            "frame_size": 384,
            "columns": 8,
            "padding": 0,
            "elevation": 60,
            "yaw_offset": 45,
            "ortho_scale": 2.0,
            "auto_ortho_scale": True,
            "auto_ortho_step": 1.12,
            "auto_ortho_max": 4.5,
            "min_alpha_margin": 16,
            "fail_alpha_margin": True,
            "exposure": 0.7,
            "world_strength": 0.05,
            "key_energy": 900,
            "fill_energy": 220,
            "engine": "eevee",
            "samples": 64,
            "factorio_preset_defaults": False,
        },
        "render_procedural": {
            "enabled": True,
            "input": "{model_path}",
            "test_asset": "machine",
            "preset": "machine",
            "output_sheet": "{output_root}/renders/{asset_name}-animation.png",
            "shadow_sheet": "{output_root}/renders/{asset_name}-animation-shadow.png",
            "frames": 16,
            "directions": 1,
            "columns": 4,
            "frame_size": 256,
            "ortho_scale": 2.8,
            "auto_ortho_scale": True,
            "auto_ortho_step": 1.12,
            "auto_ortho_max": 8.0,
            "min_alpha_margin": 16,
            "fail_alpha_margin": True,
            "direction_mode": "rotate-object",
            "shadow_offset": "18,12",
            "shadow_alpha": 0.42,
            "engine": "eevee",
            "samples": 64,
            "factorio_preset_defaults": False,
        },
        "render_preset": {
            "enabled": False,
            "preset_blend": "{factorio_render_preset.blend}",
            "input": "{model_path}",
            "test_cube": True,
            "asset_name": "{asset_name}",
            "output_dir": "{output_root}/Render",
            "manifest": "{output_root}/Render/factorio-preset-render-manifest.json",
            "frames": 64,
            "directions": 4,
            "animation_frames": 16,
            "ortho_scale": 6,
            "tile_size": 64,
            "passes": ["object", "shadow", "light-alpha-reduced", "light-alpha", "mask"],
            "quality": "smoke",
            "pack_sheets": True,
            "grid": "8x8",
            "preflight_only": False,
            "preflight_margin": 0.12,
            "auto_ortho_scale": True,
            "auto_ortho_step": 1.04,
            "auto_ortho_max": 12.0,
            "fail_framing_risk": True,
            "material_report": True,
            "warn_alpha_materials": True,
            "footprint_tiles": "3x3",
            "auto_prep": False,
            "prep_origin_mode": "center",
            "prep_target_size": 2.0,
            "prep_alpha_mode": "report",
            "prep_remove_imported_cameras": False,
            "prep_delete_empty_meshes": False,
            "prep_apply_scale": False,
        },
        "export": {
            "enabled": True,
            "mode": "machine",
            "sheet": "{render_static.output_sheet}",
            "render_manifest": "{render_static.manifest}",
            "working_sheet": "{render_procedural.output_sheet}",
            "working_manifest": "{render_procedural.manifest}",
            "working_shadow_sheet": "{render_procedural.shadow_sheet}",
            "scale": 0.35,
            "shift": "0,-0.2",
            "animation_speed": 0.6,
            "output_dir": "{output_root}/factorio-export",
            "pack_raw_frames": False,
            "emit_water_reflection": False,
        },
        "promotion": {
            "enabled": False,
            "manifest": "{export.output_dir}/{asset_name}.factorio-asset-manifest.json",
            "copy_assets": False,
            "graphics_destination": "exotic-space-industries-remembrance/graphics/entity/{asset_name}",
            "apply_prototype": False,
            "prototype_file": "",
            "prototype_type": "assembling-machine" if kind == "machine" else "{kind}",
            "prototype_name": "{asset_name}",
            "field": "graphics_set",
            "execute": False,
            "expected_asset_count": None,
            "require_prototype_identity": True,
            "prototype_integration": "marker",
        },
        "style": {
            "enabled": True,
            "target_paths": [
                "{render_static.output_sheet}",
                "{render_procedural.output_sheet}",
            ],
            "baseline_globs": [
                "exotic-space-industries-remembrance/graphics/**/*.png",
            ],
            "max_baseline_images": 120,
            "output": "{output_root}/style/style-report.json",
            "warn_luma_delta": 45,
            "warn_saturation_delta": 0.35,
            "warn_edge_density_delta": 0.12,
        },
        "regression": {
            "enabled": False,
            "baseline": "{output_root}/baseline/style-report.json",
            "output": "{output_root}/qa/regression-report.json",
            "warn_luma_delta": 30,
            "warn_alpha_coverage_delta": 0.18,
            "fail_dimension_change": True,
        },
        "registry": {
            "enabled": True,
            "path": "output/meshy/asset-index.json",
        },
        "gallery": {
            "enabled": True,
            "output": "{output_root}/approval-gallery.html",
            "include_snippet": True,
        },
        "variants": [
            {
                "name": "smoke",
                "overrides": {
                    "output_root": f"{output_root}/variants/smoke",
                    "render_preset": {"quality": "smoke", "samples": 16},
                },
            }
        ],
        "qa": {
            "enabled": True,
            "require_alpha": True,
            "require_shadow_lower_right": True,
            "contact_sheet_dir": "{output_root}/qa",
            "min_alpha_pixels": 8,
            "check_paths": [
                "{render_static.output_sheet}",
                "{render_procedural.output_sheet}",
                "{render_procedural.shadow_sheet}",
                "{export.output_dir}/{asset_name}.preview.png",
            ],
        },
    }


def parse_steps(raw: str) -> list[str]:
    if raw.strip().lower() == "all":
        return list(DEFAULT_ALL_STEPS)
    steps = [part.strip() for part in raw.split(",") if part.strip()]
    unknown = [step for step in steps if step not in ALL_STEPS]
    if unknown:
        raise PipelineError(f"Unknown step(s): {', '.join(unknown)}")
    return steps


def deep_get(value: dict[str, Any], dotted: str) -> Any:
    current: Any = value
    for part in dotted.split("."):
        if not isinstance(current, dict) or part not in current:
            raise KeyError(dotted)
        current = current[part]
    return current


def format_value(value: Any, context: dict[str, Any]) -> Any:
    if isinstance(value, str):
        out = value
        for _ in range(8):
            changed = False
            start = out.find("{")
            while start != -1:
                end = out.find("}", start + 1)
                if end == -1:
                    break
                key = out[start + 1 : end]
                try:
                    replacement = str(deep_get(context, key) if "." in key else context[key])
                except KeyError:
                    replacement = out[start : end + 1]
                else:
                    changed = True
                out = out[:start] + replacement + out[end + 1 :]
                start = out.find("{", start + len(replacement))
            if not changed:
                break
        return out
    if isinstance(value, list):
        return [format_value(item, context) for item in value]
    if isinstance(value, dict):
        return {key: format_value(item, context) for key, item in value.items()}
    return value


def defaulted_spec(spec: dict[str, Any]) -> dict[str, Any]:
    if "asset_name" not in spec:
        raise PipelineError("Spec requires asset_name.")
    result = deepcopy(spec)
    result.setdefault("kind", "machine")
    result.setdefault("output_root", f"output/meshy/{result['asset_name']}")
    result.setdefault("model_path", f"{result['output_root']}/model.glb")
    result.setdefault("model_glob", f"{result['output_root']}/**/*.glb")
    result.setdefault("blender", {})
    result["blender"].setdefault("exe", str(DEFAULT_BLENDER))
    for section in ALL_STEPS:
        if section not in result:
            result[section] = {"enabled": False}
    result["qa"].setdefault("enabled", True)
    return result


def resolve_spec(spec: dict[str, Any]) -> dict[str, Any]:
    result = defaulted_spec(spec)
    output_root = Path(result["output_root"])
    result.setdefault("dossier_path", str(output_root / "asset.pipeline-dossier.json"))
    changed = True
    for _ in range(8):
        if not changed:
            break
        before = json.dumps(result, sort_keys=True)
        result = format_value(result, result)
        after = json.dumps(result, sort_keys=True)
        changed = before != after

    if "render_static" in result:
        render_static = result["render_static"]
        if isinstance(render_static, dict):
            render_static.setdefault("manifest", str(Path(render_static.get("output_sheet", output_root / "renders/static.png")).with_suffix(".manifest.json")))
    if "render_procedural" in result:
        render_procedural = result["render_procedural"]
        if isinstance(render_procedural, dict):
            render_procedural.setdefault("manifest", str(Path(render_procedural.get("output_sheet", output_root / "renders/animation.png")).with_suffix(".manifest.json")))
    if "render_preset" in result:
        render_preset = result["render_preset"]
        if isinstance(render_preset, dict):
            render_preset.setdefault("output_dir", str(output_root / "Render"))
            render_preset.setdefault("manifest", str(Path(render_preset["output_dir"]) / "factorio-preset-render-manifest.json"))
    if "export" in result:
        export = result["export"]
        if isinstance(export, dict):
            export.setdefault("output_dir", str(output_root / "factorio-export"))
            export.setdefault("manifest", str(Path(export["output_dir"]) / f"{result['asset_name']}.factorio-asset-manifest.json"))
    if "style" in result:
        style = result["style"]
        if isinstance(style, dict):
            style.setdefault("output", str(output_root / "style" / "style-report.json"))
    if "regression" in result:
        regression = result["regression"]
        if isinstance(regression, dict):
            regression.setdefault("output", str(output_root / "qa" / "regression-report.json"))
    if "gallery" in result:
        gallery = result["gallery"]
        if isinstance(gallery, dict):
            gallery.setdefault("output", str(output_root / "approval-gallery.html"))
    changed = True
    for _ in range(8):
        if not changed:
            break
        before = json.dumps(result, sort_keys=True)
        result = format_value(result, result)
        after = json.dumps(result, sort_keys=True)
        changed = before != after
    return result


def as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    return bool(value)


def append_flag(command: list[str], flag: str, value: Any = True) -> None:
    if value is None or value is False:
        return
    command.append(flag)
    if value is not True:
        command.append(str(value))


def python_cmd(script: Path) -> list[str]:
    return [sys.executable, str(script)]


def blender_cmd(spec: dict[str, Any], script: Path) -> list[str]:
    blender_exe = Path(str(spec.get("blender", {}).get("exe", DEFAULT_BLENDER)))
    return [str(blender_exe), "--background", "--python", str(script), "--"]


def existing_or_glob(path: str, pattern: str | None) -> str:
    candidate = Path(path)
    if candidate.exists():
        return str(candidate)
    if pattern:
        matches = sorted(glob.glob(pattern, recursive=True))
        if matches:
            return matches[-1]
    return path


def build_meshy_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("meshy", {})
    if not as_bool(section.get("enabled")):
        return None
    if section.get("args"):
        return python_cmd(MESHY_SCRIPT) + [str(arg) for arg in section["args"]]

    workflow = section.get("workflow", "text-3d-preview")
    command = python_cmd(MESHY_SCRIPT) + [workflow]
    if workflow == "text-3d-preview":
        append_flag(command, "--prompt", section.get("prompt"))
        append_flag(command, "--ai-model", section.get("ai_model"))
        append_flag(command, "--negative-prompt", section.get("negative_prompt"))
        append_flag(command, "--art-style", section.get("art_style"))
        append_flag(command, "--should-remesh", section.get("should_remesh"))
        append_flag(command, "--target-polycount", section.get("target_polycount"))
    elif workflow == "image-3d":
        append_flag(command, "--image-url", section.get("image_url"))
        append_flag(command, "--enable-pbr", section.get("enable_pbr"))
        append_flag(command, "--should-remesh", section.get("should_remesh"))
        append_flag(command, "--should-texture", section.get("should_texture"))
        append_flag(command, "--pose-mode", section.get("pose_mode"))
        append_flag(command, "--target-polycount", section.get("target_polycount"))
    elif workflow == "multi-image-3d":
        for url in section.get("image_urls", []):
            append_flag(command, "--image-url", url)
        append_flag(command, "--enable-pbr", section.get("enable_pbr"))
        append_flag(command, "--should-remesh", section.get("should_remesh"))
        append_flag(command, "--should-texture", section.get("should_texture"))
        append_flag(command, "--target-polycount", section.get("target_polycount"))
    else:
        raise PipelineError(f"Use meshy.args for unsupported simplified workflow: {workflow}")

    append_flag(command, "--target-format", section.get("target_format"))
    append_flag(command, "--format", section.get("format"))
    append_flag(command, "--poll", section.get("poll"))
    append_flag(command, "--stream", section.get("stream"))
    append_flag(command, "--download", section.get("download"))
    append_flag(command, "--output-dir", section.get("output_dir"))
    append_flag(command, "--interval", section.get("interval"))
    append_flag(command, "--timeout", section.get("timeout"))
    if section.get("dry_run"):
        command.append("--dry-run")
    return command


def build_static_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("render_static", {})
    if not as_bool(section.get("enabled")):
        return None
    command = blender_cmd(spec, STATIC_RENDER_SCRIPT)
    append_flag(command, "--base-dir", ".")
    if section.get("test_cube"):
        command.append("--test-cube")
    else:
        input_path = existing_or_glob(section.get("input", spec.get("model_path", "")), spec.get("model_glob"))
        append_flag(command, "--input", input_path)
    for key, flag in [
        ("output_sheet", "--output-sheet"),
        ("frames_dir", "--frames-dir"),
        ("manifest", "--manifest"),
        ("directions", "--directions"),
        ("frame_size", "--frame-size"),
        ("columns", "--columns"),
        ("padding", "--padding"),
        ("elevation", "--elevation"),
        ("yaw_offset", "--yaw-offset"),
        ("ortho_scale", "--ortho-scale"),
        ("resolution_scale", "--resolution-scale"),
        ("engine", "--engine"),
        ("samples", "--samples"),
        ("exposure", "--exposure"),
        ("gamma", "--gamma"),
        ("world_strength", "--world-strength"),
        ("key_energy", "--key-energy"),
        ("fill_energy", "--fill-energy"),
        ("min_alpha_margin", "--min-alpha-margin"),
        ("auto_ortho_step", "--auto-ortho-step"),
        ("auto_ortho_max", "--auto-ortho-max"),
        ("factorio_preset_defaults", "--factorio-preset-defaults"),
        ("save_blend", "--save-blend"),
    ]:
        append_flag(command, flag, section.get(key))
    if section.get("no_normalize"):
        command.append("--no-normalize")
    if "auto_ortho_scale" in section:
        command.append("--auto-ortho-scale" if as_bool(section.get("auto_ortho_scale")) else "--no-auto-ortho-scale")
    if section.get("fail_alpha_margin"):
        command.append("--fail-alpha-margin")
    return command


def build_procedural_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("render_procedural", {})
    if not as_bool(section.get("enabled")):
        return None
    command = blender_cmd(spec, PROCEDURAL_RENDER_SCRIPT)
    append_flag(command, "--base-dir", ".")
    if section.get("test_asset"):
        append_flag(command, "--test-asset", section.get("test_asset"))
    else:
        input_path = existing_or_glob(section.get("input", spec.get("model_path", "")), spec.get("model_glob"))
        append_flag(command, "--input", input_path)
    for key, flag in [
        ("output_sheet", "--output-sheet"),
        ("frames_dir", "--frames-dir"),
        ("manifest", "--manifest"),
        ("save_blend", "--save-blend"),
        ("preset", "--preset"),
        ("frames", "--frames"),
        ("directions", "--directions"),
        ("direction_mode", "--direction-mode"),
        ("columns", "--columns"),
        ("padding", "--padding"),
        ("frame_size", "--frame-size"),
        ("elevation", "--elevation"),
        ("yaw_offset", "--yaw-offset"),
        ("ortho_scale", "--ortho-scale"),
        ("min_alpha_margin", "--min-alpha-margin"),
        ("auto_ortho_step", "--auto-ortho-step"),
        ("auto_ortho_max", "--auto-ortho-max"),
        ("resolution_scale", "--resolution-scale"),
        ("engine", "--engine"),
        ("samples", "--samples"),
        ("factorio_preset_defaults", "--factorio-preset-defaults"),
        ("seed", "--seed"),
        ("amplitude", "--amplitude"),
        ("spin_turns", "--spin-turns"),
        ("orbit_radius", "--orbit-radius"),
        ("key_energy", "--key-energy"),
        ("fill_energy", "--fill-energy"),
        ("shadow_sheet", "--shadow-sheet"),
        ("shadow_offset", "--shadow-offset"),
        ("shadow_alpha", "--shadow-alpha"),
    ]:
        append_flag(command, flag, section.get(key))
    if section.get("no_normalize"):
        command.append("--no-normalize")
    if "auto_ortho_scale" in section:
        command.append("--auto-ortho-scale" if as_bool(section.get("auto_ortho_scale")) else "--no-auto-ortho-scale")
    if section.get("fail_alpha_margin"):
        command.append("--fail-alpha-margin")
    return command


def csv_option(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, list):
        return ",".join(str(item) for item in value)
    return str(value)


def build_preset_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("render_preset", {})
    if not as_bool(section.get("enabled")):
        return None
    command = blender_cmd(spec, PRESET_RENDER_SCRIPT)
    append_flag(command, "--base-dir", ".")
    if section.get("test_cube"):
        command.append("--test-cube")
    else:
        input_path = existing_or_glob(section.get("input", spec.get("model_path", "")), spec.get("model_glob"))
        append_flag(command, "--input", input_path)
    for key, flag in [
        ("preset_blend", "--preset-blend"),
        ("output_dir", "--output-dir"),
        ("manifest", "--manifest"),
        ("quality", "--quality"),
        ("samples", "--samples"),
        ("frames", "--frames"),
        ("directions", "--directions"),
        ("animation_frames", "--animation-frames"),
        ("unit_directions", "--unit-directions"),
        ("initial_angle", "--initial-angle"),
        ("ortho_scale", "--ortho-scale"),
        ("tile_size", "--tile-size"),
        ("resolution", "--resolution"),
        ("grid", "--grid"),
        ("lights", "--lights"),
        ("preflight_margin", "--preflight-margin"),
        ("auto_ortho_step", "--auto-ortho-step"),
        ("auto_ortho_max", "--auto-ortho-max"),
        ("require_light_group", "--require-light-group"),
        ("footprint_tiles", "--footprint-tiles"),
        ("prep_origin_mode", "--prep-origin-mode"),
        ("prep_target_size", "--prep-target-size"),
        ("prep_alpha_mode", "--prep-alpha-mode"),
        ("save_blend", "--save-blend"),
    ]:
        append_flag(command, flag, section.get(key))
    append_flag(command, "--asset-name", section.get("asset_name", spec["asset_name"]))
    append_flag(command, "--passes", csv_option(section.get("passes")))
    if section.get("pack_sheets"):
        command.append("--pack-sheets")
    if section.get("keep_ground_dirt"):
        command.append("--keep-ground-dirt")
    if section.get("keep_pipe"):
        command.append("--keep-pipe")
    if section.get("no_parent_to_rotation"):
        command.append("--no-parent-to-rotation")
    if section.get("no_normalize"):
        command.append("--no-normalize")
    if section.get("dry_run"):
        command.append("--dry-run")
    if section.get("preflight_only"):
        command.append("--preflight-only")
    if section.get("fail_framing_risk"):
        command.append("--fail-framing-risk")
    if "auto_ortho_scale" in section:
        command.append("--auto-ortho-scale" if as_bool(section.get("auto_ortho_scale")) else "--no-auto-ortho-scale")
    if section.get("fail_missing_light_group"):
        command.append("--fail-missing-light-group")
    if section.get("material_report"):
        command.append("--material-report")
    if section.get("warn_alpha_materials"):
        command.append("--warn-alpha-materials")
    if section.get("fail_alpha_risk"):
        command.append("--fail-alpha-risk")
    if section.get("auto_prep"):
        command.append("--auto-prep")
    if section.get("prep_remove_imported_cameras"):
        command.append("--prep-remove-imported-cameras")
    if section.get("prep_delete_empty_meshes"):
        command.append("--prep-delete-empty-meshes")
    if section.get("prep_apply_scale"):
        command.append("--prep-apply-scale")
    return command


def build_export_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("export", {})
    if not as_bool(section.get("enabled")):
        return None
    mode = section.get("mode") or ("machine" if spec.get("kind") == "machine" else "entity")
    export_mode = "render-bundle" if mode in {"bundle", "render_bundle", "render-bundle"} else mode
    command = python_cmd(EXPORT_SCRIPT) + [export_mode, "--asset-name", spec["asset_name"]]
    common_keys = [
        ("output_dir", "--output-dir"),
        ("filename_root", "--filename-root"),
        ("factorio_var", "--factorio-var"),
        ("prototype_kind", "--prototype-kind"),
        ("snippet_template", "--snippet-template"),
        ("target_prototype_type", "--target-prototype-type"),
        ("target_prototype_name", "--target-prototype-name"),
        ("target_field", "--target-field"),
    ]
    for key, flag in common_keys:
        append_flag(command, flag, section.get(key))
    if export_mode in {"entity", "machine"}:
        for key, flag in [
            ("sheet", "--sheet"),
            ("render_manifest", "--render-manifest"),
            ("frame_width", "--frame-width"),
            ("frame_height", "--frame-height"),
            ("line_length", "--line-length"),
            ("frame_count", "--frame-count"),
            ("scale", "--scale"),
            ("shift", "--shift"),
            ("shadow_sheet", "--shadow-sheet"),
            ("shadow_scale", "--shadow-scale"),
            ("shadow_shift", "--shadow-shift"),
        ]:
            append_flag(command, flag, section.get(key))
        if export_mode == "entity":
            append_flag(command, "--direction-count", section.get("direction_count"))
        if export_mode == "machine":
            for key, flag in [
                ("working_sheet", "--working-sheet"),
                ("working_manifest", "--working-manifest"),
                ("working_frame_width", "--working-frame-width"),
                ("working_frame_height", "--working-frame-height"),
                ("working_frame_count", "--working-frame-count"),
                ("working_line_length", "--working-line-length"),
                ("working_scale", "--working-scale"),
                ("working_shift", "--working-shift"),
                ("working_shadow_sheet", "--working-shadow-sheet"),
                ("working_shadow_scale", "--working-shadow-scale"),
                ("working_shadow_shift", "--working-shadow-shift"),
                ("animation_speed", "--animation-speed"),
                ("run_mode", "--run-mode"),
            ]:
                append_flag(command, flag, section.get(key))
    elif export_mode == "icon":
        for key, flag in [
            ("source", "--source"),
            ("canvas_size", "--canvas-size"),
            ("fit_size", "--fit-size"),
            ("mip_sizes", "--mip-sizes"),
        ]:
            append_flag(command, flag, section.get(key))
        if section.get("allow_existing_strip"):
            command.append("--allow-existing-strip")
    elif export_mode == "render-bundle":
        bundle_value = section.get("bundle") or spec.get("render_preset", {}).get("output_dir")
        append_flag(command, "--bundle", bundle_value)
        append_flag(command, "--preset-manifest", section.get("preset_manifest") or spec.get("render_preset", {}).get("manifest"))
        for key, flag in [
            ("prototype_mode", "--prototype-mode"),
            ("frame_width", "--frame-width"),
            ("frame_height", "--frame-height"),
            ("line_length", "--line-length"),
            ("frame_count", "--frame-count"),
            ("direction_count", "--direction-count"),
            ("scale", "--scale"),
            ("shift", "--shift"),
            ("shadow_scale", "--shadow-scale"),
            ("shadow_shift", "--shadow-shift"),
            ("animation_speed", "--animation-speed"),
            ("run_mode", "--run-mode"),
            ("light_layer", "--light-layer"),
            ("light_source", "--light-source"),
            ("grid", "--grid"),
            ("sheet_output_dir", "--sheet-output-dir"),
            ("black_to_transparent", "--black-to-transparent"),
            ("water_reflection_placement", "--water-reflection-placement"),
            ("water_reflection_scale", "--water-reflection-scale"),
            ("water_reflection_shift", "--water-reflection-shift"),
            ("water_reflection_priority", "--water-reflection-priority"),
        ]:
            append_flag(command, flag, section.get(key))
        if section.get("allow_opaque_light_layer"):
            command.append("--allow-opaque-light-layer")
        if section.get("pack_raw_frames"):
            command.append("--pack-raw-frames")
        if section.get("emit_water_reflection"):
            command.append("--emit-water-reflection")
    else:
        raise PipelineError(f"Unsupported export mode: {mode}")
    return command


def build_promotion_command(spec: dict[str, Any]) -> list[str] | None:
    section = spec.get("promotion", {})
    if not as_bool(section.get("enabled")):
        return None
    manifest = section.get("manifest") or spec.get("export", {}).get("manifest")
    if not manifest:
        manifest = f"{spec.get('export', {}).get('output_dir', spec.get('output_root'))}/{spec['asset_name']}.factorio-asset-manifest.json"
    command = python_cmd(EXPORT_SCRIPT) + ["promote", "--manifest", str(manifest)]
    for key, flag in [
        ("graphics_destination", "--graphics-destination"),
        ("prototype_file", "--prototype-file"),
        ("prototype_type", "--prototype-type"),
        ("prototype_name", "--prototype-name"),
        ("field", "--field"),
        ("plan_output", "--plan-output"),
        ("expected_asset_count", "--expected-asset-count"),
    ]:
        append_flag(command, flag, section.get(key))
    if section.get("copy_assets"):
        command.append("--copy-assets")
    if section.get("apply_prototype"):
        command.append("--apply-prototype")
    if section.get("execute"):
        command.append("--execute")
    if section.get("require_prototype_identity"):
        command.append("--require-prototype-identity")
    append_flag(command, "--prototype-integration", section.get("prototype_integration"))
    return command


def command_for_step(step: str, spec: dict[str, Any]) -> list[str] | None:
    if step == "meshy":
        return build_meshy_command(spec)
    if step == "render_static":
        return build_static_command(spec)
    if step == "render_procedural":
        return build_procedural_command(spec)
    if step == "render_preset":
        return build_preset_command(spec)
    if step == "export":
        return build_export_command(spec)
    if step == "promotion":
        return build_promotion_command(spec)
    if step == "qa":
        return None
    raise PipelineError(f"Unknown step: {step}")


def shell_join(command: list[str]) -> str:
    return " ".join(shlex.quote(part) for part in command)


def run_command(command: list[str], dry_run: bool) -> dict[str, Any]:
    record: dict[str, Any] = {
        "command": command,
        "display": shell_join(command),
        "dry_run": dry_run,
    }
    if dry_run:
        record["returncode"] = None
        return record
    started = dt.datetime.now(dt.UTC)
    process = subprocess.run(
        command,
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    finished = dt.datetime.now(dt.UTC)
    output = process.stdout or ""
    record.update(
        {
            "returncode": process.returncode,
            "started_at_utc": started.isoformat(),
            "finished_at_utc": finished.isoformat(),
            "output_tail": output[-6000:],
        }
    )
    return record


def count_csv(value: Any, default: int = 1) -> int:
    if isinstance(value, list):
        return len([item for item in value if str(item).strip()]) or default
    if isinstance(value, str):
        return len([item for item in value.split(",") if item.strip()]) or default
    return default


def render_cost_estimate(spec: dict[str, Any]) -> dict[str, Any]:
    estimates: list[dict[str, Any]] = []

    static = spec.get("render_static", {})
    if isinstance(static, dict) and as_bool(static.get("enabled")):
        frame_size = int(static.get("frame_size") or 256)
        directions = int(static.get("directions") or 1)
        samples = int(static.get("samples") or (256 if static.get("engine") == "cycles" else 64))
        estimates.append(
            {
                "step": "render_static",
                "frames": directions,
                "passes": 1,
                "resolution": [frame_size, frame_size],
                "samples": samples,
                "megapixel_samples": round(directions * frame_size * frame_size * samples / 1_000_000, 2),
            }
        )

    procedural = spec.get("render_procedural", {})
    if isinstance(procedural, dict) and as_bool(procedural.get("enabled")):
        frame_size = int(procedural.get("frame_size") or 256)
        frames = int(procedural.get("frames") or 1) * int(procedural.get("directions") or 1)
        samples = int(procedural.get("samples") or (256 if procedural.get("engine") == "cycles" else 64))
        passes = 2 if procedural.get("shadow_sheet") else 1
        estimates.append(
            {
                "step": "render_procedural",
                "frames": frames,
                "passes": passes,
                "resolution": [frame_size, frame_size],
                "samples": samples,
                "megapixel_samples": round(frames * passes * frame_size * frame_size * samples / 1_000_000, 2),
            }
        )

    preset = spec.get("render_preset", {})
    if isinstance(preset, dict) and as_bool(preset.get("enabled")):
        frames = int(preset.get("frames") or 64)
        pass_count = count_csv(preset.get("passes"), default=5)
        tile_size = int(preset.get("tile_size") or 64)
        resolution = int(preset.get("resolution") or round(float(preset.get("ortho_scale") or 6) * tile_size))
        samples = int(preset.get("samples") or (256 if preset.get("quality") == "final" else 16))
        estimates.append(
            {
                "step": "render_preset",
                "frames": frames,
                "passes": pass_count,
                "resolution": [resolution, resolution],
                "samples": samples,
                "quality": preset.get("quality", "smoke"),
                "preflight_only": as_bool(preset.get("preflight_only")),
                "megapixel_samples": round(frames * pass_count * resolution * resolution * samples / 1_000_000, 2),
            }
        )

    total = round(sum(float(item["megapixel_samples"]) for item in estimates), 2)
    band = "low"
    if total > 2000:
        band = "high"
    elif total > 450:
        band = "medium"
    return {"items": estimates, "total_megapixel_samples": total, "cost_band": band}


def alpha_report(path: Path) -> dict[str, Any]:
    if Image is None:
        raise PipelineError("Pillow is required for QA image checks.")
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        extrema = alpha.getextrema()
        alpha_pixels = 0
        if bbox:
            px = alpha.load()
            sum_x = 0
            sum_y = 0
            for y in range(bbox[1], bbox[3]):
                for x in range(bbox[0], bbox[2]):
                    if px[x, y]:
                        alpha_pixels += 1
                        sum_x += x
                        sum_y += y
            centroid = [sum_x / alpha_pixels, sum_y / alpha_pixels] if alpha_pixels else None
            margins = {
                "left": bbox[0],
                "top": bbox[1],
                "right": image.width - bbox[2],
                "bottom": image.height - bbox[3],
            }
            edge_touch = any(value <= 1 for value in margins.values())
        else:
            centroid = None
            margins = None
            edge_touch = False
        return {
            "path": str(path),
            "exists": True,
            "width": image.width,
            "height": image.height,
            "mode": "RGBA",
            "alpha_bbox": bbox,
            "alpha_extrema": extrema,
            "alpha_pixels": alpha_pixels,
            "alpha_centroid": centroid,
            "alpha_margins": margins,
            "edge_touch": edge_touch,
        }


def sha256_file(path: Path) -> str:
    import hashlib

    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def style_metrics(path: Path) -> dict[str, Any]:
    if Image is None or ImageStat is None or ImageFilter is None:
        raise PipelineError("Pillow is required for style analysis.")
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        rgba = image.crop(bbox) if bbox else image
        rgb = rgba.convert("RGB")
        hsv = rgb.convert("HSV")
        gray = rgb.convert("L")
        stat_l = ImageStat.Stat(gray)
        stat_hsv = ImageStat.Stat(hsv)
        edges = gray.filter(ImageFilter.FIND_EDGES)
        edge_mean = ImageStat.Stat(edges).mean[0] / 255.0
        alpha_pixels = 0
        opaque_pixels = 0
        soft_pixels = 0
        for value in alpha.getdata():
            if value:
                alpha_pixels += 1
            if value >= 250:
                opaque_pixels += 1
            if 0 < value < 250:
                soft_pixels += 1
        total = image.width * image.height
        return {
            "path": str(path),
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
            "width": image.width,
            "height": image.height,
            "alpha_bbox": bbox,
            "alpha_coverage": alpha_pixels / max(1, total),
            "opaque_ratio": opaque_pixels / max(1, total),
            "soft_alpha_ratio": soft_pixels / max(1, total),
            "luma_mean": stat_l.mean[0],
            "luma_std": stat_l.stddev[0],
            "saturation_mean": stat_hsv.mean[1] / 255.0,
            "saturation_std": stat_hsv.stddev[1] / 255.0,
            "edge_density": edge_mean,
        }


def collect_pngs_from_manifest(path: Path) -> list[Path]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        return []
    found: list[Path] = []

    def visit(value: Any, key: str = "") -> None:
        if isinstance(value, dict):
            for k, item in value.items():
                visit(item, k)
        elif isinstance(value, list):
            for item in value:
                visit(item, key)
        elif isinstance(value, str) and value.lower().endswith(".png") and "::" not in value:
            lowered = f"{key} {value}".lower()
            if "preview" in lowered or ".packed-sheets" in lowered.replace("\\", "/"):
                return
            candidate = Path(value)
            if candidate.exists():
                found.append(candidate)

    visit(data.get("files", {}))
    return sorted(set(found))


def collect_manifest_image_entries(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        return []
    entries: list[dict[str, Any]] = []

    def add(value: str, key: str) -> None:
        if "::" in value or not value.lower().endswith(".png"):
            return
        candidate = Path(value)
        if candidate.exists():
            entries.append(
                {
                    "path": str(candidate),
                    "role": key or "png",
                    "preview": "preview" in f"{key} {value}".lower(),
                    "manifest": str(path),
                }
            )

    def visit(value: Any, key: str = "") -> None:
        if isinstance(value, dict):
            for k, item in value.items():
                visit(item, k)
        elif isinstance(value, list):
            for item in value:
                visit(item, key)
        elif isinstance(value, str):
            add(value, key)

    visit(data.get("files", {}))
    return entries


def configured_style(spec: dict[str, Any]) -> dict[str, Any]:
    style = deepcopy(spec.get("style", {})) if isinstance(spec.get("style"), dict) else {}
    qa_style = spec.get("qa", {}).get("style") if isinstance(spec.get("qa", {}), dict) else None
    if isinstance(qa_style, dict):
        style.update(qa_style)
    style.setdefault("enabled", False)
    style.setdefault("baseline_globs", ["exotic-space-industries-remembrance/graphics/**/*.png"])
    style.setdefault("target_paths", [])
    style.setdefault("max_baseline_images", 120)
    style.setdefault("warn_luma_delta", 45)
    style.setdefault("warn_saturation_delta", 0.35)
    style.setdefault("warn_edge_density_delta", 0.12)
    return style


def run_style_analysis(spec: dict[str, Any]) -> dict[str, Any] | None:
    style = configured_style(spec)
    if not as_bool(style.get("enabled")):
        return None
    target_paths = [Path(str(path)) for path in style.get("target_paths", []) if str(path).lower().endswith(".png")]
    export_manifest = Path(str(spec.get("export", {}).get("manifest", "")))
    target_paths.extend(collect_pngs_from_manifest(export_manifest))
    target_paths = [path for path in sorted(set(target_paths)) if path.exists() and not path.name.lower().endswith(".preview.png")]

    baseline_paths: list[Path] = []
    for pattern in style.get("baseline_globs", []):
        baseline_paths.extend(Path(path) for path in glob.glob(str(pattern), recursive=True))
    baseline_paths = [
        path
        for path in sorted(set(baseline_paths))
        if path.exists()
        and path.suffix.lower() == ".png"
        and not path.name.lower().endswith(".preview.png")
        and ".packed-sheets" not in str(path).replace("\\", "/")
    ]
    max_baseline = int(style.get("max_baseline_images") or 120)
    if max_baseline and len(baseline_paths) > max_baseline:
        step = max(1, len(baseline_paths) // max_baseline)
        baseline_paths = baseline_paths[::step][:max_baseline]

    target_metrics = [style_metrics(path) for path in target_paths]
    baseline_metrics = [style_metrics(path) for path in baseline_paths]
    warnings: list[str] = []
    baseline_summary: dict[str, Any] = {"count": len(baseline_metrics)}
    if baseline_metrics:
        for key in ["luma_mean", "saturation_mean", "edge_density", "alpha_coverage"]:
            values = [float(item[key]) for item in baseline_metrics]
            baseline_summary[key] = {
                "median": statistics.median(values),
                "mean": statistics.fmean(values),
            }
    for item in target_metrics:
        if baseline_metrics:
            luma_delta = abs(float(item["luma_mean"]) - baseline_summary["luma_mean"]["median"])
            sat_delta = abs(float(item["saturation_mean"]) - baseline_summary["saturation_mean"]["median"])
            edge_delta = abs(float(item["edge_density"]) - baseline_summary["edge_density"]["median"])
            item["baseline_delta"] = {
                "luma": luma_delta,
                "saturation": sat_delta,
                "edge_density": edge_delta,
            }
            if luma_delta > float(style["warn_luma_delta"]):
                warnings.append(f"{item['path']} luma is far from ESIR baseline.")
            if sat_delta > float(style["warn_saturation_delta"]):
                warnings.append(f"{item['path']} saturation is far from ESIR baseline.")
            if edge_delta > float(style["warn_edge_density_delta"]):
                warnings.append(f"{item['path']} edge density is far from ESIR baseline.")

    output = style.get("output")
    report = {
        "enabled": True,
        "targets": target_metrics,
        "baseline": baseline_summary,
        "warnings": warnings,
        "passed": True,
    }
    if output:
        write_json(Path(str(output)), report)
    return report


def configured_regression(spec: dict[str, Any]) -> dict[str, Any]:
    regression = deepcopy(spec.get("regression", {})) if isinstance(spec.get("regression"), dict) else {}
    qa_regression = spec.get("qa", {}).get("regression_baseline") if isinstance(spec.get("qa", {}), dict) else None
    if isinstance(qa_regression, dict):
        regression.update(qa_regression)
    regression.setdefault("enabled", False)
    regression.setdefault("warn_luma_delta", 30)
    regression.setdefault("warn_alpha_coverage_delta", 0.18)
    regression.setdefault("fail_dimension_change", True)
    return regression


def baseline_entries_from_report(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        return {}
    raw_entries: list[dict[str, Any]] = []
    if isinstance(data.get("entries"), dict):
        for entry in data["entries"].values():
            if isinstance(entry, dict):
                metrics = entry.get("metrics") if isinstance(entry.get("metrics"), dict) else entry
                raw_entries.append(metrics)
    elif isinstance(data.get("targets"), list):
        raw_entries = [entry for entry in data["targets"] if isinstance(entry, dict)]
    elif isinstance(data.get("current"), list):
        raw_entries = [entry for entry in data["current"] if isinstance(entry, dict)]

    entries: dict[str, dict[str, Any]] = {}
    for entry in raw_entries:
        raw_path = entry.get("path")
        if not raw_path:
            continue
        path_key = str(raw_path).replace("\\", "/")
        entries[path_key] = entry
        entries[Path(path_key).name] = entry
    return entries


def run_regression_check(spec: dict[str, Any]) -> dict[str, Any] | None:
    regression = configured_regression(spec)
    if not as_bool(regression.get("enabled")):
        return None
    baseline_path = Path(str(regression.get("baseline") or regression.get("path") or ""))
    current_paths: set[Path] = set()
    export_manifest = Path(str(spec.get("export", {}).get("manifest", "")))
    current_paths.update(collect_pngs_from_manifest(export_manifest))
    for raw in spec.get("qa", {}).get("check_paths", []):
        candidate = Path(str(raw))
        if candidate.exists() and candidate.suffix.lower() == ".png" and not candidate.name.lower().endswith(".preview.png"):
            current_paths.add(candidate)
    current = [style_metrics(path) for path in sorted(current_paths)]
    baseline = baseline_entries_from_report(baseline_path)
    warnings: list[str] = []
    errors: list[str] = []
    comparisons: list[dict[str, Any]] = []
    if not baseline:
        warnings.append(f"Regression baseline is missing or empty: {baseline_path}")
    for item in current:
        key = str(item["path"]).replace("\\", "/")
        previous = baseline.get(key) or baseline.get(Path(key).name)
        if not previous:
            warnings.append(f"{item['path']} has no regression baseline entry.")
            comparisons.append({"path": item["path"], "status": "missing-baseline"})
            continue
        comparison = {"path": item["path"], "status": "compared", "deltas": {}}
        if [item.get("width"), item.get("height")] != [previous.get("width"), previous.get("height")]:
            message = f"{item['path']} dimensions changed from {previous.get('width')}x{previous.get('height')} to {item.get('width')}x{item.get('height')}."
            if as_bool(regression.get("fail_dimension_change")):
                errors.append(message)
            else:
                warnings.append(message)
        for metric, threshold_key in [
            ("luma_mean", "warn_luma_delta"),
            ("alpha_coverage", "warn_alpha_coverage_delta"),
        ]:
            if metric in previous and metric in item:
                delta = abs(float(item[metric]) - float(previous[metric]))
                comparison["deltas"][metric] = delta
                if delta > float(regression.get(threshold_key, 0)):
                    warnings.append(f"{item['path']} {metric} drifted by {delta:.3f}.")
        if item.get("sha256") != previous.get("sha256"):
            comparison["hash_changed"] = True
            if as_bool(regression.get("fail_hash_drift")):
                errors.append(f"{item['path']} hash changed from regression baseline.")
        comparisons.append(comparison)
    report = {
        "enabled": True,
        "baseline": str(baseline_path),
        "current": current,
        "comparisons": comparisons,
        "warnings": warnings,
        "errors": errors,
        "passed": not errors,
    }
    output = regression.get("output")
    if output:
        write_json(Path(str(output)), report)
    return report


def png_layout_from_sidecar(path: Path) -> dict[str, Any] | None:
    sidecars = [path.with_suffix(".manifest.json")]
    sidecars.extend(path.parent.glob("*.factorio-asset-manifest.json"))
    for sidecar in sidecars:
        if not sidecar.exists():
            continue
        try:
            data = json.loads(sidecar.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        basename = path.name
        specs = []
        if isinstance(data.get("layer_specs"), dict):
            specs.extend(data["layer_specs"].values())
        for key in ["main_spec", "shadow_spec", "working_spec", "working_shadow_spec"]:
            if isinstance(data.get(key), dict):
                specs.append(data[key])
        for spec in specs:
            if not isinstance(spec, dict):
                continue
            stripes = spec.get("stripes")
            if isinstance(stripes, list):
                consumed = 0
                total_frames = int(spec.get("frame_count") or 1) * int(spec.get("direction_count") or 1)
                for index, stripe in enumerate(stripes):
                    if not isinstance(stripe, dict):
                        continue
                    stripe_name = Path(str(stripe.get("path") or stripe.get("filename") or "")).name
                    width_in_frames = int(stripe.get("width_in_frames") or spec.get("line_length") or 1)
                    height_in_frames = int(stripe.get("height_in_frames") or 1)
                    capacity = max(1, width_in_frames * height_in_frames)
                    active_frames = max(0, min(capacity, total_frames - consumed))
                    if stripe_name == basename:
                        return {
                            "frame_width": spec.get("frame_width"),
                            "frame_height": spec.get("frame_height"),
                            "line_length": width_in_frames,
                            "frame_count": max(1, active_frames),
                            "direction_count": 1,
                            "stripe_index": index,
                            "stripe_capacity": capacity,
                            "stripe_active_frames": active_frames,
                            "total_frame_count": total_frames,
                        }
                    consumed += capacity
            if Path(str(spec.get("path", ""))).name == basename:
                return spec
        if sidecar == path.with_suffix(".manifest.json"):
            frame_size = data.get("frame_size")
            return {
                "frame_width": data.get("frame_width") or frame_size,
                "frame_height": data.get("frame_height") or frame_size,
                "line_length": data.get("columns") or data.get("line_length"),
                "frame_count": data.get("frame_count") or data.get("frames") or data.get("directions"),
                "direction_count": data.get("direction_count") or data.get("directions") or 1,
            }
    return None


def crop_tile(image: Any, index: int, layout: dict[str, Any]) -> Any:
    frame_width = int(layout["frame_width"])
    frame_height = int(layout["frame_height"])
    line_length = int(layout["line_length"])
    col = index % line_length
    row = index // line_length
    left = col * frame_width
    top = row * frame_height
    return image.crop((left, top, left + frame_width, top + frame_height))


def mean_rgba_diff(first: Any, second: Any) -> float:
    if ImageChops is None:
        return 999.0
    diff = ImageChops.difference(first.convert("RGBA"), second.convert("RGBA"))
    histogram = diff.histogram()
    total = sum(value * (index % 256) for index, value in enumerate(histogram))
    pixels = first.width * first.height * 4
    return total / max(1, pixels)


def tile_report(path: Path, layout: dict[str, Any]) -> dict[str, Any]:
    if Image is None:
        raise PipelineError("Pillow is required for QA image checks.")
    frame_width = int(layout.get("frame_width") or 0)
    frame_height = int(layout.get("frame_height") or 0)
    line_length = int(layout.get("line_length") or 0)
    frame_count = int(layout.get("frame_count") or 1)
    direction_count = int(layout.get("direction_count") or 1)
    total = frame_count * direction_count
    if frame_width < 1 or frame_height < 1 or line_length < 1 or total < 1:
        return {"path": str(path), "layout_valid": False, "message": "invalid or incomplete sheet layout"}
    with Image.open(path).convert("RGBA") as image:
        rows = (total + line_length - 1) // line_length
        layout_valid = line_length * frame_width <= image.width and rows * frame_height <= image.height
        if not layout_valid:
            return {"path": str(path), "layout_valid": False, "message": "sheet layout exceeds image bounds"}
        blank_tiles = []
        clipped_tiles = []
        bbox_areas = []
        tile_bboxes = []
        for index in range(total):
            tile = crop_tile(image, index, layout)
            alpha = tile.getchannel("A")
            bbox = alpha.getbbox()
            tile_bboxes.append(bbox)
            if not bbox:
                blank_tiles.append(index + 1)
                bbox_areas.append(0)
                continue
            if bbox[0] <= 1 or bbox[1] <= 1 or frame_width - bbox[2] <= 1 or frame_height - bbox[3] <= 1:
                clipped_tiles.append(index + 1)
            bbox_areas.append((bbox[2] - bbox[0]) * (bbox[3] - bbox[1]))
        nonzero = [area for area in bbox_areas if area > 0]
        variance_ratio = None
        if nonzero:
            mean = sum(nonzero) / len(nonzero)
            variance_ratio = (max(nonzero) - min(nonzero)) / max(1, mean)
        duplicate_loop_diff = None
        if total > 1:
            duplicate_loop_diff = mean_rgba_diff(crop_tile(image, 0, layout), crop_tile(image, total - 1, layout))
        return {
            "path": str(path),
            "layout_valid": True,
            "frame_width": frame_width,
            "frame_height": frame_height,
            "line_length": line_length,
            "frame_count": frame_count,
            "direction_count": direction_count,
            "blank_tiles": blank_tiles,
            "clipped_tiles": clipped_tiles,
            "alpha_bbox_variance_ratio": variance_ratio,
            "duplicate_first_last_diff": duplicate_loop_diff,
            "tile_bboxes": tile_bboxes,
        }


def write_bbox_overlay(path: Path, layout: dict[str, Any], tile_details: dict[str, Any], output_dir: Path) -> str | None:
    if Image is None or ImageDraw is None or not tile_details.get("layout_valid"):
        return None
    output_dir.mkdir(parents=True, exist_ok=True)
    with Image.open(path).convert("RGBA") as image:
        scale = min(1024 / image.width, 1024 / image.height, 1.0)
        preview = image.copy()
        draw = ImageDraw.Draw(preview)
        frame_width = int(layout["frame_width"])
        frame_height = int(layout["frame_height"])
        line_length = int(layout["line_length"])
        for index, bbox in enumerate(tile_details.get("tile_bboxes", [])):
            col = index % line_length
            row = index // line_length
            left = col * frame_width
            top = row * frame_height
            draw.rectangle((left, top, left + frame_width - 1, top + frame_height - 1), outline=(255, 255, 0, 160), width=2)
            if bbox:
                draw.rectangle(
                    (left + bbox[0], top + bbox[1], left + bbox[2] - 1, top + bbox[3] - 1),
                    outline=(255, 32, 32, 220),
                    width=2,
                )
        if scale < 1.0:
            preview = preview.resize((round(preview.width * scale), round(preview.height * scale)), Image.Resampling.LANCZOS)
        target = output_dir / f"{path.stem}.bbox-preview.png"
        preview.save(target)
        return str(target)


def asset_manifest_warnings(path: Path) -> list[str]:
    warnings: list[str] = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return warnings
    specs = data.get("layer_specs")
    if not isinstance(specs, dict) or "base" not in specs:
        return warnings
    base = specs["base"]
    base_size = (base.get("image_width"), base.get("image_height"))
    for key, spec in specs.items():
        if not isinstance(spec, dict) or key == "base" or key == "water_reflection":
            continue
        size = (spec.get("image_width"), spec.get("image_height"))
        if size != base_size:
            warnings.append(f"{path}: {key} dimensions {size} differ from base {base_size}.")
    return warnings


def run_qa(spec: dict[str, Any]) -> dict[str, Any]:
    qa = spec.get("qa", {})
    checks: list[dict[str, Any]] = []
    warnings: list[str] = []
    errors: list[str] = []
    paths = qa.get("check_paths") or []
    min_alpha = int(qa.get("min_alpha_pixels", 1))

    for raw in paths:
        if not raw:
            continue
        path = Path(str(raw))
        if not path.exists():
            checks.append({"path": str(path), "exists": False})
            errors.append(f"Missing QA path: {path}")
            continue
        if path.suffix.lower() == ".png":
            if path.name.lower().endswith(".preview.png"):
                with Image.open(path) as image:
                    checks.append(
                        {
                            "path": str(path),
                            "exists": True,
                            "preview": True,
                            "width": image.width,
                            "height": image.height,
                            "mode": image.mode,
                        }
                    )
                continue
            report = alpha_report(path)
            checks.append(report)
            if qa.get("require_alpha", True) and report["alpha_pixels"] < min_alpha:
                errors.append(f"{path} has too few alpha pixels: {report['alpha_pixels']}")
            if report.get("edge_touch"):
                warnings.append(f"{path} alpha touches the image edge; check clipping.")
            layout = png_layout_from_sidecar(path)
            if layout:
                details = tile_report(path, layout)
                checks.append({"path": str(path), "tile_report": details})
                if not details.get("layout_valid", True):
                    errors.append(f"{path} has invalid sheet layout: {details.get('message')}")
                for tile in details.get("blank_tiles", []):
                    warnings.append(f"{path} tile {tile} is blank.")
                if details.get("clipped_tiles"):
                    warnings.append(f"{path} has clipped tile bbox edges: {details['clipped_tiles'][:12]}")
                if details.get("alpha_bbox_variance_ratio") is not None and details["alpha_bbox_variance_ratio"] > 0.55:
                    warnings.append(f"{path} has high alpha bbox variance across frames.")
                if details.get("duplicate_first_last_diff") is not None and details["duplicate_first_last_diff"] < 0.5:
                    warnings.append(f"{path} first and last tiles are nearly identical; avoid duplicate loop frames.")
                if qa.get("contact_sheet_dir"):
                    overlay = write_bbox_overlay(path, layout, details, Path(str(qa["contact_sheet_dir"])))
                    if overlay:
                        checks.append({"path": str(path), "bbox_preview": overlay})
        elif path.suffix.lower() == ".json":
            try:
                json.loads(path.read_text(encoding="utf-8"))
                checks.append({"path": str(path), "exists": True, "json": True})
                warnings.extend(asset_manifest_warnings(path))
            except json.JSONDecodeError as exc:
                errors.append(f"{path} is invalid JSON: {exc}")

    if qa.get("require_shadow_lower_right"):
        shadow = spec.get("render_procedural", {}).get("shadow_sheet") or spec.get("export", {}).get("shadow_sheet")
        base = spec.get("render_procedural", {}).get("output_sheet") or spec.get("render_static", {}).get("output_sheet")
        if shadow and base and Path(shadow).exists() and Path(base).exists():
            base_report = alpha_report(Path(base))
            shadow_report = alpha_report(Path(shadow))
            if base_report["alpha_bbox"] and shadow_report["alpha_bbox"]:
                bx, by, _, _ = base_report["alpha_bbox"]
                sx, sy, _, _ = shadow_report["alpha_bbox"]
                if sx < bx or sy < by:
                    warnings.append("Shadow alpha bbox is not lower-right of base alpha bbox.")
                if base_report.get("alpha_centroid") and shadow_report.get("alpha_centroid"):
                    bc = base_report["alpha_centroid"]
                    sc = shadow_report["alpha_centroid"]
                    if sc[0] < bc[0] or sc[1] < bc[1]:
                        warnings.append("Shadow centroid is not down/right of the base centroid.")

    style_result = run_style_analysis(spec)
    if style_result:
        checks.append({"style": style_result})
        warnings.extend(style_result.get("warnings", []))

    regression_result = run_regression_check(spec)
    if regression_result:
        checks.append({"regression": regression_result})
        warnings.extend(regression_result.get("warnings", []))
        errors.extend(regression_result.get("errors", []))

    return {
        "checks": checks,
        "style": style_result,
        "regression": regression_result,
        "warnings": warnings,
        "errors": errors,
        "passed": not errors,
    }


def artifact_paths(spec: dict[str, Any]) -> dict[str, Any]:
    artifacts: dict[str, Any] = {
        "output_root": spec.get("output_root"),
        "model_path": existing_or_glob(spec.get("model_path", ""), spec.get("model_glob")),
    }
    for section_name in ["render_static", "render_procedural", "render_preset", "export", "promotion"]:
        section = spec.get(section_name, {})
        if isinstance(section, dict):
            artifacts[section_name] = {
                key: value
                for key, value in section.items()
                if key.endswith("_sheet")
                or key in {"output_sheet", "manifest", "output_dir", "source", "bundle", "preset_blend", "graphics_destination", "prototype_file"}
            }
    return artifacts


def registry_role(path: Path) -> str:
    name = path.name.lower()
    if "shadow" in name:
        return "shadow"
    if "light" in name or "glow" in name:
        return "glow"
    if "mask" in name:
        return "mask"
    if "icon" in name:
        return "icon"
    if "preview" in name:
        return "preview"
    return "base"


def registry_entry_for(path: Path, spec: dict[str, Any], dossier_path: Path, qa_result: dict[str, Any] | None) -> dict[str, Any]:
    metrics = style_metrics(path) if path.exists() and path.suffix.lower() == ".png" else {}
    return {
        "asset_name": spec.get("asset_name"),
        "prototype_kind": spec.get("promotion", {}).get("prototype_type") or spec.get("kind"),
        "path": str(path),
        "role": registry_role(path),
        "manifest": spec.get("export", {}).get("manifest"),
        "dossier": str(dossier_path),
        "sha256": metrics.get("sha256"),
        "bytes": metrics.get("bytes"),
        "image": {key: metrics.get(key) for key in ["width", "height"] if key in metrics},
        "metrics": metrics,
        "qa": {"passed": qa_result.get("passed")} if qa_result else {},
    }


def update_asset_registry(spec: dict[str, Any], dossier_path: Path, qa_result: dict[str, Any] | None) -> dict[str, Any] | None:
    registry = spec.get("registry", {})
    if not isinstance(registry, dict) or not as_bool(registry.get("enabled")):
        return None
    path = Path(str(registry.get("path", "output/meshy/asset-index.json")))
    existing: dict[str, Any] = {}
    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError:
            existing = {}
    entries = existing.get("entries", {}) if isinstance(existing.get("entries"), dict) else {}
    preserve_manual = {
        key: value.get("manual", {})
        for key, value in entries.items()
        if isinstance(value, dict)
    }

    pngs: set[Path] = set()
    export_manifest = Path(str(spec.get("export", {}).get("manifest", "")))
    pngs.update(collect_pngs_from_manifest(export_manifest))
    for raw in spec.get("qa", {}).get("check_paths", []):
        candidate = Path(str(raw))
        if candidate.exists() and candidate.suffix.lower() == ".png" and not candidate.name.lower().endswith(".preview.png"):
            pngs.add(candidate)

    updated = dict(entries)
    changed = []
    for png in sorted(pngs):
        key = str(png).replace("\\", "/")
        entry = registry_entry_for(png, spec, dossier_path, qa_result)
        entry["manual"] = preserve_manual.get(key, {"status": "candidate", "notes": "", "tags": []})
        previous_sha = entries.get(key, {}).get("sha256") if isinstance(entries.get(key), dict) else None
        updated[key] = entry
        if previous_sha != entry.get("sha256"):
            changed.append(key)

    payload = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "roots": registry.get("roots", []),
        "entries": updated,
    }
    temp = path.with_suffix(path.suffix + ".tmp")
    write_json(temp, payload)
    temp.replace(path)
    return {"path": str(path), "updated_entries": len(pngs), "changed": changed}


def relative_href(path: Path, base: Path) -> str:
    return os.path.relpath(path.resolve(), base.resolve()).replace("\\", "/")


def gallery_images(spec: dict[str, Any]) -> list[dict[str, Any]]:
    images: list[dict[str, Any]] = []
    export_manifest = Path(str(spec.get("export", {}).get("manifest", "")))
    images.extend(collect_manifest_image_entries(export_manifest))
    for raw in spec.get("qa", {}).get("check_paths", []):
        candidate = Path(str(raw))
        if candidate.exists() and candidate.suffix.lower() == ".png":
            images.append({"path": str(candidate), "role": "qa", "preview": candidate.name.lower().endswith(".preview.png")})
    unique: dict[str, dict[str, Any]] = {}
    for item in images:
        unique[str(Path(item["path"])).replace("\\", "/")] = item
    return list(unique.values())


def write_approval_gallery(spec: dict[str, Any], dossier: dict[str, Any]) -> dict[str, Any] | None:
    gallery = spec.get("gallery", {})
    if not isinstance(gallery, dict) or not as_bool(gallery.get("enabled")):
        return None
    output = Path(str(gallery.get("output", Path(str(spec.get("output_root", "output/meshy"))) / "approval-gallery.html")))
    output.parent.mkdir(parents=True, exist_ok=True)
    images = gallery_images(spec)
    qa = dossier.get("qa") or {}
    registry = dossier.get("registry") or {}
    render_cost = dossier.get("render_cost_estimate") or {}
    snippet_path = Path(str(spec.get("export", {}).get("manifest", "")))
    snippet_text = ""
    if as_bool(gallery.get("include_snippet", True)) and snippet_path.exists():
        try:
            manifest = json.loads(snippet_path.read_text(encoding="utf-8-sig"))
            raw_snippet = manifest.get("files", {}).get("snippet")
            if raw_snippet and Path(str(raw_snippet)).exists():
                snippet_text = Path(str(raw_snippet)).read_text(encoding="utf-8")[:16000]
        except (json.JSONDecodeError, OSError):
            snippet_text = ""
    cards = []
    for item in images:
        path = Path(str(item["path"]))
        label = f"{item.get('role', 'png')} - {path.name}"
        cards.append(
            "\n".join(
                [
                    '<article class="card">',
                    f"<h2>{html.escape(label)}</h2>",
                    f'<a href="{html.escape(relative_href(path, output.parent))}"><img src="{html.escape(relative_href(path, output.parent))}" alt="{html.escape(label)}"></a>',
                    f"<p>{html.escape(str(path))}</p>",
                    "</article>",
                ]
            )
        )
    warnings = qa.get("warnings", []) if isinstance(qa, dict) else []
    errors = qa.get("errors", []) if isinstance(qa, dict) else []
    html_text = f"""<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <title>{html.escape(spec.get('asset_name', 'ESIR Asset'))} Approval Gallery</title>
  <style>
    body {{ font-family: Segoe UI, sans-serif; margin: 24px; background: #151515; color: #ece8df; }}
    a {{ color: #c9df8a; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 16px; }}
    .card {{ border: 1px solid #45423b; background: #20201d; padding: 12px; border-radius: 6px; }}
    img {{ max-width: 100%; height: auto; image-rendering: auto; background: #2c2c2c; }}
    pre {{ overflow: auto; background: #0f0f0f; padding: 12px; border: 1px solid #3d3a33; }}
    .bad {{ color: #ff9a8c; }}
    .warn {{ color: #f2d37a; }}
  </style>
</head>
<body>
  <h1>{html.escape(spec.get('asset_name', 'ESIR Asset'))}</h1>
  <p>Kind: {html.escape(str(spec.get('kind')))} | QA: {html.escape(str(qa.get('passed') if isinstance(qa, dict) else None))} | Cost band: {html.escape(str(render_cost.get('cost_band')))}</p>
  <p>Dossier: {html.escape(str(dossier.get('dossier_path', '')))} | Registry: {html.escape(str(registry.get('path', '')))}</p>
  <h2>Errors</h2>
  <ul>{''.join(f'<li class=\"bad\">{html.escape(str(item))}</li>' for item in errors) or '<li>None</li>'}</ul>
  <h2>Warnings</h2>
  <ul>{''.join(f'<li class=\"warn\">{html.escape(str(item))}</li>' for item in warnings) or '<li>None</li>'}</ul>
  <section class=\"grid\">{''.join(cards)}</section>
  <h2>Prototype Snippet</h2>
  <pre>{html.escape(snippet_text) if snippet_text else 'No snippet found.'}</pre>
</body>
</html>
"""
    output.write_text(html_text, encoding="utf-8")
    return {"path": str(output), "images": len(images)}


def load_registry(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": 1, "entries": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Invalid registry JSON: {path}: {exc}") from exc
    if not isinstance(data.get("entries"), dict):
        data["entries"] = {}
    return data


def write_registry_browser(path: Path, output: Path) -> dict[str, Any]:
    registry = load_registry(path)
    entries = registry.get("entries", {})
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for key, entry in sorted(entries.items()):
        if not isinstance(entry, dict):
            continue
        manual = entry.get("manual", {}) if isinstance(entry.get("manual"), dict) else {}
        image_path = Path(str(entry.get("path", "")))
        image_cell = ""
        if image_path.exists() and image_path.suffix.lower() == ".png":
            image_cell = f'<img src="{html.escape(relative_href(image_path, output.parent))}" alt="">'
        rows.append(
            "<tr>"
            f"<td>{image_cell}</td>"
            f"<td>{html.escape(str(entry.get('asset_name', '')))}</td>"
            f"<td>{html.escape(str(entry.get('role', '')))}</td>"
            f"<td>{html.escape(str(manual.get('status', 'candidate')))}</td>"
            f"<td>{html.escape(str(entry.get('qa', {}).get('passed', '')))}</td>"
            f"<td><code>{html.escape(str(key))}</code></td>"
            f"<td>{html.escape(str(manual.get('notes', '')))}</td>"
            "</tr>"
        )
    html_text = f"""<!doctype html>
<html lang=\"en\"><head><meta charset=\"utf-8\"><title>ESIR Asset Registry</title>
<style>body{{font-family:Segoe UI,sans-serif;margin:24px;background:#151515;color:#ece8df}}table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #444;padding:8px;vertical-align:top}}img{{max-width:140px;max-height:140px;background:#2c2c2c}}code{{white-space:pre-wrap}}</style>
</head><body><h1>ESIR Asset Registry</h1><p>{html.escape(str(path))}</p>
<table><thead><tr><th>Preview</th><th>Asset</th><th>Role</th><th>Status</th><th>QA</th><th>Key</th><th>Notes</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
</body></html>"""
    output.write_text(html_text, encoding="utf-8")
    return {"path": str(output), "entries": len(rows)}


def update_registry_manual(path: Path, key: str, status: str, notes: str | None, tags: list[str]) -> dict[str, Any]:
    registry = load_registry(path)
    entries = registry["entries"]
    match_key = key if key in entries else None
    if match_key is None:
        normalized = key.replace("\\", "/")
        for candidate in entries:
            if candidate == normalized or candidate.endswith(normalized) or Path(candidate).name == Path(normalized).name:
                match_key = candidate
                break
    if match_key is None:
        raise PipelineError(f"Registry entry not found: {key}")
    entry = entries[match_key]
    manual = entry.setdefault("manual", {})
    manual["status"] = status
    if notes is not None:
        manual["notes"] = notes
    existing_tags = list(manual.get("tags", [])) if isinstance(manual.get("tags"), list) else []
    for tag in tags:
        if tag not in existing_tags:
            existing_tags.append(tag)
    manual["tags"] = existing_tags
    write_json(path, registry)
    return {"path": str(path), "entry": match_key, "status": status}


def build_plan(spec: dict[str, Any], steps: list[str]) -> list[dict[str, Any]]:
    plan = []
    for step in steps:
        command = command_for_step(step, spec)
        if step == "qa":
            plan.append({"step": step, "enabled": as_bool(spec.get("qa", {}).get("enabled"), True), "command": None})
        else:
            plan.append({"step": step, "enabled": command is not None, "command": command, "display": shell_join(command) if command else None})
    return plan


def dossier_path_for(spec_path: Path, spec: dict[str, Any], override: str | None) -> Path:
    if override:
        return Path(override)
    if spec.get("dossier_path"):
        return Path(str(spec["dossier_path"]))
    return spec_path.with_name("asset.pipeline-dossier.json")


def execute(spec_path: Path, steps: list[str], *, dry_run: bool, continue_on_error: bool, dossier_override: str | None, plan_only: bool = False) -> dict[str, Any]:
    raw_spec = load_spec(spec_path)
    spec = resolve_spec(raw_spec)
    plan = build_plan(spec, steps)
    records: list[dict[str, Any]] = []
    qa_result: dict[str, Any] | None = None
    registry_result: dict[str, Any] | None = None
    gallery_result: dict[str, Any] | None = None
    cost_result = render_cost_estimate(spec)
    failed = False

    if not plan_only:
        for item in plan:
            step = item["step"]
            if not item["enabled"]:
                records.append({"step": step, "skipped": True, "reason": "disabled"})
                continue
            if step == "qa":
                if as_bool(spec.get("qa", {}).get("enabled"), True):
                    if dry_run:
                        records.append({"step": step, "skipped": True, "reason": "dry-run"})
                        continue
                    qa_result = run_qa(spec)
                    records.append({"step": step, "qa": qa_result})
                    if not qa_result["passed"]:
                        failed = True
                        if not continue_on_error:
                            break
                continue
            command = item["command"]
            assert command is not None
            record = run_command(command, dry_run=dry_run)
            record["step"] = step
            records.append(record)
            if record.get("returncode") not in {0, None}:
                failed = True
                if not continue_on_error:
                    break

    dossier_path = dossier_path_for(spec_path, spec, dossier_override)
    if not plan_only and not dry_run:
        registry_result = update_asset_registry(spec, dossier_path, qa_result)

    dossier = {
        "asset_name": spec["asset_name"],
        "kind": spec.get("kind"),
        "spec_path": str(spec_path),
        "created_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "mode": "plan" if plan_only else "dry-run" if dry_run else "run",
        "resolved_spec": spec,
        "render_cost_estimate": cost_result,
        "plan": plan,
        "records": records,
        "qa": qa_result,
        "registry": registry_result,
        "gallery": gallery_result,
        "artifacts": artifact_paths(spec),
        "failed": failed,
    }
    if not plan_only and not dry_run:
        gallery_result = write_approval_gallery(spec, dossier)
        dossier["gallery"] = gallery_result
    write_json(dossier_path, dossier)
    dossier["dossier_path"] = str(dossier_path)
    return dossier


def print_plan(dossier: dict[str, Any]) -> None:
    print(f"asset={dossier['asset_name']}")
    print(f"dossier={dossier['dossier_path']}")
    cost = dossier.get("render_cost_estimate", {})
    if cost.get("items"):
        print(f"render_cost={cost.get('cost_band')} ({cost.get('total_megapixel_samples')} megapixel-samples)")
    for item in dossier["plan"]:
        status = "enabled" if item["enabled"] else "disabled"
        print(f"[{status}] {item['step']}")
        if item.get("display"):
            print(f"  {item['display']}")


def print_run_summary(dossier: dict[str, Any]) -> None:
    print(f"asset={dossier['asset_name']}")
    print(f"mode={dossier['mode']}")
    print(f"dossier={dossier['dossier_path']}")
    for record in dossier["records"]:
        if record.get("skipped"):
            print(f"{record['step']}: skipped")
        elif "qa" in record:
            state = "passed" if record["qa"]["passed"] else "failed"
            print(f"{record['step']}: {state}")
        else:
            print(f"{record['step']}: returncode={record.get('returncode')}")
    if dossier["failed"]:
        raise PipelineError("Pipeline completed with errors. See dossier for details.")


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def variant_overrides(variant: dict[str, Any]) -> dict[str, Any]:
    overrides = deepcopy(variant.get("overrides", {})) if isinstance(variant.get("overrides"), dict) else {}
    for key, value in variant.items():
        if key not in {"name", "id", "description", "enabled", "overrides"}:
            overrides[key] = deepcopy(value)
    return overrides


def execute_batch(
    spec_path: Path,
    *,
    steps: list[str],
    dry_run: bool,
    continue_on_error: bool,
    summary_override: str | None,
) -> dict[str, Any]:
    base = load_spec(spec_path)
    variants = base.get("variants", [])
    if not isinstance(variants, list) or not variants:
        raise PipelineError("Batch spec requires a non-empty variants list.")
    base_without_variants = deepcopy(base)
    base_without_variants.pop("variants", None)
    base_asset = str(base_without_variants.get("asset_name", spec_path.stem))
    base_root = Path(str(base_without_variants.get("output_root", f"output/meshy/{base_asset}")))
    batch_root = base_root / "batch"
    child_records = []
    failed = False
    for index, variant in enumerate(variants, start=1):
        if not isinstance(variant, dict) or not as_bool(variant.get("enabled", True), True):
            continue
        variant_id = str(variant.get("id") or variant.get("name") or f"variant-{index}")
        merged = deep_merge(base_without_variants, variant_overrides(variant))
        merged.setdefault("asset_name", f"{base_asset}-{variant_id}")
        merged.setdefault("output_root", str(base_root / "variants" / variant_id))
        merged["asset_name"] = str(merged["asset_name"]).replace("{variant}", variant_id)
        merged["output_root"] = str(merged["output_root"]).replace("{variant}", variant_id)
        variant_dir = batch_root / variant_id
        variant_spec = variant_dir / "asset.pipeline.json"
        write_json(variant_spec, merged)
        try:
            child = execute(
                variant_spec,
                steps,
                dry_run=dry_run,
                continue_on_error=continue_on_error,
                dossier_override=str(variant_dir / "asset.pipeline-dossier.json"),
            )
            child_records.append(
                {
                    "variant": variant_id,
                    "spec": str(variant_spec),
                    "dossier": child.get("dossier_path"),
                    "failed": child.get("failed", False),
                    "qa_passed": (child.get("qa") or {}).get("passed") if child.get("qa") else None,
                    "cost": child.get("render_cost_estimate"),
                }
            )
            if child.get("failed"):
                failed = True
                if not continue_on_error:
                    break
        except Exception as exc:
            failed = True
            child_records.append({"variant": variant_id, "spec": str(variant_spec), "failed": True, "error": str(exc)})
            if not continue_on_error:
                break
    summary = {
        "base_spec": str(spec_path),
        "created_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "dry_run": dry_run,
        "steps": steps,
        "variants": child_records,
        "failed": failed,
    }
    summary_path = Path(summary_override) if summary_override else batch_root / "asset.pipeline-batch-dossier.json"
    write_json(summary_path, summary)
    summary["summary_path"] = str(summary_path)
    return summary


def print_batch_summary(summary: dict[str, Any]) -> None:
    print(f"batch_summary={summary['summary_path']}")
    for record in summary["variants"]:
        status = "failed" if record.get("failed") else "ok"
        print(f"{record.get('variant')}: {status}")
    if summary.get("failed"):
        raise PipelineError("One or more variants failed. See batch summary for details.")


def main() -> int:
    args = parse_args()
    try:
        if args.command == "sample":
            output = Path(args.output)
            if output.exists() and not args.force:
                raise PipelineError(f"Refusing to overwrite existing spec without --force: {output}")
            write_json(output, sample_spec(args.asset_name, args.kind))
            print(f"sample_spec={output}")
            return 0
        if args.command == "plan":
            dossier = execute(Path(args.spec), parse_steps(args.steps), dry_run=True, continue_on_error=True, dossier_override=args.dossier, plan_only=True)
            print_plan(dossier)
            return 0
        if args.command == "run":
            dossier = execute(Path(args.spec), parse_steps(args.steps), dry_run=args.dry_run, continue_on_error=args.continue_on_error, dossier_override=args.dossier)
            print_run_summary(dossier)
            return 0
        if args.command == "qa":
            dossier = execute(Path(args.spec), ["qa"], dry_run=False, continue_on_error=False, dossier_override=args.dossier)
            print_run_summary(dossier)
            return 0
        if args.command == "estimate":
            spec = resolve_spec(load_spec(Path(args.spec)))
            report = render_cost_estimate(spec)
            print(json.dumps(report, indent=2))
            return 0
        if args.command == "batch":
            summary = execute_batch(
                Path(args.spec),
                steps=parse_steps(args.steps),
                dry_run=args.dry_run,
                continue_on_error=args.continue_on_error,
                summary_override=args.summary,
            )
            print_batch_summary(summary)
            return 0
        if args.command == "registry":
            registry_path = Path(args.path)
            result = None
            if args.set_status:
                result = update_registry_manual(registry_path, args.set_status[0], args.set_status[1], args.notes, args.tag)
                print(json.dumps(result, indent=2))
            if args.html:
                result = write_registry_browser(registry_path, Path(args.html))
                print(json.dumps(result, indent=2))
            if result is None:
                registry = load_registry(registry_path)
                print(json.dumps({"path": str(registry_path), "entries": len(registry.get("entries", {}))}, indent=2))
            return 0
        raise PipelineError(f"Unknown command: {args.command}")
    except PipelineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
