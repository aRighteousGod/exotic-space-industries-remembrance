# Real engine/storage integration in a tiny isolated repo; no live-mod deployment.
[CmdletBinding()]
param([string]$RepoRoot, [string]$FactorioPath, [string]$ExpectedVersion, [switch]$KeepFixture)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-dev-lib.ps1')
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
$profile = Get-Content -LiteralPath (Join-Path $RepoRoot '.codex/esir/factorio-development.json') -Raw | ConvertFrom-Json
if (-not $ExpectedVersion) { $ExpectedVersion = $profile.engine_version }
if (-not $FactorioPath) {
    $FactorioPath = Join-Path $RepoRoot $profile.engine_path
}
$versionText = (& $FactorioPath --version | Out-String)
if ($versionText -notmatch 'Version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { throw 'Cannot resolve native fixture engine version.' }
$actualVersion = $matches[1]
if ($actualVersion -ne $ExpectedVersion) { throw "Native fixture requires exact Factorio $ExpectedVersion; found $actualVersion. The development profile is unchanged." }
$family = ($actualVersion -split '\.')[0..1] -join '.'
$fixture = Join-Path $RepoRoot ('output/housekeeping-engine-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'housekeeping-fixture'))
[IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "/.factorio-qc/`n/output/`n")
$info = @{name='housekeeping-fixture';version='0.0.1';title='Housekeeping fixture';author='ESIR QC';factorio_version=$family;dependencies=@('base >= 2.0.0','dependency-fixture')}
[IO.File]::WriteAllText((Join-Path $fixture 'housekeeping-fixture/info.json'), ($info | ConvertTo-Json))
[IO.File]::WriteAllText((Join-Path $fixture 'housekeeping-fixture/data.lua'), '-- Empty data stage for storage integration.')
& git -C $fixture init -q
if ($LASTEXITCODE) { throw 'Cannot initialize isolated fixture repository.' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = Join-Path $fixture 'dependency-fixture_1.0.0.zip'
$zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
try {
    $writer = [IO.StreamWriter]::new($zip.CreateEntry('dependency-fixture_1.0.0/info.json').Open())
    try { $writer.Write((@{name='dependency-fixture';version='1.0.0';title='Dependency fixture';author='ESIR QC';factorio_version=$family;dependencies=@('base')} | ConvertTo-Json)) }
    finally { $writer.Dispose() }
} finally { $zip.Dispose() }
$profileResult = Invoke-EsirQcStorage -RepoRoot $fixture -Action profile -Data @{name='native-fixture';packages=@(@{path=$archive})}
$artifact = $profileResult.packages[0]
Initialize-EsirHousekeepingNative
$identity = [EsirArtifactFile]::Identity($artifact.path, $false)
$measurements = @()
try {
    foreach ($iteration in 1..2) {
        $paths = Get-EsirPaths -RepoRoot $fixture
        $context = Get-EsirQcContext -Paths $paths -FactorioPath $FactorioPath -EnsureArtifactRoot
        $context | Add-Member -NotePropertyName dependency_packages -NotePropertyValue @(@{sha256=$artifact.sha256}) -Force
        $context | Add-Member -NotePropertyName qc_mod_list -NotePropertyValue @{mods=@(
            @{name='base';enabled=$true}, @{name='dependency-fixture';enabled=$true}, @{name='housekeeping-fixture';enabled=$true}
        )} -Force
        $managed = Start-EsirManagedQc -RepoRoot $fixture -Context $context -Workflow qc-fast -Scenario 'tiny-storage-native' -Reproduction "check-engine.ps1 -ExpectedVersion $ExpectedVersion"
        if (-not $managed.run) { throw $managed.error }
        $fast = Invoke-FactorioFastQC -Context $context
        $result = @{overall_status=$fast.status;results=@($fast)}
        $dump = $fast.artifacts.data_raw_dump
        $dumpBytes = (Get-Item -LiteralPath $dump).Length
        $completed = Finish-EsirManagedQc -RepoRoot $fixture -State $managed -ExitCode $(if ($fast.status -eq 'failed') { 1 } else { 0 }) -Result $result -DumpPath $dump
        if ($completed.status -ne 'success') { throw "Native fixture completion failed: $($completed.error)" }
        if ((Get-EsirRetainedFinalData $fixture $actualVersion) -ne $dump) { throw 'Active dump lookup mismatch.' }
        $closed = Set-EsirArtifactRunState $fixture $managed.run.id close
        if ($closed.cleanup_status -ne 'compacted') { throw "Native close failed: $($closed.housekeeping_error)" }
        if ((Test-Path -LiteralPath $dump) -or (Test-Path -LiteralPath $context.mod_view_root) -or (Test-Path -LiteralPath $context.scratch_root)) { throw 'Closed run retained raw dump, scratch, or setup.' }
        $store = Invoke-EsirQcStorage -RepoRoot $fixture -Action status
        if (@($store.artifacts).Count -ne 1 -or [EsirArtifactFile]::Identity($store.artifacts[0].path, $false) -ne $identity) { throw 'Repeated native QC duplicated its canonical dependency.' }
        $measurements += @{iteration=$iteration;run_id=$managed.run.id;qc_status=$fast.status;warnings=@($fast.warnings);dump_bytes=$dumpBytes;canonical_file_identity=$identity;canonical_archive_count=1;closed=$true}
    }
    $validation = @{overall_status='ok';engine_version=$actualVersion;expected_version=$ExpectedVersion;iterations=$measurements;live_mods_modified=$false;fixture_removed=$false}
    if (-not $KeepFixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $boundary = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'output')).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped output.' }
        if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Fixture contains links; retain for inspection.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $validation.fixture_removed = $true
    }
    $validation | ConvertTo-Json -Depth 6
} catch {
    Write-Warning "Native storage fixture retained for inspection: $fixture"
    throw
}
