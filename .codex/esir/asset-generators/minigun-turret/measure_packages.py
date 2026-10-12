"""Build and measure complete review archives without promoting shipping files.

The explicit artifact map supplies only approved minigun destinations. Existing
pack content is read fresh and retained. Results are candidate measurements,
not release approval or proof of firing alignment.
"""
from __future__ import annotations
import argparse, hashlib, json, os, zipfile
from pathlib import Path, PurePosixPath

CAP = 256_000_000
WARNING = 240_000_000
PACKS = {'exotic-space-industries-remembrance-graphics-6': {'profile': 'sd', 'version': '1.0.0'},
         'minigun-turret-HD': {'profile': 'hd', 'version': '1.0.0'}}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def relative(value):
    p = PurePosixPath(value)
    if p.is_absolute() or '..' in p.parts or not p.parts or '\\' in value:
        raise ValueError('Unsafe artifact destination: '+value)
    if value.startswith('graphics/entities/gatling-turret/') or value in (
        'graphics/items/gatling-turret.png', 'graphics/techs/gatling-turret.png'):
        return p.as_posix()
    raise ValueError('Artifact is outside the approved minigun family: '+value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--artifact-map', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = args.repo.resolve(); output = args.output.resolve()
    if not output.is_relative_to(repo) or output == repo or output.parts[len(repo.parts)] not in ('output', '.factorio-qc', 'temp'):
        raise ValueError('Archive output must stay in repository ignored staging')
    artifact_map = args.artifact_map.resolve()
    manifest = json.loads(artifact_map.read_text(encoding='utf-8-sig'))
    assert manifest['schema'] == 'esir.minigun.artifact-map.v1'
    assert manifest['complete_direction_family'] is True, 'Final ZIP measurement requires all 256 directions'
    assert not output.exists() or not any(output.iterdir()), 'Choose a fresh output directory; prior archives are retained'
    output.mkdir(parents=True, exist_ok=True)
    overlays = {pack:{} for pack in PACKS}
    for row in manifest['artifacts'] + manifest.get('support_artifacts', []):
        pack = row['pack']; assert pack in PACKS
        if row.get('role') == 'graphics_library_metadata':
            assert pack == 'minigun-turret-HD' and row['path'] == 'lib/graphics-data.lua'
            target = row['path']
        else:
            target = relative(row['path'])
        source = Path(row['source'])
        if not source.is_absolute(): source = artifact_map.parent/source
        source = source.resolve()
        if not source.is_relative_to(repo) or not source.is_file():
            raise ValueError('Artifact source must be a retained repository file: '+str(source))
        assert digest(source) == row['sha256'], 'Changed artifact: '+str(source)
        assert target not in overlays[pack], 'Duplicate destination: '+target
        assert row.get('profile') == PACKS[pack]['profile'], 'Archive contains a PNG from the wrong density profile'
        overlays[pack][target] = source
    result = {'schema':'esir.minigun.archive-measurement.v1',
              'status':'candidate_archive_measurement', 'archive_cap_bytes':CAP,
              'early_warning_bytes':WARNING, 'artifact_map_sha256':digest(artifact_map),
              'shadow_tier':manifest['shadow_tier'], 'firing_alignment_approval':False,
              'generator_sha256':digest(Path(__file__)), 'archives':[]}
    for pack in PACKS:
        root = repo/pack
        info = json.loads((root/'info.json').read_text(encoding='utf-8-sig'))
        assert info['name'] == pack
        expected_version = PACKS[pack]['version']
        assert info['version'] == expected_version, 'Unexpected pack version'
        files = {}
        for source in sorted(root.rglob('*')):
            if source.is_file():
                assert not source.is_symlink(), 'Packaging refuses linked sources'
                files[source.relative_to(root).as_posix()] = source
        files.update(overlays[pack])
        prefix = f'{pack}_{info["version"]}'
        archive = output/(prefix+'.zip')
        temporary = output/(prefix+'.zip.partial')
        evidence = []
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=False) as z:
            for path, source in sorted(files.items()):
                before = digest(source); stat = source.stat()
                entry = zipfile.ZipInfo(prefix+'/'+path, date_time=(1980,1,1,0,0,0))
                entry.compress_type = zipfile.ZIP_DEFLATED; entry._compresslevel = 9
                entry.external_attr = 0o100644 << 16
                with source.open('rb') as src, z.open(entry, 'w') as dst:
                    for chunk in iter(lambda: src.read(1024*1024), b''): dst.write(chunk)
                assert digest(source) == before and source.stat().st_size == stat.st_size, 'Source changed while packaging'
                evidence.append({'path':path, 'bytes':stat.st_size, 'sha256':before,
                                 'minigun_overlay':path in overlays[pack]})
        with zipfile.ZipFile(temporary) as z:
            assert z.testzip() is None, 'ZIP integrity failed'
            assert len(z.namelist()) == len(files) == len(set(z.namelist()))
        os.replace(temporary, archive)
        size = archive.stat().st_size
        record = {'pack':pack, 'version':info['version'], 'path':str(archive.relative_to(repo)),
                  'zip_bytes':size, 'zip_mb':size/1_000_000, 'sha256':digest(archive),
                  'strict_cap_passed':size < CAP, 'overage_bytes':max(0,size-CAP),
                  'early_warning':size >= WARNING, 'zip_integrity_passed':True,
                  'file_count':len(files), 'files':evidence}
        result['archives'].append(record)
        print(json.dumps({k:v for k,v in record.items() if k!='files'}), flush=True)
    result['strict_caps_passed'] = all(r['strict_cap_passed'] for r in result['archives'])
    (output/'archive-measurement.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    if not result['strict_caps_passed']: raise SystemExit(2)


if __name__ == '__main__': main()
