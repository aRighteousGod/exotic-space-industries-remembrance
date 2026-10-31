"""Observable package reuse and portal capture/consumer lifecycle contracts."""
import importlib.util
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import uuid
import zipfile

SCRIPTS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SCRIPTS))
from esir_qc_storage import dispatch, StorageError
from esir_qc_package import package


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.gettempdir()) / ('esir-adapter-' + uuid.uuid4().hex)
        self.repo.mkdir()
        self.run_id = uuid.uuid4().hex
        self.run = dispatch(self.repo, 'open', {'run_id': self.run_id, 'workflow': 'adapter-test',
            'source_mode': 'read-only', 'estimate_bytes': 1024,
            'evidence_root': str(self.repo / '.factorio-qc/evidence')})

    def tearDown(self):
        # Only this test's random directory is removed; views are closed first.
        dispatch(self.repo, 'close', {'run_id': self.run_id, 'status': 'test'})
        shutil.rmtree(self.repo)

    def test_package_reuses_exact_content_and_tracks_same_version_changes(self):
        source = self.repo / 'fixture'
        source.mkdir()
        (source / 'info.json').write_text(json.dumps({'name':'fixture', 'version':'1.0.0', 'factorio_version':'2.1'}))
        code = source / 'data.lua'
        code.write_text('-- first')
        first = package(self.repo, self.run_id, source)
        second = package(self.repo, self.run_id, source)
        self.assertTrue(second['reused'])
        self.assertEqual(first['sha256'], second['sha256'])
        self.assertEqual(Path(first['path']).stat().st_ino, Path(second['path']).stat().st_ino)
        code.write_text('-- second')
        third = package(self.repo, self.run_id, source)
        self.assertNotEqual(first['sha256'], third['sha256'])
        self.assertEqual(len(dispatch(self.repo, 'status', {})['artifacts']), 2)
        self.assertEqual(list(Path(self.run['scratch_root']).glob('package-*.zip')), [])

    def test_package_reuse_rejects_source_drift_during_lookup(self):
        source = self.repo / 'fixture'
        source.mkdir()
        (source / 'info.json').write_text(json.dumps({'name':'fixture', 'version':'1.0.0', 'factorio_version':'2.1'}))
        code = source / 'data.lua'
        code.write_text('-- first')
        package(self.repo, self.run_id, source)

        def concurrent_edit(repo, action, data):
            result = dispatch(repo, action, data)
            if action == 'status' and not data:
                code.write_text('-- changed during cached lookup')
            return result

        with patch('esir_qc_package.dispatch', side_effect=concurrent_edit):
            with self.assertRaisesRegex(StorageError, 'Source inventory changed'):
                package(self.repo, self.run_id, source)

    @unittest.skipUnless(os.name == 'nt', 'PowerShell adapter is Windows-specific')
    def test_powershell_package_mode_uses_shared_store(self):
        source = self.repo / 'fixture'
        source.mkdir()
        (source / 'info.json').write_text(json.dumps({'name':'fixture', 'version':'1.0.0', 'factorio_version':'2.1'}))
        environment = os.environ.copy()
        environment.update(ESIR_TEST_LIB=str(SCRIPTS / 'esir-dev-lib.ps1'), ESIR_TEST_REPO=str(self.repo),
                           ESIR_TEST_RUN=self.run_id, ESIR_TEST_SOURCE=str(source))
        command = ". $env:ESIR_TEST_LIB; $c=[pscustomobject]@{repo_root=$env:ESIR_TEST_REPO; qc_run_id=$env:ESIR_TEST_RUN; source_mods=@([pscustomobject]@{directory=$env:ESIR_TEST_SOURCE;folder_name='fixture';name='fixture'})}; Invoke-FactorioPackageQC -Context $c | ConvertTo-Json -Depth 8"
        completed = subprocess.run(['powershell','-NoProfile','-Command',command], env=environment, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        result = json.loads(completed.stdout)
        self.assertEqual(result['status'], 'ok')
        self.assertEqual(result['findings'][0]['entry_count'], 1)
        self.assertEqual(len(dispatch(self.repo, 'status', {})['artifacts']), 1)

    def test_acquisition_consumes_new_download_and_reuses_canonical_package(self):
        spec = importlib.util.spec_from_file_location('acquire_test', SCRIPTS / 'qc/factorio-2.1/acquire_dependencies.py')
        acquire = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(acquire)
        acquire.REPO = self.repo
        payload = io.BytesIO()
        info = {'name':'fixture', 'version':'1.0.0', 'factorio_version':'2.1'}
        with zipfile.ZipFile(payload, 'w') as archive:
            archive.writestr('fixture_1.0.0/info.json', json.dumps(info))
        raw = payload.getvalue()
        metadata = {'releases':[{'version':'1.0.0', 'file_name':'fixture_1.0.0.zip', 'info_json':info,
                     'sha1':hashlib.sha1(raw).hexdigest(), 'download_url':'/test.zip'}]}
        output = self.repo / 'downloads'
        output.mkdir()
        with patch.dict(os.environ, {'FACTORIO_USERNAME':'test', 'FACTORIO_TOKEN':'test'}), \
             patch.object(acquire.urllib.request, 'urlopen', return_value=io.BytesIO(raw)) as download:
            result = acquire.acquire('fixture', '1.0.0', output, metadata)
            self.assertEqual(result['status'], 'verified-package')
            self.assertEqual(list(output.iterdir()), [])
            again = acquire.acquire('fixture', '1.0.0', output, metadata)
            self.assertEqual(again['sha256'], result['sha256'])
            self.assertEqual(download.call_count, 1)
        self.assertEqual(len(dispatch(self.repo, 'status', {})['artifacts']), 1)

    def test_development_seed_contains_manifests_without_archive_copies(self):
        spec = importlib.util.spec_from_file_location('seed_test', SCRIPTS / 'qc/factorio-2.1/prepare_development_seed.py')
        seed = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(seed)
        seed.__file__ = str(self.repo / 'scripts/qc/factorio-2.1/prepare_development_seed.py')
        archive = self.repo / 'dependency_1.0.0.zip'
        info = {'name':'dependency', 'version':'1.0.0', 'factorio_version':'2.1'}
        with zipfile.ZipFile(archive, 'w') as bundle:
            bundle.writestr('dependency_1.0.0/info.json', json.dumps(info))
        stored = dispatch(self.repo, 'import', {'path':str(archive), 'run_id':self.run_id})
        dependencies = self.repo / 'dependency-selection'
        dependencies.mkdir()
        lock = dependencies / 'dependency-lock-2.1.json'
        lock.write_text(json.dumps([{'file':archive.name, 'name':'dependency', 'sha256':stored['sha256'], 'info':info}]))
        profile_dir = self.repo / '.codex/esir'
        profile_dir.mkdir(parents=True)
        (profile_dir / 'factorio-development.json').write_text(json.dumps({
            'dependency_seed':'.factorio-qc/dependency-seeds/core',
            'dependency_lock_sha256':hashlib.sha256(lock.read_bytes()).hexdigest(),
            'smoke_save':'.factorio-qc/core-smoke.zip'}))
        for number in range(33):
            source = self.repo / f'exotic-space-industries-remembrance-fixture-{number}'
            source.mkdir()
            (source / 'info.json').write_text(json.dumps({'name':source.name, 'factorio_version':'2.1'}))
        smoke = self.repo / 'accepted-smoke.zip'
        smoke.write_bytes(b'fixture-save')
        with patch.object(sys, 'argv', ['prepare', '--dependencies',str(dependencies), '--smoke',str(smoke)]):
            seed.main()
        output = self.repo / '.factorio-qc/dependency-seeds/core'
        self.assertEqual({p.name for p in output.iterdir()}, {'dependency-lock-2.1.json','mod-list.json'})
        self.assertEqual((output / lock.name).read_bytes(), lock.read_bytes())
        self.assertEqual(len(dispatch(self.repo, 'status', {})['artifacts']), 1)

    def test_portal_frames_survive_render_and_retire_only_after_validation(self):
        from PIL import Image
        spec = importlib.util.spec_from_file_location('portal_adapter_test', SCRIPTS / 'portal-media/portal_media.py')
        portal = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(portal)
        portal.ROOT = self.repo
        portal.OUT = self.repo / 'output/portal-media'
        batch = {'id':'test', 'features':['fixture']}
        style = {'width':32, 'height':32, 'background':'black', 'webp_quality':90, 'webp_method':4}
        (self.repo / 'portal').mkdir()
        portal.write(self.repo / 'portal/style.json', style)
        state = {'capture_fingerprint':'exact', 'capture_root':self.run['scratch_root'],
                 'capture_run_id':self.run_id, 'engine_version':'2.1.fixture', 'captured_at':'fixture'}
        portal.write(portal.state_path(batch), state)
        directory = Path(self.run['scratch_root']) / 'script-output/portal'
        directory.mkdir(parents=True)
        frames = []
        for index, color in enumerate(['red','blue']):
            filename = f'{index}.png'
            Image.new('RGB', (32,32), color).save(directory / filename)
            frames.append({'feature':'fixture', 'path':filename, 'duration_ms':5000, 'tick':index})
        portal.write(directory / 'report.json', {'complete':True, 'connected':True, 'probe':False,
            'frames':frames, 'evidence':{'fixture':{'pass':True}}, 'mods':{}, 'startup_settings':{},
            'resolution':{'width':32,'height':32}, 'scale':1})
        def compose(source, *_):
            with Image.open(source) as image:
                return image.convert('RGB')
        def close(*_, **__):
            dispatch(self.repo, 'close', {'run_id':self.run_id, 'status':'success'})
            return type('Result', (), {'returncode':0, 'stderr':''})()
        with patch.object(portal, 'capture_fingerprint', return_value='exact'), \
             patch.object(portal, 'feature_sources', return_value=[]), \
             patch.object(portal, 'compose', side_effect=compose), \
             patch.object(portal.subprocess, 'run', side_effect=close):
            portal.render(batch, [{'id':'fixture'}], style)
            self.assertTrue((directory / '0.png').exists())
            portal.validate(batch, [{'id':'fixture'}], style)
            self.assertFalse(directory.exists())
            self.assertTrue((portal.OUT / 'test/candidate/fixture.webp').is_file())
            portal.validate(batch, [{'id':'fixture'}], style)
            with self.assertRaisesRegex(ValueError, 'retired'):
                portal.render(batch, [{'id':'fixture'}], style)
            receipt_path = portal.OUT / 'test/candidate/fixture.json'
            receipt = portal.read(receipt_path)
            receipt['source_frames'][0]['sha256'] = 'tampered'
            portal.write(receipt_path, receipt)
            with self.assertRaisesRegex(ValueError, 'frame manifest'):
                portal.validate(batch, [{'id':'fixture'}], style)


if __name__ == '__main__':
    unittest.main()
