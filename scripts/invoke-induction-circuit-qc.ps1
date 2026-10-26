[CmdletBinding()]
param([switch]$SaveReload, [switch]$PrepareOnly, [switch]$CaptureLocales)
$ErrorActionPreference='Stop'
if($CaptureLocales -and -not $SaveReload){throw 'CaptureLocales requires SaveReload'}
$repo=Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot/esir-housekeeping.ps1"
$registration=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'induction-circuit' -Scenario 'native' -EngineVersion '2.0.77' -PayloadPath ('.factorio-qc/managed/im-'+[Guid]::NewGuid().ToString('N').Substring(0,8)) -Reproduction 'powershell -ExecutionPolicy Bypass -File scripts/invoke-induction-circuit-qc.ps1 -SaveReload'
$payload=Join-Path $repo $registration.payload_path
New-Item -ItemType Directory -Path $payload -Force | Out-Null
$helper=Join-Path $PSScriptRoot 'qc/induction-circuit'
$source=Join-Path $repo 'exotic-space-industries-remembrance'
$seedSave=Join-Path $repo '.factorio-qc/wtr/player/fixture.zip'
& "$PSScriptRoot/invoke-control-ups-qc.ps1" -RunName n -BaselineSource $source -Helper $helper -BridgePath "$helper/instrument.lua" -SaveInput $seedSave -PrepareOnly -CaptureConfiguration -OutputRoot $payload | Out-Null
$run=Join-Path $payload 'n'
$mods=Join-Path $run 'mods'
$utf8=[Text.UTF8Encoding]::new($false)
$nativeRun=& python -B -c 'import ctypes,sys; b=ctypes.create_unicode_buffer(4096); n=ctypes.windll.kernel32.GetShortPathNameW(sys.argv[1],b,len(b)); assert n; print(b.value)' $run
if($LASTEXITCODE -ne 0){throw 'Could not resolve native QC path'}
$nativeMods=Join-Path $nativeRun 'mods'
$config=[IO.File]::ReadAllText("$run/config.ini").Replace($run.Replace('\','/'),$nativeRun.Replace('\','/'))
[IO.File]::WriteAllText("$run/config.ini",$config,$utf8)
$list=Get-Content -LiteralPath "$mods/mod-list.json" -Raw | ConvertFrom-Json
# The seed contains a legacy optional minigun; current standalone sources target 2.1.
$list.mods=@($list.mods|Where-Object {$_.name -ne 'exotic-space-industries-remembrance-graphics-6' -and $_.name -ne 'minigun-turret-HD'})+@(@{name='exotic-space-industries-remembrance-graphics-6';enabled=$true})
[IO.File]::WriteAllText("$mods/mod-list.json",($list|ConvertTo-Json -Depth 8),$utf8)
[IO.File]::WriteAllText("$run/registration.json",($registration|ConvertTo-Json -Depth 8),$utf8)
Write-Output "MATRIX_QC_RUN $run"
if($PrepareOnly){return}
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
function Wait-MatrixEngineIdle {
    if(Get-Process factorio -ErrorAction SilentlyContinue){
        Write-Output 'Waiting for Factorio to close before matrix validation.'
        while(Get-Process factorio -ErrorAction SilentlyContinue){Start-Sleep -Milliseconds 500}
    }
}
function Invoke-MatrixEngine([string[]]$Extra,[string]$Tag){
    Wait-MatrixEngineIdle
    $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeMods+'"'),'--disable-audio')+$Extra
    $process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/$Tag-stdout.txt" -RedirectStandardError "$run/$Tag-stderr.txt"
    $process.Handle|Out-Null
    if(-not $process.WaitForExit(300000)){$process.Kill();throw "Owned QC process timed out: $run"}
    $process.Refresh()
    Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/$Tag.log"
    if(($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or (Select-String -LiteralPath "$run/$Tag.log" -Pattern 'Error Util.cpp|Error while running event' -Quiet)){
        Get-Content -LiteralPath "$run/$Tag-stdout.txt" -Tail 18
        throw "Matrix QC failed: $run/$Tag.log"
    }
}
Invoke-MatrixEngine @('--benchmark',('"'+$seedSave+'"'),'--benchmark-ticks','960','--benchmark-runs','1') 'runtime'
if(-not(Select-String -LiteralPath "$run/runtime.log" -Pattern 'Factorio 2\.0\.77 \(build' -Quiet)){
    throw 'Matrix acceptance requires the Factorio 2.0.77 engine'
}
$reportPath=Join-Path $run 'script-output/induction-circuit.json'
if(-not(Test-Path -LiteralPath $reportPath)){throw 'Matrix report missing'}
$report=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
if(-not $report.all_pass){throw 'Matrix runtime checks failed'}
$reloads=@()
if($SaveReload){
    New-Item -ItemType Directory -Path "$run/saves" -Force | Out-Null
    [IO.File]::AppendAllText("$run/config.ini","`n[graphics]`nfull-screen=false`nhalt-rendering-when-minimized=false`nmax-sprite-loading-threads=2`n",$utf8)
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeMods+'"'),'--disable-audio','--disable-migration-window',
        '--load-game',('"'+$seedSave+'"'),'--window-size','1280x720','--graphics-quality','medium','--video-memory-usage','low','--max-texture-size','8192')
    Wait-MatrixEngineIdle
    $client=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/save-stdout.txt" -RedirectStandardError "$run/save-stderr.txt"
    $client.Handle|Out-Null
    $saved=Join-Path $run 'saves/_autosave-induction-circuit.zip'
    $deadline=[DateTime]::UtcNow.AddMinutes(5)
    try{
        while(-not $client.HasExited -and [DateTime]::UtcNow -lt $deadline){
            Start-Sleep -Milliseconds 500;$client.Refresh()
            if(Test-Path -LiteralPath $saved){
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                try{$archive=[IO.Compression.ZipFile]::OpenRead($saved);$archive.Dispose();break}catch{}
            }
            if(Test-Path -LiteralPath "$run/save-stdout.txt"){
                if(Select-String -LiteralPath "$run/save-stdout.txt" -Pattern 'Error while running|Error Util.cpp' -Quiet){throw 'Matrix save client failed'}
            }
        }
        if(-not(Test-Path -LiteralPath $saved)){throw 'Matrix checkpoint not created'}
    }finally{if(-not $client.HasExited){$client.Kill();$client.WaitForExit()}}
    Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/save.log"
    foreach($kind in @('ordinary','configuration')){
        if($kind -eq 'configuration'){
            $infoPath=Join-Path $mods 'zzz-esir-induction-circuit-qc/info.json'
            $info=Get-Content -LiteralPath $infoPath -Raw|ConvertFrom-Json;$info.version='0.0.2'
            [IO.File]::WriteAllText($infoPath,($info|ConvertTo-Json -Depth 5),$utf8)
        }
        Invoke-MatrixEngine @('--benchmark',('"'+$saved+'"'),'--benchmark-ticks','60','--benchmark-runs','1') "reload-$kind"
        if(-not(Select-String -LiteralPath "$run/reload-$kind.log" -Pattern "INDUCTION_CIRCUIT_QC RELOAD_PASS $kind" -Quiet)){throw "Reload failed: $kind"}
        $reloads+=@{kind=$kind;all_pass=$true}
    }
}
$summary=@{run_id=$registration.id;workflow=$registration.workflow;engine_version='2.0.77';repo_root=$repo;payload_path=$registration.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';checks=$report.checks;report=$reportPath;reloads=$reloads}
if($CaptureLocales){
    & "$PSScriptRoot/invoke-induction-circuit-captures.ps1" -RunDirectory $run
    if($LASTEXITCODE -ne 0){throw 'Locale capture failed'}
    $summary.capture_receipts=Join-Path $run 'capture-receipts.json'
}
[IO.File]::WriteAllText("$run/summary.json",($summary|ConvertTo-Json -Depth 8),$utf8)
# Unlink only this run's direct junctions, never their shipping source targets.
foreach($link in Get-ChildItem -LiteralPath $mods -Directory){
    if($link.Attributes -band [IO.FileAttributes]::ReparsePoint){
        if(-not $link.FullName.StartsWith([IO.Path]::GetFullPath($mods)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected dependency link location'}
        [IO.Directory]::Delete($link.FullName)
    }
}
$complete=Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode 0 -Summary $summary
if($complete.status -ne 'success'){throw ('Artifact closeout failed: '+$complete.housekeeping_error)}
Set-EsirArtifactRunState -RepoRoot $repo -RunId $registration.id -Action close | Out-Null
$summary|ConvertTo-Json -Depth 8
