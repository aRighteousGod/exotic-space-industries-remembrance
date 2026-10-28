"""Acquire the approved core 2.1 packages without exposing download credentials.

Writes only to an explicitly supplied task-owned output directory. Existing files
are accepted only after their public Portal SHA-1 and ZIP metadata match.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request
import zipfile

PINS = {
    "Accumulator-V2": "1.0.8", "air-scrubber": "0.2.9",
    "Arachnids_enemy": "1.2.1", "ArmouredBiters21Compat": "2.0.7",
    "assault_spidertron_V2": "2.3.12", "Assembler-Reskin": "1.0.4",
    "atan-ash-fork": "1.0.1", "ch-concentrated-solar": "0.6.0",
    "Cold_biters": "2.3.0", "Electric_flying_enemies": "0.2.1",
    "elevated-pipes": "1.5.0", "Explosive_biters": "2.4.0",
    "informatron": "0.5.0", "PollutionCombinator-JamieFork": "1.2.0",
    "rp_steam_roboports": "2.1.0", "SolarMatrix": "1.0.9",
    "SteampunkLamp": "1.0.4", "Toxic_biters": "2.1.0",
    "zeus-wrath": "1.0.6", "mferrari_graphics_pack_1": "0.0.5",
    "perel": "1.2.2", "rp_art_util": "3.0.0",
    "rp_steam_intermediates": "1.0.0",
}


def acquire(name, version, output, metadata=None):
    try:
        if metadata is None:
            url = "https://mods.factorio.com/api/mods/" + urllib.parse.quote(name) + "/full"
            with urllib.request.urlopen(url, timeout=60) as response:
                metadata = json.load(response)
        release = next(r for r in metadata["releases"] if r["version"] == version)
        assert release["info_json"]["factorio_version"] == "2.1"
        target = output / release["file_name"]
        if not target.exists():
            auth = urllib.parse.urlencode({
                "username": os.environ["FACTORIO_USERNAME"],
                "token": os.environ["FACTORIO_TOKEN"],
            })
            partial = target.with_suffix(".partial")
            request = urllib.request.Request("https://mods.factorio.com" + release["download_url"] + "?" + auth,
                                             headers={"User-Agent": "Mozilla/5.0", "Accept": "application/octet-stream"})
            with urllib.request.urlopen(request, timeout=180) as response, partial.open("wb") as stream:
                while block := response.read(1024 * 1024):
                    stream.write(block)
            actual = hashlib.file_digest(partial.open("rb"), "sha1").hexdigest()
            assert actual == release["sha1"], "SHA-1 mismatch"
            partial.replace(target)
        assert hashlib.file_digest(target.open("rb"), "sha1").hexdigest() == release["sha1"]
        with zipfile.ZipFile(target) as archive:
            candidates = [p for p in archive.namelist() if p.count("/") == 1 and p.endswith("/info.json")]
            assert len(candidates) == 1
            info = json.loads(archive.read(candidates[0]))
            assert (info["name"], info["version"], info["factorio_version"]) == (name, version, "2.1")
            assert archive.testzip() is None
        result = {"name": name, "version": version, "status": "verified-package",
                  "file": target.name, "bytes": target.stat().st_size,
                  "sha1": release["sha1"],
                  "sha256": hashlib.file_digest(target.open("rb"), "sha256").hexdigest(),
                  "info": info, "portal_license": metadata.get("license"),
                  "owner": metadata.get("owner"), "source_url": metadata.get("source_url"),
                  "portal_url": "https://mods.factorio.com/mod/" + urllib.parse.quote(name),
                  "released_at": release.get("released_at"), "migration": "not-tested"}
        (output / (name + ".portal.json")).write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        print(name, version, "verified", target.stat().st_size, flush=True)
        return result
    except Exception as error:
        # URL-bearing exception strings and authentication details are never logged.
        result = {"name": name, "version": version, "status": "failed", "error": type(error).__name__}
        if isinstance(error, urllib.error.HTTPError):
            result["http_status"] = error.code
        print(json.dumps(result), flush=True)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda pair: acquire(*pair, args.output), PINS.items()))
    (args.output / "dependency-lock-2.1.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    return int(any(r["status"] == "failed" for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
