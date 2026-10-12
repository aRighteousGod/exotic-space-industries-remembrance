param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('on','off')][string]$Mode='on',
    [ValidateSet('sd','hd')][string]$Profile='sd',
    [ValidateSet('pilot','full')][string]$Coverage='pilot',
    [switch]$CalibrationOnly,
    [switch]$IncludeMoving,
    [switch]$IncludeWiredPreview,
    [switch]$HeadingTemplates,
    [switch]$CompactHeadingTemplates,
    [string]$CandidateData,
    [string]$CandidateAssets,
    [string]$MechanicalData,
    [string]$Calibration,
    [string]$Anchors,
    [string]$Review,
    [ValidateSet('copy','hardlink')][string]$CaptureStorage='hardlink',
    [string]$RunPath,
    [string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepoRoot)
$implementation=Join-Path $PSScriptRoot 'firing-fixture'
$engine='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
$helperName='zzz-esir-minigun-firing'
$sdName='exotic-space-industries-remembrance-graphics-6'
$hdName='minigun-turret-HD'
$legacyHdName='exotic-space-industries-remembrance-graphics-hd'
$sources=@('exotic-space-industries-remembrance\prototypes\electricity-age\gatling-turret.lua',
    'exotic-space-industries-remembrance\prototypes\electricity-age\gatling-turret\graphics.lua')
if(-not $Anchors){$Anchors=Join-Path $repo 'output\meshy\minigun-prototypes\prototype-2\handoff-256\muzzle-anchors.json'}
. (Join-Path $repo 'scripts\esir-housekeeping.ps1')

