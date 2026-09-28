"""Prismatic Liturgy: deterministic, staged lance art-direction studies.

Extends the editable original prismatic-beam/afterburn family, using its exact
cyan/cobalt, magenta/violet and orange/gold/white palette. No shipping promotion.
Run from the repository root with Python, NumPy and Pillow.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TAU = math.tau
PALETTE = [(0, 225, 255), (88, 77, 255), (255, 28, 192), (160, 63, 255),
           (255, 112, 20), (255, 232, 58), (255, 255, 246)]


def mix(a, b, t):
    return np.asarray(a) + (np.asarray(b) - np.asarray(a)) * np.clip(t, 0, 1)[..., None]


def spectrum(offset, phase, heat=1):
    """Vector form of the existing lance generator's spectral_color()."""
    band = .5 + .5 * np.sin(offset * 3.4 + phase)
    cold = mix(PALETTE[0], PALETTE[1], band * .85)
    warm = mix(PALETTE[2], PALETTE[3], band * .85)
    hot = mix(PALETTE[4], PALETTE[5], .45 + .45 * band)
    hot = mix(hot, PALETTE[6], np.maximum(0, 1 - np.abs(offset) * 7) * .72 * heat)
    return np.where((offset < -.18)[..., None], cold,
                    np.where((offset > .18)[..., None], warm, hot))


def rgba(rgb, alpha):
    a = np.clip(alpha, 0, 1)
    out = np.dstack((np.clip(rgb, 0, 255), a * 255)).astype(np.uint8)
    out[a < .006] = 0
    return Image.fromarray(out)


def field(size):
    y, x = np.mgrid[:size, :size].astype(np.float32)
    x, y = (x - size / 2) / (size / 2), (y - size / 2) / (size / 2)
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def glow(core):
    # Blur premultiplied RGB and alpha separately, then unpremultiply. This avoids
    # a dark fringe in the eventual transparent additive layer.
    a = np.asarray(core, dtype=np.float32) / 255
    premult = Image.fromarray(np.uint8(a[..., :3] * a[..., 3, None] * 255))
    blurred = np.asarray(premult.filter(ImageFilter.GaussianBlur(5)), dtype=np.float32)
    alpha = np.asarray(core.getchannel('A').filter(ImageFilter.GaussianBlur(5)), dtype=np.float32)
    rgb = np.divide(blurred * 255, alpha[..., None], out=np.zeros_like(blurred), where=alpha[..., None] > 0)
    yy,xx=np.mgrid[:core.height,:core.width]
    margin=np.minimum.reduce([xx,yy,core.width-1-xx,core.height-1-yy])
    return rgba(rgb, alpha / 255 * .42 * np.clip(margin/7,0,1))


def beam(kind, phase, width=768, height=144):
    yy, xx = np.mgrid[:height, :width].astype(np.float32)
    u, y = xx / (width - 1), (yy - height / 2) / (height / 2)
    wave = .018 * np.sin(u * TAU * 4 - phase) + .009 * np.sin(u * TAU * 11 + phase * 2)
    d = y - wave
    # A needle endpoint and long tapered strands give a direction of travel.
    taper = np.clip(u / .15, 0, 1) ** .65 * np.clip((1 - u) / .10, 0, 1) ** .5
    thickness = (.23 if kind == 'axial' else .29) * taper + .006
    bands = np.exp(-(d / thickness) ** 2)
    flow = .7 + .3 * np.sin(u * TAU * 13 - phase * 2 + d * 17)
    seam = np.exp(-(d / .018) ** 2)
    texture = .82 + .18 * np.sin(u * TAU * 29 + d * 24 - phase * 3)
    alpha = (bands * 1.16 * flow + seam * .8) * taper * texture
    rgb = spectrum(d / np.maximum(thickness, .001), phase + u * TAU * 3)
    if kind == 'axial':
        # Two cyan incision banks remain separate from the moving broad spectrum.
        edge = .36 * taper + .035 * np.sin(u * TAU * 5 - phase)
        lips = np.exp(-((np.abs(d) - edge) / .016) ** 2) * taper
        rgb = mix(rgb, (5, 242, 255), np.clip(lips, 0, .95))
        alpha = np.maximum(alpha, lips * .95)
    else:
        # A genuinely dark aperture, held inside white/gold banks and broad color.
        gap = .052 + .011 * np.sin(u * TAU * 8 - phase)
        rims = np.exp(-((np.abs(d) - gap) / .018) ** 2) * taper
        rgb = mix(rgb, (255, 246, 222), rims * .92)
        alpha = np.maximum(alpha, rims)
        cavity = (np.abs(d) < gap * .72) & (taper > .2)
        rgb[cavity] = (3, 1, 12)
        alpha[cavity] = .97
    # Long, fine streamers. Their bright heads travel; their tails taper.
    for k in range(4):
        head = (.2 + k * .21 + phase / TAU * .85) % .85 + .06
        tail = np.clip((u - (head - .18)) / .18, 0, 1) * (u <= head)
        yy0 = (-1 if k % 2 else 1) * (.49 + .095 * np.sin(u * TAU * 3 + phase + k))
        strand = np.exp(-((y - yy0) / (.008 + .013 * tail)) ** 2) * tail ** 2 * taper
        rgb = mix(rgb, PALETTE[0 if k % 2 else 2], strand * .95)
        alpha = np.maximum(alpha, strand * .82)
    alpha *= np.clip((1 - np.abs(y)) / .12, 0, 1)
    return rgba(rgb, alpha)


