"""Stage complete current main/G6 ZIPs for the indexed-HD default profile.

The sd key is a profile-selection slot, never an assumed 32 px/tile density.
Verify shipping membership against the derivative manifest and retained backup.
No installation, cleanup or Git operation is performed.
"""
from pathlib import Path
import argparse,hashlib,json,zipfile
from PIL import Image

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,required=True)
    p.add_argument('--dossier',type=Path,required=True);p.add_argument('--conversion',type=Path,required=True)
    a=p.parse_args();repo=a.repo.resolve();dossier=a.dossier.resolve()
    assert dossier.is_relative_to(repo/'output')
    conversion=json.loads((a.conversion/'conversion-report.json').read_text())
    baseline=json.loads((dossier/'baseline.json').read_text())
    assert conversion['complete'] and conversion['density']==64
    g6=repo/'exotic-space-industries-remembrance-graphics-6';hd=repo/'minigun-turret-HD'
    expected={x['path'] for x in conversion['artifacts']};modes={}
    for row in conversion['artifacts']:
        file=g6/row['path'];assert sha(file)==row['sha256']
        with Image.open(file) as im:
            assert im.mode==row['mode'] and list(im.size)==row['size']
            modes[im.mode]=modes.get(im.mode,0)+1
    actual={p.relative_to(g6).as_posix() for p in (g6/'graphics/entities/gatling-turret').glob('*') if p.is_file()}
    actual|={'graphics/items/gatling-turret.png','graphics/techs/gatling-turret.png'}
    assert actual==expected and modes=={'P':135,'LA':64}
    for path,h in baseline['graphics6_other'].items():
        if path not in ('info.json','changelog.txt'):assert sha(g6/path)==h,'Unrelated Graphics6 content changed: '+path
    assert {p.relative_to(hd).as_posix():sha(p) for p in hd.rglob('*') if p.is_file()}==baseline['hd_all_files']
    main_info=json.loads((repo/'exotic-space-industries-remembrance/info.json').read_text())
    assert 'exotic-space-industries-remembrance-graphics-6 >= 1.0.1' in main_info['dependencies']
    output=dossier/'packages';assert not output.exists(),'Keep previous package measurements';output.mkdir()
    records=[]
    for name,version in [('exotic-space-industries-remembrance','1.3.43'),('exotic-space-industries-remembrance-graphics-6','1.0.1')]:
        root=repo/name;assert json.loads((root/'info.json').read_text())['version']==version
        files={p.relative_to(root).as_posix():p for p in sorted(root.rglob('*')) if p.is_file()}
        assert all(not p.is_symlink() for p in files.values())
        prefix=name+'_'+version;archive=output/(prefix+'.zip');rows=[]
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9,allowZip64=False) as z:
            for rel,file in files.items():
                payload=file.read_bytes();digest=hashlib.sha256(payload).hexdigest()
                zi=zipfile.ZipInfo(prefix+'/'+rel,date_time=(1980,1,1,0,0,0));zi.compress_type=zipfile.ZIP_DEFLATED;zi._compresslevel=9;zi.external_attr=0o100644<<16
                z.writestr(zi,payload);assert sha(file)==digest
                rows.append({'path':rel,'bytes':len(payload),'sha256':digest})
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None and len(z.infolist())==len(files)
            for row in rows:assert hashlib.sha256(z.read(prefix+'/'+row['path'])).hexdigest()==row['sha256']
        # Verify the complete tree again to catch concurrent edits during packaging.
        assert {p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file()}=={r['path']:r['sha256'] for r in rows}
        record={'pack':name,'version':version,'path':str(archive.relative_to(repo)),'zip_bytes':archive.stat().st_size,
                'sha256':sha(archive),'strict_cap_passed':archive.stat().st_size<256_000_000,'integrity_passed':True,'files':rows}
        records.append(record);print(json.dumps({k:v for k,v in record.items() if k!='files'}),flush=True)
    report={'schema':'esir.minigun.indexed-package.v1','archives':records,'modes':modes,
            'full_color_hd_unchanged':True,'unrelated_graphics6_baseline_unchanged':True,'live_installation_changed':False}
    (dossier/'package-report.json').write_text(json.dumps(report,indent=2)+'\n')
    assert all(x['strict_cap_passed'] for x in records),'Measured archive exceeds project cap; do not discard shadows automatically'

if __name__=='__main__':main()
