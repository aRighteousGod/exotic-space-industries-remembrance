# Repository artifact ownership and retention. Source edits use the normal patch workflow.
# Registry state lives outside payloads; only explicitly closed, verified runs can expire.
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'esir-qc-storage.ps1')

function Test-EsirCompactQcRun {
    param($Run)
    return $Run.PSObject.Properties.Name -contains 'storage_policy' -and $Run.storage_policy -eq 'compact-v1'
}

function Initialize-EsirManagedQcContext {
    param([string]$RepoRoot, $Context, [string]$RunId,
        [Parameter(Mandatory)][ValidateSet('read-only', 'private-mutable')][string]$SourceMode)
    $run = Read-EsirArtifactRun $RepoRoot $RunId
    if ($run.status -ne 'running' -or -not $run.task_open) { throw 'Managed staging requires an open running task.' }
    $evidence = Assert-EsirArtifactTarget $RepoRoot $run.payload_path
    $storage = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action open -Data @{
        run_id = $run.id; evidence_root = $evidence; workflow = $run.workflow; source_mode = $SourceMode
    }
    foreach ($property in @('store_root', 'mod_view_root', 'scratch_root', 'evidence_root')) {
        $Context | Add-Member -NotePropertyName $property -NotePropertyValue $storage.$property -Force
    }
    $Context | Add-Member -NotePropertyName qc_run_id -NotePropertyValue $run.id -Force
    $Context | Add-Member -NotePropertyName source_mode -NotePropertyValue $SourceMode -Force
    $Context.artifact_root = $evidence
    $Context.run_mod_directory = $storage.mod_view_root
    $lock = Enter-EsirHousekeepingLock $RepoRoot
    try {
        $run = Read-EsirArtifactRun $RepoRoot $RunId
        $run | Add-Member -NotePropertyName storage_policy -NotePropertyValue 'compact-v1' -Force
        $roots = @{store_root=$storage.store_root;mod_view_root=$storage.mod_view_root;scratch_root=$storage.scratch_root;evidence_root=$storage.evidence_root;source_mode=$SourceMode}
        $run | Add-Member -NotePropertyName storage_roots -NotePropertyValue $roots -Force
        if ($run.PSObject.Properties.Name -notcontains 'selected_evidence') {
            $run | Add-Member -NotePropertyName selected_evidence -NotePropertyValue @()
            $run | Add-Member -NotePropertyName dump_identity -NotePropertyValue $null
            $run | Add-Member -NotePropertyName cleanup_status -NotePropertyValue 'active'
        }
        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $RunId) $run
    } finally { $lock.Dispose() }
    return $storage
}

function Set-EsirQcSelectedEvidence {
    param([string]$RepoRoot, [string]$RunId, [string[]]$Paths)
    $lock = Enter-EsirHousekeepingLock $RepoRoot
    try {
        $run = Read-EsirArtifactRun $RepoRoot $RunId
        if (-not (Test-EsirCompactQcRun $run) -or -not $run.task_open) { throw 'Selected evidence requires an open managed QC task.' }
        $run.selected_evidence = @(@($run.selected_evidence) + $Paths | Select-Object -Unique)
        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $RunId) $run
    } finally { $lock.Dispose() }
}