def fracture_distance(x, y, points):
    best = np.full_like(x, 10)
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        vx, vy = bx - ax, by - ay
        t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
        best = np.minimum(best, np.hypot(x - ax - t * vx, y - ay - t * vy))
    return best


def wound(band, phase, size=256):
    x, y, r, angle = field(size)
    paths = [[(-.12, -.72), (.08, -.37), (-.13, -.07), (.11, .30), (-.06, .71)]]
    if band >= 2:
        paths += [[(.04, -.41), (.43, -.53), (.65, -.33)],
                  [(-.10, -.13), (-.46, -.37), (-.69, -.22)],
                  [(.10, .30), (.42, .23), (.68, .42)],
                  [(.0, .49), (-.35, .66), (-.58, .57)]]
    dist = np.minimum.reduce([fracture_distance(x, y, p) for p in paths])
    dist += .007*np.sin(y*55+phase*2)*np.sin(x*37-phase)
    pulse = .72 + .28 * np.sin(y * 13 - phase * 2 + x * 7)
    alpha = np.exp(-(dist / .048) ** 2) * pulse
    edge = np.exp(-((dist - .057) / .030) ** 2) * .62 * pulse
    alpha = np.maximum(alpha, edge)
    rgb = spectrum(np.sin(x * 8 + y * 3 + phase) * .85, phase + y * 7)
    rgb = mix(rgb, (255, 241, 172), np.exp(-(dist / .008) ** 2) * .85)
    # Fine spectral currents flow parallel to the fracture without filling its gaps.
    wisps = np.exp(-((np.abs(x - .045 * np.sin(y * 12 + phase)) - .14) / .022) ** 2)
    wisps *= np.exp(-(y / .65) ** 6) * (.3 + .4 * np.sin(y * 18 - phase) ** 2)
    alpha = np.maximum(alpha, wisps)
    if band >= 3:
        radius = .70 + .013 * np.sin(angle * 7 - phase)
        gaps = (np.cos(angle * 4 + .25) > -.52).astype(float)
        ring = np.exp(-((r - radius) / .028) ** 2) * gaps
        flow = .65 + .35 * np.sin(angle * 9 - phase * 2)
        rgb = mix(rgb, spectrum(np.sin(angle + phase), phase + angle * 2), ring)
        alpha = np.maximum(alpha, ring * flow)
        pearls = np.exp(-((r - radius) / .011) ** 2) * (.5 + .5 * np.sin(angle * 4 - phase)) ** 16 * gaps
        rgb = mix(rgb, (255, 248, 205), pearls)
    alpha *= np.clip((.94 - r) / .08, 0, 1)
    return rgba(rgb, alpha)


