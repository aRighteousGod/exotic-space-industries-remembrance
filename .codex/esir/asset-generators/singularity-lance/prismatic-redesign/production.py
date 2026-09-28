"""Production Prismatic Liturgy sheets; deterministic and staging-only.

Replay beside generate.py. Native beam bodies tile horizontally; finite caps,
engine-followed wounds and timed collapses retain separate semantic/glow layers.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import generate as study

TAU = math.tau


def beam(kind, part, phase):
    width, height = (256, 96) if part == 'body' else (192, 160)
    yy, xx = np.mgrid[:height, :width].astype(np.float64)
    u = xx / (width - 1)
    y = (yy - (height - 1) / 2) / 48
    wave = .028 * np.sin(u * TAU * 3 - phase)
    envelope = np.ones_like(u)
    if part != 'body':
        # Native BeamGraphicsSet caps inherit the original generator's direction:
        # head grows toward +X, tail fades toward +X (the engine places each cap).
        travel = 1 - u if part == 'head' else u
        envelope = np.cos(travel * math.pi / 2) ** .65
        envelope *= np.clip(np.minimum(u, 1-u) / .065, 0, 1)
    band = ((.48 if kind == 'testament' else .34) + .035 * np.sin(u * TAU * 4 - phase * 2)) * envelope
    offset = (y - wave * envelope) / np.maximum(.018, band)
    caustic = .62 + .38 * np.sin(u * TAU * 7 + y * 16 - phase * 2) ** 2
    alpha = np.exp(-offset ** 4) * .83 * caustic * envelope
    rgb = study.spectrum(offset * .65, phase + .6 * np.sin(u * TAU * 2))
    core = np.exp(-(y / (.023 + .026 * envelope)) ** 2) * envelope
    rgb = study.mix(rgb, (255, 246, 203), core * .92)
    alpha = np.maximum(alpha, core)
    if kind == 'axial':
        edge = np.exp(-((np.abs(y) - band * 1.09) / .020) ** 2) * envelope
        rgb = study.mix(rgb, (0, 230, 255), edge * .96)
        alpha = np.maximum(alpha, edge)
    else:
        gap = (.12 + .010 * np.sin(u * TAU * 5 - phase)) * envelope
        rim = np.exp(-((np.abs(y) - gap) / .020) ** 2) * envelope
        rgb = study.mix(rgb, (255, 240, 228), rim)
        alpha = np.maximum(alpha, rim)
        void = (np.abs(y) < gap * .64) & (envelope > .12)
        rgb[void], alpha[void] = (3, 1, 10), .99
    # Coherent fine tails and moving motes are pixels, never particle entities.
    for k in range(4):
        trail = (.5 + .5 * np.sin(u * TAU * 2 - phase + k * 1.7)) ** 5
        side = -1 if k % 2 else 1
        ribbon = side * (.45 + k * .028 + .047 * np.sin(u * TAU * 3 - phase + k))
        filament = np.exp(-((y - ribbon * envelope) / .012) ** 2) * trail * envelope
        rgb = study.mix(rgb, study.PALETTE[0 if side < 0 else 2], filament)
        alpha = np.maximum(alpha, filament * .85)
        mote = np.exp(-((y - side * .65 * envelope) / .022) ** 2)
        mote *= (.5 + .5 * np.sin(u * TAU * 3 - phase + k)) ** 80 * envelope * .62
        rgb = study.mix(rgb, study.PALETTE[5], mote)
        alpha = np.maximum(alpha, mote)
    alpha *= np.clip((height / 96 - np.abs(y)) / .16, 0, 1)
    result = study.rgba(rgb, alpha)
    if part == 'body':
        # Identical endpoints avoid a one-code-value floating-point seam.
        result.paste(result.crop((0, 0, 1, height)), (width-1, 0))
    return result


def glow(core, tile=False):
    if not tile:
        return study.glow(core)
    width, height = core.size
    expanded = Image.new('RGBA', (width*3, height))
    for i in range(3):
        expanded.paste(core, (i*width, 0))
    result = study.glow(expanded).crop((width, 0, width*2, height))
    result.paste(result.crop((0, 0, 1, height)), (width-1, 0))
    return result


def wound(band, phase):
    core = study.wound(band, phase, 192)
    pixels = np.array(core)
    x, y, radius, _ = study.field(192)
    # Reduce the blunt branch tips of the study while retaining the three bands.
    edge = np.clip((.88-radius)/.15, 0, 1)
    pixels[..., 3] = (pixels[..., 3] * edge).astype(np.uint8)
    return Image.fromarray(pixels)


def crown(t):
    x, y, r, angle = study.field(192)
    radius = .40 + .40*t
    rays = (.5 + .5*np.cos(angle*7))**8
    alpha = np.exp(-((r-radius)/.05)**2) * rays * (1-t)**1.2
    return study.rgba(study.spectrum(np.sin(angle), t*TAU), alpha)


def clean_crystal(source):
    crop = source.crop((78, 8, 176, 108))
    pixels = np.array(crop)
    pixels[(pixels[..., 1].astype(float) > pixels[..., 2]*1.08), 3] = 0
    mask = pixels[..., 3] > 16
    seen = set(); largest = []
    for y, x in zip(*np.where(mask)):
        if (y, x) in seen:
            continue
        stack = [(int(y), int(x))]; component = []; seen.add((y, x))
        while stack:
            cy, cx = stack.pop(); component.append((cy, cx))
            for dy, dx in [(0,1),(0,-1),(1,0),(-1,0)]:
                ny, nx = cy+dy, cx+dx
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny,nx] and (ny,nx) not in seen:
                    seen.add((ny,nx)); stack.append((ny,nx))
        if len(component) > len(largest):
            largest = component
    keep = np.zeros(mask.shape, dtype=np.uint8)
    for y,x in largest:
        keep[y,x] = 255
    keep = np.array(Image.fromarray(keep).filter(ImageFilter.MaxFilter(3)))
    pixels[...,3] = np.minimum(pixels[...,3],keep)
    return Image.fromarray(pixels).resize((112,126),Image.Resampling.LANCZOS)


def icon(kind, source, effect_source):
    body = Image.new('RGBA',(256,256))
    body.alpha_composite(source.crop((0,96,256,256)).resize((192,120),Image.Resampling.LANCZOS),(32,131))
    crystal = clean_crystal(source)
    if kind == 0:
        body.alpha_composite(crystal,(72,20))
    elif kind == 1:
        body.alpha_composite(crystal.crop((0,0,56,126)),(64,20))
        body.alpha_composite(crystal.crop((56,0,112,126)),(136,34))
    else:
        for i in range(3):
            shard = crystal.resize((42,58),Image.Resampling.LANCZOS).rotate(i*120+25,resample=Image.Resampling.BICUBIC,expand=True)
            a = i*TAU/3-.5
            body.alpha_composite(shard,(int(128+52*math.cos(a)-shard.width/2),int(92+52*math.sin(a)-shard.height/2)))
    effect = Image.new('RGBA',(256,256))
    if kind == 0:
        art = effect_source.resize((248,66),Image.Resampling.LANCZOS).rotate(38,resample=Image.Resampling.BICUBIC,expand=True)
        effect.alpha_composite(art,((256-art.width)//2,(256-art.height)//2-12))
    else:
        effect.alpha_composite(effect_source.resize((224,224),Image.Resampling.LANCZOS),(16,-12))
    composed = body.copy(); composed.alpha_composite(effect)
    return body,effect,composed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path('output/meshy/lance-prismatic-liturgy/production'))
    parser.add_argument('--repo',type=Path,default=Path.cwd())
    args = parser.parse_args(); out = args.output; export = out/'factorio-export'
    export.mkdir(parents=True,exist_ok=True)
    sequences = {f'beam-{kind}-{part}':[beam(kind,part,i/16*TAU) for i in range(16)]
                 for kind in ['axial','testament'] for part in ['body','head','tail']}
    sequences.update({f'wound-{band}':[wound(band,i/24*TAU) for i in range(24)] for band in [1,2,3]})
    sequences['wound-crown'] = [crown(i/11) for i in range(12)]
    for kind in ['collapse','testament']:
        for part, count in [('warning',30),('impact',12)]:
            sequences[f'{kind}-{part}'] = [study.collapse(kind=='testament',part=='impact',i/(count-1),256) for i in range(count)]
    manifest = {}; atlas_bytes = 0
    for key, frames in sequences.items():
        w,h = frames[0].size; columns = 4 if key.startswith('beam') else 6
        size = (w*columns,h*math.ceil(len(frames)/columns)); atlas_bytes += size[0]*size[1]*4*2
        tile = key.endswith('body'); layers = []
        for suffix in ['', '-glow']:
            sheet = Image.new('RGBA',size)
            for i,frame in enumerate(frames):
                sheet.paste(glow(frame,tile) if suffix else frame,((i%columns)*w,(i//columns)*h))
            path = export/f'{key}{suffix}.png'; sheet.save(path)
            layers.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        manifest[key] = {'width':w,'height':h,'frames':len(frames),'columns':columns,'tile_x':tile,'layers':layers}
    source = Image.open(args.repo/'exotic-space-industries-remembrance-graphics-4/graphics/techs/singularity-lance.png').convert('RGBA')
    names = ['axial-rupture','wound-memory','terminal-collapse','black-hole-testament']
    effects = [study.beam('axial',1.7),wound(3,1.7),sequences['collapse-warning'][6],sequences['testament-warning'][5]]
    icons = []
    for i,(name,effect) in enumerate(zip(names,effects)):
        body,phenomenon,composed = icon(i,source,effect)
        body.save(export/f'{name}-mineral.png'); phenomenon.save(export/f'{name}-phenomenon.png')
        composed.save(out/f'{name}.png'); icons.append(composed)
    board = Image.new('RGB',(1280,1060),(10,15,24)); d = ImageDraw.Draw(board)
    d.text((24,18),'PRISMATIC LITURGY / production sheets',font=study.font(30),fill='white')
    for i,im in enumerate(icons):
        board.paste(im,(32+i*312,65),im)
        d.text((30+i*312,324),names[i],font=study.font(16),fill=(193,211,223))
        for j,size in enumerate([64,32]):
            small=im.resize((size,size),Image.Resampling.LANCZOS);board.paste(small,(40+i*312+j*90,355),small)
    for row,kind in enumerate(['axial','testament']):
        for col in range(4):
            core=sequences[f'beam-{kind}-body'][4]
            board.paste(study.composite(core),(120+col*256,455+row*115))
        d.text((26,481+row*115),kind,font=study.font(16),fill='white')
    for i,key in enumerate(['wound-1','wound-2','wound-3','collapse-warning','testament-warning']):
        art=sequences[key][5].resize((224,224),Image.Resampling.LANCZOS)
        board.paste(study.composite(art,bg=(48,55,45)),(20+i*252,720))
        d.text((24+i*252,952),key,font=study.font(16),fill='white')
    d.text((24,1001),'Periodic beam material / original mineral emblems / separate semantic and glow layers',font=study.font(20),fill=(151,176,193))
    board.save(out/'production-board.png')
    # Actual production frames at useful normal-scale sizes, with glow on/off.
    preview=[]
    for tick in range(64):
        im=Image.new('RGB',(1024,580),(32,39,34)); d=ImageDraw.Draw(im)
        d.text((22,14),'Production material / frame '+str(tick),font=study.font(21),fill='white')
        for row,kind in enumerate(['axial','testament']):
            core=sequences[f'beam-{kind}-body'][tick%16]
            for col in range(4):
                im.paste(study.composite(core,bloom=row==0,bg=(32,39,34)),(col*256,55+row*104))
        for i in range(3):
            im.paste(study.composite(sequences[f'wound-{i+1}'][tick%24],bg=(32,39,34)),(10+i*195,305))
        for i,kind in enumerate(['collapse','testament']):
            local=tick%64
            if local<42:
                key=kind+('-warning' if local<30 else '-impact');frame=local if local<30 else local-30
                im.paste(study.composite(sequences[key][frame],bg=(32,39,34)).resize((208,208)),(602+i*210,298))
        preview.append(im)
    preview[0].save(out/'production-motion.webp',save_all=True,append_images=preview[1:],duration=33,loop=0,quality=90,method=4)
    (out/'manifest.json').write_text(json.dumps({'sequences':manifest,'rgba_atlas_bytes':atlas_bytes,
        'core_atlas_bytes':atlas_bytes//2,'icons':names,'source':'production.py + generate.py',
        'warning_reference_radius_pixels':.775*128,'wound_world_canvas_tiles':2},indent=2)+'\n',encoding='utf-8')
    print(f'{out}: {len(sequences)} sequences; RGBA atlas {atlas_bytes/1024**2:.2f} MiB, Lean {atlas_bytes/2/1024**2:.2f} MiB')


if __name__ == '__main__':
    main()
