[CmdletBinding()]
param([string]$Scene='smoke',[string]$SaveInput,[switch]$Probe,
    [ValidateRange(640,4096)][int]$Width=1920,[ValidateRange(480,2160)][int]$Height=1080,
    [string]$FactorioPath)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
$paths=Get-EsirPaths $repo
$context=Get-EsirQcContext -Paths $paths -FactorioPath $FactorioPath
$profile=Read-EsirJson (Join-Path $repo '.codex/esir/factorio-development.json')
$FactorioPath=$context.factorio_exe
if(-not $SaveInput){$SaveInput=Join-Path $repo $profile.smoke_save}
$save=(Resolve-Path -LiteralPath $SaveInput).Path
if($Scene -notmatch '^[a-z0-9-]+$'){throw 'Invalid scene ID'}
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$shortPath='.factorio-qc/pm/'+([guid]::NewGuid().ToString('N').Substring(0,8))
$managed=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'portal-media' -Scenario $Scene -EngineVersion $profile.engine_version -PayloadPath $shortPath -Reproduction "powershell -File scripts/invoke-portal-capture.ps1 -Scene $Scene -SaveInput $save"
[void](Initialize-EsirManagedQcContext -RepoRoot $repo -Context $context -RunId $managed.id -SourceMode private-mutable)
$run=$context.scratch_root
Write-Host "Portal capture: $run"
$mods=$null
$process=$null;$completed=$false;$failure=$null;$resized=$false
try{
$stageResult=New-FactorioQCResult -Name 'portal-media'
$mediaText=& python -X utf8 -B (Join-Path $PSScriptRoot 'portal-media/pack_media.py') --run-id $managed.id
if($LASTEXITCODE -ne 0){throw 'Managed media package build failed'}
$media=@(($mediaText|Out-String)|ConvertFrom-Json)
$context.source_mods=@($context.source_mods | Where-Object {$_.name -notlike 'exotic-space-industries-remembrance-graphics-*'})
$context|Add-Member -NotePropertyName extra_dependency_packages -NotePropertyValue $media
Write-EsirJson -Path (Join-Path $context.evidence_root 'media-sources.json') -Data $media
$mods=Sync-FactorioRunMods -Context $context -Result $stageResult
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
$helper=Join-Path $mods 'zzz-esir-portal-capture'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'portal-media/native') -Destination $helper -Recurse
$enc=[Text.UTF8Encoding]::new($false)
$helperInfo=Read-EsirJson (Join-Path $helper 'info.json')
$helperInfo.factorio_version=($profile.engine_version -replace '\.\d+$','')
Write-EsirJson -Path (Join-Path $helper 'info.json') -Data $helperInfo
[IO.File]::WriteAllText((Join-Path $helper 'capture-config.lua'),"return {scene='$Scene',probe=$($Probe.IsPresent.ToString().ToLowerInvariant()),width=$Width,height=$Height}",$enc)
$bridge=Join-Path $PSScriptRoot 'portal-media/native/bridge.lua'
if(Test-Path -LiteralPath $bridge){[IO.File]::AppendAllText((Join-Path $pack 'control.lua'),("`n"+[IO.File]::ReadAllText($bridge)),$enc)}
$list=Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-portal-capture')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-portal-capture';enabled=$true}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($list|ConvertTo-Json -Depth 8),$enc)
$config=Join-Path $run 'config.ini'
[IO.File]::WriteAllText($config,"[path]`nread-data=__PATH__executable__/../../data`nwrite-data=$($run.Replace('\','/'))`n[other]`ncheck-updates=false`n[interface]`nui-scale-mode=manual-pixels`ncustom-ui-scale=1`n[graphics]`nfull-screen=false`ncache-sprite-atlas=false`n",$enc)
$env:SteamAppId='427520';$env:SteamGameId='427520'
$arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--load-game',('"'+$save+'"'),'--disable-audio','--disable-migration-window','--window-size',"$($Width)x$Height",'--graphics-quality','medium','--video-memory-usage','low','--single-thread-loading')
if($Probe){$arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--benchmark',('"'+$save+'"'),'--benchmark-ticks','16000','--benchmark-runs','1','--benchmark-ignore-paused','--disable-audio')}
. (Join-Path $PSScriptRoot 'portal-media/window.ps1')
$process=Start-Process -FilePath $FactorioPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'stdout.txt') -RedirectStandardError (Join-Path $run 'stderr.txt')
$process.Handle|Out-Null
    $deadline=(Get-Date).AddMinutes(12)
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if(-not $Probe){$resized=[ESIRPortalWindow]::Resize($process.Id,$Width,$Height)}
        $log=Join-Path $run 'factorio-current.log'
        if(Test-Path -LiteralPath $log){
            $errorLogs=@($log,(Join-Path $run 'stdout.txt'),(Join-Path $run 'stderr.txt')) | Where-Object {Test-Path -LiteralPath $_}
            if(Select-String -LiteralPath $errorLogs -Pattern 'Error while running|Error [A-Za-z]+\.cpp' -Quiet){throw "Engine error; inspect stdout.txt and factorio-current.log in $run"}
            if(Select-String -LiteralPath $log -Pattern 'PORTAL_CAPTURE_COMPLETE' -Quiet){$completed=$true;Start-Sleep -Seconds 2;break}
        }
        Start-Sleep -Milliseconds 500;$process.Refresh()
    }
    if(-not $completed -and (Test-Path -LiteralPath (Join-Path $run 'script-output/portal/report.json'))){$completed=$true}
    if(-not $completed){throw "Capture did not complete: $run"}
    $report=Get-Content -LiteralPath (Join-Path $run 'script-output/portal/report.json') -Raw | ConvertFrom-Json
    if(-not $Probe -and (-not $report.connected -or $report.resolution.width -ne $Width -or $report.resolution.height -ne $Height -or $report.scale -ne 1)){throw 'Native viewport/player preflight failed'}
}catch{$failure=$_.Exception.Message}finally{
    if($process -and -not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}
}
$result=@{run_id=$managed.id;workflow='portal-media';engine_version=$profile.engine_version;repo_root=$managed.repo_root;payload_path=$managed.payload_path;
    timestamp=[DateTime]::UtcNow.ToString('o');overall_status=$(if($failure){'failed'}else{'ok'});
    path=$run;scene=$Scene;complete=$completed;error=$failure;save_sha256=(Get-FileHash -LiteralPath $save).Hash}
# Completion releases the mod view; the open task lease keeps frames for rendering.
$completion=Complete-EsirArtifactRun -RepoRoot $repo -RunId $managed.id -ExitCode $(if($failure){1}else{0}) -Summary $result
if($completion.cleanup_status -eq 'protected-error'){$failure=$completion.housekeeping_error;$result.error=$failure;$result.overall_status='failed'}
$result|ConvertTo-Json -Depth 6
if($failure){throw $failure}
