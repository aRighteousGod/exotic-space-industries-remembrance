"""Owned, content-addressed QC storage. JSON CLI and importable dispatch entrypoint.

Only paths created and recorded by this module are disposable. Historical outputs,
installed mods and source trees are never adopted as disposable storage.
"""
from __future__ import annotations

import argparse
import base64
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time
import uuid
import zipfile

GIB = 1024 ** 3
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.ogg', '.wav', '.flac', '.mp3', '.dds', '.svg'}
REPORTS = {'.json', '.txt', '.log', '.ini', '.cfg', '.lua', '.md', '.csv', '.ps1', '.py'}
EXCLUDED = {'.git', '.factorio-qc', '.qc', '__pycache__', 'dist', 'tests', 'node_modules'}


class StorageError(RuntimeError):
    pass


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def absolute(path):
    return Path(os.path.abspath(path))


def native(path):
    value = str(absolute(path))
    if os.name == 'nt' and not value.startswith('\\\\?\\'):
        return '\\\\?\\UNC\\' + value[2:] if value.startswith('\\\\') else '\\\\?\\' + value
    return value


def hardlink(source, destination):
    os.link(native(source), native(destination))


def within(path, root):
    try:
        absolute(path).relative_to(absolute(root))
        return True
    except ValueError:
        return False


def is_link(path):
    try:
        info = Path(path).lstat()
        return stat.S_ISLNK(info.st_mode) or bool(getattr(info, 'st_file_attributes', 0) & 0x400)
    except FileNotFoundError:
        return False


def plain(path):
    """Do not resolve through even an ancestor reparse point."""
    path = absolute(path)
    for component in (path, *path.parents):
        if is_link(component):
            raise StorageError(f'Reparse point is outside managed ownership: {component}')
    return path


def atomic_json(path, value):
    path = plain(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def read_json(path):
    return json.loads(plain(path).read_text(encoding='utf-8-sig'))


def identity(path):
    info = Path(path).stat(follow_symlinks=False)
    return [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns]


def same_volume(first, second):
    return Path(first).stat().st_dev == Path(second).stat().st_dev


def tree_files(root):
    root = plain(root)
    for folder, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDED)
        for name in dirs:
            if is_link(Path(folder) / name):
                raise StorageError(f'Unexpected source link: {Path(folder) / name}')
        for name in sorted(files):
            path = plain(Path(folder) / name)
            yield path


def fingerprint(root):
    return {str(p.relative_to(root)).replace('\\', '/'): {'identity': identity(p), 'sha256': digest(p)}
            for p in tree_files(root)}


def junction(path, target):
    if path.exists() or is_link(path):
        raise StorageError(f'Link destination already exists: {path}')
    if os.name == 'nt':
        environment = os.environ.copy()
        environment.update(ESIR_QC_LINK=str(path), ESIR_QC_TARGET=str(target))
        subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-Command',
                        "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path $env:ESIR_QC_LINK -Target $env:ESIR_QC_TARGET | Out-Null"],
                       env=environment, check=True, capture_output=True)
    else:
        path.symlink_to(target, target_is_directory=True)


def unlink_directory_link(path):
    if not is_link(path):
        raise StorageError(f'Expected owned directory link: {path}')
    if os.name == 'nt' and not path.is_symlink():
        os.rmdir(path)  # Removes the junction itself, never its target.
    else:
        path.unlink()


