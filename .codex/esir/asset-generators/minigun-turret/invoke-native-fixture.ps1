param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('on','off')][string]$Mode='on',
    [ValidateRange(0,120)][int]$FoldDelayTicks=0,
    [ValidateSet('native','color','shadow')][string]$FixtureKind='native',
    [string]$FixtureDirectory,
    [ValidateRange(60,60000)][int]$BenchmarkTicks=1580,
    [string]$RunPath,
    [string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepoRoot)
$implementation=if($FixtureDirectory){[IO.Path]::GetFullPath($FixtureDirectory)}else{Join-Path $PSScriptRoot 'native-fixture'}
$sdName='exotic-space-industries-remembrance-graphics-6'
$hdName='minigun-turret-HD'
$legacyHdName='exotic-space-industries-remembrance-graphics-hd'
$engine='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
$source=Join-Path $repo 'exotic-space-industries-remembrance\prototypes\electricity-age\gatling-turret.lua'
if(-not (Test-Path -LiteralPath $source)){throw 'Run from the ESIR repository or provide -RepoRoot'}
. (Join-Path $repo 'scripts\esir-housekeeping.ps1')

if($Task -eq 'Stage') {
    if($RunPath){throw '-RunPath is for Run/Analyze; Stage always creates a new managed payload'}
    # Both source roots are explicit; a stale seed must not choose another pack.
    foreach($requiredPack in @($sdName,$hdName)) {
        $packInfoPath=Join-Path $repo ($requiredPack+'\info.json')
        if(-not (Test-Path -LiteralPath $packInfoPath -PathType Leaf)){throw "Missing graphics source pack: $requiredPack"}
        $packInfo=Get-Content -LiteralPath $packInfoPath -Raw | ConvertFrom-Json
        if($packInfo.name -ne $requiredPack){throw "Graphics source folder/name mismatch: $requiredPack"}
    }
    if(-not (Test-Path -LiteralPath (Join-Path $seed 'mod-list.json'))){throw 'Pinned QC dependency seed is missing'}
    $color=$FixtureKind -eq 'color'
    $shadow=$FixtureKind -eq 'shadow'
    $helperName=if($color){'zzz-esir-minigun-color'}elseif($shadow){'zzz-esir-minigun-shadow'}else{'zzz-esir-minigun-native'}
    $workflow=if($color){'minigun-native-color-fixture'}elseif($shadow){'minigun-native-shadow-fixture'}else{'minigun-native-fixture'}
    $subfolder=if($color){'native-color-fixture'}elseif($shadow){'native-shadow-fixture'}else{'native-fixture'}
    $scenario=if($color){$env:ESIR_MINIGUN_COLOR_MATRIX+'-'+$env:ESIR_MINIGUN_COLOR_COMPRESSION}elseif($shadow){$env:ESIR_MINIGUN_SHADOW_MATRIX+'-'+$env:ESIR_MINIGUN_SHADOW_TIER+'-'+$env:ESIR_MINIGUN_SHADOW_COMPRESSION}else{$Mode}
    $label=$scenario+'-fold'+$FoldDelayTicks+'-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $retained='output/meshy/minigun-prototypes/prototype-2/handoff-256/'+$subfolder+'/'+$label
    $reproduction=if($color){"powershell -File .codex/esir/asset-generators/minigun-turret/invoke-color-fixture.ps1 -Task Stage -Matrix $env:ESIR_MINIGUN_COLOR_MATRIX -TextureCompression $env:ESIR_MINIGUN_COLOR_COMPRESSION -CompiledPath `"$env:ESIR_MINIGUN_COLOR_COMPILED`""}elseif($shadow){"powershell -File .codex/esir/asset-generators/minigun-turret/invoke-shadow-fixture.ps1 -Task Stage -Matrix $env:ESIR_MINIGUN_SHADOW_MATRIX -Tier $env:ESIR_MINIGUN_SHADOW_TIER -TextureCompression $env:ESIR_MINIGUN_SHADOW_COMPRESSION -ShadowCandidatesPath `"$env:ESIR_MINIGUN_SHADOW_CANDIDATES`" -ReferencePath `"$env:ESIR_MINIGUN_SHADOW_REFERENCE`""}else{"powershell -File .codex/esir/asset-generators/minigun-turret/invoke-native-fixture.ps1 -Task Stage -Mode $Mode -FoldDelayTicks $FoldDelayTicks"}
    $record=Register-EsirArtifactRun -RepoRoot $repo -Workflow $workflow -Scenario $scenario -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction $reproduction -RetainedPaths @("$retained/summary.json")
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
    $ballistic=($Mode -eq 'on').ToString().ToLowerInvariant()
    "return {ballistic=$ballistic,fold_delay_ticks=$FoldDelayTicks}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    & python -B (Join-Path $helper 'build_fixture.py') --output (Join-Path $helper 'graphics')
    if($LASTEXITCODE -ne 0){throw 'Diagnostic generation failed; staged payload remains protected'}
    if($color -or $shadow) {
        $inputName=if($color){'color-input-manifest.json'}else{'shadow-input-manifest.json'}
        $fixtureInputs=Get-Content -LiteralPath (Join-Path $helper $inputName) -Raw | ConvertFrom-Json
        $BenchmarkTicks=[int]$fixtureInputs.benchmark_ticks
        if($BenchmarkTicks -lt 60 -or $BenchmarkTicks -gt 60000){throw 'Fixture benchmark duration is out of bounds'}
    }
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object {$_.name -notmatch 'qc|benchmark|zzz-esir-minigun'})
    $list.mods=@($list.mods | Where-Object {$_.name -notin @($legacyHdName,$hdName,$sdName)})
    $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance\info.json') -Raw | ConvertFrom-Json
    foreach($dependency in $info.dependencies) {
        if($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') {
            $conflict=$Matches[1]
            foreach($mod in $list.mods){if($mod.name -eq $conflict){$mod.enabled=$false}}
        }
    }
    $list.mods+=@{name=$sdName;enabled=$true}
    $list.mods+=@{name=$hdName;enabled=$false}
    $list.mods+=@{name=$helperName;enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",
        '[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false',
        '[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
    $stage=@{schema=1;record=$record;mode=$Mode;fold_delay_ticks=$FoldDelayTicks;retained=$retained;
        fixture_kind=$FixtureKind;helper_name=$helperName;benchmark_ticks=$BenchmarkTicks;
        source_path=$source;source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;
        staged_at=[DateTime]::UtcNow.ToString('o');engine_started=$false}
    $stage | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'native-fixture-stage.json') -Encoding UTF8
    Write-Output "STAGED ONLY; Factorio was not started. RunPath: $run"
    Write-Output "Next: powershell -File .codex/esir/asset-generators/minigun-turret/invoke-native-fixture.ps1 -Task Run -RunPath `"$run`""
    return
}

if(-not $RunPath){throw '-RunPath is required for Run/Analyze'}
$run=[IO.Path]::GetFullPath($RunPath)
$managed=[IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc\managed'))+[IO.Path]::DirectorySeparatorChar
if(-not $run.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)){throw 'RunPath must be this repository managed QC payload'}
$stage=Get-Content -LiteralPath (Join-Path $run 'native-fixture-stage.json') -Raw | ConvertFrom-Json
if([IO.Path]::GetFullPath((Join-Path $repo $stage.record.payload_path)) -ne $run){throw 'Stage record path does not match'}
$mods=Join-Path $run 'mods'
$helperName=if($stage.PSObject.Properties.Name -contains 'helper_name'){$stage.helper_name}else{'zzz-esir-minigun-native'}
$kind=if($stage.PSObject.Properties.Name -contains 'fixture_kind'){$stage.fixture_kind}else{'native'}
$benchmark=if($stage.PSObject.Properties.Name -contains 'benchmark_ticks'){[int]$stage.benchmark_ticks}else{1580}
if($helperName -notin @('zzz-esir-minigun-native','zzz-esir-minigun-color','zzz-esir-minigun-shadow') -or $kind -notin @('native','color','shadow') -or $benchmark -lt 60 -or $benchmark -gt 60000){throw 'Unexpected staged fixture kind, helper or benchmark duration'}
$reportName=if($kind -eq 'color'){'minigun-native-color-report.json'}elseif($kind -eq 'shadow'){'minigun-native-shadow-report.json'}else{'minigun-native-report.json'}
$helper=Join-Path $mods $helperName
$retained=Join-Path $repo $stage.retained
$null=New-Item -ItemType Directory -Force -Path $retained

if($Task -eq 'Run') {
    if($stage.engine_started){throw 'Execution was already attempted for this payload; stage a new one to preserve evidence'}
    if($kind -in @('color','shadow')) {
        $inputName=if($kind -eq 'color'){'color-input-manifest.json'}else{'shadow-input-manifest.json'}
        $captureInputs=Get-Content -LiteralPath (Join-Path $helper $inputName) -Raw | ConvertFrom-Json
        if($captureInputs.PSObject.Properties.Name -notcontains 'capture_geometry' -or $captureInputs.capture_geometry -ne 'entity-relative-camera-v3') {
            throw 'This comparison payload predates the corrected camera geometry; stage a fresh smoke fixture'
        }
    }
    if(Get-Process -Name factorio -ErrorAction SilentlyContinue){throw 'Factorio is already running; keep heavy jobs serial'}
    $backgroundBlender=Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '(--background|\s-b\s)'}
    if($backgroundBlender){throw 'A background Blender job is active; keep heavy jobs serial'}
    if(Test-Path -LiteralPath (Join-Path $run ('script-output\'+$reportName))){throw 'This payload already ran; stage a new payload instead of replacing evidence'}
    if((Get-FileHash -LiteralPath $stage.source_path -Algorithm SHA256).Hash -ne $stage.source_sha256){throw 'Turret source changed since staging; stage a fresh fixture'}
    $versionProcess=Start-Process -FilePath $engine -ArgumentList @('--version') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $run 'version.log') -RedirectStandardError (Join-Path $run 'version-error.log')
    $version=Get-Content -LiteralPath (Join-Path $run 'version.log') -Raw
    if($versionProcess.ExitCode -ne 0 -or $version -notmatch 'Version:\s*2\.0\.77\b'){throw 'Fixture requires installed Factorio 2.0.77'}
    $config=Join-Path $run 'config.ini'
    $save=Join-Path $run 'fixture.zip'
    $alias=Join-Path $env:TEMP ('esir-mg-native-'+$stage.record.id.Substring(0,8))
    if(Test-Path -LiteralPath $alias){throw 'Temporary alias already exists; inspect before reusing'}
    $null=New-Item -ItemType Junction -Path $alias -Target $mods
    $oldApp=$env:SteamAppId
    $oldGame=$env:SteamGameId
    try {
        $stage.engine_started=$true
        $stage | Add-Member -NotePropertyName engine_started_at -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
        $stage | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'native-fixture-stage.json') -Encoding UTF8
        $env:SteamAppId='427520';$env:SteamGameId='427520'
        $createArgs=@('--create',('"'+$save+'"'),'--map-gen-seed','42','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio')
        $process=Start-Process -FilePath $engine -ArgumentList $createArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'create.log') -RedirectStandardError (Join-Path $run 'create-error.log')
        $null=$process.Handle
        while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        if($process.ExitCode -ne 0){throw 'Native fixture save creation failed; inspect create.log'}
        $arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks',([string]$benchmark),'--benchmark-runs','1','--window-size','1024x768','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio','--disable-migration-window')
        $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'graphics.log') -RedirectStandardError (Join-Path $run 'graphics-error.log')
        $null=$process.Handle
        while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
        if($process.ExitCode -ne 0){throw 'Native graphics fixture failed; inspect graphics.log'}
    } finally {
        $env:SteamAppId=$oldApp;$env:SteamGameId=$oldGame
        if(Test-Path -LiteralPath $alias) {
            $link=Get-Item -LiteralPath $alias
            if(-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                [IO.Path]::GetFullPath(@($link.Target)[0]) -ne [IO.Path]::GetFullPath($mods)){throw 'Unexpected alias; refusing to unlink'}
            [IO.Directory]::Delete($alias) # Nonrecursive unlink of this verified junction only.
        }
    }
}

& python -B (Join-Path $helper 'analyze_fixture.py') --run $run --output $retained
$analysisExit=$LASTEXITCODE
foreach($name in @('create.log','create-error.log','graphics.log','graphics-error.log','native-fixture-stage.json')) {
    $path=Join-Path $run $name
    if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination $retained}
}
if($Task -eq 'Run') {
    foreach($link in Get-ChildItem -LiteralPath $mods -Directory | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}) {
        $expected=[IO.Path]::GetFullPath((Join-Path $repo $link.Name))
        if([IO.Path]::GetFullPath(@($link.Target)[0]) -ne $expected -or
            -not (Test-Path -LiteralPath (Join-Path $expected 'info.json'))){throw 'Unexpected source junction; refusing to unlink'}
        [IO.Directory]::Delete($link.FullName)
    }
    $summary=@{run_id=$stage.record.id;workflow=$stage.record.workflow;engine_version=$stage.record.engine_version;
        repo_root=$stage.record.repo_root;payload_path=$stage.record.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');
        overall_status=$(if($analysisExit -eq 0){'warning'}else{'error'});result='Native diagnostics retained; production remains gated by visual and geometry review'}
    $completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $stage.record.id -ExitCode $analysisExit -Summary $summary
    $closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $stage.record.id -Action close
    $closed | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $retained 'managed-run.json') -Encoding UTF8
}
Write-Output "Native fixture analysis exit=$analysisExit; retained evidence: $retained"
if($analysisExit -ne 0){throw 'Native fixture gates failed; inspect the retained summary, not only the engine exit code'}
