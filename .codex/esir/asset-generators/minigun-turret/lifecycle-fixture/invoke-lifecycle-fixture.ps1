param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('sd','hd')][string]$Profile='sd',
    [ValidateSet('on','off')][string]$Mode='on',
    [string]$CandidateData,[string]$CandidateAssets,[string]$MechanicalData,[string]$Anchors,
    [string]$AssetsManifest,[string]$EvidenceContract,
    [ValidateRange(0,120)][int]$FoldDelayTicks=0,
    [ValidateRange(0,900)][int]$FreezeLeadTicks=0,
    [string]$RunPath,[string]$AnalysisOutput,[string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepoRoot)
$engine='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$helperName='zzz-esir-minigun-firing' # Keeps the exact tested candidate PNG paths/Lua bytes.
$sd='exotic-space-industries-remembrance-graphics-6'
$hd='minigun-turret-HD'
$oldHd='exotic-space-industries-remembrance-graphics-hd'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
. (Join-Path $repo 'scripts\esir-housekeeping.ps1')
if(-not $EvidenceContract){$EvidenceContract=Join-Path $repo '.codex/esir/asset-generators/minigun-turret/firing-fixture/evidence_contract.py'}

if($Task -eq 'Stage') {
    if($RunPath){throw 'Stage always creates a new isolated managed payload'}
    foreach($path in @($CandidateData,$MechanicalData,$Anchors,$AssetsManifest,$EvidenceContract)) {
        if(-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)){throw 'All explicit candidate/mechanics/anchors/atlas manifest/validator inputs are required'}
    }
    if(-not (Test-Path -LiteralPath $CandidateAssets -PathType Container)){throw 'CandidateAssets is required'}
    foreach($name in @($sd,$hd)) {
        $info=Get-Content -LiteralPath (Join-Path $repo ($name+'\info.json')) -Raw | ConvertFrom-Json
        if($info.name -ne $name){throw 'Graphics pack folder/name mismatch'}
    }
    $label="$Profile-$Mode-"+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $retained='output/minigun-implementation/lifecycle-results/'+$label
    $record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-lifecycle-fixture' -Scenario "$Profile-$Mode" -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction 'Replay explicit lifecycle-stage.json inputs through invoke-lifecycle-fixture.ps1' -RetainedPaths @("$retained/summary.json")
    $run=Join-Path $repo $record.payload_path
    $mods=Join-Path $run 'mods';$helper=Join-Path $mods $helperName
    $null=New-Item -ItemType Directory -Path $helper
    foreach($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
        if($archive.Name -notlike ($oldHd+'_*.zip') -and $archive.Name -notlike ($hd+'_*.zip') -and $archive.Name -notlike ($sd+'_*.zip')) {
            $null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName
        }
    }
    foreach($directory in Get-ChildItem -LiteralPath $repo -Directory) {
        if((($directory.Name -like 'exotic-space-industries-remembrance*' -and $directory.Name -ne $oldHd) -or $directory.Name -eq $hd) -and
           (Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json'))) {
            $null=New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName
        }
    }
    foreach($name in @('info.json','settings-updates.lua','data-final-fixes.lua','control.lua','build_fixture.py','analyze_fixture.py')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $helper
    }
    Copy-Item -LiteralPath $EvidenceContract -Destination (Join-Path $helper 'evidence_contract.py')
    & python -B (Join-Path $helper 'build_fixture.py') --repo $repo --output $helper --candidate-data $CandidateData --candidate-assets $CandidateAssets --mechanical-data $MechanicalData --anchors $Anchors --assets-manifest $AssetsManifest --evidence-contract (Join-Path $helper 'evidence_contract.py') --profile $Profile --mode $Mode --run-id $record.id --fold-delay-ticks $FoldDelayTicks --freeze-lead-ticks $FreezeLeadTicks
    if($LASTEXITCODE -ne 0){throw 'Lifecycle staging failed; no engine was started'}
    $plan=Get-Content -LiteralPath (Join-Path $helper 'fixture-plan.json') -Raw | ConvertFrom-Json
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object {$_.name -notin @($oldHd,$sd,$hd,$helperName)})
    foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark|zzz-esir-minigun'){$mod.enabled=$false}}
    $mainInfo=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/info.json') -Raw | ConvertFrom-Json
    foreach($dependency in $mainInfo.dependencies) {
        if($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') {foreach($mod in $list.mods){if($mod.name -eq $Matches[1]){$mod.enabled=$false}}}
    }
    $list.mods+=@{name=$sd;enabled=$true};$list.mods+=@{name=$hd;enabled=($Profile -eq 'hd')}
    $list.mods+=@{name=$helperName;enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]',
      'check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') |
      Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
    $hashes=@{}
    foreach($source in @('exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret.lua',
        'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics.lua')) {
        $hashes[$source]=(Get-FileHash -LiteralPath (Join-Path $repo $source) -Algorithm SHA256).Hash
    }
    $helperHashes=@{}
    foreach($file in Get-ChildItem -LiteralPath $helper -File){$helperHashes[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    $stage=@{schema=1;record=$record;retained=$retained;source_hashes=$hashes;helper_hashes=$helperHashes;
        engine_started=$false;profile=$Profile;mode=$Mode;baseline_ticks=$plan.baseline_ticks;resume_ticks=$plan.resume_ticks;
        checkpoint_prefix=$plan.config.checkpoint_prefix;lineage=$plan.config.lineage}
    $stage | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $run 'lifecycle-stage.json') -Encoding UTF8
    Write-Output "STAGED ONLY; no engine started. RunPath: $run"
    return
}

