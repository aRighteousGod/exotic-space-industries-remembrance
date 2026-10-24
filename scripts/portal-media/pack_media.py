"""Make current-source media archives to avoid Factorio's Windows loose-file path limit."""
import hashlib
import json
from pathlib import Path
import zipfile


def stage(repo: Path, destination: Path):
    cache = repo / "output/portal-media/media-cache"
    cache.mkdir(parents=True, exist_ok=True)
    receipts = []
    for source in sorted(repo.glob("exotic-space-industries-remembrance-graphics-*")):
        files = sorted(p for p in source.rglob("*") if p.is_file())
        identity = hashlib.sha256("\n".join(
            f"{p.relative_to(source)}:{p.stat().st_size}:{p.stat().st_mtime_ns}" for p in files
        ).encode()).hexdigest()
        info = json.loads((source / "info.json").read_text(encoding="utf-8-sig"))
        basename = f"{info['name']}_{info['version']}"
        archive = cache / f"{identity}.zip"
        if not archive.exists():
            temporary = archive.with_suffix(".partial")
            with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED) as bundle:
                for path in files:
                    bundle.write(path, basename + "/" + path.relative_to(source).as_posix())
            temporary.replace(archive)
        target = destination / (basename + ".zip")
        target.hardlink_to(archive)
        receipts.append({"pack": basename, "source_identity": identity, "archive": str(archive), "bytes": archive.stat().st_size})
    (destination.parent / "media-sources.json").write_text(json.dumps(receipts, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    import sys
    stage(Path(__file__).resolve().parents[2], Path(sys.argv[1]))
