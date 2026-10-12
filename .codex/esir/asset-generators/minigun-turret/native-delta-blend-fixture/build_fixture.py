"""Known-color native multiplier/additive proof; no art conversion or engine run."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, PngImagePlugin

MOD='zzz-esir-minigun-color'


def lua(value):
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,bool):return 'true' if value else 'false'
    if value is None:return 'nil'
    return repr(value)


def build(output):
    output.mkdir(parents=True,exist_ok=True)
    h,w=128,192
    under=np.zeros((h,w,4),np.uint8);target=under.copy()
    colors=[((110,70,35),(91,61,24)),((40,95,140),(57,119,163)),
            ((140,95,45),(151,70,55)),((0,60,255),(12,44,249)),
            ((211,187,156),(91,98,122)),((5,8,12),(53,22,16)),
            ((80,80,80),(80,80,80)),((210,90,60),(160,112,44))]
    for i,(u,t) in enumerate(colors):
        x,y=16+i%4*40,16+i//4*48
        for dy in range(40):
            for dx in range(32):
                # Per-pixel texture makes fractional-filter covariance observable.
                modulation=((dx//4+dy//4)%2)*7
                under[y+dy,x+dx,:3]=np.clip(np.array(u)+modulation,0,255)
                target[y+dy,x+dx,:3]=np.clip(np.array(t)+modulation,0,255)
                under[y+dy,x+dx,3]=target[y+dy,x+dx,3]=255
    normal=np.zeros_like(under)
    eligible=np.zeros((h,w),bool)
    for i in range(8):
        x,y=16+i%4*40,16+i//4*48
        eligible[y+6:y+34,x+6:x+26]=True
    opaque=under[:,:,3]==255
    normal[opaque&~eligible]=target[opaque&~eligible]
    u,t=under[:,:,:3].astype(np.int32),target[:,:,:3].astype(np.int32)
    minimum=np.minimum(u,t)
    factor=np.full_like(u,255)
    np.divide(minimum*255,np.maximum(u,1),out=factor,casting='unsafe')
    factor=np.where(u==0,255,np.floor(minimum*255/np.maximum(u,1)+.5)).astype(np.int32)
    multiplied=(u*factor+127)//255
    delta=t-multiplied
    assert np.all(delta[eligible]>=0)
    assert np.array_equal((multiplied+delta)[eligible],t[eligible])
    multiplier=np.zeros_like(under);multiplier[:,:,:3]=255
    multiplier[eligible,:3]=factor[eligible];multiplier[eligible,3]=255
    additive=np.zeros_like(under);additive[eligible,:3]=delta[eligible];additive[eligible,3]=255
    # The identity control must leave the original U unchanged at every light level.
    identity=np.zeros_like(under);identity[:,:,:3]=255;identity[eligible,3]=255
    background=np.zeros((512,512,4),np.uint8);background[:]=[72,94,108,255]
    yy,xx=np.indices((512,512));background[(xx//16+yy//16)%2==0]=[105,112,117,255]
    foreground=np.zeros_like(under);foreground[34:42,24:168]=[16,213,163,255]
    glow=np.zeros_like(under);glow[84:88,24:168]=[231,177,31,190]
    arrays={'under':under,'reference':target,'normal':normal,'multiplier':multiplier,'additive':additive,
            'identity':identity,'background':background,'foreground':foreground,'fx':glow}
    info=PngImagePlugin.PngInfo();info.add(b'sRGB',b'\x03');info.add(b'gAMA',(45455).to_bytes(4,'big'))
    info.add(b'cHRM',bytes.fromhex('00007a26000080840000fa00000080e8000075300000ea6000003a9800001770'))
    files=[]
    for name,array in arrays.items():
        path=output/(name+'.png');Image.fromarray(array).save(path,optimize=True,pnginfo=info)
        assert np.array_equal(np.array(Image.open(path).convert('RGBA')),array)
        files.append({'path':'graphics/'+path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[array.shape[1],array.shape[0]]})
    cases=[]
    for surface in ('base','state','base-state'):
        for variant in ('ordinary','glow'):
            for daytime in (0,.4,.5):
                for zoom in (1,1.5):
                    for offset in (0,.5):
                        cases.append({'id':f'{surface}-{variant}-t{daytime:g}-z{zoom:g}-f{offset:g}',
                            'surface':surface,'variant':variant,'daytime':daytime,'zoom':zoom,'offset':offset,
                            'resolution':[384,320]})
    for variant in ('ordinary','glow'):
        for daytime in (0,.4,.5):
            cases.append({'id':f'identity-{variant}-t{daytime:g}','surface':'base-state','variant':variant,
                          'daytime':daytime,'zoom':1.5,'offset':.5,'identity':True,'resolution':[384,320]})
    for daytime in (0,.4,.5):
        cases.append({'id':f'control-t{daytime:g}','surface':'state','variant':'ordinary','daytime':daytime,
                      'zoom':1.5,'offset':.5,'control':True,'resolution':[384,320]})
    contract={'schema':'esir.minigun.native-delta-blend.v1','width':w,'height':h,'cases':cases,
              'first_tick':20,'finish_tick':24+8*len(cases),'rgb_max_allowance':2,'rgb_rms_allowance':.25,
              'proposed_blend_modes':['multiplicative-with-alpha','additive'],
              'coefficient_premul_alpha':False,'multiplier_hidden_rgb':'white identity with alpha zero',
              'expected_no_light_emission':True,'production_approved':False}
    manifest={'schema':contract['schema'],'matrix':'delta-blend-proof','files':files,'cases':cases,
              'benchmark_ticks':contract['finish_tick']+20,'production_approved':False,
              'source_equation':'M=round(255*min(T,U)/U); D=T-round(U*M/255); zero-U M=255',
              'png_encoding_lossless':True,'coefficient_math_center_error':0}
    (output.parent/'contract.lua').write_text('return '+lua(contract)+'\n')
    (output.parent/'color-input-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=build(args.output)
    print(json.dumps({'cases':len(result['cases']),'benchmark_ticks':result['benchmark_ticks'],'engine_started':False}))
