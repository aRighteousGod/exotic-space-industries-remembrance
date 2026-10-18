[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunDirectory,
    [ValidateSet('dump','runtime','preview','save')][string]$Mode='runtime',
    [string]$SavePath='.factorio-qc/wtr/player/fixture.zip',
    [string]$Planet='gaia', [uint32]$Seed=1000,
    [string]$MapSettings, [string]$QuantityNames,
    [string]$Tag='runtime', [int]$Ticks=120, [int]$Size=2048,
    [string]$Report='planet-enemies-runtime.json', [int]$TimeoutSeconds=600
)
$ErrorActionPreference='Stop'
$run=(Resolve-Path -LiteralPath $RunDirectory).Path
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$arguments=@('--config',('"'+$run+'/config.ini"'),'--mod-directory',('"'+$run+'/mods"'),'--disable-audio')
if($Mode -eq 'dump'){$arguments+='--dump-data'}
elseif($Mode -eq 'save'){
    $options=Get-Content -LiteralPath 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw|ConvertFrom-Json
    $options.name='Planet enemy lifecycle QC'
    $options.visibility.public=$false;$options.visibility.lan=$false
    $options.require_user_verification=$false;$options.auto_pause=$false
    $options|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$run/server-settings.json" -Encoding utf8
    New-Item -ItemType Directory -Path "$run/saves" -Force|Out-Null
    $arguments+=@('--start-server',('"'+(Resolve-Path -LiteralPath $SavePath).Path+'"'),'--server-settings',('"'+$run+'/server-settings.json"'),'--bind','127.0.0.1:34328')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}
elseif($Mode -eq 'runtime'){$arguments+=@('--benchmark',('"'+(Resolve-Path -LiteralPath $SavePath).Path+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1')}
else{
    $arguments+=@('--generate-map-preview',('"'+$run+'/'+$Tag+'.png"'),'--map-preview-size',"$Size",'--map-preview-planet',$Planet,'--map-gen-seed',"$Seed")
    if($MapSettings){$arguments+=@('--map-gen-settings',('"'+(Resolve-Path -LiteralPath $MapSettings).Path+'"'))}
    if($QuantityNames){$arguments+=@('--report-quantities',$QuantityNames)}
}
$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/$Tag-stdout.txt" -RedirectStandardError "$run/$Tag-stderr.txt"
$process.Handle|Out-Null
$started=Get-Date
$saved=$false
Write-Output "Factorio QC process: $($process.Id)"
while(-not $process.HasExited){
    Start-Sleep -Milliseconds 500;$process.Refresh()
    if($Mode -eq 'save' -and (Test-Path -LiteralPath "$run/factorio-current.log") -and
        (Get-Item -LiteralPath "$run/factorio-current.log").LastWriteTime -ge $started -and
        (Select-String -LiteralPath "$run/factorio-current.log" -Pattern 'Error while running event|Hosting multiplayer game failed' -Quiet)){
        $process.Kill();$process.WaitForExit();break
    }
    if($Mode -eq 'save'){
        $checkpoint=Get-Item -LiteralPath "$run/saves/planet-enemies-pending.zip" -ErrorAction SilentlyContinue
        if($checkpoint -and $checkpoint.LastWriteTime -ge $started){
            try{$zip=[IO.Compression.ZipFile]::OpenRead($checkpoint.FullName);$zip.Dispose();$saved=$true}catch{}
            if($saved){$process.Kill();$process.WaitForExit();break}
        }
    }
    if(((Get-Date)-$started).TotalSeconds -gt $TimeoutSeconds){$process.Kill();throw "Timed out: $Tag"}
}
Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/$Tag.log"
if(((-not $saved) -and $process.ExitCode -ne 0) -or (Select-String -LiteralPath "$run/$Tag.log" -Pattern 'Error Util.cpp|Error while running event' -Quiet)){
    Get-Content -LiteralPath "$run/$Tag.log" -Tail 35
    Get-Content -LiteralPath "$run/$Tag-stderr.txt" -Tail 25
    Get-Content -LiteralPath "$run/$Tag-stdout.txt" -Tail 25
    throw "Planet enemy QC failed: $Tag"
}
if($Mode -eq 'save' -and -not $saved){throw 'Native checkpoint was not saved.'}
if($Mode -eq 'runtime'){
    $reportFile=Get-Item -LiteralPath "$run/script-output/$Report"
    if($reportFile.LastWriteTime -lt $started){throw 'Stale runtime report.'}
    $result=Get-Content -LiteralPath $reportFile.FullName -Raw|ConvertFrom-Json
    if($result.PSObject.Properties.Name -contains 'all_pass' -and -not $result.all_pass){throw 'Planet enemy runtime assertions failed.'}
    Write-Output "Fresh report: $($reportFile.FullName)"
}
Write-Output "$run/$Tag.log"
