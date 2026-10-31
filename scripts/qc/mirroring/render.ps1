[CmdletBinding()]
param([Parameter(Mandatory)][string]$Record)
$ErrorActionPreference='Stop'
$r=Get-Content -LiteralPath $Record -Raw | ConvertFrom-Json
$started=Get-Date
. (Join-Path $r.repo 'scripts/esir-dev-lib.ps1')
& python -B (Join-Path $PSScriptRoot 'prepare.py') $Record candidate enabled --visual
if ($LASTEXITCODE -ne 0) { throw 'Render preparation failed.' }
$config=Join-Path $r.write_data 'render-config.ini'
@"
[path]
write-data=$($r.write_data)
[other]
check-updates=false
[graphics]
full-screen=false
halt-rendering-when-minimized=false
max-sprite-loading-threads=2
screenshots-threads-count=2
cache-sprite-atlas=false
"@ | Set-Content -LiteralPath $config -Encoding UTF8
$common=@('--config',$config,'--mod-directory',$r.mods,'--disable-audio','--disable-migration-window')
$save=Join-Path $r.write_data 'render.zip'
$created=Invoke-NativeProcess -FilePath $r.engine -Arguments (@('--create',$save)+$common) -OutputPath (Join-Path $r.write_data 'render-create.log')
if ($created.exit_code -ne 0) { throw 'Render save failed.' }
$env:SteamAppId='427520'
$env:SteamGameId='427520'
$arguments=@('--benchmark-graphics',$save,'--benchmark-ticks','330','--benchmark-runs','1','--window-size','1280x720')+$common
$process=Start-Process -FilePath $r.engine -ArgumentList @($arguments | ForEach-Object {'"'+$_+'"'}) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $r.write_data 'render.log') -RedirectStandardError (Join-Path $r.write_data 'render-error.log')
$null=$process.Handle
try {
    while (-not $process.HasExited) { Start-Sleep -Seconds 1; $process.Refresh() }
    $process.WaitForExit()
    $process.Refresh()
    if ($process.ExitCode -ne 0) { throw 'Native rendering failed.' }
} finally { $process.Dispose() }
$receipt=Join-Path $r.write_data 'script-output/mirroring/render/receipt.json'
if (-not (Test-Path -LiteralPath $receipt)) { throw 'Missing graphical receipt.' }
if ((Get-Item -LiteralPath $receipt).LastWriteTime -lt $started) { throw 'Stale graphical receipt.' }
foreach ($file in Get-ChildItem (Split-Path $receipt) -Filter '*.png' | Where-Object { $_.Name -notlike 'review-*' }) {
    if ($file.LastWriteTime -lt $started) { throw "Stale capture: $($file.Name)" }
}
Write-Output $receipt
