"""Stage actual-owner probes only in the managed native fixture's private copy."""
from pathlib import Path

from adapters import append_main, read, replace, write


def expose(main, relative, body):
    path = main / relative
    text = read(path)
    owner = "steam_train" if relative == "scripts/control/steam-train.lua" else "model"
    marker = "return " + owner
    position = text.rfind(marker)
    if position < 0:
        raise ValueError("Missing module return: " + relative)
    write(path, text[:position] + body.replace("function model.", "function " + owner + ".") + "\n" + text[position:])


def stage(repo, main, helper, profile):
    source = repo / "scripts/qc/runtime-options"
    write(helper / "options-expected.lua", read(source / "expected.lua"))
    write(helper / "options-fluid.lua", read(source / "fluid.lua"))
    write(helper / "options-defaults.lua", read(source / "defaults.lua"))
    write(helper / "data.lua", read(source / "defaults-data.lua"))
    write(helper / "options-ecology.lua", read(repo / "scripts/qc/terrain-evolution/admin/ecology.lua"))
    if profile.get("legacy_inputs"):
        write(helper / "settings-final-fixes.lua", read(source / "settings-final-fixes.lua"))

    path = main / "scripts/control/runtime-options.lua"
    text = read(path)
    text = replace(text,
        "function model.configure(callback) reconcile=callback end",
        '''function model.configure(callback)
    reconcile=function(changes,tick)
        local probe=storage.esir_native_options_probe
        if probe and probe.observe then
            probe.reconciliations=probe.reconciliations+1
            probe.last_changes=table.deepcopy(changes);probe.last_tick=tick;probe.last_values={}
            for id in pairs(changes) do probe.last_values[id]=settings.global[id].value end
        end
        return callback(changes,tick)
    end
end''')
    text = replace(text,
        "local function write_setting(name,value)\n    settings.global[name]={value=value}\nend",
        '''local function write_setting(name,value)
    local probe=storage.esir_native_options_probe
    local inject=probe and probe.fail_after_write
    if inject then probe.write_attempts=(probe.write_attempts or 0)+1 end
    settings.global[name]={value=value}
    if inject and probe.write_attempts==inject then
        probe.fail_after_write=nil
        error("ESIR_NATIVE_OPTIONS_INJECTED_WRITE_FAILURE")
    end
end''')
    write(path, text)

    # These probes observe the real module-local caches, not a second resolver.
    for relative, body in (
        ("scripts/control/water-turret.lua", "function model.esir_native_option_cache() return nearest end"),
        ("scripts/control/gaian-saucer-wake.lua", "function model.esir_native_option_cache() return get_visual_config().visual_fidelity end"),
        ("scripts/control/emerald-apocalypse-hover-tank.lua", "function model.esir_native_option_cache() return get_hover_visual_config().visual_fidelity end"),
        ("scripts/control/teslas-legacy.lua", "function model.esir_native_option_cache() return table.deepcopy(tl_settings.text) end"),
        ("scripts/control/camp-fire.lua", "function model.esir_native_option_cache() return FIRE_UPDATE_TICK end"),
        ("scripts/control/steam-train.lua", "function model.esir_native_option_cache() return WHEEL_UPDATE_TICK end"),
        ("scripts/control/flamethrower-fuels.lua", "function model.esir_native_option_cache() return budget end"),
    ):
        expose(main, relative, body)
    path = main / "scripts/control/fluid-safety.lua"
    text = read(path)
    text = replace(text,
        "local function service_ignore_reconciliation(runtime,budget)\n",
        '''local function service_ignore_reconciliation(runtime,budget)
    local probe=storage.esir_native_options_fluid_probe
    if probe and probe.hold then return 0 end
''')
    text = replace(text,
        "function model.rebuild_fluid_runtime(reason)\n",
        '''function model.rebuild_fluid_runtime(reason)
    local probe=storage.esir_native_options_fluid_probe
    if probe then probe.rebuilds=probe.rebuilds+1 end
''')
    text = replace(text,
        "local x,y=chunk.x*32,chunk.y*32\n",
        '''local x,y=chunk.x*32,chunk.y*32
                    if probe then probe.queries=probe.queries+1 end
''')
    write(path, text)
    append_main(main, read(source / "bridge.lua"))
    return {
        "requires_checkpoint": True,
        "evidence": "Native settings and GUI; controlled legacy marker and second-write failure; real cache observers",
        "legacy_inputs": bool(profile.get("legacy_inputs")),
        "not_claimed": ["historical-old-source-save", "rendered", "two-client-multiplayer", "performance"],
    }
