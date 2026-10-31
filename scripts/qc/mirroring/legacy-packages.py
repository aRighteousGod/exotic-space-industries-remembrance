"""Resolve exact preserved package hashes, downloading only missing historical releases."""
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.parse
import urllib.request

record_path = Path(sys.argv[1])
record = json.loads(record_path.read_text(encoding="utf-8-sig"))
repo = Path(record["repo"])
selection = json.loads((repo / ".factorio-qc/managed/0422e48554e14570806ee8e7c009f9a8/migration-native-20/donor-stage.json").read_text())
downloads = Path(record["scratch"]) / "historical-downloads"
downloads.mkdir(exist_ok=True)
paths = {}
for row in selection["packages"]:
    name, version = row["name"], row["version"]
    filename = name + "_" + version + ".zip"
    candidates = [repo / row["archive"], Path(os.environ["APPDATA"]) / "Factorio/mods" / filename, downloads / filename]
    found = None
    for candidate in candidates:
        if candidate.is_file():
            with candidate.open("rb") as stream:
                if hashlib.file_digest(stream, "sha256").hexdigest() == row["sha256"]:
                    found = candidate
                    break
    if found is None:
        try:
            request = urllib.request.Request("https://mods.factorio.com/api/mods/" + urllib.parse.quote(name),
                headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=60) as response:
                metadata = json.load(response)
            release = next(r for r in metadata["releases"] if r["version"] == version)
            assert release["info_json"]["factorio_version"] == "2.0"
            auth = urllib.parse.urlencode({"username": os.environ["FACTORIO_USERNAME"], "token": os.environ["FACTORIO_TOKEN"]})
            request = urllib.request.Request("https://mods.factorio.com" + release["download_url"] + "?" + auth,
                headers={"User-Agent": "Mozilla/5.0", "Accept": "application/octet-stream"})
            temporary = downloads / (filename + ".partial")
            with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as output:
                while block := response.read(1024 * 1024):
                    output.write(block)
            with temporary.open("rb") as stream:
                assert hashlib.file_digest(stream, "sha256").hexdigest() == row["sha256"], "Historical hash mismatch"
            found = downloads / filename
            temporary.replace(found)
        except Exception as error:
            raise RuntimeError(f"{name} {version}: {type(error).__name__} {getattr(error, 'code', '')}") from None
    paths[name] = str(found)
    print(name, version, "verified", flush=True)
record["package_paths"] = paths
record_path.write_text(json.dumps(record, indent=2) + "\n")