function Initialize-EsirHousekeepingNative {
    if ('EsirArtifactFile' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class EsirArtifactFile {
    [StructLayout(LayoutKind.Sequential)] private struct Info {
        public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Created;
        public System.Runtime.InteropServices.ComTypes.FILETIME Accessed;
        public System.Runtime.InteropServices.ComTypes.FILETIME Written;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [DllImport("kernel32.dll", SetLastError=true)] private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out Info info);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] private static extern bool MoveFileEx(string source, string target, uint flags);
    public static string ExtendedPath(string path) {
        path = Path.GetFullPath(path);
        if (path.StartsWith(@"\\?\")) return path;
        return path.StartsWith(@"\\") ? @"\\?\UNC\" + path.Substring(2) : @"\\?\" + path;
    }
    public static void Replace(string source, string target) {
        if (!MoveFileEx(source, target, 1 | 8))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
    public static string Identity(string path, bool exclusive) {
        using (var stream = new FileStream(ExtendedPath(path), FileMode.Open, FileAccess.Read,
            exclusive ? FileShare.None : FileShare.ReadWrite | FileShare.Delete)) {
            Info info;
            if (!GetFileInformationByHandle(stream.SafeFileHandle, out info))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return String.Join(":", info.Volume, info.IndexHigh, info.IndexLow,
                info.SizeHigh, info.SizeLow, info.Written.dwHighDateTime, info.Written.dwLowDateTime);
        }
    }
}
'@
}

function Get-EsirHousekeepingRoot {
    param([string]$RepoRoot)
    return [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
}

function Test-EsirArtifactWithin {
    param([string]$Path, [string]$Parent)
    return $Path.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Parent.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-EsirArtifactPath {
    param([string]$RepoRoot, [string]$Path)
    Initialize-EsirHousekeepingNative
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[*?]' -or $Path -match '(^|[\\/])\.\.([\\/]|$)') { throw "Invalid artifact path: $Path" }
    $root = Get-EsirHousekeepingRoot $RepoRoot
    $full = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }))
    if (-not (Test-EsirArtifactWithin $full $root) -or $full -eq $root -or $full.Substring($root.Length) -match ':') { throw "Artifact is outside the repository: $Path" }
    # Check every component, including repository ancestors. Never resolve through a junction.
    $cursor = $full
    while ($cursor) {
        try {
            if ([IO.File]::GetAttributes([EsirArtifactFile]::ExtendedPath($cursor)) -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point is protected: $cursor" }
        } catch [IO.FileNotFoundException] { } catch [IO.DirectoryNotFoundException] { }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $full
}

function Get-EsirArtifactRelativePath {
    param([string]$RepoRoot, [string]$Path)
    return $Path.Substring((Get-EsirHousekeepingRoot $RepoRoot).Length + 1).Replace('\', '/')
}

function Assert-EsirArtifactTarget {
    param([string]$RepoRoot, [string]$Path, [switch]$Metadata)
    $root = Get-EsirHousekeepingRoot $RepoRoot
    $full = Resolve-EsirArtifactPath $root $Path
    $relative = Get-EsirArtifactRelativePath $root $full
    $parts = $relative.Split('/')
    $allowed = @('.factorio-qc', 'output', 'temp', 'tmp', '.tmp_inspect', 'Render')
    if ($parts.Count -lt 2 -or $parts[0] -notin $allowed) { throw "Not an approved artifact subtree: $relative" }
    $top = Join-Path $root $parts[0]
    if (Test-Path -LiteralPath (Join-Path $top 'info.json')) { throw "Source mod root is protected: $top" }
    if (-not $Metadata) {
        if ($relative -match '^\.factorio-qc/housekeeping(?:/|$)' -or
            $parts -match '^(mods-live|mods-preview|dependency-seed|baseline-source|asset-cache|tesla-run-mods)$') { throw "Shared input or registry is protected: $relative" }
        # Catalog fixtures remain protected even if a later task adds a managed path to the catalog.
        $catalog = Join-Path $root '.codex/esir/save-catalog.json'
        if (Test-Path -LiteralPath $catalog) {
            $data = Get-Content -LiteralPath $catalog -Raw | ConvertFrom-Json
            foreach ($entry in $data.entries) {
                $saved = [IO.Path]::GetFullPath((Join-Path $root $entry.path))
                if ((Test-EsirArtifactWithin $saved $full) -or (Test-EsirArtifactWithin $full $saved)) { throw "Catalog save is protected: $relative" }
            }
        }
    }
    $tracked = @(& git -C $root -c core.quotepath=false ls-files -- $relative)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot establish Git tracking; refusing housekeeping.' }
    if ($tracked.Count -gt 0) { throw "Tracked content is protected: $relative" }
    & git -C $root check-ignore -q -- $relative
    if ($LASTEXITCODE -ne 0) { throw "Artifact path must be ignored: $relative" }
    return $full
}

function Get-EsirHousekeepingStore {
    param([string]$RepoRoot, [switch]$Create)
    $path = Assert-EsirArtifactTarget $RepoRoot '.factorio-qc/housekeeping' -Metadata
    if ($Create) { [void][IO.Directory]::CreateDirectory($path) }
    return $path
}

function Enter-EsirHousekeepingLock {
    param([string]$RepoRoot)
    $store = Get-EsirHousekeepingStore $RepoRoot -Create
    $path = Resolve-EsirArtifactPath $RepoRoot (Join-Path $store 'registry.lock')
    # FileShare.None serializes registry changes, closeout and apply. No stale PID lock removal.
    return [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
}

function Write-EsirArtifactJson {
    param([string]$RepoRoot, [string]$Path, $Value)
    $target = Resolve-EsirArtifactPath $RepoRoot $Path
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
    $temporary = $target + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [void](Resolve-EsirArtifactPath $RepoRoot $temporary)
    [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 32), [Text.UTF8Encoding]::new($false))
    Initialize-EsirHousekeepingNative
    [EsirArtifactFile]::Replace($temporary, $target)
}

function Get-EsirArtifactRecordPath {
    param([string]$RepoRoot, [string]$RunId)
    if ($RunId -notmatch '^[a-f0-9]{32}$') { throw 'Invalid housekeeping run ID.' }
    # The operation validates/locks the store once; record reads still check every ancestor.
    return Resolve-EsirArtifactPath $RepoRoot ('.factorio-qc/housekeeping/' + $RunId + '.json')
}

function Read-EsirArtifactRun {
    param([string]$RepoRoot, [string]$RunId)
    $run = Get-Content -LiteralPath (Get-EsirArtifactRecordPath $RepoRoot $RunId) -Raw | ConvertFrom-Json
    if ($run.schema_version -ne 1 -or $run.id -ne $RunId -or $run.repo_root -ne (Get-EsirHousekeepingRoot $RepoRoot)) { throw 'Invalid artifact registry record.' }
    return $run
}

function Get-EsirArtifactRuns {
    param([string]$RepoRoot)
    $store = Get-EsirHousekeepingStore $RepoRoot
    if (-not (Test-Path -LiteralPath $store)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $store -File -Filter '*.json') {
        if ($file.BaseName -match '^[a-f0-9]{32}$') { Read-EsirArtifactRun $RepoRoot $file.BaseName }
    }
}

function Get-EsirArtifactSnapshot {
    param([string]$RepoRoot, [string]$PayloadPath, [switch]$Exclusive)
    Initialize-EsirHousekeepingNative
    $payload = Assert-EsirArtifactTarget $RepoRoot $PayloadPath
    if (-not [IO.Directory]::Exists([EsirArtifactFile]::ExtendedPath($payload))) { throw "Missing payload: $payload" }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($payload)
    $files = [Collections.Generic.List[object]]::new()
    $directories = [Collections.Generic.List[string]]::new()
    while ($pending.Count) {
        $directory = $pending.Pop()
        [void](Resolve-EsirArtifactPath $RepoRoot $directory)
        $directories.Add((Get-EsirArtifactRelativePath $RepoRoot $directory))
        foreach ($entry in [IO.DirectoryInfo]::new([EsirArtifactFile]::ExtendedPath($directory)).EnumerateFileSystemInfos()) {
            $entryPath = Join-Path $directory $entry.Name
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Payload contains a reparse point: $entryPath" }
            if ($entry.Name -match '^(mods-live|mods-preview|dependency-seed|baseline-source|asset-cache|tesla-run-mods)$') { throw "Payload contains a protected dependency/cache role: $entryPath" }
            if ($entry.Attributes -band [IO.FileAttributes]::Directory) { $pending.Push($entryPath); continue }
            $files.Add([pscustomobject]@{
                path = Get-EsirArtifactRelativePath $RepoRoot $entryPath
                bytes = $entry.Length
                identity = [EsirArtifactFile]::Identity($entryPath, [bool]$Exclusive)
            })
        }
    }
    return [pscustomobject]@{ files = @($files.ToArray() | Sort-Object path); directories = @($directories.ToArray() | Sort-Object) }
}

function Register-EsirArtifactRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Workflow,
        [string]$Scenario = 'default', [string]$EngineVersion = 'unknown',
        [string]$Owner = $env:CODEX_THREAD_ID,
        [ValidateSet('qc-payload', 'scratch', 'render-intermediates', 'protected-evidence')][string]$Classification = 'qc-payload',
        [Parameter(Mandatory)][string]$Reproduction,
        [string]$PayloadPath, [string[]]$RetainedPaths = @()
    )
    $lock = Enter-EsirHousekeepingLock $RepoRoot
    try {
        $id = [Guid]::NewGuid().ToString('N')
        if (-not $PayloadPath) { $PayloadPath = ".factorio-qc/managed/$id" }
        $payload = Assert-EsirArtifactTarget $RepoRoot $PayloadPath
        if ([IO.Directory]::Exists([EsirArtifactFile]::ExtendedPath($payload)) -or [IO.File]::Exists([EsirArtifactFile]::ExtendedPath($payload))) { throw 'Only a new, absent payload directory can be registered. Legacy adoption is not automatic.' }
        $existingRuns = @(Get-EsirArtifactRuns $RepoRoot)
        $registeredPaths = @($existingRuns | ForEach-Object {
            @($_.payload_path) + @($_.retained_paths) | ForEach-Object {
                [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $RepoRoot $_ }))
            }
        } | Sort-Object -Unique)
        $resolvedPaths = @{}
        if ($registeredPaths.Count) {
            # Resolve only path/link metadata, never enumerate historical payload
            # contents. Reverse aliases can own a plain candidate's parent too.
            $request = ConvertTo-Json -InputObject $registeredPaths -Compress
            $response = $request | & python -X utf8 -B -c 'import json,pathlib,sys; print(json.dumps([{sys.argv[1]:p,sys.argv[2]:str(pathlib.Path(p).resolve())} for p in json.load(sys.stdin)]))' registered resolved
            if ($LASTEXITCODE) { throw 'Cannot resolve historical ownership aliases safely.' }
            foreach ($item in ($response | Out-String | ConvertFrom-Json)) { $resolvedPaths[$item.registered] = $item.resolved }
        }
        foreach ($existing in $existingRuns) {
            $owned = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($existing.payload_path)) { $existing.payload_path } else { Join-Path $RepoRoot $existing.payload_path }))
            if (-not (Test-EsirArtifactWithin $owned (Get-EsirHousekeepingRoot $RepoRoot))) { throw 'Existing payload record escapes the repository.' }
            foreach ($alias in @($owned, $resolvedPaths[$owned])) {
                if ((Test-EsirArtifactWithin $payload $alias) -or (Test-EsirArtifactWithin $alias $payload)) { throw 'Payload ownership overlaps an existing run.' }
            }
            foreach ($reference in $existing.retained_paths) {
                $retained = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($reference)) { $reference } else { Join-Path $RepoRoot $reference }))
                foreach ($alias in @($retained, $resolvedPaths[$retained])) {
                    if ((Test-EsirArtifactWithin $alias $payload) -or (Test-EsirArtifactWithin $payload $alias)) { throw 'Another run retains this path as evidence.' }
                }
            }
        }
        if ($Classification -eq 'render-intermediates' -and $RetainedPaths.Count -eq 0) { throw 'Render intermediates require retained source/specification/final-output evidence paths.' }
        $run = [pscustomobject]@{
            schema_version = 1; id = $id; repo_root = Get-EsirHousekeepingRoot $RepoRoot
            workflow = $Workflow; scenario = $Scenario; engine_version = $EngineVersion
            owner = $(if ($Owner) { $Owner } else { "process-$PID" })
            creator_pid = $PID; creator_started_at = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
            classification = $Classification; reproduction = $Reproduction; retained_paths = @($RetainedPaths); retained_evidence = @()
            payload_path = Get-EsirArtifactRelativePath $RepoRoot $payload
            started_at = [DateTime]::UtcNow.ToString('o'); completed_at = $null
            status = 'running'; task_open = $true; pins = @(); release_reason = $null
            verified_dump = $null; snapshot = $null; summary = $null; housekeeping_error = $null
        }
        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $id) $run
        [void][IO.Directory]::CreateDirectory([EsirArtifactFile]::ExtendedPath($payload))
        return $run
    } finally { $lock.Dispose() }
}

