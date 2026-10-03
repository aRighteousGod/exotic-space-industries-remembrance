[CmdletBinding()]
param(
 [ValidateSet('stage','save','reload','all')][string]$Mode='stage',
 [string]$RunName='shutdown',
 [string]$SaveInput='.factorio-qc/wtr/final-player/fixture.zip',
 [string]$AssetMods='.factorio-qc/admin-v720/mods'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$fixtureSource=Join-Path $PSScriptRoot 'qc/admin-shutdown'
if($RunName -notmatch '^[A-Za-z0-9_-]{1,16}$'){throw 'Use a simple fixture RunName of at most 16 characters.'}
$run=Join-Path $repo ('.factorio-qc/asd/'+$RunName)
$assets=if([IO.Path]::IsPathRooted($AssetMods)){$AssetMods}else{Join-Path $repo $AssetMods}
$inputSave=if([IO.Path]::IsPathRooted($SaveInput)){$SaveInput}else{Join-Path $repo $SaveInput}
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$utf8=[Text.UTF8Encoding]::new($false)
function WriteJson($Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 8),$utf8)}
function ReadSharedText($Path){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 $reader=[IO.StreamReader]::new($stream)
 try{return $reader.ReadToEnd()}finally{$reader.Dispose()}
}
function StageFixture{
 if(Test-Path -LiteralPath $run){throw 'Use a fresh RunName; prior fixture evidence is retained.'}
 if(-not(Test-Path -LiteralPath $inputSave)){throw 'A disposable connected-player seed is required.'}
 if(-not(Test-Path -LiteralPath (Join-Path $assets 'mod-list.json'))){throw 'Complete native visual assets are required.'}
 foreach($phase in @('enabled','disabled')){
  $profile=Join-Path $run $phase
  $mods=Join-Path $profile 'mods'
  New-Item -ItemType Directory -Force -Path $mods | Out-Null
  foreach($archive in Get-ChildItem -LiteralPath $assets -File -Filter '*.zip'){
   New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
  }
  foreach($directory in Get-ChildItem -LiteralPath $assets -Directory){
   if($directory.Name -eq 'exotic-space-industries-remembrance' -or $directory.Name -match 'qc|benchmark'){continue}
   New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null
  }
  $pack=Join-Path $mods 'exotic-space-industries-remembrance'
  New-Item -ItemType Directory -Path $pack | Out-Null
  Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
  $helper=Join-Path $mods 'zzz-esir-admin-shutdown-qc'
  New-Item -ItemType Directory -Path $helper | Out-Null
  Get-ChildItem -LiteralPath $fixtureSource -Filter '*.lua' -File | Copy-Item -Destination $helper
  $enabled=($phase -eq 'enabled').ToString().ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $helper 'fixture-config.lua'),"return {enabled=$enabled}",$utf8)
  WriteJson (Join-Path $helper 'info.json') @{name='zzz-esir-admin-shutdown-qc';version='0.0.1';title='Full coordinator shutdown QC';author='ESIR QC';factorio_version='2.0';dependencies=@('base','exotic-space-industries-remembrance')}
  [IO.File]::AppendAllText((Join-Path $pack 'control.lua'),[IO.File]::ReadAllText((Join-Path $helper 'instrument.lua')),$utf8)
  $list=Get-Content -LiteralPath (Join-Path $assets 'mod-list.json') -Raw | ConvertFrom-Json
  foreach($entry in $list.mods){if($entry.name -match 'qc|benchmark'){$entry.enabled=$false}}
  $list.mods=@($list.mods | Where-Object name -ne 'zzz-esir-admin-shutdown-qc')+@(@{name='zzz-esir-admin-shutdown-qc';enabled=$true})
  WriteJson (Join-Path $mods 'mod-list.json') $list
  [IO.File]::WriteAllLines((Join-Path $profile 'config.ini'),@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$profile",'[other]','check-updates=false','autosave-interval=0'),$utf8)
  $hashes=Get-ChildItem -LiteralPath $pack -Recurse -File -Filter '*.lua' | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash
  WriteJson (Join-Path $profile 'source-hashes.json') $hashes
 }
 Copy-Item -LiteralPath $inputSave -Destination (Join-Path $run 'enabled/input.zip')
 WriteJson (Join-Path $run 'manifest.json') @{engine='2.0.77';created_utc=(Get-Date).ToUniversalTime().ToString('o');input=$inputSave;input_sha256=(Get-FileHash -LiteralPath $inputSave).Hash;assets=$assets;source=(Join-Path $repo 'exotic-space-industries-remembrance');scope='Full coordinator shutdown after native client autosave; no multiplayer proof'}
 Write-Output "Staged without starting Factorio: $run"
}
function RunFixture([string]$phase){
 $profile=Join-Path $run $phase
 if(-not(Test-Path -LiteralPath (Join-Path $profile 'config.ini'))){throw 'Run -Mode stage first.'}
 if($phase -eq 'disabled'){
  $checkpoint=Join-Path $run 'enabled/saves/_autosave-admin-shutdown-enabled.zip'
  if(-not(Test-Path -LiteralPath $checkpoint)){throw 'Enabled native autosave is missing.'}
  Copy-Item -LiteralPath $checkpoint -Destination (Join-Path $profile 'input.zip') -Force
 }
 $arguments=@('--load-game',(Join-Path $profile 'input.zip'),'--config',(Join-Path $profile 'config.ini'),'--mod-directory',(Join-Path $profile 'mods'),'--disable-audio','--disable-migration-window','--window-size','1280x720','--force-graphics-preset','very-low')
 $env:SteamAppId='427520';$env:SteamGameId='427520'
 $started=Get-Date
 $process=Start-Process -FilePath $exe -ArgumentList @($arguments|ForEach-Object{'"'+$_+'"'}) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $profile 'stdout.log') -RedirectStandardError (Join-Path $profile 'stderr.log')
 $process.Handle | Out-Null
 WriteJson (Join-Path $profile 'process.json') @{id=$process.Id;started_utc=$process.StartTime.ToUniversalTime().ToString('o')}
 $complete=$false
 try{
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $deadline=(Get-Date).AddSeconds(240)
  while(-not $process.HasExited -and (Get-Date) -lt $deadline){
   $logPath=Join-Path $profile 'stdout.log'
   $log=if(Test-Path -LiteralPath $logPath){ReadSharedText $logPath}else{''}
   if($log -match 'Error while running event|ADMIN_SHUTDOWN_QC ERROR|Error Util.cpp|Error AppManagerStates.cpp'){throw "Native fixture error: $logPath"}
   $reportPath=Join-Path $profile 'script-output/shutdown-qc.json'
   if((Test-Path -LiteralPath $reportPath) -and (Get-Item -LiteralPath $reportPath).LastWriteTime -gt $started){
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if($report.version -and $report.version -ne '2.0.77'){throw "Expected Factorio 2.0.77; fixture reports $($report.version)."}
    if($report.phase -eq 'error' -or -not $report.all_pass){throw "Fixture assertion failed: $reportPath"}
    if($phase -eq 'disabled' -and $report.phase -eq 'disabled_done'){$complete=$true;break}
    if($phase -eq 'enabled' -and $report.phase -eq 'prepared' -and $log -match 'Saving finished'){
     $checkpoint=Join-Path $profile 'saves/_autosave-admin-shutdown-enabled.zip'
     if((Test-Path -LiteralPath $checkpoint) -and (Get-Item -LiteralPath $checkpoint).LastWriteTime -gt $started){
      try{$zip=[IO.Compression.ZipFile]::OpenRead($checkpoint);$zip.Dispose();$complete=$true;break}catch{}
     }
    }
   }
   Start-Sleep -Milliseconds 250;$process.Refresh()
  }
  if(-not $complete){throw "Native $phase fixture did not complete; inspect $profile/stdout.log"}
 }finally{
  if(-not $process.HasExited){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
 }
 $reportPath=Join-Path $profile 'script-output/shutdown-qc.json'
 $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
 [pscustomobject]@{phase=$phase;all_pass=$report.all_pass;checks=$report.checks.Count;report=$reportPath}|ConvertTo-Json
}
if($Mode -eq 'stage' -or $Mode -eq 'all'){StageFixture}
if($Mode -eq 'save' -or $Mode -eq 'all'){RunFixture 'enabled'}
if($Mode -eq 'reload' -or $Mode -eq 'all'){RunFixture 'disabled'}
