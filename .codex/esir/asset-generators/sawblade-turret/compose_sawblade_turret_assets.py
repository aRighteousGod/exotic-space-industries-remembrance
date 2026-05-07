import argparse
import json
import math
import random
import re
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ASSET_NAME = "ei-sawblade-turret"
ENTITY_NAME = "sawblade-turret"


def parse_args():
    parser = argparse.ArgumentParser(description="Compose Oathbreaker Saw Factorio sprites from rendered frames.")
    parser.add_argument("--out", required=True, help="Output staging directory.")
    parser.add_argument("--preset-render-dir", help="Render folder produced by render_factorio_preset.py.")
    parser.add_argument("--full-render-dir", help="One-frame full turret preset render for icons and shadows.")
    parser.add_argument("--body-render-dir", help="One-frame body-only preset render for the entity base.")
    parser.add_argument("--blade-render-dir", help="Blade-only preset render for static and attack runtime overlays.")
    parser.add_argument("--promote", action="store_true", help="Copy composed sprites to the main mod graphics folder.")
    parser.add_argument("--graphics-root", default=None, help="Path to exotic-space-industries-remembrance/graphics.")
    parser.add_argument("--frame-size", type=int, default=512)
    parser.add_argument("--frames", type=int, default=64)
    parser.add_argument(
        "--attack-frame-order",
        choices=("reverse", "forward"),
        default="reverse",
        help="Order used for attack frames. Reverse anchors frame 0, then walks backward to flip spin without an attack-start snap.",
    )
    return parser.parse_args()


def natural_key(path):
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", path.name)]


def frame_files(folder):
    return sorted([path for path in folder.glob("*.png") if path.is_file()], key=natural_key)


def alpha_bbox(image):
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    return image.getchannel("A").getbbox()


def paste_centered(canvas, image):
    x = (canvas.width - image.width) // 2
    y = (canvas.height - image.height) // 2
    canvas.alpha_composite(image, (x, y))


