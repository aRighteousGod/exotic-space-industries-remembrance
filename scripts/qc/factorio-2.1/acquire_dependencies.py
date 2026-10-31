"""Acquire the approved core 2.1 packages without exposing download credentials.

The output contains a dependency lock only. Verified archives live in the shared
QC store; temporary downloads are consumed after verification.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from esir_qc_storage import dispatch

REPO = Path(__file__).resolve().parents[3]

PINS = {
    "Accumulator-V2": "1.0.8", "air-scrubber": "0.2.9",
    "Arachnids_enemy": "1.2.1", "ArmouredBiters": "2.1.0",
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


def file_digest(path, algorithm):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def acquire(name, version, output, metadata=None):
    try:
        if metadata is None:
            url = "https://mods.factorio.com/api/mods/" + urllib.parse.quote(name) + "/full"
            with urllib.request.urlopen(url, timeout=60) as response:
                metadata = json.load(response)
        release = next(r for r in metadata["releases"] if r["version"] == version)
        assert release["info_json"]["factorio_version"] == "2.1"
        stored = dispatch(REPO, "status", {})["artifacts"]
        candidates = [r for r in stored if r["name"] == name and r["version"] == version]
        target = output / release["file_name"]
        downloaded = False
        for candidate in candidates:
            with Path(candidate["path"]).open("rb") as stream:
                if hashlib.file_digest(stream, "sha1").hexdigest() == release["sha1"]:
                    target = Path(candidate["path"])
                    break
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
            actual = file_digest(partial, "sha1")
            assert actual == release["sha1"], "SHA-1 mismatch"
            partial.replace(target)
            downloaded = True
        assert file_digest(target, "sha1") == release["sha1"]
        with zipfile.ZipFile(target) as archive:
            candidates = [p for p in archive.namelist() if p.count("/") == 1 and p.endswith("/info.json")]
            assert len(candidates) == 1
            info = json.loads(archive.read(candidates[0]))
            assert (info["name"], info["version"], info["factorio_version"]) == (name, version, "2.1")
            assert archive.testzip() is None
        result = {"name": name, "version": version, "status": "verified-package",
                  "file": release["file_name"], "bytes": target.stat().st_size,
                  "sha1": release["sha1"],
                  "sha256": file_digest(target, "sha256"),
                  "info": info, "portal_license": metadata.get("license"),
                  "owner": metadata.get("owner"), "source_url": metadata.get("source_url"),
                  "portal_url": "https://mods.factorio.com/mod/" + urllib.parse.quote(name),
                  "released_at": release.get("released_at"), "migration": "not-tested"}
        dispatch(REPO, "import", {"path": str(target), "sha256": result["sha256"],
                                  "profile": "acquired-core-2.1", "consume": downloaded,
                                  "temporary_root": str(output.resolve())})
        print(name, version, "verified", result["bytes"], flush=True)
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
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda pair: acquire(*pair, args.output), PINS.items()))
    (args.output / "dependency-lock-2.1.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    if not any(r["status"] == "failed" for r in results):
        dispatch(REPO, "profile", {"name": "acquired-core-2.1", "packages": [r["sha256"] for r in results]})
    return int(any(r["status"] == "failed" for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
