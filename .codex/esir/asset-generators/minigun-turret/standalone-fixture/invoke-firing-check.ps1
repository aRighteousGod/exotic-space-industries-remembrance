param([string]$Attempt='006',[switch]$Headless,
    [string]$Dossier=(Join-Path (Get-Location).Path 'output/minigun-implementation/standalone-rename-001'))
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
# Keep the shared engine idle for a short gap between another agent's runs.
$idleSeconds=0
while($idleSeconds -lt 15){
    if(Get-Process factorio -ErrorAction SilentlyContinue){$idleSeconds=0}else{$idleSeconds++}
    Start-Sleep -Seconds 1
}
$stage=Get-Content -LiteralPath (Join-Path $Dossier 'data-base-stage.json') -Raw | ConvertFrom-Json
$run=$stage.run;$mods=Join-Path $run 'mods';$helperName='zzz-minigun-standalone-check-'+$Attempt;$helper=Join-Path $mods $helperName
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Please close Factorio before the graphics check'}
if(Test-Path -LiteralPath $helper){throw 'Do not overwrite an attempted fixture'}
$null=New-Item -ItemType Directory -Path $helper
@{name=$helperName;version='1.0.0';title='Standalone minigun check';author='QC';factorio_version='2.0';dependencies=@('base >= 2.0.77','minigun-turret-HD >= 1.0.0')} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'control.lua'),(Join-Path $PSScriptRoot 'test-config.lua') -Destination $helper
if($Headless){$config=Get-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Raw; ('local config='+($config -replace '^return ','')+"`nconfig.disable_gui=true`nreturn config") | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding UTF8}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'firing-data.lua') -Destination (Join-Path $helper 'data.lua')
$list=Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
foreach($mod in $list.mods){if($mod.name -like 'zzz-minigun-standalone-check*'){$mod.enabled=$false}}
$list.mods+=@{name=$helperName;enabled=$true}
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$engine='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$env:SteamAppId='427520';$env:SteamGameId='427520'
$common=@('--config',('"'+(Join-Path $run 'config.ini')+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
$save=Join-Path $run ('fixture-'+$Attempt+'.zip')
foreach($mode in @('create','graphics')){
    $args=if($mode -eq 'create'){@('--create',('"'+$save+'"'),'--map-gen-seed','42')}elseif($Headless){@('--benchmark',('"'+$save+'"'),'--benchmark-ticks','520','--benchmark-runs','1')}else{@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','520','--benchmark-runs','1','--window-size','1280x960','--disable-migration-window')}
    $process=Start-Process -FilePath $engine -ArgumentList ($args+$common) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run ($mode+'-'+$Attempt+'.log')) -RedirectStandardError (Join-Path $run ($mode+'-'+$Attempt+'-error.log'))
    $null=$process.Handle
    while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
    if($process.ExitCode -ne 0){Get-Content -LiteralPath (Join-Path $run ($mode+'-'+$Attempt+'.log')) -Tail 35;throw ($mode+' failed: '+$process.ExitCode)}
}
Copy-Item -LiteralPath (Join-Path $run 'script-output/minigun-consumer-report.json') -Destination (Join-Path $Dossier 'firing-report.json')
Write-Output ('FIRING CHECK COMPLETE: '+$run)
