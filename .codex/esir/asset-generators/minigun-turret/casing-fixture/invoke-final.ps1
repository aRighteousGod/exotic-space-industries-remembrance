param([ValidateSet('standalone','esir-sd','esir-hd')][string]$Case='standalone',
    [ValidateSet('off','on')][string]$Ballistic='off',[string]$Attempt='001',
    [string]$Dossier=(Join-Path (Get-Location).Path 'output/minigun-implementation/casing-ejection-001'),
    [string]$MainSource=(Join-Path (Get-Location).Path 'exotic-space-industries-remembrance'),
    [string]$DependencySeed=(Join-Path (Get-Location).Path '.factorio-qc/mg-casing-deps'))
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path;$dossier=$Dossier
$null=New-Item -ItemType Directory -Force -Path $dossier
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$scenario=$Case+'-'+$Ballistic+'-'+$Attempt
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-casings' -Scenario $scenario -EngineVersion '2.0.77' -Reproduction 'Replay casing-ejection-001/invoke-final.ps1 in a fresh attempt' -RetainedPaths @('output/minigun-implementation/casing-ejection-001/acceptance.json')
$run=Join-Path $repo $record.payload_path;$mods=Join-Path $run 'mods'
$helperName='zzz-minigun-casing-final';$helper=Join-Path $mods $helperName
$null=New-Item -ItemType Directory -Path $helper
$hd='minigun-turret-HD'
$standalone=$Case -eq 'standalone'
$dependencies=@('base >= 2.0.77')
if($standalone){
    $null=New-Item -ItemType Junction -Path (Join-Path $mods $hd) -Target (Join-Path $repo $hd)
    $dependencies+= $hd
    $list=@{mods=@(@{name='base';enabled=$true},@{name=$hd;enabled=$true})}
    foreach($name in @('space-age','quality','elevated-rails')){$list.mods+=@{name=$name;enabled=$false}}
}else{
    $seed=Join-Path $repo '.factorio-qc/fmqc/mods-live'
    $sources=@(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {$_.Name -like 'exotic-space-industries-remembrance*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'info.json'))})
    $excluded=@($sources.Name)+@($hd,'e-s-i-r-minigun-turret-graphics-hd','exotic-space-industries-remembrance-graphics-hd')
    foreach($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip'){
        if($archive.Name -like 'exotic-space-industries-remembrance-graphics-4_*.zip'){
            $null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName
            continue
        }
        $skip=$false;foreach($name in $excluded){if($archive.Name.StartsWith($name+'_')){$skip=$true;break}}
        if(-not $skip){$null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName}
    }
    foreach($n in 1..5){
        $pattern='exotic-space-industries-remembrance-graphics-'+$n+'_*.zip'
        if(-not (Get-ChildItem -LiteralPath $mods -Filter $pattern)){
            $archive=Get-ChildItem -LiteralPath $DependencySeed -Filter $pattern -File | Select-Object -First 1
            if(-not $archive){throw ('The complete baseline Graphics '+$n+' ZIP is required')}
            $null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName
        }
    }
    foreach($source in $sources){
        if($source.Name -match '^exotic-space-industries-remembrance-graphics-[1-5]$'){continue}
        $sourcePath=if($source.Name -eq 'exotic-space-industries-remembrance'){$MainSource}else{$source.FullName}
        $null=New-Item -ItemType Junction -Path (Join-Path $mods $source.Name) -Target $sourcePath
    }
    if($Case -eq 'esir-hd'){$null=New-Item -ItemType Junction -Path (Join-Path $mods $hd) -Target (Join-Path $repo $hd)}
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object {$_.name -notin @($hd,'e-s-i-r-minigun-turret-graphics-hd','exotic-space-industries-remembrance-graphics-hd') -and $_.name -ne $helperName})
    foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark|zzz-esir-minigun'){$mod.enabled=$false}}
    $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/info.json') -Raw | ConvertFrom-Json
    foreach($dep in $info.dependencies){if($dep -match '^!\s+(.+?)(?:\s+[<>=].*)?$'){foreach($mod in $list.mods){if($mod.name -eq $Matches[1]){$mod.enabled=$false}}}}
    $list.mods+=@{name=$hd;enabled=($Case -eq 'esir-hd')}
    if(-not ($list.mods | Where-Object name -eq 'exotic-space-industries-remembrance-graphics-6')){$list.mods+=@{name='exotic-space-industries-remembrance-graphics-6';enabled=$true}}
    $dependencies+='exotic-space-industries-remembrance >= 1.3.42'
    if($Case -eq 'esir-hd'){$dependencies+=$hd}
    ('data.raw["bool-setting"]["ei-ballistic-divergence"].default_value='+$(if($Ballistic -eq 'on'){'true'}else{'false'})) | Set-Content -LiteralPath (Join-Path $helper 'settings-updates.lua') -Encoding UTF8
}
@{name=$helperName;version='1.0.0';title='Minigun casing check';author='QC';factorio_version='2.0';dependencies=$dependencies} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'final-control.lua') -Destination (Join-Path $helper 'control.lua')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'final-data.lua') -Destination (Join-Path $helper 'data-final-fixes.lua')
('return {entity="'+$(if($standalone){'minigun-turret-hd'}else{'ei-gatling-turret'})+'",standalone='+$(if($standalone){'true'}else{'false'})+',case="'+$Case+'",ballistic="'+$Ballistic+'"}') | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding UTF8
$list.mods+=@{name=$helperName;enabled=$true}
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',('write-data='+$run.Replace('\','/')),'[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
@{case=$Case;ballistic=$Ballistic;run=$run;record=$record} | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $dossier ('final-'+$scenario+'-stage.json')) -Encoding UTF8
$idle=0;while($idle -lt 15){if(Get-Process factorio -ErrorAction SilentlyContinue){$idle=0}else{$idle++};Start-Sleep -Seconds 1}
$env:SteamAppId='427520';$env:SteamGameId='427520'
$engine='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$common=@('--config',('"'+(Join-Path $run 'config.ini')+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
$save=Join-Path $run 'fixture.zip'
foreach($mode in @('create','graphics')){
    $args=if($mode -eq 'create'){@('--create',('"'+$save+'"'),'--map-gen-seed','42')}else{@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','450','--benchmark-runs','1','--window-size','1280x960','--disable-migration-window')}
    $process=Start-Process -FilePath $engine -ArgumentList ($args+$common) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run ($mode+'.log')) -RedirectStandardError (Join-Path $run ($mode+'-error.log'))
    $null=$process.Handle
    while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
    $log=Get-Content -LiteralPath (Join-Path $run ($mode+'.log')) -Raw
    if($process.ExitCode -ne 0 -or $log -match 'Failed to load mods:|Factorio crashed|Error Util.cpp'){
        Get-Content -LiteralPath (Join-Path $run ($mode+'.log')) -Tail 24;throw ($mode+' failed: '+$process.ExitCode)
    }
}
Copy-Item -LiteralPath (Join-Path $run 'script-output/casing-final-report.json') -Destination (Join-Path $dossier ('final-'+$scenario+'-report.json'))
Write-Output ('CASING CHECK COMPLETE: '+$run)
