[CmdletBinding()]
param([string]$RunName='save-release')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$run=Join-Path $repo (".factorio-qc/terrain-evolution/$RunName")
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Close other Factorio fixtures before starting the server.'}
$mods=Join-Path $run 'mods'
$main=Join-Path $mods 'exotic-space-industries-remembrance/control.lua'
$bridge=Get-Content -LiteralPath (Join-Path $repo 'scripts/qc/terrain-evolution/persistence-bridge.lua') -Raw -Encoding UTF8
if((Get-Content -LiteralPath $main -Raw) -notmatch 'local persistence_terrain='){
    [IO.File]::AppendAllText($main,"`n$bridge",[Text.UTF8Encoding]::new($false))
}
New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
$server=Get-Content -LiteralPath 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
$server.name='ESIR disposable terrain persistence fixture'
$server.auto_pause=$false;$server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
$server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'server-settings.json') -Encoding UTF8
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$arguments=@('--start-server',(Join-Path $run 'fixture.zip'),'--server-settings',(Join-Path $run 'server-settings.json'),'--port','34397','--config',(Join-Path $run 'config.ini'),'--mod-directory',$mods,'--disable-audio','--disable-migration-window')
$quoted=@($arguments | ForEach-Object {'"'+$_+'"'})
$started=Get-Date
$process=Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.log') -RedirectStandardError (Join-Path $run 'server.stderr.log')
$process.Handle | Out-Null
try{
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $deadline=(Get-Date).AddSeconds(180);$saved=$false
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        $log=Get-Content -LiteralPath (Join-Path $run 'server.log') -Raw
        if($log -match 'Error while running event|Couldn.t create lock file|Error Util.cpp'){throw 'Native persistence server failed; inspect server.log'}
        $save=Join-Path $run 'saves/terrain-lifecycle-checkpoint.zip'
        if((Test-Path -LiteralPath $save) -and (Get-Item -LiteralPath $save).LastWriteTime -gt $started -and $log -match 'Saving finished'){
            try{$archive=[IO.Compression.ZipFile]::OpenRead($save);$archive.Dispose();$saved=$true;break}catch{}
        }
        Start-Sleep -Milliseconds 500;$process.Refresh()
    }
    if(-not $saved){throw 'Native persistence checkpoint was not saved.'}
}finally{
    if(-not $process.HasExited){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
}
Get-Content -LiteralPath (Join-Path $run 'script-output/terrain-persistence-seed.json') -Raw
