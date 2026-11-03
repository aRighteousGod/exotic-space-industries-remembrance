"""Exact-engine orbital fixture, staged only into managed private copies."""
from adapters import append_main, read, write


def stage(repo, main, helper, profile):
    source = repo / "scripts/qc/orbital-logistics"
    write(helper / "orbital-suite.lua", read(source / "suite.lua"))
    write(helper / "orbital-radar.lua", read(source / "radar.lua"))
    write(helper / "orbital-cargo.lua", read(source / "cargo.lua"))
    write(helper / "orbital-lifecycle.lua", read(source / "lifecycle.lua"))
    write(helper / "data.lua", read(repo / ".codex/skills/esir-dev/assets/zzz-orbital-logistics-qc_0.0.1/data.lua"))
    append_main(main, '''
local fixture = require("__esir-qc-native-tests__.orbital-suite")(orbital_logistics, orbital_combinator)
remote.add_interface("esir-native-tests", {step=fixture.step})
''')
    return {"requires_checkpoint": True,
            "rendered_output": "orbital-native",
            "evidence": "Real native hubs, requests, inventories, dispatch ownership and persistence; programmatic GUI callbacks",
            "not_claimed": ["physical-input", "two-client-multiplayer", "performance"]}
