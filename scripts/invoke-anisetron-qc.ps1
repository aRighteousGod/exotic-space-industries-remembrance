[CmdletBinding()]
param([switch]$DumpOnly,[switch]$FocusedDump,[switch]$Visual,[switch]$Save,[switch]$Resume,[switch]$InstalledMods,[string]$SaveInput,[string]$AssetRoot,[string]$RunName='native',
    [ValidateSet('off','lean','standard','cinematic','maximal','unbounded')][string]$Fidelity='standard',
    [ValidateSet('all','crown','facade')][string]$Isolate='all',
    [switch]$Legacy,[switch]$HistoricalLegacy,[switch]$FullDirections,[switch]$Timing,[switch]$Regression,[switch]$TenLegTrial,
    [string]$RepoRoot='',[string]$FixtureSource='',[string]$FixtureOptions='',[string]$SourceRoot='',
    [ValidateRange(0,1000000)][int]$RuntimeTicks=0)
$ErrorActionPreference='Stop'
if(($Resume -and ($Save -or $Visual)) -or ($Save -and $Visual)){throw 'Choose one runtime, visual, save or resume mode.'}
if($Timing -and ($Resume -or $Save -or $Visual -or $Legacy -or $HistoricalLegacy)){throw 'Timing is a separate native runtime profile.'}
if($Regression -and ($Resume -or $Save -or $Timing -or $Legacy -or $HistoricalLegacy -or $FullDirections)){throw 'Regression is a separate profile; Visual optionally enables dense captures.'}
if($Isolate -ne 'all' -and -not $Visual){throw 'Emitter isolation requires the visual profile.'}
if(-not $RepoRoot){
    $candidateRepo=Split-Path -Parent $PSScriptRoot
    $RepoRoot=if(Test-Path -LiteralPath (Join-Path $candidateRepo 'exotic-space-industries-remembrance')){$candidateRepo}else{Join-Path $PSScriptRoot '..\..\..'}
}
$repo=(Resolve-Path -LiteralPath $RepoRoot).Path
if(-not $FixtureSource){
    $FixtureSource=if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'fixture')){Join-Path $PSScriptRoot 'fixture'}else{Join-Path $repo 'scripts\qc\anisetron'}
}
$fixtureSource=(Resolve-Path -LiteralPath $FixtureSource).Path
if($HistoricalLegacy -and -not $Resume){throw 'HistoricalLegacy requires Resume with the retained v1 transition save.'}
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$artifactRun=Join-Path $repo ".factorio-qc\anisetron\$RunName"
# Factorio's graphics loader rejects some >260-character paths. Keep visual
# dependency paths short, then retain reports/screenshots in repo staging.
$run=if($Visual){Join-Path ([IO.Path]::GetTempPath()) "esir-anisetron-$RunName"}else{$artifactRun}
$mods=Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
if($InstalledMods){$seed=Join-Path $env:APPDATA 'Factorio\mods'}
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    $destination=Join-Path $mods $archive.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null}
}
foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
    $destination=Join-Path $mods $directory.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null}
}
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
# Differential runtime fixtures may freeze code separately; assets still come
# from the reviewed repository/cache (or the explicit AssetRoot override).
$source=if($SourceRoot){(Resolve-Path -LiteralPath $SourceRoot).Path}else{Join-Path $repo 'exotic-space-industries-remembrance'}
Get-ChildItem -LiteralPath $source |
    Where-Object { $_.Name -notin @('graphics','sounds') } | Copy-Item -Destination $pack -Recurse -Force