function Complete-EsirArtifactRun {
    [CmdletBinding()]
    param([string]$RepoRoot, [string]$RunId, [int]$ExitCode, [Parameter(Mandatory)]$Summary, [string]$DumpPath)
    $lock = Enter-EsirHousekeepingLock $RepoRoot
    try {
        $run = Read-EsirArtifactRun $RepoRoot $RunId
        if ($run.status -ne 'running') { throw 'Only a running artifact record can be completed.' }
        if (Test-EsirCompactQcRun $run) {
            return (Complete-EsirCompactQcRun -RepoRoot $RepoRoot -Run $run -ExitCode $ExitCode -Summary $Summary -DumpPath $DumpPath)
        }
        $run.completed_at = [DateTime]::UtcNow.ToString('o')
        $run.summary = $Summary
        $run.status = 'failed'
        try {
            if ($Summary.run_id -ne $run.id -or $Summary.workflow -ne $run.workflow -or
                $Summary.engine_version -ne $run.engine_version -or $Summary.repo_root -ne $run.repo_root -or
                $Summary.payload_path -ne $run.payload_path -or
                [DateTime]::Parse($Summary.timestamp).ToUniversalTime() -lt [DateTime]::Parse($run.started_at).ToUniversalTime()) { throw 'Missing, stale, or mismatched completion evidence.' }
            if ($ExitCode -ne 0 -or $Summary.overall_status -notin @('ok', 'warning')) { throw 'Run did not complete successfully.' }
            $retainedEvidence = @()
            foreach ($retained in $run.retained_paths) {
                $retainedFull = Resolve-EsirArtifactPath $RepoRoot $retained
                if ((Test-EsirArtifactWithin $retainedFull (Resolve-EsirArtifactPath $RepoRoot $run.payload_path)) -or
                    -not [IO.File]::Exists([EsirArtifactFile]::ExtendedPath($retainedFull))) { throw "Retained evidence must be a file outside disposable output: $retained" }
                $retainedEvidence += [pscustomobject]@{ path = $retained; identity = [EsirArtifactFile]::Identity($retainedFull, $false) }
            }
            $run.retained_evidence = $retainedEvidence
            $run.snapshot = Get-EsirArtifactSnapshot $RepoRoot $run.payload_path
            if ($DumpPath) {
                $dump = Resolve-EsirArtifactPath $RepoRoot $DumpPath
                $relative = Get-EsirArtifactRelativePath $RepoRoot $dump
                $match = @($run.snapshot.files | Where-Object { $_.path -eq $relative })
                if ($match.Count -ne 1 -or $match[0].bytes -eq 0 -or
                    [IO.FileInfo]::new([EsirArtifactFile]::ExtendedPath($dump)).LastWriteTimeUtc -lt [DateTime]::Parse($run.started_at).ToUniversalTime()) { throw 'Final-data dump is empty, stale, or not owned by this run.' }
                # A producer-success check plus streamed JSON validation avoids loading a multi-GB dump in PowerShell.
                & python -B (Join-Path $PSScriptRoot 'validate-esir-json.py') $dump
                if ($LASTEXITCODE -ne 0) { throw 'Final-data dump is not complete JSON.' }
                $run.verified_dump = $relative
            } elseif ($run.workflow -in @('qc-fast', 'qc-full')) { throw 'Data QC must provide its final-data dump.' }
            $run.status = 'success'
        } catch { $run.housekeeping_error = $_.Exception.Message }
        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $RunId) $run
        return $run
    } finally { $lock.Dispose() }
}

