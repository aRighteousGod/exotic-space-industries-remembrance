"""Exercise repacking and corruption checks on isolated generated pixels."""
import importlib.util
import json
import struct
import zlib
from pathlib import Path
from PIL import Image, ImageDraw

source=Path(__file__).with_name('spritesheets.py')
spec=importlib.util.spec_from_file_location('radar_pack_test',source)
pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
pack.ROOT=Path.cwd()/'output/meshy/radar-production/packing-fixture'
root=pack.ROOT/'output/meshy/sweeping-radar/master-256/Render'
record=dict(complete=True,contract=dict(master_count=256,resolution=[64,64],
            passes=['Object','Shadow'],scale=.5,source_anchor_pixels=[32,32],initial_angle=90),frames={})

def write_rgba16(image,path):
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    values=[channel*257 for pixel in image.getdata() for channel in pixel]
    raw=struct.pack('>'+str(len(values))+'H',*values)
    stride=image.width*8
    filtered=b''.join(b'\x00'+raw[y*stride:(y+1)*stride] for y in range(image.height))
    header=struct.pack('>IIBBBBB',image.width,image.height,16,6,0,0,0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)+chunk(b'IDAT',zlib.compress(filtered))+chunk(b'IEND',b''))
for frame in range(1,257):
    entry={'passes':{}}
    for folder in ['Object','Shadow']:
        directory=root/folder;directory.mkdir(parents=True,exist_ok=True)
        path=directory/f'{frame:04d}.png'
        image=Image.new('RGBA',(64,64),(19,23,27,0))
        draw=ImageDraw.Draw(image)
        draw.rectangle((28,28,34,34),fill=(frame-1,(frame*7)%256,127,255))
        draw.point((35,32),fill=(87,91,31,91))
        write_rgba16(image,path)
        entry['passes'][folder]=dict(path=f'{folder}/{path.name}',sha256=pack.sha(path))
    record['frames'][str(frame)]=entry
manifest=root/'radar-master-manifest.json';pack.write_json(manifest,record)
before=pack.sha(manifest)
for facings in (256,128,64):
    pack.pack('sweeping-radar',facings);pack.check('sweeping-radar',facings)
assert pack.sha(manifest)==before
packed=pack.ROOT/'output/meshy/sweeping-radar/factorio-export/256/sweeping-radar-body.png'
original=packed.read_bytes();packed.write_bytes(original+b'changed')
try:
    pack.check('sweeping-radar',256)
    raise RuntimeError('Corruption was not detected')
except AssertionError:
    print('Expected packed-file corruption detected')
finally:
    packed.write_bytes(original)
pack.check('sweeping-radar',256)
print('Repacking 256/128/64, frame order, alpha, visible colors, source retention and corruption checks passed')
