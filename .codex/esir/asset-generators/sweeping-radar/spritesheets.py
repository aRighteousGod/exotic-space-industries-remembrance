"""Source-preserving radar sheet packaging and RGBA8 pixel verification.

Render masters remain uncropped at their original PNG precision. Shipping uses
the shared exporter's RGBA8 decode, then lossless packing. Every output facing
selects one master; packing never invents geometry or changes world scale.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import struct
import sys
from io import BytesIO
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path.cwd()
ASSETS = ('sweeping-radar', 'phased-array-radar')
ROLES = {'body': 'Object', 'shadow': 'Shadow', 'glow': 'Light A'}
SOURCE = ROOT / '.codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py'
spec = importlib.util.spec_from_file_location('esir_radar_export', SOURCE)
export = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = export
spec.loader.exec_module(export)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def relative(path):
    return Path(path).resolve().relative_to(ROOT.resolve()).as_posix()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def read_master(asset, verify=True):
    root = ROOT / 'output/meshy' / asset / 'master-256/Render'
    manifest_path = root / 'radar-master-manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    count = manifest['contract']['master_count']
    assert count == 256 and manifest['complete'], 'Render all 256 master facings before packing'
    assert set(manifest['frames']) == {str(n) for n in range(1, count + 1)}
    for folder in manifest['contract']['passes']:
        names = {p.name for p in (root / folder).glob('[0-9][0-9][0-9][0-9].png')}
        assert names == {f'{n:04d}.png' for n in range(1, count + 1)}, ('Missing or extra master frames', folder)
    if verify:
        for entry in manifest['frames'].values():
            for record in entry['passes'].values():
                data=(root / record['path']).read_bytes()
                assert hashlib.sha256(data).hexdigest() == record['sha256'], ('Master hash mismatch', record['path'])
                assert data[:8] == b'\x89PNG\r\n\x1a\n' and data[24:26] == bytes([16,6]), ('Expected retained RGBA16',record['path'])
                assert list(struct.unpack('>II',data[16:24])) == manifest['contract']['resolution']
    return root, manifest_path, manifest


def union(a, b):
    return [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])] if a else list(b)


def crop_contract(root, manifest):
    """Bounds use the complete master, so all reduced sets keep identical anchors."""
    groups = {'body': None, 'shadow': None}
    width, height = manifest['contract']['resolution']
    for folder in manifest['contract']['passes']:
        group = 'shadow' if folder == 'Shadow' else 'body'
        for frame in range(1, 257):
            with Image.open(root / folder / f'{frame:04d}.png') as image:
                assert image.mode == 'RGBA' and image.size == (width, height)
                bounds = image.getchannel('A').getbbox()
                assert bounds, ('Empty alpha', folder, frame)
                assert min(bounds[0], bounds[1], width-bounds[2], height-bounds[3]) >= 12, ('Master clipped', folder, frame)
                groups[group] = union(groups[group], bounds)
    for group, bounds in groups.items():
        groups[group] = [math.floor((bounds[0]-12)/8)*8, math.floor((bounds[1]-12)/8)*8,
                         math.ceil((bounds[2]+12)/8)*8, math.ceil((bounds[3]+12)/8)*8]
        left, top, right, bottom = groups[group]
        assert 0 <= left < right <= width and 0 <= top < bottom <= height
    return groups


def layer_lua(page, role, shift, scale):
    flags = ', draw_as_shadow=true' if role == 'shadow' else ', draw_as_light=true, blend_mode="additive"' if role == 'glow' else ''
    return ('{filename=graphics_path.."' + page['filename'] + '", width=' + str(page['frame_width'])
            + ', height=' + str(page['frame_height']) + ', line_length=' + str(page['columns'])
            + ', frame_count=' + str(page['frame_count']) + ', animation_speed=1, scale=' + str(scale)
            + ', shift={' + ','.join(f'{x:.9g}' for x in shift) + '}' + flags + '}')


def write_snippet(output, manifest):
    # Each page is <=128 frames: usable without a 256-entry frame_sequence.
    lines = ['-- Staged graphics only. No entity or runtime integration is performed.',
             '-- Returns animation layers for each ordered <=128-frame segment.',
             '-- Native radar orientation remains disabled; integration must select render frames.',
             '-- heading_index is relative to source yaw '
             + str(manifest['heading_contract']['initial_model_yaw_degrees'])
             + ' degrees, not calibrated north.',
             'return function(graphics_path)', '    return {']
    for index in range(len(manifest['layers']['body']['pages'])):
        body = manifest['layers']['body']; shadow = manifest['layers']['shadow']
        lines += ['        {', '            animation={layers={',
                  '                ' + layer_lua(body['pages'][index], 'body', body['shift'], manifest['scale']) + ',',
                  '                ' + layer_lua(shadow['pages'][index], 'shadow', shadow['shift'], manifest['scale']),
                  '            }},']
        if 'glow' in manifest['layers']:
            glow = manifest['layers']['glow']
            lines.append('            glow=' + layer_lua(glow['pages'][index], 'glow', glow['shift'], manifest['scale']) + ',')
        lines.append('        },')
    lines += ['    }', 'end', '']
    (output / (manifest['asset'] + '.animation-segments.lua')).write_text('\n'.join(lines), encoding='utf-8')


def pack(asset, facings):
    assert 1 <= facings <= 256 and 256 % facings == 0, 'Facings must divide the 256 master headings'
    root, source_manifest, master = read_master(asset)
    crops = crop_contract(root, master)
    selected = list(range(1, 257, 256 // facings))
    output = ROOT / 'output/meshy' / asset / 'factorio-export' / str(facings)
    output.mkdir(parents=True, exist_ok=True)
    scale = master['contract']['scale']
    anchor = master['contract']['source_anchor_pixels']
    manifest = dict(schema=1, asset=asset, prototype_name='ei-' + asset, status='staged-not-integrated',
        master_manifest=relative(source_manifest), master_manifest_sha256=sha(source_manifest),
        master_count=256, facings=facings, selected_source_frames=selected, scale=scale,
        heading_contract=dict(initial_model_yaw_degrees=-master['contract']['initial_angle'], clockwise_step_degrees=360/facings,
                              north_calibration='pending in-game integration', closing_pose_duplicated=False),
        source_anchor_pixels=anchor, layers={}, decoded_rgba_bytes=0, png_bytes=0,
        source_png_bit_depth=(root/'Object/0001.png').read_bytes()[24], output_png_bit_depth=8,
        conversion='Standard Pillow RGBA8 decode; original high-precision PNG masters are retained',
        crop_padding_pixels=12, allowed_pixel_difference='After RGBA8 decode: RGB where alpha is zero only')
    for role, folder in ROLES.items():
        if folder not in master['contract']['passes']:
            continue
        bounds = crops['shadow' if role == 'shadow' else 'body']
        left, top, right, bottom = bounds
        width, height = right-left, bottom-top
        shift = [((left+right)/2-anchor[0])*scale/32, ((top+bottom)/2-anchor[1])*scale/32]
        frames = []
        for frame in selected:
            source = root / folder / f'{frame:04d}.png'
            with Image.open(source) as image:
                stream = BytesIO(); image.crop(bounds).save(stream, format='PNG')
            frames.append(dict(name=f'{frame:04d}.png', source=relative(source), data=stream.getvalue()))
        columns = min(8, facings)
        rows = math.ceil(min(128, facings)/columns)
        pages = export.pack_frame_record_chunks(frames, target_name=f'{asset}-{role}.png',
            columns=columns, rows=rows, black_to_transparent='none')
        layer = dict(role=role, source_pass=folder, crop=bounds, frame_size=[width,height], shift=shift, pages=[])
        for page in pages:
            destination = output / page['basename']
            with Image.open(BytesIO(page['data'])) as image:
                assert max(image.size) <= 4096
                image.save(destination, format='PNG', optimize=True)
                decoded = image.width*image.height*4
            info = dict(filename=destination.name, sha256=sha(destination), bytes=destination.stat().st_size,
                frame_width=width, frame_height=height, columns=columns, rows=page['rows'],
                frame_count=page['frame_count'], output_start=page['frame_start']-1, output_end=page['frame_end']-1,
                source_frames=selected[page['frame_start']-1:page['frame_end']])
            layer['pages'].append(info)
            manifest['decoded_rgba_bytes'] += decoded
            manifest['png_bytes'] += info['bytes']
        manifest['layers'][role] = layer
    write_snippet(output, manifest)
    write_json(output / 'spritesheet-manifest.json', manifest)
    print(json.dumps(dict(asset=asset,facings=facings,png_MB=manifest['png_bytes']/1e6,
                         decoded_MiB=manifest['decoded_rgba_bytes']/2**20,output=relative(output))))


def check(asset, facings):
    root, master_path, master = read_master(asset)
    output = ROOT / 'output/meshy' / asset / 'factorio-export' / str(facings)
    manifest = json.loads((output / 'spritesheet-manifest.json').read_text())
    assert manifest['master_manifest_sha256'] == sha(master_path)
    selected = list(range(1,257,256//facings))
    assert manifest['selected_source_frames'] == selected
    comparisons = 0; minimum_margin = 100000
    for role, layer in manifest['layers'].items():
        recovered = []
        for page in layer['pages']:
            assert page['frame_count'] <= 128
            assert sha(output/page['filename']) == page['sha256']
            with Image.open(output/page['filename']) as packed:
                width,height=layer['frame_size']
                assert packed.size == (width*page['columns'],height*page['rows'])
                for index, frame in enumerate(page['source_frames']):
                    with Image.open(root/layer['source_pass']/f'{frame:04d}.png') as original:
                        original=original.crop(layer['crop'])
                        x,y=index%page['columns']*width,index//page['columns']*height
                        tile=packed.crop((x,y,x+width,y+height))
                        diff=ImageChops.difference(original,tile)
                        visible=original.getchannel('A').point(lambda value:255 if value else 0).convert('RGB')
                        assert diff.getchannel('A').getbbox() is None
                        assert ImageChops.multiply(diff.convert('RGB'),visible).getbbox() is None, (role,frame)
                        bbox=original.getchannel('A').getbbox()
                        margin=min(bbox[0],bbox[1],width-bbox[2],height-bbox[3])
                        minimum_margin=min(minimum_margin,margin)
                        assert margin>=12
                    comparisons+=1;recovered.append(frame)
        assert recovered==selected, ('Frame ordering changed', role)
    result=dict(asset=asset,facings=facings,all_pass=True,compared_pass_frames=comparisons,
        spritesheet_manifest_sha256=sha(output/'spritesheet-manifest.json'),
        minimum_alpha_margin=minimum_margin,master_hashes_verified=True,frame_mapping_verified=True,
        decoded_rgba8_alpha_and_visible_rgb_exact=True,north_calibration_and_live_playback='not yet integrated')
    write_json(output/'verification.json',result)
    print(json.dumps(result))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['pack','check'])
    parser.add_argument('--asset',choices=ASSETS,required=True)
    parser.add_argument('--facings',type=int,default=256)
    args=parser.parse_args()
    (pack if args.command=='pack' else check)(args.asset,args.facings)
