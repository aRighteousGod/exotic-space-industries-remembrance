"""Register raw chapel sprites and measure native beam centerlines in engine views."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', type=Path, required=True)
parser.add_argument('--shots', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
manifest = json.loads((args.bundle/'factorio-preset-render-manifest.json').read_text())
points = manifest['preflight']['anisetron_muzzle_pixels']
scale = manifest['preflight']['anisetron_sprite_scale']
size = round(512*scale)
half = size/2
rows = []
hashes = {}
for lighting in ('day', 'night'):
    for heading in range(8):
        raw = Image.open(args.bundle/'Object'/f'{heading*8+1:04}.png').convert('RGBA').resize(
            (size,size), Image.Resampling.BILINEAR)
        bounds = raw.getchannel('A').getbbox()
        ref = np.asarray(raw.crop(bounds),dtype=np.float32)/255
        shot = args.shots/f'pose-{heading}-{lighting}.png'
        hashes[shot.name] = hashlib.sha256(shot.read_bytes()).hexdigest()
        screen = np.asarray(Image.open(shot).convert('RGB'),dtype=np.float32)/255
        gold = (ref[:,:,3]>.95)&(ref[:,:,0]>ref[:,:,2]*1.15)&(ref[:,:,0]>.05)
        guess_x, guess_y = round(384+bounds[0]-half), round(470+bounds[1]-half)
        angle = heading*math.tau/8
        target = np.array([384+math.sin(angle)*640,544-math.cos(angle)*640])
        expected_muzzle = np.array([384,470])+(np.array(points[heading*8]['muzzle'])-256)*scale
        expected_direction = target-expected_muzzle
        expected_direction /= np.linalg.norm(expected_direction)
        expected_normal = np.array([-expected_direction[1],expected_direction[0]])
        ry,rx = np.indices(gold.shape)
        dx,dy = rx+guess_x-expected_muzzle[0],ry+guess_y-expected_muzzle[1]
        ar = dx*expected_direction[0]+dy*expected_direction[1]
        nr = dx*expected_normal[0]+dy*expected_normal[1]
        gold &= ~((ar>-25)&(np.abs(nr)<24))
        a = ref[:,:,:3].mean(2)[gold]
        a -= a.mean()
        denominator = np.sqrt((a*a).sum())
        best = (-1,0,0)
        for y in range(guess_y-16,guess_y+17):
            for x in range(guess_x-3,guess_x+4):
                b = screen[y:y+ref.shape[0],x:x+ref.shape[1]].mean(2)[gold]
                b -= b.mean()
                correlation = float((a*b).sum()/(denominator*np.sqrt((b*b).sum())))
                if correlation>best[0]: best = (correlation,x,y)
        correlation,x,y = best
        pivot = np.array([x+half-bounds[0],y+half-bounds[1]])
        muzzle = pivot+(np.array(points[heading*8]['muzzle'])-256)*scale
        direction = target-muzzle
        direction /= np.linalg.norm(direction)
        normal = np.array([-direction[1],direction[0]])
        yy,xx = np.indices((768,768))
        along = (xx-muzzle[0])*direction[0]+(yy-muzzle[1])*direction[1]
        across = (xx-muzzle[0])*normal[0]+(yy-muzzle[1])*normal[1]
        occupied = Image.new('L',(768,768))
        occupied.paste(raw.getchannel('A'),(round(pivot[0]-half),round(pivot[1]-half)))
        occupied = np.asarray(occupied.filter(ImageFilter.MaxFilter(11)))>20
        colors = screen*255
        bright = (colors.max(2)-colors.min(2)>55)&(colors.max(2)>140)&(colors[:,:,1]+colors[:,:,2]>210)
        selected = bright&(~occupied)&(along>25)&(np.abs(across)<18)
        coords = np.stack((xx[selected],yy[selected]),axis=1)
        if len(coords)<100: raise RuntimeError(f'Insufficient beam pixels: {lighting}, {heading}')
        mean = coords.mean(0)
        centered = coords-mean
        _,eigenvectors = np.linalg.eigh(centered.T@centered)
        line = eigenvectors[:,-1]
        line_normal = np.array([-line[1],line[0]])
        distance = abs(float((muzzle-mean)@line_normal))
        rows.append({'lighting':lighting,'heading':heading/8,'pivot_px':pivot.tolist(),
            'correlation':round(correlation,6),'muzzle_px':np.round(muzzle,6).tolist(),
            'centerline_distance_px':round(distance,6),'beam_pixels':len(coords),
            'pass':distance<=2 and correlation>.95})
report = {'run':args.shots.parents[1].name,'criterion_px':2,'views':len(rows),
    'pass':all(r['pass'] for r in rows),'maximum_distance_px':max(r['centerline_distance_px'] for r in rows),
    'scope':'Perpendicular centerline alignment, eight headings in day/night; fixture camera 768px zoom1.',
    'sha256':hashes,'results':rows}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ('run','views','pass','maximum_distance_px')}))
if not report['pass']: raise SystemExit(1)
