param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('absent','disabled','enabled','incompatible','standalone-unloaded','standalone-example')][string]$Scenario='enabled',
    [ValidateSet('on','off')][string]$Mode='on',
    [string]$ArtifactMap,[string]$MechanicalData,[string]$Anchors,[string]$AssetsManifest,[string]$Finalized,
    [string]$RunPath,[string]$AnalysisOutput,[string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepoRoot)
$engine='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$helperName='zzz-esir-minigun-consumer';$sd='exotic-space-industries-remembrance-graphics-6';$hd='minigun-turret-HD'
$oldHd='exotic-space-industries-remembrance-graphics-hd';$seed=Join-Path $repo '.factorio-qc/fmqc/mods-live'
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
if($Task -eq 'Stage') {
    if($RunPath){throw 'Stage always creates a fresh managed payload'}
    foreach($path in @($ArtifactMap,$MechanicalData,$Anchors,$AssetsManifest)) {
        if(-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)){throw 'Explicit frozen map, mechanics, anchors and native PNG manifest are required'}
    }
    $standalone=$Scenario.StartsWith('standalone-')
    if($standalone -and $Mode -ne 'off'){throw 'Standalone runs have no ESIR doctrine setting; use Mode off'}
    $label="$Scenario-$Mode-"+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $retained='output/minigun-implementation/consumer-results/'+$label
    $record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-consumer-fixture' -Scenario "$Scenario-$Mode" -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction 'Use explicit consumer-stage.json and fixture-plan.json inputs' -RetainedPaths @("$retained/summary.json")
    $run=Join-Path $repo $record.payload_path;$mods=Join-Path $run 'mods';$helper=Join-Path $mods $helperName
    $null=New-Item -ItemType Directory -Path $helper
    if(-not $standalone) {
        foreach($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
            if($archive.Name -notlike ($oldHd+'_*.zip') -and $archive.Name -notlike ($sd+'_*.zip') -and $archive.Name -notlike ($hd+'_*.zip')) {
                $null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName
            }
        }
        foreach($directory in Get-ChildItem -LiteralPath $repo -Directory) {
            if($directory.Name -like 'exotic-space-industries-remembrance*' -and $directory.Name -notin @($oldHd,$sd,$hd) -and (Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json'))) {
                $null=New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName
            }
        }
    }
    foreach($name in @('build_fixture.py','analyze_fixture.py','control.lua','data-final-fixes.lua','settings-updates.lua')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $helper}
    $args=@('-B',(Join-Path $helper 'build_fixture.py'),'--repo',$repo,'--output',$helper,'--artifact-map',$ArtifactMap,'--mechanical-data',$MechanicalData,'--anchors',$Anchors,'--assets-manifest',$AssetsManifest,'--scenario',$Scenario,'--mode',$Mode)
    if($Finalized){$args+=@('--finalized',$Finalized)}
    & python @args
    if($LASTEXITCODE -ne 0){throw 'Consumer stage failed; no engine started'}
    $plan=Get-Content -LiteralPath (Join-Path $helper 'fixture-plan.json') -Raw | ConvertFrom-Json
    if($standalone){$list=@{mods=@(@{name='base';enabled=$true})}}
    else {
        $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
        $list.mods=@($list.mods | Where-Object {$_.name -notin @($oldHd,$sd,$hd,$helperName)})
        foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark|zzz-esir-minigun'){$mod.enabled=$false}}
        $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/info.json') -Raw | ConvertFrom-Json
        foreach($dependency in $info.dependencies) {if($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$'){foreach($mod in $list.mods){if($mod.name -eq $Matches[1]){$mod.enabled=$false}}}}
        $list.mods+=@{name=$sd;enabled=$true}
    }
    if($Scenario -ne 'absent'){$list.mods+=@{name=$hd;enabled=($Scenario -ne 'disabled')}}
    $list.mods+=@{name=$helperName;enabled=$true}
    $list | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false',
      '[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
    $hashes=@{}
    if(-not $standalone) {foreach($source in @('exotic-space-industries-remembrance/info.json','exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret.lua','exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics.lua')) {$hashes[$source]=(Get-FileHash -LiteralPath (Join-Path $repo $source) -Algorithm SHA256).Hash}}
    if(-not $standalone -and $Finalized) {
        $source='exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua'
        $hashes[$source]=(Get-FileHash -LiteralPath (Join-Path $repo $source) -Algorithm SHA256).Hash
    }
    $helperHashes=@{};foreach($file in Get-ChildItem -LiteralPath $helper -File){$helperHashes[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    $stage=@{schema=1;record=$record;retained=$retained;scenario=$Scenario;mode=$Mode;lineage=$plan.config.lineage;source_hashes=$hashes;helper_hashes=$helperHashes;engine_started=$false}
    $stage | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $run 'consumer-stage.json') -Encoding UTF8
    Write-Output "STAGED ONLY; no engine started. RunPath: $run";return
}
if(-not $RunPath){throw 'RunPath required'}
if($Task -eq 'Run' -and $AnalysisOutput){throw 'Run uses its registered retained path; AnalysisOutput is for Analyze only'}
$run=[IO.Path]::GetFullPath($RunPath);$managed=[IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc/managed'))+[IO.Path]::DirectorySeparatorChar
if(-not $run.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)){throw 'RunPath outside managed QC root'}
$stage=Get-Content -LiteralPath (Join-Path $run 'consumer-stage.json') -Raw | ConvertFrom-Json
if([IO.Path]::GetFullPath((Join-Path $repo $stage.record.payload_path)) -ne $run){throw 'Managed run identity mismatch'}
$mods=Join-Path $run 'mods';$helper=Join-Path $mods $helperName
$retained=if($AnalysisOutput){[IO.Path]::GetFullPath($AnalysisOutput)}else{Join-Path $repo $stage.retained}
if(-not $retained.StartsWith([IO.Path]::GetFullPath((Join-Path $repo 'output'))+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $retained)){throw 'Use a fresh retained directory beneath output'}
if($Task -eq 'Run') {
    if($stage.engine_started){throw 'Already attempted; stage a fresh payload'}
    if(Get-Process -Name factorio -ErrorAction SilentlyContinue){throw 'Factorio already running'}
    if(Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '(--background|\s-b\s)'}){throw 'Background Blender active; heavy jobs must stay serial'}
    foreach($entry in $stage.source_hashes.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $repo $entry.Name) -Algorithm SHA256).Hash -ne $entry.Value){throw 'Main source changed since Stage'}}
    foreach($entry in $stage.helper_hashes.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $helper $entry.Name) -Algorithm SHA256).Hash -ne $entry.Value){throw 'Fixture code/input changed since Stage'}}
    & python -B (Join-Path $helper 'analyze_fixture.py') --verify-plan $helper
    if($LASTEXITCODE -ne 0){throw 'Staged asset pack byte verification failed'}
    $version=& $engine --version | Out-String
    if($LASTEXITCODE -ne 0 -or $version -notmatch 'Version:\s*2\.0\.77\b'){throw 'Pinned Factorio2.0.77 required'}
    $alias=Join-Path $env:TEMP ('esir-mg-consumer-'+$stage.record.id.Substring(0,8))
    if(Test-Path -LiteralPath $alias){throw 'Existing temporary alias'}
    $null=New-Item -ItemType Junction -Path $alias -Target $mods
    $oldApp=$env:SteamAppId;$oldGame=$env:SteamGameId
    try {
        $stage.engine_started=$true;$stage | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $run 'consumer-stage.json') -Encoding UTF8
        $env:SteamAppId='427520';$env:SteamGameId='427520'
        $common=@('--config',('"'+(Join-Path $run 'config.ini')+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio')
        $save=Join-Path $run 'fixture.zip'
        $process=Start-Process -FilePath $engine -ArgumentList (@('--create',('"'+$save+'"'),'--map-gen-seed','42')+$common) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'create.log') -RedirectStandardError (Join-Path $run 'create-error.log')
        $null=$process.Handle;while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        $createExit=$process.ExitCode;$graphicsExit=$null
        if($createExit -eq 0 -and $stage.scenario -ne 'incompatible') {
            $process=Start-Process -FilePath $engine -ArgumentList (@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','660','--benchmark-runs','1','--window-size','1280x960','--disable-migration-window')+$common) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'graphics.log') -RedirectStandardError (Join-Path $run 'graphics-error.log')
            $null=$process.Handle;while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()};$graphicsExit=$process.ExitCode
        }
        @{create_exit_code=$createExit;graphics_exit_code=$graphicsExit;engine_version='2.0.77'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'consumer-execution.json') -Encoding UTF8
    } finally {
        $env:SteamAppId=$oldApp;$env:SteamGameId=$oldGame
        if(Test-Path -LiteralPath $alias){$link=Get-Item -LiteralPath $alias;if(-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or [IO.Path]::GetFullPath(@($link.Target)[0]) -ne [IO.Path]::GetFullPath($mods)){throw 'Unexpected alias; refusing unlink'};[IO.Directory]::Delete($alias)}
    }
}
& python -B (Join-Path $helper 'analyze_fixture.py') --run $run --output $retained
$exit=$LASTEXITCODE
if($Task -eq 'Run' -and $exit -in @(0,2,3) -and (Test-Path -LiteralPath (Join-Path $retained 'summary.json'))) {
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}) {
        $expected=[IO.Path]::GetFullPath((Join-Path $repo $link.Name))
        if([IO.Path]::GetFullPath(@($link.Target)[0]) -ne $expected -or -not (Test-Path -LiteralPath (Join-Path $expected 'info.json'))){throw 'Unexpected source junction; refusing to unlink'}
        [IO.Directory]::Delete($link.FullName)
    }
    $summary=@{timestamp=[DateTime]::UtcNow.ToString('o');run_id=$stage.record.id;workflow=$stage.record.workflow;engine_version='2.0.77';repo_root=$repo;
        payload_path=$stage.record.payload_path;overall_status=$(if($exit -eq 2){'error'}elseif($exit -eq 3){'warning'}else{'ok'});
        result='Native consumer observations retained; explicit image review remains required'}
    $null=Complete-EsirArtifactRun -RepoRoot $repo -RunId $stage.record.id -ExitCode $(if($exit -eq 3){0}else{$exit}) -Summary $summary
    $closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $stage.record.id -Action close
    $closed | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $retained 'managed-run.json') -Encoding UTF8
}
if($exit -ne 0 -and $exit -ne 3){throw 'Consumer native checks failed; retained evidence is not acceptance'}
Write-Output "Consumer evidence: $retained; native checks exit=$exit, explicit visual review remains required"
