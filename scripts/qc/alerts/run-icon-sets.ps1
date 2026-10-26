[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputRoot,[switch]$Checkpoint,[ValidateRange(120,900)][int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$run=[IO.Path]::GetFullPath($OutputRoot)
if(-not $Checkpoint){
    & (Join-Path $PSScriptRoot '../terrain-evolution/run-admin.ps1') -OutputRoot $run -TimeoutSeconds $TimeoutSeconds
    exit $LASTEXITCODE
}
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Run Factorio fixtures sequentially.'}
$env:SteamAppId='427520';$env:SteamGameId='427520'
. (Join-Path $PSScriptRoot '../rebuild-monitor/viewport.ps1')
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$arguments=@('--load-game',(Join-Path $run 'fixture.zip'),'--config',(Join-Path $run 'config.ini'),
    '--mod-directory',(Join-Path $run 'mods'),'--disable-audio','--disable-migration-window','--window-size','1280x720',
    '--graphics-quality','medium','--video-memory-usage','low','--single-thread-loading')
$quoted=@($arguments|ForEach-Object {'"'+$_+'"'})
$started=Get-Date
$process=Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $run 'client-release.txt') -RedirectStandardError (Join-Path $run 'client-release-error.txt')
$process.Handle|Out-Null
try{
    $deadline=(Get-Date).AddSeconds($TimeoutSeconds);$passed=$false;$resized=$false;$previousLength=-1
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if(-not $resized){$resized=[RebuildViewport]::Resize($process.Id)}
        $report=Join-Path $run 'script-output/checkpoint-ready.json'
        $save=Join-Path $run 'saves/_autosave-style-provider.zip'
        if((Test-Path -LiteralPath $report) -and (Get-Item -LiteralPath $report).LastWriteTime -gt $started){
            $result=Get-Content -LiteralPath $report -Raw -Encoding UTF8|ConvertFrom-Json
            if(-not $result.all_pass){throw 'Icon-set checkpoint assertions failed.'}
            if(Test-Path -LiteralPath $save){
                $file=Get-Item -LiteralPath $save
                $log=Get-Content -LiteralPath (Join-Path $run 'factorio-current.log') -Raw -Encoding UTF8
                if($file.LastWriteTime -gt $started -and $file.Length -eq $previousLength -and $log -match 'Saving finished'){
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip=[IO.Compression.ZipFile]::OpenRead($save)
                    try{if($zip.Entries.Count -lt 2){throw 'Checkpoint archive is incomplete.'}}finally{$zip.Dispose()}
                    $passed=$true
                    $result|Add-Member -NotePropertyName host_verified_save -NotePropertyValue $save -Force
                    $result|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $run 'script-output/terrain-admin-qc.json') -Encoding UTF8
                    break
                }
                $previousLength=$file.Length
            }
        }
        Start-Sleep -Milliseconds 500;$process.Refresh()
    }
    if(-not $passed){throw 'No fresh completed checkpoint; inspect client-release.txt.'}
    $result|ConvertTo-Json -Depth 12
}finally{
    if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}
}