if($Task -eq 'Stage') {
    if($RunPath){throw '-RunPath is for Run/Analyze; Stage creates a new managed payload'}
    if(-not $CandidateData -or -not (Test-Path -LiteralPath $CandidateData -PathType Leaf)){throw 'Stage requires the explicit candidate graphics-data Lua file'}
    if(-not (Test-Path -LiteralPath $Anchors -PathType Leaf)){throw 'Muzzle geometry proposals are missing'}
    # Both source roots are explicit; a stale seed must not choose another pack.
    foreach($requiredPack in @($sdName,$hdName)) {
        $packInfoPath=Join-Path $repo ($requiredPack+'\info.json')
        if(-not (Test-Path -LiteralPath $packInfoPath -PathType Leaf)){throw "Missing graphics source pack: $requiredPack"}
        $packInfo=Get-Content -LiteralPath $packInfoPath -Raw | ConvertFrom-Json
        if($packInfo.name -ne $requiredPack){throw "Graphics source folder/name mismatch: $requiredPack"}
    }
    if(-not (Test-Path -LiteralPath (Join-Path $seed 'mod-list.json'))){throw 'Pinned native QC dependency seed is missing'}
    if($CalibrationOnly -and $Coverage -ne 'pilot'){throw '-CalibrationOnly requires -Coverage pilot'}
    if($CalibrationOnly -and $IncludeMoving){throw '-CalibrationOnly is eight static cases; use ordinary pilot/full coverage for moving fire'}
    if($HeadingTemplates -and $CompactHeadingTemplates){throw 'Choose compact or diagnostic heading templates, not both'}
    $scenario="$Profile-$Mode-$Coverage"+$(if($CalibrationOnly){'-calibration'}else{'-acceptance'})
    if($HeadingTemplates){$scenario+='-heading-templates'}
    if($CompactHeadingTemplates){$scenario+='-compact-templates'}
    $label=$scenario+'-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $retained='output/meshy/minigun-prototypes/prototype-2/handoff-256/firing-fixture/'+$label
    $record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-firing-fixture' -Scenario $scenario -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction "Use this run's firing-fixture-stage.json inputs with invoke-firing-fixture.ps1 -Task Stage" -RetainedPaths @("$retained/summary.json","$retained/native-report.json")
    $run=Join-Path $repo $record.payload_path
    $mods=Join-Path $run 'mods'
    $helper=Join-Path $mods $helperName
    $null=New-Item -ItemType Directory -Path $helper
    foreach($archive in (Get-ChildItem -LiteralPath $seed -File -Filter '*.zip' | Where-Object {$_.Name -notlike ($legacyHdName+'_*.zip') -and $_.Name -notlike ($hdName+'_*.zip') -and $_.Name -notlike ($sdName+'_*.zip')})) {
        $null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName
    }
    foreach($directory in (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {($_.Name -like 'exotic-space-industries-remembrance*' -and $_.Name -ne $legacyHdName) -or $_.Name -eq $hdName})) {
        if(Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json')) {
            $null=New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName
        }
    }
    Get-ChildItem -LiteralPath $implementation -File | Copy-Item -Destination $helper
    $build=@('-B',(Join-Path $helper 'build_fixture.py'),'--output',$helper,'--anchors',$Anchors,
        '--candidate-data',$CandidateData,'--mode',$Mode,'--profile',$Profile,'--coverage',$Coverage)
    if($CandidateAssets){$build+=@('--candidate-assets',$CandidateAssets)}
    if($MechanicalData){$build+=@('--mechanical-data',$MechanicalData)}
    if($Calibration){$build+=@('--calibration',$Calibration)}
    if($CalibrationOnly){$build+='--calibration-only'}
    if($IncludeMoving){$build+='--include-moving'}
    if($IncludeWiredPreview){$build+='--include-wired-preview'}
    if($HeadingTemplates){$build+='--heading-templates'}
    if($CompactHeadingTemplates){$build+='--compact-heading-templates'}
    & python @build
    if($LASTEXITCODE -ne 0){throw 'Firing fixture generation failed; staged payload remains protected'}
    $plan=Get-Content -LiteralPath (Join-Path $helper 'fixture-plan.json') -Raw | ConvertFrom-Json
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object {$_.name -ne $helperName -and $_.name -ne $hdName})
    foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark|zzz-esir-minigun'){$mod.enabled=$false}}
    $list.mods=@($list.mods | Where-Object {$_.name -notin @($legacyHdName,$hdName,$sdName)})
    $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance\info.json') -Raw | ConvertFrom-Json
    foreach($dependency in $info.dependencies) {
        if($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') {
            $conflict=$Matches[1]
            foreach($mod in $list.mods){if($mod.name -eq $conflict){$mod.enabled=$false}}
        }
    }
    # Factorio enables newly discovered roots by default. SD must explicitly
    # disable HD; omission from the seed list is not a disabled-profile test.
    $list.mods+=@{name=$sdName;enabled=$true}
    $list.mods+=@{name=$hdName;enabled=($Profile -eq 'hd')}
    $list.mods+=@{name=$helperName;enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",
        '[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false',
        '[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
    $hashes=@{}
    foreach($source in $sources){$hashes[$source]=(Get-FileHash -LiteralPath (Join-Path $repo $source) -Algorithm SHA256).Hash}
    $stage=@{schema=1;record=$record;mode=$Mode;profile=$Profile;coverage=$Coverage;retained=$retained;
        calibration_only=$CalibrationOnly.IsPresent;include_moving=$plan.config.include_moving;include_wired_preview=$IncludeWiredPreview.IsPresent;
        heading_templates=$HeadingTemplates.IsPresent;
        compact_heading_templates=$CompactHeadingTemplates.IsPresent;
        capture_storage=$CaptureStorage;
        maximum_native_pixel_error=2;attachment_goal_native_pixels=1;
        source_hashes=$hashes;candidate_data=[IO.Path]::GetFullPath($CandidateData);candidate_assets=$CandidateAssets;
        mechanical_data=$MechanicalData;anchors=[IO.Path]::GetFullPath($Anchors);calibration=$Calibration;
        benchmark_ticks=$plan.benchmark_ticks;staged_at=[DateTime]::UtcNow.ToString('o');engine_started=$false}
    $stage | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'firing-fixture-stage.json') -Encoding UTF8
    Write-Output "STAGED ONLY; Factorio was not started. RunPath: $run"
    Write-Output "Native cases: $($plan.config.case_count); ticks: $($plan.benchmark_ticks); pending image-backed review after Run."
    return
}