if(-not $RunPath){throw 'RunPath is required'}
$run=[IO.Path]::GetFullPath($RunPath)
$managed=[IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc/managed'))+[IO.Path]::DirectorySeparatorChar
if(-not $run.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)){throw 'RunPath is outside this repository managed QC directory'}
$stage=Get-Content -LiteralPath (Join-Path $run 'lifecycle-stage.json') -Raw | ConvertFrom-Json
if([IO.Path]::GetFullPath((Join-Path $repo $stage.record.payload_path)) -ne $run){throw 'Managed run identity mismatch'}
$mods=Join-Path $run 'mods';$helper=Join-Path $mods $helperName
$retained=if($AnalysisOutput){[IO.Path]::GetFullPath($AnalysisOutput)}else{Join-Path $repo $stage.retained}
$outputRoot=[IO.Path]::GetFullPath((Join-Path $repo 'output'))+[IO.Path]::DirectorySeparatorChar
if(-not $retained.StartsWith($outputRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Retained evidence must remain beneath repository output'}
if(Test-Path -LiteralPath $retained){throw 'Choose a fresh AnalysisOutput; retained evidence is immutable'}

if($Task -eq 'Run') {
    if($stage.engine_started){throw 'This payload already attempted native execution; stage a fresh one'}
    if(Get-Process -Name factorio -ErrorAction SilentlyContinue){throw 'Factorio is already running; heavy jobs must stay serial'}
    if(Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '(--background|\s-b\s)'}){throw 'Background Blender is active; keep heavy jobs serial'}
    foreach($entry in $stage.source_hashes.PSObject.Properties) {
        if((Get-FileHash -LiteralPath (Join-Path $repo $entry.Name) -Algorithm SHA256).Hash -ne $entry.Value){throw 'Production source changed since Stage'}
    }
    foreach($entry in $stage.helper_hashes.PSObject.Properties) {
        if((Get-FileHash -LiteralPath (Join-Path $helper $entry.Name) -Algorithm SHA256).Hash -ne $entry.Value){throw 'Fixture code/inputs changed since Stage'}
    }
    $version=& $engine --version | Out-String
    if($LASTEXITCODE -ne 0 -or $version -notmatch 'Version:\s*2\.0\.77\b'){throw 'Pinned Factorio 2.0.77 is required'}
    $alias=Join-Path $env:TEMP ('esir-mg-life-'+$stage.record.id.Substring(0,8))
    if(Test-Path -LiteralPath $alias){throw 'Temporary fixture alias already exists'}
    $null=New-Item -ItemType Junction -Path $alias -Target $mods
    $oldApp=$env:SteamAppId;$oldGame=$env:SteamGameId
    $config=Join-Path $run 'config.ini'
    function Invoke-LifecycleEngine([string]$Name,[string[]]$Arguments) {
        $process=Start-Process -FilePath $engine -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run ($Name+'.log')) -RedirectStandardError (Join-Path $run ($Name+'-error.log'))
        $null=$process.Handle
        while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        if($process.ExitCode -ne 0){throw "Native $Name failed; inspect its retained logs"}
    }
    try {
        $stage.engine_started=$true
        $stage | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $run 'lifecycle-stage.json') -Encoding UTF8
        $env:SteamAppId='427520';$env:SteamGameId='427520'
        $save=Join-Path $run 'fixture.zip'
        $common=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio')
        Invoke-LifecycleEngine 'create' (@('--create',('"'+$save+'"'),'--map-gen-seed','42')+$common)
        Invoke-LifecycleEngine 'baseline' (@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks',[string]$stage.baseline_ticks,'--benchmark-runs','1','--window-size','1024x768','--disable-migration-window')+$common)
        if(-not (Test-Path -LiteralPath (Join-Path $run 'script-output/minigun-lifecycle-baseline.json'))){throw 'Baseline never completed its bounded native case matrix'}
        foreach($phase in @('preparing','running','folding')) {
            $checkpoint=Join-Path $run ('saves/_autosave-'+$stage.checkpoint_prefix+'-'+$phase+'.zip')
            if(-not (Test-Path -LiteralPath $checkpoint -PathType Leaf)){throw "Actual $phase checkpoint save is missing; auto_save was not proven"}
            $before=(Get-FileHash -LiteralPath $checkpoint -Algorithm SHA256).Hash
            Invoke-LifecycleEngine ('resume-'+$phase) (@('--benchmark-graphics',('"'+$checkpoint+'"'),'--benchmark-ticks',[string]$stage.resume_ticks,'--benchmark-runs','1','--window-size','1024x768','--disable-migration-window')+$common)
            if((Get-FileHash -LiteralPath $checkpoint -Algorithm SHA256).Hash -ne $before){throw 'Replay mutated its source checkpoint'}
        }
    } finally {
        $env:SteamAppId=$oldApp;$env:SteamGameId=$oldGame
        if(Test-Path -LiteralPath $alias) {
            $link=Get-Item -LiteralPath $alias
            if(-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or [IO.Path]::GetFullPath(@($link.Target)[0]) -ne [IO.Path]::GetFullPath($mods)){throw 'Unexpected alias; refusing to unlink'}
            [IO.Directory]::Delete($alias)
        }
    }
}
& python -B (Join-Path $helper 'analyze_fixture.py') --run $run --output $retained --helper $helper
$exit=$LASTEXITCODE
if(Test-Path -LiteralPath $retained) {
    foreach($file in Get-ChildItem -LiteralPath $run -File | Where-Object {$_.Extension -eq '.log' -or $_.Name -eq 'lifecycle-stage.json'}) {
        Copy-Item -LiteralPath $file.FullName -Destination $retained
    }
}
if($Task -eq 'Run' -and $exit -in @(2,3)) {
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}) {
        $expected=[IO.Path]::GetFullPath((Join-Path $repo $link.Name))
        if([IO.Path]::GetFullPath(@($link.Target)[0]) -ne $expected -or -not (Test-Path -LiteralPath (Join-Path $expected 'info.json'))){throw 'Unexpected source junction; refusing to unlink'}
        [IO.Directory]::Delete($link.FullName)
    }
    $summary=@{timestamp=[DateTime]::UtcNow.ToString('o');run_id=$stage.record.id;workflow=$stage.record.workflow;engine_version='2.0.77';repo_root=$repo;
        payload_path=$stage.record.payload_path;overall_status=$(if($exit -eq 2){'error'}else{'warning'});
        result='Native lifecycle observations retained; signed-off image review is required before finalization'}
    $null=Complete-EsirArtifactRun -RepoRoot $repo -RunId $stage.record.id -ExitCode $(if($exit -eq 3){0}else{$exit}) -Summary $summary
    $closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $stage.record.id -Action close
    $closed | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $retained 'managed-run.json') -Encoding UTF8
}
Write-Output "Lifecycle analysis exit=$exit; evidence=$retained"
if($exit -eq 3){Write-Warning 'Automated lifecycle checks passed; actual native image review remains pending';return}
if($exit -ne 0){throw 'Lifecycle gate failed; do not convert a successful engine exit into acceptance'}
