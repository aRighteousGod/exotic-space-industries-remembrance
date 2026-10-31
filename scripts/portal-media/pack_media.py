"""Lease canonical current-source media ZIPs for the managed portal capture.

Archives avoid Factorio's loose-file path limit. There is no portal-specific
persistent cache or copied ZIP set: the common store owns every package.
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from esir_qc_package import package


def stage(repo: Path, run_id: str):
    profile = json.loads((repo / '.codex/esir/factorio-development.json').read_text(encoding='utf-8-sig'))
    family = '.'.join(profile['engine_version'].split('.')[:2])
    return [package(repo, run_id, source, {".idea", ".git", ".vscode", ".gitignore"})
            for source in sorted(repo.glob("exotic-space-industries-remembrance-graphics-*"))
            if (source / "info.json").is_file() and
            json.loads((source / 'info.json').read_text(encoding='utf-8-sig')).get('factorio_version') == family]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    print(json.dumps(stage(Path(__file__).resolve().parents[2], args.run_id)))
