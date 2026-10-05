"""Adversarial, temporary-source checks for the read-only structural advisory."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import shutil
import uuid
import unittest

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / '.codex/skills/esir-dev/scripts/runtime_contract_audit.py'
SPEC = importlib.util.spec_from_file_location('runtime_contract_audit', SCRIPT)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)
PACK = AUDIT.PACK


class Contracts(unittest.TestCase):
    def setUp(self):
        staging = REPO / '.factorio-qc/runtime-standards-tests'
        staging.mkdir(parents=True, exist_ok=True)
        # Inherit workspace ACLs: tempfile's mode-0700 directories can exclude
        # Windows sandbox tokens even when located beneath the writable root.
        self.repo = staging / uuid.uuid4().hex
        self.repo.mkdir()
        self.repo.resolve().relative_to(staging.resolve())
        self.addCleanup(shutil.rmtree, self.repo)
        (self.repo / PACK / 'lib').mkdir(parents=True)
        (self.repo / PACK / 'scripts/control').mkdir(parents=True)
        self.config = self.repo / 'exceptions.json'
        self.write('control.lua', '')
        self.write('lib/example.lua', 'local M={}\nfunction M.run(event) end\nreturn M\n')
        self.exceptions([])

    def write(self, path, text):
        (self.repo / PACK / path).write_text(text, encoding='utf-8')

    def exceptions(self, entries):
        self.config.write_text(
            json.dumps({'version': 1, 'exceptions': entries}), encoding='utf-8')

    def report(self):
        return AUDIT.audit(self.repo, self.config)

    def rules(self):
        return [f['rule'] for f in self.report()['findings']]

    def test_comments_and_strings_are_not_executable(self):
        self.write('lib/example.lua', '''local M={}
-- script.on_event(x,f); game.tick
--[=[ function M.run() end; script.on_load(f) ]=]
local s="escaped \\\" script.on_event(x,f)"
local long=[==[ game.tick; function M.run() end ]==]
function M.run(event) end
return M
''')
        self.assertEqual(self.rules(), [])

    def test_multiline_and_assigned_exports(self):
        self.write('lib/example.lua', 'local M={}\nfunction M.run(\n event\n) end\nM.other = function(tick) end\nreturn M')
        exports = self.report()['exports']
        self.assertEqual([(e['symbol'], e['parameters']) for e in exports], [('run', ['event']), ('other', ['tick'])])

    def test_registration_only_outside_dispatcher(self):
        self.write('control.lua', 'script.on_event(x,f)\nscript.on_nth_tick(2,f)')
        self.write('scripts/control/extra.lua', 'script.on_load(f)\ncommands.add_command(x,x,f)\nremote.add_interface(x,{})')
        self.assertEqual(self.rules(), ['parallel-registration'])

    def test_clock_reads_are_review_inventory(self):
        self.write('control.lua', 'local tick=game.tick')
        report = self.report()
        self.assertEqual(report['findings'][0]['rule'], 'clock-review')
        self.assertEqual(report['clock_reads'][0]['line'], 1)
        self.assertFalse(report['blocking'])

    def test_colon_call_to_known_dot_export(self):
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)')
        self.assertEqual(self.rules(), ['module-call-form'])

    def test_method_definition_is_not_a_call(self):
        self.write('control.lua', 'local m=require("lib/example")\nfunction m:run(event) end')
        self.assertEqual(self.rules(), [])

    def test_native_and_unknown_receivers_are_not_proven_modules(self):
        self.write('control.lua', 'entity:destroy()\ndata:extend({})\nunknown:run(event)')
        self.assertEqual(self.rules(), [])

    def test_self_methods_and_explicit_self(self):
        self.write('lib/example.lua', 'local M={}\nfunction M:run(event) end\nfunction M.other(self,event) end\nreturn M')
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)\nm.run(m,event)\nm:other(event)')
        self.assertEqual(self.rules(), [])

    def test_missing_self_is_reviewed(self):
        self.write('lib/example.lua', 'local M={}\nfunction M:run(event) end\nreturn M')
        self.write('control.lua', 'local m=require("lib/example")\nm.run(event)')
        self.assertEqual(self.rules(), ['module-call-form'])

    def test_rebound_and_shadowed_bindings_are_uncertain(self):
        for text in ('local m=require("lib/example")\nm=entity\nm:run(event)',
                     'local m=require("lib/example")\nfunction f(m) m:run(event) end',
                     'local m=require("lib/example")\nlocal m\nm:run(event)',
                     'm:run(event)\nlocal m=require("lib/example")'):
            with self.subTest(text=text):
                self.write('control.lua', text)
                self.assertEqual(self.rules(), [])

    def test_conditional_and_forwarded_exports_are_uncertain(self):
        self.write('lib/example.lua', 'local M={}\nif flag then function M.run(event) end end\nM.other=external.run\nreturn M')
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)\nm:other(event)')
        report = self.report()
        self.assertEqual(report['findings'], [])
        self.assertEqual(report['aliases'][0]['symbol'], 'other')

    def test_nonliteral_expression_and_loop_bindings_are_uncertain(self):
        for text in ('local m=require("lib/example" .. suffix)\nm:run(event)',
                     'local m=require("lib/example") .. suffix\nm:run(event)',
                     'local m=require("lib/example")\nfor m in iterator do m:run(event) end',
                     'local m=require("lib/example")\nfor _,m in pairs(items) do m:run(event) end',
                     'local m=require("lib/example")\nm,other=entity,2\nm:run(event)',
                     'local m=require("lib/example")\nlocal other,m\nm:run(event)'):
            with self.subTest(text=text):
                self.write('control.lua', text)
                self.assertEqual(self.rules(), [])

    def test_rebound_root_and_overridden_export_are_uncertain(self):
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)')
        for body in ('M=object', 'M.run=object.run'):
            with self.subTest(body=body):
                self.write('lib/example.lua', 'local M={}\nfunction M.run(event) end\n'+body+'\nreturn M')
                self.assertEqual(self.rules(), [])

    def test_dynamic_import_is_inventory(self):
        self.write('control.lua', 'local m=require(module_name)\nm:run(event)')
        report = self.report()
        self.assertEqual(report['findings'], [])
        self.assertIsNone(report['imports'][0]['module'])
        self.assertFalse(report['imports'][0]['proven'])

    def test_global_import_then_local_shadow_is_uncertain(self):
        self.write('control.lua', 'm=require("lib/example")\nlocal m;\nm:run(event)')
        report = self.report()
        self.assertEqual(report['findings'], [])
        self.assertFalse(report['imports'][0]['proven'])

    def test_mixed_parallel_assignment_is_uncertain(self):
        self.write('control.lua', 'local m=require("lib/example")\nm,other.value=entity,2\nm:run(event)')
        report = self.report()
        self.assertEqual(report['findings'], [])
        self.assertFalse(report['imports'][0]['proven'])

    def test_provider_bracket_overwrite_is_uncertain(self):
        self.write('lib/example.lua', 'local M={}\nfunction M.run(event) end\nM["run"]=external.run\nreturn M')
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)')
        report = self.report()
        self.assertEqual(report['findings'], [])
        self.assertTrue(report['exports'][0]['uncertain'])
        self.assertFalse(report['calls'][0]['proven_export'])

    def test_caller_method_replacement_is_uncertain(self):
        for replacement in ('function m:run(event) end', 'm.run=external.run', 'm["run"]=external.run'):
            with self.subTest(replacement=replacement):
                self.write('control.lua', 'local m=require("lib/example")\n'+replacement+'\nm:run(event)')
                report = self.report()
                self.assertEqual(report['findings'], [])
                self.assertFalse(report['imports'][0]['proven'])

    def test_provider_bracket_read_keeps_proof(self):
        self.write('lib/example.lua', 'local M={}\nfunction M.run(event) end\nlocal existing=M["run"]\nreturn M')
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)')
        self.assertEqual(self.rules(), ['module-call-form'])

    def test_nested_table_assignment_is_not_module_export(self):
        self.write('lib/example.lua', 'local M={}\nother.M.run=function(event) end\nreturn M')
        self.assertEqual(self.report()['exports'], [])

    def test_missing_observed_key_does_not_match_null_exception(self):
        self.exceptions([{'file': PACK+'/lib/example.lua', 'rule': 'signature', 'symbol': 'run',
                          'expected': {'nonexistent': None}, 'reason': 'Invalid shape cannot match.'}])
        self.assertEqual(self.rules(), ['stale-exception'])

    def test_required_probe_not_boolean_result(self):
        self.write('control.lua', 'local m=require("lib/example")\nif m.run then m.run(event) end\nif m.run(event) then result=true end')
        self.assertEqual(self.rules(), ['required-export-probe'])

    def test_duplicate_exports_ignore_comments(self):
        self.write('lib/example.lua', 'local M={}\nfunction M.run() end\n-- function M.run() end\nM.run=function() end\nreturn M')
        self.assertEqual(self.rules(), ['duplicate-export'])

    def test_matched_and_stale_exceptions(self):
        entry = {'file': PACK+'/lib/example.lua', 'rule': 'signature', 'symbol': 'run',
                 'expected': {'parameters': ['event'], 'form': '.'}, 'reason': 'Native event contract.'}
        self.exceptions([entry])
        report = self.report()
        self.assertEqual(report['applied_exception_count'], 1)
        self.assertEqual(report['stale_exception_count'], 0)
        self.write('lib/example.lua', 'local M={}\nfunction M.run(tick) end\nreturn M')
        self.assertEqual(self.rules(), ['stale-exception'])

    def test_narrow_finding_exception_and_configuration_validation(self):
        self.write('control.lua', 'local m=require("lib/example")\nif m.run then m.run(event) end')
        entry = {'file': PACK+'/control.lua', 'rule': 'required-export-probe', 'symbol': 'run',
                 'expected': {'form': '.', 'target': PACK+'/lib/example.lua'}, 'reason': 'Diagnostic collector.'}
        self.exceptions([entry])
        self.assertEqual(self.rules(), [])
        self.exceptions([entry, entry])
        with self.assertRaises(ValueError):
            self.report()

    def test_stable_reporting_and_cli_exit_codes(self):
        self.write('control.lua', 'local m=require("lib/example")\nm:run(event)\nlocal tick=game.tick')
        self.assertEqual(self.report(), self.report())
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), '--repo-root', str(self.repo), '--exceptions', str(self.config), '--format', 'json'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['run_status'], 'ok')
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), '--repo-root', str(self.repo), '--exceptions', str(self.config), '--format', 'markdown'], capture_output=True, text=True)
        self.assertIn('Structural advisory', result.stdout)
        self.config.unlink()
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), '--repo-root', str(self.repo), '--exceptions', str(self.config)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stderr)['run_status'], 'unavailable')


if __name__ == '__main__':
    unittest.main()
