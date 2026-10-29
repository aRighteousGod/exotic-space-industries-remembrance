"""Named ESIR alert sets and deterministic RGBA exports. Preview is staging-only.

Generate with --set and --staging-dir. Explicit --ship promotes a complete,
hash-verified named stage. Original art is retained and cannot be overwritten.
"""
from pathlib import Path
from hashlib import sha256
import argparse
import json
import shutil
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageOps, ImageFont
from sigils import make_icons, PILOT
from vanilla import make_icons as make_vanilla_icons, svg_document as vanilla_svg_document

ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
SHIPPING=ROOT/'exotic-space-industries-remembrance-graphics-6/graphics/gui/alerts'
SCALE=4
MATERIALS={
    'ceramic':('#fff0cf','#d9c6a4','#a0927b'),
    'steel':('#b3bdc1','#66747e','#35414b'),
    'amber':('#ffdc85','#f2a239','#bd6224'),
    'red':('#ffb18b','#e16b47','#9f3d2b'),
    'green':('#dcf1ac','#8bc47a','#3b7965'),
    'teal':('#b9ead2','#61bdab','#316e70'),
    'earth':('#e7d4a5','#b39b70','#71614a'),
}

def number(value): return f'{value:.3f}'.rstrip('0').rstrip('.')

def svg_document(name,glyph):
    # Structural faces occupy 100px; relief gives a visible body around 110px.
    bounds=[]
    for kind,coords,_,width,_ in glyph.shapes:
        pts=[(coords[0],coords[1]),(coords[2],coords[3])] if kind=='ellipse' else coords
        bounds.extend((x+dx*width/2,y+dy*width/2) for x,y in pts for dx,dy in [(-1,-1),(1,1)])
    lx=min(p[0] for p in bounds);ly=min(p[1] for p in bounds)
    hx=max(p[0] for p in bounds);hy=max(p[1] for p in bounds)
    scale=100/max(hx-lx,hy-ly);ox=63-(hx+lx)*scale/2;oy=62-(hy+ly)*scale/2
    lines=['<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">',
           f'<title>{name}: ESIR cast-metal signal sigil</title>','<defs>']
    for key,colors in MATERIALS.items():
        lines.append(f'<linearGradient id="{key}" x1="0" y1="0" x2="128" y2="128" gradientUnits="userSpaceOnUse">')
        lines.extend(f'<stop offset="{offset}" stop-color="{color}"/>' for offset,color in zip(('0','0.48','1'),colors))
        lines.append('</linearGradient>')
    lines.append('</defs>')
    def shape(kind,coords,fill,stroke,width,dx=0,dy=0):
        color=lambda c:f'url(#{c})' if c in MATERIALS else c
        attrs=f'fill="{color(fill)}" stroke="{color(stroke)}" stroke-width="{number(width)}" stroke-linejoin="round" stroke-linecap="butt"'
        if kind=='ellipse':
            x1,y1,x2,y2=coords
            lines.append(f'<ellipse cx="{number((x1+x2)*scale/2+ox+dx)}" cy="{number((y1+y2)*scale/2+oy+dy)}" rx="{number((x2-x1)*scale/2)}" ry="{number((y2-y1)*scale/2)}" {attrs}/>')
        else:
            points=' '.join(f'{number(x*scale+ox+dx)},{number(y*scale+oy+dy)}' for x,y in coords)
            lines.append(f'<{kind} points="{points}" {attrs}/>')
    for kind,coords,material,width,relief in glyph.shapes:
        width*=scale
        if relief:
            shape(kind,coords,'none' if kind=='polyline' else '#101920','#101920',width+8,2,3)
            shape(kind,coords,'none' if kind=='polyline' else '#5e686b','#5e686b',width+5)
            shape(kind,coords,'none' if kind=='polyline' else material,material if kind=='polyline' else '#f5e4c5',width if kind=='polyline' else 1.8)
        else:
            shape(kind,coords,'none' if kind=='polyline' else material,material if kind=='polyline' else 'none',width)
    lines.append('</svg>')
    return '\n'.join(lines)+'\n'

