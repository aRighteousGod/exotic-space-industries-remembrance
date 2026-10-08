"""Pack reviewed Meshy passes, source-derived icons, and native muzzle framing.

--preview stages an eight-view engine draft; it never promotes shipping art.
The final path requires all 64 frames and checks every nonempty alpha margin.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bundle', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
    count = 8 if args.preview else 64
    assert manifest['directions'] == count
    assert manifest['animation_frames'] == 1
    framing = manifest['preflight']
    scale = framing['anisetron_sprite_scale']
    (args.output/'graphics/entities/anisetron').mkdir(parents=True, exist_ok=True)
    (args.output/'graphics/items').mkdir(parents=True, exist_ok=True)
    (args.output/'graphics/technology').mkdir(parents=True, exist_ok=True)
    roles = {'anisetron': 'Object', 'anisetron_shadow': 'Shadow',
             'anisetron_glow': 'Light A Reduced', 'anisetron_mask': 'ColorMask'}
    results = []
    # Draft starts at180; final starts at0. Draft resampling is only for engine
    # behavior tests while the complete directional render runs independently.
    phase = 4 if args.preview else 0
    for name, folder in roles.items():
        images = [Image.open(args.bundle/folder/f'{i+1:04}.png').convert('RGBA') for i in range(count)]
        sheet = Image.new('RGBA', (4096,4096))
        for direction in range(64):
            index = (round(direction/8)+phase)%8 if args.preview else direction
            frame = images[index]
            assert frame.size == (512,512)
            bbox = frame.getchannel('A').getbbox()
            margin = min(bbox[0],bbox[1],512-bbox[2],512-bbox[3]) if bbox else None
            if bbox: assert margin >=16, (name,direction,bbox)
            results.append({'role':name,'direction':direction,'alpha_bounds':bbox,'margin':margin})
            sheet.paste(frame, ((direction%8)*512,(direction//8)*512))
        sheet.save(args.output/'graphics/entities/anisetron'/f'{name}.png')
    # Vehicle icon uses its real facade view with baked PBR and crystal emission.
    front_index = 0 if args.preview else 32
    front = Image.open(args.bundle/'Object'/f'{front_index+1:04}.png').convert('RGBA')
    for folder in ('Light A Reduced','ColorMask'):
        front = Image.alpha_composite(front,Image.open(args.bundle/folder/f'{front_index+1:04}.png').convert('RGBA'))
    bounds = front.getchannel('A').getbbox()
    crystal_alpha = Image.open(args.bundle/'Light A Reduced'/f'{front_index+1:04}.png').convert('RGBA').getchannel('A').crop(bounds)
    front = front.crop(bounds)
    source = args.output/'vehicle-icon-source.png'; front.save(source)
    # A real faceted crystal from the chapel texture gives the paid charge its
    # family identity. Crop the front crystal; do not invent a new material.
    crystal_body = front.copy(); crystal_body.putalpha(crystal_alpha)
    charge = crystal_body.crop((int(front.width*.32),int(front.height*.27),int(front.width*.68),int(front.height*.70)))
    charge_source = args.output/'charge-icon-source.png'; charge.save(charge_source)
    helper = Path('.codex/skills/esir-item-icon-prep/scripts/build_factorio_item_icon.py')
    for name, original in (('anisetron',source),('anisetron-crystal-charge',charge_source)):
        subprocess.run([sys.executable,str(helper),'--source',str(original),'--output',
            str(args.output/'graphics/items'/f'{name}.png'),'--preview',str(args.output/f'{name}-preview.png')],check=True)
    tech = Image.new('RGBA',(256,256))
    subject = front.copy(); subject.thumbnail((232,232),Image.Resampling.LANCZOS)
    tech.alpha_composite(subject,((256-subject.width)//2,(256-subject.height)//2))
    tech.save(args.output/'graphics/technology/anisetron.png')
    # Locked camera coordinates are already projected. Native body height adds
    # the vehicle's1.8 separately; it is absent from this lookup and body render.
    points = framing['anisetron_muzzle_pixels']
    lookup = []
    if args.preview:
        reordered = [points[(i+phase)%8] for i in range(8)]
        center_y = (reordered[0]['muzzle'][1]+reordered[4]['muzzle'][1])/2
        radius_y = (reordered[4]['muzzle'][1]-reordered[0]['muzzle'][1])/2
        radius_x = reordered[2]['muzzle'][0]-256
        for i in range(64):
            theta = i*math.tau/64
            lookup.append([i/64,[radius_x*math.sin(theta)*scale/32,
                (center_y-radius_y*math.cos(theta)-256)*scale/32]])
    else:
        for point in points:
            lookup.append([point['direction']/64,[(point['muzzle'][j]-point['pivot'][j])*scale/32 for j in range(2)]])
    lua = ['-- blueprint: .codex/esir/blueprints/anisetron.md#contract',
        '-- Generated by .codex/esir/asset-generators/anisetron/package_meshy.py.',
        '-- Original facade aperture, clockwise64views; projected offsets in tiles.',
        'return {scale = %.9f, muzzle = {'%scale]
    lua += ['    {%.8f, {%.9f, %.9f}},'%(orientation,*vector) for orientation,vector in lookup]
    lua.append('}}')
    (args.output/'anisetron-graphics.lua').write_text('\n'.join(lua)+'\n')
    hashes = {str(p.relative_to(args.output)):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (args.output/'graphics').rglob('*.png')}
    (args.output/'asset-qc.json').write_text(json.dumps({'preview':args.preview,'directions':count,
        'scale':scale,'shift':[0,0],'muzzle_lookup':lookup,'alpha':results,'sha256':hashes},indent=2))
    print(json.dumps({'output':str(args.output),'preview':args.preview,'scale':scale,'roles':list(roles),'minimum_margin':min(r['margin'] for r in results if r['margin'] is not None)}))


if __name__ == '__main__':
    main()
