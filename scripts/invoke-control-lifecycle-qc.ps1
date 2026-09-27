[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunName,
    [Parameter(Mandatory=$true)][string]$BaselineSource,
    [string]$SourceRoot,
    [Parameter(Mandatory=$true)][ValidateSet('queue-save','queue-load','gui')][string]$Mode,
    [string]$SaveInput, [switch]$ForceConfig, [switch]$HeadlessGui, [switch]$ClientGui,
    [string]$GraphicsArchiveDirectory,
    [int]$Ticks=180
)
$ErrorActionPreference='Stop'
if($Mode -eq 'gui' -and -not $PSBoundParameters.ContainsKey('Ticks')){$Ticks=420}
$repo=Split-Path -Parent $PSScriptRoot
$extra=@{}
if($SourceRoot){$extra.SourceRoot=$SourceRoot}
if($SaveInput){$extra.SaveInput=$SaveInput}
if($ForceConfig){$extra.ForceConfig=$true}
$bridge=if($Mode -eq 'gui'){'gui-lifecycle.lua'}else{'queue-save.lua'}
$exports=if($Mode -eq 'gui'){'gui-exports.json'}else{'queue-exports.json'}
& "$PSScriptRoot/invoke-control-ups-qc.ps1" -RunName $RunName -BaselineSource $BaselineSource -PrepareOnly -CaptureConfiguration -Helper "$PSScriptRoot/qc/control-ups/lifecycle-helper" -BridgePath "$PSScriptRoot/qc/control-ups/$bridge" -ExportsPath "$PSScriptRoot/qc/control-ups/$exports" -Ticks $Ticks -Runs 1 @extra | Out-Null
$run=Join-Path $repo ".factorio-qc/cu/g/$RunName"
$config=Join-Path $run 'config.ini'
$mods=Join-Path $run 'mods'
if($ClientGui -and $HeadlessGui){throw 'Choose either ClientGui or HeadlessGui.'}
$graphicsArchives=@()
if($GraphicsArchiveDirectory){
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory -Filter 'exotic-space-industries-remembrance-graphics-*'){
        $resolvedLink=[IO.Path]::GetFullPath($link.FullName)
        if(-not $resolvedLink.StartsWith(([IO.Path]::GetFullPath($mods)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -or -not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Expected a staged graphics junction.'}
        $info=Get-Content -LiteralPath (Join-Path $link.FullName 'info.json') -Raw | ConvertFrom-Json
        $archive=(Resolve-Path -LiteralPath (Join-Path $GraphicsArchiveDirectory "$($info.name)_$($info.version).zip")).Path
        if(Test-Path -LiteralPath (Join-Path $mods ([IO.Path]::GetFileName($archive)))){throw 'Graphics archive already staged; refuse to overwrite a possible hard link.'}
        # Delete only this verified junction itself, never its target or children.
        [IO.Directory]::Delete($resolvedLink)
        Copy-Item -LiteralPath $archive -Destination $mods
        $graphicsArchives+=@{name=[IO.Path]::GetFileName($archive);sha256=(Get-FileHash -LiteralPath $archive).Hash}
    }
}
$manifest=Get-Content -LiteralPath "$run/manifest.json" -Raw | ConvertFrom-Json
$manifest | Add-Member -NotePropertyName lifecycle_mode -NotePropertyValue $Mode
$manifest | Add-Member -NotePropertyName headless_gui -NotePropertyValue ([bool]$HeadlessGui)
$manifest | Add-Member -NotePropertyName client_gui -NotePropertyValue ([bool]$ClientGui)
$manifest | Add-Member -NotePropertyName graphics_archives -NotePropertyValue $graphicsArchives
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath "$run/manifest.json" -Encoding UTF8
$save=if($SaveInput){(Resolve-Path -LiteralPath $SaveInput).Path}else{Join-Path $run 'fixture.zip'}
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$utf8=New-Object Text.UTF8Encoding($false)
$arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
if($Mode -eq 'queue-save'){
    New-Item -ItemType Directory -Path "$run/saves" -Force | Out-Null
    $options=Get-Content -LiteralPath 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
    $options.name='Control UPS queue persistence'
    $options.visibility.public=$false;$options.visibility.lan=$false
    $options.require_user_verification=$false;$options.auto_pause=$false
    [IO.File]::WriteAllText("$run/server-settings.json",($options|ConvertTo-Json -Depth 8),$utf8)
    $arguments+=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$run+'/server-settings.json"'),'--port','34219')
}elseif($Mode -eq 'gui'){
    New-Item -ItemType Directory -Path "$run/saves" -Force | Out-Null
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    if($ClientGui){$arguments+=@('--load-game',('"'+$save+'"'),'--disable-migration-window','--window-size','1280x720')}
    else{
        $benchmarkFlag=if($HeadlessGui){'--benchmark'}else{'--benchmark-graphics'}
        $arguments+=@($benchmarkFlag,('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1','--disable-migration-window','--window-size','1280x720')
    }
}else{
    $arguments+=@('--benchmark',('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1')
}
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Another Factorio process is running; QC engines must run sequentially.'}
$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/$Mode-stdout.txt" -RedirectStandardError "$run/$Mode-stderr.txt"
$process.Handle|Out-Null
$deadline=(Get-Date).AddMinutes(5)
$saved=Join-Path $run 'saves/control-ups-pending.zip'
$validSave=$false
$clientComplete=$false
Add-Type -AssemblyName System.IO.Compression.FileSystem
try{
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if($ClientGui -and (Test-Path -LiteralPath "$run/factorio-current.log") -and (Select-String -LiteralPath "$run/factorio-current.log" -Pattern 'CONTROL_UPS_GUI ALL_COMPLETE' -Quiet)){
            $clientComplete=$true;break
        }
        if((Test-Path -LiteralPath "$run/factorio-current.log") -and (Select-String -LiteralPath "$run/factorio-current.log" -Pattern 'Error while running event|Error Util.cpp|Error AtlasBuilder|Hosting multiplayer game failed' -Quiet)){
            throw "Lifecycle script failed: $run/factorio-current.log"
        }
        if($Mode -eq 'queue-save' -and (Test-Path -LiteralPath $saved)){
            try{$archive=[IO.Compression.ZipFile]::OpenRead($saved);$archive.Dispose();$validSave=$true;break}catch{}
        }
        Start-Sleep -Milliseconds 500;$process.Refresh()
    }
    if($Mode -eq 'queue-save'){
        if(-not $validSave){throw "Queue save missing: $run"}
    }elseif($ClientGui){
        if(-not $clientComplete){throw "GUI client did not complete: $run"}
        $guiSave=Join-Path $run 'saves/_autosave-control-ups-gui.zip'
        $archive=[IO.Compression.ZipFile]::OpenRead($guiSave);$archive.Dispose()
    }else{
        if(-not $process.HasExited){throw "Lifecycle run timed out: $run"}
        if($process.ExitCode -ne 0){throw "Lifecycle engine failed: $run"}
    }
}finally{
    if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}
    Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/$Mode.log"
}
if(Select-String -LiteralPath "$run/$Mode.log" -Pattern 'Error while running event|Error Util.cpp' -Quiet){throw "Lifecycle script failed: $run"}
if($Mode -ne 'queue-save'){
    $marker=if($Mode -eq 'gui'){'CONTROL_UPS_GUI ALL_COMPLETE'}else{'CONTROL_UPS_QUEUE ALL_COMPLETE'}
    if(-not(Select-String -LiteralPath "$run/$Mode.log" -Pattern $marker -Quiet)){throw "Lifecycle completion marker missing: $run"}
}
Write-Output $(if($Mode -eq 'queue-save'){$saved}else{$run})
