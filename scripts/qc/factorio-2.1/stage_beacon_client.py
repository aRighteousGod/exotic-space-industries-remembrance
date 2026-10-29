"""Stage the existing NSBC native-player suite against the complete current ESIR.

Retains native blueprint transforms, player placement, permission/reach/controller
guards and information-panel tests. Only prototype names and unavailable source
families are adapted. Private hooks are appended to a physical NSBC test copy.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
NSBC = REPO.parent / "nonstandard-beacons-continued"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    root.mkdir(parents=True, exist_ok=True)
    assert not (root / "mods").exists(), "Use a new fixture stage"
    fixture = root / "fixture"
    fixture.mkdir()
    (fixture / "info.json").write_text(json.dumps({"name": "esir-qc-beacon-client", "version": "1.0.0",
        "title": "ESIR native beacon player acceptance", "author": "ESIR QC", "factorio_version": "2.1",
        "dependencies": ["exotic-space-industries-remembrance >= 1.4.0"]}), encoding="utf-8")
    original = NSBC / "tests/player-control.lua"
    text = original.read_text(encoding="utf-8")
    # ESIR's generated terrain differs from the small standalone fixture. Cover
    # the player replacement/reach/GUI lanes as well as the blueprint grid.
    text = text.replace('for y = -125, 125 do', 'for y = -140, 200 do')
    text = text.replace('{{-250, -125}, {250, 125}}', '{{-250, -140}, {250, 200}}')
    for old, new in (("nsbc-copper", "ei-copper-beacon"), ("nsbc-iron", "ei-iron-beacon"),
                     ("nsbc-nitrogen", "ei-liquid-nitrogen"), ("nsbc-burner", "ei-alien-beacon")):
        assert old in text
        text = text.replace(old, new)
    old = 'phase >= 6 and phase <= 9'
    assert old in text
    text = text.replace(old, 'phase == 6')
    old = 'local names = {[6] = "ei-alien-beacon", [7] = "nsbc-heat", [8] = "nsbc-electric", [9] = "nsbc-fluid-process"}'
    assert old in text
    text = text.replace(old, 'local names = {[6] = "ei-alien-beacon"}')
    # ESIR burner beacons use the authored bio-matter fuel category.
    text = text.replace('name = "coal", quality = "rare"', 'name = "ei-bio-matter", quality = "rare"')
    # Keep the accepted save ticking so a second native load can validate custody.
    text = text.replace('game.tick_paused = true', 'storage.native_accepted = true')
    (fixture / "player-control.lua").write_text(text, encoding="utf-8")
    shutil.copy2(HERE / "beacons/player-matrix.lua", fixture / "player-matrix.lua")
    (fixture / "control.lua").write_text((HERE / "beacons/client-control.lua").read_text(encoding="utf-8"), encoding="utf-8")
    ownership = (HERE / "beacon-ownership.lua").read_text(encoding="utf-8")
    ownership = ownership.replace('if complete then return end', 'if complete or not storage.native_accepted then return end')
    with (fixture / "control.lua").open("a", encoding="utf-8") as stream:
        stream.write("\n" + ownership)
    subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", str(HERE / "invoke-core.ps1"),
        "-Task", "stage", "-RunRoot", str(root), "-FixtureRoot", str(fixture),
        "-DependencyRoot", str(REPO / ".factorio-qc/dependency-seeds/2.1-core")], check=True)
    target = root / "mods/zzz-nonstandard-beacons-continued"
    # Remove only the checked junction object; no recursive source traversal.
    assert target.is_junction() and target.resolve() == NSBC.resolve()
    os.rmdir(target)
    shutil.copytree(NSBC, target, ignore=shutil.ignore_patterns(".git", ".qc", "dist", "tests", "__pycache__"))
    hooks = '''
-- Private native-player fixture adapters; never part of a release package.
remote.add_interface("nsbc-qc", {
  rotate = function(player_index, reverse, in_gui)
    orientation.rotate({player_index=player_index, tick=game.tick, in_gui=in_gui or false}, reverse)
  end,
  capture = function(stack, mapping)
    orientation.setup_blueprint{stack=stack, mapping={get=function() return mapping end}}
  end,
  custody = function()
    local rows={}
    for unit, record in pairs(storage.beacons) do
      assert(record.beacon.valid and record.source.valid and record.manager.valid, "invalid live beacon helper")
      rows[#rows+1]={unit=unit, source=record.source.unit_number, manager=record.manager.unit_number,
        phase=record.phase, direction=record.source.direction, mirrored=record.source.mirroring}
    end
    table.sort(rows,function(a,b) return a.unit<b.unit end)
    return rows
  end
})
'''
    with (target / "control.lua").open("a", encoding="utf-8") as stream:
        stream.write(hooks)
    hashes = {str(p.relative_to(NSBC)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in NSBC.rglob("*.lua") if not any(x in p.parts for x in (".git", ".qc", "dist", "tests"))}
    receipt = {"source_test": str(original), "source_test_sha256": hashlib.sha256(original.read_bytes()).hexdigest(),
        "staged_test_sha256": hashlib.sha256((fixture / "player-control.lua").read_bytes()).hexdigest(),
        "nsbc_sources": hashes, "private_hooks": ["rotate", "capture", "custody"],
        "scope": "Full current ESIR, native client; 128 blueprint transforms, player replacement, rotation and source panels"}
    (root / "stage.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"run": str(root), "nsbc_source_files": len(hashes)}))


if __name__ == "__main__":
    main()
