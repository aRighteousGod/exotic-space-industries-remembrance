"""Lossless PNG filter/deflate trials; never rewrite the source asset.

Pinned zopfli 0.4.0 may be installed in a task-local --tool-path. Every selected
image must retain exact decoded RGBA and its sRGB/gAMA/cHRM chunks. Hidden RGB
is also preserved: both lossy optimizer switches are explicitly disabled.
"""
import argparse, hashlib, io, json, sys, time
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from compile_separated import png_color_chunks


def sha(value): return hashlib.sha256(value).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,nargs='+',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--tool-path',type=Path)
    p.add_argument('--iterations',type=int,default=5)
    p.add_argument('--filters-only',action='store_true')
    args=p.parse_args()
    if args.tool_path: sys.path.insert(0,str(args.tool_path.resolve()))
    import zopfli, zopfli.png
    assert zopfli.__version__=='0.4.0', 'Pinned zopfli version required'
    args.output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for path in args.source:
        before=path.read_bytes();profile=png_color_chunks(before)
        assert set(profile)=={'sRGB','gAMA','cHRM'}
        original=np.asarray(Image.open(io.BytesIO(before)).convert('RGBA'))
        started=time.monotonic()
        optimized=zopfli.png.optimize(before,lossy_transparent=False,lossy_8bit=False,
            keepchunks=list(profile),use_zopfli=not args.filters_only,
            num_iterations=args.iterations,num_iterations_large=args.iterations)
        assert np.array_equal(original,np.asarray(Image.open(io.BytesIO(optimized)).convert('RGBA')))
        assert png_color_chunks(optimized)==profile, 'Color metadata changed'
        assert path.read_bytes()==before, 'Source changed during optimization'
        result=min((before,optimized),key=len)
        # SD and HD intentionally share basenames; keep both retained results.
        source_key=sha(str(path.resolve()).encode('utf-8'))[:12]
        target=args.output/(source_key+'-'+path.name)
        assert target.resolve()!=path.resolve(), 'Source overwrite prohibited'
        target.write_bytes(result)
        row={'source':str(path.resolve()),'output':str(target.resolve()),
             'source_sha256':sha(before),'sha256':sha(result),
             'before_bytes':len(before),'after_bytes':len(result),
             'decoded_rgba_equal':True,'color_chunks_equal':True,
             'seconds':time.monotonic()-started}
        rows.append(row);print(json.dumps(row),flush=True)
    report={'schema':'esir.minigun.png-optimization.v1','zopfli_version':zopfli.__version__,
            'filters_only':args.filters_only,'iterations':args.iterations,
            'generator_sha256':sha(Path(__file__).read_bytes()),'files':rows}
    (args.output/'optimization-report.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
