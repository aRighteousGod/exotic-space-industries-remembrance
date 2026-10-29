"""Native contact sheets, state/aiming animations and visible outlet measurements."""
import argparse
from collections import deque
import json
import hashlib
import math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output;out.mkdir(parents=True,exist_ok=True)
report=json.loads((a.run/'client/script-output/acid-eight-native.json').read_text())
images=a.run/'visual.images/acid-eight'
receipt=json.loads((a.run/'visual.receipt.json').read_text())
assert receipt['passed'] and report['passed']
inventory={Path(row['path']).stem:row for row in receipt['images']}
assert len(inventory)==len(report['captures']) and set(inventory)==set(report['captures'])
for key,row in inventory.items():
    assert hashlib.file_digest((images/(key+'.png')).open('rb'),'sha256').hexdigest()==row['sha256'],key
names=('N','NE','E','SE','S','SW','W','NW')


def contact(keys,name,scale,columns=4):
    side=round(512*scale);canvas=Image.new('RGB',(columns*side,math.ceil(len(keys)/columns)*(side+24)),(30,33,35))
    draw=ImageDraw.Draw(canvas)
    for i,key in enumerate(keys):
        image=Image.open(images/(key+'.png')).convert('RGB').resize((side,side),Image.Resampling.NEAREST)
        x=i%columns*side;y=i//columns*(side+24)
        canvas.paste(image,(x,y+24));draw.text((x+5,y+6),key,fill='white')
    canvas.save(out/name)


contact(['ports-'+str(i)+'-'+str(mask) for i in range(1,9) for mask in (0,1,2,3)],'ports-enlarged.png',1)
contact(['ports-'+str(i)+'-'+str(mask) for i in range(1,9) for mask in (0,3)],'ports-native.png',1/3)
contact([prefix+str(i)+'-3' for i in range(1,9) for prefix in ('ports-','ports-night-')],'day-night.png',.5)
for i,name in enumerate(names,1):
    for kind,keys in (
        ('aim',['aim-'+str(i)+'-'+str(t) for t in range(260,381,4)]),
        ('state',['startup-'+str(i)+'-'+str(t) for t in range(0,121,8)]+['shutdown-'+str(i)+'-'+str(t) for t in range(400,481,4)])):
        frames=[Image.open(images/(key+'.png')).convert('RGB') for key in keys]
        frames[0].save(out/(kind+'-'+name+'.webp'),save_all=True,append_images=frames[1:],duration=100,loop=0,lossless=True)
    if 'startup-day-'+str(i)+'-0' in inventory:
        keys=['startup-day-'+str(i)+'-'+str(t) for t in range(0,121,8)]+['shutdown-day-'+str(i)+'-'+str(t) for t in range(400,481,4)]
        frames=[Image.open(images/(key+'.png')).convert('RGB') for key in keys]
        frames[0].save(out/('state-day-'+name+'.webp'),save_all=True,append_images=frames[1:],duration=100,loop=0,lossless=True)

