"""Stage complete source ZIPs and verify exact inventory, decoded art lineage and caps."""
from pathlib import Path
import argparse, hashlib, json, os, zipfile

REPO=Path.cwd()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dossier', type=Path, default=REPO/'output/minigun-implementation/standalone-rename-001')
parser.add_argument('--package-directory', type=Path)
ARGS=parser.parse_args()
ROOT=ARGS.dossier.resolve()
HD='minigun-turret-HD'
CAP=256_000_000


def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()


def main():
    output=(ARGS.package_directory or ROOT/'packages').resolve()
    assert output.is_relative_to(ROOT) and output!=ROOT
    assert not output.exists(), 'Keep old delivery measurements; choose a new dossier'
    output.mkdir()
    original=json.loads((REPO/'output/minigun-implementation/finalized-minigun/artifact-map.json').read_text(encoding='utf-8-sig'))
    revision=json.loads((REPO/'output/minigun-implementation/icon-framing-001/revision.json').read_text(encoding='utf-8-sig'))
    checked=0
    for row in original['artifacts']:
        if row['profile']!='hd' or row['path']=='graphics/items/gatling-turret.png': continue
        assert sha(REPO/HD/row['path'])==row['sha256'], 'Approved render changed: '+row['path']
        checked+=1
    assert sha(REPO/HD/'graphics/items/gatling-turret.png')=='121a3c25d52c75ffe1ef06c454eef33004cc6b11da7db31847e3a3fd1f8e9bd7'
    records=[]
    for pack in [HD,'exotic-space-industries-remembrance']:
        source=REPO/pack;info=json.loads((source/'info.json').read_text(encoding='utf-8-sig'))
        assert info['name']==pack
        prefix=pack+'_'+info['version'];archive=output/(prefix+'.zip')
        files={p.relative_to(source).as_posix():p for p in sorted(source.rglob('*')) if p.is_file()}
        assert all(not p.is_symlink() for p in files.values())
        evidence=[]
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9,allowZip64=False) as z:
            for relative,p in files.items():
                before=sha(p)
                entry=zipfile.ZipInfo(prefix+'/'+relative,date_time=(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry._compresslevel=9;entry.external_attr=0o100644<<16
                with p.open('rb') as src,z.open(entry,'w') as dst:
                    for block in iter(lambda:src.read(1024*1024),b''):dst.write(block)
                assert sha(p)==before
                evidence.append({'path':relative,'sha256':before,'bytes':p.stat().st_size})
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            assert z.namelist()==[prefix+'/'+p for p in files]
            for row in evidence:
                assert hashlib.sha256(z.read(prefix+'/'+row['path'])).hexdigest()==row['sha256']
        size=archive.stat().st_size
        assert size<CAP, 'Archive exceeds project byte limit'
        record={'pack':pack,'version':info['version'],'path':str(archive.relative_to(REPO)),'zip_bytes':size,'sha256':sha(archive),'files':evidence,'integrity_passed':True,'strict_cap_passed':True}
        records.append(record)
        print(pack,size,'bytes;',len(files),'files',flush=True)
    report={'schema':'minigun-turret.package-delivery.v1','archives':records,'approved_hd_render_hashes_verified':checked,'current_item_icon_verified':True,'live_installation_changed':False}
    (ROOT/'package-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