function Complete-EsirCompactQcRun {
    # Caller holds the registry lock. Execution scratch and source views have their
    # own storage ownership; only compact evidence is snapshotted here.
    param([string]$RepoRoot, $Run, [int]$ExitCode, $Summary, [string]$DumpPath)
    $Run.completed_at = [DateTime]::UtcNow.ToString('o')
    $Run.summary = $Summary
    $Run.status = 'failed'
    try {
        if ($Summary.run_id -ne $Run.id -or $Summary.workflow -ne $Run.workflow -or
            $Summary.engine_version -ne $Run.engine_version -or $Summary.repo_root -ne $Run.repo_root -or
            $Summary.payload_path -ne $Run.payload_path -or
            [DateTime]::Parse($Summary.timestamp).ToUniversalTime() -lt [DateTime]::Parse($Run.started_at).ToUniversalTime()) {
            throw 'Missing, stale, or mismatched completion evidence.'
        }
        $storage = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action inspect -Data @{run_id=$Run.id}
        [void](Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action validate -Data @{run_id=$Run.id})
        if ($DumpPath) {
            $dump = [IO.Path]::GetFullPath($DumpPath)
            if (-not (Test-EsirArtifactWithin $dump $storage.scratch_root) -or
                -not (Test-Path -LiteralPath $dump -PathType Leaf) -or
                (Get-Item -LiteralPath $dump).Length -eq 0 -or
                (Get-Item -LiteralPath $dump).LastWriteTimeUtc -lt [DateTime]::Parse($Run.started_at).ToUniversalTime()) {
                throw 'Final-data dump is empty, stale, or outside the owned scratch root.'
            }
            & python -B (Join-Path $PSScriptRoot 'validate-esir-json.py') $dump
            if ($LASTEXITCODE -ne 0) { throw 'Final-data dump is not complete JSON.' }
            $Run.verified_dump = $dump
            $Run.dump_identity = [EsirArtifactFile]::Identity($dump, $false)
            Write-EsirArtifactJson $RepoRoot (Join-Path $storage.evidence_root 'final-data-receipt.json') @{
                engine_version=$Run.engine_version; sha256=(Get-FileHash -LiteralPath $dump -Algorithm SHA256).Hash.ToLowerInvariant()
                bytes=(Get-Item -LiteralPath $dump).Length; valid_json=$true; retained_by_default=$false
            }
        } elseif ($ExitCode -eq 0 -and $Run.workflow -in @('qc-fast', 'qc-full')) {
            throw 'Data QC must provide its final-data dump before compact closeout.'
        }
        # Completion ends staging, not the task's data/capture consumer lifetime.
        [void](Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action release -Data @{run_id=$Run.id})
        $Run.cleanup_status = 'ready'
        $Run | Add-Member -NotePropertyName closeout_retryable -NotePropertyValue $false -Force
        if ($ExitCode -eq 0 -and $Summary.overall_status -in @('ok', 'warning')) { $Run.status = 'success' }
        else { $Run.housekeeping_error = 'Run did not complete successfully; compact failure evidence remains available.' }
    } catch {
        $Run.cleanup_status = 'protected-error'
        $Run | Add-Member -NotePropertyName closeout_retryable -NotePropertyValue $false -Force
        $Run.housekeeping_error = $_.Exception.Message
    }
    Write-EsirArtifactJson $RepoRoot (Join-Path (Resolve-EsirArtifactPath $RepoRoot $Run.payload_path) 'completion.json') $Summary
    $Run.snapshot = Get-EsirArtifactSnapshot $RepoRoot $Run.payload_path
    Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $Run.id) $Run
    return $Run
}