def fit_to_square(image, size, padding):
    image = image.convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox:
        image = image.crop(bbox)
    max_side = size - padding * 2
    scale = min(max_side / image.width, max_side / image.height)
    new_size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    image = image.resize(new_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    paste_centered(canvas, image)
    return canvas


def make_drop_shadow(image, offset, blur, alpha):
    mask = image.getchannel("A")
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", image.size, (0, 0, 0, alpha))
    shadow_layer.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
    shadow.alpha_composite(shadow_layer, offset)
    shadow.alpha_composite(image)
    return shadow


def composite_layers(*layers):
    if not layers:
        raise ValueError("At least one icon layer is required")
    size = layers[0].size
    icon = Image.new("RGBA", size, (0, 0, 0, 0))
    for layer in layers:
        if layer.size != size:
            raise ValueError(f"Icon layer size mismatch: {layer.size}, expected {size}")
        icon.alpha_composite(layer.convert("RGBA"))
    return icon


def sharpen_icon(image):
    image = ImageEnhance.Contrast(image).enhance(1.12)
    image = ImageEnhance.Sharpness(image).enhance(1.35)
    return image


def compose_sheet(frame_dir, entity_dir, frame_size, frames, prefix, output_name):
    sheet = Image.new("RGBA", (frame_size * 8, frame_size * math.ceil(frames / 8)), (0, 0, 0, 0))
    for frame in range(frames):
        image = Image.open(frame_dir / f"{prefix}_{frame:03d}.png").convert("RGBA")
        x = frame_size * (frame % 8)
        y = frame_size * (frame // 8)
        sheet.alpha_composite(image, (x, y))
    path = entity_dir / output_name
    sheet.save(path)
    return path


def compose_sheet_from_paths(frame_paths, entity_dir, output_name, columns=8):
    if not frame_paths:
        raise FileNotFoundError(f"No preset frames available for {output_name}")
    first = Image.open(frame_paths[0]).convert("RGBA")
    frame_w, frame_h = first.size
    rows = math.ceil(len(frame_paths) / columns)
    sheet = Image.new("RGBA", (frame_w * columns, frame_h * rows), (0, 0, 0, 0))
    for frame, path in enumerate(frame_paths):
        image = Image.open(path).convert("RGBA")
        if image.size != (frame_w, frame_h):
            raise ValueError(f"Frame size mismatch: {path} is {image.size}, expected {(frame_w, frame_h)}")
        x = frame_w * (frame % columns)
        y = frame_h * (frame // columns)
        sheet.alpha_composite(image, (x, y))
    out_path = entity_dir / output_name
    sheet.save(out_path)
    return out_path, (frame_w, frame_h)


def order_attack_frames(frame_paths, frame_order):
    frame_paths = list(frame_paths)
    if frame_order == "forward" or len(frame_paths) <= 2:
        return frame_paths
    if frame_order == "reverse":
        return [frame_paths[0]] + list(reversed(frame_paths[1:]))
    raise ValueError(f"Unsupported attack frame order: {frame_order}")


def compose_empty_sheet(frame_size, frame_count, entity_dir, output_name, columns=8):
    rows = math.ceil(frame_count / columns)
    sheet = Image.new("RGBA", (frame_size[0] * columns, frame_size[1] * rows), (0, 0, 0, 0))
    out_path = entity_dir / output_name
    sheet.save(out_path)
    return out_path


def compose_attack_sheet(frame_dir, entity_dir, frame_size, frames):
    return compose_sheet(frame_dir, entity_dir, frame_size, frames, "attack", "sawblade-turret-attack.png")


def compose_attack_shadow_sheet(frame_dir, entity_dir, frame_size, frames):
    shadow = compose_sheet(
        frame_dir,
        entity_dir,
        frame_size,
        frames,
        "attack_shadow",
        "sawblade-turret-attack-shadow.png",
    )
    return normalize_shadow_sprite(shadow)


def normalize_shadow_sprite(path):
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A").filter(ImageFilter.GaussianBlur(0.65))
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda value: min(255, int(value * 0.88))))
    shadow.save(path)
    return path


def make_item_icon(static_image, icon_dir):
    icon = fit_to_square(static_image, 64, 4)
    icon = make_drop_shadow(icon, (1, 2), 1.2, 115)
    icon = sharpen_icon(icon)
    path = icon_dir / "sawblade-turret.png"
    icon.save(path)
    return path


def make_tech_underlay(size=256):
    underlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(underlay, "RGBA")
    draw.ellipse((10, 12, 246, 248), fill=(22, 22, 24, 245), outline=(140, 138, 128, 170), width=4)
    for index in range(18):
        theta = math.tau * index / 18
        cx, cy = 128, 130
        inner = 58
        outer = 119
        p1 = (cx + math.cos(theta - 0.025) * inner, cy + math.sin(theta - 0.025) * inner)
        p2 = (cx + math.cos(theta) * outer, cy + math.sin(theta) * outer)
        p3 = (cx + math.cos(theta + 0.025) * inner, cy + math.sin(theta + 0.025) * inner)
        draw.polygon([p1, p2, p3], fill=(190, 188, 174, 55))
    return underlay


def make_tech_entity_layer(static_image, size=256):
    fitted = fit_to_square(static_image, 256, 24)
    fitted = ImageEnhance.Contrast(fitted).enhance(1.08)
    return make_drop_shadow(fitted, (3, 5), 2.2, 150)


def make_tech_icons(static_image, tech_dir):
    underlay = make_tech_underlay()
    entity = make_tech_entity_layer(static_image)
    icon = composite_layers(underlay, entity)

    underlay_path = tech_dir / "sawblade-turret-underlay.png"
    entity_path = tech_dir / "sawblade-turret-entity.png"
    icon_path = tech_dir / "sawblade-turret-preview.png"
    underlay.save(underlay_path)
    entity.save(entity_path)
    icon.save(icon_path)
    return {
        "tech": icon_path,
        "tech_underlay": underlay_path,
        "tech_entity": entity_path,
    }


def make_impact_sheet(entity_dir):
    frame_size = 128
    frames = 16
    sheet = Image.new("RGBA", (frame_size * 8, frame_size * 2), (0, 0, 0, 0))
    for frame in range(frames):
        progress = frame / (frames - 1)
        fade = 1.0 - progress
        image = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image, "RGBA")
        rng = random.Random(9001 + frame)
        radius = 26 + progress * 28
        for arc in range(3):
            start = -35 + arc * 78 + progress * 55
            end = start + 52 + progress * 22
            alpha = int(210 * fade)
            color = (210, 210, 205, alpha) if arc != 1 else (255, 190, 72, int(180 * fade))
            box = (
                64 - radius - arc * 7,
                62 - radius * 0.70 - arc * 4,
                64 + radius + arc * 7,
                62 + radius * 0.70 + arc * 4,
            )
            draw.arc(box, start=start, end=end, fill=color, width=max(1, int(5 - progress * 3)))

        for _ in range(16):
            theta = rng.uniform(0, math.tau)
            distance = rng.uniform(10, 18 + progress * 46)
            length = rng.uniform(4, 13) * fade
            x = 64 + math.cos(theta) * distance
            y = 63 + math.sin(theta) * distance * 0.68
            x2 = x + math.cos(theta) * length
            y2 = y + math.sin(theta) * length * 0.68
            spark_alpha = int(rng.uniform(90, 230) * fade)
            spark_color = (255, rng.randint(150, 230), rng.randint(60, 105), spark_alpha)
            draw.line((x, y, x2, y2), fill=spark_color, width=1)

        for _ in range(7):
            x = 64 + rng.uniform(-36, 36) * progress
            y = 64 + rng.uniform(-24, 24) * progress
            debris_alpha = int(130 * fade)
            draw.rectangle((x, y, x + 2, y + 1), fill=(150, 150, 145, debris_alpha))

        image = image.filter(ImageFilter.GaussianBlur(0.18))
        x = frame_size * (frame % 8)
        y = frame_size * (frame // 8)
        sheet.alpha_composite(image, (x, y))

    path = entity_dir / "sawblade-turret-impact.png"
    sheet.save(path)
    return path


def promote(staged, graphics_root):
    graphics_root = Path(graphics_root)
    targets = {
        staged["body"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret.png",
        staged["body_shadow"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret-shadow.png",
        staged["blade"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret-blade.png",
        staged["attack"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret-attack.png",
        staged["attack_shadow"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret-attack-shadow.png",
        staged["impact"]: graphics_root / "entities" / "sawblade-turret" / "sawblade-turret-impact.png",
        staged["icon"]: graphics_root / "items" / "sawblade-turret.png",
        staged["tech_underlay"]: graphics_root / "techs" / "sawblade-turret-underlay.png",
        staged["tech_entity"]: graphics_root / "techs" / "sawblade-turret-entity.png",
    }
    for source, target in targets.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return targets


def first_frame(render_dir, pass_name):
    paths = frame_files(Path(render_dir) / pass_name)
    if not paths:
        raise FileNotFoundError(f"No {pass_name} frames found in {render_dir}")
    return paths[0]


def composite_static_preview(body_image, blade_image):
    preview = Image.new("RGBA", body_image.size, (0, 0, 0, 0))
    preview.alpha_composite(body_image)
    preview.alpha_composite(blade_image)
    return preview


def main():
    args = parse_args()
    out = Path(args.out)
    preset_render_dir = Path(args.preset_render_dir) if args.preset_render_dir else None
    full_render_dir = Path(args.full_render_dir) if args.full_render_dir else preset_render_dir
    body_render_dir = Path(args.body_render_dir) if args.body_render_dir else None
    blade_render_dir = Path(args.blade_render_dir) if args.blade_render_dir else None
    frame_dir = out / "rendered-frames"
    entity_dir = out / "entities"
    icon_dir = out / "icons"
    tech_dir = out / "tech"
    entity_dir.mkdir(parents=True, exist_ok=True)
    icon_dir.mkdir(parents=True, exist_ok=True)
    tech_dir.mkdir(parents=True, exist_ok=True)

    if body_render_dir and blade_render_dir:
        body_frame = first_frame(body_render_dir, "Object")
        blade_frames = frame_files(blade_render_dir / "Object")
        if len(blade_frames) < args.frames:
            raise FileNotFoundError(f"Expected at least {args.frames} blade frames in {blade_render_dir / 'Object'}")

        static_body = Image.open(body_frame).convert("RGBA")
        static_path = entity_dir / "sawblade-turret.png"
        static_body.save(static_path)

        static_blade = Image.open(blade_frames[0]).convert("RGBA")
        blade_static_path = entity_dir / "sawblade-turret-blade.png"
        static_blade.save(blade_static_path)

        if full_render_dir:
            full_object = Image.open(first_frame(full_render_dir, "Object")).convert("RGBA")
            shadow_source = first_frame(full_render_dir, "Shadow")
        else:
            full_object = composite_static_preview(static_body, static_blade)
            shadow_source = first_frame(body_render_dir, "Shadow")

        static_shadow_path = entity_dir / "sawblade-turret-shadow.png"
        Image.open(shadow_source).convert("RGBA").save(static_shadow_path)
        normalize_shadow_sprite(static_shadow_path)

        attack_path, frame_size = compose_sheet_from_paths(
            order_attack_frames(blade_frames[:args.frames], args.attack_frame_order),
            entity_dir,
            "sawblade-turret-attack.png",
        )
        attack_shadow_path = compose_empty_sheet(
            frame_size,
            args.frames,
            entity_dir,
            "sawblade-turret-attack-shadow.png",
        )
        composed_frame_size = list(frame_size)
        static_image = full_object
    elif preset_render_dir:
        object_frames = frame_files(preset_render_dir / "Object")
        shadow_frames = frame_files(preset_render_dir / "Shadow")
        if len(object_frames) < args.frames:
            raise FileNotFoundError(f"Expected at least {args.frames} object frames in {preset_render_dir / 'Object'}")
        if len(shadow_frames) < args.frames:
            raise FileNotFoundError(f"Expected at least {args.frames} shadow frames in {preset_render_dir / 'Shadow'}")

        static_image = Image.open(object_frames[0]).convert("RGBA")
        static_path = entity_dir / "sawblade-turret.png"
        static_image.save(static_path)

        blade_static_path = entity_dir / "sawblade-turret-blade.png"
        Image.new("RGBA", static_image.size, (0, 0, 0, 0)).save(blade_static_path)

        static_shadow_path = entity_dir / "sawblade-turret-shadow.png"
        Image.open(shadow_frames[0]).convert("RGBA").save(static_shadow_path)
        normalize_shadow_sprite(static_shadow_path)

        attack_path, frame_size = compose_sheet_from_paths(
            order_attack_frames(object_frames[:args.frames], args.attack_frame_order),
            entity_dir,
            "sawblade-turret-attack.png",
        )
        attack_shadow_path = compose_empty_sheet(
            frame_size,
            args.frames,
            entity_dir,
            "sawblade-turret-attack-shadow.png",
        )
        composed_frame_size = list(frame_size)
    else:
        static_image = Image.open(frame_dir / "body.png").convert("RGBA")
        static_path = entity_dir / "sawblade-turret.png"
        static_image.save(static_path)
        blade_static_path = entity_dir / "sawblade-turret-blade.png"
        Image.open(frame_dir / "blade.png").convert("RGBA").save(blade_static_path)
        static_shadow_path = entity_dir / "sawblade-turret-shadow.png"
        Image.open(frame_dir / "body_shadow.png").convert("RGBA").save(static_shadow_path)
        normalize_shadow_sprite(static_shadow_path)
        attack_path = compose_attack_sheet(frame_dir, entity_dir, args.frame_size, args.frames)
        attack_shadow_path = compose_attack_shadow_sheet(frame_dir, entity_dir, args.frame_size, args.frames)
        composed_frame_size = [args.frame_size, args.frame_size]

    tech_icons = make_tech_icons(static_image, tech_dir)

    staged = {
        "body": static_path,
        "body_shadow": static_shadow_path,
        "blade": blade_static_path,
        "attack": attack_path,
        "attack_shadow": attack_shadow_path,
        "impact": make_impact_sheet(entity_dir),
        "icon": make_item_icon(static_image, icon_dir),
    }
    staged.update(tech_icons)

    manifest = {
        "asset": ASSET_NAME,
        "frame_size": composed_frame_size,
        "frames": args.frames,
        "line_length": 8,
        "preset_render_dir": str(preset_render_dir) if preset_render_dir else None,
        "full_render_dir": str(full_render_dir) if full_render_dir else None,
        "body_render_dir": str(body_render_dir) if body_render_dir else None,
        "blade_render_dir": str(blade_render_dir) if blade_render_dir else None,
        "attack_composition": "runtime blade layer: body sprite is blade-less, idle uses a static blade render, attack swaps to the blade-only 64-frame loop",
        "attack_frame_order": args.attack_frame_order,
        "attack_shadow": "empty by design; avoid full-body rotating attack shadows",
        "staged": {key: str(path) for key, path in staged.items()},
    }
    if args.promote:
        if not args.graphics_root:
            raise SystemExit("--graphics-root is required when using --promote")
        targets = promote(staged, args.graphics_root)
        manifest["promoted"] = {str(source): str(target) for source, target in targets.items()}

    (out / "compose-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
