"""Pack original review pixels through ESIR's shared raw-frame exporter."""
import argparse
import importlib.util
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--asset', choices=['sweeping-radar', 'phased-array-radar'], required=True)
args = parser.parse_args()
path = Path.cwd() / '.codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py'
spec = importlib.util.spec_from_file_location('esir_asset_export', path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
root = Path.cwd() / 'output/meshy' / args.asset / 'review'
result = module.pack_raw_bundle_sheets(root / 'Render', root / 'raw-packed',
                                      grid=(4, 2), black_to_transparent='none')
print(args.asset + ': packed ' + str(len(result)) + ' sheets from original pixels')
