"""Exercise real C:/D: managed storage using only new disposable namespaces."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from esir_qc_storage import QCStorage, dispatch, digest, is_link, plain, within


def main():
    if os.name != 'nt' or not Path('D:/').exists():
        raise RuntimeError('This integration check requires Windows with C: and D: available.')
    temporary_parent = plain(tempfile.gettempdir())
    fixture = temporary_parent / ('esir-qc-overflow-' + uuid.uuid4().hex)
    if fixture.drive.lower() != 'c:':
        raise RuntimeError('The test requires its temporary source repository on C:.')
    fixture.mkdir()
    overflow = None
    success = False
    try:
        dispatch(fixture, 'configure', {'reserve_bytes': 0, 'default_estimate_bytes': 0})
        storage = QCStorage(fixture)
        overflow = storage._overflow()
        if overflow.exists():
            raise RuntimeError('Unique test overflow namespace unexpectedly exists; do not adopt it.')
        moved = dispatch(fixture, 'relocate')
        assert Path(moved['store_root']).drive.lower() == 'd:'

        source = fixture / 'source-fixture'
        source.mkdir()
        (source / 'info.json').write_text(json.dumps({'name': 'source-fixture', 'version': '1.0.0', 'factorio_version': '2.1'}))
        (source / 'control.lua').write_text('-- Original authoritative source.\n')
        (source / 'thumbnail.png').write_bytes(b'standalone immutable media')
        (source / 'graphics').mkdir()
        (source / 'graphics/icon.png').write_bytes(b'immutable directory media')
        original_control = digest(source / 'control.lua')
        media_identity = (source / 'thumbnail.png').stat().st_dev, (source / 'thumbnail.png').stat().st_ino
        archive = fixture / 'dependency-fixture_1.0.0.zip'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
            output.writestr('dependency-fixture_1.0.0/info.json', json.dumps({'name': 'dependency-fixture', 'version': '1.0.0', 'factorio_version': '2.1'}))
            output.writestr('dependency-fixture_1.0.0/data.lua', '-- Immutable dependency.\n')
        artifact = dispatch(fixture, 'import', {'path': str(archive), 'consume': True,
                                              'temporary_root': str(fixture), 'profile': 'overflow-test'})
        assert not archive.exists()
        assert Path(artifact['path']).drive.lower() == 'd:'
        runners = [('entity-presentation/isolate-runtime.py', 'zzz-esir-entity-presentation-qc'),
                   ('machine-status-lights/isolate.py', 'zzz-esir-machine-lights-qc')]
        for script, helper_name in runners:
            run_id = uuid.uuid4().hex
            dispatch(fixture, 'open', {'run_id': run_id, 'workflow': 'overflow-test', 'source_mode': 'private-mutable',
                                      'evidence_root': str(fixture / '.factorio-qc/managed' / run_id)})
            run = dispatch(fixture, 'stage', {'run_id': run_id, 'packages': [artifact['sha256']], 'sources': [{'path': str(source)}]})
            mods, backing = Path(run['mod_view_root']), Path(run['private_root'])
            assert mods.drive.lower() == 'd:' and backing.drive.lower() == 'c:'
            actual = Path(dispatch(fixture, 'mutable-sources', {'run_id': run_id})['names']['source-fixture'])
            assert is_link(mods / 'source-fixture') and actual == backing / 'source-fixture'
            assert (actual / 'control.lua').stat().st_nlink == 1
            assert ((actual / 'thumbnail.png').stat().st_dev, (actual / 'thumbnail.png').stat().st_ino) == media_identity
            package_view = mods / 'dependency-fixture_1.0.0.zip'
            assert package_view.stat().st_ino == Path(artifact['path']).stat().st_ino
            helper = mods / helper_name
            helper.mkdir()
            (helper / 'info.json').write_text('{}')
            completed = subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/qc' / script), str(mods),
                                        '--repo', str(fixture), '--run-id', run_id], capture_output=True, text=True)
            if completed.returncode:
                raise RuntimeError(completed.stderr or completed.stdout)
            assert digest(source / 'control.lua') == original_control
            assert digest(actual / 'control.lua') != original_control
            assert dispatch(fixture, 'validate', {'run_id': run_id})['valid']
            result = dispatch(fixture, 'close', {'run_id': run_id, 'status': 'success'})
            assert result['closed'] and not backing.exists() and not Path(run['view_root']).exists()
            assert not Path(run['scratch_root']).exists()
        dispatch(fixture, 'profile', {'name': 'overflow-test', 'packages': []})
        dispatch(fixture, 'collect', {'apply': True})
        assert dispatch(fixture, 'status')['artifacts'] == []
        with QCStorage(fixture).locked() as storage:
            store_root = Path(storage.state['store_root'])
            assert store_root == overflow / 'store'
            storage._delete_owned(store_root, 'store', storage.state['store_id'])
        assert overflow.parent == Path('D:/ESIR/qc')
        overflow.rmdir()
        success = True
        print(json.dumps({'passed': True, 'source_volume': 'C:', 'store_and_view_volume': 'D:',
                          'private_backing_volume': 'C:', 'isolation_runners': 2, 'unique_standalone_media_files': 1,
                          'extra_media_payload_bytes': 0, 'source_unchanged': True,
                          'views_scratch_backings_and_unused_packages_remaining': 0}))
    finally:
        if success:
            assert fixture.parent == temporary_parent and fixture.name.startswith('esir-qc-overflow-')
            for folder, dirs, files in os.walk(fixture, followlinks=False):
                if any(is_link(Path(folder) / name) for name in dirs + files):
                    raise RuntimeError('Test cleanup found an unexpected remaining link; preserve fixture.')
            shutil.rmtree(fixture)
        else:
            print(json.dumps({'protected_test_fixture': str(fixture), 'overflow': str(overflow) if overflow else None}), file=sys.stderr)


if __name__ == '__main__':
    main()
