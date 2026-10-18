# Real engine integration in a tiny isolated repository; no ESIR/live-mod deployment.
[CmdletBinding()]
param([string]$RepoRoot, [string]$FactorioPath, [switch]$KeepFixture)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
$fixture = Join-Path $RepoRoot ('output/housekeeping-engine-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'housekeeping-fixture'))
[IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "/.factorio-qc/`n/output/`n")
[IO.File]::WriteAllText((Join-Path $fixture 'housekeeping-fixture/info.json'), '{"name":"housekeeping-fixture","version":"0.0.1","title":"Housekeeping fixture","author":"ESIR QC","factorio_version":"2.0","dependencies":["base >= 2.0.0"]}')
[IO.File]::WriteAllText((Join-Path $fixture 'housekeeping-fixture/data.lua'), '-- Empty data stage for tooling integration.\n')
& git -C $fixture init -q
if ($LASTEXITCODE) { throw 'Cannot initialize fixture repository.' }
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $RepoRoot 'scripts/invoke-esir-dev.ps1'), '-Task', 'qc-fast', '-RepoRoot', $fixture, '-AsJson')
if ($FactorioPath) { $arguments += @('-FactorioPath', $FactorioPath) }
$output = @(& powershell @arguments)
$exitCode = $LASTEXITCODE
$text = $output -join "`n"
[IO.File]::WriteAllText((Join-Path $fixture 'wrapper-result.json'), $text)
if ($exitCode -ne 0) { throw "Engine fixture failed; inspect $fixture/wrapper-result.json" }
$result = $text | ConvertFrom-Json
if ($result.overall_status -notin @('ok', 'warning') -or $result.housekeeping.status -ne 'success' -or -not $result.housekeeping.task_open) { throw "Managed QC did not register verified successful evidence: $text" }
$run = Read-EsirArtifactRun $fixture $result.housekeeping.run_id
$dump = Get-EsirRetainedFinalData $fixture $run.engine_version
if ((Get-Item -LiteralPath $dump).Length -eq 0) { throw 'Engine produced an empty dump.' }
if ($result.summary.run_mod_directory -notlike '*run-mods') { throw 'QC did not isolate run-mod staging.' }
[void](Set-EsirArtifactRunState $fixture $run.id close)
$report = Invoke-EsirHousekeeping $fixture
if ($report.deleted_file_count -ne 0) { throw 'Dry-run integration unexpectedly deleted files.' }
$validation = [ordered]@{ overall_status = 'ok'; engine_version = $run.engine_version; run_id = $run.id; fixture_root = $fixture; dump_bytes = (Get-Item -LiteralPath $dump).Length; qc_status = $result.overall_status; managed_status = $result.housekeeping.status; task_closed = $true; live_mods_modified = $false; fixture_removed = $false }
if (-not $KeepFixture) {
    # This exact newly created test repository is task-owned scratch, not historical QC.
    $resolved = [IO.Path]::GetFullPath($fixture)
    $parent = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'output')).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped output.' }
    [void](Resolve-EsirArtifactPath $RepoRoot $resolved)
    if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Fixture contains a reparse point; retained for inspection.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    $validation.fixture_removed = $true
}
$validation | ConvertTo-Json
