param([string]$Dossier=(Join-Path (Get-Location).Path 'output/minigun-implementation/indexed-native-next'))
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path; $dossier=[IO.Path]::GetFullPath($Dossier)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'output/minigun-implementation'))+[IO.Path]::DirectorySeparatorChar
if(-not $dossier.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Choose an ignored minigun output dossier.' }
if(Test-Path -LiteralPath (Join-Path $dossier 'stage.json')) { throw 'Choose a fresh dossier to preserve previous evidence.' }
$null=New-Item -ItemType Directory -Path $dossier -Force
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-indexed-hd' -Scenario 'default-fullcolor' -EngineVersion '2.0.77' -Reproduction 'Run indexed-fixture/invoke.ps1 with a fresh Dossier after promoting the indexed default profile' -RetainedPaths @((Get-EsirArtifactRelativePath $repo (Join-Path $dossier 'native/report.json')))
$run=Join-Path $repo $record.payload_path; $mods=Join-Path $run 'mods'; $helper=Join-Path $mods 'zzz-minigun-centering'
$null=New-Item -ItemType Directory -Path $helper
foreach($pack in @('minigun-turret-HD','exotic-space-industries-remembrance-graphics-6')) {
    $null=New-Item -ItemType Junction -Path (Join-Path $mods $pack) -Target (Join-Path $repo $pack)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'control.lua') -Destination $helper
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'data-final-fixes.lua') -Destination $helper
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'baseline-launch.lua') -Destination $helper
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'baseline-graphics-data.lua') -Destination $helper
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics.lua') -Destination (Join-Path $helper 'main-graphics.lua')
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua') -Destination (Join-Path $helper 'main-graphics-data.lua')
@{name='zzz-minigun-centering';version='1.0.0';title='Minigun indexed HD check';author='QC';factorio_version='2.0';dependencies=@('base >= 2.0.77','minigun-turret-HD','exotic-space-industries-remembrance-graphics-6 >= 1.0.1')} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
@{mods=@(@{name='base';enabled=$true},@{name='minigun-turret-HD';enabled=$true},@{name='exotic-space-industries-remembrance-graphics-6';enabled=$true},@{name='zzz-minigun-centering';enabled=$true},@{name='space-age';enabled=$false},@{name='quality';enabled=$false},@{name='elevated-rails';enabled=$false})} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',('write-data='+$run.Replace('\','/')),'[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
@{run=$run;record=$record} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dossier 'stage.json') -Encoding UTF8
$idle=0;while($idle -lt 15){if(Get-Process factorio -ErrorAction SilentlyContinue){$idle=0}else{$idle++};Start-Sleep -Seconds 1}
$env:SteamAppId='427520'; $env:SteamGameId='427520'
$engine='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
foreach($mode in @('create','graphics')) {
    $arguments=@('--config',(Join-Path $run 'config.ini'),'--mod-directory',$mods)
    if($mode -eq 'create') { $arguments+=@('--create',(Join-Path $run 'fixture.zip'),'--map-gen-seed','1729') }
    else { $arguments+=@('--benchmark-graphics',(Join-Path $run 'fixture.zip'),'--benchmark-ticks','240','--benchmark-runs','1','--window-size','1280x960','--disable-migration-window') }
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $run ($mode+'.log')) -RedirectStandardError (Join-Path $run ($mode+'-error.log'))
    $null=$process.Handle
    while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
    $log=Get-Content -LiteralPath (Join-Path $run ($mode+'.log')) -Raw
    if($process.ExitCode -ne 0 -or $log -match 'Failed to load mods:|Factorio crashed|Error Util.cpp') { Get-Content -LiteralPath (Join-Path $run ($mode+'.log')) -Tail 16; throw ($mode+' failed: '+$process.ExitCode) }
}
$retained=Join-Path $dossier 'native'; $null=New-Item -ItemType Directory -Path $retained -Force
Copy-Item -LiteralPath (Join-Path $run 'script-output/centering/report.json') -Destination $retained
Get-ChildItem -LiteralPath (Join-Path $run 'script-output/centering') -File -Filter '*.png' | ForEach-Object { $null=New-Item -ItemType HardLink -Path (Join-Path $retained $_.Name) -Target $_.FullName }
'INDEXED HD COMPLETE: '+$run
