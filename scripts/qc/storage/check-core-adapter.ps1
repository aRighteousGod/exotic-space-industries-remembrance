# Exercise the actual core runner in a disposable repository, never changing the
# real development profile or adopting historical QC output.
[CmdletBinding()]
param([string]$RepoRoot, [string]$FactorioPath, [switch]$KeepFixture)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
$liveProfilePath = Join-Path $RepoRoot '.codex/esir/factorio-development.json'
$liveProfileHash = (Get-FileHash -LiteralPath $liveProfilePath).Hash
if (-not $FactorioPath) {
    $liveProfile = Get-Content -LiteralPath $liveProfilePath -Raw | ConvertFrom-Json
    $FactorioPath = Join-Path $RepoRoot $liveProfile.engine_path
}
$versionText = (& $FactorioPath --version | Out-String)
if ($versionText -notmatch 'Version:\s*(2\.1\.[0-9]+)') { throw 'This storage adapter fixture needs a locally available Factorio 2.1 engine.' }
$actualVersion = $matches[1]
$fixture = Join-Path $RepoRoot ('output/core-adapter-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$checks = 0
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Write-TestJson([string]$Path, $Data) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, ($Data | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}
function Invoke-Core([string]$Task, [string]$RunRoot, [string[]]$Extra = @()) {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:runner -Task $Task -RunRoot $RunRoot @Extra)
    if ($LASTEXITCODE -ne 0) { throw "Core $Task failed: $($output -join [Environment]::NewLine)" }
}
try {
    & git -C $fixture init -q
    if ($LASTEXITCODE) { throw 'Could not initialize isolated core fixture.' }
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "/.factorio-qc/`n/output/`n")
    foreach ($relative in @('scripts/esir-dev-lib.ps1', 'scripts/esir-housekeeping.ps1', 'scripts/esir-qc-storage.ps1',
        'scripts/esir_qc_storage.py', 'scripts/esir-qc-version-staging.ps1', 'scripts/validate-esir-json.py',
        'scripts/qc/factorio-2.1/invoke-core.ps1')) {
        $destination = Join-Path $fixture $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath (Join-Path $RepoRoot $relative) -Destination $destination
    }
    $runner = Join-Path $fixture 'scripts/qc/factorio-2.1/invoke-core.ps1'
    $main = Join-Path $fixture 'exotic-space-industries-remembrance'
    Write-TestJson (Join-Path $main 'info.json') @{name='exotic-space-industries-remembrance';version='1.0.0';factorio_version='2.1'}
    [IO.File]::WriteAllText((Join-Path $main 'control.lua'), '-- authoritative fixture source')
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $main 'control.lua')).Hash
    $nsbc = Join-Path $fixture 'fixtures/nsbc'
    Write-TestJson (Join-Path $nsbc 'info.json') @{name='zzz-nonstandard-beacons-continued';version='1.0.0';factorio_version='2.1'}
    $companion = Join-Path $fixture 'fixtures/selected'
    Write-TestJson (Join-Path $companion 'info.json') @{name='esir-qc-selected';version='1.0.0';factorio_version='2.1'}
    [IO.File]::WriteAllText((Join-Path $companion 'control.lua'), '-- private helper fixture')
    $dependencyInfo = @{name='dependency-fixture';version='1.0.0';factorio_version='2.1'}
    $inputs = Join-Path $fixture 'inputs'
    [void][IO.Directory]::CreateDirectory($inputs)
    $archive = Join-Path $inputs 'dependency-fixture_1.0.0.zip'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $writer = [IO.StreamWriter]::new($zip.CreateEntry('dependency-fixture_1.0.0/info.json').Open())
        try { $writer.Write(($dependencyInfo | ConvertTo-Json)) } finally { $writer.Dispose() }
    } finally { $zip.Dispose() }
    $hash = (Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant()
    $seed = Join-Path $fixture '.factorio-qc/dependency-seeds/2.1-core'
    $lockPath = Join-Path $seed 'dependency-lock-2.1.json'
    Write-TestJson $lockPath @(@{name='dependency-fixture';version='1.0.0';file='dependency-fixture_1.0.0.zip';sha256=$hash;info=$dependencyInfo})
    Write-TestJson (Join-Path $seed 'mod-list.json') @{mods=@(@{name='base';enabled=$true})}
    [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action profile -Data @{name='development';packages=@(@{path=$archive;sha256=$hash})})
    $baseUri = [Uri]($fixture.TrimEnd('\') + '\')
    $engineRelative = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri([Uri]([IO.Path]::GetFullPath($FactorioPath))).ToString()).Replace('/', '\')
    Write-TestJson (Join-Path $fixture '.codex/esir/factorio-development.json') @{
        engine_version=$actualVersion;engine_path=$engineRelative;dependency_seed='.factorio-qc/dependency-seeds/2.1-core'
        dependency_lock_sha256=(Get-FileHash -LiteralPath $lockPath).Hash.ToLowerInvariant();nsbc_source='fixtures/nsbc'
        smoke_save_id='fixture';smoke_save='.factorio-qc/unused-fixture-save.zip'
    }
    $modes = @()
    foreach ($mode in @('read-only', 'private-mutable')) {
        $runRoot = Join-Path $fixture ('.factorio-qc/core-' + $mode)
        Invoke-Core stage $runRoot @('-FixtureRoot', $companion, '-Quality', 'disabled', '-SourceMode', $mode)
        $first = Get-Content -LiteralPath (Join-Path $runRoot 'context.json') -Raw | ConvertFrom-Json
        $initialList = Get-Content -LiteralPath (Join-Path $first.mod_view_root 'mod-list.json') -Raw | ConvertFrom-Json
        Assert (-not ($initialList.mods | Where-Object name -eq quality).enabled) 'Explicit disabled quality was lost'
        Assert (($initialList.mods | Where-Object name -eq 'esir-qc-selected').enabled) 'Selected fixture was not staged'
        $stagedMain = Get-Item -LiteralPath (Join-Path $first.mod_view_root 'exotic-space-industries-remembrance')
        Assert ([bool]($stagedMain.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq ($mode -eq 'read-only')) 'Source mutability was staged incorrectly'
        Invoke-Core stage $runRoot
        $second = Get-Content -LiteralPath (Join-Path $runRoot 'context.json') -Raw | ConvertFrom-Json
        Assert ($second.run_id -eq $first.run_id -and $second.mod_view_root -eq $first.mod_view_root) 'Repeated Stage created another mod view'
        Assert ($second.source_mode -eq $mode -and $second.options.quality -eq 'disabled') 'Repeated Stage lost inferred mode or quality'
        Assert (@($second.options.fixture_roots).Count -eq 1 -and $second.options.fixture_roots[0] -eq $companion) 'Repeated Stage lost its fixture selection'
        Invoke-Core close $runRoot
        $closed = Read-EsirArtifactRun $fixture $first.run_id
        Assert ($closed.cleanup_status -eq 'compacted') 'Core adapter did not compact its completed run'
        Assert (-not (Test-Path -LiteralPath $first.mod_view_root) -and -not (Test-Path -LiteralPath $first.scratch_root)) 'Core close left disposable setup or scratch'
        Assert (Test-Path -LiteralPath (Join-Path $runRoot 'evidence.zip')) 'Core close lost compact reproduction evidence'
        Assert ((Get-FileHash -LiteralPath (Join-Path $main 'control.lua')).Hash -eq $sourceHash) 'Core adapter changed authoritative source'
        $modes += @{source_mode=$mode;run_id=$first.run_id;reused=$true;closed=$true}
    }
    Assert (@(Get-ChildItem -LiteralPath $seed -File -Filter '*.zip').Count -eq 0) 'Manifest-only seed accumulated package copies'
    Assert ((Get-FileHash -LiteralPath $liveProfilePath).Hash -eq $liveProfileHash) 'Live development profile changed'
    $result = @{status='passed';checks=$checks;engine_version=$actualVersion;coverage='stage/reuse/close adapter mechanics';modes=$modes;live_profile_unchanged=$true;fixture_removed=$false}
    if (-not $KeepFixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $boundary = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'output')).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped output.' }
        if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Fixture contains links; retain for inspection.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $result.fixture_removed = $true
    }
    $result | ConvertTo-Json -Depth 5
} catch {
    Write-Warning "Core adapter fixture retained for inspection: $fixture"
    throw
}
