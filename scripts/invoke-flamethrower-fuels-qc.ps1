[CmdletBinding()]
param([switch]$Proof,[switch]$CreationProof,[switch]$Disabled,[ValidateRange(1,100)][int]$Budget=10,[ValidateSet(0,100,500,1000)][int]$Performance=0,[switch]$Transition,[string]$SaveInput,[switch]$Combat,[switch]$Client,[switch]$FuelMatrix,[switch]$Effects,[switch]$Overlap,[ValidateSet('original','2x','4x','8x','16x')][string]$Profile='original')
$ErrorActionPreference='Stop'
if ($Combat -and -not $SaveInput) { throw 'Native player combat requires -SaveInput pointing to a disposable copy of a save containing a player.' }
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
if (-not ($Proof -or $CreationProof)) {
    $mode=if ($Disabled) {'disabled'} else {'enabled'}
    if ($Transition) {
        $mode=if ($Disabled) {'off'} else {'on'}
        $mode+=if ($SaveInput) {'-load'} else {'-save'}
    }
    if ($Combat) { $mode+='-combat' }
    if ($FuelMatrix) { $mode+='-matrix' }
    if ($Effects) { $mode+='-effects' }
    if ($Overlap) { $mode+="-overlap-$Profile" }
    $run=Join-Path $repo ".factorio-qc\flamethrower-fuels\$mode-$Budget-$Performance"
    # Keep the staged pack below Windows PowerShell's legacy path-length limit.
    if ($Overlap) { $run=Join-Path $repo ('.factorio-qc\fov\'+$(if ($Disabled) {'off'} else {'on'})+"-$Profile") }
    $mods=Join-Path $run 'mods'
    New-Item -ItemType Directory -Path $mods -Force | Out-Null
    $seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
    foreach ($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip') {
        $destination=Join-Path $mods $archive.Name
        if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null }
    }
    foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
        $destination=Join-Path $mods $directory.Name
        if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null }
    }
    $pack=Join-Path $mods 'exotic-space-industries-remembrance'
    New-Item -ItemType Directory -Path $pack -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $helper=Join-Path $mods 'zzz-esir-flamethrower-qc'
    New-Item -ItemType Directory -Path $helper -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\flamethrower-fuels') -File | Copy-Item -Destination $helper -Force
    $enabled=(-not $Disabled.IsPresent).ToString().ToLowerInvariant()
    $transitionValue=$Transition.IsPresent.ToString().ToLowerInvariant()
    $combatValue=$Combat.IsPresent.ToString().ToLowerInvariant()
    $matrixValue=$FuelMatrix.IsPresent.ToString().ToLowerInvariant()
    $effectsValue=$Effects.IsPresent.ToString().ToLowerInvariant()
    $visualValue=$Client.IsPresent.ToString().ToLowerInvariant()
    $overlapValue=$Overlap.IsPresent.ToString().ToLowerInvariant()
    "return {enabled=$enabled,budget=$Budget,performance=$Performance,transition=$transitionValue,combat=$combatValue,matrix=$matrixValue,effects=$effectsValue,visual=$visualValue,overlap=$overlapValue,profile='$Profile'}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    Get-Content -LiteralPath (Join-Path $helper 'instrument.lua') -Raw | Add-Content -LiteralPath (Join-Path $pack 'control.lua') -Encoding UTF8
    $modulePath=Join-Path $pack 'scripts\control\flamethrower-fuels.lua'
    $module=Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
    $instrumentation=Get-Content -LiteralPath (Join-Path $helper 'performance-instrument.lua') -Raw -Encoding UTF8
    $module=$module.Replace('return model',($instrumentation+"`nreturn model"))
    $module.Replace('assert(source.fluids_count==candidate.fluids_count', 'assert(not storage.ei.flame_qc_fail,"injected-rollback"); assert(source.fluids_count==candidate.fluids_count') | Set-Content -LiteralPath $modulePath -Encoding UTF8
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    # Cached optional mods may predate the checkout's current incompatibilities.
    $incompatible=@{}
    foreach ($dependency in (Get-Content -LiteralPath (Join-Path $pack 'info.json') -Raw | ConvertFrom-Json).dependencies) {
        if ($dependency -match '^!\s*(\S+)') { $incompatible[$Matches[1]]=$true }
    }
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $incompatible.ContainsKey($mod.name)) { $mod.enabled=$false } }
    $list.mods+=@{name='zzz-esir-flamethrower-qc';enabled=$true}
    $list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    $config=Join-Path $run 'config.ini'
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
    $save=Join-Path $run 'fixture.zip'
    $started=Get-Date
    if ($SaveInput) { Copy-Item -LiteralPath $SaveInput -Destination $save -Force }
    else {
        & $factorio --create $save --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw "Fixture creation failed: $run\create.txt" }
    }
    $ticks=if ($Performance -gt 0) {4925*16} else {620}
    if ($Combat) { $ticks=21605 }
    if ($Effects) { $ticks=6600 }
    if ($Client) {
        $reportPath=Join-Path $run 'script-output\flamethrower-qc.json'
        $started=Get-Date
        # Keep Steam's restart helper from discarding this isolated run's arguments.
        '427520' | Set-Content -LiteralPath (Join-Path $run 'steam_appid.txt') -Encoding ASCII
        $arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks',"$ticks",'--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'client.txt') -RedirectStandardError (Join-Path $run 'client-error.txt')
        try {
            $ready=$false
            $deadline=(Get-Date).AddMinutes(8)
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
                if ((Test-Path -LiteralPath $reportPath) -and (Get-Item -LiteralPath $reportPath).LastWriteTime -gt $started) { $ready=$true;break }
                if (Test-Path -LiteralPath (Join-Path $run 'client.txt')) {
                    if (Select-String -LiteralPath (Join-Path $run 'client.txt') -Pattern 'Error while running event|non-recoverable error|Error AtlasBuilder' -Quiet) { throw "Client fixture failed: $run\client.txt" }
                }
                Start-Sleep -Milliseconds 500
                $process.Refresh()
            }
            if (-not $ready) { throw "Client fixture timed out: $run\client.txt" }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    } elseif ($Transition) {
        $serverSettings=Join-Path $run 'server-settings.json'
        $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name='ESIR isolated flamethrower QC';$server.description='Disposable setting transition test'
        $server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
        $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverSettings -Encoding UTF8
        $savedPath=Join-Path $run 'saves\flame-transition.zip'
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $started=Get-Date
        $arguments=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$serverSettings+'"'),'--port','34197','--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.txt') -RedirectStandardError (Join-Path $run 'server-error.txt')
        try {
            $ready=$false
            $deadline=(Get-Date).AddMinutes(3)
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
                if (Test-Path -LiteralPath (Join-Path $run 'server.txt')) {
                    if (Select-String -LiteralPath (Join-Path $run 'server.txt') -Pattern 'Error while running event|Hosting multiplayer game failed' -Quiet) { throw "Transition engine error: $run\server.txt" }
                }
                if ((Test-Path -LiteralPath $savedPath) -and (Get-Item -LiteralPath $savedPath).LastWriteTime -gt $started) {
                    try { $zip=[IO.Compression.ZipFile]::OpenRead($savedPath);$zip.Dispose();$ready=$true;break } catch { }
                }
                Start-Sleep -Milliseconds 500
                $process.Refresh()
            }
            if (-not $ready) { throw "Transition fixture failed: $run\server.txt" }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    } else {
        & $factorio --benchmark $save --benchmark-ticks $ticks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw "Fixture runtime failed: $run\benchmark.txt" }
    }
    $reportPath=Join-Path $run 'script-output\flamethrower-qc.json'
    if ((Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started) { throw "Fixture did not produce a fresh report: $reportPath" }
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $report | ConvertTo-Json -Depth 12
    if (-not $report.all_pass) { throw 'Flamethrower acceptance failed.' }
    exit
}
$proofFolder=if ($CreationProof) {'creation-proof'} else {'proof'}
$run=Join-Path $repo ".factorio-qc\flamethrower-fuels\$proofFolder"
$mods=Join-Path $run 'mods'
$helper=Join-Path $mods 'esir-flamethrower-proof'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "qc\flamethrower-fuels\$proofFolder") | Copy-Item -Destination $helper -Force
@{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$true},@{name='quality';enabled=$true},@{name='elevated-rails';enabled=$true},@{name='esir-flamethrower-proof';enabled=$true})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
$save=Join-Path $run 'proof.zip'
& $factorio --create $save --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw "Proof creation failed: $run\create.txt" }
$proofTicks=if ($CreationProof) {160} else {5}
& $factorio --benchmark $save --benchmark-ticks $proofTicks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw "Proof runtime failed: $run\benchmark.txt" }
$report=Get-Content -LiteralPath (Join-Path $run 'script-output\flamethrower-proof.json') -Raw | ConvertFrom-Json
$report | ConvertTo-Json -Depth 8
if (-not $report.all_pass) { throw 'Flamethrower replacement proof failed.' }
