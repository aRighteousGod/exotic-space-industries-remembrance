"""Build deterministic release candidates with an explicit shipping file policy.

No installation or publication. Preserves original source-only archives, editor
files and caches in place while excluding them from the actual mod ZIPs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

EXTENSIONS = {'.lua', '.json', '.cfg', '.png', '.ogg', '.wav', '.txt', '.md'}
EXCLUDED_DIRECTORIES = {'.git', '.qc', 'dist', 'output', '__pycache__', 'tests'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pack', action='append', required=True, help='Source folder, repeat for multiple packs')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    receipts = []
    for folder in args.pack:
        source = Path(folder)
        info = json.loads((source / 'info.json').read_text(encoding='utf-8-sig'))
        assert re.fullmatch(r'[A-Za-z0-9_-]+', info['name'])
        assert info['factorio_version'] == '2.1'
        root = info['name'] + '_' + info['version']
        archive = args.output / (root + '.zip')
        assert not archive.exists(), 'Use a new candidate folder; preserve earlier candidates'
        files, excluded = [], []
        for path in sorted(source.rglob('*')):
            if not path.is_file():
                continue
            relative = path.relative_to(source)
            if any(part in EXCLUDED_DIRECTORIES for part in relative.parts) or (
                    path.suffix.lower() not in EXTENSIONS and path.name not in ('LICENSE', 'COPYING')):
                excluded.append(relative.as_posix())
            else:
                files.append((relative, path))
        inventory = []
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as target:
            for relative, path in files:
                data = path.read_bytes()
                assert b'esir-fusion-qc' not in data if relative.as_posix() == 'control.lua' else True
                entry = zipfile.ZipInfo(root + '/' + relative.as_posix(), date_time=(2026, 10, 27, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                target.writestr(entry, data, compresslevel=6)
                inventory.append(dict(path=relative.as_posix(), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        with zipfile.ZipFile(archive) as target:
            assert target.testzip() is None
            assert json.loads(target.read(root + '/info.json')) == info
            assert len(target.namelist()) == len(inventory)
        with archive.open('rb') as stream:
            checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
        receipt = dict(name=info['name'], version=info['version'], source=str(source.absolute()),
                       archive=str(archive.absolute()), sha256=checksum, bytes=archive.stat().st_size,
                       files=inventory, excluded=excluded, published=False, engine_tested=False)
        (args.output / (root + '.manifest.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        receipts.append({k:v for k,v in receipt.items() if k not in ('files','excluded')})
        print(json.dumps(receipts[-1]), flush=True)
    (args.output / 'packages.json').write_text(json.dumps(receipts, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
