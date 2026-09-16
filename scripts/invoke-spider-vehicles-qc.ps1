[CmdletBinding()]
param([switch]$SkipDataCheck,[string]$SavePath,[switch]$Arachnophobia,[switch]$WithPatrols,[switch]$NativeCycling,[ValidateSet(0,100,500)][int]$PerformanceVehicles=0,[switch]$PerformanceCombat,[switch]$SaveFixture)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$mods = Join-Path $repo '.factorio-qc\fmqc\mods-live'
$run = Join-Path $repo '.factorio-qc\spider-vehicles-runtime'
New-Item -ItemType Directory -Path $run -Force | Out-Null
if (-not $SkipDataCheck) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'invoke-esir-dev.ps1') -Task qc-fast *> (Join-Path $run 'data-check.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Data check failed. See .factorio-qc/spider-vehicles-runtime/data-check.txt.' }
} else {
    $pack = Join-Path $repo 'exotic-space-industries-remembrance'
    $destination = Join-Path $mods 'exotic-space-industries-remembrance'
    Get-ChildItem -LiteralPath $pack -Force | Copy-Item -Destination $destination -Recurse -Force
}
$helper = Join-Path $mods 'zzz-esir-spider-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\spider-vehicles') | Copy-Item -Destination $helper -Force
Get-Content -LiteralPath (Join-Path $helper 'gui-instrument.lua') -Raw | Add-Content -LiteralPath (Join-Path $mods 'exotic-space-industries-remembrance\control.lua') -Encoding UTF8
if ($PerformanceVehicles -gt 0) {
    $modulePath=Join-Path $mods 'exotic-space-industries-remembrance\scripts\control\spider-vehicles.lua'
    $module=Get-Content -LiteralPath $modulePath -Raw
    $instrument=Get-Content -LiteralPath (Join-Path $helper 'selector-instrument.lua') -Raw
    $module.Replace("`nreturn model",("`n"+$instrument+"`nreturn model")) | Set-Content -LiteralPath $modulePath -Encoding UTF8
}
$arachnoValue = $Arachnophobia.IsPresent.ToString().ToLowerInvariant()
$smartValue = (-not $NativeCycling.IsPresent).ToString().ToLowerInvariant()
$combatValue = $PerformanceCombat.IsPresent.ToString().ToLowerInvariant()
$saveValue = $SaveFixture.IsPresent.ToString().ToLowerInvariant()
"return {arachnophobia=$arachnoValue,smart=$smartValue,performance=$PerformanceVehicles,combat=$combatValue,save_fixture=$saveValue}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
$listPath = Join-Path $mods 'mod-list.json'
$list = Get-Content -LiteralPath $listPath -Raw | ConvertFrom-Json
$originalList = Get-Content -LiteralPath $listPath -Raw
if ($WithPatrols) {
    foreach ($archive in @('SpidertronEnhancements_1.10.8.zip','SpidertronPatrols_2.6.4.zip')) {
        Copy-Item -LiteralPath (Join-Path $env:APPDATA "Factorio\mods\$archive") -Destination $mods -Force
        $name = $archive.Split('_')[0]
        $existing = @($list.mods | Where-Object name -eq $name)
        if ($existing.Count) { $existing[0].enabled=$true }
        else { $list.mods += [pscustomobject]@{name=$name;enabled=$true} }
    }
}
$entry = @($list.mods | Where-Object name -eq 'zzz-esir-spider-qc')
if ($entry.Count -eq 0) { $list.mods += [pscustomobject]@{name='zzz-esir-spider-qc';enabled=$true} }
else { $entry[0].enabled=$true }
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $listPath -Encoding UTF8
$configuration = Join-Path $run 'config.ini'
@("[path]", "read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data", "write-data=$run", "[other]", "check-updates=false") | Set-Content -LiteralPath $configuration -Encoding UTF8
$save = Join-Path $run 'spider-vehicles.zip'
$started = Get-Date
try {
    if ($SavePath) {
        $inputSave = (Resolve-Path -LiteralPath $SavePath).Path
        $save = Join-Path $run 'input-save.zip'
        if ($inputSave -ne $save) { Copy-Item -LiteralPath $inputSave -Destination $save -Force }
    }
    else {
        & $factorio --create $save --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw 'Fixture creation failed. See create.txt.' }
    }
    if ($SaveFixture) {
        # Benchmark mode intentionally does not write saves. Use a private local
        # server and stop only our process after the requested ZIP is complete.
        $serverSettings=Join-Path $run 'server-settings.json'
        $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name='ESIR isolated spider QC';$server.description='Disposable local acceptance fixture'
        $server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false
        $server.require_user_verification=$false
        $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverSettings -Encoding UTF8
        $mode=if ($NativeCycling) { 'native' } else { 'smart' }
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $savedPath=Join-Path $run "saves\spider-controls-$mode.zip"
        $arguments=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$serverSettings+'"'),'--port','34198','--config',('"'+$configuration+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server-stdout.txt') -RedirectStandardError (Join-Path $run 'server-stderr.txt')
        try {
            $ready=$false
            $deadline=(Get-Date).AddMinutes(4)
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
                if (Select-String -LiteralPath (Join-Path $run 'server-stdout.txt') -Pattern 'Error while running event|Hosting multiplayer game failed' -Quiet) { throw 'Server fixture failed. See server-stdout.txt.' }
                if ((Test-Path -LiteralPath $savedPath) -and (Get-Item -LiteralPath $savedPath).LastWriteTime -gt $started) {
                    try { $zip=[IO.Compression.ZipFile]::OpenRead($savedPath);$zip.Dispose();$ready=$true;break } catch { }
                }
                Start-Sleep -Milliseconds 500
                $process.Refresh()
            }
            if (-not $ready) { throw 'Server fixture did not save. See server-stdout.txt/server-stderr.txt.' }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    } else {
        & $factorio --benchmark $save --benchmark-ticks 650 --benchmark-runs 1 --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw 'Runtime fixture failed. See benchmark.txt.' }
    }
    $reportPath = Join-Path $run 'script-output\spider-vehicles-qc.json'
    if ((Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started) { throw 'Fixture did not write a fresh report.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($report.status.smart_setting -ne (-not $NativeCycling.IsPresent)) { throw 'Fixture startup mode differs from the requested mode.' }
    if ($PerformanceVehicles -gt 0) {
        $profile = Get-Content -LiteralPath (Join-Path $run 'script-output\spider-selector-profile.txt') -Raw
        $report.performance.profile | Add-Member -NotePropertyName elapsed -NotePropertyValue $profile.Trim() -Force
        $searchProfile=Get-Content -LiteralPath (Join-Path $run 'script-output\spider-search-profile.txt') -Raw
        $report.performance.profile | Add-Member -NotePropertyName searches -NotePropertyValue $searchProfile.Trim() -Force
        $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    }
    $report | ConvertTo-Json -Depth 12
    if (-not $report.all_pass) { throw 'Spider vehicle assertions failed.' }
} finally {
    $list = $originalList | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -eq 'zzz-esir-spider-qc') { $mod.enabled=$false } }
    if ($WithPatrols) {
        foreach ($name in @('SpidertronEnhancements','SpidertronPatrols')) {
            if (-not @($list.mods | Where-Object name -eq $name).Count) { $list.mods += [pscustomobject]@{name=$name;enabled=$false} }
        }
    }
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $listPath -Encoding UTF8
}
