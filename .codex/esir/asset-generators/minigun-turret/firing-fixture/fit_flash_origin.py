"""Fit actual native flash pixels to isolated native templates; never approve a gate.

The attachment point is the known zero-height template origin translated by the
image fit. The search never receives a proposed muzzle coordinate. Native frame
timing, rotation rasterization, smoke and overlapping projectiles can make a fit
ambiguous; confidence is diagnostic and every result remains unapproved.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from analyze_fixture import fs_path, rgb, sha


def signal(delta):
    light=np.clip(np.maximum(delta,0).mean(axis=2),0,255).astype(np.uint8)
    image=Image.fromarray(light)
    smooth=np.asarray(image.filter(ImageFilter.GaussianBlur(2)),dtype=np.float32)
    return light.astype(np.float32)-smooth


def correlate(source,template):
    """Cosine correlation at every fully-contained translation, no anchor prior."""
    height,width=template.shape
    rows,cols=source.shape
    shape=(rows+height-1,cols+width-1)
    scores=np.fft.irfft2(np.fft.rfft2(source,s=shape)*
                        np.conj(np.fft.rfft2(template,s=shape)),s=shape)
    scores=scores[:rows-height+1,:cols-width+1]
    summed=np.pad(np.cumsum(np.cumsum(source*source,axis=0),axis=1),((1,0),(1,0)))
    energy=summed[height:,width:]-summed[:-height,width:]-summed[height:,:-width]+summed[:-height,:-width]
    scores=scores/np.sqrt(np.maximum(energy,1)*max(float((template*template).sum()),1))
    y,x=np.unravel_index(np.argmax(scores),scores.shape)
    others=scores.copy()
    others[max(0,y-8):y+9,max(0,x-8):x+9]=-1
    return {"score":float(scores[y,x]),"translation_peak_margin":float(scores[y,x]-others.max()),
            "origin_pixels":[float(x+width/2),float(y+height/2)]}


def rotation(signal_image,degrees):
    # F-mode retains signed high-pass values. Rotation interpolation is a fitting
    # approximation, not a claim to duplicate Factorio's rasterizer exactly.
    return np.asarray(Image.fromarray(signal_image).rotate(degrees,
        resample=Image.Resampling.BILINEAR,expand=False,fillcolor=0),dtype=np.float32)


def fit(source,templates):
    if float((source*source).sum())<500:
        return {"status":"no_native_signal","approved":False}
    candidates=[]
    for template in templates:
        pixels=template["signal"]
        if float((pixels*pixels).sum())<500:
            continue
        best=None
        for angle in range(0,360,15):
            candidate=correlate(source,rotation(pixels,angle))
            candidate.update(template=template["identity"],angle_degrees=angle)
            if best is None or candidate["score"]>best["score"]:best=candidate
        for angle in range(int(best["angle_degrees"])-7,int(best["angle_degrees"])+8):
            candidate=correlate(source,rotation(pixels,angle))
            candidate.update(template=template["identity"],angle_degrees=angle%360)
            if candidate["score"]>best["score"]:best=candidate
        candidates.append(best)
    if not candidates:return {"status":"no_template_signal","approved":False}
    candidates.sort(key=lambda row:row["score"],reverse=True)
    best=candidates[0]
    nearby=[row for row in candidates if row["score"]>=best["score"]-0.05]
    spread=max(float(np.linalg.norm(np.asarray(row["origin_pixels"])-best["origin_pixels"])) for row in nearby)
    alternatives=[dict(row) for row in candidates[:5]]
    best.update(status="review_candidate" if best["score"]>=0.65 and spread<=3 and best["translation_peak_margin"]>=0.04 else "ambiguous",
                competing_origin_spread_pixels=spread,alternatives=alternatives,approved=False)
    return best


def run(root,output,case_ids=None,template_calibration=None):
    root,output=fs_path(root),fs_path(output)
    report=json.loads((root/"native-report.json").read_text(encoding="utf-8-sig"))
    calibration=json.loads(fs_path(template_calibration).read_text(encoding="utf-8-sig")) if template_calibration else {}
    if calibration and calibration.get('native_report_sha256')!=sha(root/'native-report.json'):
        raise ValueError('Template-origin calibration belongs to different native image evidence')
    output.mkdir(parents=True,exist_ok=True)
    results=[]
    cache={}
    for case in report["cases"]:
        if case["spec"]["kind"]!="static" or case_ids and case["id"] not in case_ids:continue
        rows={row["variant"]:row for row in case["rows"]}
        captures={name:{cap["shot_offset"]:cap for cap in row["captures"]} for name,row in rows.items()}
        ammo=case["spec"]["ammo"]
        group=report.get("flash_templates",{}).get(ammo)
        if not group:
            results.append({"case":case["id"],"status":"native_templates_missing","approved":False});continue
        origins=calibration.get('ammunition',{}).get(ammo,{}).get('origins',[])
        if len(origins)!=len(group['definitions']):
            results.append({'case':case['id'],'status':'template_attachment_origins_require_image_calibration','approved':False});continue
        if ammo not in cache:
            template_captures={cap["shot_offset"]:cap for cap in group["captures"]}
            base=rgb(root/template_captures[-1]["path"])
            templates=[]
            for offset,cap in template_captures.items():
                if offset<0:continue
                atlas=rgb(root/cap["path"])-base
                for index,definition in enumerate(group["definitions"]):
                    measured=origins[index]
                    if measured.get('status')!='source_frame_pixel_match' or measured['capture_sha256']!=sha(root/measured['capture']):
                        raise ValueError('Template origin lacks matching actual image bytes')
                    center,y=map(round,measured['origin_pixels'])
                    tile=signal(atlas[y-64:y+64,center-64:center+64])
                    if tile.shape!=(128,128):raise ValueError('Calibrated template crop falls outside atlas')
                    templates.append({"signal":tile,"identity":{"path":cap["path"],"sha256":sha(root/cap["path"]),
                        "variation":definition["variation"],"shot_offset":offset,
                        "known_attachment_origin_in_crop":[64,64],"template_height":0,
                        "origin_calibration":measured}})
            cache[ammo]=templates
        base_native=rgb(root/captures["native"][-1]["path"])
        base_blank=rgb(root/captures["blank"][-1]["path"])
        measured=[]
        # Match the first three actual shot updates. A later best-looking tail
        # must never substitute for a missing launch frame.
        for offset in (0,1,2):
            cap=captures["native"][offset]
            native=rgb(root/cap["path"])
            difference=(native-base_native)-(rgb(root/captures["blank"][offset]["path"])-base_blank)
            candidates=[x for x in cache[ammo] if abs(x["identity"]["shot_offset"]-offset)<=1]
            result=fit(signal(difference),candidates)
            result.update(case=case["id"],capture=cap["path"],sha256=sha(root/cap["path"]),shot_offset=offset,
                zoom=cap["zoom"],method="native_template_pixel_translation_rotation_fit",native_visibility_confirmed=False)
            measured.append(result)
            if "origin_pixels" in result:
                image=Image.fromarray(native.astype(np.uint8));draw=ImageDraw.Draw(image)
                x,y=result["origin_pixels"]
                draw.line((x-10,y,x+10,y),fill=(0,255,255),width=1)
                draw.line((x,y-10,x,y+10),fill=(0,255,255),width=1)
                image.resize((960,960),Image.Resampling.NEAREST).save(output/f'{case["id"]}-t{offset}.png')
        results.extend(measured)
    result={"schema":1,"status":"unreviewed_pixel_measurements","approved":False,"results":results,
        "candidate_data_sha256":report["config"]["candidate_data_sha256"],
        "limitations":["No expected muzzle coordinates enter the search",
            "Native templates have zero height, fixed rotation and no secondary emissions; firing effects stay native",
            "Template source tick alignment and CPU rotation rasterization require native inspection",
            "Missing or ambiguous first flash remains unresolved; projectile origins are not inferred by this tool",
            "Copying suggestions into a review without image inspection is not acceptance"]}
    (output/"flash-origin-fits.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf8")
    return result


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--case",action="append",dest="cases")
    parser.add_argument('--template-calibration',type=Path)
    args=parser.parse_args()
    result=run(args.evidence,args.output,set(args.cases) if args.cases else None,args.template_calibration)
    print(json.dumps({"status":result["status"],"measurements":len(result["results"]),"approved":False}))
