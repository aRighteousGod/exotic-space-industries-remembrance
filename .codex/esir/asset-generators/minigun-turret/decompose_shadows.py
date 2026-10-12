"""Candidate shadow families from measured all-caster references.

Native alpha-over has been measured; these candidates still require native
real-geometry/fractional-registration comparison before promotion. The RGB
channels remain grayscale reference values. Only alpha is solved; Factorio's
shadow atlas processing must be confirmed to reproduce the reference visually.
"""
import argparse, hashlib, json, sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from compile_separated import (ReferenceReader, PHYSICAL_POSES, PILOT_DIRECTIONS,
    bounds, union_bounds, padded_crop, packing_directory, pack_family, canonical_rgba)


def accumulate(a,b):
    # Exact integer source-over alpha rounding, independently checked against
    # Pillow by the native color compiler. No max-opacity approximation.
    a=a.astype(np.int32);b=b.astype(np.int32)
    return ((a*255+b*(255-a)+127)//255).astype(np.uint8)


def residual(under,target,floor=False):
    u=under.astype(np.int32);t=target.astype(np.int32)
    assert np.all(t>=u),'Shadow underlay exceeds the all-caster target'
    denominator=255-u
    numerator=(t-u)*255
    safe=np.maximum(denominator,1)
    result=(numerator//safe if floor else (numerator+safe//2)//safe)
    result[denominator==0]=0
    return np.clip(result,0,255).astype(np.uint8)


def mask(reference,alpha):
    image=reference.copy();image[:,:,3]=alpha
    return canonical_rgba(image)


class ShadowCompiler:
    def __init__(self,reader,directions,density):
        self.reader=reader;self.directions=directions;self.density=density
        self.radius=density//8;self.size=540*density//64
        self.cache_direction=None;self.cache_upper=None

    def load(self,family,direction=0,pose=0):
        return self.reader.load(family,direction,pose,'Shadow',self.density)

    def prepare(self):
        base=self.load('base');low=base[:,:,3].copy();self.upper_goals={}
        for d in self.directions:
            upper=self.load('upper',d);goal=upper[:,:,3].copy()
            for p in range(PHYSICAL_POSES): goal=np.minimum(goal,self.load('full',d,p)[:,:,3])
            self.upper_goals[d]=goal;low=np.minimum(low,goal)
        self.base=mask(base,low)
        self.boxes={'base':bounds(self.base),'upper':None,'shadow':None}
        self.metrics={'native_alpha_over_measurement':'native-fixture/on-fold0-20261010-224556-d66595/analysis-v2/summary.json',
            'base_alpha_reduced_pixels':int(np.count_nonzero(low!=base[:,:,3])),
            'maximum_alpha_error':0,'native_real_geometry_validated':False,'native_filtered_seams_validated':False}
        for d in self.directions:
            under,upper=self.upper(d)
            self.boxes['upper']=union_bounds(self.boxes['upper'],bounds(upper))
            for p in range(PHYSICAL_POSES):
                target=self.load('full',d,p);rotor=self.frame('shadow',d,p)
                actual=accumulate(under,rotor[:,:,3])
                error=int(np.abs(actual.astype(np.int32)-target[:,:,3].astype(np.int32)).max())
                assert error<=1,(d,p,error)
                self.metrics['maximum_alpha_error']=max(self.metrics['maximum_alpha_error'],error)
                self.boxes['shadow']=union_bounds(self.boxes['shadow'],bounds(rotor))
        alignment=2 if self.density==64 else 1
        self.crops={k:padded_crop(v,(self.size,self.size),self.radius,alignment) for k,v in self.boxes.items()}
        return self

    def upper(self,d):
        if self.cache_direction!=d:
            reference=self.load('upper',d)
            alpha=residual(self.base[:,:,3],self.upper_goals[d],floor=True)
            upper=mask(reference,alpha)
            under=accumulate(self.base[:,:,3],alpha)
            assert np.all(under<=self.upper_goals[d])
            self.cache_direction=d;self.cache_upper=(under,upper)
        return self.cache_upper

    def frame(self,family,direction=0,pose=0):
        if family=='base': return self.base
        if family=='upper': return self.upper(direction)[1]
        target=self.load('full',direction,pose)
        alpha=residual(self.upper(direction)[0],target[:,:,3])
        return mask(target,alpha)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input-root',type=Path,required=True)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--directions',default='0,32,64,96,128,160,192,224')
    args=parser.parse_args()
    directions=list(range(256)) if args.directions=='all' else [int(x) for x in args.directions.split(',')]
    assert directions==sorted(set(directions)) and all(0<=d<256 for d in directions)
    reader=ReferenceReader(args.input_root.resolve());reader.required(directions)
    for family, direction, pose in [('base',0,0)]+[('upper',d,0) for d in directions]:
        if (family,direction,pose,'Shadow') not in reader.records or not reader.path(family,direction,pose,'Shadow').is_file():
            raise ValueError(f'Missing all-caster reference: {family}, {direction}, {pose}')
    output=(args.output or args.input_root/'shadow-candidates').resolve();output.mkdir(parents=True,exist_ok=True)
    report={'schema':'esir.minigun.shadow-candidates.v1','directions':directions,
        'complete_direction_family':directions==list(range(256)),
        'native_law':'alpha_over','native_real_geometry_validated':False,
        'render_configuration_hash':reader.configuration['hash'],
        'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'compiler_sha256':hashlib.sha256((HERE/'compile_separated.py').read_bytes()).hexdigest(),
        'profiles':{}}
    for name,density in [('sd',32),('hd',64)]:
        profile_root=output/name;profile_root.mkdir(parents=True,exist_ok=True)
        compiler=ShadowCompiler(reader,directions,density).prepare()
        with packing_directory(profile_root) as temporary:
            families={f:pack_family(compiler,f,profile_root,temporary) for f in ('base','upper','shadow')}
        for row in families.values(): row['leaf']['draw_as_shadow']=True
        total=sum(x['bytes'] for x in families.values())
        projected=families['base']['bytes']+sum(families[f]['bytes']*256/len(directions) for f in ('upper','shadow'))
        report['profiles'][name]={'density':density,'families':families,
            'leaves':{f:families[f]['leaf'] for f in families},'metrics':compiler.metrics,
            'png_bytes':total,'projected_256_png_bytes':int(np.ceil(projected))}
        print('SHADOW_CANDIDATE '+json.dumps({'profile':name,'bytes':total,'projected':projected,'metrics':compiler.metrics}),flush=True)
    report['source_files']=reader.sources
    (output/'metadata.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
