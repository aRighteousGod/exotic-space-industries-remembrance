[CmdletBinding()]
param([string]$RunName='gui-1')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$run=Join-Path $repo (".factorio-qc/terrain-evolution/$RunName")
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Run Factorio fixtures sequentially.'}
$env:SteamAppId='427520';$env:SteamGameId='427520'
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$arguments=@('--load-game',(Join-Path $run 'fixture.zip'),'--config',(Join-Path $run 'config.ini'),
    '--mod-directory',(Join-Path $run 'mods'),'--disable-audio','--disable-migration-window','--window-size','1280x720')
$quoted=@($arguments|ForEach-Object {'"'+$_+'"'})
$started=Get-Date
$process=Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $run 'client-release.txt') -RedirectStandardError (Join-Path $run 'client-release-error.txt')
$process.Handle|Out-Null
try{
    $deadline=(Get-Date).AddSeconds(180);$passed=$false
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        $report=Join-Path $run 'script-output/terrain-admin-qc.json'
        if((Test-Path $report) -and (Get-Item $report).LastWriteTime -gt $started){
            $result=Get-Content $report -Raw -Encoding UTF8|ConvertFrom-Json
            if($result.complete){
                if($result.all_pass){$passed=$true;break}
                throw 'Connected administrator acceptance failed.'
            }
        }
        Start-Sleep -Milliseconds 500;$process.Refresh()
    }
    if(-not $passed){throw 'No fresh connected administrator report; inspect client-release.txt.'}
    $result|ConvertTo-Json -Depth 6
}finally{
    if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}
}
