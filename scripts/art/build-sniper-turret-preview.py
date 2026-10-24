#!/usr/bin/env python3
"""Build a review gallery and pixel-bound checks from the sniper preset renders."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = Path('C:/Windows/Fonts/segoeui.ttf')
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def composite(body: Path, shadow: Path, background: str = '#292e32') -> Image.Image:
    with Image.open(body) as source:
        body_image = source.convert('RGBA')
    canvas = Image.new('RGBA', body_image.size, background)
    with Image.open(shadow) as source:
        shadow_image = source.convert('RGBA')
        shadow_image.putalpha(shadow_image.getchannel('A').point(lambda value: round(value * 0.42)))
        canvas.alpha_composite(shadow_image)
    canvas.alpha_composite(body_image)
    return canvas.convert('RGB')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--model', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    source_hash = hashlib.sha256(args.model.read_bytes()).hexdigest()
    variants = [p for p in ('preset-default', 'rail-fill') if (root / p / 'factorio-preset-render-manifest.json').exists()]
    if not variants:
        raise SystemExit('No completed preset renders found.')
    records = {}
    tiles = {}
    for profile in variants:
        folder = root / profile
        manifest = json.loads((folder / 'factorio-preset-render-manifest.json').read_text(encoding='utf-8'))
        bodies = sorted((folder / 'Object').glob('*.png'))
        shadows = sorted((folder / 'Shadow').glob('*.png'))
        if len(bodies) != manifest['frames'] or len(shadows) != manifest['frames']:
            raise SystemExit(f'Incomplete object/shadow frame count for {profile}.')
        evidence = []
        tiles[profile] = []
        for index, (body, shadow) in enumerate(zip(bodies, shadows), 1):
            with Image.open(body) as image:
                rgba = image.convert('RGBA')
                bounds = rgba.getchannel('A').getbbox()
                if bounds is None:
                    raise SystemExit(f'Empty render: {body}')
                margin = min(bounds[0], bounds[1], rgba.width - bounds[2], rgba.height - bounds[3])
                if margin < 16:
                    raise SystemExit(f'Clipped or low-margin render: {body}, {margin}px')
                evidence.append({'frame': index, 'size': list(rgba.size), 'alpha_bounds': list(bounds), 'minimum_margin_px': margin})
            with Image.open(shadow) as image:
                shadow_bounds = image.convert('RGBA').getchannel('A').getbbox()
                if shadow_bounds is None:
                    raise SystemExit(f'Empty shadow: {shadow}')
                shadow_margin = min(shadow_bounds[0], shadow_bounds[1], image.width - shadow_bounds[2], image.height - shadow_bounds[3])
                if shadow_margin < 16:
                    raise SystemExit(f'Clipped or low-margin shadow: {shadow}, {shadow_margin}px')
                evidence[-1].update({'shadow_alpha_bounds': list(shadow_bounds), 'shadow_minimum_margin_px': shadow_margin})
            frame = composite(body, shadow)
            output_name = f'{profile}-view-{index:02d}.jpg'
            frame.save(root / output_name, quality=94, subsampling=0)
            tiles[profile].append(frame)
        records[profile] = {'preflight_passed': manifest['preflight']['passed'], 'frame_count': len(bodies), 'frames': evidence,
                            'lighting': manifest['resolved_lighting'], 'material_lift': manifest['resolved_material_lift']}
        sheet = Image.new('RGB', (1920, 1120), '#1a1e21')
        draw = ImageDraw.Draw(sheet)
        draw.text((30, 20), f'SNIPER TURRET / PROTOTYPE 4 / {profile.upper()}', font=font(27), fill='#e5e2d9')
        draw.text((30, 60), 'Factorio preset | eight views | complete model rotation | separate baked shadows', font=font(18), fill='#aab5bc')
        for index, frame in enumerate(tiles[profile]):
            tile = frame.resize((460, 460), Image.Resampling.LANCZOS)
            x = 20 + (index % 4) * 475
            y = 105 + (index // 4) * 500
            sheet.paste(tile, (x, y))
            draw.text((x + 12, y + 464), f'VIEW {index + 1:02d} / rotation {-90 - index * 45} deg', font=font(17), fill='#ccd3d6')
        sheet.save(root / f'contact-sheet-{profile}.jpg', quality=94, subsampling=0)
        frames = [frame.resize((640, 640), Image.Resampling.LANCZOS) for frame in tiles[profile]]
        frames[0].save(root / f'turntable-{profile}.webp', save_all=True, append_images=frames[1:], duration=400, loop=0, quality=88)
    if len(variants) == 2:
        comparison = Image.new('RGB', (1560, 890), '#1a1e21')
        draw = ImageDraw.Draw(comparison)
        draw.text((25, 18), 'PROTOTYPE 4 / LIGHTING AND MATERIAL COMPARISON', font=font(27), fill='#e5e2d9')
        for index, profile in enumerate(variants):
            comparison.paste(tiles[profile][1], (12 + index * 780, 75))
            draw.text((30 + index * 780, 850), profile, font=font(22), fill='#ccd3d6')
        comparison.save(root / 'lighting-comparison.jpg', quality=94, subsampling=0)
    report = {'source': str(args.model.resolve()), 'source_sha256': source_hash, 'variants': records,
              'draft_only': True, 'gallery_shadow_opacity': 0.42, 'notes': ['Original GLB geometry and textures are read without modification.',
              'rail-fill is an alternate render with material and lighting adjustments.',
              'The source is a single mesh; preview rotation moves base and head together.']}
    (root / 'preview-qa.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    parts = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
             '<title>Sniper turret prototype 4 — preview renders</title>',
             '<style>body{margin:0;background:#171b1e;color:#dddcd5;font:17px/1.5 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px}h1{font-size:34px}h2{margin-top:45px}a{color:#c9d9eb}img{max-width:100%;border-radius:6px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:16px}figure{margin:0;background:#242a2e;padding:12px;border-radius:8px}figcaption{padding:8px;color:#b7c1c6}.turn{width:520px}.note{color:#a8b5be}</style>',
             '<main><h1>Sniper turret / prototype 4</h1><p>Eight orthographic views using the local Factorio lighting and shadow preset.</p>',
             '<p class="note">The source is one mesh. These previews rotate the complete model; base and head have not been separated. The brighter rail-fill alternative changes render materials and lighting. The original GLB is untouched.</p>']
    if len(variants) == 2:
        parts.append('<h2>Lighting comparison</h2><a href="lighting-comparison.jpg"><img src="lighting-comparison.jpg" alt="Default and brighter lighting comparison"></a>')
    for profile in variants:
        description = 'Imported materials with standard preset lighting.' if profile == 'preset-default' else 'Brighter alternate: stronger fill, rough nonmetallic material lift. Review against the original material appearance.'
        parts += [f'<h2>{html.escape(profile)}</h2><p>{description}</p>',
                  f'<a href="contact-sheet-{profile}.jpg"><img src="contact-sheet-{profile}.jpg" alt="Eight view contact sheet"></a>',
                  f'<p><img class="turn" src="turntable-{profile}.webp" alt="Eight view looping turntable"></p><div class="grid">']
        for index in range(len(tiles[profile])):
            filename = f'{profile}-view-{index + 1:02d}.jpg'
            transparent = f'{profile}/Object/{index + 1:04d}.png'
            parts.append(f'<figure><a href="{filename}"><img src="{filename}" alt="View {index + 1}"></a><figcaption>View {index + 1:02d} · <a href="{transparent}">transparent PNG</a></figcaption></figure>')
        parts.append('</div>')
    parts += ['<p><a href="preview-qa.json">Framing and source-hash evidence</a></p></main></html>']
    (root / 'preview-gallery.html').write_text('\n'.join(parts), encoding='utf-8')
    print(json.dumps({'gallery': str(root / 'preview-gallery.html'), 'variants': list(records), 'qa': 'passed'}, indent=2))


if __name__ == '__main__':
    main()
