"""Locate native template attachment origins using authored source-frame pixels.

This calibrates isolated template geometry, never actual turret launch points.
It binds source PNG bytes and native screenshots; no expected muzzle is an input.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

from analyze_fixture import fs_path,rgb,sha
from fit_flash_origin import correlate,signal


def run(root,output,data_root):
    root,output,data_root=map(fs_path,(root,output,data_root))
    report=json.loads((root/'native-report.json').read_text(encoding='utf-8-sig'))
    result={'schema':1,'native_report_sha256':sha(root/'native-report.json'),'approved':False,'ammunition':{}}
    for ammo,group in report.get('flash_templates',{}).items():
        caps={c['shot_offset']:c for c in group['captures']}
        capture=caps[0]
        delta=rgb(root/capture['path'])-rgb(root/caps[-1]['path'])
        origins=[]
        for index,definition in enumerate(group['definitions']):
            source=next(x for x in report['prototype_audit']['flashes'].values()
                        if x['original']==definition['original'] and not x['hidden'])
            animation=source['animations'][index]
            filename=animation['filename']
            if not filename.startswith('__base__/'):raise ValueError('Explicit source-root support required: '+filename)
            sprite=data_root/'base'/filename[len('__base__/'):]
            width,height=animation['width'],animation['height']
            zoom=capture['zoom']
            scale=animation.get('scale',1)*zoom
            size=(round(width*scale),round(height*scale))
            shift=animation.get('shift',[0,0])
            if isinstance(shift,dict):shift=[shift['x'],shift['y']]
            matches=[]
            with Image.open(sprite) as sheet:
                for frame in range(animation.get('frame_count',1)):
                    line=animation.get('line_length',animation.get('frame_count',1))
                    x=animation.get('x',0)+(frame%line)*width
                    y=animation.get('y',0)+(frame//line)*height
                    pixels=sheet.crop((x,y,x+width,y+height)).convert('RGBA').resize(size,Image.Resampling.NEAREST)
                    rgba=np.asarray(pixels,dtype=np.float32)
                    colors=rgba[:,:,:3]*rgba[:,:,3:]/255
                    template=np.zeros((128,128,3),dtype=np.float32)
                    left=round(64-size[0]/2+shift[0]*32*zoom)
                    top=round(64-size[1]/2+shift[1]*32*zoom)
                    if min(left,top)<0 or left+size[0]>128 or top+size[1]>128:raise ValueError('Source frame exceeds template support')
                    template[top:top+size[1],left:left+size[0]]=colors
                    fit=correlate(signal(delta[:,index*256:(index+1)*256]),signal(template))
                    fit['frame']=frame;matches.append(fit)
            matches.sort(key=lambda x:x['score'],reverse=True)
            best=matches[0]
            best['origin_pixels'][0]+=index*256
            best.update(variation=definition['variation'],capture=capture['path'],capture_sha256=sha(root/capture['path']),
                source_png=filename,source_sha256=sha(sprite),authored_frame_size=[width,height],
                status='source_frame_pixel_match' if best['score']>=0.65 and best['translation_peak_margin']>=0.04 else 'ambiguous',
                approved=False)
            origins.append(best)
        result['ammunition'][ammo]={'origins':origins}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--data-root',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data'))
    args=parser.parse_args()
    result=run(args.evidence,args.output,args.data_root)
    print(json.dumps(result,indent=2))
