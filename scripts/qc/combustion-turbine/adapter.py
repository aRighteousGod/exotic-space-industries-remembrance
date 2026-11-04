"""Stage turbine fixtures only in the managed helper/private gameplay copy."""
from adapters import append_main, read, replace, write


def stage(repo, main, helper, profile):
    source = repo / 'scripts/qc/combustion-turbine'
    if profile.get('integration'):
        write(helper / 'data-final-fixes.lua', read(source / 'integration-data.lua'))
        write(helper / 'integration.lua', read(source / 'integration.lua'))
        write(helper / 'expansion.lua', read(source / 'expansion.lua'))
        write(helper / 'native-suite.lua', 'return {}\n')
        path = main / 'scripts/control/combustion-turbine.lua'
        signature = 'local function create_turbine_shell(surface, name, position, force, direction, quality)\n'
        write(path, replace(read(path), signature, signature+'    if storage.ei.turbine_qc_fail then return nil end\n'))
        signature = 'local function read_generation(record)\n'
        write(path, replace(read(path), signature, signature+'    storage.ei.turbine_qc_reads=(storage.ei.turbine_qc_reads or 0)+1\n'))
        # Exercise two viewer-map entries against a real GUI without claiming
        # networked multiplayer. Factorio cannot create a second LuaPlayer.
        write(path, replace(read(path), 'local player=game.get_player(player_index)\n        if player',
            'local player=game.get_player(player_index==1000000 and storage.ei.turbine_qc_player_alias or player_index)\n        if player'))
        append_main(main, '''
local fixture=require("__esir-qc-native-tests__.integration")
remote.add_interface("esir-native-tests",{step=function(tick)
    return fixture.step(ei_combustion_turbine,tick)
end})
''')
        return {'requires_checkpoint': True, 'rendered_output': 'turbine-native',
                'evidence': 'Actual turbine production, pressure, settings and process custody'}
    write(helper / 'data-final-fixes.lua', read(source / 'proof-data.lua'))
    write(helper / 'native-suite.lua', read(source / 'proof.lua'))
    return {'evidence': 'Native fuel/oxygen conversion, linked fluid flow and blocked exhaust'}