def collapse(testament, impact, t, size=320):
    x, y, r, angle = field(size)
    phase = t * TAU
    radius = .72 * (1 - t) ** .82 + .055 if not impact else .15 + .58 * np.sin(t * math.pi / 2)
    edge = r - radius - .007 * np.sin(angle * 13 - phase * 2)
    ring = np.exp(-(edge / .027) ** 2)
    inner = np.exp(-((edge + .035) / .030) ** 2) * .62
    caustic = (.62 + .38 * np.sin(angle * 17 + r * 52 - phase * 5))
    rgb = spectrum(np.sin(angle + phase * .27) * .82, phase * .7 + angle * 3)
    alpha = ring * .94 + inner * caustic
    # A handful of long inward-spiralling comet tails, encoded in the sheet.
    radial = np.clip((r - radius) / .29, 0, 1)
    spiral_phase = angle * (3 if testament else 4) + radial * 4.4 - phase * 2
    tails = np.maximum(0, np.cos(spiral_phase)) ** 16
    tails *= np.exp(-((r - radius - .085) / .20) ** 2) * (r > radius - .025)
    tails *= np.clip((.90 - r) / .12, 0, 1)
    alpha = np.maximum(alpha, tails * .9)
    seam = np.exp(-(edge / .0065) ** 2)
    rgb = mix(rgb, (255, 243, 188), seam * .72)
    if not impact:
        nucleus = np.exp(-(r / (.02 + .04 * t)) ** 2) * t
        alpha = np.maximum(alpha, nucleus)
        rgb = mix(rgb, (255, 249, 221), nucleus)
    else:
        petals = (.5 + .5 * np.sin(angle * (4 if testament else 6) + r * 15 - phase)) ** 10
        petals *= np.exp(-(r / (.40 + .30 * t)) ** 2)
        alpha = np.maximum(alpha, petals * (1 - t) ** .7)
        alpha *= (1 - t) ** .65
        contact = np.exp(-(r/(.10+.07*t))**2) * (1-t)**5
        rgb = mix(rgb,(255,249,218),contact)
        alpha = np.maximum(alpha,contact)
    alpha *= np.clip((.99 - np.maximum(np.abs(x),np.abs(y)))/.08,0,1)
    im = rgba(rgb, alpha)
    if testament:
        # Opaque silhouette lives in the semantic layer, never in additive glow.
        void = Image.new('RGBA', (size, size))
        d = ImageDraw.Draw(void)
        rad = max(0, radius - .045) * size / 2
        opacity = int(246 * ((1 - t) ** .45 if impact else 1))
        d.ellipse((size/2-rad, size/2-rad, size/2+rad, size/2+rad), fill=(3, 1, 10, opacity))
        im.alpha_composite(void)
        if impact:
            a = np.exp(-((y / .014) ** 2)) * np.exp(-(x / .84) ** 4)
            a += np.exp(-((x / .014) ** 2)) * np.exp(-(y / .84) ** 4)
            a *= (1 - t) ** 2
            a *= np.clip((.97-np.maximum(np.abs(x),np.abs(y)))/.09,0,1)
            cross = rgba(spectrum(np.sin(angle + phase), phase) * .15 + np.array((255, 246, 213)) * .85, a)
            im.alpha_composite(cross)
    return im


def font(size):
    for path in ['C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/arial.ttf']:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def composite(core, bloom=True, bg=(9, 13, 23)):
    im = Image.new('RGBA', core.size, (*bg, 255))
    if bloom:
        im.alpha_composite(glow(core))
    im.alpha_composite(core)
    return im.convert('RGB')


