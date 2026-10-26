[CmdletBinding()]
param(
    [ValidateSet('Stage', 'Data', 'Runtime', 'Visual', 'Finish')][string]$Phase = 'Stage',
    [string]$RunDirectory,
    [string]$PreparedMods,
    [string]$SeedMods,
    [ValidateSet('all', 'smelters')][string]$Focus = 'all',
    [ValidateSet('absent', 'disabled', 'enabled', 'custom')][string]$Bottleneck = 'absent',
    [switch]$TransitionsOnly,
    [ValidateSet('original', 'off', 'static', 'soft', 'reduced')][string]$ArcPreset = 'original',
    [ValidateSet('baseline', 'original', 'status', 'off')][string]$Mode = 'status'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$paths = Get-EsirPaths -RepoRoot $repo
$context = Get-EsirQcContext -Paths $paths -EnsureArtifactRoot
$utf8 = [Text.UTF8Encoding]::new($false)
$fixture = Join-Path $repo 'scripts/qc/machine-status-lights'
if ($Phase -eq 'Stage') {
    $version = (& $context.factorio_exe --version | Out-String)
    if ($version -notmatch 'Version:\s*(2\.0\.77)') { throw 'This fixture requires Factorio 2.0.77.' }
    $payload = '.factorio-qc/ml-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $run = Register-EsirArtifactRun -RepoRoot $repo -Workflow 'machine-status-lights' -Scenario "$Focus-startup-modes" -EngineVersion '2.0.77' -PayloadPath $payload -Reproduction 'scripts/invoke-machine-status-light-qc.ps1: Stage, Data baseline/original/status/off, Visual status, Finish; smelter focus also covers all ArcPreset values'
    $RunDirectory = Join-Path $repo $run.payload_path
    New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null
    & python -B (Join-Path $repo '.codex/esir/asset-generators/machine-status-lights/generate.py') --output (Join-Path $RunDirectory 'lens-art')
    if ($LASTEXITCODE -ne 0) { throw 'Reproducible lens-mask extraction failed.' }
    & python -B (Join-Path $fixture 'check-masks.py') $RunDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Shipping lens masks differ from reproducible extraction.' }
    $mods = Join-Path $RunDirectory 'm'
    if ($SeedMods) {
        & python -B (Join-Path $fixture 'stage.py') $SeedMods $mods
        if ($LASTEXITCODE -ne 0) { throw 'Read-only dependency seed copy failed.' }
    } elseif ($PreparedMods) {
        $source = (Resolve-Path -LiteralPath $PreparedMods).Path
        $boundary = [IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc')) + [IO.Path]::DirectorySeparatorChar
        if (-not $source.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Prepared mods must be task-owned private QC staging.' }
        # Short alias avoids Factorio's long require paths without another asset copy.
        New-Item -ItemType Junction -Path $mods -Target $source | Out-Null
    } else {
        $context.artifact_root = $RunDirectory
        $context.run_mod_directory = $mods
        $result = New-FactorioQCResult -Name 'machine-status-lights'
        $null = Sync-FactorioRunMods -Context $context -Result $result
    }
    $pack = Join-Path $mods 'exotic-space-industries-remembrance'
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $entrypoints = Join-Path $RunDirectory 'entrypoints'
    New-Item -ItemType Directory -Path $entrypoints -Force | Out-Null
    foreach ($entry in @('data-updates.lua', 'data-final-fixes.lua')) {
        Copy-Item -LiteralPath (Join-Path $pack $entry) -Destination $entrypoints
    }
    $helper = Join-Path $mods 'zzz-esir-machine-lights-qc'
    New-Item -ItemType Directory -Path $helper -Force | Out-Null
    Get-ChildItem -LiteralPath $fixture -File | Where-Object Extension -in '.lua', '.json' | Copy-Item -Destination $helper -Force
    $list = Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-esir-machine-lights-qc') + @{name = 'zzz-esir-machine-lights-qc'; enabled = $true}
    [IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 8), $utf8)
    $info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
    $info.dependencies = @($list.mods | Where-Object { $_.enabled -and $_.name -ne $info.name } | ForEach-Object name)
    [IO.File]::WriteAllText((Join-Path $helper 'info.json'), ($info | ConvertTo-Json -Depth 5), $utf8)
    & python -B (Join-Path $fixture 'isolate.py') $mods | Set-Content (Join-Path $RunDirectory 'isolation.json') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw 'Private runtime isolation failed.' }
    [IO.File]::WriteAllText((Join-Path $RunDirectory 'run-id.txt'), $run.id, $utf8)
    [IO.File]::WriteAllText((Join-Path $RunDirectory 'config.ini'), "[path]`nwrite-data=$RunDirectory`n[other]`ncheck-updates=false`n[graphics]`nfull-screen=false`nhalt-rendering-when-minimized=false`nmax-sprite-loading-threads=2`nscreenshots-threads-count=2`ncache-sprite-atlas=false`n", $utf8)
    Write-Output $RunDirectory
    return
}
$RunDirectory = (Resolve-Path -LiteralPath $RunDirectory).Path
$boundary = [IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc')) + [IO.Path]::DirectorySeparatorChar
if (-not $RunDirectory.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Run must be private QC staging.' }
$runId = Get-Content -LiteralPath (Join-Path $RunDirectory 'run-id.txt') -Raw
if ($Phase -eq 'Finish') {
    if ($Focus -eq 'smelters') {
        & python -B (Join-Path $fixture 'check-smelters.py') $RunDirectory
    } else {
        & python -B (Join-Path $fixture 'check.py') (Join-Path $RunDirectory 'script-output')
    }
    if ($LASTEXITCODE -ne 0) { throw 'Machine status light acceptance failed.' }
    $reviews = if ($Focus -eq 'smelters') { @('review-smelters.py') } else { @('check-masks.py', 'check-bottleneck.py', 'check-smelters.py', 'review.py', 'calibrate.py', 'gallery.py', 'review-edges.py', 'review-smelters.py') }
    foreach ($review in $reviews) {
        & python -B (Join-Path $fixture $review) $RunDirectory
        if ($LASTEXITCODE -ne 0) { throw "Machine lighting review failed: $review" }
    }
    $summaryName = if ($Focus -eq 'smelters') { 'smelter-acceptance.json' } else { 'acceptance.json' }
    $summary = Get-Content -LiteralPath (Join-Path $RunDirectory ("script-output/machine-lights/" + $summaryName)) -Raw | ConvertFrom-Json
    if ($Focus -eq 'all') {
        foreach ($receipt in @('bottleneck-acceptance', 'smelter-acceptance')) {
            $details = Get-Content -LiteralPath (Join-Path $RunDirectory "script-output/machine-lights/$receipt.json") -Raw | ConvertFrom-Json
            $summary | Add-Member -NotePropertyName $receipt -NotePropertyValue $details
        }
    }
    $managed = [pscustomobject]@{run = (Read-EsirArtifactRun $repo $runId); error = $null}
    $result = Finish-EsirManagedQc -RepoRoot $repo -State $managed -ExitCode 0 -Result $summary
    if ($result.status -ne 'success') { throw $result.error }
    [void](Set-EsirArtifactRunState -RepoRoot $repo -RunId $runId -Action close)
    return
}
$mods = Join-Path $RunDirectory 'm'
$helper = Join-Path $mods 'zzz-esir-machine-lights-qc'
foreach ($relative in @('lib/machine-status-light-config.lua', 'lib/machine-status-light-definitions.lua', 'scripts/data-updates/machine-status-lights.lua', 'scripts/data-final-updates/machine-status-lights.lua', 'settings.lua')) {
    Copy-Item -LiteralPath (Join-Path (Join-Path $repo 'exotic-space-industries-remembrance') $relative) -Destination (Join-Path (Join-Path $mods 'exotic-space-industries-remembrance') $relative) -Force
}
Get-ChildItem -LiteralPath $fixture -File -Filter '*.lua' | Copy-Item -Destination $helper -Force
foreach ($language in @('en', 'de', 'fr', 'ja', 'pl', 'ru', 'zh-CN', 'zh-TW')) {
    $relative = "locale/$language/machine-status-lights.cfg"
    Copy-Item -LiteralPath (Join-Path (Join-Path $repo 'exotic-space-industries-remembrance') $relative) -Destination (Join-Path (Join-Path $mods 'exotic-space-industries-remembrance') $relative) -Force
}
$art = Join-Path $repo 'exotic-space-industries-remembrance/graphics/status-lights'
if (Test-Path -LiteralPath $art) {
    $targetArt = Join-Path $mods 'exotic-space-industries-remembrance/graphics/status-lights'
    New-Item -ItemType Directory -Path $targetArt -Force | Out-Null
    Get-ChildItem -LiteralPath $art -File | Copy-Item -Destination $targetArt -Force
}
$list = Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods = @($list.mods | Where-Object name -ne 'BottleneckLite')
if ($Bottleneck -eq 'absent') { $list.mods += @{name='BottleneckLite'; enabled=$false} }
if ($Bottleneck -ne 'absent') {
    $archive = Join-Path $env:APPDATA 'Factorio/mods/BottleneckLite_1.3.4.zip'
    Copy-Item -LiteralPath $archive -Destination (Join-Path $mods 'BottleneckLite_1.3.4.zip') -Force
    $list.mods += @{name='BottleneckLite'; enabled=$true; version='1.3.4'}
    Copy-Item -LiteralPath (Join-Path $env:APPDATA 'Factorio/mods/flib_0.16.5.zip') -Destination (Join-Path $mods 'flib_0.16.5.zip') -Force
    $list.mods = @($list.mods | Where-Object name -ne 'flib') + @{name='flib'; enabled=$true; version='0.16.5'}
}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 8), $utf8)
$info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
$info.dependencies = @($list.mods | Where-Object { $_.enabled -and $_.name -ne $info.name } | ForEach-Object name)
[IO.File]::WriteAllText((Join-Path $helper 'info.json'), ($info | ConvertTo-Json -Depth 5), $utf8)
$final = Get-Content -LiteralPath (Join-Path $RunDirectory 'entrypoints/data-final-fixes.lua') -Raw
$updates = Get-Content -LiteralPath (Join-Path $RunDirectory 'entrypoints/data-updates.lua') -Raw
if ($Mode -eq 'baseline') {
    $final = $final.Replace('require("scripts/data-final-updates/machine-status-lights")', '-- Baseline: status-light finalizer disabled only in private staging.')
    $updates = $updates.Replace('require("scripts/data-updates/machine-status-lights")', '-- Baseline: early compatibility hook disabled only in private staging.')
}
[IO.File]::WriteAllText((Join-Path $mods 'exotic-space-industries-remembrance/data-final-fixes.lua'), $final, $utf8)
[IO.File]::WriteAllText((Join-Path $mods 'exotic-space-industries-remembrance/data-updates.lua'), $updates, $utf8)
$visual = ($Phase -eq 'Visual').ToString().ToLowerInvariant()
$lightingProfile = if ($ArcPreset -eq 'original') { $Mode } else { "$ArcPreset-$Mode" }
if ($Bottleneck -ne 'absent') { $lightingProfile = "bnl-$Bottleneck-$lightingProfile" }
$transitionCapture = $TransitionsOnly.ToString().ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'), "return {mode='$Mode',visual=$visual,focus='$Focus',arc='$ArcPreset',profile='$lightingProfile',bottleneck='$Bottleneck',transitions_only=$transitionCapture}", $utf8)
$save = Join-Path $RunDirectory "$lightingProfile.zip"
$arguments = @('--config', (Join-Path $RunDirectory 'config.ini'), '--mod-directory', $mods, '--disable-audio', '--disable-migration-window')
if ($Phase -in @('Data', 'Runtime')) {
    if ($Phase -eq 'Data') {
        $created = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--create', $save) + $arguments) -OutputPath (Join-Path $RunDirectory "$lightingProfile-create.txt")
        if ($created.exit_code -ne 0) { throw "Data/create failed: $lightingProfile-create.txt" }
    }
    $bench = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--benchmark', $save, '--benchmark-ticks', '1000', '--benchmark-runs', '1') + $arguments) -OutputPath (Join-Path $RunDirectory "$lightingProfile-runtime.txt")
    if ($bench.exit_code -ne 0) { throw "Runtime failed: $lightingProfile-runtime.txt" }
} else {
    $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
    # Leave room after the final simulation transition at tick 960. The fixture
    # disables Freeplay's intro modal, which otherwise pauses graphical playback.
    $arguments = @('--benchmark-graphics', $save, '--benchmark-ticks', '1600', '--benchmark-runs', '1', '--window-size', '1280x720') + $arguments
    $process = Start-Process -FilePath $context.factorio_exe -ArgumentList @($arguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RunDirectory "$lightingProfile-visual.txt") -RedirectStandardError (Join-Path $RunDirectory "$lightingProfile-visual-error.txt")
    [IO.File]::WriteAllText((Join-Path $RunDirectory "$lightingProfile-visual-process.json"), (@{id=$process.Id; started_at=$process.StartTime.ToUniversalTime().ToString('o')} | ConvertTo-Json -Compress), $utf8)
    $null = $process.Handle
    try {
        $deadline = (Get-Date).AddMinutes(12)
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 1
            $process.Refresh()
            if (-not $process.HasExited -and $process.MainWindowTitle -eq 'Error') { throw "Factorio graphics error: $lightingProfile-visual.txt" }
        }
        if (-not $process.HasExited) { throw 'Graphics capture timed out.' }
        $process.WaitForExit(); $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "Graphics failed: $lightingProfile-visual.txt" }
        $transitionReport = Get-Item -LiteralPath (Join-Path $RunDirectory "script-output/machine-lights/$lightingProfile-transitions.json")
        if ($transitionReport.LastWriteTime -lt $process.StartTime) { throw 'Graphics quit before the final transition evidence was written.' }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id }; $process.Dispose() }
}
Write-Output "Machine lighting $Phase $lightingProfile finished: $RunDirectory"
