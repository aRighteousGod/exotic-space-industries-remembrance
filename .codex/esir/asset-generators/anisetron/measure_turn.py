"""Register displayed chapel directions and measure their beam attachment in motion."""
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
parser.add_argument('--step-ticks', type=int, default=3)
parser.add_argument('--rotation-speed', type=float, default=.005)
args = parser.parse_args()
manifest_path = args.bundle/'factorio-preset-render-manifest.json'
manifest = json.loads(manifest_path.read_text())
points = manifest['preflight']['anisetron_muzzle_pixels']
scale = manifest['preflight']['anisetron_sprite_scale']
assert manifest['directions'] == 64 and len(points) == 64
size = round(512*scale)
half = size/2
poses_path = args.shots/'poses.json'
poses = json.loads(poses_path.read_text()) if poses_path.exists() else []
samples = []
for number, pose in enumerate(poses, 1):
    if number > 1:
        delta = (pose['torso']-poses[number-2]['torso']+.5) % 1-.5
    elif len(poses) > 1:
        delta = (poses[1]['torso']-pose['torso']+.5) % 1-.5
    else:
        delta = 0
    step = max(-args.rotation_speed, min(args.rotation_speed, delta/args.step_ticks))
    samples.append((f'{number:03d}', pose, step))
for path in sorted(set(args.shots.glob('frozen*.json')) | set(args.shots.glob('static-*.json'))):
    samples.append((path.stem, json.loads(path.read_text()), 0))
if not samples:
    raise RuntimeError('No moving/frozen/static metadata found')
cache, rows = {}, []
hashes = {str(manifest_path): hashlib.sha256(manifest_path.read_bytes()).hexdigest()}
if poses_path.exists():
    hashes[str(poses_path)] = hashlib.sha256(poses_path.read_bytes()).hexdigest()

