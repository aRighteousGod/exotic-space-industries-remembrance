"""Current-profile path resolution shared by legacy checkpoint adapters."""
import json
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[3]


def context(root):
    record = json.loads((Path(root) / 'context.json').read_text(encoding='utf-8-sig'))
    for key in ('run_id', 'config', 'mod_view_root', 'write_data_root', 'scratch_root'):
        if not record.get(key): raise ValueError('Missing managed context field: ' + key)
    return record


def engine_path(override=None):
    profile = json.loads((REPO / '.codex/esir/factorio-development.json').read_text(encoding='utf-8-sig'))
    engine = Path(override).absolute() if override else REPO / profile['engine_path']
    version = profile['engine_version']
    base = json.loads((engine.parents[2] / 'data/base/info.json').read_text(encoding='utf-8-sig'))
    output = subprocess.check_output([str(engine), '--version'], text=True)
    if base['version'] != version or 'Version: ' + version + ' ' not in output:
        raise ValueError('Executable/base do not match the exact development profile')
    return engine, version
