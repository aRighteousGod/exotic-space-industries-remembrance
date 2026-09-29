"""Dedicated Prismatic Liturgy source apertures; deterministic, staging-only.

Run from the repository root. Reuses the approved material equations, not the
regular lance's opening pixels. Native beam start layers supply position/motion.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw


def opening(kind, phase, study):
    yy, xx = np.mgrid[:160, :192].astype(np.float64)
    u, y = xx / 191, (yy - 79.5) / 48
    # A broad source aperture narrows into the existing forward-running material.
    # Finite edge fades keep the native endpoint overlay free of rectangular cuts.
    aperture = np.exp(-((u - .39) / .24) ** 2)
    envelope = np.clip(u / .10, 0, 1) ** .7 * np.clip((1-u) / .10, 0, 1) ** .7
    wave = .028 * np.sin(u * math.tau * 3 - phase)
    band = (.48 if kind == 'testament' else .34) + .57 * aperture
    band *= 1 + .045 * np.sin(u * math.tau * 4 - phase * 2)
    d = y - wave
    offset = d / band
    flow = .67 + .33 * np.sin(u * math.tau * 7 + y * 16 - phase * 2) ** 2
    alpha = np.exp(-offset ** 4) * .88 * flow
    rgb = study.spectrum(offset * .65, phase + .6 * np.sin(u * math.tau * 2))
    if kind == 'axial':
        core = np.exp(-(d / (.047 + .055 * aperture)) ** 2)
        rgb = study.mix(rgb, (255, 246, 203), core * .96)
        alpha = np.maximum(alpha, core)
        edges = np.exp(-((np.abs(d) - band * 1.05) / .025) ** 2)
        rgb = study.mix(rgb, (0, 235, 255), edges * .95)
        alpha = np.maximum(alpha, edges)
    else:
        gap = .12 + .25 * aperture + .008 * np.sin(u * math.tau * 5 - phase)
        rim = np.exp(-((np.abs(d) - gap) / .028) ** 2)
        rgb = study.mix(rgb, (255, 238, 247), rim)
        alpha = np.maximum(alpha, rim)
        void = np.abs(d) < gap * .70
        rgb[void], alpha[void] = (3, 1, 10), .99
    # A swept collar makes the emitter legible, then opens into the forward ray.
    radius = np.sqrt(((u-.38)/.19) ** 2 + (d/(band*1.04)) ** 2)
    collar = np.exp(-((radius-1)/.043) ** 2)
    collar *= np.clip((.65-u)/.22, 0, 1) * (.7+.3*np.sin(phase+y*7)**2)
    rgb = study.mix(rgb, (206, 249, 255) if kind == 'axial' else (245, 210, 255), collar * .8)
    alpha = np.maximum(alpha, collar)
    # Moving saturated streamers and gold knots remain baked into the two layers.
    for k in range(4):
        side = -1 if k % 2 else 1
        path = side * (band * (1.07+k*.045) + .035*np.sin(u*math.tau*3-phase+k))
        travel = (.5+.5*np.sin(u*math.tau*2-phase+k*1.7)) ** 5
        strand = np.exp(-((d-path)/.014)**2) * travel
        rgb = study.mix(rgb, study.PALETTE[0 if side < 0 else 2], strand)
        alpha = np.maximum(alpha, strand*.88)
        knot = np.exp(-((d-side*band*.83)/.025)**2)
        knot *= (.5+.5*np.sin(u*math.tau*3-phase+k))**60
        rgb = study.mix(rgb, (255, 231, 89), knot)
        alpha = np.maximum(alpha, knot*.9)
    margin = np.minimum.reduce([xx, yy, 191-xx, 159-yy])
    alpha *= envelope * np.clip(margin/9, 0, 1)
    return study.rgba(rgb, alpha)


def preview(frames, kind, index, production, study, glow, scale):
    # Material-comparison staging only; native cap placement remains a game check.
    row = Image.new('RGBA', (960, 160))
    for i in range(4):
        body = production.beam(kind, 'body', index/16*math.tau)
        row.alpha_composite(body, (112+i*256, 32))
    row.alpha_composite(frames[index], (0, 0))
    if glow:
        row.alpha_composite(study.glow(frames[index]), (0, 0))
    return row.resize((round(row.width*scale), round(row.height*scale)), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    parser.add_argument('--output', type=Path, default=Path('output/meshy/lance-prismatic-liturgy/origins'))
    args = parser.parse_args()
    sys.path.insert(0, str(args.repo/'.codex/esir/asset-generators/singularity-lance/prismatic-redesign'))
    import generate as study
    import production
    out, export = args.output, args.output/'factorio-export'
    export.mkdir(parents=True, exist_ok=True)
    manifest = {'frames': 16, 'frame_size': [192,160], 'columns': 4, 'animation_speed': .55,
        'scale': .34, 'branch_scale': .65, 'rgba_atlas_bytes': 768*640*4*4,
        'placement': 'native BeamGraphicsSet.beam.start; no extra entities',
        'manual': ['crystal alignment', 'native start-to-body transition', 'fork brightness'], 'sequences': {}}
    all_frames = {}
    for kind in ['axial', 'testament']:
        frames = [opening(kind, i/16*math.tau, study) for i in range(16)]
        assert len({frame.tobytes() for frame in frames}) == 16
        all_frames[kind] = frames
        layers = []
        for suffix in ['', '-glow']:
            sheet = Image.new('RGBA', (768,640))
            for i, frame in enumerate(frames):
                layer = study.glow(frame) if suffix else frame
                a = np.array(layer)[...,3]
                assert not np.any(a[0]) and not np.any(a[-1]) and not np.any(a[:,0]) and not np.any(a[:,-1])
                sheet.paste(layer, ((i%4)*192, (i//4)*160))
            path = export/f'beam-{kind}-start{suffix}.png'
            sheet.save(path)
            layers.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        metrics = []
        for i, frame in enumerate(frames):
            pixels = np.array(frame)
            solid = pixels[...,3] > 128
            old = np.array(production.beam(kind, 'tail', i/16*math.tau))[...,3] > 128
            height, old_height = int(solid.sum(axis=0).max()), int(old.sum(axis=0).max())
            assert height >= old_height*1.4, (kind, i, height, old_height)
            if kind == 'testament':
                assert ((pixels[...,3]>200) & (pixels[...,:3].sum(axis=2)<25)).sum() > 500
            metrics.append({'frame': i, 'solid_height': height, 'prior_tail_solid_height': old_height})
        manifest['sequences'][kind] = {'layers': layers, 'qa': metrics}
    board = Image.new('RGB', (1140,800), (9,15,24)); draw = ImageDraw.Draw(board)
    draw.text((24,18), 'PRISMATIC LITURGY / dedicated origin apertures', font=study.font(27), fill='white')
    draw.text((24,57), 'Own animated starts; approved body material retained. Native placement needs gameplay review.', font=study.font(16), fill=(178,201,222))
    for row, kind in enumerate(['axial','testament']):
        y = 110+row*330
        draw.text((24,y), kind.upper(), font=study.font(22), fill='white')
        strip = Image.new('RGBA',(768,160))
        for col, i in enumerate([0,4,8,12]): strip.alpha_composite(all_frames[kind][i],(col*192,0))
        board.paste(strip, (220,y), strip)
        for col, (bg, mode, use_glow) in enumerate([((12,20,32),'night / Standard',True),((58,64,44),'day / Lean',False)]):
            x, yy = 24+col*554, y+180
            draw.rectangle((x,yy,x+530,yy+94),fill=bg)
            draw.text((x+10,yy+7), mode+' / scale .34',font=study.font(15),fill='white')
            im=preview(all_frames[kind],kind,4,production,study,use_glow,.34)
            board.paste(im,(x+16,yy+33),im)
    board.save(out/'origin-board.png')
    animation = []
    for i in range(16):
        canvas = Image.new('RGB',(1050,360),(9,15,24)); d = ImageDraw.Draw(canvas)
        for row,kind in enumerate(['axial','testament']):
            d.text((20,row*170+12),kind+' / source and body material',font=study.font(19),fill='white')
            im=preview(all_frames[kind],kind,i,production,study,True,1)
            canvas.paste(im,(20,row*170+40),im)
        animation.append(canvas)
    animation[0].save(out/'origin-motion.webp',save_all=True,append_images=animation[1:],duration=61,loop=0,lossless=True)
    (out/'origin-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'new_sheets':4,'unique_frames':32,'edge_qa':'passed','silhouette_qa':'passed','output':str(out)}))


if __name__ == '__main__':
    main()
