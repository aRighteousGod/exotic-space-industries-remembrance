"""Adapt established robot/platform and six ruined-beacon cases to full ESIR 2.1.

Uses a saved native player from the accepted graphical fixture. The repair
selection callback is reached through a private staged-main adapter, never shipped.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",required=True)
    args=parser.parse_args()
    root=Path(os.path.abspath(args.run))
    root.mkdir(parents=True,exist_ok=True)
    assert not (root / "mods").exists(),"Use a new actor fixture stage"
    fixture=root / "fixture"
    fixture.mkdir()
    (fixture / "info.json").write_text(json.dumps({"name":"esir-qc-beacon-actors","version":"1.0.0","factorio_version":"2.1",
        "title":"ESIR native beacon actor and ruin acceptance","author":"ESIR QC","dependencies":["exotic-space-industries-remembrance >= 1.4.0"]}),encoding="utf-8")
    actor_source=REPO.parent / "nonstandard-beacons-continued/tests/actor-control.lua"
    actor=actor_source.read_text(encoding="utf-8")
    for old,new in (("nsbc-copper","ei-copper-beacon"),("nsbc-iron","ei-iron-beacon"),("nsbc-nitrogen","ei-liquid-nitrogen")):
        actor=actor.replace(old,new)
    (fixture / "actor-control.lua").write_text(actor,encoding="utf-8")
    shutil.copy2(HERE / "beacons/actor-matrix.lua", fixture / "actor-matrix.lua")
    repair_source=HERE.parent / "alien-beacon-repair/control.lua"
    repair=repair_source.read_text(encoding="utf-8")
    assert repair.count("end)")==2
    repair=repair.replace('local test = require("test-config")','local M = {}\nlocal test = {baseline=false}')
    repair=repair.replace('script.on_event(defines.events.script_raised_built, function(event)','function M.built(event)')
    repair=repair.replace('script.on_event(defines.events.on_tick, function(event)','function M.tick(event)')
    repair=repair.replace("end)","end")
    repair=repair.replace('beacon.custom_status ~= nil',' #beacon.get_tooltip_fields() > 0')
    repair=repair.replace('script.active_mods["zzz-nonstandard-beacons"]','script.active_mods["zzz-nonstandard-beacons-continued"]')
    repair=repair.replace('all_pass = true','passed = true')
    repair=repair.replace('local unit = beacon.unit_number', '''-- The real repair path must immediately support a native tier upgrade.
        metadata.source.disabled_by_script = true
        local remaining = metadata.source.burner.remaining_burning_fuel
        check(beacon.order_upgrade{target={name="ei-warp-beacon",quality=beacon.quality},force=beacon.force}, "repaired Alien upgrade order")
        beacon = assert(beacon.apply_upgrade())
        metadata = remote.call("nonstandard-beacons", "get-beacon-data", beacon.unit_number)
        check(metadata.phase == "attached" and metadata.source.disabled_by_script, "repaired Alien to Warp attachment")
        check(metadata.source.burner.remaining_burning_fuel == remaining, "repair upgrade burning remainder")
        local unit = beacon.unit_number''')
    (fixture / "repair-control.lua").write_text(repair+"\nreturn M\n",encoding="utf-8")
    (fixture / "control.lua").write_text('''local actors=require("actor-control")
local repair=require("repair-control")
local matrix=require("actor-matrix")
script.on_event({defines.events.script_raised_built,defines.events.on_robot_built_entity,defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_built_entity,defines.events.on_space_platform_mined_entity},function(event)
    actors.event(event)
    matrix.event(event)
    if event.name==defines.events.script_raised_built then repair.built(event) end
end)
script.on_event(defines.events.on_tick,function(event)
    storage.start_tick=storage.start_tick or event.tick
    actors.tick(event.tick-storage.start_tick+1)
    matrix.tick(event.tick-storage.start_tick+1)
    repair.tick(event)
    if storage.actors_complete and storage.done and storage.actor_matrix and storage.actor_matrix.done and not storage.accepted then
        storage.accepted=true
        helpers.write_file("beacon-actors-complete.json",helpers.table_to_json{passed=true,actors=26,ruin_cases=6,repair_upgrades=6,
            engine=script.active_mods.base,tick=event.tick},false)
        if game.is_multiplayer() then game.server_save("beacon-actors-accepted") end
    end
end)
''',encoding="utf-8")
    subprocess.run(["powershell","-ExecutionPolicy","Bypass","-File",str(HERE / "invoke-core.ps1"),
        "-Task","stage","-RunRoot",str(root),"-FixtureRoot",str(fixture),
        "-DependencyRoot",str(REPO / ".factorio-qc/dependency-seeds/2.1-core")],check=True)
    target=root / "mods/exotic-space-industries-remembrance"
    source=REPO / "exotic-space-industries-remembrance"
    assert target.is_junction() and target.resolve()==source.resolve()
    os.rmdir(target)
    shutil.copytree(source,target)
    with (target / "control.lua").open("a",encoding="utf-8") as stream:
        stream.write("\n-- Private repair callback adapter; never packaged.\n")
        stream.write((HERE.parent / "alien-beacon-repair/bridge.lua").read_text(encoding="utf-8"))
    hashes={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob("*.lua")}
    (root / "stage.json").write_text(json.dumps({"main_sources":hashes,"private_repair_adapter":True,
        "original_test_sha256":{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (actor_source,repair_source)}},indent=2),encoding="utf-8")


if __name__=="__main__": main()
