"""Nonshipping lossless APNG/contact review of an existing separated compilation.

Reads packed sheets without changing compiler inputs or provenance. Durations
use millisecond boundary rounding: the complete transition retains its exact
12/18-tick duration at 60 Hz; individual APNG delays differ by at most 1 ms.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiled", type=Path, required=True)
    parser.add_argument("--direction", type=int, default=96)
    parser.add_argument("--profile", choices=("sd", "hd"), default="hd")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.compiled.resolve()
    metadata_path = root / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    assert metadata["schema"] == "esir.minigun.separated.compiled.v2"
    assert args.direction in metadata["direction_indices"], "Requested direction was not rendered"
    profile = metadata["profiles"][args.profile]
    density = profile["density"]
    canvas_size = 540 * density // 64
    output = (args.output or root / "motion-review" / f"{args.profile}-d{args.direction:03}").resolve()
    assert output.is_relative_to((Path.cwd() / "output").resolve()), "Review belongs in ignored output staging"
    signature = {"compiled_metadata_sha256": hashlib.sha256(metadata_path.read_bytes()).hexdigest(),
                 "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                 "profile": args.profile, "direction": args.direction}
    if output.exists() and any(output.iterdir()):
        assert json.loads((output / "review-input.json").read_text()) == signature, "Use a new output path for changed review inputs"
    output.mkdir(parents=True, exist_ok=True)
    (output / "review-input.json").write_text(json.dumps(signature, indent=2) + "\n")
    cache = {}

    def layer(family, pose=0):
        family_record = profile["families"][family]
        leaf, layout = family_record["leaf"], family_record["layout"]
        direction = 0 if family == "base" else metadata["direction_indices"].index(args.direction)
        file_index, local_direction = divmod(direction, layout["directions_per_file"])
        record = family_record["files"][file_index]
        path = root / args.profile / "images" / record["name"]
        if path not in cache:
            assert hashlib.sha256(path.read_bytes()).hexdigest() == record["sha256"], "Packed sheet changed"
            cache[path] = Image.open(path).convert("RGBA")
        index = local_direction * leaf["frame_count"] + pose
        column, row = index % layout["columns"], index // layout["columns"]
        x, y = column * leaf["width"], row * leaf["height"]
        cell = cache[path].crop((x, y, x + leaf["width"], y + leaf["height"]))
        canvas = Image.new("RGBA", (canvas_size, canvas_size))
        canvas.paste(cell, tuple(family_record["crop"][:2]))
        return canvas

    background = Image.new("RGBA", (canvas_size, canvas_size), "#364249")
    draw = ImageDraw.Draw(background)
    for y in range(0, canvas_size, 16):
        for x in range(0, canvas_size, 16):
            if (x // 16 + y // 16) % 2:
                draw.rectangle((x, y, x + 15, y + 15), fill="#3f4c53")
    base_upper = Image.alpha_composite(layer("base"), layer("upper"))
    frames = []
    for pose in range(28):
        shadow = layer("shadow", pose)
        shadow.putalpha(shadow.getchannel("A").point(lambda value: round(value * .35)))
        colors = Image.alpha_composite(base_upper, layer("rotor", pose))
        frames.append(Image.alpha_composite(Image.alpha_composite(background, shadow), colors))
    info = PngImagePlugin.PngInfo()
    for key, value in metadata["png_color_profile_chunks"].items():
        info.add(key.encode("ascii"), bytes.fromhex(value))
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 16) if font_path.is_file() else ImageFont.load_default()
    heading = 30
    contact = Image.new("RGBA", (4 * canvas_size, 7 * (canvas_size + heading)), "#182127")
    draw = ImageDraw.Draw(contact)
    for pose, frame in enumerate(frames):
        x, y = pose % 4 * canvas_size, pose // 4 * (canvas_size + heading)
        contact.paste(frame, (x, y + heading))
        state = "P / parked" if pose == 0 else "R / running" if pose == 1 else "spin-up" if pose <= 11 else "spin-down"
        draw.text((x + 8, y + 6), f"physical {pose + 1:02} / {state}", font=font, fill="#dce8e9")
    contact.save(output / "physical-28.png", optimize=True, pnginfo=info)

    def delays(count, ticks):
        duration = ticks * 1000 / 60
        return [round((i + 1) * duration / count) - round(i * duration / count) for i in range(count)]

    def animated(name, sequence, durations):
        images = [frames[index - 1] for index in sequence]
        path = output / (name + ".png")
        images[0].save(path, save_all=True, append_images=images[1:], duration=durations,
                       loop=0, disposal=0, blend=0, optimize=True, pnginfo=info)
        # APNG may merge identical consecutive frames. Decode every stored frame
        # and validate total timing; no palette or lossy image conversion is used.
        with Image.open(path) as image:
            total = 0
            for i in range(image.n_frames):
                image.seek(i)
                total += image.info["duration"]
            assert abs(total - sum(durations)) < 1e-6
        return {"file": path.name, "logical_sequence": sequence, "duration_ms": sum(durations),
                "requested_delays_ms": durations, "lossless_encoding": "RGBA APNG"}

    up, down = metadata["sequences"]["preparing"], metadata["sequences"]["folding"]
    up_delays = delays(len(up), metadata["preparing_ticks"])
    down_delays = delays(len(down), metadata["folding_ticks"])
    animations = {
        "spin_up": animated("spin-up", up, up_delays),
        "spin_down": animated("spin-down", down, down_delays),
        "cycle": animated("spin-cycle", [1] + up + [2] + down + [1],
                          [500] + up_delays + [500] + down_delays + [500]),
    }
    report = {**signature, "preparing_ticks": metadata["preparing_ticks"], "folding_ticks": metadata["folding_ticks"],
              "native_smoothness_accepted": False, "animations": animations,
              "preview_shadow_opacity_factor": .35, "shipping_payload": False,
              "timing": "60 Hz target; integer-millisecond boundary rounding preserves complete transition durations",
              "isolated_transition_loop_note": "Spin-up/down loops jump back to their starting endpoint; the complete cycle contains both transitions and endpoint holds."}
    (output / "review-report.json").write_text(json.dumps(report, indent=2) + "\n")
    (output / "index.html").write_text(f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>Minigun motion review</title>
<style>body{{background:#182127;color:#dce8e9;font:16px/1.5 system-ui;max-width:1400px;margin:32px auto;padding:0 24px}}img{{max-width:100%}}a{{color:#9acedd}}.row{{display:flex;gap:24px;flex-wrap:wrap}}</style>
<h1>Direction {args.direction:03} / {density} pixels per tile</h1><p>Nonshipping reconstruction from the packed layers. Spin-up {metadata['preparing_ticks']} ticks; spin-down 18 ticks. Native timing and smoothness acceptance remain separate. Shadow preview opacity is 35%.</p>
<h2>Complete cycle with endpoint holds</h2><img src="spin-cycle.png" alt="Parked, spin-up, running, spin-down, parked cycle">
<div class="row"><div><h2>Spin-up</h2><img src="spin-up.png" alt="Spin-up transition"></div><div><h2>Spin-down</h2><img src="spin-down.png" alt="Spin-down transition"></div></div>
<p>These individual transition loops jump back to their first endpoint; inspect the complete cycle for continuity.</p>
<h2>All 28 physical poses</h2><a href="physical-28.png"><img src="physical-28.png" alt="All 28 physical poses"></a><p><a href="review-report.json">Timing and provenance report</a></p></html>''', encoding="utf-8")
    print("MOTION_REVIEW " + json.dumps({"output": str(output), "animations": animations}), flush=True)


if __name__ == "__main__":
    main()