function Set-EsirArtifactRunState {
    [CmdletBinding()]
    param([string]$RepoRoot, [string]$RunId, [ValidateSet('close', 'pin', 'unpin', 'release')][string]$Action, [string]$Reason)
    $lock = Enter-EsirHousekeepingLock $RepoRoot
    try {
        $run = Read-EsirArtifactRun $RepoRoot $RunId
        if ($Action -eq 'close') {
            if ($run.status -eq 'running') { throw 'Running/interrupted runs require an explicit release after investigation.' }
            $run.task_open = $false
        } else {
            if ([string]::IsNullOrWhiteSpace($Reason)) { throw 'Pin/unpin/release requires a reason (the pin label for unpin).' }
            switch ($Action) {
                'pin' { $run.pins = @(@($run.pins) + $Reason | Select-Object -Unique) }
                'unpin' { $run.pins = @($run.pins | Where-Object { $_ -ne $Reason }) }
                'release' {
                    if ($run.status -notin @('running', 'failed')) { throw 'Release resolves failed or interrupted work; successful runs use close/unpin and normal retention.' }
                    if ($run.status -eq 'running') {
                        $process = Get-Process -Id $run.creator_pid -ErrorAction SilentlyContinue
                        if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -eq $run.creator_started_at) { throw 'Run owner is still alive; cannot release running work.' }
                    }
                    $run.snapshot = Get-EsirArtifactSnapshot $RepoRoot $run.payload_path -Exclusive
                    $run.status = 'released'; $run.task_open = $false; $run.release_reason = $Reason
                }
            }
        }
        if (Test-EsirCompactQcRun $run) {
            if ($Action -in @('pin', 'unpin')) {
                [void](Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action pin -Data @{
                    run_id=$run.id; reason=$Reason; pinned=($Action -eq 'pin')
                })
            }
            if (-not $run.task_open -and -not @($run.pins).Count) {
                $closeAttempted = $false
                try {
                    # Completion/input failures still need verified completion. A
                    # failed close may retry through the helper's identity checks.
                    $retryable = $run.PSObject.Properties.Name -contains 'closeout_retryable' -and $run.closeout_retryable
                    if ($run.cleanup_status -eq 'protected-error' -and -not $retryable) { throw $run.housekeeping_error }
                    $closeAttempted = $true
                    $closed = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action close -Data @{
                        run_id=$run.id; status=$run.status; reason=$Reason
                        retain=@(@($run.selected_evidence) + @($run.retained_paths | ForEach-Object {
                            if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $RepoRoot $_ }
                        }))
                    }
                    $run.cleanup_status = 'compacted'
                    $run.housekeeping_error = $null
                    $run | Add-Member -NotePropertyName closeout_retryable -NotePropertyValue $false -Force
                    $run.verified_dump = $null; $run.dump_identity = $null
                    $run | Add-Member -NotePropertyName compact_evidence -NotePropertyValue $closed -Force
                    $run.snapshot = Get-EsirArtifactSnapshot $RepoRoot $run.payload_path
                    [void](Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action collect -Data @{apply=$true})
                } catch {
                    $run.cleanup_status = 'protected-error'; $run.housekeeping_error = $_.Exception.Message
                    $run | Add-Member -NotePropertyName closeout_retryable -NotePropertyValue $closeAttempted -Force
                }
            }
        }
        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $RunId) $run
        return $run
    } finally { $lock.Dispose() }
}

