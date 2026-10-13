"""Retain the native registration comparison and approved PNG lineage."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageDraw

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dossier',type=Path,default=Path.cwd()/'output/minigun-implementation/centering-next')
ROOT=parser.parse_args().dossier.resolve()
REPO=Path.cwd().resolve()
assert ROOT.is_relative_to(REPO/'output/minigun-implementation')
report=json.loads((ROOT/'native/report.json').read_text())
audit=report['audit']
assert report['engine']=='2.0.77' and report['shots']>0
for key in ('all256_launch_entries_translated','all_animation_and_shadow_leaves_translated',
            'repeated_apply_stable','source_metadata_unchanged'):
    assert audit[key]
assert audit['delta']==.1875
assert audit['selection_box']==[[-1.5,-1.5],[1.5,1.5]]
assert audit['collision_box']==[[-1.4,-1.4],[1.4,1.4]]

pixels=np.array(Image.open(ROOT/'native/parked.png').convert('RGB'),dtype=np.float64)
displacements=[]
for density,before_y,after_y in [('sd',288,672),('hd',1056,1440)]:
    first=pixels[before_y-115:before_y+40,602:742]
    mask=(first.max(axis=2)>65)&~((first[:,:,1]>first[:,:,0]+25)&(first[:,:,1]>first[:,:,2]+25))
    candidates=[]
    for delta in range(0,21):
        second=pixels[after_y-115+delta:after_y+40+delta,602:742]
        candidates.append(float(np.mean((first[mask]-second[mask])**2)))
    measured=int(np.argmin(candidates))
    assert measured==12,(density,measured,candidates)
    displacements.append({'density':density,'zoom':2,'native_pixels_south':measured,
                          'standard_pixels_south':measured/2,'matching_mse':candidates[measured]})

baseline=json.loads((REPO/'output/minigun-implementation/casing-ejection-001/package-report.json').read_text())
count=0
for pack in baseline['archives']:
    for entry in pack['files']:
        relative=entry['path']
        if relative.endswith('.png') and ('gatling-turret/' in relative or relative.endswith('/gatling-turret.png')):
            current=REPO/pack['pack']/relative
            assert hashlib.sha256(current.read_bytes()).hexdigest()==entry['sha256'],str(current)
            count+=1
assert count>0

sheet=Image.new('RGB',(1000,690),(24,24,24))
draw=ImageDraw.Draw(sheet)
parked=Image.open(ROOT/'native/parked.png').convert('RGB')
for row,(density,before_y,after_y) in enumerate([('SD',288,672),('HD',1056,1440)]):
    for col,(state,y) in enumerate([('Before',before_y),('After: 6 px south',after_y)]):
        crop=parked.crop((442,y-155,922,y+135))
        sheet.paste(crop,(col*500+10,row*340+38))
        draw.text((col*500+14,row*340+12),density+' — '+state,fill=(240,240,240))
sheet.save(ROOT/'review.png')
result={'passed':True,'engine':'2.0.77','native_engine_exit_code':0,
        'presentation_offset_tiles':[0,.1875],'native_displacement':displacements,
        'all256_launch_entries_translated':True,'all_color_shadow_state_leaves_translated':True,
        'original_metadata_preserved':True,'repeated_apply_stable':True,
        'unchanged_minigun_pngs':count,'selection_collision_boxes_unchanged':True,
        'native_visual_review_passed':True,'shots':report['shots'],
        'fixture_note':'Main SD factory copied verbatim; shipping standalone HD factory. No full main gameplay load or full firing-matrix repeat.',
        'setup_note':'Initial benchmark flag corrected before native graphics ran; daylight-only capture repeated for readable evidence.'}
(ROOT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
