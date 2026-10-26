"""Normalize named-set exports and build a portable review gallery."""
import argparse
import html
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageOps
from sigils import make_icons
from generate import render_raster, digest

ROOT=Path(__file__).resolve().parents[4]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--original',type=Path,required=True)
parser.add_argument('--svg-png',type=Path,required=True)
parser.add_argument('--rendered',type=Path,required=True)
parser.add_argument('--vanilla',type=Path,help='Optional fourth flat-triangle family')
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--terrain',type=Path)
args=parser.parse_args();out=args.output.resolve()
sets=('original','svg','rendered','vanilla') if args.vanilla else ('original','svg','rendered')
assert any(out.is_relative_to(ROOT/p) for p in ('.factorio-qc','output','temp'))
names=list(make_icons())
for name in names:assert (args.rendered/f'{name}.png').is_file(),name
for folder in sets:(out/folder).mkdir(parents=True,exist_ok=True)
records={}
for name in names:
    shutil.copyfile(args.original/f'{name}.png',out/'original'/f'{name}.png')
    shutil.copyfile(args.svg_png/f'{name}.png',out/'svg'/f'{name}.png')
    target,bounds,source_size=render_raster(args.rendered/f'{name}.png')
    target.save(out/'rendered'/f'{name}.png',optimize=True)
    if args.vanilla:shutil.copyfile(args.vanilla/f'{name}.png',out/'vanilla'/f'{name}.png')
    records[name]={'source_size':source_size,'subject_bounds_alpha32':bounds,'export_size':target.size,
                   'source_sha256':digest(args.rendered/f'{name}.png'),
                   'sets':{key:digest(out/key/f'{name}.png') for key in sets}}