# Immutable assets are content-addressed in a QC-only cache. Hardlinks retain
# each run's exact bytes without repeatedly copying gigabytes or linking back
# into writable shipping assets. AssetRoot overrides still get private copies.
$assetCache=Join-Path $repo '.factorio-qc\anisetron\asset-cache'
foreach($assetDirectory in @('graphics','sounds')){
    $sourceRoot=Join-Path $repo "exotic-space-industries-remembrance\$assetDirectory"
    if(-not(Test-Path -LiteralPath $sourceRoot)){continue}
    foreach($asset in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File){
        $relative=$asset.FullName.Substring($sourceRoot.Length+1)
        $destination=Join-Path (Join-Path $pack $assetDirectory) $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        if(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination -Force}
        if($AssetRoot){Copy-Item -LiteralPath $asset.FullName -Destination $destination;continue}
        $hash=(Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $cached=Join-Path $assetCache $hash
        if(-not(Test-Path -LiteralPath $cached)){
            New-Item -ItemType Directory -Path $assetCache -Force | Out-Null
            Copy-Item -LiteralPath $asset.FullName -Destination $cached
        }
        New-Item -ItemType HardLink -Path $destination -Target $cached | Out-Null
    }
}
if($AssetRoot){
    Copy-Item -LiteralPath (Join-Path $AssetRoot 'graphics') -Destination $pack -Recurse -Force
    $assetLookup=Join-Path $AssetRoot 'anisetron-graphics.lua'
    if(Test-Path -LiteralPath $assetLookup){Copy-Item -LiteralPath $assetLookup -Destination (Join-Path $pack 'lib\anisetron-graphics.lua') -Force}
}
$helper=Join-Path $mods 'zzz-esir-anisetron-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath $fixtureSource -File | Copy-Item -Destination $helper -Force
if($FixtureOptions){Copy-Item -LiteralPath $FixtureOptions -Destination (Join-Path $helper 'options.lua') -Force}
if(Test-Path -LiteralPath (Join-Path $fixtureSource 'observer-test.lua')){
    Copy-Item -LiteralPath (Join-Path $repo 'scripts/qc/anisetron-live-observer/control.lua') -Destination (Join-Path $helper 'live-observer.lua') -Force
}
if($TenLegTrial){
    Copy-Item -LiteralPath (Join-Path $repo 'scripts\qc\anisetron-glide\ten-leg-trial.lua') -Destination $helper -Force
    [IO.File]::AppendAllText((Join-Path $helper 'data-final-fixes.lua'), "`nrequire('ten-leg-trial').apply()`n", [Text.UTF8Encoding]::new($false))
}
# Same staged-only bridge pattern as the Singularity Lance runner.
$bridge=Get-Content -LiteralPath (Join-Path $fixtureSource 'bridge.lua') -Raw
[IO.File]::AppendAllText((Join-Path $pack 'control.lua'), "`n$bridge", [Text.UTF8Encoding]::new($false))
if($Resume -and -not $SaveInput){throw 'Resume requires a transition save.'}
$loaded=$Resume.IsPresent.ToString().ToLowerInvariant()
"return {visual=$($Visual.IsPresent.ToString().ToLowerInvariant()),regression=$($Regression.IsPresent.ToString().ToLowerInvariant()),save=$($Save.IsPresent.ToString().ToLowerInvariant()),loaded=$loaded,ten_leg_trial=$($TenLegTrial.IsPresent.ToString().ToLowerInvariant()),fidelity='$Fidelity',isolate='$Isolate',legacy=$($Legacy.IsPresent.ToString().ToLowerInvariant()),historical_legacy=$($HistoricalLegacy.IsPresent.ToString().ToLowerInvariant()),full_directions=$($FullDirections.IsPresent.ToString().ToLowerInvariant()),timing=$($Timing.IsPresent.ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-anisetron-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-anisetron-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
if($Visual){
    # Bound transient PNG decoding/screenshot memory on large dependency sets.
    # These worker counts preserve graphics quality and simulation behavior.
    Add-Content -LiteralPath $config -Value @('[graphics]','max-sprite-loading-threads=2','screenshots-threads-count=2') -Encoding UTF8
}
if($DumpOnly){
    if($FocusedDump){
        Copy-Item -LiteralPath (Join-Path $repo 'scripts/qc/anisetron/focused-dump.lua') -Destination $helper -Force
        [IO.File]::AppendAllText((Join-Path $helper 'data-final-fixes.lua'), "`nrequire('focused-dump')`n", [Text.UTF8Encoding]::new($false))
        & $factorio --create (Join-Path $run 'data-validation.zip') --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'dump.txt') -Encoding utf8
        if($LASTEXITCODE -ne 0){throw "Focused data load failed: $run\dump.txt"}
        $line=Get-Content -LiteralPath (Join-Path $run 'dump.txt') | Where-Object {$_ -match 'ANISETRON_FOCUSED_FINAL_DATA '}
        if(@($line).Count -ne 1){throw 'Missing unique final data snapshot'}
        $marker='ANISETRON_FOCUSED_FINAL_DATA '
        $json=$line.Substring($line.IndexOf($marker)+$marker.Length)
        New-Item -ItemType Directory -Path (Join-Path $run 'script-output') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $run 'script-output/focused-data-raw.json'),$json,[Text.UTF8Encoding]::new($false))
        Write-Output "Focused final data: $run\script-output\focused-data-raw.json";exit
    }
    & $factorio --dump-data --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'dump.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Data load failed: $run\dump.txt"}
    Write-Output "Data dump: $run\script-output\data-raw-dump.json";exit
}
$fixture=Join-Path $run 'fixture.zip'
if(-not $SaveInput -and -not $Save){$SaveInput=Join-Path $env:APPDATA 'Factorio\saves\explode.zip'}
if($SaveInput){Copy-Item -LiteralPath $SaveInput -Destination $fixture -Force}
else{
    & $factorio --create $fixture --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Fixture creation failed: $run\create.txt"}
}
$started=Get-Date
if($Save){
    New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
    $settings=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
    $settings.name='ESIR ANISETRON native fixture';$settings.auto_pause=$false
    $settings.visibility.public=$false;$settings.visibility.lan=$false;$settings.require_user_verification=$false
    $server=Join-Path $run 'server-settings.json'
    $settings | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $server -Encoding UTF8
    $saved=Join-Path $run 'saves\anisetron-transition.zip'
    $args=@('--start-server',('"'+$fixture+'"'),'--server-settings',('"'+$server+'"'),'--port','34237','--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
    $process=Start-Process -FilePath $factorio -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'server.txt') -RedirectStandardError (Join-Path $run 'server-error.txt')
    try{
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $deadline=(Get-Date).AddMinutes(5);$ready=$false
        while(-not $process.HasExited -and (Get-Date) -lt $deadline){
            if((Test-Path -LiteralPath $saved) -and (Get-Item -LiteralPath $saved).LastWriteTime -gt $started){
                try{$zip=[IO.Compression.ZipFile]::OpenRead($saved);$zip.Dispose();$ready=$true;break}catch{}
            }
            Start-Sleep -Milliseconds 500;$process.Refresh()
        }
        if(-not $ready){throw "Save fixture failed: $run\server.txt"}
        Write-Output "Saved fixture: $saved"
    }finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}elseif($Visual){
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    $graphicsTicks=if($RuntimeTicks -gt 0){$RuntimeTicks}elseif($Regression){3700}elseif($FullDirections){900}else{800}
    $args=@('--benchmark-graphics',('"'+$fixture+'"'),'--benchmark-ticks',"$graphicsTicks",'--benchmark-runs','1','--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio','--window-size','1280x720','--disable-migration-window')
    $process=Start-Process -FilePath $factorio -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'visual.txt') -RedirectStandardError (Join-Path $run 'visual-error.txt')
    $null=$process.Handle
    try{if(-not $process.WaitForExit(300000)){throw 'Graphics fixture timed out.'};$process.Refresh();if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw "Graphics failed: $run\visual.txt"}}finally{if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}else{
    $ticks=if($Regression -or $Timing){3700}elseif($Resume){1300}else{2500}
    if($RuntimeTicks -gt 0){$ticks=$RuntimeTicks}
    & $factorio --benchmark $fixture --benchmark-ticks $ticks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio --disable-migration-window 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Runtime fixture failed: $run\benchmark.txt"}
}
$report=Join-Path $run 'script-output\anisetron-qc.json'
if(-not(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started){throw "Missing fresh report: $report"}
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$failedCases=@($result.cases.PSObject.Properties | Where-Object { -not $_.Value.pass } | ForEach-Object Name)
[pscustomobject]@{all_pass=$result.all_pass;count=$result.count;complete=$result.complete;profile=$result.profile;
    fixture_version=$result.fixture_version;fidelity=$result.fidelity;channel_view=$result.channel_view;failed_cases=$failedCases;report=$report} | ConvertTo-Json -Depth 4
if(-not $result.all_pass){throw "Acceptance failed: $report"}
if(-not $result.complete){throw "Incomplete fixture report: $report"}
if($Visual -and $result.profile -eq 'stability-art'){
    $manifest=Get-Content -LiteralPath (Join-Path $run 'script-output\anisetron-stability\captures.json') -Raw | ConvertFrom-Json
    if($manifest.frames.Count -ne $result.count){throw 'Stability capture count differs from its manifest'}
    Add-Type -AssemblyName System.Drawing
    foreach($frame in $manifest.frames){
        $shot=Join-Path (Join-Path $run 'script-output') $frame.path
        if(-not(Test-Path -LiteralPath $shot)){throw "Missing capture: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Get-ChildItem -LiteralPath $run -File | Copy-Item -Destination $artifactRun -Force
    Write-Output "Stability art: $artifactRun\script-output\anisetron-stability";exit
}
if($Visual -and $result.profile -eq 'inheritance-art'){
    $manifest=Get-Content -LiteralPath (Join-Path $run 'script-output\inheritance-art\captures.json') -Raw | ConvertFrom-Json
    if($manifest.frames.Count -notin @(156,160)){throw 'Expected 39 frames per day/night fire/movement clip, plus optional split-emitter views'}
    Add-Type -AssemblyName System.Drawing
    foreach($frame in $manifest.frames){
        $shot=Join-Path (Join-Path $run 'script-output') $frame.path
        if(-not(Test-Path -LiteralPath $shot)){throw "Missing capture: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Get-ChildItem -LiteralPath $run -File | Copy-Item -Destination $artifactRun -Force
    Write-Output "Inheritance art: $artifactRun\script-output\inheritance-art";exit
}
if($Visual -and $result.profile -eq 'hover-combat'){
    $manifest=Get-Content -LiteralPath (Join-Path $run 'script-output\anisetron-art\hover-captures.json') -Raw | ConvertFrom-Json
    if($manifest.Count -ne 12){throw 'Expected six day/night chromatic pairs.'}
    Add-Type -AssemblyName System.Drawing
    foreach($capture in $manifest){
        $shot=Join-Path (Join-Path $run 'script-output') $capture.path
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh screenshot: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Get-ChildItem -LiteralPath $run -File | Copy-Item -Destination $artifactRun -Force
    Write-Output "Chromatic captures: $artifactRun\script-output\anisetron-art"
    exit
}
if($Visual -and $result.profile -eq 'native-glide'){
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Get-ChildItem -LiteralPath $run -File | Copy-Item -Destination $artifactRun -Force
    Write-Output "Glide captures: $artifactRun\script-output\anisetron-glide"
    exit
}
if($Visual -and $Regression){
    $dense=Join-Path $run 'script-output\anisetron-regression\captures.json'
    if(-not(Test-Path -LiteralPath $dense)){throw "Missing dense regression captures: $dense"}
    $denseReport=Get-Content -LiteralPath $dense -Raw | ConvertFrom-Json
    Add-Type -AssemblyName System.Drawing
    foreach($capture in $denseReport.frames){
        $shot=Join-Path (Join-Path $run 'script-output') $capture.path
        if(-not(Test-Path -LiteralPath $shot)){throw "Missing regression frame: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Write-Output "Regression captures: $artifactRun\script-output\anisetron-regression"
    exit
}
if($Visual){
    Add-Type -AssemblyName System.Drawing
    foreach($heading in 0..7){foreach($light in @('day','night')){
        $shot=Join-Path $run "script-output\anisetron-art\pose-$heading-$light.png"
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh screenshot: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }}
    foreach($frame in 1..24){
        $shot=Join-Path $run ('script-output\anisetron-art\strafe\{0:D3}.png' -f $frame)
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh sweep frame: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    foreach($motion in @('turn','counterclockwise','north-wrap')){foreach($frame in 1..12){
        $shot=Join-Path $run ('script-output\anisetron-art\{0}\{1:D3}.png' -f $motion,$frame)
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh turn frame: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }}
    foreach($pose in @('frozen','static-65','static-75','static-85')){
        $shot=Join-Path $run "script-output\anisetron-art\turn\$pose.png"
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh frozen frame: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    foreach($pose in @('movement-day','movement-night','movement-stopped','movement-front-day','movement-front-night','movement-front-stopped','movement-probe-east','movement-probe-front')){
        $shot=Join-Path $run "script-output\anisetron-art\$pose.png"
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh movement screenshot: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }
    foreach($clip in @('ring-day','ring-night','motion-day','motion-night')){foreach($frame in 1..24){
        $shot=Join-Path $run ('script-output\anisetron-art\{0}\{1:D3}.png' -f $clip,$frame)
        if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh v2 visual clip frame: $shot"}
        $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
    }}
    $captureManifest=Join-Path $run 'script-output\anisetron-art\capture-manifest.json'
    if(-not(Test-Path -LiteralPath $captureManifest) -or (Get-Item -LiteralPath $captureManifest).LastWriteTime -lt $started){throw "Missing fresh capture manifest: $captureManifest"}
    $captures=Get-Content -LiteralPath $captureManifest -Raw | ConvertFrom-Json
    if($captures.channel_view -ne $Isolate){throw "Capture isolation mismatch: $captureManifest"}
    if($FullDirections){
        foreach($heading in 0..127){foreach($light in @('day','night')){
            $shot=Join-Path $run ('script-output\anisetron-art\directions128\{0:D3}-{1}.png' -f $heading,$light)
            if(-not(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh 128-direction screenshot: $shot"}
            $decoded=[Drawing.Image]::FromFile($shot);$decoded.Dispose()
        }}
    }
    New-Item -ItemType Directory -Path $artifactRun -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $run 'script-output') -Destination $artifactRun -Recurse -Force
    Get-ChildItem -LiteralPath $run -File | Copy-Item -Destination $artifactRun -Force
    Write-Output "Visual artifacts: $artifactRun"
}
