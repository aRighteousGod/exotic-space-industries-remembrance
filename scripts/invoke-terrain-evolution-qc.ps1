[CmdletBinding()]
param([string]$RunName='native',[switch]$Disabled,[switch]$DumpOnly,[int]$Ticks=2800,[uint32]$MapSeed=42,[string]$SaveInput,[string]$SourceRoot,
    [string]$Scenario,[string]$HelperRoot,[string]$SeedMods,[switch]$PrepareOnly,[switch]$Bare,[switch]$Lifecycle,[switch]$Checkpoint,[switch]$Guards,[switch]$GlebaFire,[switch]$Presets,
    [ValidateSet('TerrainEvolution','TerrainEvolution2','diurnal-dynamics')][string]$Compatibility)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$run=Join-Path $repo ".factorio-qc/terrain-evolution/$RunName"
$mods=Join-Path $run 'mods'
$seed=Join-Path $repo '.factorio-qc/fmqc/mods-live'
if($SeedMods){$seed=(Resolve-Path -LiteralPath $SeedMods).Path}
$factorio='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
if(($DumpOnly -or -not $SaveInput -or -not $PrepareOnly) -and (Get-Process factorio -ErrorAction SilentlyContinue)){
    throw 'Run Factorio fixtures sequentially; another Factorio process is active.'
}
New-Item -ItemType Directory -Path $mods -Force | Out-Null
foreach($zip in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    $target=Join-Path $mods $zip.Name
    if(-not(Test-Path -LiteralPath $target)){New-Item -ItemType HardLink -Path $target -Target $zip.FullName | Out-Null}
}
foreach($pack in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
    $target=Join-Path $mods $pack.Name
    if(-not(Test-Path -LiteralPath $target)){New-Item -ItemType Junction -Path $target -Target $pack.FullName | Out-Null}
}
$main=Join-Path $mods 'exotic-space-industries-remembrance'
$source=if($SourceRoot){(Resolve-Path -LiteralPath $SourceRoot).Path}else{Join-Path $repo 'exotic-space-industries-remembrance'}
New-Item -ItemType Directory -Path $main -Force | Out-Null
$null=& robocopy $source $main /E /XJ /XD (Join-Path $source 'graphics') (Join-Path $source 'sounds') /NJH /NJS /NFL /NDL /NP
if($LASTEXITCODE -ge 8){throw "Source copy failed: $source"}
foreach($assets in @('graphics','sounds')){
    $assetSource=Join-Path $source $assets
    if(-not(Test-Path -LiteralPath $assetSource -PathType Container)){
        if($assets -eq 'sounds'){continue}
        $assetSource=Join-Path $repo 'exotic-space-industries-remembrance/graphics'
    }
    $target=Join-Path $main $assets
    if(-not(Test-Path -LiteralPath $target)){New-Item -ItemType Junction -Path $target -Target $assetSource | Out-Null}
}
$helper=Join-Path $mods 'zzz-esir-terrain-qc'
if($HelperRoot){
    $helperInfo=Get-Content -LiteralPath (Join-Path $HelperRoot 'info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $helper=Join-Path $mods $helperInfo.name
}
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/terrain-evolution') -File | Copy-Item -Destination $helper -Force
if($HelperRoot){Get-ChildItem -LiteralPath $HelperRoot -File | Copy-Item -Destination $helper -Force}
if($Scenario){Copy-Item -LiteralPath $Scenario -Destination (Join-Path $helper 'control.lua') -Force}
if($Checkpoint){Copy-Item -LiteralPath (Join-Path $helper 'persistence-control.lua') -Destination (Join-Path $helper 'control.lua') -Force}
$utf8=[Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $helper 'options.lua'),"return {disabled=$($Disabled.IsPresent.ToString().ToLowerInvariant()),ticks=$Ticks}",$utf8)
$bridgeName=if($HelperRoot){'instrument.lua'}else{'bridge.lua'}
if(-not $Bare){
    $bridge=Get-Content -LiteralPath (Join-Path $helper $bridgeName) -Raw -Encoding UTF8
    [IO.File]::AppendAllText((Join-Path $main 'control.lua'),"`n$bridge",$utf8)
    if($Lifecycle){
        [IO.File]::AppendAllText((Join-Path $main 'control.lua'),"`n"+[IO.File]::ReadAllText((Join-Path $helper 'lifecycle-bridge.lua')),$utf8)
        [IO.File]::AppendAllText((Join-Path $helper 'control.lua'),"`n"+[IO.File]::ReadAllText((Join-Path $helper 'lifecycle-driver.lua')),$utf8)
    }
    if($Checkpoint){[IO.File]::AppendAllText((Join-Path $main 'control.lua'),"`n"+[IO.File]::ReadAllText((Join-Path $helper 'persistence-bridge.lua')),$utf8)}
    if($Presets){
        [IO.File]::AppendAllText((Join-Path $main 'control.lua'),"`n"+[IO.File]::ReadAllText((Join-Path $helper 'preset-bridge.lua')),$utf8)
        Copy-Item -LiteralPath (Join-Path $helper 'control-presets.lua') -Destination (Join-Path $helper 'control.lua') -Force
    }
    if($Guards -or $GlebaFire){
        $runtime=Join-Path $main 'scripts/control/terrain-evolution.lua'
        $body=[IO.File]::ReadAllText($runtime)
        $export='model._qc={propose=propose,commit=commit,hazards=hazards,recover_tiles=recover_tiles,active=active,entity_event=entity_event,service_events=service_events}'+"`nreturn model"
        if(([regex]::Matches($body,'(?m)^return model\s*$')).Count -ne 1){throw 'Unexpected terrain module return shape.'}
        [IO.File]::WriteAllText($runtime,[regex]::Replace($body,'(?m)^return model\s*$',$export),$utf8)
        $fixturePrefix=if($GlebaFire){'gleba-fire'}else{'guard'}
        [IO.File]::AppendAllText((Join-Path $main 'control.lua'),"`n"+[IO.File]::ReadAllText((Join-Path $helper ($fixturePrefix+'-bridge.lua'))),$utf8)
        Copy-Item -LiteralPath (Join-Path $helper ($fixturePrefix+'-control.lua')) -Destination (Join-Path $helper 'control.lua') -Force
    }
}
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-terrain-qc')
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -in @('TerrainEvolution','TerrainEvolution2','diurnal-dynamics','extinguisher')){$mod.enabled=$false}}
$list.mods+=@{name=(Split-Path $helper -Leaf);enabled=(-not $Bare)}
if($Compatibility){
    $stub=Join-Path $mods $Compatibility
    New-Item -ItemType Directory -Path $stub -Force | Out-Null
    @{name=$Compatibility;version='1.0.3';title='Compatibility presence fixture';author='ESIR QC';factorio_version='2.0'}|ConvertTo-Json|Set-Content (Join-Path $stub 'info.json') -Encoding UTF8
    $list.mods=@($list.mods|Where-Object name -ne $Compatibility)+@(@{name=$Compatibility;enabled=$true})
    Copy-Item -LiteralPath (Join-Path $helper 'control-compat.lua') -Destination (Join-Path $helper 'control.lua') -Force
}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
if($Bare -and (Test-Path -LiteralPath (Join-Path $seed 'mod-settings.dat'))){Copy-Item -LiteralPath (Join-Path $seed 'mod-settings.dat') -Destination (Join-Path $mods 'mod-settings.dat')}
$ini=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $ini -Encoding UTF8
if($DumpOnly){
    & $factorio --dump-data --config $ini --mod-directory $mods --disable-audio 2>&1 | Out-File (Join-Path $run 'dump.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Final data load failed: $run/dump.txt"}
    Write-Output "Final data: $run/script-output/data-raw-dump.json";exit
}
$save=Join-Path $run 'fixture.zip'
if($SaveInput){Copy-Item -LiteralPath $SaveInput -Destination $save -Force}
else {
    & $factorio --create $save --map-gen-seed $MapSeed --config $ini --mod-directory $mods --disable-audio 2>&1 | Out-File (Join-Path $run 'create.txt') -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Create failed: $run/create.txt"}
}
$started=Get-Date
if($PrepareOnly){Write-Output "Prepared: $run";exit}
& $factorio --benchmark $save --benchmark-ticks $Ticks --benchmark-runs 1 --config $ini --mod-directory $mods --disable-audio --disable-migration-window 2>&1 | Out-File (Join-Path $run 'benchmark.txt') -Encoding utf8
if($LASTEXITCODE -ne 0){throw "Runtime failed: $run/benchmark.txt"}
$report=Join-Path $run $(if($Checkpoint){'script-output/terrain-persistence-qc.json'}else{'script-output/terrain-qc.json'})
if(-not(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started){throw "Missing fresh report: $report"}
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
[pscustomobject]@{all_pass=$result.all_pass;count=$result.count;failed=@($result.cases.PSObject.Properties | Where-Object {-not $_.Value.pass} | ForEach-Object Name);report=$report} | ConvertTo-Json -Depth 5
if(-not $result.all_pass){throw "Acceptance failed: $report"}