def raw_frame(index):
    if index not in cache:
        path = args.bundle/'Object'/f'{index+1:04d}.png'
        raw = Image.open(path).convert('RGBA').resize((size,size), Image.Resampling.BILINEAR)
        bounds = raw.getchannel('A').getbbox()
        ref = np.asarray(raw.crop(bounds), dtype=np.float32)/255
        cache[index] = raw, bounds, ref
        hashes[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return cache[index]

def normalized_score(gray, sy, sx, a, den, x, y):
    b = gray[y+sy,x+sx]
    b = b-b.mean()
    return float((a*b).sum()/(den*np.sqrt((b*b).sum())))

def pixel_muzzle(index, pivot):
    return pivot+(np.array(points[index]['muzzle'])-256)*scale

for name, pose, step in samples:
    shot = args.shots/f'{name}.png'
    hashes[str(shot)] = hashlib.sha256(shot.read_bytes()).hexdigest()
    metadata = args.shots/f'{name}.json'
    if metadata.exists():
        hashes[str(metadata)] = hashlib.sha256(metadata.read_bytes()).hexdigest()
    screen = np.asarray(Image.open(shot).convert('RGB'), dtype=np.float32)/255
    if screen.shape != (768,768,3):
        raise RuntimeError(f'Unexpected camera size: {shot}')
    gray = screen.mean(2)
    torso = pose['torso']
    q = torso*64
    floor_index, round_index, ceil_index = math.floor(q)%64, math.floor(q+.5)%64, math.ceil(q)%64
    active = pose.get('active', name.isdecimal())
    predicted = (torso+step)%1 if active else torso
    predicted_index = math.floor(predicted*64+.5)%64
    candidates = sorted({(base+d)%64 for base in (floor_index,round_index,ceil_index,predicted_index) for d in (-1,0,1)})
    target = np.array([384+(pose['target']['x']-pose['position']['x'])*32,
                       544+(pose['target']['y']-pose['position']['y'])*32])
    guesses = []
    for index in candidates:
        raw, bounds, ref = raw_frame(index)
        gold = (ref[:,:,3]>.95)&(ref[:,:,0]>ref[:,:,2]*1.15)&(ref[:,:,0]>.05)
        gx, gy = round(384+bounds[0]-half), round(478+bounds[1]-half)
        expected = pixel_muzzle(round_index,np.array([384,478]))
        direction = target-expected
        direction /= np.linalg.norm(direction)
        normal = np.array([-direction[1],direction[0]])
        ry, rx = np.indices(gold.shape)
        dx, dy = rx+gx-expected[0], ry+gy-expected[1]
        along, across = dx*direction[0]+dy*direction[1], dx*normal[0]+dy*normal[1]
        gold &= ~((along>-30)&(np.abs(across)<35))
        sy, sx = np.nonzero(gold)
        a = ref.mean(2)[gold]
        a -= a.mean()
        den = np.sqrt((a*a).sum())
        def score(x,y):
            return normalized_score(gray,sy,sx,a,den,x,y)
        best = max((score(x,y),x,y) for y in range(gy-34,gy+35,2) for x in range(gx-6,gx+7,2))
        base = best
        best = max((score(x,y),x,y) for y in range(base[2]-1,base[2]+2) for x in range(base[1]-1,base[1]+2))
        guesses.append((best[0],index,best[1],best[2],sy,sx,a,den))
    guesses.sort(key=lambda entry: entry[0],reverse=True)
    corr, index, x, y, sy, sx, a, den = guesses[0]
    raw, bounds, _ = raw_frame(index)
    def score(xa,ya):
        return normalized_score(gray,sy,sx,a,den,xa,ya)
    xm, xp, ym, yp = score(x-1,y),score(x+1,y),score(x,y-1),score(x,y+1)
    ox, oy = .5*(xm-xp)/(xm-2*corr+xp), .5*(ym-yp)/(ym-2*corr+yp)
    pivot = np.array([x+ox+half-bounds[0],y+oy+half-bounds[1]])
    current_muzzle, body_muzzle = pixel_muzzle(round_index,pivot), pixel_muzzle(index,pivot)
    predicted_muzzle = pixel_muzzle(predicted_index,pivot)
    direction = target-current_muzzle
    direction /= np.linalg.norm(direction)
    normal = np.array([-direction[1],direction[0]])
    yy, xx = np.indices((768,768))
    along = (xx-current_muzzle[0])*direction[0]+(yy-current_muzzle[1])*direction[1]
    across = (xx-current_muzzle[0])*normal[0]+(yy-current_muzzle[1])*normal[1]
    occupied = Image.new('L',(768,768))
    occupied.paste(raw.getchannel('A'),(round(pivot[0]-half),round(pivot[1]-half)))
    occupied = np.asarray(occupied.filter(ImageFilter.MaxFilter(11)))>20
    c = screen*255
    bright = (c.max(2)-c.min(2)>55)&(c.max(2)>140)&(c[:,:,1]+c[:,:,2]>210)
    selected = bright&(~occupied)&(along>25)&(np.abs(across)<18)
    coords = np.stack((xx[selected],yy[selected]),axis=1)
    if len(coords)<100:
        raise RuntimeError(f'No usable beam: {name}')
    mean = coords.mean(0)
    centered = coords-mean
    _, vectors = np.linalg.eigh(centered.T@centered)
    beam = vectors[:,-1]
    beam_normal = np.array([-beam[1],beam[0]])
    def distance(point):
        return abs(float((point-mean)@beam_normal))
    body_distance = distance(body_muzzle)
    rows.append({'sample':name,'torso':torso,'orientation':pose.get('orientation'),
        'speed':pose.get('speed'),'active':active,'floor_index':floor_index,
        'round_index':round_index,'ceil_index':ceil_index,'native_next_index':predicted_index,
        'native_next_step':step if active else 0,'body_index':index,
        'native_next_index_matches_body':predicted_index==index,
        'correlation':round(corr,6),'pivot_px':np.round(pivot,6).tolist(),
        'body_muzzle_px':np.round(body_muzzle,6).tolist(),
        'current_round_distance_px':round(distance(current_muzzle),6),
        'native_next_distance_px':round(distance(predicted_muzzle),6),
        'body_distance_px':round(body_distance,6),'beam_pixels':len(coords),
        'candidate_correlations':{str(g[1]):round(g[0],6) for g in guesses},
        'pass':body_distance<=2 and corr>.95})
report = {'run':args.shots.parents[2].name,'indices':'zero-based','criterion_px':2,
    'views':len(rows),'pass':all(row['pass'] for row in rows),
    'maximum_body_distance_px':max(row['body_distance_px'] for row in rows),
    'scope':'Displayed raw body aperture versus beam centerline; 768px zoom1. Native-next diagnostic uses sampled torso velocity.',
    'sha256':hashes,'results':rows}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({key:report[key] for key in ('run','views','pass','maximum_body_distance_px')}))
if not report['pass']:
    raise SystemExit(1)