if(-not $RunPath){throw '-RunPath is required for Run/Analyze'}
$run=[IO.Path]::GetFullPath($RunPath)
$managed=[IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc\managed'))+[IO.Path]::DirectorySeparatorChar
if(-not $run.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)){throw 'RunPath must be this repository managed QC payload'}
$stage=Get-Content -LiteralPath (Join-Path $run 'firing-fixture-stage.json') -Raw | ConvertFrom-Json
if([IO.Path]::GetFullPath((Join-Path $repo $stage.record.payload_path)) -ne $run){throw 'Stage record path mismatch'}
$mods=Join-Path $run 'mods'
$helper=Join-Path $mods $helperName
$retained=Join-Path $repo $stage.retained
$null=New-Item -ItemType Directory -Force -Path $retained
if($Task -eq 'Run') {
    if($stage.engine_started){throw 'Execution was already attempted; stage a fresh payload to preserve evidence'}
    if(Get-Process -Name factorio -ErrorAction SilentlyContinue){throw 'Factorio is already running; heavy jobs must stay serial'}
    $backgroundBlender=Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '(--background|\s-b\s)'}
    if($backgroundBlender){throw 'A background Blender job is active; heavy jobs must stay serial'}
    foreach($entry in $stage.source_hashes.PSObject.Properties) {
        if((Get-FileHash -LiteralPath (Join-Path $repo $entry.Name) -Algorithm SHA256).Hash -ne $entry.Value){throw "Source changed since Stage: $($entry.Name)"}
    }
    # Out-String waits for this Windows GUI executable to finish writing/version
    # exit instead of inspecting a still-running process's partial output.
    $version=& $engine --version | Out-String
    if($LASTEXITCODE -ne 0 -or $version -notmatch 'Version:\s*2\.0\.77\b'){throw 'Fixture requires installed Factorio 2.0.77'}
    $config=Join-Path $run 'config.ini'
    $save=Join-Path $run 'fixture.zip'
    $alias=Join-Path $env:TEMP ('esir-mg-firing-'+$stage.record.id.Substring(0,8))
    if(Test-Path -LiteralPath $alias){throw 'Temporary alias already exists; inspect before reuse'}
    $null=New-Item -ItemType Junction -Path $alias -Target $mods
    $oldApp=$env:SteamAppId
    $oldGame=$env:SteamGameId
    try {
        $stage.engine_started=$true
        $stage | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'firing-fixture-stage.json') -Encoding UTF8
        $env:SteamAppId='427520';$env:SteamGameId='427520'
        $create=@('--create',('"'+$save+'"'),'--map-gen-seed','42','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio')
        $process=Start-Process -FilePath $engine -ArgumentList $create -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'create.log') -RedirectStandardError (Join-Path $run 'create-error.log')
        $null=$process.Handle
        while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        if($process.ExitCode -ne 0){throw 'Native firing save creation failed; inspect create.log'}
        $arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks',[string]$stage.benchmark_ticks,'--benchmark-runs','1','--window-size','1024x768','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio','--disable-migration-window')
        $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'graphics.log') -RedirectStandardError (Join-Path $run 'graphics-error.log')
        $null=$process.Handle
        while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        if($process.ExitCode -ne 0){throw 'Native firing capture failed; inspect graphics.log'}
    } finally {
        $env:SteamAppId=$oldApp;$env:SteamGameId=$oldGame
        if(Test-Path -LiteralPath $alias) {
            $link=Get-Item -LiteralPath $alias
            if(-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or [IO.Path]::GetFullPath(@($link.Target)[0]) -ne [IO.Path]::GetFullPath($mods)){throw 'Unexpected alias; refusing to unlink'}
            [IO.Directory]::Delete($alias)
        }
    }
}
$analyze=@('-B',(Join-Path $helper 'analyze_fixture.py'),'--run',$run,'--output',$retained,'--tolerance-native-pixels','2')
if($stage.capture_storage){$analyze+=@('--capture-storage',$stage.capture_storage)}
if($Review){$analyze+=@('--review',$Review)}
& python @analyze
$analysisExit=$LASTEXITCODE
foreach($name in @('create.log','create-error.log','graphics.log','graphics-error.log','firing-fixture-stage.json')) {
    $path=Join-Path $run $name
    if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination $retained}
}
if($Task -eq 'Run') {
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}) {
        $expected=[IO.Path]::GetFullPath((Join-Path $repo $link.Name))
        if([IO.Path]::GetFullPath(@($link.Target)[0]) -ne $expected -or -not (Test-Path -LiteralPath (Join-Path $expected 'info.json'))){throw 'Unexpected source junction; refusing to unlink'}
        [IO.Directory]::Delete($link.FullName)
    }
    $summary=@{run_id=$stage.record.id;workflow=$stage.record.workflow;engine_version=$stage.record.engine_version;
        repo_root=$stage.record.repo_root;payload_path=$stage.record.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');
        overall_status=$(if($analysisExit -eq 2){'error'}else{'warning'});
        result='Native firing artifacts retained; image-backed alignment and mechanical gates remain explicit in summary.json'}
    $completionExit=$(if($analysisExit -eq 3){0}else{$analysisExit})
    $completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $stage.record.id -ExitCode $completionExit -Summary $summary
    $closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $stage.record.id -Action close
    $closed | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $retained 'managed-run.json') -Encoding UTF8
}
Write-Output "Firing fixture analysis exit=$analysisExit; retained evidence: $retained"
if($analysisExit -eq 3){Write-Warning 'Native captures exist, but image-backed review is pending; the alignment gate has NOT passed';return}
if($analysisExit -ne 0){throw 'Firing alignment gates failed; inspect retained summary.json'}
