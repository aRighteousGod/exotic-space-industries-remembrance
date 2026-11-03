"""Instrument only the managed private main pack; retain source and injection hashes."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--phase', choices=['baseline', 'candidate', 'reload'], required=True)
    args = parser.parse_args()
    record = json.loads(Path(args.record).read_text(encoding='utf-8-sig'))
    target = Path(record['mods']) / 'exotic-space-industries-remembrance'
    source = Path(args.source).resolve()
    assert target.resolve() != source and not target.is_junction(), 'Refuse linked source mutation'
    files = ['control.lua'] + [f'scripts/control/{name}.lua' for name in (
        'combustion-turbine', 'induction-matrix', 'gaia', 'crystal-accumulator', 'steam-train', 'teslas-legacy')]
    hashes = {}
    for relative in files:
        content = (source / relative).read_bytes()
        hashes[relative] = hashlib.sha256(content).hexdigest()
        (target / relative).write_bytes(content)
    # Explicit fault injection only in private copies, with real native entities.
    turbine = target / 'scripts/control/combustion-turbine.lua'
    text = turbine.read_text(encoding='utf-8')
    signature = 'local function create_turbine_shell(surface, name, position, force, direction, quality)\n'
    assert text.count(signature) == 1
    text = text.replace(signature, signature + '    if storage.ei.build_dispatch_fail_turbine then return nil end\n')
    turbine.write_text(text, encoding='utf-8')
    for filename, signature, flag in (
        ('crystal-accumulator', '    local new_entity = surface.create_entity{', 'crystal'),
        ('steam-train', '\t\tlocal locomotive = surface.create_entity({', 'steam'),
        ('teslas-legacy', '    local replacement = surface.create_entity({', 'tesla'),
    ):
        path = target / f'scripts/control/{filename}.lua'
        text = path.read_text(encoding='utf-8')
        assert signature in text
        replacement = signature.replace('= surface.create_entity', f'= not storage.ei.build_dispatch_fail_{flag} and surface.create_entity')
        text = text.replace(signature, replacement, 1)
        path.write_text(text, encoding='utf-8')
    bridge = Path(__file__).with_name('suite.lua').read_text(encoding='utf-8')
    control = target / 'control.lua'
    with control.open('a', encoding='utf-8') as stream:
        stream.write('\n-- Private build-dispatch acceptance.\ndo\nlocal qc_phase = ' + json.dumps(args.phase) + '\n' + bridge + '\nend\n')
    metadata = {'phase': args.phase, 'source': str(source), 'source_sha256': hashes,
                'staged_sha256': {f: hashlib.sha256((target / f).read_bytes()).hexdigest() for f in files},
                'injection': 'Explicit turbine/crystal/steam/Tesla constructor failure flags in private code; appended dispatch probes.'}
    Path(record['evidence'], f'{args.phase}-inputs.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
