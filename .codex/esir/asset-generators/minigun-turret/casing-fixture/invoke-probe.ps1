param([string]$Attempt='001',
    [string]$Dossier=(Join-Path (Get-Location).Path 'output/minigun-implementation/casing-ejection-001'))
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$dossier=$Dossier
$null=New-Item -ItemType Directory -Force -Path $dossier
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-casings' -Scenario ('basis-'+$Attempt) -EngineVersion '2.0.77' -Reproduction 'Replay casing-ejection-001/invoke-probe.ps1 with a new attempt' -RetainedPaths @('output/minigun-implementation/casing-ejection-001/probe-report.json')
$run=Join-Path $repo $record.payload_path
$mods=Join-Path $run 'mods'
$null=New-Item -ItemType Directory -Path $mods
$g6='exotic-space-industries-remembrance-graphics-6'
$null=New-Item -ItemType Junction -Path (Join-Path $mods $g6) -Target (Join-Path $repo $g6)
$helperName='zzz-minigun-casing-probe';$helper=Join-Path $mods $helperName
$null=New-Item -ItemType Directory -Path $helper
@{name=$helperName;version='1.0.0';title='Casing origin probe';author='QC';factorio_version='2.0';dependencies=@('base >= 2.0.77',$g6)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe-control.lua') -Destination (Join-Path $helper 'control.lua')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe-data.lua') -Destination (Join-Path $helper 'data.lua')
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics.lua') -Destination (Join-Path $helper 'graphics.lua')
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua') -Destination (Join-Path $helper 'metadata.lua')
@{mods=@(@{name='base';enabled=$true},@{name=$g6;enabled=$true},@{name=$helperName;enabled=$true},@{name='space-age';enabled=$false},@{name='quality';enabled=$false},@{name='elevated-rails';enabled=$false})} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',('write-data='+$run.Replace('\','/')),'[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
@{run=$run;record=$record} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dossier ('probe-'+$Attempt+'-stage.json')) -Encoding UTF8
$idle=0
while($idle -lt 15){if(Get-Process factorio -ErrorAction SilentlyContinue){$idle=0}else{$idle++};Start-Sleep -Seconds 1}
$env:SteamAppId='427520';$env:SteamGameId='427520'
$engine='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$common=@('--config',('"'+(Join-Path $run 'config.ini')+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
$save=Join-Path $run 'fixture.zip'
foreach($mode in @('create','graphics')){
    $args=if($mode -eq 'create'){@('--create',('"'+$save+'"'),'--map-gen-seed','42')}else{@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','110','--benchmark-runs','1','--window-size','1280x960','--disable-migration-window')}
    $process=Start-Process -FilePath $engine -ArgumentList ($args+$common) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run ($mode+'.log')) -RedirectStandardError (Join-Path $run ($mode+'-error.log'))
    $null=$process.Handle
    while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
    if($process.ExitCode -ne 0){Get-Content -LiteralPath (Join-Path $run ($mode+'.log')) -Tail 28;throw ($mode+' failed: '+$process.ExitCode)}
}
Copy-Item -LiteralPath (Join-Path $run 'script-output/casing-probe-report.json') -Destination (Join-Path $dossier 'probe-report.json')
Write-Output ('PROBE COMPLETE: '+$run)
