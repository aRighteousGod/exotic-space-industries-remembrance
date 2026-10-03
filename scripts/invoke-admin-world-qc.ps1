[CmdletBinding()]
param([ValidateSet('all','stage','server','reload')][string]$Mode='all',
    [string]$SeedSave='.factorio-qc/wtr/final-player/fixture.zip')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$run=Join-Path $repo '.factorio-qc/admin-world'
$fixtureSource=Join-Path $PSScriptRoot 'qc/admin-world'
$seed=if([IO.Path]::IsPathRooted($SeedSave)){$SeedSave}else{Join-Path $repo $SeedSave}
$mods=Join-Path $run 'mods'
$mod=Join-Path $mods 'admin-world-qc'
$factorio='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$config=Join-Path $run 'config.ini'
if($Mode -eq 'all'){
    foreach($phase in @('stage','server','reload')){
        & powershell -ExecutionPolicy Bypass -File $PSCommandPath -Mode $phase -SeedSave $seed
        if($LASTEXITCODE -ne 0){throw "Admin world $phase failed."}
    }
    exit
}
if($Mode -eq 'stage'){
    if(-not(Test-Path -LiteralPath $seed)){throw "Provide -SeedSave pointing to a disposable save with a real player: $seed"}
    New-Item -ItemType Directory -Force -Path $run | Out-Null
    $versionLog=Join-Path $run 'version.log'
    $versionProcess=Start-Process -FilePath $factorio -ArgumentList '--version' -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $versionLog -RedirectStandardError (Join-Path $run 'version.stderr.log')
    if($versionProcess.ExitCode -ne 0 -or (Get-Content -LiteralPath $versionLog -Raw) -notmatch '(?m)^Version: 2\.0\.77 '){throw 'This native fixture requires Factorio 2.0.77.'}
    New-Item -ItemType Directory -Force -Path $mod,(Join-Path $mod 'lib'),(Join-Path $mod 'scripts/control/admin'),(Join-Path $run 'saves') | Out-Null
    foreach($file in @('lib/lib.lua','lib/runtime-scheduler.lua','lib/camera-window.lua','scripts/control/fluid-rupture-effects.lua','scripts/control/flammable-rupture-scheduler.lua')){
        Copy-Item -LiteralPath (Join-Path $repo ('exotic-space-industries-remembrance/'+$file)) -Destination (Join-Path $mod $file) -Force
    }
    $worldSource=Join-Path $repo 'exotic-space-industries-remembrance/scripts/control/admin/world.lua'
    Copy-Item -LiteralPath $worldSource -Destination (Join-Path $mod 'scripts/control/admin/world.lua') -Force
    Copy-Item -LiteralPath $seed -Destination (Join-Path $run 'fixture.zip') -Force
    foreach($name in @('control.lua','data.lua','settings.lua')){Copy-Item -LiteralPath (Join-Path $fixtureSource $name) -Destination (Join-Path $mod $name) -Force}
    @{name='admin-world-qc';version='0.0.1';title='Admin native world QC';author='ESIR QC';factorio_version='2.0';dependencies=@('base','space-age','quality','elevated-rails')} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mod 'info.json') -Encoding UTF8
    @{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$true},@{name='quality';enabled=$true},@{name='elevated-rails';enabled=$true},@{name='admin-world-qc';enabled=$true})} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
    $server=Get-Content -Raw 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' | ConvertFrom-Json
    $server.name='ESIR admin isolated native QC';$server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
    $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'server-settings.json') -Encoding UTF8
    Get-ChildItem -LiteralPath $mod -Filter '*.lua' -Recurse | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'source-hashes.json') -Encoding UTF8
    Write-Output $run
    exit
}
$common=@('--config',$config,'--mod-directory',$mods,'--disable-audio')
if($Mode -eq 'server'){
    $arguments=$common+@('--start-server',(Join-Path $run 'fixture.zip'),'--server-settings',(Join-Path $run 'server-settings.json'),'--port','34391','--disable-migration-window')
    $started=Get-Date
    $quoted=@($arguments | ForEach-Object {'"'+$_+'"'})
    $process=Start-Process -FilePath $factorio -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.log') -RedirectStandardError (Join-Path $run 'server.stderr.log')
    $process.Handle | Out-Null
    try{
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $deadline=(Get-Date).AddSeconds(60);$saved=$false
        while(-not $process.HasExited -and (Get-Date) -lt $deadline){
            $log=Get-Content -LiteralPath (Join-Path $run 'server.log') -Raw
            if($log -match 'Error while running event|Couldn.t create lock file|Error Util.cpp'){throw 'Native server failed; inspect server.log'}
            $save=Join-Path $run 'saves/admin-world-checkpoint.zip'
            if((Test-Path -LiteralPath $save) -and (Get-Item -LiteralPath $save).LastWriteTime -gt $started -and $log -match 'Saving finished'){
                try{$archive=[IO.Compression.ZipFile]::OpenRead($save);$archive.Dispose();$saved=$true;break}catch{}
            }
            Start-Sleep -Milliseconds 200;$process.Refresh()
        }
        if(-not $saved){throw 'Native checkpoint was not saved within 60 seconds.'}
    }finally{
        if(-not $process.HasExited){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
    }
    Get-Content -LiteralPath (Join-Path $run 'server.log') -Tail 8
    exit
}
else{$arguments=$common+@('--benchmark',(Join-Path $run 'saves/admin-world-checkpoint.zip'),'--benchmark-ticks','1000','--benchmark-runs','1')}
$quoted=@($arguments | ForEach-Object {'"'+$_+'"'})
$process=Start-Process -FilePath $factorio -ArgumentList $quoted -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $run ($Mode+'.log')) -RedirectStandardError (Join-Path $run ($Mode+'.stderr.log'))
if($process.ExitCode -ne 0){throw "$Mode failed; inspect $run/$Mode.log"}
Get-Content -LiteralPath (Join-Path $run ($Mode+'.log')) -Tail 12
$result=Get-Content -Raw -LiteralPath (Join-Path $run 'script-output/admin-world-results.json') | ConvertFrom-Json
if(-not $result.all_pass -or $result.phase -ne 'finished'){throw "Native admin world checks failed: $($result.failures | ConvertTo-Json -Compress)"}
Write-Output "Native admin world: $($result.checks) checks passed; chart peak $($result.chart_pending_peak); creation admissions $($result.first_attempts)."
