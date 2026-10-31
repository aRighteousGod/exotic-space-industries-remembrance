# Managed core fixture. context.json records actual temporary paths; close after consumers.
[CmdletBinding()]
param(
    [ValidateSet('stage','dump','create','benchmark','close')][string]$Task = 'dump',
    [string]$RunRoot, [string]$Engine, [string]$DependencyRoot,
    [ValidateSet('enabled','disabled')][string]$Quality = 'enabled',
    [ValidateSet('read-only','private-mutable')][string]$SourceMode = 'read-only',
    [string]$Save, [string]$Tag, [int]$Ticks = 600,
    [string[]]$FixtureRoot = @(), [switch]$AirOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
. (Join-Path $repo 'scripts/esir-qc-storage.ps1')
$profile = Read-EsirJson (Join-Path $repo '.codex/esir/factorio-development.json')
$context = $null
if ($Task -ne 'close') { $context = Get-EsirQcContext -Paths (Get-EsirPaths $repo) -FactorioPath $Engine }
if (-not $DependencyRoot) { $DependencyRoot = Join-Path $repo $profile.dependency_seed }
if (-not $RunRoot) { $RunRoot = Join-Path $repo ('.factorio-qc/core-' + [guid]::NewGuid().ToString('N').Substring(0,8)) }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
$recordPath = Join-Path $RunRoot 'context.json'
$prior = $null
if (Test-Path -LiteralPath $RunRoot) {
    if (-not (Test-Path -LiteralPath $recordPath)) { throw 'Existing unmanaged RunRoot is protected; choose a new directory.' }
    $prior = Read-EsirJson $recordPath
    if (-not $PSBoundParameters.ContainsKey('SourceMode')) { $SourceMode = $prior.source_mode }
    if ($prior.PSObject.Properties.Name -contains 'options') {
        if (-not $PSBoundParameters.ContainsKey('FixtureRoot')) { $FixtureRoot = @($prior.options.fixture_roots) }
        if (-not $PSBoundParameters.ContainsKey('Quality')) { $Quality = $prior.options.quality }
        if (-not $PSBoundParameters.ContainsKey('AirOnly')) { $AirOnly = [switch]$prior.options.air_only }
        if (-not $PSBoundParameters.ContainsKey('DependencyRoot')) { $DependencyRoot = $prior.options.dependency_root }
    }
    $managed = Read-EsirArtifactRun $repo $prior.run_id
    if ($managed.workflow -ne 'core-2.1' -or (Join-Path $repo $managed.payload_path) -ne $RunRoot -or -not $managed.task_open) { throw 'RunRoot is not an open managed core fixture.' }
    if ($prior.source_mode -ne $SourceMode) { throw 'Cannot change mutability of an existing fixture.' }
} else {
    if ($Task -eq 'close') { throw 'Close requires an existing managed RunRoot.' }
    $managed = Register-EsirArtifactRun -RepoRoot $repo -Workflow 'core-2.1' -EngineVersion $profile.engine_version -PayloadPath $RunRoot -Reproduction "invoke-core.ps1 -Task $Task -RunRoot $RunRoot -SourceMode $SourceMode"
}
if ($Task -eq 'close') {
    $summary = @{run_id=$managed.id; workflow=$managed.workflow; engine_version=$managed.engine_version; repo_root=$repo; payload_path=$managed.payload_path; timestamp=[DateTime]::UtcNow.ToString('o'); overall_status=$prior.overall_status}
    $dumpArgs = @{}
    if ($prior.PSObject.Properties.Name -contains 'dump' -and (Test-Path -LiteralPath $prior.dump)) { $dumpArgs.DumpPath = $prior.dump }
    if ($managed.status -eq 'running') { $null = Complete-EsirArtifactRun -RepoRoot $repo -RunId $managed.id -ExitCode $(if($prior.overall_status -eq 'ok'){0}else{1}) -Summary $summary @dumpArgs }
    $closed = Set-EsirArtifactRunState -RepoRoot $repo -RunId $managed.id -Action close
    $closed | ConvertTo-Json -Depth 8
    if ($closed.cleanup_status -eq 'protected-error') { throw $closed.housekeeping_error }
    exit 0
}
[void](Initialize-EsirManagedQcContext -RepoRoot $repo -Context $context -RunId $managed.id -SourceMode $SourceMode)
$probe = New-FactorioWriteDataConfig -Context $context -Label 'version'
$version = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @('--version') -OutputPath (Join-Path $probe.write_data_dir 'version.log')
if ($version.exit_code -ne 0 -or ($version.output -join "`n") -notmatch ('Version:\s*' + [regex]::Escape($profile.engine_version) + '\s')) { throw 'Executable does not match the exact development engine.' }
$lockPath = Join-Path $DependencyRoot 'dependency-lock-2.1.json'
if ((Get-FileHash -LiteralPath $lockPath).Hash -ne $profile.dependency_lock_sha256) { throw 'Dependency lock does not match the development profile.' }
$packages = @()
foreach ($row in @(Read-EsirJson $lockPath)) {
    if ($row.info.factorio_version -ne '2.1') { throw 'Incompatible dependency family.' }
    if ($AirOnly -and $row.name -ne 'air-scrubber') { continue }
    $item = @{sha256=$row.sha256; name=$row.name; version=$row.version; factorio_version='2.1'}
    $oldArchive = Join-Path $DependencyRoot $row.file
    if (Test-Path -LiteralPath $oldArchive) { $item.path = $oldArchive }
    $packages += $item
}
$sources = @()
if (-not $AirOnly) {
    $selection = Select-EsirEngineSourceMods -Context $context
    foreach ($mod in $selection.included) { $sources += @{path=$mod.directory; name=$mod.name; mode=$SourceMode} }
    $nsbc = [IO.Path]::GetFullPath((Join-Path $repo $profile.nsbc_source))
    $nsbcInfo = Read-EsirJson (Join-Path $nsbc 'info.json')
    if ($nsbcInfo.name -ne 'zzz-nonstandard-beacons-continued' -or $nsbcInfo.version -ne '1.0.0' -or $nsbcInfo.factorio_version -ne '2.1') { throw 'NSBC source differs from the accepted continuation.' }
    $sources += @{path=$nsbc; name=$nsbcInfo.name; mode=$SourceMode}
}
foreach ($fixture in $FixtureRoot) {
    $path = (Resolve-Path -LiteralPath $fixture).Path
    $info = Read-EsirJson (Join-Path $path 'info.json')
    if ($info.factorio_version -ne '2.1' -or $info.name -notlike 'esir-qc-*') { throw 'Fixture must be a separate esir-qc-* mod targeting 2.1.' }
    $sources += @{path=$path; name=$info.name; mode='private-mutable'}
}
$enabled = @('base','space-age','quality','elevated-rails','recycler') + @($packages | ForEach-Object {$_.name}) + @($sources | ForEach-Object {$_.name})
$list = @{mods=@($enabled | Sort-Object -Unique | ForEach-Object { @{name=$_; enabled=($_ -ne 'quality' -or $Quality -eq 'enabled')} })}
$view = Invoke-EsirQcStorage -RepoRoot $repo -Action stage -Data @{run_id=$managed.id; packages=$packages; sources=$sources; mod_list=$list}
$config = New-FactorioWriteDataConfig -Context $context -Label 'core'
$manifest = @{run_id=$managed.id; source_mode=$SourceMode; mod_view_root=$view.mod_view_root; scratch_root=$view.scratch_root; write_data_root=$config.write_data_dir; config=$config.config_path; engine_version=$profile.engine_version; overall_status='ok'}
$manifest.options = @{fixture_roots=@($FixtureRoot | ForEach-Object {(Resolve-Path -LiteralPath $_).Path}); quality=$Quality; air_only=[bool]$AirOnly; dependency_root=[IO.Path]::GetFullPath($DependencyRoot)}
if ($prior) {
    $manifest.overall_status = $prior.overall_status
    foreach ($field in @('dump','dump_sha256','dump_bytes','dump_valid')) {
        if ($prior.PSObject.Properties.Name -contains $field) { $manifest[$field] = $prior.$field }
    }
}
Write-EsirJson -Path $recordPath -Data $manifest
if ($Task -eq 'stage') { $manifest | ConvertTo-Json; exit 0 }
if (-not $Tag) { $Tag = "$Task-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
if ($Tag -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid output tag.' }
$arguments = @('--config',$config.config_path,'--mod-directory',$view.mod_view_root,'--disable-audio')
switch ($Task) {
    'dump' { $arguments += '--dump-data' }
    'create' { if (-not $Save) { $Save = Join-Path $view.scratch_root 'fresh.zip' }; $arguments += @('--create',$Save) }
    'benchmark' { if (-not $Save) { $Save = Join-Path $view.scratch_root 'fresh.zip' }; $arguments += @('--benchmark',$Save,'--benchmark-ticks',"$Ticks",'--benchmark-runs','1') }
}
$process = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments $arguments -OutputPath (Join-Path $config.write_data_dir "$Tag.stdout.log")
$null = Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$managed.id}
if ($process.exit_code -ne 0) { $manifest.overall_status='failed' }
if ($Task -eq 'dump') {
    $dump = Join-Path $config.write_data_dir 'script-output/data-raw-dump.json'
    if ($process.exit_code -eq 0) { & python -B (Join-Path $repo 'scripts/validate-esir-json.py') $dump; if ($LASTEXITCODE -ne 0) { throw 'Invalid dump.' } }
    $manifest.dump = $dump
    if ($process.exit_code -eq 0) { $manifest.dump_sha256 = (Get-FileHash -LiteralPath $dump).Hash; $manifest.dump_bytes = (Get-Item -LiteralPath $dump).Length; $manifest.dump_valid = $true }
}
Write-EsirJson -Path $recordPath -Data $manifest
$manifest | ConvertTo-Json
exit $process.exit_code
