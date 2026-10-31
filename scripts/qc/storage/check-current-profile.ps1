# Verify the real selected inputs through two managed views; no engine simulation.
[CmdletBinding()]
param([string]$RepoRoot)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-dev-lib.ps1')
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
Initialize-EsirHousekeepingNative
$paths = Get-EsirPaths $RepoRoot
$profile = Read-EsirJson (Join-Path $RepoRoot '.codex/esir/factorio-development.json')
$lock = @(Read-EsirJson (Join-Path (Join-Path $RepoRoot $profile.dependency_seed) 'dependency-lock-2.1.json'))
$records = @()
$canonical = @{}
foreach ($iteration in 1..2) {
    $context = Get-EsirQcContext -Paths $paths -EnsureArtifactRoot
    $state = Start-EsirManagedQc -RepoRoot $RepoRoot -Context $context -Workflow 'storage-profile-validation' -Scenario "view-$iteration" -Reproduction 'powershell -File scripts/qc/storage/check-current-profile.ps1'
    if (-not $state.run) { throw $state.error }
    $failure = $null
    try {
        $result = New-FactorioQCResult -Name 'profile-stage'
        $view = Sync-FactorioRunMods -Context $context -Result $result
        $store = Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action status
        $artifacts = @{}
        foreach ($artifact in $store.artifacts) { $artifacts[$artifact.sha256] = $artifact }
        $archivePaths = @()
        foreach ($row in $lock) {
            $artifact = $artifacts[$row.sha256]
            $linked = Join-Path $view $row.file
            $identity = [EsirArtifactFile]::Identity($artifact.path, $false)
            if ([EsirArtifactFile]::Identity($linked, $false) -ne $identity) { throw "Dependency payload copied: $($row.name)" }
            if ($canonical.ContainsKey($row.sha256) -and $canonical[$row.sha256] -ne $identity) { throw "Repeated staging replaced $($row.name)" }
            $canonical[$row.sha256] = $identity
            $archivePaths += $artifact.path
        }
        $allocationCode = @'
import ctypes, json, os, sys
from ctypes import wintypes
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.GetCompressedFileSizeW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
kernel.GetCompressedFileSizeW.restype = wintypes.DWORD
seen, allocated = set(), 0
for path in sys.argv[1:]:
    info = os.stat(path)
    identity = (info.st_dev, info.st_ino)
    if identity in seen:
        continue
    seen.add(identity)
    high = wintypes.DWORD()
    ctypes.set_last_error(0)
    low = kernel.GetCompressedFileSizeW(path, ctypes.byref(high))
    if low == 0xffffffff and ctypes.get_last_error():
        raise ctypes.WinError(ctypes.get_last_error())
    allocated += (high.value << 32) + low
print(json.dumps({'files':len(seen),'allocated_bytes':allocated}))
'@
        $viewPaths = @($lock | ForEach-Object { Join-Path $view $_.file })
        $allocationText = $allocationCode | & python -B - @archivePaths @viewPaths
        if ($LASTEXITCODE) { throw 'Allocation probe failed.' }
        $allocation = $allocationText | ConvertFrom-Json
        if ($allocation.files -ne $lock.Count) { throw 'Unexpected distinct dependency file count.' }
        $record = @{iteration=$iteration;run_id=$state.run.id;engine_version=$profile.engine_version;dependency_files=$allocation.files;
            allocated_dependency_bytes=$allocation.allocated_bytes;extra_dependency_payload_bytes=0;source_mode=$context.source_mode}
        Write-EsirJson -Path (Join-Path $context.evidence_root 'profile-assertions.json') -Data $record
        $records += $record
    } catch { $failure = $_ }
    $verdict = if ($failure) { 'failed' } else { 'ok' }
    $completed = Finish-EsirManagedQc -RepoRoot $RepoRoot -State $state -ExitCode $(if ($failure) { 1 } else { 0 }) -Result @{overall_status=$verdict}
    $closed = Set-EsirArtifactRunState -RepoRoot $RepoRoot -RunId $state.run.id -Action close
    if ($closed.cleanup_status -ne 'compacted') { throw "Profile closeout protected: $($closed.housekeeping_error)" }
    if ((Test-Path -LiteralPath $context.mod_view_root) -or (Test-Path -LiteralPath $context.scratch_root)) { throw 'Disposable setup survived closeout.' }
    if ($failure) { throw $failure }
    if ($completed.status -ne 'success') { throw "Profile validation failed: $($completed.error)" }
}
@{passed=$true;engine_version=$profile.engine_version;runs=$records;scope='current-profile staging';scratch_and_views_remaining=0} | ConvertTo-Json -Depth 6
