param([ValidateSet('on','off')][string]$Mode='on',[switch]$Advanced,[switch]$Glow)
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$base=Join-Path $repo 'output\meshy\minigun-prototypes\prototype-2\handoff-256'
$implementation=$PSScriptRoot
$sdName='exotic-space-industries-remembrance-graphics-6'
$hdName='minigun-turret-HD'
$legacyHdName='exotic-space-industries-remembrance-graphics-hd'
$engine='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
. (Join-Path $repo 'scripts\esir-housekeeping.ps1')
# Both source roots are explicit; a stale seed must not choose another pack.
foreach($requiredPack in @($sdName,$hdName)) {
    $packInfoPath=Join-Path $repo ($requiredPack+'\info.json')
    if(-not (Test-Path -LiteralPath $packInfoPath -PathType Leaf)){throw "Missing graphics source pack: $requiredPack"}
    $packInfo=Get-Content -LiteralPath $packInfoPath -Raw | ConvertFrom-Json
    if($packInfo.name -ne $requiredPack){throw "Graphics source folder/name mismatch: $requiredPack"}
}
$scenario=$Mode+$(if($Glow){'-glow-hidden'}elseif($Advanced){'-advanced'}else{''})
$switchArgs=$(if($Advanced){' -Advanced'}else{''})+$(if($Glow){' -Glow'}else{''})
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-native-timing' -Scenario $scenario -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction "powershell -File .codex/esir/asset-generators/minigun-turret/invoke-timing.ps1 -Mode $Mode$switchArgs" -RetainedPaths @("output/meshy/minigun-prototypes/prototype-2/handoff-256/timing-probe/$scenario/native-report.json")
$run=Join-Path $repo $record.payload_path
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $base "timing-$scenario-run.json") -Encoding UTF8
$mods=Join-Path $run 'mods'
$null=New-Item -ItemType Directory -Path $mods
foreach($archive in (Get-ChildItem -LiteralPath $seed -File -Filter '*.zip' | Where-Object {$_.Name -notlike ($legacyHdName+'_*.zip') -and $_.Name -notlike ($hdName+'_*.zip') -and $_.Name -notlike ($sdName+'_*.zip')})) { New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null }
foreach($directory in (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {($_.Name -like 'exotic-space-industries-remembrance*' -and $_.Name -ne $legacyHdName) -or $_.Name -eq $hdName})) {
    if(Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json')) { New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null }
}
$helper=Join-Path $mods 'zzz-esir-minigun-timing'
New-Item -ItemType Directory -Path $helper | Out-Null
Get-ChildItem -LiteralPath (Join-Path $implementation 'timing-fixture') -File | Copy-Item -Destination $helper
"return {ballistic=$($Mode -eq 'on' | ForEach-Object {$_.ToString().ToLowerInvariant()}),advanced=$($Advanced.IsPresent.ToString().ToLowerInvariant()),glow=$($Glow.IsPresent.ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
& python (Join-Path $implementation 'build_timing_atlas.py') (Join-Path $helper 'graphics')
if($LASTEXITCODE -ne 0){throw 'Diagnostic atlas generation failed'}
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object {$_.name -notmatch 'qc|benchmark|zzz-esir-minigun-timing'})
$list.mods=@($list.mods | Where-Object {$_.name -notin @($legacyHdName,$hdName,$sdName)})
$info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance\info.json') -Raw | ConvertFrom-Json
foreach($dependency in $info.dependencies) {if($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$'){foreach($mod in $list.mods){if($mod.name -eq $Matches[1]){$mod.enabled=$false}}}}
$list.mods+=@{name=$sdName;enabled=$true}
$list.mods+=@{name=$hdName;enabled=$false}
$list.mods+=@{name='zzz-esir-minigun-timing';enabled=$true}
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath $config -Encoding UTF8
$alias=Join-Path $env:TEMP ("esir-mg-timing-"+$record.id.Substring(0,8))
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
$env:SteamAppId='427520';$env:SteamGameId='427520'
$save=Join-Path $run 'fixture.zip'
$createArgs=@('--create',('"'+$save+'"'),'--map-gen-seed','42','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio')
$process=Start-Process -FilePath $engine -ArgumentList $createArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'create.log') -RedirectStandardError (Join-Path $run 'create-error.log')
$null=$process.Handle
while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
if($process.ExitCode -ne 0){Get-Content -LiteralPath (Join-Path $run 'create.log') -Tail 25;throw 'Timing fixture creation failed'}
$arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','1530','--benchmark-runs','1','--window-size','1024x768','--config',('"'+$config+'"'),'--mod-directory',('"'+$alias+'"'),'--disable-audio','--disable-migration-window')
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'graphics.log') -RedirectStandardError (Join-Path $run 'graphics-error.log')
$null=$process.Handle
while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
if($process.ExitCode -ne 0){Get-Content -LiteralPath (Join-Path $run 'graphics.log') -Tail 25;throw 'Timing graphics fixture failed'}
& python (Join-Path $implementation 'analyze_timing.py') --runs $run
if($LASTEXITCODE -ne 0){throw 'Timing decoding failed; managed payload remains protected'}
$summary=@{run_id=$record.id;workflow=$record.workflow;engine_version=$record.engine_version;repo_root=$repo;
    payload_path=$record.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='warning';
    result='Native fixture executed and decoded; inspect candidate parity in retained report'}
foreach($link in Get-ChildItem -LiteralPath $mods -Directory | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}) {
    $expected=[IO.Path]::GetFullPath((Join-Path $repo $link.Name))
    $actual=[IO.Path]::GetFullPath(@($link.Target)[0])
    if($actual -ne $expected -or -not (Test-Path -LiteralPath (Join-Path $expected 'info.json'))){throw 'Unexpected staging junction; refusing to unlink'}
    # Nonrecursive Directory.Delete removes only the task-created junction.
    [IO.Directory]::Delete($link.FullName)
}
if([IO.Path]::GetFullPath(@((Get-Item -LiteralPath $alias).Target)[0]) -ne [IO.Path]::GetFullPath($mods)){throw 'Unexpected temporary alias target'}
[IO.Directory]::Delete($alias)
$completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $record.id -ExitCode 0 -Summary $summary
if($completed.status -ne 'success'){throw "Timing retention failed: $($completed.housekeeping_error)"}
$closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $record.id -Action close
$closed | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $base "timing-$scenario-run.json") -Encoding UTF8
Write-Output "Timing run $Mode completed: $run"
