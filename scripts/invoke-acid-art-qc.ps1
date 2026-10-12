[CmdletBinding()]
param([switch]$Visual,[switch]$ReuseFixture,
    [string]$RunRoot,[string]$SeedMods,
    [ValidateSet('high','medium')][string]$GraphicsQuality='high')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$run=if($RunRoot){[IO.Path]::GetFullPath($RunRoot)}else{Join-Path $repo '.factorio-qc/acid-art-r03'}
$mods=Join-Path $run 'mods'
$shortMods=if($RunRoot){Join-Path ([IO.Path]::GetPathRoot($run)) 'esir-acid-art-r03-mods'}else{Join-Path $env:TEMP 'esir-acid-art-r03-mods'}
$env:TEMP=Join-Path $run 'cache';$env:TMP=$env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
$factorio='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$seed=if($SeedMods){$SeedMods}else{Join-Path $repo '.factorio-qc/wtr/ports-3x3/mods'}
New-Item -ItemType Directory -Path $mods -Force | Out-Null
if(Test-Path -LiteralPath $shortMods){
    $link=Get-Item -LiteralPath $shortMods
    if($link.LinkType -ne 'Junction' -or [string]$link.Target -ne $mods){throw "Unexpected existing QC link: $shortMods"}
}else{New-Item -ItemType Junction -Path $shortMods -Target $mods | Out-Null}
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
$helper=Join-Path $mods 'zzz-esir-acid-art-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/acid-art') -File | Copy-Item -Destination $helper -Force
"return {visual=$($Visual.IsPresent.ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-acid-art-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-acid-art-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$config=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
$fixture=Join-Path $run 'fixture.zip'
$env:SteamAppId='427520';$env:SteamGameId='427520'
if(-not($ReuseFixture -and (Test-Path -LiteralPath $fixture))){
    $createArgs=@('--create',('"'+$fixture+'"'),'--config',('"'+$config+'"'),'--mod-directory',('"'+$shortMods+'"'),'--disable-audio')
    $create=Start-Process -FilePath $factorio -ArgumentList $createArgs -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'create.log') -RedirectStandardError (Join-Path $run 'create-error.log')
    $createHandle=$create.Handle
    $create.WaitForExit()
    if($create.ExitCode -ne 0){throw "Fixture creation failed ($($create.ExitCode)): $run/create.log"}
}
$mode=if($Visual){'--benchmark-graphics'}else{'--benchmark'}
$env:SteamAppId='427520';$env:SteamGameId='427520'
Set-Content -LiteralPath (Join-Path $run 'steam_appid.txt') -Value '427520' -Encoding ASCII
$arguments=@($mode,('"'+$fixture+'"'),'--benchmark-ticks','300','--benchmark-runs','1',
    '--config',('"'+$config+'"'),'--mod-directory',('"'+$shortMods+'"'),'--disable-audio','--disable-migration-window')
if($Visual){$arguments+=@('--window-size','1280x720','--graphics-quality',$GraphicsQuality)}
$process=Start-Process -FilePath $factorio -ArgumentList $arguments -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'benchmark.log') -RedirectStandardError (Join-Path $run 'benchmark-error.log')
$captureStarted=$process.StartTime.ToUniversalTime()
$handle=$process.Handle
$process.WaitForExit()
if($process.ExitCode -ne 0){throw "Benchmark failed: $run/benchmark.log"}
$reportPath=Join-Path $run 'script-output/acid-art-qc.json'
if(-not(Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $captureStarted){throw 'Benchmark did not write a fresh acceptance report'}
$report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$report | ConvertTo-Json -Depth 8
if(-not $report.all_pass){throw 'Acidthrower muzzle acceptance failed'}
if($Visual){
    if($report.captures.Count -ne 88){throw "Expected 88 native captures; got $($report.captures.Count)"}
    foreach($capture in $report.captures){
        $path=Join-Path $run "script-output/acid-art/$capture.png"
        if(-not(Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTimeUtc -lt $captureStarted){throw "Missing fresh capture: $capture"}
    }
}