def render_svg(source):
    """Render the documented editable SVG subset; no platform-specific renderer."""
    root=ET.fromstring(source);image=Image.new('RGBA',(128*SCALE,)*2);gradients={}
    if root.attrib.get('viewBox')!='0 0 128 128':raise ValueError('SVG must use the 128px icon viewBox')
    for element in root.iter():
        if element.tag.endswith('linearGradient'):
            if tuple(float(element.attrib[k]) for k in ('x1','y1','x2','y2'))!=(0,0,128,128):
                raise ValueError('Only the documented upper-left material gradient is supported')
            stops=[(float(s.attrib['offset']),s.attrib['stop-color']) for s in element]
            paint=Image.new('RGBA',image.size);draw=ImageDraw.Draw(paint)
            for diagonal in range(image.width+image.height-1):
                t=diagonal/(image.width+image.height-2);left,right=stops[0],stops[-1]
                for a,b in zip(stops,stops[1:]):
                    if a[0]<=t<=b[0]:left,right=a,b;break
                f=(t-left[0])/(right[0]-left[0])
                rgb=lambda h:tuple(int(h[i:i+2],16) for i in (1,3,5))
                col=tuple(round(a+(b-a)*f) for a,b in zip(rgb(left[1]),rgb(right[1])))+(255,)
                draw.line((0,diagonal,diagonal,0),fill=col)
            gradients[element.attrib['id']]=paint
    def paint(mask,color):
        if color=='none':return
        layer=gradients[color[5:-1]].copy() if color.startswith('url(#') else Image.new('RGBA',image.size,color)
        layer.putalpha(mask);image.alpha_composite(layer)
    for element in root:
        kind=element.tag.rsplit('}',1)[-1]
        if kind in ('defs','title'):continue
        if kind not in ('polygon','polyline','ellipse'):raise ValueError('Unsupported SVG element: '+kind)
        a=element.attrib;fill=Image.new('L',image.size);stroke=Image.new('L',image.size)
        fd,sd=ImageDraw.Draw(fill),ImageDraw.Draw(stroke);width=round(float(a['stroke-width'])*SCALE)
        if kind=='ellipse':
            cx,cy,rx,ry=(float(a[k])*SCALE for k in ('cx','cy','rx','ry'))
            box=(cx-rx,cy-ry,cx+rx,cy+ry);fd.ellipse(box,fill=255)
            if width:
                sd.ellipse((box[0]-width/2,box[1]-width/2,box[2]+width/2,box[3]+width/2),fill=255)
                sd.ellipse((box[0]+width/2,box[1]+width/2,box[2]-width/2,box[3]-width/2),fill=0)
        else:
            points=[tuple(float(v)*SCALE for v in pair.split(',')) for pair in a['points'].split()]
            if kind=='polygon':fd.polygon(points,fill=255);points.append(points[0])
            if width:sd.line(points,fill=255,width=width,joint='curve')
        paint(fill,a['fill']);paint(stroke,a['stroke'])
    return image.resize((128,128),Image.Resampling.LANCZOS)

def font(size=14):
    try:return ImageFont.truetype('C:/Windows/Fonts/consola.ttf',size)
    except OSError:return ImageFont.load_default()

