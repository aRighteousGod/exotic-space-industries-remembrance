[CmdletBinding()]
param([switch]$Baseline, [switch]$SaveBaseline, [string]$SaveInput)
$ErrorActionPreference = 'Stop'
if ($SaveBaseline -and -not $Baseline) { throw '-SaveBaseline requires -Baseline.' }
if ($SaveInput -and ($Baseline -or $SaveBaseline)) { throw '-SaveInput requires the fixed profile.' }
$repo = Split-Path -Parent $PSScriptRoot
$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$mode = if ($Baseline) { 'baseline' } else { 'fixed' }
if ($SaveInput) { $mode += '-loaded' }
$run = Join-Path $repo ".factorio-qc\railgun-cooling\$mode"
$mods = Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed = Join-Path $repo '.factorio-qc\fmqc\mods-live'
foreach ($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip') {
    $destination = Join-Path $mods $archive.Name
    if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null }
}
foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
    $destination = Join-Path $mods $directory.Name
    if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null }
}
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
$helper = Join-Path $mods 'zzz-esir-railgun-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\railgun-cooling') -File | Copy-Item -Destination $helper -Force
"return {save_baseline=$($SaveBaseline.IsPresent.ToString().ToLowerInvariant()),load_baseline=$(([bool]$SaveInput).ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
Get-Content -LiteralPath (Join-Path $helper 'instrument.lua') -Raw | Add-Content -LiteralPath (Join-Path $pack 'control.lua') -Encoding UTF8
if ($Baseline) {
    Remove-Item -LiteralPath (Join-Path $pack 'migrations\1.3.40.lua')
    $prototype = Join-Path $pack 'scripts\data-updates\railgun-cooling.lua'
    $source = Get-Content -LiteralPath $prototype -Raw
    $source.Replace('"no-automated-item-insertion",', '').Replace('"no-automated-item-removal",', '') | Set-Content -LiteralPath $prototype -Encoding UTF8
}
$list = Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark') { $mod.enabled = $false } }
$list.mods += @{name = 'zzz-esir-railgun-qc'; enabled = $true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config = Join-Path $run 'config.ini'
@('[path]', 'read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data', "write-data=$run", '[other]', 'check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
$save = Join-Path $run 'fixture.zip'
if ($SaveInput) { Copy-Item -LiteralPath $SaveInput -Destination $save -Force }
else {
& $factorio --create $save --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw "Fixture creation failed: $run\create.txt" }
}
if ($SaveBaseline) {
    $server = Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
    $server.name = 'ESIR isolated railgun QC'
    $server.auto_pause = $false
    $server.visibility.public = $false
    $server.visibility.lan = $false
    $server.require_user_verification = $false
    $settings = Join-Path $run 'server-settings.json'
    $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $settings -Encoding UTF8
    $saved = Join-Path $run 'saves\railgun-baseline.zip'
    New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
    $started = Get-Date
    $arguments = @('--start-server', ('"' + $save + '"'), '--server-settings', ('"' + $settings + '"'), '--port', '34198', '--config', ('"' + $config + '"'), '--mod-directory', ('"' + $mods + '"'), '--disable-audio')
    $process = Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.txt') -RedirectStandardError (Join-Path $run 'server-error.txt')
    try {
        $ready = $false
        $deadline = (Get-Date).AddMinutes(3)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            if ((Test-Path -LiteralPath $saved) -and (Get-Item -LiteralPath $saved).LastWriteTime -gt $started) {
                try { $zip = [IO.Compression.ZipFile]::OpenRead($saved); $zip.Dispose(); $ready = $true; break } catch { }
            }
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }
        if (-not $ready) { throw "Baseline save failed: $run\server.txt" }
        Write-Output "Baseline save: $saved"
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    exit
}
& $factorio --benchmark $save --benchmark-ticks 605 --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw "Fixture runtime failed: $run\benchmark.txt" }
$report = Get-Content -LiteralPath (Join-Path $run 'script-output\railgun-qc.json') -Raw | ConvertFrom-Json
$checked = if ($SaveInput) { $report.loaded } else { $report.initial }
@{ mode = $mode; all_pass = $report.all_pass; cases = $checked.cases; wrong_targets = $checked.wrong_target_count; empty_turrets = $checked.empty_turrets; fluids = $report.fluids } | ConvertTo-Json -Depth 6
if ($Baseline) {
    if ($report.initial.wrong_target_count -eq 0) { throw 'Baseline did not reproduce incorrect targeting.' }
} elseif (-not $report.all_pass) { throw "Railgun acceptance failed: $run\script-output\railgun-qc.json" }
