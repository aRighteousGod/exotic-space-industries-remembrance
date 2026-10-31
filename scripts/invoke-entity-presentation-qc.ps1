[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineDump,
    [string]$SeedDirectory,
    [string]$PreparedModDirectory,
    [string]$RunId,
    [switch]$Visual,
    [int]$Ticks = 11010,
    [int]$GraphicsTicks = 900
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$paths = Get-EsirPaths -RepoRoot $repo
$context = Get-EsirQcContext -Paths $paths -EnsureArtifactRoot
$baseline = (Resolve-Path -LiteralPath $BaselineDump).Path
if ($Ticks -lt 10803) { throw 'Ticks must cover the native Incinerator lifetime.' }
if ($GraphicsTicks -lt 300) { throw 'GraphicsTicks must allow the mine pre-roll and capture completion.' }
if ($RunId) {
    $run = Read-EsirArtifactRun $repo $RunId
    if ($run.status -ne 'running' -or -not $run.task_open) { throw 'RunId must refer to an open running task-owned payload.' }
} else {
    $versionText = (& $context.factorio_exe --version 2>&1 | Out-String)
    if ($versionText -notmatch 'Version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { throw 'Cannot resolve engine version.' }
    $payload = '.factorio-qc/ep-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $run = Register-EsirArtifactRun -RepoRoot $repo -Workflow 'entity-presentation' -Scenario 'new-entity-native-scenes' -EngineVersion $matches[1] -PayloadPath $payload -Reproduction 'invoke-entity-presentation-qc; data assertions and isolated exact native scenes'
}
[void](Initialize-EsirManagedQcContext -RepoRoot $repo -Context $context -RunId $run.id -SourceMode private-mutable)
# Runtime isolation changes control.lua in every enabled source mod.
$context | Add-Member -NotePropertyName mutable_source_names -NotePropertyValue @('*') -Force
if ($SeedDirectory) { $context.cache_seed_directories = @((Resolve-Path -LiteralPath $SeedDirectory).Path) }
$result = New-FactorioQCResult -Name 'entity-presentation'
$managed = [pscustomobject]@{run = $run; error = $null}
try {
    if ($PreparedModDirectory) {
        $mods = (Resolve-Path -LiteralPath $PreparedModDirectory).Path
        if ($mods -ne $context.mod_view_root) { throw 'Prepared mods must be this run''s managed private-mutable view; historical setups cannot be adopted.' }
        [void](Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$run.id})
        # Preserve runtime isolation but require the entire live gameplay Lua
        # source to match, so a retry cannot silently validate stale data code.
        $live = Join-Path $repo 'exotic-space-industries-remembrance'
        foreach ($source in Get-ChildItem -LiteralPath $live -Recurse -File -Filter '*.lua') {
            $relative = $source.FullName.Substring($live.Length + 1)
            if ($relative -eq 'control.lua') { continue }
            $staged = Join-Path (Join-Path $mods 'exotic-space-industries-remembrance') $relative
            if ((Get-FileHash -LiteralPath $source.FullName).Hash -ne (Get-FileHash -LiteralPath $staged).Hash) { throw "Stale prepared source: $relative" }
        }
    } else {
        $mods = Sync-FactorioRunMods -Context $context -Result $result
    }
    $fixtureSource = Join-Path $repo 'scripts/qc/entity-presentation'
    $helper = Join-Path $mods 'zzz-esir-entity-presentation-qc'
    New-Item -ItemType Directory -Path $helper -Force | Out-Null
    Get-ChildItem -LiteralPath $fixtureSource -File -Filter '*.lua' | Copy-Item -Destination $helper -Force
    Copy-Item -LiteralPath (Join-Path $fixtureSource 'info.json') -Destination $helper -Force
    "return {visual=false,ticks=$Ticks}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    $list = Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-esir-entity-presentation-qc')
    $list.mods += @{name = 'zzz-esir-entity-presentation-qc'; enabled = $true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    # The assertion/snapshot companion must run after every active data-final
    # modifier, including optional mods that do not depend on ESIR.
    $helperInfo = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
    $helperInfo.dependencies = @($list.mods | Where-Object { $_.enabled -and $_.name -ne 'zzz-esir-entity-presentation-qc' } | ForEach-Object name)
    $helperInfo | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
    & python -B (Join-Path $fixtureSource 'isolate-runtime.py') $mods --run-id $run.id |
        Set-Content -LiteralPath (Join-Path $context.artifact_root 'runtime-isolation.json') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw 'Runtime isolation failed.' }
    foreach ($file in @(
        'exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation.lua',
        'exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-machines.lua',
        'exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-combat.lua',
        'scripts/qc/entity-presentation/control.lua', 'scripts/qc/entity-presentation/data-final-fixes.lua'
    )) {
        if ($context.luac_exe) {
            & $context.luac_exe -p (Join-Path $repo $file)
            if ($LASTEXITCODE -ne 0) { throw "Lua syntax failed: $file" }
        }
    }
    $config = New-FactorioWriteDataConfig -Context $context -Label 'presentation'
    if ($Visual) {
        [IO.File]::AppendAllText($config.config_path, "`n[graphics]`nmax-sprite-loading-threads=2`nscreenshots-threads-count=2`n", [Text.UTF8Encoding]::new($false))
    }
    $save = Join-Path $config.write_data_dir 'fixture.zip'
    $created = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @('--create', $save, '--config', $config.config_path, '--mod-directory', $mods, '--disable-audio') -OutputPath (Join-Path $config.write_data_dir 'create.txt')
    if ($created.exit_code -ne 0) { throw "Engine data/create failed: $($config.write_data_dir)" }
    $marker = 'ESIR_PRESENTATION_FINAL_DATA '
    $snapshotLine = @($created.output | Where-Object { $_.Contains($marker) })
    if ($snapshotLine.Count -ne 1) { throw 'Missing unique final-data snapshot.' }
    $snapshot = Join-Path $context.artifact_root 'final-data.json'
    [IO.File]::WriteAllText($snapshot, $snapshotLine[0].Substring($snapshotLine[0].IndexOf($marker) + $marker.Length), [Text.UTF8Encoding]::new($false))
    # Headless ticks prove lifetime/steady behavior. Graphics ticks are a wall/
    # frame budget, so they independently report capture readiness.
    $benchmark = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @('--benchmark', $save, '--benchmark-ticks', "$Ticks", '--benchmark-runs', '1', '--config', $config.config_path, '--mod-directory', $mods, '--disable-audio', '--disable-migration-window') -OutputPath (Join-Path $config.write_data_dir 'benchmark.txt')
    if ($benchmark.exit_code -ne 0) { throw "Scene runtime failed: $($config.write_data_dir)" }
    $visualReport = @()
    if ($Visual) {
        "return {visual=true,ticks=$Ticks}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
        $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
        $arguments = @('--benchmark-graphics', ('"' + $save + '"'), '--benchmark-ticks', "$GraphicsTicks", '--benchmark-runs', '1',
            '--config', ('"' + $config.config_path + '"'), '--mod-directory', ('"' + $mods + '"'),
            '--disable-audio', '--window-size', '1280x720', '--disable-migration-window')
        $native = Start-Process -FilePath $context.factorio_exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $config.write_data_dir 'visual.txt') -RedirectStandardError (Join-Path $config.write_data_dir 'visual-error.txt')
        $null = $native.Handle
        try {
            $deadline = (Get-Date).AddMinutes(10)
            while (-not $native.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1; $native.Refresh() }
            if (-not $native.HasExited) { throw 'Scene graphics timed out.' }
            $native.WaitForExit(); $native.Refresh()
            if ($native.ExitCode -ne 0) { throw "Scene graphics failed: $($config.write_data_dir)" }
        } finally { if (-not $native.HasExited) { Stop-Process -Id $native.Id }; $native.Dispose() }
        $shots = @(Get-ChildItem -LiteralPath (Join-Path $config.write_data_dir 'script-output/presentation') -File -Filter '*.png')
        if ($shots.Count -ne 8) { throw 'Missing scene captures.' }
        Set-EsirQcSelectedEvidence -RepoRoot $repo -RunId $run.id -Paths @($shots.FullName)
        $visualReport = @('--visual-report', (Join-Path $config.write_data_dir 'script-output/presentation-visual.json'))
    }
    $runtime = Join-Path $config.write_data_dir 'script-output/presentation-runtime.json'
    $acceptance = Join-Path $context.artifact_root 'acceptance.json'
    & python -B (Join-Path $fixtureSource 'check.py') $snapshot --baseline-dump $baseline --runtime $runtime --output $acceptance @visualReport
    if ($LASTEXITCODE -ne 0) { throw 'Presentation preservation/runtime acceptance failed.' }
    $summary = [ordered]@{overall_status = 'ok'; validation = 'passed'; visual = $Visual.IsPresent; run_id = $run.id;
        snapshot = $snapshot; runtime = $runtime; acceptance = $acceptance; write_data = $config.write_data_dir; mod_directory = $mods}
    Write-EsirJson -Path (Join-Path $context.artifact_root 'engine-summary.json') -Data $summary
    # This is a selected fixture snapshot, not a full data.raw cache seed.
    $completion = Finish-EsirManagedQc -RepoRoot $repo -State $managed -ExitCode 0 -Result $summary
    if ($completion.status -ne 'success') { throw $completion.error }
    [void](Set-EsirArtifactRunState -RepoRoot $repo -RunId $run.id -Action close)
    $summary | ConvertTo-Json -Depth 4
} catch {
    $failure = [ordered]@{overall_status = 'failed'; reason = $_.Exception.Message; run_id = $run.id}
    [void](Finish-EsirManagedQc -RepoRoot $repo -State $managed -ExitCode 1 -Result $failure)
    throw
}