function Get-EsirArtifactRetention {
    param([string]$RepoRoot)
    $runs = @(Get-EsirArtifactRuns $RepoRoot)
    $keep = @{}
    foreach ($group in @($runs | Where-Object { $_.status -eq 'success' -and -not (Test-EsirCompactQcRun $_) } | Group-Object { $_.workflow + '|' + $_.scenario + '|' + $_.engine_version })) {
        foreach ($run in @($group.Group | Sort-Object completed_at -Descending | Select-Object -First 2)) { $keep[$run.id] = 'latest-two-successes' }
    }
    foreach ($group in @($runs | Where-Object { $_.status -eq 'success' -and $_.verified_dump -and -not (Test-EsirCompactQcRun $_) } | Group-Object engine_version)) {
        # Only an unchanged, present dump may displace an older verified dump.
        foreach ($run in @($group.Group | Sort-Object completed_at -Descending)) {
            try {
                $payload = Assert-EsirArtifactTarget $RepoRoot $run.payload_path
                $dump = Resolve-EsirArtifactPath $RepoRoot $run.verified_dump
                if (-not (Test-EsirArtifactWithin $dump $payload)) { continue }
                $recorded = @($run.snapshot.files | Where-Object { $_.path -eq $run.verified_dump })[0]
                Initialize-EsirHousekeepingNative
                if ([EsirArtifactFile]::Identity($dump, $false) -ne $recorded.identity) { continue }
                $keep[$run.id] = 'latest-verified-final-data'; break
            } catch { continue }
        }
    }
    foreach ($run in $runs) {
        $reason = if ($run.status -eq 'retired') { 'already-retired' }
            elseif ((Test-EsirCompactQcRun $run) -and $run.cleanup_status -eq 'protected-error') { 'protected-error' }
            elseif ($run.classification -eq 'protected-evidence') { 'durable-evidence' }
            elseif ($run.classification -notin @('qc-payload', 'scratch', 'render-intermediates')) { 'unclassified' }
            elseif ($run.task_open) { 'active-task' }
            elseif (@($run.pins).Count) { 'pinned' }
            elseif (Test-EsirCompactQcRun $run) { 'compact-evidence' }
            elseif ($run.status -notin @('success', 'released')) { 'unresolved-or-incomplete' }
            elseif ($run.engine_version -eq 'unknown' -and $run.classification -eq 'qc-payload') { 'unknown-engine' }
            elseif ($keep.ContainsKey($run.id)) { $keep[$run.id] }
            else { 'eligible' }
        if ($reason -eq 'eligible') {
            $ownPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($run.payload_path)) { $run.payload_path } else { Join-Path $RepoRoot $run.payload_path }))
            foreach ($other in $runs) {
                if ($other.id -eq $run.id) { continue }
                foreach ($reference in $other.retained_paths) {
                    $retained = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($reference)) { $reference } else { Join-Path $RepoRoot $reference }))
                    if ((Test-EsirArtifactWithin $retained $ownPath) -or (Test-EsirArtifactWithin $ownPath $retained)) { $reason = 'retained-by-another-run'; break }
                }
                if ($reason -ne 'eligible') { break }
                if ($other.status -eq 'retired') { continue }
                $otherPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($other.payload_path)) { $other.payload_path } else { Join-Path $RepoRoot $other.payload_path }))
                if ((Test-EsirArtifactWithin $ownPath $otherPath) -or (Test-EsirArtifactWithin $otherPath $ownPath)) { $reason = 'overlapping-ownership'; break }
            }
        }
        [pscustomobject]@{ run = $run; reason = $reason }
    }
}

function Assert-EsirArtifactUnchanged {
    param([string]$RepoRoot, $Run)
    if (-not $Run.snapshot) { throw 'No completed file inventory exists.' }
    $current = Get-EsirArtifactSnapshot $RepoRoot $Run.payload_path -Exclusive
    $before = $Run.snapshot | ConvertTo-Json -Depth 8 -Compress
    $after = $current | ConvertTo-Json -Depth 8 -Compress
    if ($before -cne $after) { throw 'Payload changed after completion; retain and investigate.' }
    foreach ($retained in $Run.retained_evidence) {
        if ([EsirArtifactFile]::Identity((Resolve-EsirArtifactPath $RepoRoot $retained.path), $false) -ne $retained.identity) { throw "Retained evidence changed: $($retained.path)" }
    }
    return $current
}

