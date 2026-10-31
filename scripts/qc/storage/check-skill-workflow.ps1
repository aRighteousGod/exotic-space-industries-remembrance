# Follow the documented focused-run lifecycle against a disposable repository.
# This is storage evidence only: no Factorio executable or real dependency is used.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
Initialize-EsirHousekeepingNative
# Keep the disposable repository outside the editor-watched workspace: archive
# indexers can legitimately hold a ZIP open and make safe teardown defer.
$temporaryBoundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$fixture = [IO.Path]::GetFullPath((Join-Path $temporaryBoundary ('esir-qc-skill-workflow-' + [Guid]::NewGuid().ToString('N'))))
if (-not $fixture.StartsWith($temporaryBoundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped the temporary boundary.' }
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Workflow {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-UniqueAllocation {
    param([string[]]$Paths)
    $result = @'
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
    $output = $result | & python -B - @Paths
    if ($LASTEXITCODE -ne 0) { throw 'Allocation probe failed.' }
    return ($output | Out-String | ConvertFrom-Json)
}

try {
    [void][IO.Directory]::CreateDirectory($fixture)
    & git -C $fixture init -q
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize disposable repository.' }
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), ".factorio-qc/`n", $utf8)
    $source = Join-Path $fixture 'source-fixture'
    [void][IO.Directory]::CreateDirectory($source)
    [IO.File]::WriteAllText((Join-Path $source 'info.json'), '{"name":"source-fixture","version":"1.0.0","factorio_version":"2.1","title":"Storage source fixture","author":"QC"}', $utf8)
    [IO.File]::WriteAllText((Join-Path $source 'data.lua'), '-- Storage-only fixture.', $utf8)

    $inputZip = Join-Path $fixture 'dependency-fixture_1.0.0.zip'
    @'
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'x', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr('dependency-fixture_1.0.0/info.json', json.dumps({'name':'dependency-fixture','version':'1.0.0','factorio_version':'2.1','title':'Storage dependency fixture','author':'QC'}))
'@ | & python -B - $inputZip
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the fixture dependency.' }
    $first = Invoke-EsirQcStorage -RepoRoot $fixture -Action import -Data @{path=$inputZip}
    $second = Invoke-EsirQcStorage -RepoRoot $fixture -Action import -Data @{path=$inputZip}
    Assert-Workflow ($first.sha256 -eq $second.sha256 -and $first.path -eq $second.path) 'Repeated import created another canonical artifact.'
    [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action profile -Data @{name='skill-workflow';packages=@($first.sha256)})
    $baseline = Get-UniqueAllocation @($first.path)
    $runs = @()
    $views = @()
    foreach ($sequence in 1..2) {
        $run = Register-EsirArtifactRun -RepoRoot $fixture -Workflow 'skill-workflow' -Scenario "view-$sequence" -EngineVersion 'storage-only' -Reproduction 'scripts/qc/storage/check-skill-workflow.ps1 (no engine)'
        $context = [pscustomobject]@{artifact_root=(Join-Path $fixture $run.payload_path);run_mod_directory=$null}
        $storage = Initialize-EsirManagedQcContext -RepoRoot $fixture -Context $context -RunId $run.id -SourceMode read-only
        $selection = @{mods=@(@{name='base';enabled=$true},@{name='dependency-fixture';enabled=$true},@{name='source-fixture';enabled=$true})}
        $storage = Invoke-EsirQcStorage -RepoRoot $fixture -Action stage -Data @{
            run_id=$run.id; packages=@($first.sha256); sources=@(@{path=$source;name='source-fixture'}); mod_list=$selection
        }
        $views += Join-Path $storage.mod_view_root 'dependency-fixture_1.0.0.zip'
        $runs += [pscustomobject]@{run=$run;storage=$storage}
        [IO.File]::WriteAllText((Join-Path $storage.scratch_root 'assertions.json'), '{"scope":"storage-only","passed":true}', $utf8)
        [IO.File]::WriteAllText((Join-Path $storage.scratch_root 'data-raw-dump.json'), '{"synthetic":true}', $utf8)
    }
    $withViews = Get-UniqueAllocation (@($first.path, $inputZip) + $views)
    Assert-Workflow ($withViews.files -eq 1 -and $withViews.allocated_bytes -eq $baseline.allocated_bytes) 'Thin views allocated another dependency payload.'
    foreach ($entry in $runs) {
        $run = $entry.run
        $summary = @{run_id=$run.id;workflow=$run.workflow;engine_version=$run.engine_version;repo_root=$run.repo_root;payload_path=$run.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';scope='storage-only'}
        $completed = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $run.id -ExitCode 0 -Summary $summary
        Assert-Workflow ($completed.status -eq 'success' -and $completed.cleanup_status -eq 'ready') "Completion failed: $($completed.housekeeping_error)"
        $closed = Set-EsirArtifactRunState -RepoRoot $fixture -RunId $run.id -Action close
        Assert-Workflow ($closed.cleanup_status -eq 'compacted') "Closeout failed: $($closed.housekeeping_error)"
        Assert-Workflow (-not (Test-Path -LiteralPath $entry.storage.scratch_root)) 'Scratch survived closeout.'
        Assert-Workflow (-not (Test-Path -LiteralPath $entry.storage.view_root)) 'A mod view survived closeout.'
        Assert-Workflow (Test-Path -LiteralPath (Join-Path $entry.storage.evidence_root 'evidence.zip')) 'Compact evidence is missing.'
        Assert-Workflow (Test-Path -LiteralPath (Join-Path $source 'data.lua')) 'Source was removed through a junction.'
    }
    $status = Invoke-EsirQcStorage -RepoRoot $fixture -Action status
    Assert-Workflow (@($status.artifacts).Count -eq 1) 'Current profile did not retain its single package.'
    [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action profile -Data @{name='skill-workflow';packages=@()})
    [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action collect -Data @{apply=$true})
    $status = Invoke-EsirQcStorage -RepoRoot $fixture -Action status
    Assert-Workflow (@($status.artifacts).Count -eq 0) 'Unused managed package remained after collection.'
    @{passed=$true;scope='storage-only';runs=2;unique_dependency_files=$withViews.files;allocated_dependency_bytes=$withViews.allocated_bytes;extra_view_payload_bytes=($withViews.allocated_bytes-$baseline.allocated_bytes);scratch_and_views_remaining=0;unused_packages_remaining=0} | ConvertTo-Json -Compress
} finally {
    # The test creates this exact disposable repository. Do not follow any view
    # links left by a failing implementation during test teardown.
    if (Test-Path -LiteralPath $fixture) {
        $remainingLinks = @(Get-ChildItem -LiteralPath $fixture -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue)
        if ($remainingLinks.Count) { Write-Warning "Test fixture preserved because links remain: $fixture" }
        else { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
}
