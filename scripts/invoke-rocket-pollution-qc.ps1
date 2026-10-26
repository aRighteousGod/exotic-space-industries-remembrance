[CmdletBinding()]
param([int]$Ticks=6050, [switch]$SaveReload, [switch]$Visual)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot/esir-housekeeping.ps1"
$shortPayload='.factorio-qc/managed/rp-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$reproduction='powershell -ExecutionPolicy Bypass -File scripts/invoke-rocket-pollution-qc.ps1 -Ticks '+$Ticks
if($SaveReload){$reproduction+=' -SaveReload'}
if($Visual){$reproduction+=' -Visual'}
$registration=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'rocket-pollution' -Scenario 'native' -EngineVersion '2.0.77' -PayloadPath $shortPayload -Reproduction $reproduction
$payload=Join-Path $repo $registration.payload_path
New-Item -ItemType Directory -Path $payload -Force | Out-Null
$helper=Join-Path $PSScriptRoot 'qc/rocket-launch-pollution'
$source=Join-Path $repo 'exotic-space-industries-remembrance'
$seedSave=Join-Path $repo '.factorio-qc/wtr/player/fixture.zip'
& "$PSScriptRoot/invoke-control-ups-qc.ps1" -RunName n -BaselineSource $source -Helper $helper -BridgePath "$helper/instrument.lua" -SaveInput $seedSave -PrepareOnly -OutputRoot $payload | Out-Null
$run=Join-Path $payload 'n'
$mods=Join-Path $run 'mods'
$utf8=[Text.UTF8Encoding]::new($false)
# Factorio's graphical loader still hits Windows path limits on long sprite names.
# Use the existing filesystem alias; no relocation or source mutation is needed.
$nativeRun=& python -B -c 'import ctypes,sys; b=ctypes.create_unicode_buffer(4096); n=ctypes.windll.kernel32.GetShortPathNameW(sys.argv[1],b,len(b)); assert n; print(b.value)' $run
if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $nativeRun)){throw 'Could not resolve native QC path'}
$nativeMods=Join-Path $nativeRun 'mods'
$config=[IO.File]::ReadAllText("$run/config.ini").Replace($run.Replace('\','/'),$nativeRun.Replace('\','/'))
[IO.File]::WriteAllText("$run/config.ini",$config,$utf8)
$list=Get-Content -LiteralPath "$mods/mod-list.json" -Raw | ConvertFrom-Json
$list.mods=@($list.mods|Where-Object {$_.name -ne 'exotic-space-industries-remembrance-graphics-6' -and $_.name -ne 'minigun-turret-HD'})+@(@{name='exotic-space-industries-remembrance-graphics-6';enabled=$true})
[IO.File]::WriteAllText("$mods/mod-list.json",($list|ConvertTo-Json -Depth 8),$utf8)
$runtime=Join-Path $mods 'exotic-space-industries-remembrance/scripts/control/rocket-launch-pollution.lua'
$body=[IO.File]::ReadAllText($runtime)
$body=$body.Replace('surface.create_trivial_smoke{','rocket_qc_smoke(surface){')
$body=$body.Replace('launch.canceled = true','rocket_qc_cancellation(launch, current_tick); launch.canceled = true')
$needle='surface.pollute(launch.position, amount, LAUNCH_POLLUTION_SOURCE)'
if(-not $body.Contains($needle)){throw 'Emission instrumentation boundary missing'}
$body=$body.Replace($needle,'rocket_qc_pollute(surface, launch.position, amount, LAUNCH_POLLUTION_SOURCE, current_tick)')
$body=[regex]::Replace($body,'(?m)^return model\s*$',"model._qc_retaliation = try_form_retaliation`nreturn model")
[IO.File]::WriteAllText($runtime,$body,$utf8)
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
function Invoke-RocketEngine([string[]]$Extra,[string]$Tag){
    # Private write-data/mod-directory; never stop or alter an existing player client.
    $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeMods+'"'),'--disable-audio')+$Extra
    $process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/$Tag-stdout.txt" -RedirectStandardError "$run/$Tag-stderr.txt"
    $process.Handle|Out-Null
    if(-not $process.WaitForExit(300000)){$process.Kill();throw "Owned QC process timed out: $run"}
    $process.Refresh()
    Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/$Tag.log"
    if(($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or (Select-String -LiteralPath "$run/$Tag.log" -Pattern 'Error Util.cpp|Error while running event' -Quiet)){
        Get-Content -LiteralPath "$run/$Tag-stdout.txt" -Tail 20
        throw "Rocket QC failed: $run/$Tag.log"
    }
}
$save=Join-Path $run 'rocket.zip'
Invoke-RocketEngine @('--create',('"'+$save+'"')) 'create'
if(-not(Select-String -LiteralPath "$run/create.log" -Pattern 'Factorio 2\.0\.77 \(build' -Quiet)){throw 'This acceptance fixture requires Factorio 2.0.77'}
Invoke-RocketEngine @('--benchmark',('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1') 'runtime'
$reportPath=Join-Path $run 'script-output/rocket-pollution.json'
if(-not(Test-Path -LiteralPath $reportPath)){throw "Missing rocket acceptance report: $run"}
$report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if(-not $report.all_pass){throw 'Rocket acceptance failed'}
$reloadChecks=@()
if($SaveReload){
    Copy-Item -LiteralPath $reportPath -Destination "$run/native-report.json"
    New-Item -ItemType Directory -Path "$run/saves" -Force | Out-Null
    $server=Get-Content 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
    $server.name='Private rocket pollution acceptance';$server.visibility.public=$false;$server.visibility.lan=$false
    $server.require_user_verification=$false;$server.auto_pause=$false
    [IO.File]::WriteAllText("$run/server-settings.json",($server|ConvertTo-Json -Depth 8),$utf8)
    $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeMods+'"'),'--disable-audio',
      '--start-server',('"'+$save+'"'),'--server-settings',('"'+$run+'/server-settings.json"'),'--bind','127.0.0.1:34449')
    $serverProcess=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/save-stdout.txt" -RedirectStandardError "$run/save-stderr.txt"
    $serverProcess.Handle|Out-Null
    $deadline=[DateTime]::UtcNow.AddMinutes(5)
    try{
        while(-not $serverProcess.HasExited -and [DateTime]::UtcNow -lt $deadline){
            Start-Sleep -Milliseconds 500
            $serverProcess.Refresh()
            if(Test-Path -LiteralPath "$run/save-stdout.txt"){
                if(Select-String -LiteralPath "$run/save-stdout.txt" -Pattern 'Error while running|Failed to start server' -Quiet){throw "Checkpoint server failed: $run/save-stdout.txt"}
            }
            if(Test-Path -LiteralPath "$run/saves/rocket-after.zip"){
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $archive=[IO.Compression.ZipFile]::OpenRead("$run/saves/rocket-after.zip");$archive.Dispose()
                break
            }
        }
        foreach($phase in @('before','during','after')){if(-not(Test-Path -LiteralPath "$run/saves/rocket-$phase.zip")){throw "Missing $phase checkpoint: $run/save-stdout.txt"}}
    }finally{if(-not $serverProcess.HasExited){$serverProcess.Kill();$serverProcess.WaitForExit()}}
    Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/save.log"
    foreach($phase in @('before','during','after')){
        Invoke-RocketEngine @('--benchmark',('"'+$run+'/saves/rocket-'+$phase+'.zip"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1') "reload-$phase"
        if(-not(Select-String -LiteralPath "$run/reload-$phase.log" -Pattern 'ROCKET_POLLUTION_QC COMPLETE' -Quiet)){throw "Reload did not finish: $phase"}
        $reloaded=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
        if(-not $reloaded.all_pass){throw "Reload failed: $phase"}
        Copy-Item -LiteralPath $reportPath -Destination "$run/reload-$phase-report.json"
        $reloadChecks+=@{phase=$phase;checks=$reloaded.checks;all_pass=$true}
    }
}
$summary=@{run_id=$registration.id;workflow=$registration.workflow;engine_version='2.0.77';repo_root=$repo;payload_path=$registration.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';checks=$report.checks;cases=@($report.cases).Count;report=$reportPath;performance_evidence=$false}
$summary.reloads=$reloadChecks
if($Visual){
    if(-not $SaveReload){throw 'Visual requires SaveReload for the pre-ignition checkpoint'}
    [IO.File]::AppendAllText("$mods/zzz-esir-rocket-pollution-qc/control.lua","`nrequire('visual')`n",$utf8)
    [IO.File]::AppendAllText("$run/config.ini","`n[graphics]`nfull-screen=false`nhalt-rendering-when-minimized=false`nmax-sprite-loading-threads=2`n",$utf8)
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeMods+'"'),'--disable-audio','--disable-migration-window',
      '--load-game',('"'+$run+'/saves/rocket-before.zip"'),'--window-size','1280x720','--graphics-quality','medium','--video-memory-usage','low','--max-texture-size','8192')
    # This is the requested interactive review window; background engines stay hidden.
    $visualProcess=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Normal -PassThru -RedirectStandardOutput "$run/visual-stdout.txt" -RedirectStandardError "$run/visual-stderr.txt"
    $visualProcess.Handle|Out-Null
    [IO.File]::WriteAllText("$run/visual-process.json",(@{pid=$visualProcess.Id;run=$run}|ConvertTo-Json),$utf8)
    Write-Output "VISUAL_REVIEW_READY $run"
    $deadline=[DateTime]::UtcNow.AddMinutes(10)
    try{
        while(-not $visualProcess.HasExited -and [DateTime]::UtcNow -lt $deadline -and -not(Test-Path -LiteralPath "$run/visual-reviewed.json")){
            Start-Sleep -Milliseconds 500;$visualProcess.Refresh()
        }
        if(-not(Test-Path -LiteralPath "$run/visual-reviewed.json")){throw "Visual review incomplete: $run"}
        $summary.visual=Get-Content -LiteralPath "$run/visual-reviewed.json" -Raw|ConvertFrom-Json
    }finally{if(-not $visualProcess.HasExited){$visualProcess.Kill();$visualProcess.WaitForExit()}}
}
# Unlink only this run's direct dependency junctions, never their source targets.
foreach($link in Get-ChildItem -LiteralPath $mods -Directory){
    if($link.Attributes -band [IO.FileAttributes]::ReparsePoint){
        if(-not $link.FullName.StartsWith([IO.Path]::GetFullPath($mods)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected dependency link location'}
        [IO.Directory]::Delete($link.FullName)
    }
}
$completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode 0 -Summary $summary
if($completed.status -ne 'success'){throw ('Artifact closeout failed: '+$completed.housekeeping_error)}
Set-EsirArtifactRunState -RepoRoot $repo -RunId $registration.id -Action close | Out-Null
$summary|ConvertTo-Json -Depth 5
