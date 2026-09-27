"""Reproduce the pinned 2026-09-24 save profile used by this UPS comparison.

The binary offsets below belong ONLY to the hash-checked save. This is not a
general Factorio save decoder. Never substitute the current live settings file.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import zipfile
import zlib

parser = argparse.ArgumentParser()
parser.add_argument('--save', required=True, type=Path)
parser.add_argument('--base-seed', required=True, type=Path)
parser.add_argument('--installed-mods', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
expected = '30FEA966BBAC323AEB9E6BBA30B35C6D0E56E88F3B433073FDF765AB3263B03D'
assert hashlib.sha256(args.save.read_bytes()).hexdigest().upper() == expected, 'Different save: offsets are not reusable.'
with zipfile.ZipFile(args.save) as archive:
    names = [name for name in archive.namelist() if name.endswith('/level.dat0')]
    assert len(names) == 1
    level = zlib.decompress(archive.read(names[0]))
startup = level[1301:15765]
assert startup[:2] == b'\x05\x00' and struct.unpack_from('<I', startup, 2)[0] == 269


def string(value):
    raw = value.encode()
    assert len(raw) < 255
    return b'\x00' + bytes([len(raw)]) + raw


def dictionary(entries):
    return b'\x05\x00' + struct.pack('<I', len(entries)) + b''.join(string(key) + value for key, value in entries)


args.output.mkdir(exist_ok=False, parents=True)
for path in args.base_seed.glob('*.zip'):
    os.link(path, args.output / path.name)
mods = json.loads((args.base_seed / 'mod-list.json').read_text(encoding='utf-8-sig'))
for name, version in [('AspctTrainPatch', '1.1.0'), ('module-inserter', '1.0.4'),
                      ('visible-planets', '1.7.2'), ('vp-scale', '1.4.1'),
                      ('recipe-icons-improvement-for-esir', '1.1.26')]:
    path = args.installed_mods / f'{name}_{version}.zip'
    shutil.copyfile(path, args.output / path.name)
    mods['mods'] = [mod for mod in mods['mods'] if mod['name'] != name] + [{'name': name, 'enabled': True}]
for mod in mods['mods']:
    if mod['name'] == 'extinguisher':
        mod['enabled'] = False
(args.output / 'mod-list.json').write_text(json.dumps(mods, indent=2), encoding='utf-8')
empty = dictionary([])
payload = struct.pack('<4HB', 2, 0, 77, 0, 0) + dictionary([
    ('startup', startup), ('runtime-global', empty), ('runtime-per-user', empty)])
(args.output / 'mod-settings.dat').write_bytes(payload)
(args.output / 'provenance.json').write_text(json.dumps({
    'save': str(args.save.resolve()), 'save_sha256': expected, 'startup_entries': 269,
    'startup_bytes': [1301, 15765], 'settings_sha256': hashlib.sha256(payload).hexdigest(),
}, indent=2), encoding='utf-8')
print(args.output.resolve())
