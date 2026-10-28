"""Build reproducible API changes and the original 50-entry optional inventory.

API inputs are exact local caches. Portal refresh is an explicit --portal action.
Output is evidence, not an assertion that a dependency or API change is accepted.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import re
import urllib.request
import zipfile

REPLACEMENTS = {
    "distant-misfires": ("distant-misfires-2_1-fork", "0.15.4"),
    "fire-lights": ("fire-lights-fork", "0.15.0"),
    "diurnal-dynamics": ("diurnal-dynamics-fork", "0.16.0"),
    "celestial-weather": ("celestial-weather-updated", "1.5.1"),
    "heat_glow": ("heat_glow-temp-21-patch", "2.0.6"),
    "Shield-FX": ("Shield-FX_fork", "2.0.1"),
    "gore": ("gore_fork", "2.0.6"),
    "castra": ("castra-prime", "0.9.4"),
    "terrapalus": ("terrapalus-updated", "0.5.0"),
    "dea-dia-system": ("dea-dia-system-beomyo", "0.37.0"),
}
BACKLOG = {"auto-barrel", "vehicle_physics", "janus", "fall-of-promethea", "metal-and-stars"}
BUILTINS = {"base", "space-age", "elevated-rails", "quality", "recycler"}


def parse_dependency(value):
    match = re.fullmatch(r"\s*(\(\?\)|[?!~+])?\s*([^<>=]+?)(?:\s*(>=|<=|=|>|<)\s*([\d.]+))?\s*", value)
    if not match:
        raise ValueError("Unrecognized dependency: " + value)
    return dict(zip(("prefix", "name", "operator", "version"), match.groups()))


def structural(value):
    if isinstance(value, dict):
        return {k: structural(v) for k, v in value.items() if k not in {"description", "order", "examples", "images"}}
    if isinstance(value, list):
        if value and all(isinstance(v, dict) and "name" in v for v in value):
            return {v["name"]: structural(v) for v in value}
        return [structural(v) for v in value]
    return value


def differences(old, new, path=""):
    if isinstance(old, dict) and isinstance(new, dict):
        for key in sorted(old.keys() | new.keys()):
            name = path + "." + key if path else key
            if key not in old:
                yield {"path": name, "change": "added", "after": new[key]}
            elif key not in new:
                yield {"path": name, "change": "removed", "before": old[key]}
            else:
                yield from differences(old[key], new[key], name)
    elif old != new:
        yield {"path": path, "change": "changed", "before": old, "after": new}


def api_ledger(output):
    result = {"from": "2.0.77", "to": "2.1.23", "sources": {}, "entries": []}
    for stage in ("runtime", "prototype"):
        documents = []
        for version in ("2.0.77", "2.1.23"):
            path = Path(".factorio-lua-docs-cache") / version / (stage + "-api.json")
            raw = path.read_bytes()
            document = json.loads(raw)
            assert document["application_version"] == version
            result["sources"][stage + "-" + version] = hashlib.sha256(raw).hexdigest()
            documents.append(document)
        for entry in differences(structural(documents[0]), structural(documents[1])):
            entry.update(stage=stage, disposition="pending-review", evidence=[])
            result["entries"].append(entry)
    (output / "api-differences.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("API structural changes:", len(result["entries"]), flush=True)


def portal(name):
    url = "https://mods.factorio.com/api/mods/" + urllib.parse.quote(name) + "/full"
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def optional_matrix(output, baseline):
    with zipfile.ZipFile(baseline) as archive:
        info = json.loads(archive.read(next(n for n in archive.namelist() if n.count("/") == 1 and n.endswith("/info.json"))))
    original = [parse_dependency(d) for d in info["dependencies"]]
    original = [d for d in original if d["prefix"] in ("?", "(?)") and d["name"] not in {"TerrainEvolution", "TerrainEvolution2"}]
    assert len(original) == 50
    metadata_cache = {}

    def inspect(dependency):
        name = dependency["name"]
        selected, pin = REPLACEMENTS.get(name, (name, None))
        metadata = portal(selected)
        metadata_cache[selected] = metadata
        releases = [r for r in metadata["releases"] if r["info_json"].get("factorio_version") == "2.1" and (pin is None or r["version"] == pin)]
        release = max(releases, key=lambda r: tuple(map(int, r["version"].split("."))), default=None)
        return {"original": name, "selected": selected, "original_prefix": dependency["prefix"],
                "status": "port-backlog" if name in BACKLOG else "provenance-pending" if name == "gore" else "package-and-integration-pending",
                "version": release["version"] if release else None,
                "release_id": release["download_url"].rsplit("/", 1)[-1] if release else None,
                "sha1": release["sha1"] if release else None, "sha256": None,
                "license": metadata.get("license"), "owner": metadata.get("owner"),
                "source_url": metadata.get("source_url"), "portal_url": "https://mods.factorio.com/mod/" + urllib.parse.quote(selected),
                "dependencies": release["info_json"].get("dependencies", []) if release else None,
                "tested_version": None, "migration": "not-accepted", "evidence": []}

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(inspect, original))
    result = {"refreshed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "original_count": 50, "excluded_conflicts": ["TerrainEvolution", "TerrainEvolution2"], "entries": rows}
    (output / "optional-dependencies.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    cache = output / "portal-metadata"
    cache.mkdir(exist_ok=True)
    for name, metadata in metadata_cache.items():
        (cache / (name + ".json")).write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print("Optional matrix:", len(rows), "entries;", sum(r["version"] is not None for r in rows), "selected 2.1 releases", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--portal", action="store_true")
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    api_ledger(args.output)
    if args.portal:
        optional_matrix(args.output, args.baseline)


if __name__ == "__main__":
    main()