function Get-EsirArtifactInventory {
    param([string]$RepoRoot, [switch]$FullInventory, [switch]$IncludeCodexHome)
    $root = Get-EsirHousekeepingRoot $RepoRoot
    $excluded = @((Join-Path $root 'models'), (Join-Path $root '.git'))
    foreach ($top in Get-ChildItem -LiteralPath $root -Directory -Force) {
        if ($top.Name -in @('models', '.git')) { continue }
        if ($top.Name -like 'exotic-space-industries-remembrance*' -or
            (-not ($top.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Path -LiteralPath (Join-Path $top.FullName 'info.json')))) { $excluded += $top.FullName }
    }
    $roots = @('.factorio-qc', 'output', 'temp', 'tmp', '.tmp_inspect', 'Render', '.factorio-lua-docs-cache', '.codex/skills/esir-recipe-icon-style/output')
    if ($IncludeCodexHome) {
        $codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
        # Metadata only; do not read history, credentials, database or plugin contents.
        foreach ($name in @('sessions', 'session-repair-backups', '.tmp', 'plugins', 'generated_images', 'cache', 'tools')) {
            $roots += Join-Path $codexRoot $name
        }
    }
    foreach ($item in $roots) {
        $path = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $root $item }))
        if (@($excluded | Where-Object { (Test-EsirArtifactWithin $path $_) -or (Test-EsirArtifactWithin $_ $path) }).Count) { continue }
        $unsafe = $false; $ancestor = $path
        while ($ancestor) {
            if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { $unsafe = $true; break }
            $ancestor = [IO.Path]::GetDirectoryName($ancestor)
        }
        if ($unsafe) { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
        if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if (Test-Path -LiteralPath (Join-Path $path 'info.json')) { continue }
        $count = 0L; $bytes = 0L; $skipped = 0; $errors = 0; $groups = @{}
        $pending = [Collections.Generic.Stack[string]]::new(); $pending.Push($path)
        while ($pending.Count) {
            $directory = $pending.Pop()
            try {
                foreach ($entry in [IO.DirectoryInfo]::new($directory).EnumerateFileSystemInfos()) {
                    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { $skipped++; continue }
                    if ($entry.Attributes -band [IO.FileAttributes]::Directory) {
                        if ($FullInventory) { $pending.Push($entry.FullName) }
                    } else {
                        $count++; $bytes += $entry.Length
                        $tail = $entry.FullName.Substring($path.Length + 1)
                        $group = if ($tail.Contains('\')) { $tail.Split('\')[0] } else { '[root files]' }
                        if (-not $groups.ContainsKey($group)) { $groups[$group] = [ordered]@{ name = $group; file_count = 0L; logical_bytes = 0L } }
                        $groups[$group].file_count++; $groups[$group].logical_bytes += $entry.Length
                    }
                }
            } catch { $errors++ }
        }
        [pscustomobject]@{ path = $item; file_count = $count; logical_bytes = $bytes; recursive = [bool]$FullInventory; reparse_skipped = $skipped; errors = $errors; largest_groups = @($groups.Values | Sort-Object { $_.logical_bytes } -Descending | Select-Object -First 12); classification = 'inventory-only; registration required' }
    }
}

function Invoke-EsirHousekeeping {
    [CmdletBinding()]
    param([string]$RepoRoot, [switch]$Apply, [string[]]$CloseRunId = @(), [switch]$FullInventory, [switch]$IncludeCodexHome)
    foreach ($id in $CloseRunId) { [void](Set-EsirArtifactRunState $RepoRoot $id close) }
    $lock = $null
    if ($Apply) { $lock = Enter-EsirHousekeepingLock $RepoRoot }
    try {
        $rows = [Collections.Generic.List[object]]::new()
        $deletedCount = 0L; $deletedBytes = 0L
        $freeBefore = [IO.DriveInfo]::new([IO.Path]::GetPathRoot((Get-EsirHousekeepingRoot $RepoRoot))).AvailableFreeSpace
        foreach ($entry in @(Get-EsirArtifactRetention $RepoRoot)) {
            $run = $entry.run
            $row = [ordered]@{ run_id = $run.id; workflow = $run.workflow; scenario = $run.scenario; engine_version = $run.engine_version; payload_path = $run.payload_path; disposition = $entry.reason; file_count = 0; logical_bytes = 0; error = $null }
            if ($entry.reason -eq 'protected-error') { $row.error = $run.housekeeping_error }
            if ($run.snapshot) {
                $row.file_count = @($run.snapshot.files).Count
                foreach ($file in $run.snapshot.files) { $row.logical_bytes += [long]$file.bytes }
            }
            if ($entry.reason -eq 'eligible') {
                try {
                    $snapshot = Assert-EsirArtifactUnchanged $RepoRoot $run
                    if ($Apply) {
                        # No recursive delete: enumerate exactly the verified files and then empty dirs.
                        [void](Assert-EsirArtifactTarget $RepoRoot $run.payload_path)
                        foreach ($file in $snapshot.files) {
                            $target = Resolve-EsirArtifactPath $RepoRoot $file.path
                            if ([EsirArtifactFile]::Identity($target, $true) -ne $file.identity) { throw "File changed before deletion: $($file.path)" }
                            [IO.File]::Delete([EsirArtifactFile]::ExtendedPath($target))
                            $deletedCount++; $deletedBytes += [long]$file.bytes
                        }
                        foreach ($directory in @($snapshot.directories | Sort-Object Length -Descending)) {
                            $target = Resolve-EsirArtifactPath $RepoRoot $directory
                            [IO.Directory]::Delete([EsirArtifactFile]::ExtendedPath($target), $false)
                        }
                        $run.status = 'retired'
                        # Compact summary and provenance survive; a retired run need not retain a huge file list.
                        $run.snapshot = $null
                        Write-EsirArtifactJson $RepoRoot (Get-EsirArtifactRecordPath $RepoRoot $run.id) $run
                        $row.disposition = 'retired'
                    }
                } catch { $row.disposition = 'protected-error'; $row.error = $_.Exception.Message }
            }
            $rows.Add([pscustomobject]$row)
        }
        $freeAfter = [IO.DriveInfo]::new([IO.Path]::GetPathRoot((Get-EsirHousekeepingRoot $RepoRoot))).AvailableFreeSpace
        $storageCollection = $null
        if (Test-Path -LiteralPath (Join-Path $RepoRoot '.factorio-qc/storage')) {
            try { $storageCollection = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action collect -Data @{apply=[bool]$Apply} }
            catch { $storageCollection = [pscustomobject]@{status='protected-error';error=$_.Exception.Message} }
        }
        return [ordered]@{
            task = 'housekeeping'; overall_status = $(if (@($rows | Where-Object error).Count -or
                ($storageCollection -and (($storageCollection.PSObject.Properties.Name -contains 'error') -or
                ($storageCollection.PSObject.Properties.Name -contains 'protected' -and @($storageCollection.protected).Count)))) { 'warning' } else { 'ok' })
            applied = [bool]$Apply; runs = @($rows.ToArray())
            storage = $storageCollection
            inventory = @(Get-EsirArtifactInventory $RepoRoot -FullInventory:$FullInventory -IncludeCodexHome:$IncludeCodexHome)
            deleted_file_count = $deletedCount; deleted_logical_bytes = $deletedBytes
            observed_free_space_delta = $freeAfter - $freeBefore
            size_note = 'Logical bytes include hard links; free-space change is observed volume-wide, not guaranteed attributable recovery.'
            exclusions = @('models/', '.git/', 'actual source mod folders', 'unregistered historical payloads', 'external Codex storage')
        }
    } finally { if ($lock) { $lock.Dispose() } }
}

function Start-EsirManagedQc {
    param([string]$RepoRoot, $Context, [string]$Workflow, [string]$Scenario = 'default', [string]$Reproduction, [string[]]$RetainedPaths = @(),
        [ValidateSet('read-only', 'private-mutable')][string]$SourceMode = 'read-only')
    $state = [pscustomobject]@{ run = $null; error = $null; original_artifact_root = $Context.artifact_root }
    try {
        $version = 'unknown'
        if ($Context.factorio_exe) {
            # Factorio's Windows GUI subsystem does not reliably populate LASTEXITCODE.
            $probe = [Diagnostics.Process]::new()
            $probe.StartInfo.FileName = $Context.factorio_exe
            $probe.StartInfo.Arguments = '--version'
            $probe.StartInfo.UseShellExecute = $false
            $probe.StartInfo.CreateNoWindow = $true
            $probe.StartInfo.RedirectStandardOutput = $true
            $probe.StartInfo.RedirectStandardError = $true
            try {
                [void]$probe.Start()
                $stdout = $probe.StandardOutput.ReadToEndAsync()
                $stderr = $probe.StandardError.ReadToEndAsync()
                if (-not $probe.WaitForExit(15000)) { $probe.Kill(); throw 'Engine version probe timed out.' }
                $versionText = $stdout.Result + $stderr.Result
                if ($probe.ExitCode -eq 0 -and $versionText -match 'Version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { $version = $matches[1] }
            } finally { $probe.Dispose() }
        }
        $state.run = Register-EsirArtifactRun -RepoRoot $RepoRoot -Workflow $Workflow -Scenario $Scenario -EngineVersion $version -Reproduction $Reproduction -RetainedPaths $RetainedPaths
        [void](Initialize-EsirManagedQcContext -RepoRoot $RepoRoot -Context $Context -RunId $state.run.id -SourceMode $SourceMode)
    } catch {
        $state.error = $_.Exception.Message
        $state.run = $null
    }
    return $state
}

function Finish-EsirManagedQc {
    param([string]$RepoRoot, $State, [int]$ExitCode, $Result, [string]$DumpPath)
    if (-not $State.run) { return [ordered]@{ status = 'unmanaged'; error = $State.error } }
    try {
        $summary = [ordered]@{
            run_id = $State.run.id; workflow = $State.run.workflow; engine_version = $State.run.engine_version
            repo_root = $State.run.repo_root; payload_path = $State.run.payload_path
            timestamp = [DateTime]::UtcNow.ToString('o'); overall_status = $Result.overall_status
            result = $Result
        }
        $record = Complete-EsirArtifactRun -RepoRoot $RepoRoot -RunId $State.run.id -ExitCode $ExitCode -Summary $summary -DumpPath $DumpPath
        return [ordered]@{ run_id = $record.id; status = $record.status; task_open = $record.task_open; payload_path = $record.payload_path; error = $record.housekeeping_error }
    } catch { return [ordered]@{ run_id = $State.run.id; status = 'protected-error'; error = $_.Exception.Message } }
}

function Get-EsirRetainedFinalData {
    param([string]$RepoRoot, [Parameter(Mandatory)][string]$EngineVersion)
    Initialize-EsirHousekeepingNative
    foreach ($run in @(Get-EsirArtifactRuns $RepoRoot | Where-Object { $_.status -eq 'success' -and $_.engine_version -eq $EngineVersion -and $_.verified_dump -and ($_.task_open -or @($_.pins).Count) } | Sort-Object completed_at -Descending)) {
        try {
            if (Test-EsirCompactQcRun $run) {
                $storage = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action inspect -Data @{run_id=$run.id}
                $dump = [IO.Path]::GetFullPath($run.verified_dump)
                if ((Test-EsirArtifactWithin $dump $storage.scratch_root) -and
                    [EsirArtifactFile]::Identity($dump, $false) -eq $run.dump_identity) { return $dump }
                continue
            }
            $payload = Assert-EsirArtifactTarget $RepoRoot $run.payload_path
            $dump = Resolve-EsirArtifactPath $RepoRoot $run.verified_dump
            if (-not (Test-EsirArtifactWithin $dump $payload)) { continue }
            $recorded = @($run.snapshot.files | Where-Object { $_.path -eq $run.verified_dump })[0]
            if ([EsirArtifactFile]::Identity($dump, $false) -eq $recorded.identity) { return $dump }
        } catch { continue }
    }
    throw "No active or explicitly pinned verified dump for Factorio $EngineVersion. Regenerate with engine-matching qc-fast and consume before task close; never substitute historical output silently."
}