repo=Path(__file__).resolve().parents[3]
atlas=Image.open(repo/'exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret/acidthrower-head.png').convert('RGBA')
templates=[]
for frame in range(256):
    cell=np.array(atlas.crop((frame%16*256,frame//16*256,frame%16*256+256,frame//16*256+256)),dtype=float)
    mask=(cell[:,:,3]>250)&(cell[:,:,0]>35)&(cell[:,:,1]<cell[:,:,0]*1.10)
    yy,xx=np.where(mask);templates.append((xx[::3],yy[::3],cell[yy[::3],xx[::3],:3]))
ticks={(r['case'],r['tick']):r for r in report['ticks']}
results=[]
for capture in report['visual']:
    image=Image.open(images/(capture['key']+'.png')).convert('RGB');rgb=np.asarray(image,dtype=float)
    angle=(capture['facing']-1)*math.pi/4
    shift=np.array([.0014700282*math.cos(angle)+(.6423900127-.18)*math.sin(angle),
                    .0014700282*math.sin(angle)-(.6423900127-.18)*math.cos(angle)])
    center=np.array([256,256])+(shift+[0,.3])*128
    orientation=ticks.get((capture['case'],capture['tick']+1),capture)['orientation']*math.tau
    predicted=round((math.atan2(math.sin(orientation),math.sqrt(2)*math.cos(orientation))%math.tau)*256/math.tau)%256
    candidates=[]
    for delta in range(-8,9):
        frame=(predicted+delta)%256;xx,yy,src=templates[frame]
        sx=np.rint(center[0]+(xx-128)*2).astype(int);sy=np.rint(center[1]+(yy-128)*2).astype(int)
        valid=(sx>=0)&(sx<512)&(sy>=0)&(sy<512);target=rgb[sy[valid],sx[valid]];src=src[valid]
        clean=(target[:,1]<target[:,0]*1.15)|(target[:,1]<target[:,2]*1.8);src,target=src[clean],target[clean]
        gain=(src*target).sum()/max(1,(src*src).sum());error=np.mean((target-src*gain)**2)
        candidates.append((float(error),frame))
    candidates.sort();error,frame=candidates[0]
    assert abs((frame-predicted+128)%256-128)<8,'Head-frame match reached search boundary: '+capture['key']
    phi=frame*math.tau/256;q=math.sqrt(.5)
    outlet=center+128*np.array([.854090101414*math.sin(phi),-q*(.854090101414*math.cos(phi)+.886152416900)])
    along=np.array([math.sin(phi),-q*math.cos(phi)]);along/=np.linalg.norm(along);normal=np.array([-along[1],along[0]])
    yy,xx=np.indices(rgb.shape[:2]);delta=np.stack((xx-outlet[0],yy-outlet[1]),axis=-1);u,w=delta@along,delta@normal
    green=(rgb[:,:,1]>45)&(rgb[:,:,1]>rgb[:,:,0]*1.15)&(rgb[:,:,1]>rgb[:,:,2]*1.8)
    corridor=green&(u>-100)&(u<128)&(np.abs(w)<10)
    connected=corridor&(u>32);todo=deque(zip(*np.where(connected)))
    while todo:
        y,x=todo.popleft()
        for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
            ny,nx=y+dy,x+dx
            if 0<=ny<512 and 0<=nx<512 and corridor[ny,nx] and not connected[ny,nx]:connected[ny,nx]=True;todo.append((ny,nx))
    near=connected&(u>-16)&(u<16)
    source=capture.get('source');screen=None
    if source:screen=(np.array([source['position']['x'],source['position']['y']])-capture['camera'])*128+256
    row=dict(key=capture['key'],frame=frame,predicted=predicted,frame_error=error,
        frame_delta=abs((frame-predicted+128)%256-128),outlet=list(outlet),source=list(screen) if screen is not None else None,
        first_green_native_pixels=float(u[connected].min()/4) if connected.any() else None,
        nearest_green_native_pixels=float(np.linalg.norm(delta[near],axis=1).min()/4) if near.any() else None)
    results.append(row)
    if capture['key'].startswith('firing-') and capture['key'].endswith('-2'):
        draw=ImageDraw.Draw(image);x,y=outlet;draw.ellipse((x-5,y-5,x+5,y+5),outline=(255,166,62),width=2)
        if screen is not None:
            x,y=screen;draw.line((x-4,y,x+4,y),fill=(46,225,255),width=2);draw.line((x,y-4,x,y+4),fill=(46,225,255),width=2)
        image.save(out/(capture['key']+'-markers.png'))
(out/'visible-outlet.json').write_text(json.dumps(results,indent=2))
summary=dict(captures=len(results),frame_delta_max=max(r['frame_delta'] for r in results),
    visible_near_outlet=sum(r['nearest_green_native_pixels'] is not None for r in results),
    note='Orange markers: fitted visible grey outlet; cyan: last native stream creation source. Inspect sparse/sweeping stream frames separately.')
(out/'review.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
