"""Build/reuse one deterministic package in the managed QC store, never deploy."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import uuid
import zipfile

from esir_qc_storage import dispatch, plain, tree_files, digest, StorageError

PACKAGING_VERSION = "esir-qc-zip-1"


def package(repo, run_id, source, excludes=()):
    source = plain(source)
    run = dispatch(repo, "status", {"run_id": run_id})
    if run["closed"]:
        raise StorageError("Package QC requires an open run")
    info = json.loads((source / "info.json").read_text(encoding="utf-8-sig"))
    files = [p for p in tree_files(source) if not set(p.relative_to(source).parts).intersection(excludes)]
    inputs = [(p.relative_to(source).as_posix(), digest(p)) for p in files]
    identity = hashlib.sha256(json.dumps([PACKAGING_VERSION, inputs], separators=(",", ":")).encode()).hexdigest()
    for artifact in dispatch(repo, "status", {})["artifacts"]:
        if artifact.get("source_fingerprint") == identity and artifact.get("packaging_version") == PACKAGING_VERSION:
            result = dispatch(repo, "import", {"path": artifact["path"], "sha256": artifact["sha256"], "run_id": run_id})
            if [(p.relative_to(source).as_posix(), digest(p)) for p in tree_files(source)
                    if not set(p.relative_to(source).parts).intersection(excludes)] != inputs:
                raise StorageError("Source inventory changed during package reuse")
            return {**result, "reused": True, "entry_count": len(files)}
    scratch = plain(run["scratch_root"])
    temporary = scratch / ("package-" + uuid.uuid4().hex + ".zip")
    prefix = f"{info['name']}_{info['version']}/"
    with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, (relative, expected) in zip(files, inputs):
            entry = zipfile.ZipInfo(prefix + relative, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            with path.open("rb") as origin, archive.open(entry, "w", force_zip64=True) as target:
                shutil.copyfileobj(origin, target, 1024 * 1024)
            if digest(path) != expected:
                raise StorageError("Source changed during packaging; temporary archive remains owned scratch")
    if [(p.relative_to(source).as_posix(), digest(p)) for p in tree_files(source)
            if not set(p.relative_to(source).parts).intersection(excludes)] != inputs:
        raise StorageError("Source inventory changed during packaging")
    result = dispatch(repo, "import", {"path": str(temporary), "consume": True,
                                      "temporary_root": str(scratch), "run_id": run_id,
                                      "source_fingerprint": identity, "packaging_version": PACKAGING_VERSION})
    return {**result, "reused": False, "entry_count": len(files)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args()
    print(json.dumps(package(args.repo, args.run_id, args.source, args.exclude)))


if __name__ == "__main__":
    main()
