"""Assemble review, measured sizes and a verified archive of retained masters."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import zipfile

ROOT=Path.cwd()
ASSETS=('sweeping-radar','phased-array-radar')
destination=ROOT/'output/meshy/radar-production'
source=Path(__file__).parent

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()

manifests={};assets=[];retained=[]
for asset in ASSETS:
    root=ROOT/'output/meshy'/asset
    manifests[asset]={}
    for facings in (256,128,64):
        export=root/'factorio-export'/str(facings)
        value=json.loads((export/'spritesheet-manifest.json').read_text())
        checks=json.loads((export/'verification.json').read_text())
        assert checks['all_pass']
        assert checks['asset']==asset and checks['facings']==facings
        assert checks['spritesheet_manifest_sha256']==sha(export/'spritesheet-manifest.json')
        assert hashlib.sha256((ROOT/value['master_manifest']).read_bytes()).hexdigest()==value['master_manifest_sha256']
        for layer in value['layers'].values():
            for page in layer['pages']:
                assert hashlib.sha256((export/page['filename']).read_bytes()).hexdigest()==page['sha256']
        manifests[asset][str(facings)]=value
    master_path=root/'master-256/Render/radar-master-manifest.json'
    master=json.loads(master_path.read_text());assert master['complete']
    raw_bytes=0
    for frame in master['frames'].values():
        for record in frame['passes'].values():
            path=master_path.parent/record['path']
            data=path.read_bytes()
            assert hashlib.sha256(data).hexdigest()==record['sha256']
            assert data[:8]==b'\x89PNG\r\n\x1a\n' and data[24:26]==bytes([16,6])
            retained.append((path,asset+'/master-256/Render/'+record['path'],record['sha256']))
            raw_bytes+=path.stat().st_size
    for name in ('radar-master-manifest.json','factorio-preset-render-manifest.json'):
        path=master_path.parent/name
        retained.append((path,asset+'/master-256/Render/'+name,hashlib.sha256(path.read_bytes()).hexdigest()))
    assets.append(dict(asset=asset,master_frames=256,raw_pass_frames=256*len(master['contract']['passes']),
        raw_bytes=raw_bytes,raw_directory=str(master_path.parent.relative_to(ROOT)),
        variants={count:dict(png_bytes=record['png_bytes'],decoded_rgba_bytes=record['decoded_rgba_bytes'])
                  for count,record in manifests[asset].items()}))
archive=destination/'radar-master-renders-256.zip'
temporary=archive.with_suffix('.zip.tmp')
with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_STORED,allowZip64=True) as zipped:
    for path,name,digest in retained:zipped.write(path,name)
    zipped.writestr('RETAINED-MASTERS.txt','User-approved 256-facing radar masters. Keep these original PNGs.\n'
        'Extract into output/meshy/ under the ESIR repository to restore the default repacking paths.\n'
        '256/128/64 sheets are generated without rerendering by the repository radar asset generator.\n'
        'Master PNGs retain 16-bit RGBA channels; normal shipping sheets use RGBA8.\n'
        'This archive is source material, not part of the shipped mod.\n')
with zipfile.ZipFile(temporary) as zipped:
    assert zipped.testzip() is None
    for path,name,digest in retained:
        assert hashlib.sha256(zipped.read(name)).hexdigest()==digest
temporary.replace(archive)
report=dict(completed_at=datetime.now().astimezone().isoformat(),selected_facings=256,
    master_pass_frames=sum(a['raw_pass_frames'] for a in assets),assets=assets,
    combined_sizes={str(count):dict(png_bytes=sum(manifests[a][str(count)]['png_bytes'] for a in ASSETS),
                    decoded_rgba_bytes=sum(manifests[a][str(count)]['decoded_rgba_bytes'] for a in ASSETS))
                    for count in (256,128,64)},
    retained_archive=dict(path=str(archive.relative_to(ROOT)),bytes=archive.stat().st_size,
        sha256=sha(archive),all_entries_verified=True),
    shipping_graphics_changed=False,live_runtime_integration=False)
(destination/'spritesheet-completion.json').write_text(json.dumps(report,indent=2)+'\n')
template=(source/'spritesheets.html').read_text(encoding='utf-8')
html=template.replace('<script>','<script>window.RADAR_SHEETS='+json.dumps(manifests,separators=(',',':'))+';\n',1)
(destination/'spritesheets-review.html').write_text(html,encoding='utf-8')
print(json.dumps(report,indent=2))