class QCStorage:
    def __init__(self, repo):
        self.repo = plain(repo)
        if not self.repo.is_dir():
            raise StorageError('Repository root does not exist.')
        self.metadata = plain(self.repo / '.factorio-qc/storage')
        self.state_path = self.metadata / 'state.json'
        self.state = None

    @contextlib.contextmanager
    def locked(self):
        self.metadata.mkdir(parents=True, exist_ok=True)
        lock_path = plain(self.metadata / 'storage.lock')
        with lock_path.open('a+b') as stream:
            if os.fstat(stream.fileno()).st_size == 0:
                stream.write(b'0')
                stream.flush()
            start = time.monotonic()
            while True:
                try:
                    stream.seek(0)
                    if os.name == 'nt':
                        import msvcrt
                        msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
                    else:
                        import fcntl
                        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError:
                    if time.monotonic() - start > 30:
                        raise StorageError('QC storage is busy; retry after the current operation.')
                    time.sleep(.1)
            try:
                if self.state_path.exists():
                    self.state = read_json(self.state_path)
                    if self.state.get('schema') != 1 or self.state.get('repo') != str(self.repo):
                        raise StorageError('Storage registry identity mismatch.')
                else:
                    if any(p.name != 'storage.lock' for p in self.metadata.iterdir()):
                        raise StorageError('Unclassified storage directory cannot be adopted.')
                    self.state = {'schema': 1, 'repo': str(self.repo), 'store_id': uuid.uuid4().hex,
                                  'store_root': str(self.metadata / 'payload'), 'artifacts': {}, 'runs': {},
                                  'profiles': {}, 'peaks': {}, 'reserve_bytes': 10 * GIB,
                                  'default_estimate_bytes': 20 * GIB, 'migration': None}
                    self._create_owned(Path(self.state['store_root']), 'store', self.state['store_id'])
                    self.save()
                self._assert_owned(Path(self.state['store_root']), 'store', self.state['store_id'])
                yield self
            finally:
                stream.seek(0)
                if os.name == 'nt':
                    import msvcrt
                    msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(stream, fcntl.LOCK_UN)

    def save(self):
        atomic_json(self.state_path, self.state)

    def _create_owned(self, path, role, owner):
        path = plain(path)
        if path.exists():
            raise StorageError(f'Only absent directories can become managed {role}: {path}')
        path.mkdir(parents=True)
        atomic_json(path / '.esir-owner.json', {'store_id': self.state['store_id'], 'role': role, 'owner': owner})

    def _assert_owned(self, path, role, owner):
        path = plain(path)
        expected = {'store_id': self.state['store_id'], 'role': role, 'owner': owner}
        if read_json(path / '.esir-owner.json') != expected:
            raise StorageError(f'Ownership mismatch: {path}')
        return path

    def _overflow(self):
        # A stable separate namespace avoids collisions with historical ESIR output.
        return Path('D:/ESIR/qc') / hashlib.sha256(str(self.repo).lower().encode()).hexdigest()[:12]

    def _free(self, path):
        cursor = plain(path)
        while not cursor.exists():
            if cursor.parent == cursor:
                raise StorageError(f'Volume is unavailable: {path}')
            cursor = cursor.parent
        return shutil.disk_usage(cursor).free

    def _fits(self, path, growth):
        return self._free(path) >= growth + self.state['reserve_bytes']

    def _run(self, run_id):
        if run_id not in self.state['runs']:
            raise StorageError(f'Unknown managed run: {run_id}')
        return self.state['runs'][run_id]

    def _artifact(self, selected):
        if isinstance(selected, str):
            key = selected
        elif selected.get('path'):
            return self.import_archive(selected)
        else:
            key = selected.get('sha256')
        if key not in self.state['artifacts']:
            raise StorageError(f'Exact package hash is unavailable: {key}')
        artifact = self.state['artifacts'][key]
        path = plain(Path(self.state['store_root']) / artifact['file'])
        if digest(path) != key:
            raise StorageError(f'Canonical archive changed: {path}')
        if isinstance(selected, dict):
            for field in ('name', 'version', 'factorio_version'):
                if selected.get(field) and str(selected[field]) != artifact[field]:
                    raise StorageError(f'Archive {field} disagrees with lock: {path}')
        return {**artifact, 'path': str(path)}

    def import_archive(self, data):
        source = plain(data['path'])
        if not source.is_file():
            raise StorageError(f'Package input is missing: {source}')
        sha = digest(source)
        if data.get('sha256') and sha != data['sha256']:
            raise StorageError(f'Archive hash disagrees with lock: {source}')
        with zipfile.ZipFile(source) as archive:
            infos = [n for n in archive.namelist() if n.count('/') == 1 and n.endswith('/info.json')]
            if len(infos) != 1:
                raise StorageError(f'Archive must contain one mod-root info.json: {source}')
            info = json.loads(archive.read(infos[0]).decode('utf-8-sig'))
        for field in ('name', 'version', 'factorio_version'):
            if not info.get(field) or not re.fullmatch(r'[A-Za-z0-9_. -]+', str(info[field])):
                raise StorageError(f'Invalid archive {field}: {source}')
            if data.get(field) and str(data[field]) != str(info[field]):
                raise StorageError(f'Archive {field} disagrees with lock: {source}')
        consume = bool(data.get('consume'))
        if consume:
            if not data.get('temporary_root') or not within(source, plain(data['temporary_root'])):
                raise StorageError('Consuming an import requires its explicit caller-owned temporary_root.')
            if within(source, self.repo / '.git') or (source.parent / 'info.json').exists():
                raise StorageError('Source or Git files cannot be consumed.')
        if sha not in self.state['artifacts']:
            if not self._fits(Path(self.state['store_root']), source.stat().st_size):
                self.relocate({})
            store = self._assert_owned(Path(self.state['store_root']), 'store', self.state['store_id'])
            destination = store / 'objects' / (sha + '.zip')
            plain(destination).parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                raise StorageError('Unregistered canonical object exists; review interrupted import.')
            temporary = destination.parent / ('.import-' + uuid.uuid4().hex)
            try:
                # Import may copy across volumes; run views never do. The temporary
                # source is consumed only after canonical publication and verification.
                if source.stat().st_dev == destination.parent.stat().st_dev:
                    hardlink(source, temporary)
                else:
                    shutil.copyfile(source, temporary)
                if digest(temporary) != sha:
                    raise StorageError('Imported archive verification failed.')
                os.replace(temporary, destination)
            finally:
                if temporary.exists():
                    temporary.unlink()
            self.state['artifacts'][sha] = {field: str(info[field]) for field in ('name', 'version', 'factorio_version')}
            self.state['artifacts'][sha].update(sha256=sha, bytes=source.stat().st_size,
                                               file='objects/' + sha + '.zip')
            self.save()
        for field in ('source_fingerprint', 'packaging_version'):
            if data.get(field):
                self.state['artifacts'][sha][field] = str(data[field])
        result = self._artifact(sha)
        if data.get('profile'):
            profile = str(data['profile'])
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', profile):
                raise StorageError('Invalid import profile name.')
            references = self.state['profiles'].setdefault(profile, [])
            if sha not in references:
                references.append(sha)
        if data.get('run_id'):
            run = self._run(data['run_id'])
            if run['closed']:
                raise StorageError('Cannot attach a package to a closed run.')
            if sha not in run['packages']:
                run['packages'].append(sha)
        self.save()
        if consume and source != Path(result['path']):
            if digest(source) != sha:
                raise StorageError('Temporary import changed before consumption.')
            source.unlink()
        return result

    def profile(self, data):
        name = data['name']
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
            raise StorageError('Invalid profile name.')
        artifacts = [self._artifact(p) for p in data.get('packages', [])]
        self.state['profiles'][name] = [a['sha256'] for a in artifacts]
        self.save()
        return {'name': name, 'packages': artifacts}

    def open_run(self, data):
        run_id = data['run_id']
        if not re.fullmatch(r'[A-Za-z0-9_-]{8,64}', run_id):
            raise StorageError('Invalid managed run ID.')
        mode = data.get('source_mode')
        if mode not in ('read-only', 'private-mutable'):
            raise StorageError('Declare source_mode: read-only or private-mutable.')
        evidence = plain(data['evidence_root'])
        if not within(evidence, self.repo / '.factorio-qc') and not within(evidence, self.repo / 'output'):
            raise StorageError('Evidence root must be a new registered repository output directory.')
        if run_id in self.state['runs']:
            run = self._run(run_id)
            if run['closed'] or any(run[k] != value for k, value in (
                    ('source_mode', mode), ('evidence_root', str(evidence)), ('workflow', data['workflow']))):
                raise StorageError('Existing run identity differs or has closed.')
            self._assert_owned(evidence, 'evidence', run_id)
            return run
        if evidence.exists() and any(evidence.iterdir()):
            raise StorageError('Existing evidence content cannot be adopted by a new storage run.')
        estimate = data.get('estimate_bytes')
        if estimate is None:
            previous = self.state['peaks'].get(data['workflow'])
            estimate = int(previous * 1.25) if previous else self.state['default_estimate_bytes']
        if int(estimate) < 0:
            raise StorageError('Scratch estimate cannot be negative.')
        scratch = self.repo / '.factorio-qc/scratch' / run_id
        if not self._fits(scratch, int(estimate)):
            scratch = self._overflow() / 'scratch' / run_id
            if not self._fits(scratch, int(estimate)):
                raise StorageError('Neither C: nor D: has the scratch estimate plus free-space reserve.')
        store = Path(self.state['store_root'])
        # Keep Factorio Lua require paths short. Ownership still uses the full ID.
        view = (self.repo / '.factorio-qc' if store.drive.lower() == self.repo.drive.lower()
                else store.parent) / ('v' + hashlib.sha256(run_id.encode()).hexdigest()[:12])
        self._create_owned(view, 'view', run_id)
        try:
            self._create_owned(scratch, 'scratch', run_id)
        except Exception:
            (view / '.esir-owner.json').unlink()
            view.rmdir()
            raise
        if evidence.exists():
            if any(evidence.iterdir()):
                raise StorageError('Existing evidence content cannot be adopted by a new storage run.')
            atomic_json(evidence / '.esir-owner.json', {'store_id': self.state['store_id'], 'role': 'evidence', 'owner': run_id})
        else:
            self._create_owned(evidence, 'evidence', run_id)
        run = {'run_id': run_id, 'workflow': data['workflow'], 'source_mode': mode,
               'store_root': str(store), 'mod_view_root': str(view / 'mods'), 'view_root': str(view),
               'scratch_root': str(scratch), 'evidence_root': str(evidence), 'packages': [],
               'sources': [], 'links': {}, 'view_files': {}, 'pins': [], 'closed': False,
               'private_root': None, 'private_links': {},
               'view_released': False, 'staged': False, 'estimate_bytes': int(estimate)}
        self.state['runs'][run_id] = run
        self.save()
        return run

    def _private_source(self, source, target, links):
        target.mkdir()
        # Whole media directories can be shared across volumes by junction. All
        # code/settings remain private even if a fixture later opens them in-place.
        def copy_tree(origin, destination):
            for entry in sorted(origin.iterdir()):
                if entry.name in EXCLUDED:
                    continue
                plain(entry)
                output = destination / entry.name
                if entry.is_dir():
                    files = list(tree_files(entry)) if entry.name in ('graphics', 'sounds') else []
                    if files and all(p.suffix.lower() in MEDIA | {'.txt', '.md', '.json'} for p in files):
                        junction(output, entry)
                        links[str(output)] = str(entry)
                    else:
                        output.mkdir()
                        copy_tree(entry, output)
                elif entry.suffix.lower() in MEDIA:
                    try:
                        hardlink(entry, output)
                    except OSError as error:
                        raise StorageError(f'Cannot share immutable media across volumes: {entry}; use a directory media view.') from error
                else:
                    shutil.copyfile(entry, output)
        copy_tree(source, target)

    def stage(self, data):
        run = self._run(data['run_id'])
        if run['closed']:
            raise StorageError('Cannot stage a closed run.')
        if run['staged'] and not run['view_released']:
            signature = hashlib.sha256(json.dumps({k: data.get(k) for k in ('packages', 'sources', 'settings_path', 'mod_list')}, sort_keys=True).encode()).hexdigest()
            if signature != run.get('stage_signature'):
                raise StorageError('Existing view has a different selection; release it before restaging.')
            self.validate({'run_id': run['run_id']})
            return run
        if run['view_released']:
            self._create_owned(Path(run['view_root']), 'view', run['run_id'])
            run.update(view_released=False, links={}, view_files={})
        artifacts = [self._artifact(p) for p in data.get('packages', [])]
        # An initial import may move an otherwise empty store/view to overflow.
        # Obtain the final view path only after those imports have finished.
        mods = plain(run['mod_view_root'])
        mods.mkdir(exist_ok=False)
        sources = data.get('sources', [])
        names = set()
        run['packages'] = [p['sha256'] for p in artifacts]
        run['sources'] = []
        self.save()  # Imports are leased before any link is exposed to an engine.
        try:
            source_names = {s.get('name') or read_json(Path(s['path']) / 'info.json')['name'] for s in sources}
            for artifact in artifacts:
                if artifact['name'] in source_names:
                    continue
                if artifact['name'] in names:
                    raise StorageError('A mod selection contains multiple versions of the same mod.')
                names.add(artifact['name'])
                target = mods / f"{artifact['name']}_{artifact['version']}.zip"
                try:
                    hardlink(artifact['path'], target)
                except OSError as error:
                    raise StorageError(f'Hardlink failed; no copy fallback is permitted: {artifact["path"]} -> {target}') from error
            for descriptor in sources:
                source = plain(descriptor['path'])
                info = read_json(source / 'info.json')
                name = descriptor.get('name', info['name'])
                if name != info['name'] or name in names or not re.fullmatch(r'[A-Za-z0-9_. -]+', name):
                    raise StorageError('Invalid or duplicate source mod identity.')
                names.add(name)
                mode = descriptor.get('mode', run['source_mode'])
                if mode not in ('read-only', 'private-mutable'):
                    raise StorageError('Invalid source staging mode.')
                source_row = {'path': str(source), 'name': name, 'mode': mode, 'fingerprint': fingerprint(source)}
                run['sources'].append(source_row)
                target = mods / name
                if mode == 'read-only':
                    junction(target, source)
                    run['links'][str(target)] = str(source)
                else:
                    if same_volume(source, mods):
                        self._private_source(source, target, run['links'])
                    else:
                        # A mutable C: source can still share standalone media
                        # when the ZIP store lives on D:. Its small private code
                        # backing stays on C:, then the mod view junctions it.
                        if not same_volume(source, self.repo):
                            raise StorageError('Private source backing requires the repository/source volume; do not copy media across volumes.')
                        if not run.get('private_root'):
                            backing_root = self.repo / '.factorio-qc' / ('p' + hashlib.sha256(run['run_id'].encode()).hexdigest()[:12])
                            self._create_owned(backing_root, 'private-source', run['run_id'])
                            run['private_root'] = str(backing_root)
                            run['private_links'] = {}
                            self.save()
                        backing = Path(run['private_root']) / name
                        self._private_source(source, backing, run['private_links'])
                        junction(target, backing)
                        run['links'][str(target)] = str(backing)
                self.save()
            selection = data.get('mod_list')
            if selection is None:
                selection = {'mods': [{'name': 'base', 'enabled': True}] +
                             [{'name': n, 'enabled': True} for n in sorted(names)]}
            atomic_json(mods / 'mod-list.json', selection)
            if data.get('settings_path'):
                shutil.copyfile(plain(data['settings_path']), mods / 'mod-settings.dat')
            run['staged'] = True
            run['stage_signature'] = hashlib.sha256(json.dumps({k: data.get(k) for k in ('packages', 'sources', 'settings_path', 'mod_list')}, sort_keys=True).encode()).hexdigest()
            run['view_files'] = self._inventory(Path(run['view_root']), run['links'])
            self.save()
            return run
        except Exception:
            # Persist exactly created links so an interrupted stage is reviewable.
            run['stage_error'] = str(sys.exc_info()[1])
            self.save()
            raise

    def validate(self, data):
        run = self._run(data['run_id'])
        for key in run['packages']:
            self._artifact(key)
        for source in run['sources']:
            root = plain(source['path'])
            current_paths = {str(p.relative_to(root)).replace('\\', '/'): p for p in tree_files(root)}
            if set(current_paths) != set(source['fingerprint']):
                raise StorageError(f'Source file selection changed during QC: {root}')
            for relative, recorded in source['fingerprint'].items():
                current = current_paths[relative]
                if identity(current) != recorded['identity'] or digest(current) != recorded['sha256']:
                    raise StorageError(f'Source changed during QC: {current}')
        return {'valid': True, 'run_id': run['run_id'], 'run': run}

    def mutable_sources(self, data):
        run = self._run(data['run_id'])
        if run['closed'] or run['view_released'] or not run['staged']:
            raise StorageError('Mutable source resolution requires an active staged view.')
        self._assert_owned(Path(run['view_root']), 'view', run['run_id'])
        names = {}
        for source in run['sources']:
            if source['mode'] != 'private-mutable':
                continue
            view = Path(run['mod_view_root']) / source['name']
            if is_link(view):
                if not run.get('private_root'):
                    raise StorageError('Mutable source link has no owned private backing.')
                backing_root = self._assert_owned(Path(run['private_root']), 'private-source', run['run_id'])
                expected = backing_root / source['name']
                if run['links'].get(str(view)) != str(expected) or view.resolve() != expected.resolve():
                    raise StorageError('Mutable source view no longer points to its owned backing.')
                names[source['name']] = str(plain(expected))
            else:
                names[source['name']] = str(plain(view))
        return {'names': names}

    def _inventory(self, root, links=None):
        links = links or {}
        inventory = {}
        for folder, dirs, files in os.walk(plain(root), followlinks=False):
            for name in list(dirs):
                path = Path(folder) / name
                if is_link(path):
                    if str(path) not in links or path.resolve() != Path(links[str(path)]).resolve():
                        raise StorageError(f'Unowned or retargeted link: {path}')
                    dirs.remove(name)
            for name in files:
                path = plain(Path(folder) / name)
                inventory[str(path)] = identity(path)
        return inventory

    def _exclusive(self, inventory):
        # Preflight all leaf handles before modifying anything. On Windows an
        # exclusive read detects open engine output and prevents partial cleanup.
        for path in inventory:
            if getattr(Path(path).stat(follow_symlinks=False), 'st_file_attributes', 0) & 1:
                raise StorageError(f'Owned output is read-only; shared attributes remain unchanged: {path}')
        handles = []
        try:
            if os.name == 'nt':
                import ctypes
                from ctypes import wintypes
                kernel = ctypes.WinDLL('kernel32', use_last_error=True)
                kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                    wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
                kernel.CreateFileW.restype = wintypes.HANDLE
                kernel.CloseHandle.argtypes = [wintypes.HANDLE]
                kernel.CloseHandle.restype = wintypes.BOOL
                checked_files = set()
                for path in inventory:
                    physical = tuple(inventory[path][:2])
                    if physical in checked_files:
                        continue
                    handle = kernel.CreateFileW(native(path), 0x80000000, 0, None, 3, 0x80, None)
                    last_error = ctypes.get_last_error()
                    deadline = time.monotonic() + 2
                    while handle == wintypes.HANDLE(-1).value and last_error in (32, 33) and time.monotonic() < deadline:
                        time.sleep(.05)
                        handle = kernel.CreateFileW(native(path), 0x80000000, 0, None, 3, 0x80, None)
                        last_error = ctypes.get_last_error()
                    if handle == wintypes.HANDLE(-1).value:
                        raise StorageError(f'Owned output is locked or inaccessible (Win32 {last_error}): {path}')
                    handles.append(handle)
                    checked_files.add(physical)
        finally:
            if os.name == 'nt':
                for handle in handles:
                    kernel.CloseHandle(wintypes.HANDLE(handle))

    def _delete_owned(self, root, role, run_id, links=None, expected=None):
        root = self._assert_owned(root, role, run_id)
        inventory = self._inventory(root, links)
        if expected is not None and inventory != expected:
            raise StorageError(f'Owned output changed after evidence verification: {root}')
        self._exclusive(inventory)
        for link, target in sorted((links or {}).items(), key=lambda row: len(row[0]), reverse=True):
            path = Path(link)
            if not within(path, root) or not is_link(path) or path.resolve() != Path(target).resolve():
                raise StorageError(f'Owned link changed before teardown: {path}')
            unlink_directory_link(path)
        marker = root / '.esir-owner.json'
        # Keep the ownership marker until all other leaves and directories retire.
        for path, recorded in inventory.items():
            if Path(path) == marker:
                continue
            path = plain(path)
            if identity(path) != recorded:
                raise StorageError(f'Owned output changed during cleanup: {path}')
            path.unlink()  # No attribute changes: a leaf may be a shared hardlink.
        for folder, dirs, files in os.walk(root, topdown=False, followlinks=False):
            for name in dirs:
                plain(Path(folder) / name).rmdir()
        if identity(marker) != inventory[str(marker)]:
            raise StorageError(f'Ownership marker changed during cleanup: {marker}')
        marker.unlink()
        root.rmdir()
        return sum(row[2] for row in inventory.values())

    def release(self, data):
        run = self._run(data['run_id'])
        if run['view_released'] and not run.get('private_root'):
            return run
        self.validate(data)
        # Preserve the small private fixture delta and effective settings before
        # removing its view. Immutable archives/media remain referenced by hash.
        mods = Path(run['mod_view_root'])
        changed = {}
        inventory = self._inventory(Path(run['view_root']), run['links']) if not run['view_released'] else {}
        candidates = [(Path(filename), Path(filename).relative_to(mods)) for filename in inventory if within(filename, mods)]
        private_inventory = {}
        if run.get('private_root'):
            private_root = Path(run['private_root'])
            private_inventory = self._inventory(private_root, run['private_links'])
            self._exclusive(private_inventory)
            candidates += [(Path(filename), Path(filename).relative_to(private_root)) for filename in private_inventory
                           if Path(filename).name != '.esir-owner.json']
        source_by_name = {s['name']: s for s in run['sources']}
        for file, relative in candidates:
            if file.suffix.lower() in MEDIA | {'.zip'}:
                continue
            source = source_by_name.get(relative.parts[0])
            original = '/'.join(relative.parts[1:])
            if source and original in source['fingerprint'] and digest(file) == source['fingerprint'][original]['sha256']:
                continue
            if file.stat().st_size > 8 * 1024 * 1024:
                raise StorageError(f'Large private fixture input needs explicit retention before release: {file}')
            changed[str(relative).replace('\\', '/')] = base64.b64encode(file.read_bytes()).decode('ascii')
        if changed:
            evidence = self._assert_owned(Path(run['evidence_root']), 'evidence', run['run_id'])
            reproducer = {'encoding': 'base64', 'files': changed}
            if len(json.dumps(reproducer).encode()) > 8 * 1024 * 1024:
                raise StorageError('Private fixture delta exceeds the compact limit; explicitly preserve its reproducer before release.')
            atomic_json(evidence / 'staged-reproducer.json', reproducer)
        if not run['view_released']:
            self._delete_owned(Path(run['view_root']), 'view', run['run_id'], run['links'])
            run['view_released'] = True
            run['links'] = {}
            run['view_files'] = {}
            self.save()
        if run.get('private_root'):
            self._delete_owned(Path(run['private_root']), 'private-source', run['run_id'], run['private_links'], expected=private_inventory)
            run['private_root'] = None
            run['private_links'] = {}
        self.save()
        return run

    def pin(self, data):
        run = self._run(data['run_id'])
        reason = str(data.get('reason', '')).strip()
        if not reason:
            raise StorageError('A retention pin requires a reason.')
        if data.get('pinned', True):
            if reason not in run['pins']:
                run['pins'].append(reason)
        else:
            run['pins'] = [p for p in run['pins'] if p != reason]
        self.save()
        return run

    def close(self, data):
        run = self._run(data['run_id'])
        if run['closed']:
            return run
        if run['pins']:
            raise StorageError('Pinned run must be unpinned before compact closeout.')
        self.release(data)
        scratch = self._assert_owned(Path(run['scratch_root']), 'scratch', run['run_id'])
        evidence = self._assert_owned(Path(run['evidence_root']), 'evidence', run['run_id'])
        if run.get('close_pending'):
            pending = run['close_pending']
            archive = evidence / 'evidence.zip'
            index_path = evidence / 'evidence-index.json'
            if digest(index_path) != pending['index_sha256'] or digest(archive) != pending['archive_sha256']:
                raise StorageError('Pending closeout evidence changed; preserve it for review.')
            index = read_json(index_path)
            if index['run_id'] != run['run_id']:
                raise StorageError('Pending closeout belongs to another run.')
            return self._finish_close(run, index, pending['inventory'], pending['small_evidence'])
        retained = [plain(p) for p in data.get('retain', data.get('retained_paths', []))]
        inventory = self._inventory(scratch)
        small = []
        for root in (scratch, evidence):
            for file in tree_files(root):
                if file.name in ('evidence.zip', 'evidence-index.json', '.esir-owner.json'):
                    continue
                if file.name == 'data-raw-dump.json' or file.suffix.lower() not in REPORTS:
                    continue
                if file.stat().st_size <= 8 * 1024 * 1024:
                    small.append((file, ('scratch/' if root == scratch else 'reports/') + str(file.relative_to(root)).replace('\\', '/')))
        external = []
        for file in retained:
            if not file.is_file():
                raise StorageError(f'Retained evidence is missing: {file}')
            if file.name == 'data-raw-dump.json':
                raise StorageError('Retaining a raw dump requires a reasoned run pin; keep the run open until its dump consumer finishes.')
            if within(file, scratch):
                # Required saves/captures are moved to the durable destination.
                destination = evidence / 'selected' / file.relative_to(scratch)
                plain(destination).parent.mkdir(parents=True, exist_ok=True)
                if destination.exists():
                    raise StorageError(f'Selected evidence destination exists: {destination}')
                source_hash = digest(file)
                if file.stat().st_dev == destination.parent.stat().st_dev:
                    hardlink(file, destination)
                else:
                    shutil.copyfile(file, destination)
                if digest(destination) != source_hash:
                    raise StorageError('Selected evidence verification failed.')
                external.append({'path': str(destination), 'sha256': source_hash, 'bytes': file.stat().st_size})
            else:
                external.append({'path': str(file), 'sha256': digest(file), 'bytes': file.stat().st_size})
        index = {'run_id': run['run_id'], 'workflow': run['workflow'], 'status': data.get('status', 'completed'),
                 'reason': data.get('reason'), 'packages': run['packages'], 'source_mode': run['source_mode'],
                 'sources': [{'path': s['path'], 'name': s['name'], 'mode': s['mode'],
                              'fingerprint_sha256': hashlib.sha256(json.dumps(s['fingerprint'], sort_keys=True).encode()).hexdigest()}
                             for s in run['sources']], 'external_evidence': external, 'entries': []}
        archive = evidence / 'evidence.zip'
        temporary = evidence / ('evidence-' + uuid.uuid4().hex + '.partial')
        if archive.exists() or (evidence / 'evidence-index.json').exists():
            raise StorageError('Evidence closeout already started; preserve it for recovery.')
        with zipfile.ZipFile(temporary, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
            for path, name in small:
                output.write(path, name)
                index['entries'].append({'name': name, 'sha256': digest(path), 'bytes': path.stat().st_size})
            output.writestr('reproduction-inputs.json', json.dumps({'sources': run['sources'], 'packages': run['packages']}, separators=(',', ':')))
        with zipfile.ZipFile(temporary) as check:
            if check.testzip() is not None:
                raise StorageError('Compact evidence ZIP failed verification.')
            for entry in index['entries']:
                if hashlib.sha256(check.read(entry['name'])).hexdigest() != entry['sha256']:
                    raise StorageError('Compact evidence content changed during closeout.')
        os.replace(temporary, archive)
        index['archive_sha256'] = digest(archive)
        atomic_json(evidence / 'evidence-index.json', index)
        small_evidence = [{'path': str(file), 'sha256': next(e['sha256'] for e in index['entries'] if e['name'] == name)}
                          for file, name in small if within(file, evidence)]
        run['close_pending'] = {'inventory': inventory, 'small_evidence': small_evidence,
                                'archive_sha256': index['archive_sha256'], 'index_sha256': digest(evidence / 'evidence-index.json')}
        self.save()
        return self._finish_close(run, index, inventory, small_evidence)

    def _finish_close(self, run, index, inventory, small_evidence):
        scratch = Path(run['scratch_root'])
        evidence = Path(run['evidence_root'])
        total = self._delete_owned(scratch, 'scratch', run['run_id'], expected=inventory)
        for entry in small_evidence:
            file = plain(entry['path'])
            if not within(file, evidence) or digest(file) != entry['sha256']:
                raise StorageError(f'Evidence changed after bundling: {file}')
            file.unlink()
        archive = evidence / 'evidence.zip'
        run.update(closed=True, status=index['status'], evidence_archive=str(archive), evidence_index=str(evidence / 'evidence-index.json'))
        run.pop('close_pending', None)
        self.state['peaks'][run['workflow']] = total
        # Fingerprints now exist once inside compact evidence, not duplicated in registry.
        run['sources'] = index['sources']
        self.save()
        run['collection'] = self.collect({'apply': True})
        self.save()
        return run

    def collect(self, data):
        retained = {key for keys in self.state['profiles'].values() for key in keys}
        for run in self.state['runs'].values():
            if not run['closed'] or run['pins']:
                retained.update(run['packages'])
        candidates = [key for key in self.state['artifacts'] if key not in retained]
        result = {'candidates': candidates, 'removed': [], 'protected': []}
        if data.get('apply'):
            for key in candidates:
                try:
                    artifact = self._artifact(key)
                    path = plain(artifact['path'])
                    self._exclusive({str(path): identity(path)})
                    # Never change attributes of a shared imported hardlink.
                    path.unlink()
                    del self.state['artifacts'][key]
                    result['removed'].append(key)
                except (OSError, StorageError) as error:
                    result['protected'].append({'sha256': key, 'reason': str(error)})
            self.save()
        return result

    def relocate(self, data):
        pending = [r for r in self.state['runs'].values() if not r['closed']]
        if any(r['staged'] or r['packages'] or r['pins'] for r in pending):
            raise StorageError('Canonical store overflow requires all active run leases to close first.')
        # A just-opened lease with no materialized input cannot have an engine
        # consumer yet. It may follow the store during the first package import.
        pending_views = []
        for run in pending:
            view = self._assert_owned(Path(run['view_root']), 'view', run['run_id'])
            inventory = self._inventory(view)
            if set(inventory) != {str(view / '.esir-owner.json')}:
                raise StorageError('Unmaterialized run contains unexpected files; relocation is protected.')
            pending_views.append((run, view, inventory))
        old = self._assert_owned(Path(self.state['store_root']), 'store', self.state['store_id'])
        target = self._overflow() / 'store'
        if data.get('target') and absolute(data['target']) != absolute(target):
            raise StorageError('Store relocation target must be the configured D: overflow namespace.')
        if old == target:
            raise StorageError('Overflow store lacks capacity; no second cache will be created.')
        if self.state.get('migration'):
            raise StorageError('Interrupted store migration needs review; the recorded store remains authoritative.')
        growth = sum(a['bytes'] for a in self.state['artifacts'].values())
        if not self._fits(target, growth):
            raise StorageError('D: cannot hold the store plus free-space reserve.')
        self.state['migration'] = {'source': str(old), 'target': str(target), 'phase': 'copying'}
        self.save()
        self._create_owned(target, 'store', self.state['store_id'])
        for key, artifact in self.state['artifacts'].items():
            source = plain(old / artifact['file'])
            destination = plain(target / artifact['file'])
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            if digest(source) != key or digest(destination) != key:
                raise StorageError('Store migration hash verification failed; old store remains authoritative.')
        old_inventory = self._inventory(old)
        known = {str(old / '.esir-owner.json')} | {str(old / a['file']) for a in self.state['artifacts'].values()}
        if set(old_inventory) != known:
            raise StorageError('Unknown files in canonical store; migration remains protected.')
        # Publish the verified target before retirement. A crash can leave a
        # journaled duplicate, but never a pointer to an already-deleted store.
        self.state['migration']['phase'] = 'published'
        self.state['store_root'] = str(target)
        old_views = []
        for run, view, inventory in pending_views:
            new_view = target.parent / view.name
            self._create_owned(new_view, 'view', run['run_id'])
            old_views.append((view, inventory, run['run_id']))
            run.update(store_root=str(target), view_root=str(new_view), mod_view_root=str(new_view / 'mods'))
        self.state['migration']['old_views'] = [str(view) for view, _, _ in old_views]
        self.save()
        self._delete_owned(old, 'store', self.state['store_id'], expected=old_inventory)
        for view, inventory, run_id in old_views:
            self._delete_owned(view, 'view', run_id, expected=inventory)
        self.state['migration'] = None
        self.save()
        return {'store_root': str(target), 'relocated': True}

    def status(self, data):
        if data.get('run_id'):
            return self._run(data['run_id'])
        return {'store_root': self.state['store_root'], 'artifacts': [
            {**a, 'path': str(Path(self.state['store_root']) / a['file'])} for a in self.state['artifacts'].values()],
            'profiles': self.state['profiles'], 'runs': list(self.state['runs'].values()),
            'migration': self.state['migration']}

    def configure(self, data):
        for key in ('reserve_bytes', 'default_estimate_bytes'):
            if key in data:
                if isinstance(data[key], bool) or not isinstance(data[key], int):
                    raise StorageError(f'{key} must be an integer number of bytes.')
                value = int(data[key])
                if value < 0:
                    raise StorageError(f'{key} cannot be negative.')
                self.state[key] = value
        self.save()
        return {key: self.state[key] for key in ('reserve_bytes', 'default_estimate_bytes')}


ALIASES = {'open-run': 'open', 'stage-view': 'stage', 'inspect-run': 'status', 'inspect': 'status',
           'validate-run': 'validate', 'release-view': 'release', 'close-run': 'close',
           'mutable-sources': 'mutable_sources'}


def dispatch(repo, action, data=None):
    action = ALIASES.get(action, action)
    method = {'import': 'import_archive', 'open': 'open_run'}.get(action, action)
    if method not in ('import_archive', 'profile', 'open_run', 'stage', 'validate', 'release', 'close',
                      'pin', 'collect', 'relocate', 'status', 'configure', 'mutable_sources'):
        raise StorageError(f'Unknown storage action: {action}')
    storage = QCStorage(repo)
    if not storage.state_path.exists() and (method == 'status' or (method == 'collect' and not (data or {}).get('apply'))):
        if (data or {}).get('run_id'):
            raise StorageError(f'Unknown managed run: {data["run_id"]}')
        return ({'store_root': None, 'artifacts': [], 'profiles': {}, 'runs': [], 'migration': None}
                if method == 'status' else {'candidates': [], 'removed': [], 'protected': []})
    with storage.locked():
        return getattr(storage, method)(data or {})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--action', required=True)
    arguments = parser.parse_args()
    try:
        payload = json.loads(sys.stdin.read() or '{}')
        print(json.dumps(dispatch(arguments.repo, arguments.action, payload), ensure_ascii=True))
    except Exception as error:
        print(json.dumps({'error': str(error), 'status': 'protected-error'}), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
