[CmdletBinding()]
param([string]$RunName='gate',[ValidateSet('gate','acceptance','quality','energy-migration','benchmark','persistence','generation-persistence','visual')][string]$Fixture='gate',
    [switch]$DumpOnly,[int]$Ticks=1300,[switch]$ReuseFixture,[string]$SaveInput,
    [int]$Population=1,[string]$Workload='warm',[int]$MeasureTicks=2400,[switch]$SingleCase,[switch]$SpreadOut,[switch]$Baseline,[switch]$Profile,
    [switch]$Save,[switch]$Visual,[switch]$ForceConfig,[string]$GraphicsArchiveDirectory,[string]$SourceRoot)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$run=Join-Path $repo ('.factorio-qc\radar\'+$RunName)
$mods=Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    $destination=Join-Path $mods $archive.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null}
}
foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
    $destination=Join-Path $mods $directory.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null}
}
if($GraphicsArchiveDirectory){
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory -Filter 'exotic-space-industries-remembrance-graphics-*'){
        $resolved=[IO.Path]::GetFullPath($link.FullName)
        if(-not $resolved.StartsWith(([IO.Path]::GetFullPath($mods)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -or -not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Expected staged graphics junction.'}
        $info=Get-Content -LiteralPath (Join-Path $link.FullName 'info.json') -Raw | ConvertFrom-Json
        $archive=(Resolve-Path -LiteralPath (Join-Path $GraphicsArchiveDirectory "$($info.name)_$($info.version).zip")).Path
        # Remove only this verified junction, never its source directory.
        [IO.Directory]::Delete($resolved)
        $target=Join-Path $mods ([IO.Path]::GetFileName($archive))
        if(-not(Test-Path -LiteralPath $target)){New-Item -ItemType HardLink -Path $target -Target $archive | Out-Null}
    }
}
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
$source=if($SourceRoot){(Resolve-Path -LiteralPath $SourceRoot).Path}else{Join-Path $repo 'exotic-space-industries-remembrance'}
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $pack -Recurse -Force
$helper=Join-Path $mods 'zzz-esir-radar-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\sweeping-radar') -File | Copy-Item -Destination $helper -Force
if($ForceConfig){
    $helperInfo=Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
    $helperInfo.version='0.0.2'
    $helperInfo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
}
"return {fixture='$Fixture',population=$Population,workload='$Workload',measure_ticks=$MeasureTicks,single=$($SingleCase.IsPresent.ToString().ToLowerInvariant()),spread=$($SpreadOut.IsPresent.ToString().ToLowerInvariant()),baseline=$($Baseline.IsPresent.ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
Get-Content -LiteralPath (Join-Path $helper 'instrument.lua') -Raw | Add-Content -LiteralPath (Join-Path $pack 'control.lua') -Encoding UTF8
if($Fixture -eq 'benchmark' -and $Profile -and -not $Baseline){
    python -B (Join-Path $helper 'profile.py') (Join-Path $pack 'scripts/control/sweeping-radar.lua')
    if($LASTEXITCODE -ne 0){throw 'Profiler staging failed.'}
}
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-radar-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-radar-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
if($Visual){@('[graphics]','full-screen=false','[interface]','ui-scale-mode=manual-pixels','custom-ui-scale=1') | Add-Content -LiteralPath $config -Encoding UTF8}
if($DumpOnly){
    & $factorio --dump-data --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File (Join-Path $run 'dump.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Data load failed: $run\dump.txt"}
    Write-Output "Data dump: $run\script-output\data-raw-dump.json"
    exit
}
$fixturePath=Join-Path $run 'fixture.zip'
if($SaveInput){Copy-Item -LiteralPath $SaveInput -Destination $fixturePath -Force}
elseif(-not($ReuseFixture -and (Test-Path -LiteralPath $fixturePath))){
    & $factorio --create $fixturePath --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File (Join-Path $run 'create.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Fixture creation failed: $run\create.txt"}
}
$started=Get-Date
$extra=if($Fixture -eq 'benchmark'){@('--benchmark-verbose','all')}else{@()}
Get-Process factorio -ErrorAction SilentlyContinue | Select-Object Id,CPU,StartTime | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'concurrent-processes.json') -Encoding UTF8
if($Save -or $Visual){
    $arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
    if($Save){
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name='ESIR isolated radar QC';$server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
        $serverPath=Join-Path $run 'server-settings.json'
        $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverPath -Encoding UTF8
        $arguments+=@('--start-server',('"'+$fixturePath+'"'),'--server-settings',('"'+$serverPath+'"'),'--port','34231')
    }else{
        $env:SteamAppId='427520';$env:SteamGameId='427520'
        $arguments+=@('--benchmark-graphics',('"'+$fixturePath+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1','--window-size','1280x720','--disable-migration-window')
    }
    $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'benchmark.txt') -RedirectStandardError (Join-Path $run 'stderr.txt')
    $process.Handle | Out-Null
    try{
        $deadline=(Get-Date).AddMinutes(5);$savedReady=$false
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        while(-not $process.HasExited -and (Get-Date) -lt $deadline){
            if(Select-String -LiteralPath (Join-Path $run 'benchmark.txt') -Pattern 'Error while running event|Error Util.cpp|Couldn.t create lock file' -Quiet){throw "Radar engine error: $run\benchmark.txt"}
            $savedPath=Join-Path $run 'saves/radar-transition.zip'
            if($Save -and (Test-Path -LiteralPath $savedPath) -and (Get-Item -LiteralPath $savedPath).LastWriteTime -gt $started){
                try{$zip=[IO.Compression.ZipFile]::OpenRead($savedPath);$zip.Dispose();$savedReady=$true;break}catch{}
            }
            Start-Sleep -Milliseconds 500;$process.Refresh()
        }
        if($Save -and -not $savedReady){throw "Radar save failed: $run\benchmark.txt"}
        if($Visual -and (-not $process.HasExited -or $process.ExitCode -ne 0)){throw "Radar visual run failed: $run\benchmark.txt"}
    }finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}else{
    & $factorio --benchmark $fixturePath --benchmark-ticks $Ticks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio @extra 2>&1 | Out-File (Join-Path $run 'benchmark.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Runtime fixture failed: $run\benchmark.txt"}
}
$report=Join-Path $run 'script-output\radar-qc.json'
if(-not(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started){throw "Missing fresh report: $report"}
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
Write-Output "Radar $Fixture result: all_pass=$($result.all_pass); $report"
if(-not $result.all_pass){throw "Acceptance failed: $report"}
