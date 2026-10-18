[CmdletBinding()]
param([switch]$Full,[switch]$Visual,[switch]$Reload,[double]$Scale=1,[int]$Ticks=6100,[string]$SaveInput)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
. (Join-Path $PSScriptRoot 'qc/rebuild-monitor/viewport.ps1')
function Invoke-RebuildRegistry([scriptblock]$Action){
    for($attempt=0;$attempt -lt 60;$attempt++){
        try{return & $Action}catch{
            if($_.Exception.Message -notmatch 'registry.lock' -or $attempt -eq 59){throw}
            Start-Sleep -Milliseconds 500
        }
    }
}
$scenario=if($Full){'owners'}elseif($Reload){'reload-'+$Scale}elseif($Visual){'gui-'+$Scale}else{'core-gui'}
$registration=Invoke-RebuildRegistry {Register-EsirArtifactRun -RepoRoot $repo -Workflow 'rebuild-monitor' -Scenario $scenario -EngineVersion '2.0.77' -Reproduction ('scripts/invoke-rebuild-monitor-qc.ps1 -Full:$'+$Full.IsPresent+' -Visual:$'+$Visual.IsPresent+' -Reload:$'+$Reload.IsPresent+' -Scale '+$Scale)}
$run=Join-Path $repo $registration.payload_path
$mods=Join-Path $run 'mods';$helper=Join-Path $mods 'zzz-esir-rebuild-qc'
$pack=Join-Path $repo 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/rebuild-monitor') -File | Copy-Item -Destination $helper
$enc=[Text.UTF8Encoding]::new($false)
if($Reload){[IO.File]::WriteAllText((Join-Path $helper 'reload.lua'),'return true',$enc);$Visual=$true}
$list=@{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$false},@{name='quality';enabled=$false},@{name='elevated-rails';enabled=$false})}
$stagedLinks=@()
if($Full){
    $seed=Join-Path $repo '.factorio-qc/fmqc/mods-live'
    foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
        New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
    }
    foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
        $link=Join-Path $mods $directory.Name
        New-Item -ItemType Junction -Path $link -Target $directory.FullName | Out-Null
        $stagedLinks+=@{path=$link;target=$directory.FullName}
    }
    $staged=Join-Path $mods 'exotic-space-industries-remembrance'
    Copy-Item -LiteralPath $pack -Destination $staged -Recurse
    [IO.File]::AppendAllText((Join-Path $staged 'control.lua'),[IO.File]::ReadAllText((Join-Path $helper 'instrument.lua')),$enc)
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-rebuild-qc')
    foreach($entry in $list.mods){if($entry.name -match 'qc|benchmark'){$entry.enabled=$false}}
}else{
    foreach($path in @('lib/runtime-scheduler.lua','scripts/control/rebuild-monitor.lua','locale/en/rebuild-monitor.cfg')){
        $target=Join-Path $helper $path
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $pack $path) -Destination $target
    }
}
$list.mods+=@{name='zzz-esir-rebuild-qc';enabled=$true}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($list|ConvertTo-Json -Depth 5),$enc)
$config=Join-Path $run 'config.ini'
$scaleText=$Scale.ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)
[IO.File]::WriteAllText($config,"[path]`nread-data=__PATH__executable__/../../data`nwrite-data="+$run.Replace('\','/')+"`n[other]`ncheck-updates=false`n[interface]`nui-scale-mode=manual-pixels`ncustom-ui-scale=$scaleText`n[graphics]`nfull-screen=false`n",$enc)
if(-not $SaveInput){$SaveInput=Join-Path $repo '.factorio-qc/wtr/final-player/fixture.zip'}
$save=(Resolve-Path -LiteralPath $SaveInput).Path
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$mode=if($Visual){'--benchmark-graphics'}else{'--benchmark'}
$arguments=@($mode,$save,'--benchmark-ticks',"$Ticks",'--benchmark-runs','1','--config',$config,'--mod-directory',$mods,'--disable-audio','--disable-migration-window')
if($Visual){$arguments+=@('--window-size','1280x720','--graphics-quality','medium','--video-memory-usage','low','--single-thread-loading')}
Write-Output "Rebuild QC run: $run"
$env:SteamAppId='427520';$env:SteamGameId='427520'
if($Reload){
    $stages=@(@{save=$save;target=(Join-Path $run 'saves/_autosave-rebuild-monitor-open.zip')},@{save=(Join-Path $run 'saves/_autosave-rebuild-monitor-open.zip');target=(Join-Path $run 'saves/_autosave-rebuild-monitor-closed.zip')},@{save=(Join-Path $run 'saves/_autosave-rebuild-monitor-closed.zip');target=(Join-Path $run 'script-output/rebuild-qc.json')})
    $stageIndex=0
    foreach($stage in $stages){
        $stageIndex++
        $clientArgs=@('--load-game',$stage.save,'--config',$config,'--mod-directory',$mods,'--disable-audio','--disable-migration-window','--window-size','1280x720','--graphics-quality','medium','--video-memory-usage','low','--single-thread-loading')
        $process=Start-Process -FilePath $exe -ArgumentList @($clientArgs|ForEach-Object{'"'+$_+'"'}) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run "client-$stageIndex.txt") -RedirectStandardError (Join-Path $run "client-$stageIndex-error.txt")
        $deadline=(Get-Date).AddMinutes(5);$ready=$false;$resized=$false
        try{
            while(-not $process.HasExited -and (Get-Date) -lt $deadline){
                if(-not $resized){$resized=[RebuildViewport]::Resize($process.Id)}
                $clientLog=Join-Path $run "client-$stageIndex.txt"
                if((Test-Path -LiteralPath $clientLog) -and (Select-String -LiteralPath $clientLog -Pattern 'Error while running event|Error Util.cpp' -Quiet)){throw "Native reload error: $clientLog"}
                if(Test-Path -LiteralPath $stage.target){
                    if($stageIndex -lt 3){try{$archive=[IO.Compression.ZipFile]::OpenRead($stage.target);$archive.Dispose();$ready=$true}catch{}}
                    else{try{$result=Get-Content -LiteralPath $stage.target -Raw|ConvertFrom-Json;$ready=[bool]$result.all_pass}catch{}}
                }
                if($ready){break};Start-Sleep -Milliseconds 200;$process.Refresh()
            }
        }finally{if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}}
        if(-not $ready){throw "Reload fixture did not reach stage $stageIndex : $run"}
    }
    $engineExit=0
}elseif($Visual){
    $process=Start-Process -FilePath $exe -ArgumentList @($arguments|ForEach-Object{'"'+$_+'"'}) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'engine.txt') -RedirectStandardError (Join-Path $run 'stderr.txt')
    $process.Handle|Out-Null
    $resized=$false;$deadline=(Get-Date).AddMinutes(5)
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if(-not $resized){$resized=[RebuildViewport]::Resize($process.Id)}
        Start-Sleep -Milliseconds 100;$process.Refresh()
    }
    if(-not $process.HasExited){Stop-Process -Id $process.Id;throw "Visual fixture timeout: $run"}
    $engineExit=$process.ExitCode
}else{
    & $exe @arguments 2>&1 | Out-File -LiteralPath (Join-Path $run 'engine.txt') -Encoding utf8
    $engineExit=$LASTEXITCODE
}
$reportPath=Join-Path $run 'script-output/rebuild-qc.json'
$report=if(Test-Path -LiteralPath $reportPath){Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json}else{@{all_pass=$false;checks=@();error='No report'}}
if($Visual -and $report.all_pass -and ($report.resolution.width -ne 1280 -or $report.resolution.height -ne 720 -or [Math]::Abs($report.scale-$Scale) -gt 0.001)){throw "Unexpected native viewport/scale: $reportPath"}
# The engine has exited. Unlink only this run's verified staging junctions;
# managed retention deliberately refuses any payload containing reparse points.
foreach($stagedLink in $stagedLinks){
    $item=Get-Item -LiteralPath $stagedLink.path -Force
    if($item.Parent.FullName -ne $mods -or $item.LinkType -ne 'Junction' -or $item.Target -ne $stagedLink.target){throw "Staging link identity changed: $($stagedLink.path)"}
    [IO.Directory]::Delete($item.FullName)
}
$summary=@{run_id=$registration.id;workflow=$registration.workflow;engine_version=$registration.engine_version;repo_root=$registration.repo_root;payload_path=$registration.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status=if($engineExit -eq 0 -and $report.all_pass){'ok'}else{'error'};result=$report;engine_exit=$engineExit;report_path=$reportPath}
$completed=Invoke-RebuildRegistry {Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode $engineExit -Summary $summary}
[pscustomobject]@{run_id=$registration.id;status=$summary.overall_status;engine_exit=$engineExit;checks=@($report.checks).Count;failed=@($report.checks|Where-Object {-not $_.ok});report=$reportPath;housekeeping_status=$completed.status;housekeeping_error=$completed.housekeeping_error} | ConvertTo-Json -Depth 5
if($engineExit -ne 0 -or -not $report.all_pass){throw "Rebuild QC failed: $run/engine.txt"}
