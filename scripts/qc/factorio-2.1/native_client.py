"""Run an isolated hidden graphical client until a fresh fixture marker is written.

Never reads installed account profiles. Retains logs, screenshots and autosaves.
Only terminates the child launched by this invocation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import zipfile


def native_window_geometry(pid):
    """Read only this child window's physical client bounds, independently of Lua."""
    if os.name != "nt":
        return []
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.SetThreadDpiAwarenessContext.argtypes = [ctypes.c_void_p]
    user32.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
    user32.GetDpiForWindow.argtypes = [wintypes.HWND]
    rows = []
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def inspect(window, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(window, ctypes.byref(owner))
        if owner.value == pid:
            rectangle = wintypes.RECT()
            user32.GetClientRect(window, ctypes.byref(rectangle))
            rows.append(dict(width=rectangle.right-rectangle.left, height=rectangle.bottom-rectangle.top,
                             dpi=user32.GetDpiForWindow(window)))
        return True

    user32.EnumWindows(callback_type(inspect), 0)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--engine", default=".factorio-qc/f21/bin/x64/factorio.exe")
    parser.add_argument("--locale", default="en")
    parser.add_argument("--save", required=True)
    parser.add_argument("--marker", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--checkpoint")
    parser.add_argument("--pass-key", default="passed", choices=("passed", "all_pass"))
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=1000)
    parser.add_argument("--ui-scale", type=float, default=1)
    parser.add_argument("--graphics-quality", choices=("high", "medium"), default="high")
    args = parser.parse_args()
    assert args.width >= 800 and args.height >= 600 and 0.5 <= args.ui_scale <= 2
    window_size = str(args.width) + "x" + str(args.height)
    root = Path(os.path.abspath(args.run))
    engine = Path(os.path.abspath(args.engine))
    assert "Version: 2.1.23 " in subprocess.check_output([str(engine), "--version"], text=True)
    assert json.loads((engine.parents[2] / "data/base/info.json").read_text())["version"] == "2.1.23"
    user = root / "client"
    user.mkdir(exist_ok=True)
    config = root / "client.ini"
    config.write_text(f"[path]\nread-data={(engine.parents[2] / 'data').as_posix()}\nwrite-data={user.as_posix()}\n"
        "[general]\ncheck-updates=false\nlocale=" + args.locale + "\n[graphics]\nfull-screen=false\nwindow-size=" + window_size + "\n"
        "halt-rendering-when-minimized=false\nmax-sprite-loading-threads=2\nvideo-memory-usage=low\ncache-sprite-atlas=false\n"
        "[interface]\nui-scale-mode=manual-pixels\ncustom-ui-scale=" + str(args.ui_scale) + "\n", encoding="utf-8")
    output = root / (args.phase + ".client.log")
    marker = user / "script-output" / args.marker
    checkpoint = user / "saves" / args.checkpoint if args.checkpoint else None
    started = time.time()
    source_hashes = {}
    for directory in (root / "mods").iterdir():
        if directory.is_dir() and (directory / "info.json").is_file():
            for path in [directory / "info.json", *directory.rglob("*.lua")]:
                source_hashes[str(path.relative_to(root / "mods"))] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = root / (args.phase + ".source-manifest.json")
    manifest.write_text(json.dumps(source_hashes, indent=2), encoding="utf-8")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    with output.open("w", encoding="utf-8") as log:
        process = subprocess.Popen([str(engine), "--config", str(config), "--mod-directory", str(root / "mods"),
            "--disable-audio", "--disable-migration-window", "--graphics-quality", args.graphics_quality, "--window-size", window_size,
            "--load-game", os.path.abspath(args.save)], stdout=log, stderr=subprocess.STDOUT,
            startupinfo=startup)
        try:
            while time.time() - started < args.timeout:
                current = output.read_text(encoding="utf-8", errors="replace")
                # Missing media opens a native error dialog before map loading; a hidden
                # client cannot dismiss it and must fail without accepting stale markers.
                if (process.poll() is not None or "non-recoverable error" in current
                        or "Error AtlasBuilder.cpp:" in current):
                    raise RuntimeError(current[-6000:])
                if marker.exists() and marker.stat().st_mtime >= started:
                    result = json.loads(marker.read_text(encoding="utf-8"))
                    assert result.get(args.pass_key), result
                    if checkpoint:
                        if not checkpoint.exists() or checkpoint.stat().st_mtime < started or "Saving finished" not in current:
                            time.sleep(.25)
                            continue
                        try:
                            with zipfile.ZipFile(checkpoint) as saved:
                                assert saved.testzip() is None
                        except (OSError, zipfile.BadZipFile):
                            time.sleep(.25)
                            continue
                        result["checkpoint_sha256"] = hashlib.file_digest(checkpoint.open("rb"), "sha256").hexdigest()
                    time.sleep(2)  # Allow queued native screenshots to finish writing.
                    result.update(elapsed_seconds=round(time.time()-started,3), marker=str(marker), log=str(output),
                        engine=str(engine), engine_version="2.1.23", locale=args.locale, ui_scale=args.ui_scale,
                        audio=False, manual_input=False, rendered_client=True, graphics_quality=args.graphics_quality, source_manifest=str(manifest),
                        source_manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest())
                    result["native_window_geometry"] = native_window_geometry(process.pid)
                    images = []
                    for capture in (user / "script-output").rglob("*.png"):
                        if capture.stat().st_mtime < started:
                            continue
                        target = root / (args.phase + ".images") / capture.relative_to(user / "script-output")
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(capture, target)
                        images.append(dict(path=str(target), sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
                    result["images"] = images
                    (root / (args.phase + ".receipt.json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
                    print(json.dumps(result))
                    return
                time.sleep(.25)
            raise TimeoutError("Native client fixture timed out: " + str(output))
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=15)


if __name__ == "__main__":
    main()
