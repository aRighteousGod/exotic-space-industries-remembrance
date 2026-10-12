"""Lossless centred packing, render QA and an art-review gallery (Pillow)."""
import argparse,hashlib,json,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=Path('D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
args=parser.parse_args();root=args.root
out=root/'sprites';out.mkdir(exist_ok=True)
review=root/'gallery';review.mkdir(exist_ok=True)
anchors=json.loads((root/'model-anchors.json').read_text())
geometry=json.loads((root/'geometry-qa.json').read_text());assert geometry['all_pass']
specs=[('base','Object','acidthrower-base',4,320,4),('base','Shadow','acidthrower-base_shadow',4,320,4),
       ('base','Owner','acidthrower-base_mask',4,320,4),('base','Glow','acidthrower-base_glow',4,320,4),
       ('head','Object','acidthrower-head',256,256,16),('head','Shadow','acidthrower-head_shadow',256,256,16),
       ('head','Glow','acidthrower-head_glow',256,256,16)]
frames={};records=[]
for part,role,name,count,size,columns in specs:
    files=sorted((root/'renders'/part/role).glob('*.png'));assert len(files)==count,(part,role,len(files))
    poses=json.loads((root/'renders'/part/'verified-frame-poses.json').read_text())
    assert len(poses)==count
    assert all(abs(p['world_yaw_degrees']-i*360/count)<.001 for i,p in enumerate(poses))
    sheet=Image.new('RGBA',(size*columns,size*math.ceil(count/columns)))
    packed=[];bounds=[];occupancy=[]
    for i,path in enumerate(files):
        source=Image.open(path).convert('RGBA');assert source.size==(448,448)
        crop=(448-size)//2
        bbox=source.getbbox()
        if bbox:assert min(bbox[0]-crop,bbox[1]-crop,448-crop-bbox[2],448-crop-bbox[3])>=8,(path,bbox)
        frame=source.crop((crop,crop,448-crop,448-crop))
        rgba=np.array(frame);rgba[rgba[:,:,3]==0,:3]=0
        frame=Image.fromarray(rgba);packed.append(frame)
        sheet.paste(frame,((i%columns)*size,(i//columns)*size))
        bounds.append(frame.getbbox());occupancy.append(int(np.count_nonzero(rgba[:,:,3])))
    path=out/(name+'.png');sheet.save(path,optimize=True)
    records.append({'name':name,'role':role,'frames':count,'frame_size':size,'columns':columns,'scale':.5,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bounds':bounds,'alpha_pixels':occupancy})
    frames[name]=packed
assert any(frames['acidthrower-base_mask'][i].getbbox() for i in range(4))

def assemble(facing,yaw=None,active=False,night=False):
    canvas=Image.new('RGBA',(448,448),(27,31,33,255))
    angle=math.radians(facing*90)
    bx,by,_=anchors['bearing_xyz']
    x=bx*math.cos(angle)+by*math.sin(angle);y=-bx*math.sin(angle)+by*math.cos(angle)
    hx=round(96+x*64);hy=round(96-y*64)
    head=round(((facing*90 if yaw is None else yaw)%360)*256/360)%256
    for name,index,point in [('acidthrower-base_shadow',facing,(64,64)),('acidthrower-head_shadow',head,(hx,hy)),
        ('acidthrower-base',facing,(64,64)),('acidthrower-head',head,(hx,hy))]:
        sprite=frames[name][index]
        if name.endswith('_shadow'):
            arr=np.array(sprite);arr[:,:,3]=(arr[:,:,3]*.3).astype('uint8');sprite=Image.fromarray(arr)
        if night:
            arr=np.array(sprite);arr[:,:,:3]=(arr[:,:,:3]*.20).astype('uint8');sprite=Image.fromarray(arr)
        canvas.alpha_composite(sprite,point)
    if active:
        canvas.alpha_composite(frames['acidthrower-base_glow'][facing],(64,64))
        canvas.alpha_composite(frames['acidthrower-head_glow'][head],(hx,hy))
    return canvas.crop((64,64,384,384))

gallery=Image.new('RGB',(1280,1060),(27,31,33));draw=ImageDraw.Draw(gallery)
for row,(active,night,label) in enumerate([(False,False,'Day / idle'),(False,True,'Night / idle'),(True,True,'Night / active')]):
    for facing in range(4):
        gallery.paste(assemble(facing,active=active,night=night).convert('RGB'),(facing*320,row*350+25))
        draw.text((facing*320+12,row*350+10),label+' / '+['North','East','South','West'][facing],fill='white')
gallery.save(review/'facings-and-glow.png')
native=Image.new('RGB',(640,190),(27,31,33));d=ImageDraw.Draw(native)
for facing in range(4):
    native.paste(assemble(facing,active=True).resize((160,160),Image.Resampling.LANCZOS).convert('RGB'),(facing*160,25))
    d.text((facing*160+10,8),['North','East','South','West'][facing]+' / native scale',fill='white')
native.save(review/'native-size.png')
parts=Image.new('RGB',(640,360),(27,31,33));d=ImageDraw.Draw(parts)
for column,(name,label) in enumerate([('acidthrower-base','Fixed chassis and tanks'),('acidthrower-head','Rotating head')]):
    sprite=frames[name][0]
    panel=Image.new('RGBA',(320,320),(27,31,33,255))
    panel.alpha_composite(sprite,((320-sprite.width)//2,(320-sprite.height)//2))
    parts.paste(panel.convert('RGB'),(column*320,30));d.text((column*320+12,10),label,fill='white')
parts.save(review/'separate-parts.png')
animated=[]
for i in range(64):
    frame=Image.new('RGB',(640,640),(27,31,33))
    for facing in range(4):
        yaw=facing*90+48*math.sin(i*math.tau/64)
        frame.paste(assemble(facing,yaw,True).convert('RGB'),((facing%2)*320,(facing//2)*320))
    animated.append(frame)
animated[0].save(review/'forward-arc.gif',save_all=True,append_images=animated[1:],duration=65,loop=0,disposal=2)
metrics={'all_pass':True,'geometry':geometry,'sheets':records,'direction_count':256,'step_degrees':360/256,
    'raw_canvas':448,'pixels_per_tile':64,'game_scale':.5,'glow_policy':anchors['glow_active_states'],
    'collars':'native vanilla pipe covers and shadows, supplied by Factorio; no custom collars in production renders',
    'unused_evidence':['head/Owner','collars/Owner','collars/Glow','collars/Shadow','preview/*']}
(root/'sprite-qa.json').write_text(json.dumps(metrics,indent=2))
(review/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Acidthrower revision 03</title>
<style>body{background:#1b1f21;color:#eee;font:16px system-ui;max-width:1300px;margin:30px auto}img{max-width:100%}a{color:#bfe48a}</style>
<h1>Acidthrower / revision 03</h1><p>Prototype 2. Fixed rear tanks, native vanilla pipe covers, 256 head directions, ±48° mechanical arc. Model previews omit the engine-supplied covers. Preview night lighting below is illustrative; see native engine captures for the actual game shader and pipe covers.</p>
<h2>Actual game / vanilla covers only</h2><p>Production turret on a clean surface. No external pipes, acid streams or test markers.</p><img src="native-covers-size.png"><img src="native-covers.png">
<p><a href="../native-visual-qa.json">Native visual evidence</a></p>
<h2>Native fine rotation and shutdown</h2><p>Acceptance fixture with external connection-test pipes. White marker identifies the native state and is absent from the production turret.</p><img src="native-fine-rotation.gif"><img src="native-shutdown.gif">
<h2>Native size</h2><img src="native-size.png"><h2>Facings and isolated active accents</h2><img src="facings-and-glow.png">
<h2>Independent overlays</h2><img src="separate-parts.png"><h2>Limited firing arc</h2><img src="forward-arc.gif"><p><a href="../sprite-qa.json">Sprite QA</a> · <a href="../geometry-qa.json">Geometry QA</a> · <a href="../model-anchors.json">Anchors</a></p>''',encoding='utf-8')
print(json.dumps({'all_pass':True,'sheets':len(records),'gallery':str(review/'index.html')}))