def crystal_icon(kind, phenomenon, source, size=256):
    """Extend the existing rendered icon, retaining its mineral and etched body."""
    im = Image.new('RGBA', (size, size))
    pedestal=source.crop((0,96,256,256)).resize((192,120),Image.Resampling.LANCZOS)
    im.alpha_composite(pedestal,(32,131))
    crystal=source.crop((78,8,176,108))
    pixels=np.array(crystal)
    green=pixels[...,1].astype(float)>pixels[...,2].astype(float)*1.08
    pixels[green,3]=0
    crystal=Image.fromarray(pixels).resize((112,126),Image.Resampling.LANCZOS)
    if kind==0:
        im.alpha_composite(crystal,(72,20))
    elif kind==1:
        im.alpha_composite(crystal.crop((0,0,56,126)),(64,20))
        im.alpha_composite(crystal.crop((56,0,112,126)),(136,34))
    else:
        for i in range(3):
            shard=crystal.resize((42,58),Image.Resampling.LANCZOS).rotate(i*120+25,resample=Image.Resampling.BICUBIC,expand=True)
            a=i*TAU/3-.5
            im.alpha_composite(shard,(int(128+52*math.cos(a)-shard.width/2),int(92+52*math.sin(a)-shard.height/2)))
    body=im.copy()
    effect=Image.new('RGBA',im.size)
    if kind==0:
        art=phenomenon.resize((248,66),Image.Resampling.LANCZOS).rotate(38,resample=Image.Resampling.BICUBIC,expand=True)
        effect.alpha_composite(art,((size-art.width)//2,(size-art.height)//2-12))
    else:
        art=phenomenon.resize((224,224),Image.Resampling.LANCZOS)
        effect.alpha_composite(art,(16,-12))
    im.alpha_composite(effect)
    return body,effect,im


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path('output/meshy/lance-prismatic-liturgy'))
    parser.add_argument('--repo',type=Path,default=Path.cwd())
    args=parser.parse_args(); out=args.output; sheets=out/'factorio-export'; sheets.mkdir(parents=True,exist_ok=True)
    sequences={
        'axial': [beam('axial',i/32*TAU) for i in range(32)],
        'testament-beam': [beam('testament',i/32*TAU) for i in range(32)],
        **{f'wound-{band}':[wound(band,i/32*TAU) for i in range(32)] for band in range(1,4)},
        **{f'{name}-{part}':[collapse(name=='testament',part=='impact',i/(count-1)) for i in range(count)]
           for name in ['collapse','testament'] for part,count in [('warning',30),('impact',12)]},
    }
    manifest={}
    for name,frames in sequences.items():
        w,h=frames[0].size; columns=4 if w>400 else 6
        sheet=Image.new('RGBA',(w*columns,h*math.ceil(len(frames)/columns)))
        glow_sheet=Image.new('RGBA',sheet.size)
        for i,frame in enumerate(frames):
            xy=((i%columns)*w,(i//columns)*h); sheet.alpha_composite(frame,xy); glow_sheet.alpha_composite(glow(frame),xy)
        sheet.save(sheets/f'{name}.png');glow_sheet.save(sheets/f'{name}-glow.png')
        manifest[name]={'width':w,'height':h,'frames':len(frames),'columns':columns,'role':'semantic + separate glow','staged':True}
    icons=[]
    names=['Axial Rupture','Wound Memory','Terminal Collapse','Black-Hole Testament']
    sources=[sequences['axial'][9],sequences['wound-3'][9],sequences['collapse-warning'][6],sequences['testament-warning'][5]]
    original=Image.open(args.repo/'exotic-space-industries-remembrance-graphics-4/graphics/techs/singularity-lance.png').convert('RGBA')
    for i,(name,source) in enumerate(zip(names,sources)):
        body,effect,im=crystal_icon(i,source,original); key=name.lower().replace(' ','-')
        body.save(sheets/f'{key}-mineral.png');effect.save(sheets/f'{key}-phenomenon.png')
        im.save(out/f'{key}-icon-study.png');icons.append(im)
    # Review board: actual frames, both dark and ordinary-ground-like backgrounds.
    board=Image.new('RGB',(1600,1130),(9,13,23));d=ImageDraw.Draw(board)
    d.text((40,25),'PRISMATIC LITURGY',font=font(38),fill=(237,244,244))
    d.text((42,76),'Living spectrum / four rites of the same weapon',font=font(20),fill=(139,168,184))
    for i,im in enumerate(icons):
        x=45+i*395;board.paste(im,(x+50,130),im);d.text((x,401),names[i],font=font(24),fill=(230,236,240))
    for row,key in enumerate(['axial','testament-beam']):
        im=composite(sequences[key][9]);board.paste(im,(40,460+row*165))
        d.text((825,488+row*165),'Paired incision banks' if row==0 else 'Dark aperture / prismatic banks',font=font(24),fill=(230,236,240))
        d.text((825,528+row*165),'Traveling caustics, tapering filament tails',font=font(18),fill=(142,169,186))
    keys=['wound-1','wound-2','wound-3','collapse-warning','testament-warning']
    for i,key in enumerate(keys):
        im=sequences[key][9].resize((240,240),Image.Resampling.LANCZOS)
        board.paste(composite(im,bg=(40,47,42)),(45+i*310,823))
        d.text((45+i*310,1080),key.replace('-',' '),font=font(20),fill=(183,201,208))
    board.save(out/'direction-board.png')
    # Contact sheet proves progression/timing. Warning30 + impact12 is always42 ticks.
    strip=Image.new('RGB',(12*128,4*156),(18,23,27));draw=ImageDraw.Draw(strip)
    for row,key in enumerate(['collapse-warning','collapse-impact','testament-warning','testament-impact']):
        seq=sequences[key]
        for i in range(12):
            idx=round(i*(len(seq)-1)/11); im=composite(seq[idx]).resize((128,128),Image.Resampling.LANCZOS)
            strip.paste(im,(i*128,row*156));draw.text((i*128+5,row*156+131),f'{key} {idx+1}',font=font(11),fill='white')
    strip.save(out/'timing-strip.png')
    # An animated overview, explicitly slowed for art review (not gameplay timing).
    anim=[]
    for i in range(64):
        im=Image.new('RGB',(1024,620),(10,15,24));dr=ImageDraw.Draw(im)
        dr.text((24,12),'PRISMATIC LITURGY / motion study',font=font(23),fill=(224,237,244))
        for row,key in enumerate(['axial','testament-beam']):
            art=composite(sequences[key][i%32]).resize((980,128),Image.Resampling.LANCZOS);im.paste(art,(22,55+row*135))
        for j in range(3):
            art=composite(sequences[f'wound-{j+1}'][i%32]).resize((170,170),Image.Resampling.LANCZOS);im.paste(art,(20+j*172,360))
        for j,key in enumerate(['collapse','testament']):
            tick=(i*2)%64
            seq=sequences[key+'-warning'] if tick<30 else sequences[key+'-impact']
            idx=tick if tick<30 else min(11,tick-30)
            art=composite(seq[idx]).resize((220,220),Image.Resampling.LANCZOS);im.paste(art,(545+j*235,340))
        dr.text((24,583),'Saturated material first; bloom is a separate optional layer.',font=font(18),fill=(144,170,184));anim.append(im)
    anim[0].save(out/'motion-study.webp',save_all=True,append_images=anim[1:],duration=50,loop=0,quality=87,method=4)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    write_gallery(out,manifest,names)
    print(out/'index.html')


def write_gallery(out,manifest,names):
    html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Singularity Lance — Prismatic Liturgy</title><style>
:root{color-scheme:dark;font:16px/1.55 Segoe UI,system-ui,sans-serif;color:#e8edf3;background:#090d17}body{max-width:1400px;margin:40px auto;padding:0 28px}h1{font-size:46px;font-weight:500;margin:0}h2{font-size:21px;font-weight:500;margin-bottom:4px}.intro{max-width:900px;color:#a5b7c5}.eyebrow{color:#00e1ff;letter-spacing:.2em;font-size:12px}.controls{position:sticky;top:0;background:#111a27ed;border-bottom:1px solid #304052;padding:14px 18px;display:flex;gap:24px;align-items:center;flex-wrap:wrap;z-index:2}button,select{font:inherit;color:inherit;background:#1c2a3c;border:1px solid #3a4c64;border-radius:4px;padding:5px 10px}input{accent-color:#ff4fcd}section{border-top:1px solid #2c3646;padding:22px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:36px}.marks{display:flex;flex-wrap:wrap;justify-content:space-between;gap:15px}canvas{max-width:100%;background:#090d17}p{margin-top:5px}.note{font-size:14px;color:#a5b7c5}.icons{display:flex;gap:20px}.icons img{width:22%;max-width:240px}a{color:#76dcff}footer{margin:40px 0;color:#a5b7c5}@media(max-width:850px){.pair{grid-template-columns:1fr}}
</style><p class="eyebrow">VIREX // ΛAMENON · STAGED ART DIRECTION</p><h1>Prismatic Liturgy</h1>
<p class="intro">One luminous material, four successive transformations: cut, remember, gather, consume. These are new procedural motion studies drawn from the original lance’s cyan/cobalt, magenta/violet and orange/gold/white palette. No game files have been replaced.</p>
<div class="controls"><button id="play">Pause</button><label>Speed <select id="speed"><option value="1">Real time</option><option value=".25">Quarter speed</option><option value=".5">Half speed</option></select></label><label><input id="glow" type="checkbox" checked> Optional glow</label><label>Ground <select id="ground"><option value="#090d17">Dark</option><option value="#343d35">Ordinary ground</option><option value="#817d65">Bright ground</option></select></label><label>Cycle <input id="scrub" type="range" min="0" max="119" value="0"></label></div>
<section><h2>Axial Rupture — the spectrum is cut</h2><p class="note">White-gold axis; paired cyan banks; rolling polarized color and long filament tails. Final beam implementation should tile this material rather than stretch its pattern across the entire range.</p><canvas data-key="axial" width="1100" height="180"></canvas></section>
<section><h2>Wound Memory — light refuses to heal</h2><p class="note">Three persistent silhouettes. The fracture stays readable while currents travel along it. In-game attachment, expiry and stacks remain mechanical state.</p><div class="marks"><canvas data-key="wound-1" width="290" height="290"></canvas><canvas data-key="wound-2" width="290" height="290"></canvas><canvas data-key="wound-3" width="290" height="290"></canvas></div></section>
<div class="pair"><section><h2>Terminal Collapse — the spectrum gathers</h2><p class="note">Thirty warning ticks, then impact. Curved tails spiral into the fixed aim point; the circumference is the timing cue.</p><canvas data-key="collapse" width="480" height="420"></canvas></section><section><h2>Black-Hole Testament — the color is consumed</h2><p class="note">A dark aperture framed by saturated accretion tails. Its impact briefly cuts a white-hot cross through the disk.</p><canvas data-key="testament" width="480" height="420"></canvas></section></div>
<section><h2>Testament discharge</h2><canvas data-key="testament-beam" width="1100" height="180"></canvas></section>
<section><h2>Mineral emblem studies</h2><p class="note">Faceted mineral and emerald etched support tie the icons to the original machine. These composition studies still need a material-detail pass; the uniform octagonal badges are gone.</p><div class="icons">ICON_IMAGES</div></section>
<footer>Preview only. Canvas drives this local review page; shipping animations should be engine-driven sheets with no new Lua polling. The browser is not a Factorio visual acceptance capture. <a href="direction-board.png">Direction board</a> · <a href="motion-study.webp">Animated overview</a> · <a href="timing-strip.png">Timing strip</a></footer>
<script>const specs=MANIFEST;let tick=0,playing=true,last=performance.now();const images={};let ready=0;
for(const key in specs){images[key]={};for(const layer of ['core','glow']){const im=new Image();im.onload=()=>ready++;im.src='factorio-export/'+key+(layer==='glow'?'-glow':'')+'.png';images[key][layer]=im}}
const controls={play:document.querySelector('#play'),speed:document.querySelector('#speed'),glow:document.querySelector('#glow'),ground:document.querySelector('#ground'),scrub:document.querySelector('#scrub')};controls.play.onclick=()=>{playing=!playing;controls.play.textContent=playing?'Pause':'Play'};controls.scrub.oninput=()=>{tick=+controls.scrub.value;playing=false;controls.play.textContent='Play'};
function paint(canvas){const ctx=canvas.getContext('2d'),kind=canvas.dataset.key;ctx.fillStyle=controls.ground.value;ctx.fillRect(0,0,canvas.width,canvas.height);let key=kind,frame=Math.floor(tick*(kind.startsWith('wound')?.5:.8))%32;
if(kind==='collapse'||kind==='testament'){const local=Math.floor(tick)%120;if(local>=42)return;key=kind+(local<30?'-warning':'-impact');frame=local<30?local:local-30;ctx.fillStyle='#adc0d0';ctx.font='14px Segoe UI';ctx.fillText(local<30?'Warning '+(local+1)+'/30':'Impact '+(local-29)+'/12',12,22)}
const s=specs[key],scale=Math.min((canvas.width-36)/s.width,(canvas.height-30)/s.height),w=s.width*scale,h=s.height*scale,x=(canvas.width-w)/2,y=(canvas.height-h)/2;
for(const layer of controls.glow.checked?['glow','core']:['core']){const im=images[key][layer];if(im.complete&&im.naturalWidth)ctx.drawImage(im,(frame%s.columns)*s.width,Math.floor(frame/s.columns)*s.height,s.width,s.height,x,y,w,h)}}
function loop(now){if(playing)tick=(tick+(now-last)*.06*+controls.speed.value)%120;last=now;controls.scrub.value=Math.floor(tick);document.querySelectorAll('canvas').forEach(paint);requestAnimationFrame(loop)}requestAnimationFrame(loop);
</script></html>'''
    html=html.replace('MANIFEST',json.dumps(manifest)).replace('ICON_IMAGES',''.join(f'<img alt="{name}" src="{name.lower().replace(" ","-")}-icon-study.png">' for name in names))
    (out/'index.html').write_text(html,encoding='utf-8')


if __name__=='__main__':
    main()
