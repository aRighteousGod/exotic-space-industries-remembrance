"""Match captured canonical turret poses and measure the visible liquid attachment."""
import argparse
import json
import math
from pathlib import Path
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument("root", type=Path)
p.add_argument("fit", type=Path)
args = p.parse_args()
run = args.root / "qc/original-visual/script-output"
report = json.loads((run / "origin-probe.json").read_text())
fit = json.loads(args.fit.read_text())
atlas = Image.open("exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret/acidthrower-head.png").convert("RGBA")
bx, by, rear = .0014700282, .6423900127, .18
shifts = [(bx, -by+rear), (by-rear, bx), (-bx, by-rear), (-by+rear, -bx)]
cases = {row["key"]: row for row in report["cases"]}
ticks = {(r["case"], r["tick"]): r for r in report["ticks"]}
q = math.sqrt(.5)
length, height = fit["barrel_length_tiles"], fit["muzzle_height_tiles"]
templates = []
for frame in range(256):
    cell = np.asarray(atlas.crop((frame%16*256, frame//16*256, frame%16*256+256, frame//16*256+256)), dtype=float)
    # Match only opaque grey/ivory structure; omit acid-green windows and spray.
    mask = (cell[:,:,3] > 250) & (cell[:,:,0] > 35) & (cell[:,:,1] < cell[:,:,0]*1.10)
    yy, xx = np.where(mask)
    templates.append((xx[::3], yy[::3], cell[yy[::3],xx[::3],:3]))


def frame_for(orientation):
    theta = orientation * math.tau
    phi = math.atan2(math.sin(theta), math.sqrt(2)*math.cos(theta)) % math.tau
    return round(phi * 256 / math.tau) % 256


def match_frame(a, capture, case):
    # Screenshots are rendered at end of update; next on_tick observes that pose.
    nxt = ticks.get((case["key"], capture["tick"]+1))
    prediction = frame_for(nxt["orientation"] if nxt else capture["orientation"])
    centre = np.array(a.shape[1::-1])/2 + (np.array(shifts[case["facing"]-1])+[0,.3])*128
    candidates = []
    for delta in range(-8,9):
        frame = (prediction+delta)%256
        xx, yy, source = templates[frame]
        sx = np.rint(centre[0]+(xx-128)*2).astype(int)
        sy = np.rint(centre[1]+(yy-128)*2).astype(int)
        valid = (sx>=0)&(sx<a.shape[1])&(sy>=0)&(sy<a.shape[0])
        target = a[sy[valid],sx[valid],:3].astype(float)
        src = source[valid]
        clean = (target[:,1] < target[:,0]*1.15) | (target[:,1] < target[:,2]*1.8)
        src,target = src[clean],target[clean]
        # Day lighting has a global gain; fit it without changing image geometry.
        gain = (src*target).sum() / max(1,(src*src).sum())
        error = np.mean((target-src*gain)**2)
        candidates.append((float(error),frame))
    candidates.sort()
    error, frame = candidates[0]
    delta = abs((frame-prediction+128)%256-128)
    assert delta < 8, "Frame match reached search boundary; widen before accepting"
    return frame, prediction, error, candidates[1][0]-error, centre


rows = []
for capture in report["captures"]:
    path = run / "origin" / (capture["key"]+".png")
    image = Image.open(path).convert("RGB")
    a = np.asarray(image,dtype=float)
    case = cases[capture["case"]]
    frame, prediction, match_error, margin, centre = match_frame(a,capture,case)
    phi = frame*math.tau/256
    outlet = centre + 128*np.array([length*math.sin(phi),-q*(length*math.cos(phi)+height)])
    along = np.array([math.sin(phi),-q*math.cos(phi)])
    along /= np.linalg.norm(along)
    normal = np.array([-along[1],along[0]])
    yy,xx = np.indices(a.shape[:2])
    delta = np.stack((xx-outlet[0],yy-outlet[1]),axis=-1)
    u,w = delta@along,delta@normal
    green = (a[:,:,1]>45)&(a[:,:,1]>a[:,:,0]*1.15)&(a[:,:,1]>a[:,:,2]*1.8)
    corridor = green & (u>-100)&(u<128)&(np.abs(w)<10)
    # Machine accents cannot establish spray origin. Accept only components
    # connected to visible liquid at least eight native pixels past the outlet.
    connected = corridor & (u>32)
    todo = deque(zip(*np.where(connected)))
    while todo:
        y,x = todo.popleft()
        for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
            ny,nx = y+dy,x+dx
            if 0<=ny<corridor.shape[0] and 0<=nx<corridor.shape[1] and corridor[ny,nx] and not connected[ny,nx]:
                connected[ny,nx]=True;todo.append((ny,nx))
    corridor = connected
    near = corridor & (u>-16)&(u<16)
    source = next((s for s in reversed(report["sources"]) if s["case"]==case["key"] and s["tick"]<=capture["tick"]),None)
    source_screen = None
    if source:
        source_screen = (np.array([source["position"]["x"],source["position"]["y"]])-capture["camera"])*128+256
    rows.append({**capture,"frame":frame,"predicted_frame":prediction,"match_error":match_error,"match_margin":margin,
                 "outlet_screen":list(outlet),"source_screen":list(source_screen) if source is not None else None,
                 "source_age_ticks":capture["tick"]-source["tick"] if source else None,
                 "first_green_native_pixels":float(u[corridor].min()/4) if corridor.any() else None,
                 "nearest_green_native_pixels":float(np.linalg.norm(delta[near],axis=1).min()/4) if near.any() else None})

out = args.root / "review"
out.mkdir(exist_ok=True)
(out / "attachment-measurements.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",18)
selected=[]
for key in ["static-ESE","sweep-1","sweep-2","sweep-3","sweep-4","retarget-E"]:
    for tick in [248,400,552]:
        row = next((r for r in rows if r["case"]==key and r["tick"]==tick and not r["source_callback"]),None)
        if row: selected.append(row)
gallery=Image.new("RGB",(1536,570*6),(29,31,30))
gd=ImageDraw.Draw(gallery)
for i,row in enumerate(selected):
    image=Image.open(run/"origin"/(row["key"]+".png")).convert("RGB")
    draw=ImageDraw.Draw(image)
    x,y=row["outlet_screen"]
    draw.ellipse((x-6,y-6,x+6,y+6),outline=(255,166,62),width=2)
    if row["source_screen"]:
        x,y=row["source_screen"]
        draw.line((x-5,y,x+5,y),fill=(46,225,255),width=2)
        draw.line((x,y-5,x,y+5),fill=(46,225,255),width=2)
    x,y=(i%3)*512,(i//3)*570
    gallery.paste(image,(x,y+50))
    gd.text((x+10,y+5),row["key"],font=font,fill=(240,240,230))
    gd.text((x+10,y+27),f"Head frame {row['frame']} / source age {row['source_age_ticks']} ticks",font=font,fill=(200,211,200))
gallery.save(out/"canonical-contact.png")
for case in ["sweep-2","retarget-E"]:
    sequence=[]
    for row in rows:
        if row["case"]==case and not row["source_callback"] and 200<=row["tick"]<=680 and row["tick"]%8==0:
            image=Image.open(run/"origin"/(row["key"]+".png")).convert("RGB")
            draw=ImageDraw.Draw(image)
            x,y=row["outlet_screen"]
            draw.ellipse((x-5,y-5,x+5,y+5),outline=(255,166,62),width=2)
            draw.text((10,10),f"{case} / tick {row['tick']} / frame {row['frame']}",font=font,fill=(240,240,230))
            sequence.append(image)
    sequence[0].save(out/(case+".gif"),save_all=True,append_images=sequence[1:],duration=133,loop=0)
print(json.dumps({"captures":len(rows),"frames_match_prediction":sum(r["frame"]==r["predicted_frame"] for r in rows),
                  "frame_delta_max":max(abs((r["frame"]-r["predicted_frame"]+128)%256-128) for r in rows),
                  "gallery":str(out/"canonical-contact.png")},indent=2))
