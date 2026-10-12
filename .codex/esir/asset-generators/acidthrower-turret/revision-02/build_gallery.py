"""Validate and losslessly pack rendered review frames; build the local gallery.

Pillow is used only for technical pass compositing, crops, labels and packing.
Source renders and PBR colors are not retouched.
"""
import hashlib
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(os.environ.get('ESIR_ACID_REVISION_ROOT', 'D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
OUT = ROOT / 'gallery'
OUT.mkdir(exist_ok=True)
(OUT / 'frames').mkdir(exist_ok=True)
(ROOT / 'review-sheets').mkdir(exist_ok=True)
BG = (31, 37, 39, 255)
FG = (225, 229, 220)
MUTED = (156, 170, 161)
FONT = 'C:/Windows/Fonts/segoeui.ttf'
FACINGS = ['North', 'East', 'South', 'West']


def font(size):
    return ImageFont.truetype(FONT, size)


def read(role, channel, frame):
    return Image.open(ROOT / f'renders/{role}/{channel}/{frame:04}.png').convert('RGBA')


def combined(role, frame):
    shadow = read(role, 'Shadow', frame)
    # Display choice only: raw shadow masks are retained unchanged for export.
    shadow.putalpha(shadow.getchannel('A').point(lambda value: round(value * .5)))
    return Image.alpha_composite(shadow, read(role, 'Object', frame))


def board(size):
    return Image.new('RGBA', size, BG)


def label(im, xy, text, size=22, color=FG):
    ImageDraw.Draw(im).text(xy, text, font=font(size), fill=color)


def put(im, src, xy):
    im.alpha_composite(src, xy)


qa = {'passed': False, 'frames': [], 'pose_checks': [], 'raw_pack_roundtrip': True,
      'pixel_scales': {'review': 64, 'details': 256},
      'gallery_shadow_opacity': .5,
      'purpose': 'Model comparison only; these are not production animation sheets.'}
minimum_margin = 100000
for role, count, animation, size in [('base', 4, 1, 448), ('assembled', 20, 5, 448),
                                    ('head-only', 20, 5, 448), ('details', 4, 1, 1792)]:
    poses = json.loads((ROOT / f'renders/{role}/verified-frame-poses.json').read_text())
    manifest = json.loads((ROOT / f'renders/{role}/factorio-preset-render-manifest.json').read_text())
    assert len(poses) == count
    assert manifest['tile_size'] == (256 if role == 'details' else 64)
    assert manifest['ortho_scale'] == 7
    for i, pose in enumerate(poses):
        base_angle = (i // animation) * 90
        relative = -48 + (i % 5) * 24 if animation == 5 else 0
        assert abs(pose['base_degrees'] - base_angle) < .001
        assert abs(pose['relative_head_degrees'] - relative) < .001
        qa['pose_checks'].append({'role': role, 'frame': i + 1,
                                 'base_degrees': base_angle, 'relative_head_degrees': relative})
    for channel in ['Object', 'Shadow']:
        columns = 4 if animation == 1 else 5
        sheet = Image.new('RGBA', (size * columns, size * (count // columns)))
        for frame in range(1, count + 1):
            src = read(role, channel, frame)
            assert src.size == (size, size)
            bbox = src.getchannel('A').getbbox()
            assert bbox is not None
            margin = min(bbox[0], bbox[1], size - bbox[2], size - bbox[3])
            assert margin >= 8, (role, channel, frame, bbox)
            minimum_margin = min(minimum_margin, margin)
            qa['frames'].append({'role': role, 'pass': channel, 'frame': frame,
                                 'alpha_bounds': bbox, 'margin_pixels': margin})
            x, y = ((frame - 1) % columns) * size, ((frame - 1) // columns) * size
            sheet.paste(src, (x, y))
            assert sheet.crop((x, y, x + size, y + size)).tobytes() == src.tobytes()
        if role != 'details':
            sheet.save(ROOT / f'review-sheets/{role}-{channel.lower()}.png')
    if role != 'details':
        for frame in range(1, count + 1):
            combined(role, frame).save(OUT / f'frames/{role}-{frame:02}.png')

# Shared crop and scale preserve proportions across placement facings.
detail_crop = (432, 432, 1472, 1216)
four = board((1300, 1096))
label(four, (28, 17), 'ACIDTHROWER  /  REVISION 02', 28)
label(four, (28, 58), 'Centred head in each placement facing  ·  same 2 × 3 tile footprint', 19, MUTED)
for i, name in enumerate(FACINGS):
    x, y = (i % 2) * 650, 102 + (i // 2) * 497
    label(four, (x + 26, y), name.upper(), 21)
    src = combined('details', i + 1).crop(detail_crop).resize((650, 490), Image.Resampling.LANCZOS)
    put(four, src, (x, y + 13))
four.save(OUT / 'four-facings.png')

hero = board((790, 780))
label(hero, (28, 18), 'RECESSED TANK BED  /  PRESSURE-JET HEAD', 23)
label(hero, (28, 56), 'South placement  ·  head centred', 18, MUTED)
put(hero, combined('details', 3).crop((566, 536, 1316, 1226)), (20, 83))
hero.save(OUT / 'hero.png')

native_crop = (108, 108, 368, 304)
native = board((1080, 400))
label(native, (20, 14), 'NATIVE RENDER SCALE  /  64 pixels per tile', 23)
for i, name in enumerate(FACINGS):
    x = 20 + i * 265
    label(native, (x, 54), name, 18, MUTED)
    src = combined('assembled', 3 + i * 5).crop(native_crop)
    put(native, src, (x, 77))
    put(native, src.resize((130, 98), Image.Resampling.LANCZOS), (x + 65, 284))
label(native, (20, 270), '32 px/tile', 15, MUTED)
native.save(OUT / 'native-size.png')

parts = board((900, 410))
label(parts, (22, 16), 'SAME ORIGIN  /  SOUTH PLACEMENT', 24)
for i, (role, title) in enumerate([('assembled', 'Complete'), ('base', 'Fixed base + tanks'), ('head-only', 'Rotating head only')]):
    frame = 3 if role == 'base' else 13
    label(parts, (i * 300 + 20, 64), title, 20)
    src = combined(role, frame).crop(native_crop).resize((299, 225), Image.Resampling.NEAREST)
    put(parts, src, (i * 300, 99))
label(parts, (22, 354), 'The tanks, clamps, manifold and exterior ports stay with the base.', 19, MUTED)
parts.save(OUT / 'assembly-parts.png')

# Connector pair seen from the rear, with small outward-facing side crops.
connectors = board((960, 650))
label(connectors, (24, 16), 'MIRRORED EXTERIOR PIPE CONNECTIONS', 26)
label(connectors, (24, 54), 'Same height, diameter and grid alignment; opposite outward directions', 18, MUTED)
put(connectors, combined('details', 1).crop((562, 805, 1230, 1175)), (146, 95))
for index, (frame, x) in enumerate([(2, 46), (4, 526)]):
    poses = json.loads((ROOT / 'renders/details/verified-frame-poses.json').read_text())
    key = 'right_pipe_mouth' if frame == 2 else 'left_pipe_mouth'
    px, py = poses[frame - 1]['screen_anchors'][key]
    src = combined('details', frame).crop((round(px) - 135, round(py) - 95, round(px) + 135, round(py) + 85))
    put(connectors, src, (x + 50, 457))
    label(connectors, (x, 461), 'A' if index == 0 else 'B', 23, MUTED)
connectors.save(OUT / 'connector-pair.png')

nozzle = board((820, 460))
label(nozzle, (24, 16), 'STEPPED PRESSURE SLEEVE + OPEN CERAMIC OUTLET', 23)
label(nozzle, (24, 52), 'Modelled bore and recessed cavity; no painted opening', 18, MUTED)
put(nozzle, combined('details', 3).crop((730, 770, 1020, 1080)), (58, 108))
put(nozzle, combined('details', 2).crop((1060, 617, 1370, 897)), (438, 124))
nozzle.save(OUT / 'nozzle.png')

# Review keyposes, held within the existing +/-48 degree firing arc.
sequence = [0, 1, 2, 3, 4, 3, 2, 1]
arc_frames = []
for step in sequence:
    canvas = board((1040, 872))
    label(canvas, (24, 17), 'FIXED BASE  /  HEAD TRAVERSE WITHIN ±48°', 26)
    label(canvas, (24, 57), f'Relative aim: {-48 + 24 * step:+d}°  ·  five rendered review poses', 21, MUTED)
    for i, name in enumerate(FACINGS):
        x, y = (i % 2) * 520, 109 + (i // 2) * 382
        label(canvas, (x + 24, y), name, 20)
        src = combined('assembled', 1 + i * 5 + step).crop(native_crop)
        put(canvas, src.resize((494, 372), Image.Resampling.NEAREST), (x + 13, y + 10))
    arc_frames.append(canvas.convert('RGB'))
arc_frames[0].save(OUT / 'forward-arc.gif', save_all=True, append_images=arc_frames[1:],
                   duration=[480, 220, 480, 220, 480, 220, 480, 220], loop=0, optimize=False)

qa['minimum_unclipped_margin_pixels'] = minimum_margin
qa['passed'] = True
(ROOT / 'render-qa.json').write_text(json.dumps(qa, indent=2), encoding='utf-8')

html = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Acidthrower · Revision 02</title>
<style>
:root{color-scheme:dark;font-family:Segoe UI,system-ui,sans-serif;background:#171d1f;color:#e1e5dc}body{max-width:1320px;margin:auto;padding:32px}h1{font-size:36px;letter-spacing:-1px;margin:10px 0}h2{font-weight:500;margin-top:40px}p{line-height:1.65;max-width:950px;color:#bbc7bd}a{color:#b5c782}small,.eyebrow{color:#93a092}.eyebrow{letter-spacing:3px}img{max-width:100%;height:auto;display:block}figure{margin:18px 0;background:#1f2527;border:1px solid #36403d;border-radius:10px;overflow:hidden}figcaption{padding:14px 20px;color:#bbc7bd}section{margin-top:30px}.two{display:grid;grid-template-columns:1fr 1fr;gap:20px}.links{display:flex;gap:12px;flex-wrap:wrap}.links a{padding:12px 18px;border:1px solid #53614a;border-radius:5px;text-decoration:none}select,input{accent-color:#bbca88;background:#252e2b;color:#e1e5dc;padding:8px;border:1px solid #53614a}label{margin-right:18px}.viewer{display:grid;grid-template-columns:1fr 1fr;gap:20px;align-items:center;padding:20px}.viewer img{width:100%;image-rendering:pixelated}ul{line-height:1.8;color:#bbc7bd}.native{overflow:auto}.native img{max-width:none;width:1080px} @media(max-width:750px){body{padding:16px}.two,.viewer{grid-template-columns:1fr}}
</style>
<div class="eyebrow">ESIR / MODEL REVIEW / 2026-10-08</div>
<h1>Acidthrower — recessed rear tanks</h1>
<p>The selected pressure head, seated on a new elongated base. The footprint remains <strong>2 tiles across × 3 front-to-back</strong> (3 × 2 in east/west placement). Both upright canisters, clamps, plumbing and mirrored pipe collars belong to the fixed base.</p>
<div class="links"><a href="../prepared/assembled.glb">Complete GLB</a><a href="../prepared/base.glb">Fixed base GLB</a><a href="../prepared/head-only.glb">Head-only GLB</a><a href="../prepared/acidthrower-revision02.blend">Editable Blender scene</a><a href="../README.md">Replay notes</a></div>
<figure><img src="four-facings.png" alt="Four centred placement facings"><figcaption>Factorio rendering preset; each head is centred on its own base's forward direction. Identical camera and pixel scale across the four views. Gallery shadows use 50% opacity; raw object and shadow passes remain separate and unchanged.</figcaption></figure>
<h2>Placement and firing arc</h2>
<figure class="viewer"><img id="pose" src="frames/assembled-03.png" alt="Selected placement and aim"><div>
<p><label>Assembly <select id="role"><option value="assembled">Complete</option><option value="base">Fixed base + tanks</option><option value="head-only">Head only</option></select></label></p>
<p><label>Placement <select id="facing"><option>North</option><option>East</option><option>South</option><option>West</option></select></label></p>
<p><label>Relative aim <input id="aim" type="range" min="0" max="4" value="2" step="1"> <output id="angle">0°</output></label></p>
<p>Five actual rendered head poses: −48°, −24°, 0°, +24°, +48°. The base stays fixed. The control shows review poses, not a finished deployment or firing animation.</p></div></figure>
<figure><img src="forward-arc.gif" alt="Four placement facings traversing only within their forward arcs"><figcaption>Restricted forward-arc comparison. The rear tanks and external pipe connections remain fixed in every view.</figcaption></figure>
<h2>Readability at sprite scale</h2>
<figure class="native"><img src="native-size.png" alt="Native 64 pixel per tile previews and 32 pixel per tile display"><figcaption>Top row uses the raw 64 px/tile review render scale. Bottom row shows 32 px/tile display scale. This panel scrolls on narrow screens rather than silently shrinking the native previews.</figcaption></figure>
<figure><img src="assembly-parts.png" alt="Complete model, fixed base and isolated head with shared origin"></figure>
<div class="two"><figure><img src="connector-pair.png" alt="Mirrored exterior connector pair"><figcaption>One collar construction mirrored in Blender. Maximum measured mirror vertex error: 0.000000060 tiles.</figcaption></figure><figure><img src="nozzle.png" alt="Pressure sleeve and recessed ceramic outlet"><figcaption>The end cartridge has an actual small open bore. Stepped steel sleeve, retaining coupling and ceramic tip are precise Blender geometry.</figcaption></figure></div>
<h2>Checked for this comparison</h2>
<ul><li>Full fixed base, including pipe mouths, fits the existing 2 × 3 footprint.</li><li>33 sampled clearance poses at 3° intervals cover −48° to +48°. A conservative motion envelope also proves clearance between those samples against all 72 non-bearing fixed components. Intended bearing engagement is excluded from collision checks.</li><li>Actual rendered placement angles and bearing anchors are verified. All object and shadow frames have unclipped alpha bounds.</li><li>Complete and separate exports have identical object geometry and transforms; the original Meshy texture bytes are preserved.</li></ul>
<p><a href="../geometry-qa.json">Geometry QA</a> · <a href="../continuous-clearance-qa.json">Continuous arc proof</a> · <a href="../model-integrity.json">Export identity QA</a> · <a href="../render-qa.json">Render QA</a> · <a href="../model-anchors.json">Bearing and muzzle anchors</a> · <a href="../source/generation-ledger.json">Generation ledger</a></p>
<h2>Source and review boundary</h2>
<p>Meshy 7.1 PBR head: 4K geometry setting, 8K base colour, no remesh. Revision 02 used two 40-credit generations (80 total); the second generation was explicitly approved after the revised reference. The selected source is preserved alongside the superseded first attempt.</p>
<details><summary>Selected upper-only reference</summary><figure><img src="../source/upper-reference-refined.png" alt="Selected generated upper-only reference"></figure></details>
<p>This is a model and render review. The new base has a simpler surface finish than the scanned-looking Meshy head; that difference is most visible enlarged. Production sprite wiring, deployment animation, owner-colour mask export, muzzle calibration in the engine, and the original firing flash/alignment repair remain the next stage after the model decision. No gameplay or prototype changes are included.</p>
<script>
const role=document.getElementById('role'),facing=document.getElementById('facing'),aim=document.getElementById('aim');
function update(){const fixed=role.value==='base',d=facing.selectedIndex,a=Number(aim.value);aim.disabled=fixed;document.getElementById('angle').textContent=(fixed?0:-48+24*a)+'°';const frame=fixed?d+1:d*5+a+1;document.getElementById('pose').src='frames/'+role.value+'-'+String(frame).padStart(2,'0')+'.png';} [role,facing,aim].forEach(el=>el.addEventListener('input',update));update();
</script></html>'''
(OUT / 'index.html').write_text(html, encoding='utf-8')
print(json.dumps({'passed': True, 'checked_render_pass_frames': len(qa['frames']),
                  'checked_poses': len(qa['pose_checks']), 'minimum_margin_pixels': minimum_margin,
                  'gallery': str(OUT / 'index.html')}, indent=2))
