"""Preserve native acceptance captures and make labelled review contact sheets."""
import argparse,hashlib,json,shutil
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=Path('D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
parser.add_argument('--captures',type=Path,default=Path('.factorio-qc/acid-art-r03/script-output'))
args=parser.parse_args();root=args.root
report=json.loads((args.captures/'acid-art-qc.json').read_text())
assert report['all_pass'] and len(report['captures'])==88
native=root/'gallery/native';native.mkdir(parents=True,exist_ok=True)
for name in report['captures']:
    shutil.copy2(args.captures/'acid-art'/(name+'.png'),native/(name+'.png'))
shutil.copy2(args.captures/'acid-art-qc.json',root/'native-muzzle-qa.json')
facings=['North','East','South','West']
gallery=Image.new('RGB',(1024,1080),(27,31,33));draw=ImageDraw.Draw(gallery)
small=Image.new('RGB',(704,210),(27,31,33));sd=ImageDraw.Draw(small)
for index,name in enumerate(facings):
    source=Image.open(native/f'capped-{index+1}.png').convert('RGB')
    x=(index%2)*512;y=(index//2)*540
    gallery.paste(source,(x,y+24));draw.text((x+12,y+8),name+' / original vanilla covers',fill='white')
    small.paste(source.resize((171,171),Image.Resampling.LANCZOS),(index*176,28))
    sd.text((index*176+8,8),name+' / native scale',fill='white')
gallery.save(root/'gallery/native-covers.png');small.save(root/'gallery/native-covers-size.png')
overlap=Image.new('RGB',(1280,2688),(27,31,33))
for index,name in enumerate(facings):
    pair=Image.new('RGB',(1280,672),(27,31,33));pd=ImageDraw.Draw(pair)
    for variant,label in [(1,'previous lower layer'),(2,'corrected object layer')]:
        pair.paste(Image.open(native/f'overlap-{index+1}-{variant}.png').convert('RGB'),((variant-1)*640,32))
        pd.text(((variant-1)*640+16,10),name+' / '+label,fill='white')
    pair.save(root/f'gallery/native-draw-order-{name.lower()}.png')
    overlap.paste(pair,(0,index*672))
overlap.save(root/'gallery/native-draw-order.png')
index_path=root/'gallery/index.html'
if index_path.exists():
    html=index_path.read_text(encoding='utf-8')
    if 'native-draw-order.png' not in html:
        html+='\n<h2>Native draw order / before and after</h2><p>Identical art and placement, with real pipes immediately behind and in front of each facing.</p><img src="native-draw-order.png">\n'
        index_path.write_text(html,encoding='utf-8')
# Crop below the nozzle/stream and above the fixed tanks. This tests visible
# changes in the rendered pressure housing for each consecutive aim increment.
fine=[Image.open(native/f'fine-{index}.png').convert('RGB') for index in range(21)]
digests=[hashlib.sha256(im.crop((170,125,345,230)).tobytes()).hexdigest() for im in fine]
assert len(set(digests))==21,'Consecutive fine-aim housing crops must be distinct'
fine[0].save(root/'gallery/native-fine-rotation.gif',save_all=True,append_images=fine[1:]+fine[-2:0:-1],duration=90,loop=0)
shutdown=[Image.open(native/f'shutdown-{index}.png').convert('RGB') for index in range(46)]
shutdown[0].save(root/'gallery/native-shutdown.gif',save_all=True,append_images=shutdown[1:],duration=90,loop=0)
states=['folded','preparing','prepared','starting-attack','attacking','ending-attack','rotate-for-folding','folding']
rows=[]
for frame,im in enumerate(shutdown):
    arr=np.asarray(im,dtype=float)
    scores=[]
    for index in range(8):
        x=round(256+(-1.05+index*.3)*128);y=round(256+(1.3+.3)*128)
        scores.append(float(arr[y-3:y+4,x-3:x+4].mean()))
    state=states[int(np.argmax(scores))]
    def green(box):
        x0,y0,x1,y1=box;a=arr[y0:y1,x0:x1]
        # Exclude dim reflected green paint (G<=50 in the folded capture).
        # The active emissive accents remain well above this night threshold.
        return int(np.count_nonzero((a[:,:,1]>60)&(a[:,:,1]>1.15*a[:,:,0])&(a[:,:,1]>1.2*a[:,:,2])))
    rows.append({'frame':frame,'state':state,'marker_score':max(scores),
        'head_green_pixels':green((170,145,345,250)),'tank_green_pixels':green((140,275,375,405))})
assert all(row['marker_score']>220 for row in rows),'Native state markers must be visible'
observed={row['state'] for row in rows}
assert {'folded','folding'}<=observed,'Shutdown must actually reach folding and folded states'
assert all(row['head_green_pixels']==0 and row['tank_green_pixels']==0 for row in rows
    if row['state'] in {'folded','folding'}),'Head and tank glow must both be off at rest'
assert all(row['head_green_pixels']>0 and row['tank_green_pixels']>0 for row in rows
    if row['state'] in {'prepared','starting-attack','attacking','ending-attack','rotate-for-folding'}),'Head and tank glow must stay in step while engaged'
metrics={'all_pass':True,'native_capture_count':len(report['captures']),'muzzle_cases':len(report['muzzle']),
    'max_muzzle_error_tiles':max(row['error'] for row in report['muzzle']),
    'max_muzzle_error_native_pixels':32*max(row['error'] for row in report['muzzle']),
    'distinct_fine_housing_crops':len(set(digests)),
    'active_only_glow_verified':True,
    'shutdown_states':rows,'pipe_cover_preview':'Actual production prototype; no external pipes or helper markers',
    'draw_order_preview':'Four facings, previous and corrected layers, valid adjacent pipes north and south'}
(root/'native-visual-qa.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps({key:value for key,value in metrics.items() if key!='shutdown_states'}))
