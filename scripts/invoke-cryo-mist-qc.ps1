[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet('Data', 'Runtime', 'Reload', 'Visual', 'Check')][string]$Phase = 'Runtime',
    [ValidateSet('baseline', 'current')][string]$Mode = 'current'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
$context = Get-EsirQcContext -Paths (Get-EsirPaths -RepoRoot $repo)
$RunDirectory = (Resolve-Path -LiteralPath $RunDirectory).Path
if (-not $RunDirectory.StartsWith((Join-Path $repo '.factorio-qc') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Private QC directory required.' }
if ((& $context.factorio_exe --version | Out-String) -notmatch 'Version:\s*2\.0\.77') { throw 'Factorio 2.0.77 required.' }
$fixture = Join-Path $repo 'scripts/qc/cryo-mist'
if ($Phase -eq 'Check') {
    & python -B (Join-Path $fixture 'check.py') $RunDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Cold mist acceptance failed.' }
    return
}
$profile = if ($Phase -eq 'Visual') { 'visual' } elseif ($Phase -eq 'Reload') { 'reload' } else { $Mode }
& python -B (Join-Path $fixture 'prepare.py') $RunDirectory $profile
if ($LASTEXITCODE -ne 0) { throw 'Private staging failed.' }
$argsCommon = @('--config', (Join-Path $RunDirectory 'config.ini'), '--mod-directory', (Join-Path $RunDirectory 'm'), '--disable-audio', '--disable-migration-window')
$save = Join-Path $RunDirectory "$Mode.zip"
if ($Phase -eq 'Reload') { $save = Join-Path $RunDirectory 'saves/cryo-mist-reload.zip' }
if ($Phase -eq 'Data') {
    $result = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--create', $save) + $argsCommon) -OutputPath (Join-Path $RunDirectory "$Mode-create.txt")
} elseif ($Phase -eq 'Runtime') {
    # Benchmark mode suppresses saves. A private localhost server supplies an
    # actual mid-operation checkpoint, then the Reload phase opens that archive.
    $serverSettings = Join-Path $RunDirectory 'server-settings.json'
    $server = Get-Content -LiteralPath (Join-Path (Split-Path $context.factorio_exe) '../../data/server-settings.example.json') -Raw | ConvertFrom-Json
    $server.name = 'ESIR cold mist QC'
    $server.visibility.public = $false; $server.visibility.lan = $false
    $server.auto_pause = $false; $server.require_user_verification = $false
    [IO.File]::WriteAllText($serverSettings, ($server | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $receipt = Join-Path $RunDirectory 'script-output/cryo-mist/current-runtime.json'
    if (Test-Path -LiteralPath $receipt) { Remove-Item -LiteralPath $receipt }
    $arguments = @('--start-server', $save, '--server-settings', $serverSettings, '--bind', '127.0.0.1', '--port', '34219') + $argsCommon
    $process = Start-Process -FilePath $context.factorio_exe -ArgumentList @($arguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RunDirectory 'current-server.txt') -RedirectStandardError (Join-Path $RunDirectory 'current-server-error.txt')
    try {
        $deadline = (Get-Date).AddMinutes(4)
        while (-not $process.HasExited -and -not (Test-Path -LiteralPath $receipt) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1; $process.Refresh() }
        if (-not (Test-Path -LiteralPath $receipt)) { throw 'Native server fixture did not complete; inspect current-server.txt.' }
        if (-not (Test-Path -LiteralPath (Join-Path $RunDirectory 'saves/cryo-mist-reload.zip'))) { throw 'Native checkpoint missing.' }
        $result = @{exit_code = 0}
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id }; $process.Dispose() }
} elseif ($Phase -eq 'Reload') {
    $result = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--benchmark', $save, '--benchmark-ticks', '1250', '--benchmark-runs', '1') + $argsCommon) -OutputPath (Join-Path $RunDirectory "$profile-runtime.txt")
} else {
    # Each rendered receipt must belong to this run, never an earlier attempt.
    $captureRoot = Join-Path $RunDirectory 'script-output/cryo-mist'
    foreach ($folder in @('loop', 'states', 'transitions', 'preview')) {
        $capturePath = [IO.Path]::GetFullPath((Join-Path $captureRoot $folder))
        if (-not $capturePath.StartsWith($RunDirectory + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Capture cleanup escaped the private run.' }
        if (Test-Path -LiteralPath $capturePath) {
            Get-ChildItem -LiteralPath $capturePath -File -Filter '*.png' | Remove-Item
        }
    }
    $visualReceipt = Join-Path $captureRoot 'visual-runtime.json'
    if (Test-Path -LiteralPath $visualReceipt) { Remove-Item -LiteralPath $visualReceipt }
    $visualError = Join-Path $captureRoot 'visual-error.json'
    if (Test-Path -LiteralPath $visualError) { Remove-Item -LiteralPath $visualError }
    $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
    # Graphics benchmarking counts rendered work differently from headless ticks.
    # Leave enough room for screenshot stalls and the final native-state receipt.
    $arguments = @('--benchmark-graphics', $save, '--benchmark-ticks', '3000', '--benchmark-runs', '1', '--window-size', '1280x720') + $argsCommon
    $process = Start-Process -FilePath $context.factorio_exe -ArgumentList @($arguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RunDirectory 'visual.txt') -RedirectStandardError (Join-Path $RunDirectory 'visual-error.txt')
    $null = $process.Handle
    [IO.File]::WriteAllText((Join-Path $RunDirectory 'visual-process.json'), (@{pid=$process.Id; started=$process.StartTime.ToString('o')} | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    try {
        $deadline = (Get-Date).AddMinutes(12)
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 1; $process.Refresh()
            if (Test-Path -LiteralPath $visualError) { throw (Get-Content -LiteralPath $visualError -Raw) }
            if (Select-String -LiteralPath (Join-Path $RunDirectory 'visual.txt') -Pattern 'Error ModManager|Error AtlasBuilder|Failed to load mods:' -Quiet) { throw 'Graphics prototype error; inspect visual.txt.' }
            if (-not $process.HasExited -and $process.MainWindowTitle -eq 'Error') { throw 'Graphics error; inspect visual.txt.' }
        }
        if (-not $process.HasExited) { throw 'Graphics timed out.' }
        $process.WaitForExit()
        $result = @{exit_code = $process.ExitCode}
        if (-not (Test-Path -LiteralPath $visualReceipt)) { throw 'Graphics exited before the native fixture completed; inspect visual.txt.' }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id }; $process.Dispose() }
}
if ($result.exit_code -ne 0) { throw "Cold mist $Phase failed; inspect $RunDirectory." }
Write-Output "Cold mist $Phase $profile passed: $RunDirectory"
