import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageFilter


def parse_args():
    parser = argparse.ArgumentParser(description="Create aligned emerald crystal/glass glow overlays from rendered object frames.")
    parser.add_argument("--object-dir", required=True, help="Render/Object directory.")
    parser.add_argument("--out-dir", required=True, help="Output overlay frame directory.")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--threshold", type=float, default=0.28)
    parser.add_argument("--soft-threshold", type=float, default=0.18)
    parser.add_argument("--min-green", type=int, default=52)
    parser.add_argument("--max-red-ratio", type=float, default=0.86)
    parser.add_argument("--blue-balance", type=float, default=0.46)
    parser.add_argument("--alpha-scale", type=float, default=1.30)
    parser.add_argument("--core-alpha", type=float, default=0.82)
    parser.add_argument("--halo-radius", type=float, default=2.2)
    parser.add_argument("--halo-alpha", type=float, default=0.34)
    parser.add_argument("--color", default="50,255,178", help="Overlay RGB, comma-separated.")
    parser.add_argument("--pack-sheets", action="store_true", help="Pack generated frames into multi-sheet stripes.")
    parser.add_argument("--sheets-dir", help="Output sheet directory. Defaults to <out-dir>/.Sheets.")
    parser.add_argument("--grid", default="4x4", help="Sheet grid as CxR, e.g. 4x4.")
    parser.add_argument("--sheet-prefix", default="emerald_crystal_glow", help="Packed sheet filename prefix.")
    return parser.parse_args()


def parse_rgb(raw):
    parts = [int(part.strip()) for part in raw.split(",")]
    if len(parts) != 3:
        raise ValueError("--color must contain three comma-separated integers")
    return tuple(max(0, min(255, value)) for value in parts)


def emerald_score(r, g, b, a, args):
    if a <= 0 or g < args.min_green:
        return 0.0
    rf = r / 255.0
    gf = g / 255.0
    bf = b / 255.0
    af = a / 255.0
    if rf > gf * args.max_red_ratio:
        return 0.0
    cool = max(0.0, gf - rf * 1.08)
    cyan = max(0.0, min(gf, bf + args.blue_balance * gf) - rf * 0.72)
    saturation = max(rf, gf, bf) - min(rf, gf, bf)
    brightness = (rf + gf + bf) / 3.0
    score = cool * 0.56 + cyan * 0.34 + saturation * 0.22 + brightness * 0.16
    return max(0.0, min(1.0, score * af))


def smoothstep(edge0, edge1, value):
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def process_frame(path, out_path, args, rgb):
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    mask = Image.new("L", (width, height), 0)
    mask_pixels = mask.load()
    source_pixels = image.load()
    selected = 0
    score_sum = 0.0
    for y in range(height):
        for x in range(width):
            r, g, b, a = source_pixels[x, y]
            score = emerald_score(r, g, b, a, args)
            alpha = smoothstep(args.soft_threshold, args.threshold, score)
            if alpha <= 0.0:
                continue
            value = int(max(0, min(255, alpha * 255 * args.alpha_scale)))
            mask_pixels[x, y] = value
            selected += 1
            score_sum += score
    core = Image.new("RGBA", (width, height), rgb + (0,))
    core_alpha = mask.point(lambda value: int(max(0, min(255, value * args.core_alpha))))
    core.putalpha(core_alpha)
    halo = Image.new("RGBA", (width, height), rgb + (0,))
    halo_alpha = mask.filter(ImageFilter.GaussianBlur(args.halo_radius)).point(
        lambda value: int(max(0, min(255, value * args.halo_alpha)))
    )
    halo.putalpha(halo_alpha)
    output = Image.alpha_composite(halo, core)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(out_path)
    bbox = output.getchannel("A").getbbox()
    return {
        "frame": path.name,
        "selected_pixels": selected,
        "mean_score": round(score_sum / selected, 6) if selected else 0.0,
        "alpha_bbox": list(bbox) if bbox else None,
    }


def parse_grid(raw):
    left, right = raw.lower().split("x", 1)
    columns = int(left)
    rows = int(right)
    if columns <= 0 or rows <= 0:
        raise ValueError("--grid values must be positive")
    return columns, rows


def pack_frames(frame_paths, sheets_dir, grid, prefix):
    columns, rows = grid
    frames_per_sheet = columns * rows
    first = Image.open(frame_paths[0]).convert("RGBA")
    tile_w, tile_h = first.size
    sheets_dir.mkdir(parents=True, exist_ok=True)
    records = []
    for sheet_index, start in enumerate(range(0, len(frame_paths), frames_per_sheet)):
        sheet_paths = frame_paths[start : start + frames_per_sheet]
        sheet = Image.new("RGBA", (tile_w * columns, tile_h * rows), (0, 0, 0, 0))
        for local_index, path in enumerate(sheet_paths):
            frame = Image.open(path).convert("RGBA")
            if frame.size != (tile_w, tile_h):
                raise ValueError(f"Frame size mismatch: {path} is {frame.size}, expected {(tile_w, tile_h)}")
            col = local_index % columns
            row = local_index // columns
            sheet.alpha_composite(frame, (col * tile_w, row * tile_h))
        suffix = "_0" if sheet_index == 0 else f"_0_{sheet_index}"
        output = sheets_dir / f"{prefix}{suffix}.png"
        sheet.save(output)
        records.append(
            {
                "path": str(output.resolve()),
                "size": [sheet.width, sheet.height],
                "frames": [path.name for path in sheet_paths],
            }
        )
    return {"tile_size": [tile_w, tile_h], "grid": [columns, rows], "sheets": records}


def main():
    args = parse_args()
    rgb = parse_rgb(args.color)
    object_dir = Path(args.object_dir)
    out_dir = Path(args.out_dir)
    frames = sorted(object_dir.glob("*.png"))
    if not frames:
        raise SystemExit(f"No PNG frames found in {object_dir}")
    records = []
    generated_paths = []
    for frame in frames:
        out_path = out_dir / frame.name
        records.append(process_frame(frame, out_path, args, rgb))
        generated_paths.append(out_path)
    packed_sheets = None
    if args.pack_sheets:
        sheets_dir = Path(args.sheets_dir) if args.sheets_dir else out_dir / ".Sheets"
        packed_sheets = pack_frames(generated_paths, sheets_dir, parse_grid(args.grid), args.sheet_prefix)
    manifest = {
        "kind": "emerald_apocalypse_pixel_crystal_glow_overlay",
        "object_dir": str(object_dir.resolve()),
        "out_dir": str(out_dir.resolve()),
        "frame_count": len(records),
        "settings": {
            "threshold": args.threshold,
            "soft_threshold": args.soft_threshold,
            "min_green": args.min_green,
            "max_red_ratio": args.max_red_ratio,
            "blue_balance": args.blue_balance,
            "alpha_scale": args.alpha_scale,
            "core_alpha": args.core_alpha,
            "halo_radius": args.halo_radius,
            "halo_alpha": args.halo_alpha,
            "color": list(rgb),
        },
        "frames": records,
        "packed_sheets": packed_sheets,
        "note": "Derived from object frames so the overlay is perfectly aligned and cannot include hidden geometry. It selects emerald/cyan crystal and glass pixels, avoiding bronze/black hull casing.",
    }
    manifest_path = Path(args.manifest)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"overlay_frames={len(records)}")
    print(f"manifest={manifest_path.resolve()}")


if __name__ == "__main__":
    main()
