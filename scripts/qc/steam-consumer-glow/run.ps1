[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunDirectory,
    [ValidateSet('baseline', 'on', 'off')][string]$Mode = 'on',
    [string]$SeedMods,
    [switch]$Visual
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$context = Get-EsirQcContext -Paths (Get-EsirPaths -RepoRoot $repo)
if ((& $context.factorio_exe --version | Out-String) -notmatch 'Version:\s*2\.0\.77') { throw 'Factorio 2.0.77 required.' }
$RunDirectory = (Resolve-Path -LiteralPath $RunDirectory).Path
$prepare = @('-B', (Join-Path $PSScriptRoot 'prepare.py'), $RunDirectory, $Mode)
if ($SeedMods) { $prepare += @('--seed', $SeedMods) }
if ($Visual) { $prepare += '--visual' }
& python @prepare
if ($LASTEXITCODE -ne 0) { throw 'Private staging failed.' }
$common = @('--config', (Join-Path $RunDirectory 'config.ini'), '--mod-directory', (Join-Path $RunDirectory 'm'), '--disable-audio', '--disable-migration-window')
$save = Join-Path $RunDirectory "$Mode.zip"
$created = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--create', $save) + $common) -OutputPath (Join-Path $RunDirectory "$Mode-create.txt")
if ($created.exit_code -ne 0) { throw "Engine create failed: $Mode-create.txt" }
if (-not $Visual) {
    $bench = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments (@('--benchmark', $save, '--benchmark-ticks', '650', '--benchmark-runs', '1') + $common) -OutputPath (Join-Path $RunDirectory "$Mode-runtime.txt")
    if ($bench.exit_code -ne 0) { throw "Native state check failed: $Mode-runtime.txt" }
} else {
    $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
    $arguments = @('--benchmark-graphics', $save, '--benchmark-ticks', '1100', '--benchmark-runs', '1', '--window-size', '1280x720') + $common
    $process = Start-Process -FilePath $context.factorio_exe -ArgumentList @($arguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $RunDirectory "$Mode-visual.txt") -RedirectStandardError (Join-Path $RunDirectory "$Mode-visual-error.txt")
    # Retain the handle before polling so Windows preserves the exit code.
    $null = $process.Handle
    try {
        $deadline = (Get-Date).AddMinutes(12)
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1; $process.Refresh() }
        if (-not $process.HasExited) { throw 'Graphics capture timed out.' }
        $process.WaitForExit(); $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "Graphics failed: $Mode-visual.txt" }
        $receipt = Get-Item -LiteralPath (Join-Path $RunDirectory "script-output/steam-glow/$Mode-visual.json")
        if ($receipt.LastWriteTime -lt $process.StartTime) { throw 'Missing fresh graphics receipt.' }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id }; $process.Dispose() }
}
Write-Output "Steam glow $Mode visual=$Visual passed: $RunDirectory"
