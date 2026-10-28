"""Explicit read-only Portal refresh for the exact proposed release identities."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sources = [p for p in Path('.').iterdir() if p.is_dir() and (p / 'info.json').is_file()
               and (p.name.startswith('exotic-space-industries-remembrance')
                    or p.name in ('doeworks-deer-continued', 'enhanced-walls-continued'))]
    sources.append(Path('../nonstandard-beacons-continued'))

    def inspect(source):
        info = json.loads((source / 'info.json').read_text(encoding='utf-8-sig'))
        url = 'https://mods.factorio.com/api/mods/' + info['name'] + '/full'
        row = dict(name=info['name'], candidate=info['version'], source=str(source), url=url)
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'ESIR-release-audit/1.0'})
            with urllib.request.urlopen(request, timeout=45) as response:
                portal = json.load(response)
            row['published'] = [dict(version=r['version'], factorio=r['info_json']['factorio_version'],
                                     released_at=r.get('released_at'), sha1=r.get('sha1')) for r in portal.get('releases', [])]
            row['owner'] = portal.get('owner')
            row['license'] = portal.get('license')
            row['candidate_newer'] = all(tuple(map(int, info['version'].split('.'))) >
                                         tuple(map(int, r['version'].split('.'))) for r in row['published'])
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            row.update(published=[],candidate_newer=True,portal_not_created=True)
        return row

    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(inspect, sources))
    result = dict(checked_utc=datetime.now(timezone.utc).isoformat(), entries=rows,
                  passed=all(r['candidate_newer'] for r in rows))
    args.output.parent.mkdir(exist_ok=True, parents=True)
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({r['name']: dict(candidate=r['candidate'], newer=r['candidate_newer'],
                                     latest=r['published'][-1]['version'] if r['published'] else None) for r in rows}))
    if not result['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
