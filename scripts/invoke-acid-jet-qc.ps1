[CmdletBinding()]
param([ValidateSet('original','2x','4x','8x','16x')][string[]]$Profiles=@('original','2x','4x','8x','16x'),
    [switch]$Visual,[switch]$ReuseFixture,[switch]$TestNativeRefresh,
    [switch]$ProbeOnly,[switch]$TestAnimationLifetime,
    [switch]$DispersionProbe,[switch]$OriginProbe,[switch]$OriginVariants,
    [ValidateSet('half','short')][string]$OriginVariantSet='half',
    [string]$ArtifactRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02',
    [string]$SeedMods,
    [ValidateSet('high','medium')][string]$GraphicsQuality='medium')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$seed=if($SeedMods){$SeedMods}else{Join-Path $repo '.factorio-qc/wtr/ports-3x3/mods'}
$mods=Join-Path $ArtifactRoot 'qc/mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
# Junctions can cross volumes; hardlinks from the C: dependency seed cannot.
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    $destination=Join-Path $mods $archive.Name
    if(-not(Test-Path -LiteralPath $destination)){
        if([IO.Path]::GetPathRoot($destination) -eq [IO.Path]::GetPathRoot($archive.FullName)){
            New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null
        }else{Copy-Item -LiteralPath $archive.FullName -Destination $destination}
    }
}
foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance*'){
    if(-not(Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json'))){continue}
    $destination=Join-Path $mods $directory.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null}
}
$helper=Join-Path $mods 'zzz-esir-acid-jet-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/acid-jet') -File | Copy-Item -Destination $helper -Force
$baseline=Join-Path $ArtifactRoot 'baseline'
if(Test-Path -LiteralPath $baseline){
    Copy-Item -LiteralPath $baseline -Destination $helper -Recurse -Force
}
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-acid-jet-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-acid-jet-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$short=Join-Path ([IO.Path]::GetPathRoot($ArtifactRoot)) ('esir-acid-jet-'+(Split-Path -Leaf $ArtifactRoot)+'-mods')
if(Test-Path -LiteralPath $short){
    $link=Get-Item -LiteralPath $short
    if($link.LinkType -ne 'Junction' -or [string]$link.Target -ne $mods){throw "Unexpected QC alias $short"}
}else{New-Item -ItemType Junction -Path $short -Target $mods | Out-Null}
$factorio='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$env:SteamAppId='427520';$env:SteamGameId='427520'
$env:TEMP=Join-Path $ArtifactRoot 'cache';$env:TMP=$env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
foreach($profile in $Profiles){
    $run=Join-Path $ArtifactRoot ("qc/"+$profile+$(if($Visual){'-visual'}else{''})+$(if($TestNativeRefresh){'-refresh-candidate'}else{''})+$(if($TestAnimationLifetime){'-lifetime-candidate'}else{''})+$(if($ProbeOnly){'-probes'}else{''})+$(if($DispersionProbe){'-dispersion-probe'}else{''}))
    New-Item -ItemType Directory -Path $run -Force | Out-Null
    $config=Join-Path $run 'config.ini'
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
    "return {profile='$profile',visual=$($Visual.IsPresent.ToString().ToLowerInvariant()),native_refresh_candidate=$($TestNativeRefresh.IsPresent.ToString().ToLowerInvariant()),probe_only=$($ProbeOnly.IsPresent.ToString().ToLowerInvariant()),animation_lifetime_candidate=$($TestAnimationLifetime.IsPresent.ToString().ToLowerInvariant()),dispersion_probe=$($DispersionProbe.IsPresent.ToString().ToLowerInvariant()),origin_probe=$($OriginProbe.IsPresent.ToString().ToLowerInvariant()),origin_variants=$($OriginVariants.IsPresent.ToString().ToLowerInvariant()),origin_variant_set='$OriginVariantSet',pressure_baseline=$((Test-Path -LiteralPath $baseline).ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    $fixture=Join-Path $run 'fixture.zip'
    if(-not($ReuseFixture -and (Test-Path -LiteralPath $fixture))){
        $arguments=@('--create',('"'+$fixture+'"'),'--config',('"'+$config+'"'),'--mod-directory',('"'+$short+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/create.log" -RedirectStandardError "$run/create-error.log"
        $handle=$process.Handle;$process.WaitForExit()
        if($process.ExitCode -ne 0){throw "Create failed: $run/create.log"}
    }
    $mode=if($Visual){'--benchmark-graphics'}else{'--benchmark'}
    $ticks=if($OriginProbe){820}elseif($DispersionProbe){360}elseif($Visual -or $ProbeOnly){1800}else{9010}
    $arguments=@($mode,('"'+$fixture+'"'),'--benchmark-ticks',$ticks,'--benchmark-runs','1','--config',('"'+$config+'"'),'--mod-directory',('"'+$short+'"'),'--disable-audio','--disable-migration-window')
    if($Visual){$arguments+=@('--window-size','1280x720','--graphics-quality',$GraphicsQuality)}
    $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/benchmark.log" -RedirectStandardError "$run/benchmark-error.log"
    $started=$process.StartTime.ToUniversalTime();$handle=$process.Handle;$process.WaitForExit()
    if($process.ExitCode -ne 0){throw "Benchmark failed: $run/benchmark.log"}
    if($OriginProbe){
        $probeReport=Join-Path $run 'script-output/origin-probe.json'
        if(-not(Test-Path -LiteralPath $probeReport) -or (Get-Item -LiteralPath $probeReport).LastWriteTimeUtc -lt $started){throw "Missing fresh origin probe: $probeReport"}
        Write-Output "Completed canonical origin probe: $probeReport"
        continue
    }
    if($DispersionProbe){
        $probeReport=Join-Path $run 'script-output/dispersion-probe.json'
        if(-not(Test-Path -LiteralPath $probeReport) -or (Get-Item -LiteralPath $probeReport).LastWriteTimeUtc -lt $started){throw "Missing fresh probe: $probeReport"}
        Write-Output "Completed native dispersion probe: $probeReport"
        continue
    }
    $report=Join-Path $run 'script-output/jet-report.json'
    if(-not(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTimeUtc -lt $started){throw "Missing fresh report: $report"}
    if($Visual){
        $data=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        if($data.captures.Count -ne 352){throw "Expected 352 captures: $report"}
        foreach($capture in $data.captures){
            $path=Join-Path $run "script-output/captures/$capture.png"
            if(-not(Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTimeUtc -lt $started){throw "Missing fresh capture: $capture"}
        }
    }
    & python -B (Join-Path $PSScriptRoot 'qc/acid-jet/check.py') $run
    if($LASTEXITCODE -ne 0){throw "Native acceptance failed: $run"}
    Write-Output "Completed $profile visual=$Visual $report"
}
