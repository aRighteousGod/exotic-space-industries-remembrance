"""Present actual native crops for the ribbon registration comparison."""
import argparse
import base64
import io
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser()
p.add_argument('root',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--short',action='store_true')
args=p.parse_args()
rows=json.loads((args.root/'review/attachment-measurements.json').read_text())
rows={(r['case'],r['tick']):r for r in rows if not r['source_callback']}
source=args.root/'qc/original-visual/script-output/origin'
labels=['Shorter ribbon','Full ribbon + visual offset','Full ribbon + launch offset','Full ribbon, original registration']
prefixes=['','full-forward-ribbon-','full-forward-origin-','full-original-']
if args.short:
    labels=['Short ribbon: 32 px','Narrower: 30 px','Wider: 34 px','Short ribbon: small rear offset']
    prefixes=['','short-30-','short-34-','short-back-']
groups=[]
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
args.output.mkdir(parents=True,exist_ok=True)

def crop(case,tick):
    row=rows[(case,tick)]
    x,y=(round(v) for v in row['outlet_screen'])
    return Image.open(source/(row['key']+'.png')).convert('RGB').crop((x-128,y-112,x+128,y+112))

for pose,label in [('static-ESE','Angled right: consecutive frames'),('sweep-1','North: consecutive frames'),('sweep-2','East: consecutive frames'),('sweep-3','South: consecutive frames'),('sweep-4','West: consecutive frames'),('sweep-2','East: full turning arc')]:
    ticks=list(range(200,641,16)) if label.endswith('arc') else list(range(220,228))
    group={'label':label,'frames':[]}
    for tick in ticks:
        images=[]
        for prefix in prefixes:
            im=crop(prefix+pose,tick).resize((128,112),Image.Resampling.BOX)
            stream=io.BytesIO();im.save(stream,format='WEBP',quality=80,method=6)
            images.append('data:image/webp;base64,'+base64.b64encode(stream.getvalue()).decode())
        group['frames'].append({'tick':tick,'images':images})
    groups.append(group)
    # Slow consecutive phase comparison for visual review, using unresampled captures.
    sequence=[]
    for tick in ticks:
        panel=Image.new('RGB',(1024,258),(29,31,30));draw=ImageDraw.Draw(panel)
        for i,(prefix,name) in enumerate(zip(prefixes,labels)):
            panel.paste(crop(prefix+pose,tick),(i*256,34))
            draw.text((i*256+6,4),name,font=font,fill=(235,238,235))
        sequence.append(panel)
    suffix='turning' if label.endswith('arc') else pose
    sequence[0].save(args.output/(suffix+'.gif'),save_all=True,append_images=sequence[1:],duration=133,loop=0)

template=Path('scripts/qc/acid-jet/origin-comparison.html').read_text(encoding='utf-8')
html=template.replace('__COMPARISON_DATA__',json.dumps({'labels':labels,'groups':groups},separators=(',',':')))
assert len(html.encode())<1024*1024, 'Reduce capture payload before embedding'
(args.output/'ribbon-comparison.html').write_text(html,encoding='utf-8')
sheet=Image.new('RGB',(1024,258*3),(29,31,30));d=ImageDraw.Draw(sheet)
for r,(pose,tick) in enumerate([('static-ESE',220),('sweep-2',220),('sweep-2',221)]):
    for c,(prefix,label) in enumerate(zip(prefixes,labels)):
        sheet.paste(crop(prefix+pose,tick),(c*256,r*258+34))
        d.text((c*256+5,r*258+4),label,font=font,fill=(235,238,235))
sheet.save(args.output/'ribbon-comparison.png')
print(json.dumps({'html_bytes':len(html.encode()),'groups':len(groups),'path':str(args.output/'ribbon-comparison.html')}))
