"""Freeze approved FINAL pressure-jet presentation for repeatable native QC."""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image,ImageDraw

p=argparse.ArgumentParser()
p.add_argument('--root',type=Path,required=True)
p.add_argument('--source-data',type=Path,default=Path('D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/qc/original-visual/script-output/final-data.json'))
p.add_argument('--source-art',type=Path,default=Path('D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02/baseline'))
p.add_argument('--sticker-art',type=Path,help='Historical sticker sheet, retained outside shipping after legacy flame retirement.')
args=p.parse_args();out=args.root/'baseline';out.mkdir(parents=True,exist_ok=True)
d=json.loads(args.source_data.read_text())
keys=['spine_animation','particle','shadow','particle_start_scale','particle_scale_per_part',
    'width','particle_loop_frame_count','particle_loop_exit_threshold','particle_fade_out_threshold',
    'particle_fade_out_duration','particle_end_alpha','smoke_sources','progress_to_create_smoke']
stream={k:d['resolved'][k] for k in keys if k in d['resolved']}
assert stream['spine_animation']['width']==64 and stream['spine_animation']['frame_count']==16,'Use the approved FINAL 64px ribbon snapshot'
files=[]
flecks=d.get('flecks') if stream.get('smoke_sources') else None
animations=[stream[kind] for kind in ['spine_animation','particle','shadow']]
if flecks:animations.append(flecks['animation'])
for a in animations:
    name=a['filename'].split('/')[-1];source=args.source_art/name;destination=out/name
    pixels=Image.open(source)
    assert pixels.width==a['width']*a['line_length']
    assert pixels.height==a['height']*((a['frame_count']+a['line_length']-1)//a['line_length'])
    content=source.read_bytes()
    if destination.exists():assert destination.read_bytes()==content,'Never silently replace a frozen baseline'
    else:destination.write_bytes(content)
    a['filename']='__zzz-esir-acid-jet-qc__/baseline/'+name
    files.append({'file':name,'sha256':hashlib.sha256(content).hexdigest()})
contract={'attack':{k:d['turret']['attack_parameters'][k] for k in ['gun_barrel_length','gun_center_shift']},
    'source_offset':d['turret']['attack_parameters']['ammo_type']['action']['action_delivery']['source_offset'],
    'stream':stream,'sticker_animation':d['sticker']['animation']}
if flecks:contract['flecks']=flecks
animation=contract['sticker_animation']
if not animation['filename'].startswith('__base__/'):
    name=animation['filename'].split('/')[-1]
    source=args.sticker_art or args.source_art/name
    content=source.read_bytes();destination=out/name
    if destination.exists():assert destination.read_bytes()==content,'Never silently replace historical sticker art'
    else:destination.write_bytes(content)
    animation['filename']='__zzz-esir-acid-jet-qc__/baseline/'+name
    files.append({'file':name,'sha256':hashlib.sha256(content).hexdigest()})
def lua(x):
    if isinstance(x,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in x.items())+'}'
    if isinstance(x,list):return '{'+','.join(lua(v) for v in x)+'}'
    if isinstance(x,bool):return 'true' if x else 'false'
    if x is None:return 'nil'
    return json.dumps(x)
text='-- Approved FINAL pressure-jet snapshot, 64px ribbon; frozen art and muzzle pose.\nreturn '+lua(contract)+'\n'
if (out/'contract.lua').exists():assert (out/'contract.lua').read_text()==text,'Frozen contract differs'
else:(out/'contract.lua').write_text(text)
im=Image.new('RGBA',(256,256));draw=ImageDraw.Draw(im)
for i in range(16):
    x,y=(i%4)*64+32,(i//4)*64+32;r=2+i;color=(int(240-i*9),int(70+i*10),230,255)
    draw.rectangle((x-1,y-1,x+1,y+1),fill=color)
    for dx,dy in [(-r,0),(r,0),(0,-r),(0,r)]:draw.ellipse((x+dx-1,y+dy-1,x+dx+1,y+dy+1),fill=color)
im.save(out/'diagnostic.png')
(out/'baseline-provenance.json').write_text(json.dumps({'source_snapshot':str(args.source_data),'source_art':str(args.source_art),'files':files},indent=2))
print(json.dumps({'approved_final_baseline':True,'art_files':len(files),'root':str(out)}))
