"""Focused host regressions for Gaia measured reports and production Lua helpers."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import gaia_resources

REPO = Path(__file__).resolve().parents[3]


class GaiaMeasurements(unittest.TestCase):
    def setUp(self):
        policy = json.loads((REPO / '.codex/skills/esir-dev/assets/gaia-resource-qc.json').read_text())
        self.metadata = {'parameters': {'seed': 1000, 'resources': policy['resources']}}
        self.report = {'metrics': {'seed': 1000, 'settings': {'seed': 1000}, 'area_size': 4096,
                                  'bounds': [[-2048, -2048], [2048, 2048]], 'generated_chunks': 16384,
                                  'surface_name': 'esir-qc-gaia-runtime', 'gaia_tile_count': 4096 * 4096,
                                  'resource_counts': {name: 1 for name in policy['resources']}}}
        self.report['metrics']['settings']['property_expression_names'] = {
            'ei-enemy-generation-revision': 'ei-enemy-generation-native21',
            'elevation': 'gaia_elevation', 'moisture': 'gaia_moisture', 'temperature': 'gaia_temperature',
        }

    def evaluate(self, report):
        with tempfile.TemporaryDirectory(dir=REPO / 'temp', prefix='gaia-report-') as directory:
            path = Path(directory)
            (path / 'native-test-candidate.json').write_text(json.dumps(report), encoding='utf-8')
            return gaia_resources.postcheck(path, self.metadata, 'candidate')

    def test_complete_measurements(self):
        self.assertTrue(all(row['passed'] for row in self.evaluate(self.report)))

    def test_incomplete_or_mismatched_measurements(self):
        defects = [
            ('seed', 42), ('settings', {'seed': 42}), ('area_size', 1024),
            ('bounds', [[0, 0], [4096, 4096]]), ('generated_chunks', 16383),
            ('resource_counts', {}),
            ('surface_name', 'nauvis'), ('gaia_tile_count', 0), ('gaia_tile_count', True),
        ]
        for field, value in defects:
            with self.subTest(field=field):
                report = copy.deepcopy(self.report)
                report['metrics'][field] = value
                self.assertFalse(all(row['passed'] for row in self.evaluate(report)))
        report = copy.deepcopy(self.report)
        report['metrics']['settings']['property_expression_names']['ei-enemy-generation-revision'] = 'ei-enemy-generation-legacy20'
        self.assertFalse(all(row['passed'] for row in self.evaluate(report)))
        for count in (0, -1, True, '1'):
            report = copy.deepcopy(self.report)
            report['metrics']['resource_counts']['ei-gaia-relic-debris'] = count
            self.assertFalse(all(row['passed'] for row in self.evaluate(report)))

    def test_missing_metrics_fail(self):
        with self.assertRaises(KeyError):
            self.evaluate({})


class DataHelpers(unittest.TestCase):
    def test_actual_lua_helpers(self):
        result = subprocess.run([str(REPO / '.tools/lua-5.4.8/lua54.exe'),
                                 str(Path(__file__).with_name('test_data_helpers.lua')),
                                 str(REPO / 'exotic-space-industries-remembrance')],
                                capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('passed=true', result.stdout)


if __name__ == '__main__':
    unittest.main()
