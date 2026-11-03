"""Current runtime Gaia resource assertions using the shared native runner."""
import json
from adapters import append_main, read


def stage(repo, main, helper, profile):
    policy = json.loads(read(repo / '.codex/skills/esir-dev/assets/gaia-resource-qc.json'))
    assert profile['id'] == 'default' and profile['seed'] == 1000
    append_main(main, read(repo / 'scripts/qc/gaia-resources/runtime.lua'))
    return {
        'postcheck': 'gaia-resources',
        'parameters': {'seed': profile['seed'], 'area_size': policy['preview_size'],
                       'resources': policy['resources']},
        'evidence': 'Fresh runtime map-generation resource presence within fixed bounds',
    }


def postcheck(output, metadata, phase):
    report = json.loads(read(output / f'native-test-{phase}.json'))
    metrics = report['metrics']
    parameters = metadata['parameters']
    expected = set(parameters['resources'])
    counts = metrics['resource_counts']
    expressions = metrics['settings'].get('property_expression_names', {})
    tile_count = metrics.get('gaia_tile_count')
    checks = {
        'runtime-surface': metrics.get('surface_name') == 'esir-qc-gaia-runtime',
        'current-generation-revision': expressions.get('ei-enemy-generation-revision') == 'ei-enemy-generation-native21',
        'gaia-terrain-expressions': all(expressions.get(name) == 'gaia_' + name for name in ('elevation', 'moisture', 'temperature')),
        'gaia-tiles-present': type(tile_count) is int and 0 < tile_count <= 4096 * 4096,
        'runtime-seed': metrics['seed'] == parameters['seed'] == metrics['settings']['seed'],
        'runtime-bounds': metrics['area_size'] == 4096 and metrics['bounds'] == [[-2048, -2048], [2048, 2048]],
        'runtime-chunks': metrics['generated_chunks'] == 16384,
        'complete-resource-inventory': set(counts) == expected and len(expected) == 6,
        'all-resources-present': all(type(counts.get(name)) is int and counts[name] >= 1 for name in expected),
    }
    return [{'name': name, 'passed': passed} for name, passed in checks.items()]
