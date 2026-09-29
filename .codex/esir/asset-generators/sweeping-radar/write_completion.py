"""Assemble current model-review evidence without changing production art."""
from datetime import datetime
import json
from pathlib import Path

root = Path.cwd() / 'output/meshy'
assets = []
for name in ('sweeping-radar', 'phased-array-radar'):
    prepared = root / name / 'prepared'
    assets.append(dict(asset=name,
        mechanical_split=json.loads((prepared / 'mechanical-split.json').read_text()),
        rig_checks=json.loads((prepared / 'rig-checks.json').read_text()),
        render_manifest=str(Path('output/meshy') / name / 'review/Render/factorio-preset-render-manifest.json')))
result = dict(completed_at=datetime.now().astimezone().isoformat(),
    scope='Maximum-detail source downloads, mechanical rigs and eight-angle model review; no production art integration',
    selection=[1, 8], assets=assets,
    mesh_generation=dict(credits=120, selected_asset_credits=80, superseded_asset_credits=40,
                         balance_after=1260, model='meshy-7.1', geometry_resolution='4k', texture_resolution='8k'),
    visual_review=dict(sweeping_radar='Eight headings reviewed; fixed base and attached rotating trough',
        phased_array_radar='Eight body/glow headings reviewed independently; fixed base, attached four-panel rotor, grid-preserving white emission, surface-attached angle-dependent red indicator'),
    artifact_checks=json.loads((root / 'radar-production/review-checks.json').read_text()),
    feasibility='Disabled native radar ignores orientation writes; selected frozen LuaRendering animation offsets work in Factorio 2.0.77',
    shipping_graphics_changed=False, production_runtime_changed=False,
    limitations=['Eight-angle low-sample review, not final 64-direction sprites',
        'No exact triangle intersection test across intermediate headings',
        'No in-game custom-art lifecycle, glow power-state or fleet-overhead validation',
        'Interactive gallery controls untested because CUA reported no available browser'])
(root / 'radar-production/completion.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print('Saved radar model completion evidence')
