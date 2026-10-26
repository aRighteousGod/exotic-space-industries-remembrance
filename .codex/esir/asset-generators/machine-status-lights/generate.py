"""Extract neutral native-status lenses from the existing red/green sprite pixels.

No source image is rewritten. Review --output before copying its PNGs into the
main mod. Coordinates come from the same curated registry used by both stages.
"""
import argparse
import hashlib
import json
import re
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[4]
registry = repo / 'exotic-space-industries-remembrance/lib/machine-status-light-definitions.lua'
args.output.mkdir(parents=True, exist_ok=True)
rows = re.findall(r'\["(ei-[^"]+)"\] = (\{\{[^\n]+)', registry.read_text())
records, previews = [], []


def expand(support, distance):
    """Chebyshev neighbourhood in source pixels, without wrapping at the edge."""
    for _ in range(distance):
        padded = np.pad(support, 1)
        support = np.logical_or.reduce([padded[y:y + 64, x:x + 64]
                                        for y in range(3) for x in range(3)])
    return support


for name, coordinates in rows:
    stem = name.removeprefix('ei-')
    sources = list(repo.glob(f'exotic-space-industries-remembrance-graphics-*/graphics/entities/{stem}.png'))
    assert len(sources) == 1, (name, sources)
    base_path = sources[0]
    animation_path = base_path.with_stem(stem + '_animation')
    base, animation = Image.open(base_path).convert('RGBA'), Image.open(animation_path).convert('RGBA')
    width, height = base.size
    points = [(int(x), int(y)) for x, y in re.findall(r'\{(\d+), (\d+)\}', coordinates)]
    frames = [base] + [animation.crop((x, y, x + width, y + height))
                      for y in range(0, animation.height, height)
                      for x in range(0, animation.width, width)]
    for index, (cx, cy) in enumerate(points, 1):
        support = np.zeros((64, 64), dtype=bool)
        brightness = np.zeros((64, 64), dtype=np.uint8)
        frame_counts = []
        crops = [np.array(frame.crop((cx - 32, cy - 32, cx + 32, cy + 32)))
                 for frame in frames]
        # Castor's ribbed lenses have dark red/green grooves; the brighter bodies
        # use a strict core threshold to exclude reflected colored process light.
        minimum, difference = (60, 30) if name == 'ei-castor' else (180, 80)
        for pixels in crops:
            rgb = pixels[:, :, :3].astype(np.int16)
            red = (rgb[:, :, 0] > minimum) & (rgb[:, :, 0] - rgb[:, :, 1] > difference) & (rgb[:, :, 0] - rgb[:, :, 2] > difference)
            green = (rgb[:, :, 1] > minimum) & (rgb[:, :, 1] - rgb[:, :, 0] > difference) & (rgb[:, :, 1] - rgb[:, :, 2] > difference)
            colored = red | green
            if name == 'ei-advanced-refinery':
                # The requested indicator is the whole inset display, including
                # its constant cyan quadrants, rather than its old red corner.
                colored = (rgb.max(axis=2) > 100) & (rgb.max(axis=2) - rgb.min(axis=2) > 25)
            candidates = set(zip(*np.where(colored & (pixels[:, :, 3] > 128))))
            components = []
            while candidates:
                seed = candidates.pop()
                group, queue = [seed], deque([seed])
                while queue:
                    y, x = queue.popleft()
                    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                        neighbour = (y + dy, x + dx)
                        if neighbour in candidates:
                            candidates.remove(neighbour)
                            group.append(neighbour)
                            queue.append(neighbour)
                if len(group) >= 3:
                    distance = min((x - 32) ** 2 + (y - 32) ** 2 for y, x in group)
                    if distance <= 25:
                        components.append((distance, group))
            if not components:
                frame_counts.append(0)
                continue
            group = min(components, key=lambda pair: pair[0])[1]
            frame_counts.append(len(group))
            for y, x in group:
                support[y, x] = True
                brightness[y, x] = max(brightness[y, x], int(rgb[y, x].max()))
        assert support.any() and frame_counts[0] > 0, (name, index, frame_counts)
        seed_pixels = int(support.sum())
        original = crops[0].astype(np.int16)
        working = np.stack(crops[1:]).astype(np.int16)
        # A hue change identifies the actual lamp, including dim antialiasing,
        # without recoloring unchanged bronze casing or distant process glow.
        changes_color = ((original[:, :, 0] - original[:, :, 1] > 4)
                         & ((working[:, :, :, 1] - working[:, :, :, 0]).max(axis=0) > 4)
                         & (original[:, :, 3] > 128)
                         & (working[:, :, :, 3].max(axis=0) > 128))
        bright_red = ((original[:, :, 0] > 180)
                      & (original[:, :, 0] - original[:, :, 1] > 80)
                      & (original[:, :, 0] - original[:, :, 2] > 80))
        # Large ribbed lamps have a disconnected bright upper rim. Gather it
        # before their fringe; a nearest-component-only mask leaves a red line.
        support |= bright_red & changes_color & expand(support, 5)
        support |= changes_color & expand(support, 3)
        if name == 'ei-advanced-refinery':
            # Include the cyan screen's antialiasing without reaching the nearby
            # illuminated pipe. The nearest connected display defines the core.
            all_rgb = np.stack(crops)[:, :, :, :3].astype(np.int16)
            screen_edge = ((all_rgb.max(axis=3) > 30)
                           & (all_rgb.max(axis=3) - all_rgb.min(axis=3) > 8)).any(axis=0)
            support |= screen_edge & expand(support, 2)
        lens_pixels = int(support.sum())
        # Opaque one-pixel coverage beyond the colored footprint prevents native
        # texture filtering from reintroducing red at the overlay boundary.
        support = expand(support, 1)
        brightness = np.maximum(original[:, :, :3].max(axis=2),
                                working[:, :, :, :3].max(axis=(0, 3))).astype(np.uint8)
        yy, xx = np.where(support)
        assert min(xx) > 0 and min(yy) > 0 and max(xx) < 63 and max(yy) < 63, (name, 'clipped lens')
        mask = np.zeros((64, 64, 4), dtype=np.uint8)
        mask[:, :, :3] = brightness[:, :, None]
        mask[:, :, 3] = support.astype(np.uint8) * 255
        image = Image.fromarray(mask)
        filename = f'{stem}-{index}.png'
        image.save(args.output / filename, optimize=True)
        records.append(dict(name=name, index=index, center=[cx, cy], file=filename,
            size=[64, 64], seed_pixels=seed_pixels, lens_pixels=lens_pixels,
            opaque_pixels=int(support.sum()), edge_guard_pixels=1, frame_pixels=frame_counts,
            coverage='whole-screen' if name == 'ei-advanced-refinery' else 'status-lens',
            bounds=[int(min(xx)), int(min(yy)), int(max(xx)), int(max(yy))],
            sources=[dict(path=str(p.relative_to(repo)), sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                     for p in (base_path, animation_path)],
            sha256=hashlib.sha256((args.output / filename).read_bytes()).hexdigest()))
        original = base.crop((cx - 32, cy - 32, cx + 32, cy + 32))
        previews.append((f'{stem}-{index}', original, image))
assert len(records) == 23
canvas = Image.new('RGB', (1000, 60 + len(previews) * 105), '#242424')
draw = ImageDraw.Draw(canvas)
for x, label in ((5, 'Lens'), (240, 'Original'), (380, 'Neutral mask'), (520, 'Green'), (660, 'Yellow'), (800, 'Orange')):
    draw.text((x, 12), label, fill='white')
for row, (label, original, mask) in enumerate(previews):
    y = 45 + row * 105
    draw.text((5, y + 40), label, fill='white')
    for col, tint in enumerate((None, None, (0.08, 1, .12), (1, 1, 0), (1, .5, 0))):
        image = original if col == 0 else mask
        if tint:
            pixels = np.array(mask).copy()
            pixels[:, :, :3] = (pixels[:, :, :3] * np.array(tint)).astype(np.uint8)
            image = Image.alpha_composite(original, Image.fromarray(pixels))
        image = image.resize((96, 96), Image.Resampling.NEAREST)
        canvas.paste(image, (240 + col * 140, y), image)
canvas.save(args.output / 'lens-review.png')
(args.output / 'manifest.json').write_text(json.dumps(dict(records=records), indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(lenses=len(records), bodies=len(rows), output=str(args.output))))
