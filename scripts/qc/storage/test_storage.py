"""Meaningful storage invariants; disposable temporary repositories only."""
import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import unittest
import uuid
from unittest import mock
import zipfile

SCRIPT = Path(__file__).resolve().parents[2] / 'esir_qc_storage.py'
SPEC = importlib.util.spec_from_file_location('esir_qc_storage', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class StorageTests(unittest.TestCase):
    def setUp(self):
        fixture_parent = SCRIPT.parent.parent / 'output'
        fixture_parent.mkdir(exist_ok=True)
        self.repo = fixture_parent / ('esir-storage-' + uuid.uuid4().hex)
        self.repo.mkdir()
        self.store = MODULE.QCStorage(self.repo)
        with self.store.locked():
            self.store.state['reserve_bytes'] = 0
            self.store.state['default_estimate_bytes'] = 0
            self.store.save()

    def tearDown(self):
        # Test-created junctions are explicitly unlinked before TemporaryDirectory.
        state = MODULE.dispatch(self.repo, 'status')
        for run in state['runs']:
            for link in run['links']:
                path = Path(link)
                if MODULE.is_link(path):
                    MODULE.unlink_directory_link(path)
        self.assertEqual(self.repo.parent, SCRIPT.parent.parent / 'output')
        self.assertTrue(self.repo.name.startswith('esir-storage-'))
        shutil.rmtree(self.repo)

    def package(self, text='return true', name='test-mod', version='1.0.0'):
        root = self.repo / ('inputs-' + str(len(list(self.repo.glob('inputs-*')))))
        root.mkdir()
        path = root / (name + '_' + version + '.zip')
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as output:
            output.writestr(name + '/info.json', json.dumps({'name': name, 'version': version, 'factorio_version': '2.1'}))
            output.writestr(name + '/data.lua', text)
        return path

    def source(self):
        root = self.repo / 'source-mod'
        root.mkdir()
        (root / 'info.json').write_text(json.dumps({'name': 'source-mod', 'version': '1.0.0', 'factorio_version': '2.1'}))
        (root / 'control.lua').write_text('return true')
        (root / 'graphics').mkdir()
        (root / 'graphics/icon.png').write_bytes(b'png-placeholder')
        return root

    def open(self, number=1, mode='read-only'):
        run_id = f'{number:032x}'
        return MODULE.dispatch(self.repo, 'open', {'run_id': run_id, 'source_mode': mode, 'workflow': 'test',
                               'evidence_root': str(self.repo / '.factorio-qc/managed' / run_id)})

    def test_duplicate_import_uses_one_physical_file_and_content_collision_is_distinct(self):
        path = self.package()
        first = MODULE.dispatch(self.repo, 'import', {'path': str(path)})
        second = MODULE.dispatch(self.repo, 'import', {'path': str(path)})
        self.assertEqual(first['path'], second['path'])
        self.assertEqual(os.stat(path).st_ino, os.stat(first['path']).st_ino)
        variant = MODULE.dispatch(self.repo, 'import', {'path': str(self.package('return false'))})
        self.assertNotEqual(first['sha256'], variant['sha256'])
        self.assertEqual(len(MODULE.dispatch(self.repo, 'status')['artifacts']), 2)
        with self.assertRaises(MODULE.StorageError):
            MODULE.dispatch(self.repo, 'import', {'path': str(path), 'sha256': '0' * 64})

    def test_views_are_hardlinks_and_settings_are_private(self):
        package = MODULE.dispatch(self.repo, 'import', {'path': str(self.package())})
        settings = self.repo / 'settings.dat'
        settings.write_bytes(b'original')
        first, second = self.open(1), self.open(2)
        for run in (first, second):
            MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': [package], 'settings_path': str(settings)})
        paths = [Path(run['mod_view_root']) / 'test-mod_1.0.0.zip' for run in (first, second)]
        self.assertEqual(os.stat(paths[0]).st_ino, os.stat(paths[1]).st_ino)
        (Path(first['mod_view_root']) / 'mod-settings.dat').write_bytes(b'changed')
        self.assertEqual((Path(second['mod_view_root']) / 'mod-settings.dat').read_bytes(), b'original')
        self.assertEqual(MODULE.dispatch(self.repo, 'collect', {'apply': True})['removed'], [])

    def test_private_mutation_cannot_change_source_and_drift_invalidates(self):
        source = self.source()
        run = self.open(mode='private-mutable')
        staged = MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'sources': [{'path': str(source)}]})
        target = Path(staged['mod_view_root']) / 'source-mod'
        (target / 'control.lua').write_text('private change')
        self.assertEqual((source / 'control.lua').read_text(), 'return true')
        self.assertTrue(MODULE.dispatch(self.repo, 'validate', {'run_id': run['run_id']})['valid'])
        (source / 'control.lua').write_text('concurrent edit')
        with self.assertRaises(MODULE.StorageError):
            MODULE.dispatch(self.repo, 'release', {'run_id': run['run_id']})
        self.assertTrue(target.exists())

    def test_failed_hardlink_has_no_copy_fallback(self):
        package = MODULE.dispatch(self.repo, 'import', {'path': str(self.package())})
        run = self.open()
        with mock.patch.object(MODULE.os, 'link', side_effect=OSError('simulated cross-volume')):
            with self.assertRaisesRegex(MODULE.StorageError, 'no copy fallback'):
                MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': [package]})
        self.assertEqual(list(Path(run['mod_view_root']).glob('*.zip')), [])

    def test_close_retains_compact_evidence_and_selected_capture_then_collects(self):
        package = MODULE.dispatch(self.repo, 'import', {'path': str(self.package())})
        source = self.source()
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': [package], 'sources': [{'path': str(source)}]})
        scratch = Path(run['scratch_root'])
        (scratch / 'factorio.log').write_text('success')
        (scratch / 'data-raw-dump.json').write_text('{"bulky":"discard"}')
        (scratch / 'selected.png').write_bytes(b'capture')
        (scratch / 'unused.png').write_bytes(b'intermediate')
        result = MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id'], 'retain': [str(scratch / 'selected.png')]})
        self.assertFalse(scratch.exists())
        self.assertFalse(Path(run['view_root']).exists())
        self.assertTrue((source / 'control.lua').exists())
        evidence = Path(run['evidence_root'])
        self.assertEqual((evidence / 'selected/selected.png').read_bytes(), b'capture')
        with zipfile.ZipFile(result['evidence_archive']) as archive:
            self.assertIn('scratch/factorio.log', archive.namelist())
            self.assertNotIn('scratch/data-raw-dump.json', archive.namelist())
        self.assertEqual(MODULE.dispatch(self.repo, 'status')['artifacts'], [])

    def test_profile_and_pin_protect_then_unused_package_expires(self):
        package = MODULE.dispatch(self.repo, 'import', {'path': str(self.package()), 'profile': 'current'})
        self.assertEqual(MODULE.dispatch(self.repo, 'collect', {'apply': True})['removed'], [])
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': [package]})
        MODULE.dispatch(self.repo, 'pin', {'run_id': run['run_id'], 'reason': 'comparison'})
        with self.assertRaisesRegex(MODULE.StorageError, 'Pinned'):
            MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
        MODULE.dispatch(self.repo, 'pin', {'run_id': run['run_id'], 'reason': 'comparison', 'pinned': False})
        MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
        self.assertEqual(len(MODULE.dispatch(self.repo, 'status')['artifacts']), 1)
        MODULE.dispatch(self.repo, 'profile', {'name': 'current', 'packages': []})
        self.assertEqual(MODULE.dispatch(self.repo, 'collect', {'apply': True})['removed'], [package['sha256']])

    def test_active_lease_blocks_relocation_and_capacity_selects_overflow(self):
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': []})
        with self.assertRaisesRegex(MODULE.StorageError, 'active run'):
            MODULE.dispatch(self.repo, 'relocate')
        overflow = self.repo / 'fake-d'
        with mock.patch.object(MODULE.QCStorage, '_overflow', return_value=overflow), \
             mock.patch.object(MODULE.QCStorage, '_fits', side_effect=lambda path, growth: MODULE.within(path, overflow)):
            second = self.open(2)
        self.assertTrue(MODULE.within(second['scratch_root'], overflow))
        self.assertTrue(MODULE.within(second['mod_view_root'], self.repo / '.factorio-qc'))

    def test_first_import_can_overflow_an_unmaterialized_lease(self):
        run = self.open()
        package = self.package()
        overflow = self.repo / 'fake-d'
        with mock.patch.object(MODULE.QCStorage, '_overflow', return_value=overflow), \
             mock.patch.object(MODULE.QCStorage, '_fits', side_effect=lambda path, growth: MODULE.within(path, overflow)):
            staged = MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': [{'path': str(package)}]})
        self.assertTrue(MODULE.within(staged['mod_view_root'], overflow))
        self.assertFalse(Path(run['view_root']).exists())
        self.assertTrue((Path(staged['mod_view_root']) / 'test-mod_1.0.0.zip').exists())

    def test_failed_run_keeps_private_delta_in_compact_reproducer(self):
        source = self.source()
        run = self.open(mode='private-mutable')
        staged = MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'sources': [{'path': str(source)}]})
        (Path(staged['mod_view_root']) / 'source-mod/control.lua').write_text('failing private code')
        result = MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id'], 'status': 'failed'})
        with zipfile.ZipFile(result['evidence_archive']) as archive:
            reproducer = json.loads(archive.read('reports/staged-reproducer.json'))
            self.assertEqual(MODULE.base64.b64decode(reproducer['files']['source-mod/control.lua']), b'failing private code')
        self.assertNotIn('fingerprint', MODULE.dispatch(self.repo, 'status', {'run_id': run['run_id']})['sources'][0])

    def test_migration_verifies_then_publishes_and_interruption_preserves_authority(self):
        package = MODULE.dispatch(self.repo, 'import', {'path': str(self.package()), 'profile': 'current'})
        old = MODULE.dispatch(self.repo, 'status')['store_root']
        overflow = self.repo / 'fake-d'
        with mock.patch.object(MODULE.QCStorage, '_overflow', return_value=overflow):
            result = MODULE.dispatch(self.repo, 'relocate')
        self.assertFalse(Path(old).exists())
        self.assertTrue((Path(result['store_root']) / 'objects' / (package['sha256'] + '.zip')).exists())
        self.assertIsNone(MODULE.dispatch(self.repo, 'status')['migration'])

    def test_interrupted_migration_keeps_old_authoritative(self):
        MODULE.dispatch(self.repo, 'import', {'path': str(self.package()), 'profile': 'current'})
        old = MODULE.dispatch(self.repo, 'status')['store_root']
        with mock.patch.object(MODULE.QCStorage, '_overflow', return_value=self.repo / 'fake-d'), \
             mock.patch.object(MODULE.shutil, 'copyfile', side_effect=OSError('interrupted transfer')):
            with self.assertRaises(OSError):
                MODULE.dispatch(self.repo, 'relocate')
        state = MODULE.dispatch(self.repo, 'status')
        self.assertEqual(state['store_root'], old)
        self.assertEqual(state['migration']['phase'], 'copying')
        self.assertTrue(Path(old).exists())

    def test_existing_evidence_is_never_adopted(self):
        evidence = self.repo / '.factorio-qc/managed/legacy'
        evidence.mkdir(parents=True)
        (evidence / 'important.log').write_text('keep')
        with self.assertRaisesRegex(MODULE.StorageError, 'cannot be adopted'):
            MODULE.dispatch(self.repo, 'open', {'run_id': '12345678', 'workflow': 'test', 'source_mode': 'read-only', 'evidence_root': str(evidence)})
        self.assertEqual((evidence / 'important.log').read_text(), 'keep')

    def test_concurrent_process_imports_serialize_to_one_object(self):
        package = self.package()
        def invoke(_):
            process = subprocess.run([sys.executable, '-B', str(SCRIPT), '--repo', str(self.repo), '--action', 'import'],
                                     input=json.dumps({'path': str(package), 'profile': 'current'}), capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            return json.loads(process.stdout)['sha256']
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            hashes = list(pool.map(invoke, range(3)))
        self.assertEqual(len(set(hashes)), 1)
        self.assertEqual(len(MODULE.dispatch(self.repo, 'status')['artifacts']), 1)

    def test_retargeted_junction_is_protected(self):
        source = self.source()
        other = self.repo / 'other-source'
        other.mkdir()
        (other / 'must-survive.txt').write_text('unique source')
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'sources': [{'path': str(source)}]})
        link = Path(run['mod_view_root']) / 'source-mod'
        MODULE.unlink_directory_link(link)
        MODULE.junction(link, other)
        with self.assertRaisesRegex(MODULE.StorageError, 'retargeted'):
            MODULE.dispatch(self.repo, 'release', {'run_id': run['run_id']})
        self.assertEqual((other / 'must-survive.txt').read_text(), 'unique source')

    @unittest.skipUnless(os.name == 'nt', 'Windows sharing semantics')
    def test_locked_engine_output_is_protected(self):
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': []})
        output = Path(run['scratch_root']) / 'engine.dat'
        output.write_bytes(b'engine still owns this file')
        with output.open('rb'):
            with self.assertRaisesRegex(MODULE.StorageError, 'Win32 32'):
                MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
        self.assertTrue(output.exists())
        result = MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
        self.assertTrue(result['closed'])
        self.assertFalse(output.exists())

    def test_import_consumes_only_explicit_temporary_input(self):
        package = self.package()
        with self.assertRaisesRegex(MODULE.StorageError, 'temporary_root'):
            MODULE.dispatch(self.repo, 'import', {'path': str(package), 'consume': True})
        self.assertTrue(package.exists())
        artifact = MODULE.dispatch(self.repo, 'import', {'path': str(package), 'consume': True, 'temporary_root': str(package.parent)})
        self.assertFalse(package.exists())
        self.assertTrue(Path(artifact['path']).exists())

    def test_public_configuration_and_read_only_empty_status(self):
        config = MODULE.dispatch(self.repo, 'configure', {'reserve_bytes': 17, 'default_estimate_bytes': 29})
        self.assertEqual(config, {'reserve_bytes': 17, 'default_estimate_bytes': 29})
        with self.assertRaises(MODULE.StorageError):
            MODULE.dispatch(self.repo, 'configure', {'reserve_bytes': -1})
        with self.assertRaises(MODULE.StorageError):
            MODULE.dispatch(self.repo, 'configure', {'reserve_bytes': 1.5})
        empty = self.repo / 'empty-repo'
        empty.mkdir()
        self.assertEqual(MODULE.dispatch(empty, 'status')['artifacts'], [])
        MODULE.dispatch(empty, 'collect', {})
        self.assertFalse((empty / '.factorio-qc').exists())

    def test_cross_volume_private_source_uses_owned_source_volume_backing(self):
        source = self.source()
        (source / 'thumbnail.png').write_bytes(b'standalone media')
        run = self.open(mode='private-mutable')
        actual_same_volume = MODULE.same_volume
        with mock.patch.object(MODULE, 'same_volume', side_effect=lambda first, second: False if Path(second) == Path(run['mod_view_root']) else actual_same_volume(first, second)):
            staged = MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'sources': [{'path': str(source)}]})
        backing = Path(staged['private_root'])
        real = MODULE.dispatch(self.repo, 'mutable-sources', {'run_id': run['run_id']})['names']['source-mod']
        self.assertEqual(Path(real), backing / 'source-mod')
        self.assertEqual((Path(real) / 'thumbnail.png').stat().st_ino, (source / 'thumbnail.png').stat().st_ino)
        (Path(real) / 'control.lua').write_text('private mutation')
        result = MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
        self.assertTrue(result['closed'])
        self.assertFalse(backing.exists())
        self.assertEqual((source / 'control.lua').read_text(), 'return true')

    @unittest.skipUnless(os.name == 'nt', 'Windows read-only attributes')
    def test_readonly_leaf_preserves_owner_and_can_retry_after_external_unlock(self):
        run = self.open()
        MODULE.dispatch(self.repo, 'stage', {'run_id': run['run_id'], 'packages': []})
        output = Path(run['scratch_root']) / 'cache.dat'
        output.write_bytes(b'protected')
        output.chmod(0o444)
        try:
            with self.assertRaisesRegex(MODULE.StorageError, 'read-only'):
                MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})
            self.assertTrue((output.parent / '.esir-owner.json').exists())
        finally:
            output.chmod(0o666)  # Only this isolated test's own non-shared file.
        self.assertTrue(MODULE.dispatch(self.repo, 'close', {'run_id': run['run_id']})['closed'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
