"""Fit a single rotating barrel outlet to user marks on the shipping head atlas."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("points", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.points.read_text(encoding="utf-8"))
    atlas_path = Path("exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret/acidthrower-head.png")
    digest = hashlib.sha256(atlas_path.read_bytes()).hexdigest()
    assert digest == data["atlas_sha256"], "Marks belong to a different head atlas"
    atlas = Image.open(atlas_path).convert("RGBA")
    q = math.sqrt(.5)
    rows, values = [], []
    for point in data["points"]:
        phi = point["head_frame"] * math.tau / 256
        rows.extend([[math.sin(phi), 0], [-q * math.cos(phi), -q]])
        values.extend([(v - 128) / 64 for v in point["head_pixel"]])
    length, height = np.linalg.lstsq(rows, values, rcond=None)[0]
    least_squares = {"barrel_length_tiles": float(length), "muzzle_height_tiles": float(height)}
    # Minimise the worst marked-pose error, so a small RMS cannot hide one
    # direction outside the one-native-pixel calibration target. The objective
    # is convex; refine a small two-parameter grid about the least-squares fit.
    matrix = np.array(rows)
    for exponent in range(7):
        step = .003 / 10**exponent
        ll, hh = np.meshgrid(length+np.arange(-50,51)*step, height+np.arange(-50,51)*step)
        parameters = np.stack((ll.ravel(),hh.ravel()),axis=1)
        errors = (parameters @ matrix.T - values).reshape(-1,len(data["points"]),2)*32
        best = np.argmax(np.sum(errors**2,axis=2),axis=1)
        worst = np.sum(errors**2,axis=2)[np.arange(len(parameters)),best]
        length,height = parameters[np.argmin(worst)]
    fitted = (np.array(rows) @ [length, height]).reshape(-1, 2) * 64 + 128
    residuals = (fitted - [p["head_pixel"] for p in data["points"]]) * .5
    result = {"calibration_id": data["calibration_id"], "atlas_sha256": digest,
              "model": "x=L*sin(frame*tau/256); y=-sqrt(.5)*(L*cos(frame*tau/256)+H)",
              "barrel_length_tiles": float(length), "muzzle_height_tiles": float(height),
              "projected_height_tiles": float(q * height),
              "objective": "minimise maximum marked-pose error in native pixels",
              "least_squares_reference": least_squares,
              "rms_native_pixels": float(np.sqrt(np.mean(np.sum(residuals**2, axis=1)))),
              "max_native_pixels": float(np.max(np.linalg.norm(residuals, axis=1))),
              "points": [{**p, "fitted_head_pixel": list(f), "residual_native_pixels": list(r),
                          "error_native_pixels": float(np.linalg.norm(r))}
                         for p, f, r in zip(data["points"], fitted, residuals)]}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "origin-fit.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    # Technical atlas annotations; shipping pixels and sprites remain unchanged.
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 19)
    small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
    gallery = Image.new("RGB", (1110, 1145), (29, 31, 30))
    draw = ImageDraw.Draw(gallery)
    draw.text((15, 10), "Grey nozzle calibration: + your mark   O single rotating fit", font=font, fill=(241, 241, 232))
    draw.text((15, 40), f"RMS {result['rms_native_pixels']:.2f} native px; worst {result['max_native_pixels']:.2f} native px", font=small, fill=(203, 211, 204))
    for i, point in enumerate(result["points"]):
        frame = point["head_frame"]
        cell = atlas.crop((frame % 16 * 256, frame // 16 * 256, frame % 16 * 256 + 256, frame // 16 * 256 + 256))
        # Uniform crop about head, with exact four-times-native pixel enlargement.
        crop = (48, 30, 208, 174)
        tile = Image.new("RGBA", (320, 288), (39, 42, 39, 255))
        tile.alpha_composite(cell.crop(crop).resize((320, 288), Image.Resampling.NEAREST))
        td = ImageDraw.Draw(tile)
        mx, my = [(point["head_pixel"][j] - crop[j]) * 2 for j in range(2)]
        fx, fy = [(point["fitted_head_pixel"][j] - crop[j]) * 2 for j in range(2)]
        td.ellipse((fx-6, fy-6, fx+6, fy+6), outline=(69, 222, 255), width=2)
        td.line((mx-9, my, mx+9, my), fill=(255, 162, 69), width=2)
        td.line((mx, my-9, mx, my+9), fill=(255, 162, 69), width=2)
        x, y = i % 3 * 370 + 15, i // 3 * 355 + 80
        gallery.paste(tile.convert("RGB"), (x, y+30))
        draw.text((x,y), f"{point['view']}  frame {frame}  error {point['error_native_pixels']:.2f}px", font=font, fill=(241,241,232))
    gallery.save(args.output / "marked-pose-fit.png")
    print(json.dumps({k:v for k,v in result.items() if k != "points"}, indent=2))


if __name__ == "__main__":
    main()
