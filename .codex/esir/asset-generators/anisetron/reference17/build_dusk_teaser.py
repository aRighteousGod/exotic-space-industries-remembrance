"""Compose approved 128-heading passes into a simulated dusk review, not a game capture."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import time

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    started = time.monotonic()
    size, count, duration, ambient = 768, 128, 50, .56
    scale, pivot = 1.9, (330, 610)
    # Body and glow are unlifted; the rendered shadow already used raised casters.
    hover_raw_pixels = (1.8 + .625) * 32 / 1.25
    rng = random.Random(17)
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            grain = rng.randrange(-3, 4)
            center = max(0, 1 - math.hypot((x - 365) / 610, (y - 445) / 720))
            tone = int(22 + 7 * center + 3 * y / size) + grain
            pixels.extend((tone, tone + 2, tone + 1))
    background = Image.frombytes('RGB', (size, size), bytes(pixels)).convert('RGBA')
    pool = Image.new('RGBA', (size, size))
    draw = ImageDraw.Draw(pool)
    draw.ellipse((215, 557, 448, 640), fill=(10, 164, 137, 38))
    pool = pool.filter(ImageFilter.GaussianBlur(32))
    background = Image.alpha_composite(background, pool)
    raw_size = int(round(512 * scale))
    left = round(pivot[0] - 256 * scale)
    top = round(pivot[1] - 256 * scale)
    frames, sources = [], {}
    for i in range(count):
        name = f'{i + 1:04}.png'
        paths = {role: args.bundle / folder / name for role, folder in
                 [('body', 'Object'), ('shadow', 'Shadow'), ('glow', 'Light A Reduced')]}
        images = {role: Image.open(path).convert('RGBA') for role, path in paths.items()}
        assert all(im.size == (512, 512) for im in images.values())
        sources[str(i)] = {role: sha256(path) for role, path in paths.items()}
        frame = background.copy()
        shadow = images['shadow'].resize((raw_size, raw_size), Image.Resampling.LANCZOS)
        shadow.putalpha(shadow.getchannel('A').point(lambda v: int(v * .85)))
        frame.alpha_composite(shadow, (left, top))
        bob = math.sin(2 * math.pi * i / count) * 1.5
        body_top = round(top - (hover_raw_pixels + bob) * scale)
        body = images['body']
        body = Image.merge('RGBA', (*ImageEnhance.Brightness(body.convert('RGB')).enhance(ambient).split(),
                                   body.getchannel('A')))
        body = body.resize((raw_size, raw_size), Image.Resampling.LANCZOS)
        frame.alpha_composite(body, (left, body_top))
        glow = images['glow'].resize((raw_size, raw_size), Image.Resampling.LANCZOS)
        halo = glow.filter(ImageFilter.GaussianBlur(5))
        halo.putalpha(halo.getchannel('A').point(lambda v: int(v * .35)))
        frame.alpha_composite(halo, (left, body_top))
        frame.alpha_composite(glow, (left, body_top))
        frames.append(frame.convert('RGB'))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    poster = args.output.with_name(args.output.stem + '-poster.png')
    frames[64].save(poster)
    quality = 76
    while True:
        frames[0].save(args.output, format='WEBP', save_all=True, append_images=frames[1:],
                       duration=duration, loop=0, quality=quality, method=2,
                       lossless=False, minimize_size=False, kmin=9, kmax=17)
        if args.output.stat().st_size <= 10_000_000:
            break
        quality -= 12
        assert quality >= 28, 'Could not satisfy the 10MB cap'
    check = Image.open(args.output)
    assert check.n_frames == count and check.size == (size, size)
    assert check.info.get('loop') == 0
    encoded_duration = 0
    for i in range(check.n_frames):
        check.seek(i)
        check.load()
        encoded_duration += check.info.get('duration', 0)
    assert encoded_duration == count * duration
    record = {
        'kind': 'simulated dusk sprite composite; not a Factorio engine capture',
        'source_bundle': args.bundle.as_posix(), 'source_pass_hashes': sources,
        'source_render_manifest_sha256': sha256(args.bundle / 'factorio-preset-render-manifest.json'),
        'canvas': [size, size], 'direction_count': count,
        'heading_order': 'Native clockwise N rear, E, S facade, W; exact directions 0..127',
        'frame_duration_ms': duration, 'total_duration_ms': encoded_duration,
        'loop': 0, 'webp_quality': quality, 'bytes': args.output.stat().st_size,
        'sha256': sha256(args.output), 'poster_sha256': sha256(poster),
        'ambient_body_factor': ambient, 'glow': 'full approved original crystal emission pass',
        'shadow': 'approved shadow pass already rendered with 1.8-tile raised casters',
        'presentation': {'raw_scale': scale, 'ground_pivot': list(pivot),
                         'body_lift_raw_pixels': hover_raw_pixels,
                         'subtle_bob_raw_pixels': 1.5,
                         'terrain': 'seeded low-contrast neutral charcoal ground',
                         'pool': 'soft teal ground illumination'},
        'replay': 'python .codex/esir/asset-generators/anisetron/reference17/build_dusk_teaser.py '
                  '--bundle output/meshy/anisetron/reference17/prepared-v2/full128 '
                  '--output output/meshy/anisetron/reference17/anisetron17-dusk-teaser.webp',
        'elapsed_seconds': round(time.monotonic() - started, 2),
    }
    report = args.output.with_suffix('.json')
    report.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: record[key] for key in
                      ('bytes', 'sha256', 'direction_count', 'total_duration_ms', 'elapsed_seconds')}, indent=2))
    print(args.output)
    print(poster)
    print(report)


if __name__ == '__main__':
    main()
