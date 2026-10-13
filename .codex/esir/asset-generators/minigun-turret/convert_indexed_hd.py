"""Create a reproducible indexed-HD derivative; never overwrite source art.

Requires Pillow, numpy and imagequant==1.1.5 (bundled libimagequant 2.15.1).
The lossless renderer/finalizer remains the geometry authority, not a pixel
equality certificate for this explicitly lossy derivative. Resume by verified
source/output hashes; the palette and generator are pinned for the whole run.
"""
from __future__ import annotations
import argparse, hashlib, io, json, struct, sys
from pathlib import Path
import numpy as np
import PIL
from PIL import Image, PngImagePlugin

def sha(data): return hashlib.sha256(data).hexdigest()
def digest(path): return sha(path.read_bytes())
def chunks(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos=8; result={}
    while pos<len(data):
        size=struct.unpack('>I',data[pos:pos+4])[0];tag=data[pos+4:pos+8]
        if tag in (b'sRGB',b'gAMA',b'cHRM'): result[tag.decode()]=data[pos+8:pos+8+size].hex()
        pos+=size+12
    return result
def info(profile):
    result=PngImagePlugin.PngInfo()
    for tag,value in profile.items():result.add(tag.encode(),bytes.fromhex(value))
    return result
def relative(filename):
    result=filename.split('__/',1)[1]
    assert '..' not in Path(result).parts and result.startswith('graphics/')
    return result
def files(leaf):return [relative(s) for s in leaf.get('filenames',[leaf.get('filename')])]
def write_json(path,value):
    temp=path.with_suffix('.json.partial');temp.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');temp.replace(path)

class Quantizer:
    def __init__(self, palette):
        self.palette=np.array(palette,dtype=np.uint8)
        self.attr=lib.liq_attr_create();lib.liq_set_max_colors(self.attr,len(palette));lib.liq_set_speed(self.attr,4)
        hist=lib.liq_histogram_create(self.attr)
        for color in palette:
            c=ffi.new('liq_color *',dict(zip(('r','g','b','a'),map(int,color))))
            assert lib.liq_histogram_add_fixed_color(hist,c[0],0)==lib.LIQ_OK
        # This bundled libimagequant requires image statistics even when every
        # palette entry is fixed. The swatch image cannot introduce new colors.
        swatch=self.palette.tobytes()
        image=lib.liq_image_create_rgba(self.attr,swatch,len(palette),1,0)
        assert lib.liq_histogram_add_image(hist,self.attr,image)==lib.LIQ_OK
        lib.liq_image_destroy(image)
        result=ffi.new('liq_result**');assert lib.liq_histogram_quantize(hist,self.attr,result)==lib.LIQ_OK
        self.result=result[0];lib.liq_histogram_destroy(hist);lib.liq_set_dithering_level(self.result,0)
        p=lib.liq_get_palette(self.result)
        actual=[(c.r,c.g,c.b,c.a) for c in p.entries][:p.count]
        positions={tuple(c):i for i,c in enumerate(palette)}
        assert set(actual)==set(positions), 'Fixed palette changed'
        self.indices=np.array([positions[c] for c in actual],dtype=np.uint8)
        opaque=np.flatnonzero(self.palette[:,3]==255);transparent=np.flatnonzero(self.palette[:,3]==0)
        assert len(opaque) and len(transparent)
        self.zero=int(transparent[0]);self.opaque_map=np.resize(opaque,256)
        self.opaque_palette=Image.new('P',(1,1));self.opaque_palette.putpalette(self.palette[self.opaque_map,:3].flatten().tolist())
    def convert(self,image):
        image=image.convert('RGBA');a=np.asarray(image);raw=image.tobytes()
        source=lib.liq_image_create_rgba(self.attr,raw,image.width,image.height,0)
        buf=ffi.new('char[]',image.width*image.height)
        assert lib.liq_write_remapped_image(self.result,source,buf,image.width*image.height)==lib.LIQ_OK
        ids=self.indices[np.frombuffer(bytes(ffi.buffer(buf)),dtype=np.uint8).reshape(image.height,image.width)]
        lib.liq_image_destroy(source)
        bad=(a[:,:,3]==255)&(self.palette[ids,3]!=255)
        if np.any(bad):
            nearest=np.asarray(image.convert('RGB').quantize(palette=self.opaque_palette,dither=Image.Dither.NONE))
            ids[bad]=self.opaque_map[nearest[bad]]
        ids[a[:,:,3]==0]=self.zero
        out=Image.frombytes('P',image.size,ids.tobytes());out.putpalette(self.palette[:,:3].flatten().tolist())
        out.info['transparency']=self.palette[:,3].tobytes()
        decoded=np.asarray(out.convert('RGBA'))
        assert np.all(decoded[:,:,3][a[:,:,3]==0]==0)
        assert np.all(decoded[:,:,3][a[:,:,3]==255]==255)
        return out

def train(source,leaves,sample_limit=1600):
    attr=lib.liq_attr_create();lib.liq_set_max_colors(attr,256);lib.liq_set_speed(attr,4)
    hist=lib.liq_histogram_create(attr);total=0;cells=0
    zero=ffi.new('liq_color *',{'r':0,'g':0,'b':0,'a':0})
    assert lib.liq_histogram_add_fixed_color(hist,zero[0],0)==lib.LIQ_OK
    for leaf in leaves:
        w,h=leaf['width'],leaf['height']
        for rel in files(leaf):
            a=np.asarray(Image.open(source/rel).convert('RGBA'));samples=[]
            assert a.shape[1]%w==0 and a.shape[0]%h==0
            for y in range(0,a.shape[0],h):
                for x in range(0,a.shape[1],w):
                    visible=a[y:y+h,x:x+w].reshape(-1,4);visible=visible[visible[:,3]>0];cells+=1
                    if len(visible)>sample_limit:visible=visible[np.linspace(0,len(visible)-1,sample_limit,dtype=int)]
                    if len(visible):samples.append(visible)
            if samples:
                v=np.concatenate(samples);total+=len(v)
                v=np.pad(v,((0,(-len(v))%1024),(0,0)));raw=v.tobytes()
                image=lib.liq_image_create_rgba(attr,raw,1024,len(v)//1024,0)
                assert lib.liq_histogram_add_image(hist,attr,image)==lib.LIQ_OK
                lib.liq_image_destroy(image)
        print(json.dumps({'training_family':files(leaf)[0],'cells_so_far':cells,'visible_samples':total}),flush=True)
    result=ffi.new('liq_result**');assert lib.liq_histogram_quantize(hist,attr,result)==lib.LIQ_OK
    p=lib.liq_get_palette(result[0]);palette=[[c.r,c.g,c.b,c.a] for c in p.entries][:p.count]
    # Some antialiased icons train near-opaque entries (254) but no 255 entry.
    # Preserve a useful opaque color range instead of mapping every solid icon
    # pixel to one fallback color. Intermediate opacity is explicitly lossy.
    if not any(c[3]==255 for c in palette):
        threshold=max(c[3] for c in palette)-4
        for c in palette:
            if c[3]>=threshold:c[3]=255
        palette=[list(c) for c in dict.fromkeys(tuple(c) for c in palette)]
    for fn,obj in [(lib.liq_result_destroy,result[0]),(lib.liq_histogram_destroy,hist),(lib.liq_attr_destroy,attr)]:fn(obj)
    return palette,{'cells':cells,'visible_samples':total,'directions':256,'rotor_poses':28,'max_samples_per_cell':sample_limit}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,required=True);parser.add_argument('--metadata',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--tool-path',type=Path,required=True)
    args=parser.parse_args();repo=args.repo.resolve();out=args.output.resolve()
    assert out.is_relative_to(repo/'output') and out!=repo/'output'
    sys.path.insert(0,str(args.tool_path.resolve()))
    global lib,ffi
    from imagequant import lib,ffi
    from importlib.metadata import version
    assert version('imagequant')=='1.1.5' and lib.liq_version()==21501
    source=repo/'minigun-turret-HD';meta=json.loads(args.metadata.read_text(encoding='utf-8-sig'));profile=meta['profiles']['hd']
    colors=[profile['base'],profile['upper']]+profile['rotor']['layers']
    roles={rel:'entity' for leaf in colors for rel in files(leaf)}
    roles.update({relative(profile[k]):'icon' for k in ('item_icon','technology_icon')})
    roles.update({rel:'shadow' for rel in files(profile['shadow'])})
    assert len(roles)==199 and sum(v=='shadow' for v in roles.values())==64
    sources={rel:digest(source/rel) for rel in sorted(roles)}
    contract={'generator_sha256':digest(Path(__file__)),'metadata_sha256':digest(args.metadata),'sources':sources,
              'imagequant':'1.1.5','libimagequant':lib.liq_version(),'pillow':PIL.__version__,'numpy':np.__version__,
              'dithering':0,'max_colors':256,'density':64,'scale':0.5,'alpha_policy':'preserve_0_and_255; quantize_intermediate',
              'lossless_postprocess':'PNG DEFLATE level 9 versus level 6; retain smaller decoded-identical result'}
    out.mkdir(parents=True,exist_ok=True)
    pin=out/'source-contract.json'
    if pin.exists():assert json.loads(pin.read_text())==contract,'Inputs changed; choose a new output dossier'
    else:write_json(pin,contract)
    palette_file=out/'entity-palette.json'
    if palette_file.exists():trained=json.loads(palette_file.read_text())
    else:
        palette,stats=train(source,colors);trained={'palette':palette,'training':stats};write_json(palette_file,trained)
    assert trained['training']['cells']==1+256+4*256*28
    entity=Quantizer(trained['palette']);receipts=out/'receipts';receipts.mkdir(exist_ok=True)
    records=[]
    for number,(rel,role) in enumerate(sorted(roles.items()),1):
        src=source/rel;target=out/'assets'/rel;receipt=receipts/(sha(rel.encode())+'.json')
        if receipt.exists():
            row=json.loads(receipt.read_text());assert row['source_sha256']==sources[rel] and target.is_file() and digest(target)==row['sha256']
            records.append(row);continue
        payload=src.read_bytes();color=chunks(payload);image=Image.open(io.BytesIO(payload));original=image.convert('RGBA')
        target.parent.mkdir(parents=True,exist_ok=True)
        row={'path':rel,'role':role,'source_sha256':sources[rel],'source_bytes':len(payload),'size':list(image.size),'color_chunks':color}
        if role=='shadow':
            assert image.mode=='LA';result=payload;row.update(mode='LA',unchanged_shadow=True)
        else:
            quantizer=entity
            if role=='icon':
                leaf={'filename':'__minigun-turret-HD__/'+rel,'width':image.width,'height':image.height}
                palette,stats=train(source,[leaf],sample_limit=image.width*image.height);quantizer=Quantizer(palette);row['palette']=palette
            candidate=quantizer.convert(image);decoded=candidate.convert('RGBA').tobytes();variants=[]
            for level in (6,9):
                encoded=io.BytesIO();candidate.save(encoded,format='PNG',compress_level=level,pnginfo=info(color));variants.append(encoded.getvalue())
            result=min(variants,key=len);check=Image.open(io.BytesIO(result))
            assert check.mode=='P' and check.size==image.size and check.convert('RGBA').tobytes()==decoded
            before=np.asarray(original);after=np.asarray(check.convert('RGBA'));a=before[:,:,3]
            assert np.all(after[:,:,3][a==0]==0) and np.all(after[:,:,3][a==255]==255)
            row.update(mode='P',palette_entries=len(quantizer.palette),alpha_zero_exact=True,alpha_opaque_exact=True,
                       intermediate_alpha_changes=int(np.sum(before[:,:,3]!=after[:,:,3])),decoded_rgba_sha256=sha(decoded),
                       lossless_postprocess_verified=True)
        assert chunks(result)==color and digest(src)==sources[rel]
        temporary=target.with_suffix('.png.partial');temporary.write_bytes(result);temporary.replace(target)
        row.update(sha256=sha(result),bytes=len(result));write_json(receipt,row);records.append(row)
        print(json.dumps({'file':number,'of':len(roles),'path':rel,'bytes':len(result)}),flush=True)
    assert all(digest(source/rel)==value for rel,value in sources.items())
    report={'schema':'esir.minigun.indexed-hd.v1','complete':True,'density':64,'default_profile_slot':'sd',
            'shadow_tier':'complete_hd_combined','source_contract_sha256':digest(pin),'palette_sha256':digest(palette_file),
            'training':trained['training'],'native_geometry_lineage_only':True,'original_pixel_equality_claim':False,
            'artifacts':records,'source_bytes':sum(r['source_bytes'] for r in records),'output_bytes':sum(r['bytes'] for r in records)}
    write_json(out/'conversion-report.json',report)
    print(json.dumps({k:v for k,v in report.items() if k!='artifacts'}),flush=True)

if __name__=='__main__':main()
