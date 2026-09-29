"""Behavioral fixtures for coverage, dependency discovery, and backlink safety."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unittest
import uuid

import blueprint_audit as audit


class BlueprintAuditTests(unittest.TestCase):
    def setUp(self):
        fixture_root = (Path.cwd() / "output/blueprint-audit-tests").resolve()
        fixture_root.mkdir(parents=True, exist_ok=True)
        self.root = fixture_root / uuid.uuid4().hex[:12]
        self.root.mkdir()
        self.assertTrue(self.root.resolve().is_relative_to(fixture_root))
        self.addCleanup(shutil.rmtree, self.root)
        self.pack = audit.PACK
        self.doc = audit.MODEL_ROOT + "/example.md"
        self.write(self.pack + "/info.json", json.dumps({"name": self.pack}))
        self.write(self.pack + "/control.lua", "return {}\n")
        self.sources = [self.pack + "/control.lua"]
        self.install_model()

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def install_model(self, exceptions=""):
        for path in self.sources:
            target = self.root / path
            body = target.read_text(encoding="utf-8") if target.exists() else "return {}\n"
            body = re.sub(r"^-- blueprint:.*\n", "", body)
            self.write(path, f"-- blueprint: {self.doc}#contract\n" + body)
        links = "\n".join(f"- [{Path(p).name}](../../../{p})" for p in self.sources)
        self.write(self.doc, '<a id="contract"></a>\n# Example\n\n## Implementation sources\n' + links + '\n\n<a id="lifecycle"></a>\n## Lifecycle\nObserved behavior.\n')
        self.write(audit.MODEL_ROOT + "/index.md", "# Index\n\n- [Example](example.md#contract)\n\n## Coverage exceptions\n\n| Source | Classification | Reason |\n| --- | --- | --- |\n" + exceptions)

    def result(self):
        return audit.audit(self.root)

    def codes(self):
        return {f["code"] for f in self.result()["findings"]}

    def test_valid_model_multiple_sources_and_reference(self):
        helper = self.pack + "/lib/helper.lua"
        self.sources.append(helper)
        self.write(self.pack + "/control.lua", "local helper = require('lib.helper')\nreturn helper\n")
        self.write(helper, f"-- blueprint-ref: {self.doc}#lifecycle\nreturn {{}}\n")
        self.install_model()
        self.assertEqual(self.result()["findings"], [])
        self.assertEqual(self.result()["counts"]["runtime_dependencies"], 2)

    def test_new_control_module_requires_owner(self):
        self.write(self.pack + "/scripts/control/new.lua", "return {}\n")
        self.assertIn("unowned-source", self.codes())

    def test_exception_accounts_for_empty_placeholder(self):
        name = self.pack + "/scripts/control/empty.lua"
        self.write(name, "-- Reserved; no behavior.\n")
        self.install_model(f"| [empty](../../../{name}) | inactive | Empty unreferenced placeholder. |\n")
        self.assertEqual(self.result()["findings"], [])
        self.write(name, "return {}\n")
        self.assertIn("nonempty-inactive", self.codes())

    def test_data_only_exception_cannot_mask_runtime_import(self):
        name = self.pack + "/scripts/control/data.lua"
        importer = self.pack + "/scripts/data-updates/importer.lua"
        self.write(name, "return {}\n")
        self.write(importer, "require('scripts.control.data')\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [data owner](../../../{importer}). |\n")
        self.assertEqual(self.result()["findings"], [])
        path = self.root / self.sources[0]
        path.write_text(path.read_text() + "\nrequire('scripts.control.data')\n", encoding="utf-8")
        self.assertIn("runtime-exception", self.codes())

    def test_data_only_evidence_does_not_enroll_data_closure(self):
        name = self.pack + "/scripts/control/data.lua"
        importer = self.pack + "/scripts/data-updates/importer.lua"
        sibling = self.pack + "/lib/data-helper.lua"
        self.write(name, "return {}\n")
        self.write(importer, "--[=[ require('fake-comment') ]=]\nlocal text = \"require('fake-string')\"\nrequire [=[scripts.control.data]=]\nrequire('lib/data-helper')\n")
        self.write(sibling, "require('not-traversed')\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [data owner](../../../{importer}). |\n")
        result = self.result()
        self.assertEqual(result["findings"], [])
        self.assertEqual(result["counts"]["runtime_dependencies"], 1)
        self.assertNotIn(importer, {row["file"] for row in result["sources"]})
        self.assertNotIn(sibling, {row["file"] for row in result["sources"]})

    def test_data_only_exception_requires_linked_evidence(self):
        name = self.pack + "/scripts/control/data.lua"
        self.write(name, "return {}\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by a data-stage owner. |\n")
        self.assertIn("unproven-data-only", self.codes())

    def test_data_only_evidence_must_still_import_excluded_source(self):
        name = self.pack + "/scripts/control/data.lua"
        importer = self.pack + "/scripts/data-updates/importer.lua"
        self.write(name, "return {}\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [data owner](../../../{importer}). |\n")
        for body in ("return {}\n", "-- require('scripts/control/data')\nreturn {}\n",
                     "local example = [=[require('scripts/control/data')]=]\nreturn example\n"):
            with self.subTest(body=body):
                self.write(importer, body)
                self.assertIn("unproven-data-only", self.codes())

    def test_data_only_evidence_rejects_missing_or_non_lua_file(self):
        name = self.pack + "/scripts/control/data.lua"
        importer = self.pack + "/scripts/data-updates/importer.lua"
        self.write(name, "return {}\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [data owner](../../../{importer}). |\n")
        self.assertIn("missing-target", self.codes())
        self.assertIn("unproven-data-only", self.codes())
        document = self.pack + "/importer.md"
        self.write(document, "require('scripts/control/data')\n")
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [text](../../../{document}). |\n")
        self.assertIn("unproven-data-only", self.codes())

    def test_data_only_evidence_rejects_control_directory_and_runtime_importer(self):
        name = self.pack + "/scripts/control/data.lua"
        self.write(name, "return {}\n")
        importer = self.pack + "/scripts/control/importer.lua"
        self.write(importer, "require('scripts/control/data')\n")
        self.sources.append(importer)
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [control owner](../../../{importer}). |\n")
        self.assertIn("unproven-data-only", self.codes())
        runtime_importer = self.pack + "/lib/runtime-importer.lua"
        self.write(runtime_importer, "require('scripts/control/data')\n")
        self.write(self.sources[0], "require('lib/runtime-importer')\n")
        self.sources.append(runtime_importer)
        self.install_model(f"| [data](../../../{name}) | data-only | Imported by [runtime owner](../../../{runtime_importer}). |\n")
        self.assertIn("unproven-data-only", self.codes())
        self.assertIn("runtime-exception", self.codes())

    def test_invalid_exception_reason(self):
        name = self.pack + "/scripts/control/empty.lua"
        self.write(name, "")
        self.install_model(f"| [empty](../../../{name}) | inactive | |\n")
        self.assertIn("invalid-exception", self.codes())

    def test_nested_alternate_requires_cycles_and_external(self):
        a, b = self.pack + "/lib/a.lua", self.pack + "/lib/b.lua"
        self.sources += [a, b]
        self.write(self.pack + "/control.lua", "if false then require\n('lib/a.lua') end\nrequire('__base__.foo')\n")
        self.write(a, "local b = require [=[lib.b]=]\nreturn b\n")
        self.write(b, f"require('__{self.pack}__/lib/a')\nreturn {{}}\n")
        self.install_model()
        self.assertEqual(self.result()["findings"], [])
        self.assertEqual(self.result()["counts"]["runtime_dependencies"], 3)

    def test_require_syntax_inside_comments_and_strings_is_ignored(self):
        self.write(self.pack + "/control.lua", "-- require('missing1')\n--[==[ require('missing2') ]==]\nlocal a = [=[require('missing3')]=]\nlocal b = \"require('missing4')\\\"\"\nreturn a\n")
        self.install_model()
        self.assertEqual(self.result()["findings"], [])

    def test_dynamic_require_and_bounded_mapping(self):
        self.write(self.pack + "/control.lua", "require(name)\n")
        self.install_model()
        self.assertIn("dynamic-import", self.codes())
        helper = self.pack + "/lib/helper.lua"
        self.sources.append(helper)
        self.write(self.pack + "/control.lua", '-- blueprint-requires: ["lib/helper"]\nrequire(name)\n')
        self.install_model()
        self.assertEqual(self.result()["findings"], [])

    def test_stale_mapping_is_reported(self):
        path = self.root / self.sources[0]
        path.write_text(path.read_text() + '\n-- blueprint-requires: ["lib/helper"]\n', encoding="utf-8")
        self.assertIn("stale-import-map", self.codes())

    def test_trailing_require_references_need_bounded_mapping(self):
        helper = self.pack + "/lib/helper.lua"
        self.sources.append(helper)
        self.write(helper, "return {}\n")
        for expression in ("return require", "local loader = require"):
            with self.subTest(expression=expression):
                self.write(self.sources[0], expression)
                self.install_model()
                self.assertIn("dynamic-import", self.codes())
                self.write(self.sources[0], '-- blueprint-requires: ["lib/helper"]\n' + expression)
                self.install_model()
                self.assertEqual(self.result()["findings"], [])
                self.assertEqual(self.result()["counts"]["runtime_dependencies"], 2)

    def test_migration_dependency_is_required(self):
        self.write(self.pack + "/migrations/1.0.lua", "require('lib/migrate')\n")
        self.write(self.pack + "/lib/migrate.lua", "return {}\n")
        result = self.result()
        self.assertEqual(result["counts"]["runtime_dependencies"], 3)
        self.assertIn("unowned-source", self.codes())

    def test_missing_document_and_fragment(self):
        path = self.root / self.sources[0]
        path.write_text(f"-- blueprint: {audit.MODEL_ROOT}/missing.md#contract\nreturn {{}}\n", encoding="utf-8")
        self.assertIn("missing-target", self.codes())
        self.install_model()
        path.write_text(path.read_text() + f"\n-- blueprint-ref: {self.doc}#absent\n", encoding="utf-8")
        self.assertIn("missing-anchor", self.codes())

    def test_duplicate_anchor_owner_and_deleted_source(self):
        doc = self.root / self.doc
        doc.write_text(doc.read_text() + '\n<a id="contract"></a>\n', encoding="utf-8")
        self.assertIn("duplicate-anchor", self.codes())
        self.write(audit.MODEL_ROOT + "/other.md", doc.read_text())
        self.assertIn("duplicate-owner", self.codes())
        (self.root / self.sources[0]).unlink()
        self.assertIn("missing-target", self.codes())

    def test_missing_reverse_link_and_wrong_owner(self):
        self.write(self.doc, '<a id="contract"></a>\n# Unowned\n')
        self.assertIn("missing-reciprocal-owner", self.codes())
        self.assertIn("orphan-model", self.codes())

    def test_external_paths_and_late_marker_fail(self):
        self.write(self.pack + "/control.lua", f"local x = 1\n-- blueprint: {self.doc}#contract\nreturn x\n")
        self.assertIn("late-primary", self.codes())
        self.write(self.pack + "/control.lua", "-- blueprint: ../../outside.md#contract\nreturn {}\n")
        self.assertIn("outside-repo", self.codes())

    def test_same_result_with_stale_manifests_or_installed_mod_list(self):
        before = self.result()
        self.write(".codex/esir/runtime-modules.json", '{"repo_root":"wrong","entries":[]}')
        self.write("mod-list.json", '{"mods":[{"name":"space-age","enabled":false}]}')
        self.assertEqual(before, self.result())

    def test_audit_and_cli_do_not_write(self):
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        process = subprocess.run([sys.executable, "-B", str(Path(audit.__file__)), "--repo-root", str(self.root), "--format", "json"], capture_output=True, text=True)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(json.loads(process.stdout)["overall_status"], "ok")
        self.assertEqual(before, {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        self.write(self.pack + "/scripts/control/missing.lua", "return {}")
        process = subprocess.run([sys.executable, "-B", str(Path(audit.__file__)), "--repo-root", str(self.root), "--format", "json"], capture_output=True, text=True)
        self.assertEqual(process.returncode, 1)

    def test_executable_tokens_preserve_strings_and_ignore_comments(self):
        old = 'local text = "-- this is a string"\nreturn text\n'
        new = '-- blueprint: some.md#contract\n' + old.replace('return', '-- rationale\nreturn')
        self.assertEqual(audit.executable_tokens(old), audit.executable_tokens(new))
        self.assertNotEqual(audit.executable_tokens(old), audit.executable_tokens(old.replace('this', 'changed')))

    def test_generated_header_marker_is_rejected(self):
        text = f"--==============================================================================\n-- ESIR FILE MAP\n-- blueprint: {self.doc}#contract\n--==============================================================================\nreturn {{}}\n"
        self.write(self.sources[0], text)
        self.assertIn("generated-header-primary", self.codes())

    def test_protected_import_and_alias_cannot_hide_dependencies(self):
        helper = self.pack + "/lib/hidden.lua"
        self.write(helper, "return {}")
        for expression in ("pcall(require, 'lib/hidden')", "xpcall(require, handler, 'lib/hidden')"):
            self.write(self.sources[0], expression)
            self.install_model()
            self.assertEqual(self.result()["counts"]["runtime_dependencies"], 2)
            self.assertIn("unowned-source", self.codes())
        self.write(self.sources[0], "local load_module = require\nload_module('lib/hidden')")
        self.install_model()
        self.assertIn("dynamic-import", self.codes())

    def test_protected_import_invalidates_data_only_exception(self):
        helper = self.pack + "/scripts/control/data.lua"
        self.write(helper, "return {}")
        self.write(self.sources[0], "pcall(require, 'scripts/control/data')")
        self.install_model(f"| [data](../../../{helper}) | data-only | Data-stage helper. |\n")
        self.assertIn("runtime-exception", self.codes())

    def test_same_document_anchor_is_validated(self):
        doc = self.root / self.doc
        doc.write_text(doc.read_text() + "\n[Good](#lifecycle)\n[Bad](#missing)\n", encoding="utf-8")
        findings = self.result()["findings"]
        self.assertEqual([(f["code"], f["target"]) for f in findings], [("missing-anchor", "#missing")])

    def test_marker_after_code_on_same_line_is_rejected(self):
        self.write(self.sources[0], f"local n = 1 -- blueprint: {self.doc}#contract\nreturn n")
        self.assertIn("late-primary", self.codes())

    def test_html_comment_cannot_declare_ownership(self):
        doc = self.root / self.doc
        doc.write_text(doc.read_text().replace("## Implementation sources", "<!--\n## Implementation sources").replace('<a id="lifecycle">', '-->\n<a id="lifecycle">'), encoding="utf-8")
        self.assertIn("orphan-model", self.codes())
        self.assertIn("missing-reciprocal-owner", self.codes())

    def test_unrelated_string_is_not_a_marker(self):
        self.write(self.pack + "/prototypes/unrelated.lua", 'local example = "blueprint:"\nreturn example')
        self.assertEqual(self.result()["findings"], [])


if __name__ == "__main__":
    unittest.main()
