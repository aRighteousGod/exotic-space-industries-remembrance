[CmdletBinding()]
param([switch]$Disabled,[switch]$ReuseFixture,[switch]$Visual,[string]$Resolution='1280x720',[int]$Ticks=900,[string]$RunName='main',[string]$PlayerSave)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$run=Join-Path $repo ('.factorio-qc\admin-'+$RunName)
$mods=Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip') {
    $destination=Join-Path $mods $archive.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType HardLink -Path $destination -Target $archive.FullName | Out-Null}
}
foreach($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
    if($Visual -and $directory.Name -match '-graphics-4$'){
        $destination=Join-Path $mods ($directory.Name+'_1.0.0.zip')
        python -B (Join-Path $PSScriptRoot 'qc\admin-tools\assemble-visual-assets.py') $repo $destination
        if($LASTEXITCODE -ne 0){throw 'Visual asset assembly failed.'}
        continue
    }
    if($Visual -and $directory.Name -match '-graphics-[123]$'){
        $info=Get-Content -LiteralPath (Join-Path $directory.FullName 'info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $archive=Join-Path (Join-Path $env:APPDATA 'Factorio/mods') ($info.name+'_'+$info.version+'.zip')
        if(Test-Path -LiteralPath $archive){
            $destination=Join-Path $mods (Split-Path $archive -Leaf)
            if(-not(Test-Path -LiteralPath $destination)){Copy-Item -LiteralPath $archive -Destination $destination}
            continue
        }
    }
    $destination=Join-Path $mods $directory.Name
    if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Junction -Path $destination -Target $directory.FullName | Out-Null}
}
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
$helper=Join-Path $mods 'zzz-esir-admin-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\admin-tools') -File | Copy-Item -Destination $helper -Force
$encoding=[Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'),('return {enabled='+(-not $Disabled).ToString().ToLowerInvariant()+',visual='+$Visual.IsPresent.ToString().ToLowerInvariant()+'}'),$encoding)
[IO.File]::AppendAllText((Join-Path $pack 'control.lua'),[IO.File]::ReadAllText((Join-Path $helper 'instrument.lua')),$encoding)
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-admin-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher'){$mod.enabled=$false}}
$list.mods+=@{name='zzz-esir-admin-qc';enabled=$true}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($list|ConvertTo-Json -Depth 8),$encoding)
$config=Join-Path $run 'config.ini'
[IO.File]::WriteAllLines($config,@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false'),$encoding)
$fixture=Join-Path $run 'fixture.zip'
if($PlayerSave){Copy-Item -LiteralPath $PlayerSave -Destination $fixture -Force}
elseif(-not($ReuseFixture -and (Test-Path -LiteralPath $fixture))){
    & $factorio --create $fixture --config $config --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Admin fixture creation failed: $run\create.txt"}
}
if($Visual){
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    $arguments=@('--benchmark-graphics',('"'+$fixture+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1','--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio','--disable-migration-window','--window-size',$Resolution)
    $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'visual.txt') -RedirectStandardError (Join-Path $run 'visual-error.txt')
    try { if(-not $process.WaitForExit(240000)){throw 'Admin visual fixture timed out.'};$process.Refresh();if($process.ExitCode -ne 0){throw "Admin visual fixture failed: $run\visual.txt"} }
    finally {if(-not $process.HasExited){Stop-Process -Id $process.Id}}
}else{
    & $factorio --benchmark $fixture --benchmark-ticks $Ticks --benchmark-runs 1 --config $config --mod-directory $mods --disable-audio --disable-migration-window 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Admin fixture runtime failed: $run\benchmark.txt"}
}
$report=Get-Content -LiteralPath (Join-Path $run 'script-output\admin-qc.json') -Raw -Encoding UTF8 | ConvertFrom-Json
[pscustomobject]@{all_pass=$report.all_pass;checks=$report.checks.Count;failed=@($report.checks|Where-Object {-not $_.ok});report=(Join-Path $run 'script-output\admin-qc.json')}|ConvertTo-Json -Depth 6
if(-not $report.all_pass){throw 'Admin fixture assertions failed.'}