(out/'rendered-export.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
try:font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
except OSError:font=ImageFont.load_default()
if args.terrain:shutil.copyfile(args.terrain,out/'terrain.png')
for folder in sets[1:]:
    label=folder.upper() if folder=='svg' else folder.title()
    sheet=Image.new('RGB',(1200,32+174*((len(names)+5)//6)),'#303438')
    draw=ImageDraw.Draw(sheet)
    draw.text((12,8),label+' — 128px detail overview; use comparison sheets to judge 16–24px.',font=font,fill='#eee5d2')
    for i,name in enumerate(names):
        x=(i%6)*200;y=32+(i//6)*174
        draw.text((x+8,y+4),name.removeprefix('ecology-'),font=font,fill='#eee5d2')
        bitmap=Image.open(out/folder/f'{name}.png').convert('RGBA')
        sheet.paste(bitmap,(x+36,y+30),bitmap)
    sheet.save(out/f'{folder}-overview.png')

if args.vanilla:
    for mode in ('color','grayscale'):
        sheet=Image.new('RGB',(1080,28+96*((len(names)+2)//3)),'#303438');draw=ImageDraw.Draw(sheet)
        draw.text((10,6),'Vanilla pictograms — actual 16 / 24 / 32 / 64 pixel exports',font=font,fill='#eee5d2')
        for i,name in enumerate(names):
            x=i%3*360;y=28+i//3*96
            draw.text((x+8,y+2),name,font=font,fill='#eee5d2')
            bitmap=Image.open(out/'vanilla'/f'{name}.png').convert('RGBA')
            if mode=='grayscale':
                alpha=bitmap.getchannel('A');bitmap=ImageOps.grayscale(bitmap).convert('RGBA');bitmap.putalpha(alpha)
            for offset,size in enumerate((16,24,32,64)):
                small=bitmap.resize((size,size),Image.Resampling.LANCZOS)
                sheet.paste(small,(x+28+offset*76,y+50-size//2),small)
        sheet.save(out/f'vanilla-small-{mode}.png')

groups={'machines-fluids':names[:10],'ecology-hazards':names[10:17],'ecology-growth':names[17:]}
for group,ids in groups.items():
    for mode in ('color','grayscale','silhouette'):
        sheet=Image.new('RGB',(420*len(sets),174*len(ids)+36),'#303438');draw=ImageDraw.Draw(sheet)
        for col,label in enumerate(sets):
            draw.text((col*420+12,10),label+'   [16 / 24 / 32 / 64]',font=font,fill='#eee5d2')
        for row,name in enumerate(ids):
            y=36+174*row
            for col,folder in enumerate(sets):
                x=420*col;bitmap=Image.open(out/folder/f'{name}.png').convert('RGBA')
                if mode=='grayscale':
                    old=bitmap;bitmap=ImageOps.grayscale(old).convert('RGBA');bitmap.putalpha(old.getchannel('A'))
                elif mode=='silhouette':
                    old=bitmap;bitmap=Image.new('RGBA',old.size,'#eee4cf');bitmap.putalpha(old.getchannel('A').point(lambda a:255 if a>=128 else 0))
                draw.text((x+8,y+4),name,font=font,fill='#eee5d2')
                sheet.paste(bitmap,(x+8,y+29),bitmap)
                for index,size in enumerate((16,24,32,64)):
                    little=bitmap.resize((size,size),Image.Resampling.LANCZOS)
                    sheet.paste(little,(x+158+index*58,y+76-size//2),little)
        sheet.save(out/f'{group}-{mode}.png')

rows=[]
for name in names:
    cells=[]
    for folder in sets:
        cells.append(f'<div class="sample"><img src="{folder}/{name}.png" alt="{html.escape(name)} {folder}"></div>')
    rows.append(f'<article data-name="{name}"><h2>{name}</h2>'+''.join(cells)+'</article>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESIR alert icons — original / SVG / rendered</title><style>
:root{--icon:32px;--bg:#303438;--filter:none}*{box-sizing:border-box}body{margin:0;background:#191d21;color:#e8dfce;font:15px system-ui,sans-serif}
header{position:sticky;top:0;background:#191d21f5;padding:18px 24px;border-bottom:1px solid #5b6266;z-index:2}h1{font-size:24px;margin:0 0 8px}
p{margin:6px 0;color:#b9b7ac;max-width:1100px}label{display:inline-block;margin:12px 20px 8px 0}select,input{background:#303438;color:#f1e9d7;padding:7px;border:1px solid #7c817e}
.head,article{display:grid;grid-template-columns:250px repeat(3,1fr);gap:1px}.head{padding:12px 24px;background:#23292d;font-weight:600}.head span{padding-left:12px}
main{padding:0 24px 24px}article{border-bottom:1px solid #555e63}h2{font-size:13px;align-self:center;padding:12px;overflow-wrap:anywhere;font-weight:500}
.sample{min-height:max(76px,calc(var(--icon) + 24px));display:flex;align-items:center;justify-content:center;background:var(--bg);background-size:420px auto}.sample img{width:var(--icon);height:var(--icon);filter:var(--filter);object-fit:contain;image-rendering:auto}
.sample:hover img{outline:1px solid #b0aa9566}footer{padding:24px}a{color:#e9be77}button{padding:7px 12px;cursor:pointer}
@media(max-width:800px){.head,article{grid-template-columns:140px repeat(3,1fr)}main,.head{padding-left:4px;padding-right:4px}}
</style><header><h1>ESIR alert icons: three-way comparison</h1>
<p>All 27 identities across Original, SVG and Rendered. Original and SVG are vector-derived icons. Rendered uses built-in imagegen artwork with a physical 3D appearance; these are not Blender mesh renders. This gallery records supplied files; it does not promote them.</p>
<p>Judge the 16 and 24 pixel views first. At 128 pixels, texture can suggest a quality difference that does not survive native alert size.</p>
<label>Size <select id="size"><option>16</option><option selected>24</option><option>32</option><option>64</option><option>128</option></select> px</label>
<label>Background <select id="background"><option value="#303438">Dark GUI</option><option value="#c9ac75">Bright sand</option><option value="#74685c">Dark ground</option><option value="url(terrain.png)">Native terrain</option></select></label>
<label>View <select id="view"><option value="none">Color</option><option value="grayscale(1)">Grayscale</option><option value="brightness(0) invert(0.92)">Silhouette</option></select></label>
<label>Filter <input id="search" type="search" placeholder="fluid, restoration, tree…"></label>
</header><div class="head"><span>Alert</span><span>Original</span><span>SVG</span><span>Rendered</span></div><main>ROWS</main>
<footer><p>Static sheets: <a href="machines-fluids-color.png">machines &amp; fluids</a> · <a href="ecology-hazards-color.png">ecology hazards</a> · <a href="ecology-growth-color.png">ecology growth</a></p>
<p>128px detail overviews: <a href="svg-overview.png">SVG</a> · <a href="rendered-overview.png">Rendered</a>.</p>
<p>Each group also has -grayscale.png and -silhouette.png variants. Durable rendered originals and exact prompts are linked by the source provenance manifest; they are not fabricated vector masters.</p></footer>
<script>const root=document.documentElement;document.querySelector('#size').onchange=e=>root.style.setProperty('--icon',e.target.value+'px');
document.querySelector('#background').onchange=e=>root.style.setProperty('--bg',e.target.value);document.querySelector('#view').onchange=e=>root.style.setProperty('--filter',e.target.value);
document.querySelector('#search').oninput=e=>document.querySelectorAll('article').forEach(row=>row.style.display=row.dataset.name.includes(e.target.value.toLowerCase())?'grid':'none');root.style.setProperty('--icon','24px');</script></html>'''
if args.vanilla:
    page=page.replace('repeat(3,1fr)','repeat(4,1fr)').replace('three-way comparison','four-way comparison')
    page=page.replace('original / SVG / rendered','Original / SVG / Rendered / Vanilla')
    page=page.replace('Original, SVG and Rendered.','Original, SVG, Rendered and Vanilla. Vanilla uses original flat pictograms in the native triangle style.')
    page=page.replace('<span>Rendered</span></div>','<span>Rendered</span><span>Vanilla</span></div>')
    page=page.replace('<a href="rendered-overview.png">Rendered</a>.','<a href="rendered-overview.png">Rendered</a> · <a href="vanilla-overview.png">Vanilla</a>.')
    page=page.replace('Each group also has -grayscale.png','Vanilla intentionally shares the triangle silhouette: judge its dark pictogram in color and grayscale. Each group also has -grayscale.png')
(out/'index.html').write_text(page.replace('ROWS',''.join(rows)),encoding='utf-8')
print(f'Exported {len(names)} normalized rendered icons and named-set gallery: {out}')
