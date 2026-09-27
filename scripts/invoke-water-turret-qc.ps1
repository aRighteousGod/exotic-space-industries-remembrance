[CmdletBinding()]
param([switch]$Baseline,[switch]$Save,[string]$SaveInput,[switch]$PlayerSave,[switch]$ForceConfig,[switch]$ReuseFixture,[switch]$DumpOnly,[switch]$Muzzle,[switch]$Visual,[int]$Performance=0,[string]$RunName)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$mode=if($Baseline){'old'}else{'new'}
if($SaveInput){$mode+='-load'}
if($Performance){$mode+="-perf-$Performance"}
if($RunName){$mode=$RunName}
$run=Join-Path $repo ".factorio-qc\wtr\$mode"
$mods=Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed=@('.factorio-qc\wtr\ports-3x3\mods','.factorio-qc\wtr\player\mods','.factorio-qc\fmqc\mods-live') |
    ForEach-Object {Join-Path $repo $_} | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'mod-list.json')} | Select-Object -First 1
if(-not $seed){throw 'No local dependency seed exists; run ESIR doctor/QC staging first.'}
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    $destination=Join-Path $mods $archive.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null}
}
foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
    $destination=Join-Path $mods $directory.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null}
}
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
$source=if($Baseline){Join-Path $repo '.factorio-qc\wtr-baseline-source\exotic-space-industries-remembrance'}else{Join-Path $repo 'exotic-space-industries-remembrance'}
if(-not(Test-Path -LiteralPath (Join-Path $source 'info.json'))){throw 'Missing baseline source snapshot.'}
New-Item -ItemType Directory -Path $pack -Force | Out-Null
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $pack -Recurse -Force
$helper=Join-Path $mods 'zzz-esir-water-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\water-turret') -File | Copy-Item -Destination $helper -Force
if($ForceConfig){
    $helperInfo=Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
    $helperInfo.version='0.0.2'
    $helperInfo | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
}
"return {baseline=$($Baseline.IsPresent.ToString().ToLowerInvariant()),save=$($Save.IsPresent.ToString().ToLowerInvariant()),loaded=$(($SaveInput -and -not $PlayerSave).ToString().ToLowerInvariant()),player=$($PlayerSave.IsPresent.ToString().ToLowerInvariant()),muzzle=$($Muzzle.IsPresent.ToString().ToLowerInvariant()),visual=$($Visual.IsPresent.ToString().ToLowerInvariant()),performance=$Performance}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
if(-not $Baseline){
    Get-Content -LiteralPath (Join-Path $helper 'instrument.lua') -Raw | Add-Content -LiteralPath (Join-Path $pack 'control.lua') -Encoding UTF8
    $modulePath=Join-Path $pack 'scripts\control\water-turret.lua'
    $module=Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
    $module.Replace('return model',"model.qc_set_preferences=set_preferences`nreturn model") | Set-Content -LiteralPath $modulePath -Encoding UTF8
}
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-water-qc')
foreach($mod in $list.mods){
    if($mod.name -match 'qc|benchmark'){$mod.enabled=$false}
    if($mod.name -eq 'extinguisher'){$mod.enabled=$Baseline.IsPresent}
}
$list.mods+=@{name='zzz-esir-water-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
if($DumpOnly){
    & $factorio --dump-data --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'dump.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Data load failed: $run\dump.txt"}
    Write-Output "Data dump: $run\script-output\data-raw-dump.json";exit
}
$fixture=Join-Path $run 'fixture.zip'
if($SaveInput){Copy-Item -LiteralPath $SaveInput -Destination $fixture -Force}
elseif(-not($ReuseFixture -and (Test-Path -LiteralPath $fixture))){
    & $factorio --create $fixture --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Fixture creation failed: $run\create.txt"}
}
$started=Get-Date
if($Save){
    $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
    $server.name='ESIR isolated firefighting QC';$server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
    $settings=Join-Path $run 'server-settings.json'
    $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $settings -Encoding UTF8
    $saved=Join-Path $run 'saves\water-transition.zip'
    New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
    $arguments=@('--start-server',('"'+$fixture+'"'),'--server-settings',('"'+$settings+'"'),'--port','34200','--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
    $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.txt') -RedirectStandardError (Join-Path $run 'server-error.txt')
    try{
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ready=$false;$deadline=(Get-Date).AddMinutes(4)
        while(-not $process.HasExited -and (Get-Date) -lt $deadline){
            if((Test-Path -LiteralPath $saved) -and (Get-Item -LiteralPath $saved).LastWriteTime -gt $started){
                try{$zip=[IO.Compression.ZipFile]::OpenRead($saved);$zip.Dispose();$ready=$true;break}catch{}
            }
            Start-Sleep -Milliseconds 500;$process.Refresh()
        }
        if(-not $ready){throw "Save fixture failed: $run\server.txt"}
        Write-Output "Saved transition: $saved"
        $savedReport=Get-Content -LiteralPath (Join-Path $run 'script-output\water-qc.json') -Raw | ConvertFrom-Json
        if(-not $savedReport.all_pass){throw 'Saved fixture has failing assertions.'}
    }finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}elseif($Visual){
    # Steam's client is running locally; retain this test's arguments instead of
    # asking Steam to restart the game without the isolated profile.
    $env:SteamAppId='427520'
    $env:SteamGameId='427520'
    $arguments=@('--benchmark-graphics',('"'+$fixture+'"'),'--benchmark-ticks','480','--benchmark-runs','1',
        '--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio','--window-size','1280x720','--disable-migration-window')
    $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'visual.txt') -RedirectStandardError (Join-Path $run 'visual-error.txt')
    $processHandle=$process.Handle
    try{
        if(-not $process.WaitForExit(240000)){throw 'Visual benchmark timed out.'}
        $process.Refresh()
        if($process.ExitCode -ne 0){throw "Visual benchmark failed: $run\visual.txt"}
        foreach($pose in 0..7){
            $image=Join-Path $run "script-output/water-art/pose-$pose.png"
            if(-not(Test-Path -LiteralPath $image) -or (Get-Item -LiteralPath $image).LastWriteTime -lt $started){throw "Missing fresh screenshot: $image"}
        }
        Write-Output "Visual fixture: $run\script-output\water-art"
    }finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}else{
    $ticks=if($Performance -ne 0){7200}else{2200}
    & $factorio --benchmark $fixture --benchmark-ticks $ticks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Runtime fixture failed: $run\benchmark.txt"}
    $report=Join-Path $run 'script-output\water-qc.json'
    if(-not(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started){throw "Missing fresh report: $report"}
    $result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $result|ConvertTo-Json -Depth 8
    if(-not $result.all_pass){throw "Acceptance failed: $report"}
}
