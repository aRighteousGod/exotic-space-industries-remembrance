"""Supplement the existing selective inspector with final art/audio contracts.

This inspector reads a fresh pretty-printed final dump without loading its gigabytes
at once. It does not launch Factorio or modify shipping assets.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import mmap
from pathlib import Path

import numpy as np
from PIL import Image


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--asset-root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    name = "ei-anisetron"
    with args.dump.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as raw:
        def prototype(group: str, identity: str) -> dict:
            start = raw.find(f'\n  "{group}":'.encode())
            assert start >= 0, group
            end = raw.find(b"\n  }", start)
            key = raw.find(f'    "{identity}":'.encode(), start, end)
            assert key >= 0, (group, identity)
            begin = raw.find(b"{", key)
            finish = raw.find(b"\n    }", begin) + 6
            return json.loads(raw[begin:finish])

        vehicle = prototype("spider-vehicle", name)
        layers = vehicle["graphics_set"]["animation"]["layers"]
        assert len(layers) == 3
        body, glow, crest = layers
        shadow = vehicle["graphics_set"]["shadow_animation"]
        assert glow["draw_as_glow"] and not body.get("apply_runtime_tint")
        assert crest["apply_runtime_tint"] and "mask" in crest["flags"]
        assert not glow.get("apply_runtime_tint") and shadow["draw_as_shadow"]
        passes = {"body": body, "glow": glow, "crest": crest, "shadow": shadow}
        expected_stems = {"body": "anisetron", "glow": "anisetron_glow",
                          "crest": "anisetron_mask", "shadow": "anisetron_shadow"}
        references = []
        for role, layer in passes.items():
            assert layer["direction_count"] == 128 and layer["frame_count"] == 1, role
            assert layer["width"] == layer["height"] == 512, role
            assert layer["line_length"] == layer["lines_per_file"] == layer["slice"] == 8, role
            files = layer["filenames"]
            assert len(files) == 2 and not layer.get("filename"), role
            assert [Path(value).name for value in files] == [f"{expected_stems[role]}_{index}.png" for index in (1, 2)]
            references.extend(files)
        assert len(references) == len(set(references)) == 8
        effect_references = set()
        def collect_assets(value):
            if isinstance(value, dict):
                for entry in value.values():
                    collect_assets(entry)
            elif isinstance(value, list):
                for entry in value:
                    collect_assets(entry)
            elif isinstance(value, str) and value.startswith("__") and value.endswith((".png", ".ogg")):
                effect_references.add(value)

        # Own all six palettes for each channel/upgrade shape. These prototypes
        # carry only presentation; the paid controller owns every damage packet.
        beam_shapes = ("-beam", "-crown-beam", "-crown-beam-axial", "-crown-beam-axial-branch",
                       "-crown-beam-testament", "-crown-beam-testament-branch")
        for suffix in beam_shapes:
            for palette in ("", *(f"-light-{index}" for index in range(1, 7))):
                effect = prototype("beam", name + suffix + palette)
                assert not effect.get("action") and not effect.get("action_triggered_automatically")
                assert not effect.get("working_sound")
                assert effect["graphics_set"]["beam"]["render_layer"] == "light-effect"
                graphics = effect["graphics_set"]
                assert graphics["beam"].get("start") and graphics["beam"].get("ending")
                assert not graphics.get("transparent_start_end_animations")
                assert all(graphics["ground"][part]["filename"].endswith("/empty.png")
                           for part in ("body", "head", "tail"))
                collect_assets(effect)
        cue_names = [f"wound-{index}" for index in range(1, 4)] + [
            f"{kind}-{phase}" for kind in ("collapse-concentrated", "testament-concentrated", "echo")
            for phase in ("warning", "impact")]
        for cue in cue_names:
            collect_assets(prototype("animation", name + "-lance-" + cue))
        collect_assets(prototype("animation", name + "-movement-strand"))
        for suffix in ("-beam", "-crown-beam"):
            beam = prototype("beam", name + suffix)
            assert not beam.get("action") and not beam.get("action_triggered_automatically")
            assert not beam.get("working_sound")
            graphics = beam["graphics_set"]
            assert not graphics.get("transparent_start_end_animations")
            assert graphics["beam"].get("start") and graphics["beam"].get("ending")
            assert graphics["beam"]["render_layer"] == "light-effect"
            for index in range(1, 7):
                variant = prototype("beam", name + suffix + f"-light-{index}")
                assert not variant.get("action") and not variant["action_triggered_automatically"]
                graphic = variant["graphics_set"]
                assert graphic["beam"]["render_layer"] == "light-effect"
                assert graphic["beam"].get("start") and graphic["beam"].get("ending")
                assert not graphic.get("transparent_start_end_animations")
                layers = graphic["beam"]["head"].get("layers", [graphic["beam"]["head"]])
                assert all(layer.get("draw_as_glow") for layer in layers)
                source = prototype("beam", f"ei-singularity-lance-beam-light-{index}")["graphics_set"]
                factor = 1.2 if suffix == "-crown-beam" else .6
                for part in ("head", "tail", "start", "ending"):
                    core, glow = graphic["beam"][part]["layers"]
                    original = source["beam"][part]["layers"][0]
                    assert abs(core["scale"] / original.get("scale", 1) - factor) < 1e-10
                    assert glow["blend_mode"] == "additive-soft"
                    assert all(core.get(key) == glow.get(key) for key in
                               ("width", "height", "scale", "shift", "frame_count", "line_length"))
        trigger = prototype("beam", name + "-charge-trigger")
        for tier in range(1, 65):
            safeguard = prototype("sticker", f"{name}-hover-compensation-{tier}")
            assert safeguard["duration_in_ticks"] == 12 and safeguard["hidden"]
            assert abs(safeguard["vehicle_speed_modifier"] / 1.25 ** tier - 1) < 1e-12
            assert safeguard["vehicle_friction_modifier"] == 1
            assert not safeguard.get("damage_per_tick") and not safeguard.get("spread_fire_entity")
        effects = trigger["action"]["action_delivery"]["target_effects"]
        assert len(effects) == 1 and effects[0]["type"] == "script" and effects[0]["effect_id"] == name + "-charge"
        assert not trigger.get("working_sound")
        voices = []
        for emitter, volume, speed in (("crown", .32, .90), ("facade", .18, 1.05)):
            voice = prototype("simple-entity-with-owner", name + "-" + emitter + "-voice")
            assert voice["hidden"] and voice["hidden_in_factoriopedia"]
            assert not voice["selectable_in_game"] and not voice["allow_copy_paste"]
            assert not voice.get("is_military_target") and not voice.get("minable")
            assert not voice.get("action") and not voice.get("created_effect") and voice["max_health"] == 1
            assert not voice["collision_mask"]["layers"] and voice["collision_box"] == [[0, 0], [0, 0]]
            assert {"not-on-map", "not-blueprintable", "not-deconstructable", "not-in-kill-statistics"} <= set(voice["flags"])
            working = voice["working_sound"]
            sound = working["sound"]
            assert not working.get("persistent") and not working["use_doppler_shift"]
            assert working["fade_in_ticks"] == 6 and working["fade_out_ticks"] == 12
            assert working["max_sounds_per_prototype"] == 5
            assert sound["category"] == "weapon" and sound["volume"] == volume and sound["speed"] == speed
            assert sound["audible_distance_modifier"] == .5 and sound["filename"].endswith("/sounds/anisetron-lance-loop.ogg")
            voices.append({"emitter": emitter, "sound": sound, "working": working})
        hum = vehicle["working_sound"]
        assert hum["sound"]["filename"].endswith("/sounds/gaian-saucer-hum.ogg")
        assert hum["idle_sound"]["filename"] == hum["sound"]["filename"]
        assert [hum["sound"][key] for key in ("min_speed", "max_speed", "volume")] == [.78, .82, .38]
        assert [hum["idle_sound"][key] for key in ("min_speed", "max_speed", "volume")] == [.72, .76, .16]
        assert hum["fade_in_ticks"] == 20 and hum["fade_out_ticks"] == 60

    game_data = Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/data")
    def resolve(reference: str) -> Path:
        pack, relative = reference[2:].split("__/", 1)
        if pack == "exotic-space-industries-remembrance" and args.asset_root and relative.startswith("graphics/"):
            return args.asset_root / relative
        return (game_data if pack in ("core", "base", "space-age", "quality", "elevated-rails") else args.repo) / pack / relative

    totals = {role: 0 for role in passes}
    margins = {role: [] for role in passes}
    cyan = neutral = glow_pixels = crest_pixels = 0
    pngs = []
    for role, layer in passes.items():
        for reference in layer["filenames"]:
            path = resolve(reference)
            assert path.is_file(), reference
            with Image.open(path) as image:
                assert image.size == (4096, 4096), (role, image.size)
                rgba = np.asarray(image.convert("RGBA"))
            totals[role] += int(np.count_nonzero(rgba[..., 3]))
            for row in range(8):
                for column in range(8):
                    alpha = rgba[row*512:(row+1)*512, column*512:(column+1)*512, 3]
                    ys, xs = np.nonzero(alpha)
                    if len(xs):
                        margins[role].append(int(min(xs.min(), ys.min(), 511-xs.max(), 511-ys.max())))
            selected = rgba[..., 3] > 20
            rgb = rgba[..., :3][selected].astype(np.int16)
            if role == "glow":
                glow_pixels += len(rgb)
                cyan += int(np.count_nonzero((rgb[:, 1] + 10 >= rgb[:, 0]) & (rgb[:, 2] + 10 >= rgb[:, 0])))
            if role == "crest":
                crest_pixels += len(rgb)
                neutral += int(np.count_nonzero(np.ptp(rgb, axis=1) <= 2))
            pngs.append({"role": role, "reference": reference, "path": str(path), "sha256": digest(path)})
    assert totals["body"] > 0 and totals["shadow"] > 0
    assert 0 < totals["glow"] / totals["body"] < .45
    assert 0 < totals["crest"] / totals["body"] < .02
    assert glow_pixels and cyan / glow_pixels >= .95
    assert crest_pixels and neutral / crest_pixels >= .999
    for role, values in margins.items():
        assert values and min(values) >= 16, (role, min(values))
        if role in ("body", "shadow"):
            assert len(values) == 128, role
    effect_assets = []
    for reference in sorted(effect_references):
        path = resolve(reference)
        assert path.is_file(), reference
        effect_assets.append({"reference": reference, "bytes": path.stat().st_size, "sha256": digest(path)})
    audio = []
    for reference in {entry["sound"]["filename"] for entry in voices} | {hum["sound"]["filename"]}:
        path = resolve(reference)
        assert path.is_file(), reference
        audio.append({"reference": reference, "path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)})
    report = {"pass": True, "dump": str(args.dump), "dump_bytes": args.dump.stat().st_size,
              "directions": 128, "sheet_count": 8, "passes": pngs,
              "effects": {"beams": 42, "upgrade_cues": 9, "assets": effect_assets},
              "transparent_margins": {role: {"nonempty_directions": len(values), "minimum_pixels": min(values)} for role, values in margins.items()},
              "mobility": {"damage_free_compensation_prototypes": 64, "safety_lifetime": 12,
                           "multiplier_step": 1.25},
              "pixel_checks": {"glow_body_alpha_ratio": totals["glow"] / totals["body"],
                               "crest_body_alpha_ratio": totals["crest"] / totals["body"],
                               "glow_cyan_fraction": cyan / glow_pixels,
                               "crest_neutral_fraction": neutral / crest_pixels},
              "voices": voices, "hum": hum, "audio": audio,
              "limits": ["Limited cyan glow and neutral small crest pixels substantiate routing; named crystal geometry/material provenance and visual review establish semantic crystal-only glow", "No audible runtime proof"]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": True, "directions": 128, "sheets": 8, "voices": 2, "report": str(args.output)}))


if __name__ == "__main__":
    main()
