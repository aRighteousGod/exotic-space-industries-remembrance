param([ValidateSet('base','space-age','esir')][string]$Case='base',
    [string]$Dossier=(Join-Path (Get-Location).Path 'output/minigun-implementation/standalone-rename-001'))
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$null=New-Item -ItemType Directory -Force -Path $Dossier
$run=Join-Path $Dossier ('data-'+$Case)
if(Test-Path -LiteralPath $run){throw 'Use a fresh run directory'}
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-standalone' -Scenario $Case -EngineVersion '2.0.77' -Classification 'qc-payload' -Reproduction 'Replay standalone-rename-001/invoke-narrow-check.ps1 in a fresh output dossier' -RetainedPaths @('output/minigun-implementation/standalone-rename-001/validation.json')
$run=Join-Path $repo $record.payload_path
$mods=Join-Path $run 'mods'
$null=New-Item -ItemType Directory -Path $mods
$hd='minigun-turret-HD'
$null=New-Item -ItemType Junction -Path (Join-Path $mods $hd) -Target (Join-Path $repo $hd)
$list=@{mods=@(@{name='base';enabled=$true},@{name=$hd;enabled=$true})}
if($Case -eq 'base'){
    foreach($name in @('space-age','quality','elevated-rails')){$list.mods+=@{name=$name;enabled=$false}}
}
if($Case -eq 'space-age'){
    foreach($name in @('space-age','quality','elevated-rails')){$list.mods+=@{name=$name;enabled=$true}}
}
if($Case -eq 'esir'){
    $seed=Join-Path $repo '.factorio-qc/fmqc/mods-live'
    $sources=@(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {$_.Name -like 'exotic-space-industries-remembrance*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'info.json'))})
    $excluded=@($sources.Name)+@($hd,'e-s-i-r-minigun-turret-graphics-hd','exotic-space-industries-remembrance-graphics-hd')
    foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip' -File){
        $skip=$false
        foreach($name in $excluded){if($archive.Name.StartsWith($name+'_')){$skip=$true;break}}
        if(-not $skip){$null=New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName}
    }
    foreach($source in $sources){$null=New-Item -ItemType Junction -Path (Join-Path $mods $source.Name) -Target $source.FullName}
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object {$_.name -notin @($hd,'e-s-i-r-minigun-turret-graphics-hd','exotic-space-industries-remembrance-graphics-hd')})
    foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark|zzz-esir-minigun'){$mod.enabled=$false}}
    $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/info.json') -Raw | ConvertFrom-Json
    foreach($dep in $info.dependencies){if($dep -match '^!\s+(.+?)(?:\s+[<>=].*)?$'){foreach($mod in $list.mods){if($mod.name -eq $Matches[1]){$mod.enabled=$false}}}}
    $list.mods+=@{name=$hd;enabled=$true}
    if(-not ($list.mods | Where-Object name -eq 'exotic-space-industries-remembrance-graphics-6')){$list.mods+=@{name='exotic-space-industries-remembrance-graphics-6';enabled=$true}}
}
$list | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',('write-data='+$run.Replace('\','/')),'[other]','check-updates=false','[graphics]','full-screen=false','cache-sprite-atlas=false','[sound]','master-volume=0') | Set-Content -LiteralPath (Join-Path $run 'config.ini') -Encoding UTF8
$stage=@{case=$Case;run=$run;record=$record}
$stage | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $Dossier ('data-'+$Case+'-stage.json')) -Encoding UTF8
$env:SteamAppId='427520';$env:SteamGameId='427520'
$engine='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$process=Start-Process -FilePath $engine -ArgumentList @('--config',('"'+(Join-Path $run 'config.ini')+'"'),'--mod-directory',('"'+$mods+'"'),'--dump-data','--disable-audio') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'load.log') -RedirectStandardError (Join-Path $run 'load-error.log')
$null=$process.Handle
while(-not $process.HasExited){Start-Sleep -Seconds 1;$process.Refresh()}
Write-Output ('CASE='+$Case+' EXIT='+$process.ExitCode+' RUN='+$run)
if($process.ExitCode -ne 0){Get-Content -LiteralPath (Join-Path $run 'load.log') -Tail 35;exit 1}