def previews(stage,names,before=None,terrain=None):
    imgs={n:Image.open(stage/'png'/f'{n}.png').convert('RGBA') for n in names}
    backgrounds={'dark':Image.new('RGB',(420,178),'#303438'),'bright':Image.new('RGB',(420,178),'#c9ac75')}
    if terrain:
        native=Image.open(terrain).convert('RGB')
        backgrounds['terrain']=native.crop((140,140,560,318))
    else: backgrounds['terrain']=Image.new('RGB',(420,178),'#837556')
    for variant in ('color','grayscale','silhouette'):
        sheet=Image.new('RGB',(1260,len(names)*178),'#24282c');draw=ImageDraw.Draw(sheet)
        for row,name in enumerate(names):
            bitmap=imgs[name]
            if variant=='grayscale':
                bitmap=ImageOps.grayscale(bitmap).convert('RGBA');bitmap.putalpha(imgs[name].getchannel('A'))
            elif variant=='silhouette':
                bitmap=Image.new('RGBA',(128,128),'#f0e4ce')
                bitmap.putalpha(imgs[name].getchannel('A').point(lambda a:255 if a>=128 else 0))
            for col,(label,bg) in enumerate(backgrounds.items()):
                x=col*420;y=row*178;sheet.paste(bg,(x,y))
                ink='#ffffff' if label!='bright' else '#12181c'
                draw.text((x+8,y+5),name+' / '+label,font=font(12),fill=ink)
                sheet.paste(bitmap,(x+8,y+28),bitmap)
                for offset,size in enumerate((16,24,32,64)):
                    little=bitmap.resize((size,size),Image.Resampling.LANCZOS)
                    px=x+155+offset*58;sheet.paste(little,(px,y+75-size//2),little)
                    draw.text((px,y+117),str(size),font=font(12),fill=ink)
        sheet.save(stage/f'{variant}-matrix.png')
    if before:
        sheet=Image.new('RGB',(800,len(names)*106),'#303438');draw=ImageDraw.Draw(sheet)
        for row,name in enumerate(names):
            old=Image.open(before/f'{name}.png').convert('RGBA');new=imgs[name];y=row*106
            draw.text((8,y+4),name,font=font(),fill='#eee3cc')
            for col,(label,bitmap) in enumerate((('before',old),('after',new))):
                x=col*400;draw.text((x+8,y+31),label,font=font(),fill='#b8b4a5')
                for offset,size in enumerate((16,24,32,64)):
                    little=bitmap.resize((size,size),Image.Resampling.LANCZOS)
                    sheet.paste(little,(x+90+offset*66,y+64-size//2),little)
        sheet.save(stage/'before-after.png')

def digest(path): return sha256(path.read_bytes()).hexdigest()

def generator_hashes():
    return {name:digest(HERE/name) for name in ('generate.py','sigils.py','vanilla.py')}

def render_raster(path):
    """Reproduce the reviewed crop/fit; preserve the untouched imagegen source."""
    with Image.open(path) as source:
        image=source.convert('RGBA')
    alpha=image.getchannel('A')
    bounds=alpha.point(lambda a:255 if a>=32 else 0).getbbox()
    if not bounds or alpha.getextrema()!=(0,255):
        raise ValueError(f'Rendered source requires transparent RGBA artwork: {path}')
    subject=image.crop(bounds);subject.thumbnail((108,108),Image.Resampling.LANCZOS)
    target=Image.new('RGBA',(128,128))
    target.alpha_composite(subject,((128-subject.width)//2,(128-subject.height)//2))
    return target,bounds,image.size


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--set',dest='set_id',choices=('svg','rendered','vanilla'),required=True,
                        help='Explicit destination set; Original is immutable')
    parser.add_argument('--staging-dir',type=Path,required=True)
    parser.add_argument('--pilot',action='store_true')
    parser.add_argument('--ship',action='store_true',help='Promote the existing complete, hash-verified stage')
    parser.add_argument('--before-dir',type=Path)
    parser.add_argument('--terrain-reference',type=Path)
    parser.add_argument('--svg-dir',type=Path,help='Render edited masters instead of rebuilding geometry')
    parser.add_argument('--raster-dir',type=Path,help='Untouched imagegen originals for the rendered set')
    args=parser.parse_args();stage=args.staging_dir.resolve()
    if not any(stage.is_relative_to(ROOT/folder) for folder in ('.factorio-qc','output','temp')):
        parser.error('Use an ignored .factorio-qc, output or temp staging directory.')
    icons=make_vanilla_icons() if args.set_id=='vanilla' else make_icons()
    assert len(icons)==27
    if args.ship:
        if args.pilot:parser.error('A pilot cannot be shipped.')
        manifest=json.loads((stage/'manifest.json').read_text())
        if manifest.get('format')!=3 or manifest.get('set_id')!=args.set_id:
            parser.error('Named stage does not match --set; rebuild an explicit named stage.')
        if set(manifest['icons'])!=set(icons):parser.error('Only a complete 27-icon stage may be shipped.')
        if manifest['generator_hashes']!=generator_hashes():parser.error('Generator changed since staging; rebuild and review first.')
        source_folder,source_ext=('raster','png') if args.set_id=='rendered' else ('svg','svg')
        for name,record in manifest['icons'].items():
            for folder,ext,hash_key in (('png','png','png_sha256'),(source_folder,source_ext,'source_sha256')):
                path=stage/folder/f'{name}.{ext}'
                if digest(path)!=record[hash_key]:parser.error(f'Staged file changed: {path}')
        destination=SHIPPING/args.set_id;masters=HERE/'sources'/args.set_id
        destination.mkdir(parents=True,exist_ok=True);masters.mkdir(parents=True,exist_ok=True)
        for name in icons:
            shutil.copyfile(stage/'png'/f'{name}.png',destination/f'{name}.png')
            shutil.copyfile(stage/source_folder/f'{name}.{source_ext}',masters/f'{name}.{source_ext}')
        shutil.copyfile(stage/'manifest.json',masters/'export-manifest.json')
        print(f'Promoted 27 reviewed {args.set_id} PNGs and their actual sources; other sets unchanged.');return
    if args.set_id!='rendered' and args.raster_dir:parser.error('--raster-dir belongs to the rendered set.')
    if args.set_id=='rendered' and args.svg_dir:parser.error('--svg-dir belongs to the SVG set.')
    if args.set_id=='rendered' and not args.raster_dir:parser.error('The rendered set requires --raster-dir.')
    names=list(PILOT) if args.pilot else list(icons)
    source_folder='raster' if args.set_id=='rendered' else 'svg'
    for folder in ('png',source_folder):(stage/folder).mkdir(parents=True,exist_ok=True)
    styles={'svg':'cast-metal-sigils','rendered':'imagegen-physical-appearance','vanilla':'flat-triangle-pictograms'}
    manifest={'format':3,'set_id':args.set_id,'style':styles[args.set_id],
              'generator_hashes':generator_hashes(),'icons':{}}
    for name in names:
        if args.set_id!='rendered':
            path=stage/'svg'/f'{name}.svg'
            if args.svg_dir:shutil.copyfile(args.svg_dir/f'{name}.svg',path)
            else:
                document=vanilla_svg_document if args.set_id=='vanilla' else svg_document
                path.write_text(document(name,icons[name]),encoding='utf-8')
            bitmap=render_svg(path.read_text(encoding='utf-8'));details={}
        else:
            path=stage/'raster'/f'{name}.png';shutil.copyfile(args.raster_dir/f'{name}.png',path)
            bitmap,source_bounds,source_size=render_raster(path)
            details={'source_size':source_size,'subject_bounds_alpha32':source_bounds,'fit_pixels':108}
        png=stage/'png'/f'{name}.png';bitmap.save(png,optimize=True)
        alpha=bitmap.getchannel('A');bounds=alpha.point(lambda a:255 if a>=32 else 0).getbbox()
        assert bounds and min(bounds[:2])>=3 and max(bounds[2:])<=125,(name,bounds)
        manifest['icons'][name]={'png_sha256':digest(png),'source_sha256':digest(path),'alpha_bounds':bounds,**details}
    previews(stage,names,args.before_dir,args.terrain_reference)
    (stage/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'Staged {len(names)} {args.set_id} PNGs, sources and review matrices; shipping files untouched.')

if __name__=='__main__':main()
